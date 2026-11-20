<#
.SYNOPSIS
    Safely runs `git pull --ff-only` across one, N, or all repositories in a workspace.
.DESCRIPTION
    Scans Git repositories under -Path (filtered by -Services or an optional -ReportFile),
    checks upstream tracking, ahead/behind counts, and dirty state.
    Only fast-forwards clean repositories (unless -Stash is passed) that are behind upstream.
    Writes a Markdown summary to -OutFile (default: pull-report.md).
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string[]]$Services = @(),
    [string]$ReportFile = "",
    [switch]$Stash,
    [switch]$DryRun,
    [string]$OutFile = "pull-report.md",
    [switch]$Console,
    [int]$Depth = 1
)

$ErrorActionPreference = "SilentlyContinue"

function Find-GitRepos {
    param(
        [string]$RootPath,
        [string[]]$FilterServices,
        [int]$MaxDepth
    )

    $resolved = (Resolve-Path -Path $RootPath -ErrorAction Stop).Path
    $repos = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()

    if ((Test-Path (Join-Path $resolved ".git")) -and $FilterServices.Count -eq 0) {
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
            if (Test-Path (Join-Path $child.FullName ".git")) {
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

function Read-ReportServices {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) {
        throw "Report file not found: $FilePath"
    }
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content -Path $FilePath -Encoding UTF8)) {
        if ($line -notmatch "^\|") { continue }
        if ($line -match "^\|\s*Service\s*\|" -or $line -match "^\|\s*---") { continue }
        $cells = $line.Trim().Trim("|") -split "\|"
        if ($cells.Count -ge 1) {
            $svc = ($cells[0].Trim() -replace '`', '')
            if ($svc) { $list.Add($svc) }
        }
    }
    return $list
}

$filterList = [System.Collections.Generic.List[string]]::new()
foreach ($s in $Services) {
    if ($s -and $s.Trim()) { $filterList.Add($s.Trim()) }
}
if ($ReportFile) {
    foreach ($s in (Read-ReportServices -FilePath $ReportFile)) {
        $filterList.Add($s)
    }
}

