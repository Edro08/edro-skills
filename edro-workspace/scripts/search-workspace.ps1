<#
.SYNOPSIS
    Searches a pattern across multiple services in a workspace and writes a grouped Markdown report.
.DESCRIPTION
    Scans service directories under -Path (filtered by -Services if provided), ignoring common
    artifact/dependency folders (.git, node_modules, vendor, target, dist, build).
    Uses ripgrep (rg) if available, falling back to Select-String.
    Writes a summary table and per-service match list to -OutFile (default: search-report.md).
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [Parameter(Mandatory = $true)]
    [string]$Pattern,
    [string[]]$Services = @(),
    [string]$Include = "",
    [switch]$Regex,
    [switch]$CaseSensitive,
    [int]$MaxMatchesPerService = 50,
    [string]$OutFile = "search-report.md",
    [switch]$Console,
    [int]$Depth = 1
)

$ErrorActionPreference = "SilentlyContinue"

$SkipDirs = @(
    ".git", ".github", ".gitlab", ".vscode", ".idea", ".gemini",
    "node_modules", "vendor", "target", "dist", "build", "out", "bin", "obj", "__pycache__"
)

function Find-ServiceDirs {
    param(
        [string]$RootPath,
        [string[]]$FilterServices,
        [int]$MaxDepth
    )

    $resolved = (Resolve-Path -Path $RootPath -ErrorAction Stop).Path
    $dirs = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()

    $queue = [System.Collections.Queue]::new()
    $queue.Enqueue(@{ Dir = (Get-Item -Path $resolved); Level = 0 })

    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        $dir = $item.Dir
        $level = $item.Level
        if ($level -ge $MaxDepth) { continue }

        $children = Get-ChildItem -Path $dir.FullName -Directory | Where-Object {
            -not $_.Name.StartsWith(".") -and $_.Name -notin $SkipDirs
        } | Sort-Object Name

        foreach ($child in $children) {
            if ($level + 1 -eq $MaxDepth) {
                $dirs.Add($child)
            }
            else {
                $queue.Enqueue(@{ Dir = $child; Level = $level + 1 })
            }
        }
    }

    if ($FilterServices.Count -gt 0) {
        $normalized = $FilterServices | ForEach-Object { $_.Trim().ToLowerInvariant() }
        $dirs = [System.Collections.Generic.List[System.IO.DirectoryInfo]](
            $dirs | Where-Object { $normalized -contains $_.Name.ToLowerInvariant() }
        )
    }

    return $dirs
}

$rgCmd = Get-Command rg -ErrorAction SilentlyContinue
$serviceDirs = Find-ServiceDirs -RootPath $Path -FilterServices $Services -MaxDepth $Depth

if ($serviceDirs.Count -eq 0) {
    Write-Output "No service directories found."
    exit 0
}

$summaryRows = [System.Collections.Generic.List[PSCustomObject]]::new()
$details = [System.Collections.Generic.List[PSCustomObject]]::new()
$totalHits = 0

foreach ($svc in $serviceDirs) {
    $hits = [System.Collections.Generic.List[string]]::new()
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if ($rgCmd) {
        $rgArgs = @("--no-heading", "--line-number", "--with-filename", "--color", "never")
        if (-not $Regex) { $rgArgs += "--fixed-strings" }
        if (-not $CaseSensitive) { $rgArgs += "--ignore-case" }
        foreach ($skip in $SkipDirs) {
            $rgArgs += @("--glob", "!$skip/**")
        }
        if ($Include) {
            $rgArgs += @("--glob", $Include)
        }
        $rgArgs += @($Pattern, ".")

        Push-Location $svc.FullName
        try {
            $rgOut = & $rgCmd.Source @rgArgs 2>$null
            foreach ($line in $rgOut) {
                $s = "$line".Trim()
                if (-not $s) { continue }
                if ($s -match "^\.?[\\/](.+?):(\d+):(.*)$") {
                    [void]$files.Add($Matches[1])
                    $snippet = $Matches[3].Trim()
                    if ($snippet.Length -gt 140) { $snippet = $snippet.Substring(0, 140) + "..." }
                    if ($hits.Count -lt $MaxMatchesPerService) {
                        $hits.Add("$($Matches[1]):$($Matches[2]): $snippet")
                    }
                }
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        $skipPattern = "([\\/])(" + (($SkipDirs | ForEach-Object { [regex]::Escape($_) }) -join "|") + ")([\\/]|$)"
        $gciParams = @{ Path = $svc.FullName; Recurse = $true; File = $true }
        if ($Include) { $gciParams["Filter"] = $Include }

        $targetFiles = Get-ChildItem @gciParams | Where-Object { $_.FullName -notmatch $skipPattern }
        foreach ($f in $targetFiles) {
            $ssParams = @{ Path = $f.FullName; Pattern = $Pattern }
            if (-not $Regex) { $ssParams["SimpleMatch"] = $true }
            if ($CaseSensitive) { $ssParams["CaseSensitive"] = $true }

            $matchesFound = Select-String @ssParams
            foreach ($m in $matchesFound) {
                $relPath = $f.FullName.Substring($svc.FullName.Length).TrimStart('\', '/')
                [void]$files.Add($relPath)
                $snippet = $m.Line.Trim()
                if ($snippet.Length -gt 140) { $snippet = $snippet.Substring(0, 140) + "..." }
                if ($hits.Count -lt $MaxMatchesPerService) {
                    $hits.Add("$relPath`:$($m.LineNumber): $snippet")
                }
            }
        }
    }

    if ($hits.Count -gt 0) {
        $totalHits += $hits.Count
        $summaryRows.Add([PSCustomObject]@{
            Service = $svc.Name
            Matches = $hits.Count
            Files   = $files.Count
        })
        $details.Add([PSCustomObject]@{
            Service = $svc.Name
            Hits    = $hits
        })
    }
}

if ($Console) {
    foreach ($r in $summaryRows) {
        Write-Output "$($r.Service): $($r.Matches) matches in $($r.Files) files"
    }
    if ($summaryRows.Count -eq 0) {
        Write-Output "No matches found across $($serviceDirs.Count) services."
    }
    exit 0
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Workspace Search Report")
$lines.Add("")
$lines.Add("Generated: $timestamp | Pattern: ``$Pattern`` | Scanned: $($serviceDirs.Count) | Matched: $($summaryRows.Count) | Total hits: $totalHits")
$lines.Add("")
$lines.Add("| Service | Matches | Files |")
$lines.Add("| --- | --- | --- |")

foreach ($r in $summaryRows) {
    $lines.Add("| ``$($r.Service)`` | $($r.Matches) | $($r.Files) |")
}

if ($details.Count -gt 0) {
    $lines.Add("")
    $lines.Add("## Matches by Service")
    foreach ($d in $details) {
        $lines.Add("")
        $lines.Add("### $($d.Service)")
        $lines.Add("")
        $lines.Add('```text')
        foreach ($h in $d.Hits) {
            $lines.Add($h)
        }
        $lines.Add('```')
    }
}

$outFullPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path (Get-Location).Path $OutFile }
$outDir = Split-Path -Path $outFullPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$lines | Set-Content -Path $outFullPath -Encoding UTF8

Write-Output "Search report written to $outFullPath ($($serviceDirs.Count) services scanned: $($summaryRows.Count) matched, $totalHits total hits)"
