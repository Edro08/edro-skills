<#
.SYNOPSIS
    Audits and optionally remediates Go vulnerabilities across multiple Go services using govulncheck.
.DESCRIPTION
    Scans directories containing go.mod under -Path (filtered by -Services if provided),
    runs `govulncheck -format json ./...`, and writes a Markdown summary to -OutFile
    (default: go-vulns-report.md).
    With -Fix, upgrades vulnerable third-party modules that have a fixed_version via `go get`,
    runs `go mod tidy`, verifies with `go vet` / `go test`, and re-scans with govulncheck.
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string[]]$Services = @(),
    [switch]$Audit,
    [switch]$Fix,
    [switch]$FixStdlib,
    [string]$GoVersion = "",
    [switch]$UpgradeAll,
    [switch]$InstallTool,
    [switch]$Race,
    [switch]$SkipTests,
    [string]$OutFile = "go-vulns-report.md",
    [switch]$Console,
    [int]$Depth = 1
)

$ErrorActionPreference = "SilentlyContinue"

function Resolve-Govulncheck {
    param([bool]$AutoInstall)

    $cmd = Get-Command govulncheck -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $gopath = (& go env GOPATH 2>$null | Out-String).Trim()
    if ($gopath) {
        $candidate = Join-Path $gopath "bin\govulncheck.exe"
        if (Test-Path $candidate) { return $candidate }
        $candidateUnix = Join-Path $gopath "bin/govulncheck"
        if (Test-Path $candidateUnix) { return $candidateUnix }
    }

    if ($AutoInstall) {
        & go install golang.org/x/vuln/cmd/govulncheck@latest 2>&1 | Out-Null
        $cmd = Get-Command govulncheck -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
        if ($gopath) {
            $candidate = Join-Path $gopath "bin\govulncheck.exe"
            if (Test-Path $candidate) { return $candidate }
        }
    }

    return $null
}

function Find-GoRepos {
    param(
        [string]$RootPath,
        [string[]]$FilterServices,
        [int]$MaxDepth
    )

    $resolved = (Resolve-Path -Path $RootPath -ErrorAction Stop).Path
    $repos = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()

    if ((Test-Path (Join-Path $resolved "go.mod")) -and $FilterServices.Count -eq 0) {
        $repos.Add((Get-Item -Path $resolved))
        return $repos
    }

    $queue = [System.Collections.Queue]::new()
    $queue.Enqueue(@{ Dir = (Get-Item -Path $resolved); Level = 0 })

    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        $dir = $item.Dir
        $level = $item.Level
        if ($level -ge $MaxDepth) { continue }

        $children = Get-ChildItem -Path $dir.FullName -Directory | Where-Object {
            -not $_.Name.StartsWith(".") -and $_.Name -notin @("node_modules", "vendor", "target", "dist", "build")
        } | Sort-Object Name

        foreach ($child in $children) {
            if (Test-Path (Join-Path $child.FullName "go.mod")) {
                $repos.Add($child)
            }
            elseif ($level + 1 -lt $MaxDepth) {
                $queue.Enqueue(@{ Dir = $child; Level = $level + 1 })
            }
        }
    }

    if ($FilterServices.Count -gt 0) {
        $normalized = $FilterServices | ForEach-Object { $_.Trim().ToLowerInvariant() }
        $repos = [System.Collections.Generic.List[System.IO.DirectoryInfo]](
            $repos | Where-Object { $normalized -contains $_.Name.ToLowerInvariant() }
        )
    }

    return $repos
}

