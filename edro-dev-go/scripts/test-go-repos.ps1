<#
.SYNOPSIS
    Runs `go vet` and `go test` across multiple Go services and writes a compact Markdown report.
.DESCRIPTION
    Scans directories containing go.mod under -Path (filtered by -Services if provided),
    executes `go vet ./...` (unless -SkipVet) and `go test ./...` (or `-race` with -Race),
    and writes a summary table plus failure details to -OutFile (default: go-tests-report.md).
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string[]]$Services = @(),
    [switch]$Race,
    [switch]$SkipVet,
    [string]$OutFile = "go-tests-report.md",
    [switch]$Console,
    [int]$Depth = 1
)

$ErrorActionPreference = "SilentlyContinue"

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

$repos = Find-GoRepos -RootPath $Path -FilterServices $Services -MaxDepth $Depth
if ($repos.Count -eq 0) {
    Write-Output "No Go modules (go.mod) found."
    exit 0
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()
$failures = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($repo in $repos) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $vetStatus = "Skipped"
    $testStatus = "PASS"
    $failDetails = [System.Collections.Generic.List[string]]::new()

    Push-Location $repo.FullName
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if (-not $SkipVet) {
            $vetOut = & go vet ./... 2>&1
            if ($LASTEXITCODE -eq 0) {
                $vetStatus = "PASS"
            }
            else {
                $vetStatus = "FAIL"
                $vetText = ($vetOut | ForEach-Object { "$_" }) -join "`n"
                $failDetails.Add("### $($repo.Name) — go vet`n`n``````text`n$($vetText.Trim())`n``````")
            }
        }

        $testOut = if ($Race) { & go test -race ./... 2>&1 } else { & go test ./... 2>&1 }
        if ($LASTEXITCODE -eq 0) {
            $testStatus = "PASS"
        }
        else {
            $testStatus = "FAIL"
            $testText = ($testOut | ForEach-Object { "$_" }) -join "`n"
            $failDetails.Add("### $($repo.Name) — go test`n`n``````text`n$($testText.Trim())`n``````")
        }
    }
    finally {
        $ErrorActionPreference = $prevEAP
        Pop-Location
        $sw.Stop()
    }

    $overall = if ($vetStatus -eq "FAIL" -or $testStatus -eq "FAIL") { "FAIL" } else { "PASS" }
    $duration = "{0:N1}s" -f $sw.Elapsed.TotalSeconds

    $results.Add([PSCustomObject]@{
        Service  = $repo.Name
        Vet      = $vetStatus
        Tests    = $testStatus
        Duration = $duration
        Status   = $overall
    })

    if ($failDetails.Count -gt 0) {
        $failures.Add([PSCustomObject]@{
            Service = $repo.Name
            Body    = ($failDetails -join "`n`n")
        })
    }
}

$passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count

if ($Console) {
    foreach ($r in $results) {
        Write-Output "$($r.Service): vet=$($r.Vet) tests=$($r.Tests) ($($r.Duration)) [$($r.Status)]"
    }
    exit $(if ($failCount -gt 0) { 1 } else { 0 })
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$raceLabel = if ($Race) { "with -race" } else { "standard" }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Go Verification Report ($raceLabel)")
$lines.Add("")
$lines.Add("Generated: $timestamp | Services: $($results.Count) | Passed: $passCount | Failed: $failCount")
$lines.Add("")
$lines.Add("| Service | Vet | Tests | Duration | Status |")
$lines.Add("| --- | --- | --- | --- | --- |")

foreach ($r in $results) {
    $lines.Add("| ``$($r.Service)`` | $($r.Vet) | $($r.Tests) | $($r.Duration) | $($r.Status) |")
}

if ($failures.Count -gt 0) {
    $lines.Add("")
    $lines.Add("## Failure Details")
    $lines.Add("")
    foreach ($f in $failures) {
        $lines.Add($f.Body)
        $lines.Add("")
    }
}

$outFullPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path (Get-Location).Path $OutFile }
$outDir = Split-Path -Path $outFullPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$lines | Set-Content -Path $outFullPath -Encoding UTF8

Write-Output "Go test report ($raceLabel) written to $outFullPath ($($results.Count) services: $passCount passed, $failCount failed)"
