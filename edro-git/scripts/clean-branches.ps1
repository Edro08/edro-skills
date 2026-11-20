<#
.SYNOPSIS
    Cleans local Git branches whose remote tracking branch is [gone] across one or more repositories.
.DESCRIPTION
    Runs `git fetch --all --prune --quiet` (unless -NoFetch), detects local branches whose
    upstream is [gone] (excluding main, master, develop, and the current branch), and safely
    deletes them with `git branch -d` (use -DryRun to preview without deleting).
    Writes a Markdown summary to -OutFile (default: clean-branches-report.md).
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string[]]$Services = @(),
    [switch]$DryRun,
    [switch]$NoFetch,
    [string]$OutFile = "clean-branches-report.md",
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

$repos = Find-GitRepos -RootPath $Path -FilterServices $Services -MaxDepth $Depth
if ($repos.Count -eq 0) {
    Write-Output "No Git repositories found."
    exit 0
}

$protected = @("main", "master", "develop")
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($repo in $repos) {
    $repoPath = $repo.FullName
    $fetchErr = $null

    if (-not $NoFetch) {
        $fetchOut = & git -C $repoPath fetch --all --prune --quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            $fetchErr = ($fetchOut | Out-String).Trim() -replace "\r?\n", " "
        }
    }

    $current = (& git -C $repoPath branch --show-current 2>$null | Out-String).Trim()
    $refs = & git -C $repoPath for-each-ref --format="%(refname:short)|%(upstream:track)" refs/heads/ 2>$null

    $goneBranches = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $refs) {
        $parts = $line -split "\|", 2
        if ($parts.Count -lt 2) { continue }
        $branchName = $parts[0].Trim()
        $track = $parts[1].Trim()
        if ($track -eq "[gone]" -and ($protected -notcontains $branchName) -and ($branchName -ne $current)) {
            $goneBranches.Add($branchName)
        }
    }

    $deleted = [System.Collections.Generic.List[string]]::new()
    $skipped = [System.Collections.Generic.List[string]]::new()

    foreach ($b in $goneBranches) {
        if ($DryRun) {
            $deleted.Add($b)
        }
        else {
            & git -C $repoPath branch -d $b 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $deleted.Add($b)
            }
            else {
                $skipped.Add($b)
            }
        }
    }

    $status = if ($fetchErr) { "FetchError: $fetchErr" }
              elseif ($goneBranches.Count -eq 0) { "Clean" }
              elseif ($DryRun) { "Would delete ($($deleted.Count))" }
              elseif ($skipped.Count -gt 0 -and $deleted.Count -eq 0) { "Skipped (unmerged)" }
              elseif ($skipped.Count -gt 0) { "Partial ($($deleted.Count) deleted, $($skipped.Count) unmerged)" }
              else { "Cleaned ($($deleted.Count))" }

    $results.Add([PSCustomObject]@{
        Service = $repo.Name
        Gone    = $goneBranches.Count
        Deleted = if ($deleted.Count -gt 0) { ($deleted | ForEach-Object { "``$_``" }) -join ", " } else { "-" }
        Skipped = if ($skipped.Count -gt 0) { ($skipped | ForEach-Object { "``$_``" }) -join ", " } else { "-" }
        Status  = $status
    })
}

$totalGone = ($results | Measure-Object -Property Gone -Sum).Sum
$affectedRepos = @($results | Where-Object { $_.Gone -gt 0 }).Count

if ($Console) {
    foreach ($r in $results) {
        Write-Output "$($r.Service): gone=$($r.Gone) [$($r.Status)]"
    }
    exit 0
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$modeLabel = if ($DryRun) { "DryRun" } else { "Executed" }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Git Clean Branches Report ($modeLabel)")
$lines.Add("")
$lines.Add("Generated: $timestamp | Repositories: $($results.Count) | Repos with [gone]: $affectedRepos | Total [gone] branches: $totalGone")
$lines.Add("")
$lines.Add("| Service | [gone] | Deleted / Would Delete | Skipped (unmerged) | Status |")
$lines.Add("| --- | --- | --- | --- | --- |")

foreach ($r in $results) {
    $safeStatus = $r.Status -replace '\|', ' '
    $lines.Add("| ``$($r.Service)`` | $($r.Gone) | $($r.Deleted) | $($r.Skipped) | $safeStatus |")
}

$outFullPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path (Get-Location).Path $OutFile }
$outDir = Split-Path -Path $outFullPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$lines | Set-Content -Path $outFullPath -Encoding UTF8

Write-Output "Clean branches report ($modeLabel) written to $outFullPath ($($results.Count) repos, $totalGone [gone] branches)"