function Parse-GovulncheckStream {
    param([string[]]$Lines)

    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()
    $buffer = [System.Text.StringBuilder]::new()
    $depth = 0
    $inString = $false
    $escaped = $false

    foreach ($line in $Lines) {
        if (-not $line) { continue }
        [void]$buffer.AppendLine($line)

        foreach ($ch in $line.ToCharArray()) {
            if ($escaped) {
                $escaped = $false
                continue
            }
            if ($ch -eq '\') {
                if ($inString) { $escaped = $true }
                continue
            }
            if ($ch -eq '"') {
                $inString = -not $inString
                continue
            }
            if (-not $inString) {
                if ($ch -eq '{') { $depth++ }
                elseif ($ch -eq '}') { $depth-- }
            }
        }

        if ($depth -eq 0 -and $buffer.Length -gt 0) {
            $raw = $buffer.ToString().Trim()
            [void]$buffer.Clear()
            if ($raw.StartsWith("{")) {
                try {
                    $obj = $raw | ConvertFrom-Json
                    if ($obj.finding) {
                        $f = $obj.finding
                        $mod = $null
                        if ($f.trace -and $f.trace.Count -gt 0) {
                            $mod = $f.trace[0].module
                        }
                        $findings.Add([PSCustomObject]@{
                            Osv          = $f.osv
                            Module       = $mod
                            FixedVersion = $f.fixed_version
                        })
                    }
                }
                catch { }
            }
        }
    }

    return $findings
}

function Invoke-Govulncheck {
    param(
        [string]$BinPath,
        [string]$RepoPath
    )

    Push-Location $RepoPath
    try {
        $rawOut = & $BinPath -format json ./... 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    $findings = Parse-GovulncheckStream -Lines ($rawOut | ForEach-Object { "$_" })
    return [PSCustomObject]@{
        ExitCode = $exitCode
        Findings = $findings
    }
}

$vulnBin = Resolve-Govulncheck -AutoInstall:$InstallTool.IsPresent
if (-not $vulnBin) {
    Write-Output "Error: govulncheck not found. Install it with: go install golang.org/x/vuln/cmd/govulncheck@latest (or pass -InstallTool)."
    exit 1
}

$repos = Find-GoRepos -RootPath $Path -FilterServices $Services -MaxDepth $Depth
if ($repos.Count -eq 0) {
    Write-Output "No Go modules (go.mod) found."
    exit 0
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($repo in $repos) {
    $scan = Invoke-Govulncheck -BinPath $vulnBin -RepoPath $repo.FullName
    $uniqueOsv = @($scan.Findings | Select-Object -ExpandProperty Osv -Unique)
    $foundCount = $uniqueOsv.Count

    $fixable = @{}
    $stdlibFixes = [System.Collections.Generic.List[string]]::new()
    $stdlibCount = 0
    $noFixCount = 0

    $seenFixOsv = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($f in $scan.Findings) {
        if ($f.Module -eq "stdlib") {
            if ($seenFixOsv.Add("stdlib:" + $f.Osv)) { $stdlibCount++ }
            if ($f.FixedVersion) {
                $stdlibFixes.Add(($f.FixedVersion -replace '^go', ''))
            }
        }
        elseif ($f.Module -and $f.FixedVersion) {
            $fixable[$f.Module] = $f.FixedVersion
        }
        elseif ($f.Osv) {
            if ($seenFixOsv.Add("nofix:" + $f.Osv)) { $noFixCount++ }
        }
    }

    $fixedModules = [System.Collections.Generic.List[string]]::new()
    $remainingCount = $foundCount
    $testsStatus = "-"
    $status = if ($foundCount -eq 0) { "Clean" } else { "Vulns found (audit)" }

    $shouldApply = (-not $Audit) -and ($Fix -or $FixStdlib -or $UpgradeAll -or [bool]$GoVersion)

    if ($shouldApply -and ($fixable.Count -gt 0 -or $UpgradeAll -or [bool]$GoVersion -or ($FixStdlib -and $stdlibFixes.Count -gt 0))) {
        $upgradeFailed = $false
        Push-Location $repo.FullName
        try {
            if ($GoVersion) {
                $cleanGoVer = $GoVersion -replace '^go', ''
                & go mod tidy "-go=$cleanGoVer" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $fixedModules.Add("go@$cleanGoVer")
                }
                else {
                    $upgradeFailed = $true
                }
            }
            elseif ($FixStdlib -and $stdlibFixes.Count -gt 0) {
                $highestStdlib = ($stdlibFixes | Sort-Object {
                    try { [version]($_ -replace '[^0-9.].*$', '') } catch { [version]"0.0" }
                } | Select-Object -Last 1)
                if ($highestStdlib) {
                    & go get "go@$highestStdlib" 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $fixedModules.Add("go@$highestStdlib")
                    }
                    else {
                        $upgradeFailed = $true
                    }
                }
            }

            if ($UpgradeAll) {
                & go mod tidy 2>&1 | Out-Null
                & go get -u ./... 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $fixedModules.Add("all(-u)")
                }
                else {
                    $upgradeFailed = $true
                }
            }
            elseif ($Fix -and $fixable.Count -gt 0) {
                foreach ($mod in ($fixable.Keys | Sort-Object)) {
                    $ver = $fixable[$mod]
                    & go get "$mod@$ver" 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $fixedModules.Add("$mod@$ver")
                    }
                    else {
                        $upgradeFailed = $true
                    }
                }
            }

            & go mod tidy 2>&1 | Out-Null

            & go vet ./... 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $testsStatus = "vet failed"
            }
            elseif ($SkipTests) {
                $testsStatus = "vet OK (tests skipped)"
            }
            else {
                if ($Race) { & go test -race ./... 2>&1 | Out-Null }
                else { & go test ./... 2>&1 | Out-Null }
                $testsStatus = if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" }
            }
        }
        finally {
            Pop-Location
        }

        $rescan = Invoke-Govulncheck -BinPath $vulnBin -RepoPath $repo.FullName
        $remainingCount = @($rescan.Findings | Select-Object -ExpandProperty Osv -Unique).Count

        if ($upgradeFailed -or $testsStatus -eq "FAIL" -or $testsStatus -eq "vet failed") {
            $status = "Partial/Check tests"
        }
        elseif ($remainingCount -eq 0) {
            $status = "Fixed"
        }
        else {
            $status = "Remaining ($remainingCount)"
        }
    }
    elseif ($shouldApply -and $foundCount -gt 0) {
        $status = "Manual (stdlib/no fix)"
    }

    $notes = @()
    if ($stdlibCount -gt 0) { $notes += "stdlib:$stdlibCount" }
    if ($noFixCount -gt 0) { $notes += "no-fix:$noFixCount" }
    $noteStr = if ($notes.Count -gt 0) { " ($($notes -join ', '))" } else { "" }

    $results.Add([PSCustomObject]@{
        Service   = $repo.Name
        Found     = $foundCount
        Fixed     = if ($fixedModules.Count -gt 0) { ($fixedModules | ForEach-Object { "``$_``" }) -join ", " } else { "-" }
        Remaining = "$remainingCount$noteStr"
        Tests     = $testsStatus
        Status    = $status
    })
}