$repos = Find-GitRepos -RootPath $Path -FilterServices $filterList.ToArray() -MaxDepth $Depth
if ($repos.Count -eq 0) {
    Write-Output "No Git repositories found."
    exit 0
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($repo in $repos) {
    $repoPath = $repo.FullName
    $branch = (& git -C $repoPath branch --show-current 2>$null | Out-String).Trim()
    if (-not $branch) {
        $results.Add([PSCustomObject]@{ Service = $repo.Name; Branch = "detached"; Behind = 0; Ahead = 0; Status = "Skipped (detached HEAD)" })
        continue
    }

    $upstream = (& git -C $repoPath rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $upstream) {
        $results.Add([PSCustomObject]@{ Service = $repo.Name; Branch = $branch; Behind = 0; Ahead = 0; Status = "Skipped (no upstream)" })
        continue
    }

    $fetchOut = & git -C $repoPath fetch --quiet 2>&1
    if ($LASTEXITCODE -ne 0) {
        $err = ($fetchOut | Out-String).Trim() -replace "\r?\n", " "
        $results.Add([PSCustomObject]@{ Service = $repo.Name; Branch = $branch; Behind = 0; Ahead = 0; Status = "Error (fetch): $err" })
        continue
    }

    $countsRaw = (& git -C $repoPath rev-list --left-right --count "HEAD...@{u}" 2>$null | Out-String).Trim()
    $parts = $countsRaw -split "\s+"
    $ahead = if ($parts.Count -ge 1 -and $parts[0] -match "^\d+$") { [int]$parts[0] } else { 0 }
    $behind = if ($parts.Count -ge 2 -and $parts[1] -match "^\d+$") { [int]$parts[1] } else { 0 }

    $dirty = (& git -C $repoPath status --porcelain 2>$null | Out-String).Trim()
    $isDirty = -not [string]::IsNullOrWhiteSpace($dirty)

    if ($behind -eq 0) {
        $st = if ($ahead -gt 0) { "Up to date (ahead:$ahead)" } else { "Up to date" }
        $results.Add([PSCustomObject]@{ Service = $repo.Name; Branch = $branch; Behind = 0; Ahead = $ahead; Status = $st })
        continue
    }

    if ($ahead -gt 0) {
        $results.Add([PSCustomObject]@{ Service = $repo.Name; Branch = $branch; Behind = $behind; Ahead = $ahead; Status = "Skipped (diverged: +$ahead/-$behind)" })
        continue
    }

    if ($isDirty -and -not $Stash) {
        $results.Add([PSCustomObject]@{ Service = $repo.Name; Branch = $branch; Behind = $behind; Ahead = 0; Status = "Skipped (dirty)" })
        continue
    }

    if ($DryRun) {
        $note = if ($isDirty -and $Stash) { "Would pull +$behind (with stash)" } else { "Would pull +$behind" }
        $results.Add([PSCustomObject]@{ Service = $repo.Name; Branch = $branch; Behind = $behind; Ahead = 0; Status = $note })
        continue
    }

    if ($isDirty -and $Stash) {
        $stashOut = & git -C $repoPath stash push -u -m "pull-repos" 2>&1
        if ($LASTEXITCODE -ne 0) {
            $err = ($stashOut | Out-String).Trim() -replace "\r?\n", " "
            $results.Add([PSCustomObject]@{ Service = $repo.Name; Branch = $branch; Behind = $behind; Ahead = 0; Status = "Error (stash): $err" })
            continue
        }
    }

    $pullOut = & git -C $repoPath pull --ff-only --quiet 2>&1
    if ($LASTEXITCODE -ne 0) {
        $err = ($pullOut | Out-String).Trim() -replace "\r?\n", " "
        $results.Add([PSCustomObject]@{ Service = $repo.Name; Branch = $branch; Behind = $behind; Ahead = 0; Status = "Error (pull): $err" })
    }
    else {
        $results.Add([PSCustomObject]@{ Service = $repo.Name; Branch = $branch; Behind = $behind; Ahead = 0; Status = "Updated (+$behind)" })
    }
}

$updatedCount = @($results | Where-Object { $_.Status -like "Updated*" -or $_.Status -like "Would pull*" }).Count
$skippedCount = @($results | Where-Object { $_.Status -like "Skipped*" }).Count
$errorCount = @($results | Where-Object { $_.Status -like "Error*" }).Count

if ($Console) {
    foreach ($r in $results) {
        Write-Output "$($r.Service) ($($r.Branch)): behind=$($r.Behind) ahead=$($r.Ahead) [$($r.Status)]"
    }
    exit $(if ($errorCount -gt 0) { 1 } else { 0 })
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$modeLabel = if ($DryRun) { "DryRun" } else { "Executed" }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Git Pull Report ($modeLabel)")
$lines.Add("")
$lines.Add("Generated: $timestamp | Repositories: $($results.Count) | Updated: $updatedCount | Skipped: $skippedCount | Errors: $errorCount")
$lines.Add("")
$lines.Add("| Service | Branch | Behind | Ahead | Status |")
$lines.Add("| --- | --- | --- | --- | --- |")

foreach ($r in $results) {
    $safeStatus = $r.Status -replace '\|', ' '
    $lines.Add("| ``$($r.Service)`` | ``$($r.Branch)`` | $($r.Behind) | $($r.Ahead) | $safeStatus |")
}

$outFullPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path (Get-Location).Path $OutFile }
$outDir = Split-Path -Path $outFullPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$lines | Set-Content -Path $outFullPath -Encoding UTF8

Write-Output "Pull report ($modeLabel) written to $outFullPath ($($results.Count) repos: $updatedCount updated, $skippedCount skipped, $errorCount errors)"