$totalFound = ($results | Measure-Object -Property Found -Sum).Sum
$fixedRepos = @($results | Where-Object { $_.Status -eq "Fixed" }).Count
$cleanRepos = @($results | Where-Object { $_.Status -eq "Clean" }).Count

if ($Console) {
    foreach ($r in $results) {
        Write-Output "$($r.Service): found=$($r.Found) remaining=$($r.Remaining) tests=$($r.Tests) [$($r.Status)]"
    }
    exit 0
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$modeLabel = if ($shouldApply) { "Fix" } else { "Audit" }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Go Vulnerabilities Report ($modeLabel)")
$lines.Add("")
$lines.Add("Generated: $timestamp | Services: $($results.Count) | Total vulns found: $totalFound | Clean: $cleanRepos | Fixed: $fixedRepos")
$lines.Add("")
$lines.Add("| Service | Found | Fixed Modules | Remaining | Tests | Status |")
$lines.Add("| --- | --- | --- | --- | --- | --- |")

foreach ($r in $results) {
    $lines.Add("| ``$($r.Service)`` | $($r.Found) | $($r.Fixed) | $($r.Remaining) | $($r.Tests) | $($r.Status) |")
}

$outFullPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path (Get-Location).Path $OutFile }
$outDir = Split-Path -Path $outFullPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$lines | Set-Content -Path $outFullPath -Encoding UTF8

Write-Output "Go vuln report ($modeLabel) written to $outFullPath ($($results.Count) services, $totalFound vulns found, $fixedRepos fixed)"
