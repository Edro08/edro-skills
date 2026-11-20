<#
.SYNOPSIS
    Safely switches branches across multiple service repositories based on branches-report.md or a target rule.
.DESCRIPTION
    Reads target branches from -ReportFile (default: branches-report.md, using the Current column),
    or uses -TargetMain / -Branch across matching repositories under -Path.
    Skips repositories with uncommitted changes unless -Stash is specified.
    Writes a compact Markdown summary to -OutFile (default: switch-report.md).
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string]$ReportFile = "branches-report.md",
    [string[]]$Services = @(),
    [string]$Branch = "",
    [switch]$TargetMain,
    [switch]$Pull,
    [switch]$Stash,
    [switch]$DryRun,
    [string]$OutFile = "switch-report.md",
    [switch]$Console,
    [int]$Depth = 1
)

$ErrorActionPreference = "SilentlyContinue"

function Find-GitRepoMap {
    param(
        [string]$RootPath,
        [int]$MaxDepth
    )

    $resolved = (Resolve-Path -Path $RootPath -ErrorAction Stop).Path
    $map = @{}

    if (Test-Path (Join-Path $resolved ".git")) {
        $dir = Get-Item -Path $resolved
        $map[$dir.Name.ToLowerInvariant()] = $dir
        return $map
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
                $map[$child.Name.ToLowerInvariant()] = $child
            }
            elseif ($level + 1 -lt $MaxDepth) {
                $queue.Enqueue(@{ Dir = $child; Level = $level + 1 })
            }
        }
    }

    return $map
}

function Read-BranchesReport {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        throw "Report file not found: $FilePath"
    }

    $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
    $lines = Get-Content -Path $FilePath -Encoding UTF8

    foreach ($line in $lines) {
        if ($line -notmatch "^\|") { continue }
        if ($line -match "^\|\s*Service\s*\|" -or $line -match "^\|\s*---") { continue }

        $cells = $line.Trim().Trim("|") -split "\|"
        if ($cells.Count -lt 3) { continue }

        $svc = ($cells[0].Trim() -replace '`', '')
        $current = ($cells[1].Trim() -replace '`', '')
        $mainCol = ($cells[2].Trim() -replace '`', '')

        if ($svc) {
            $rows.Add([PSCustomObject]@{
                Service = $svc
                Target  = $current
                MainCol = $mainCol
            })
        }
    }

    return $rows
}

function Resolve-MainBranch {
    param(
        [string]$RepoPath,
        [string]$MainHint
    )

    if ($MainHint -and $MainHint -ne "-") {
        $first = ($MainHint -split ",")[0].Trim()
        if ($first) { return $first }
    }

    foreach ($candidate in @("main", "master")) {
        & git -C $RepoPath show-ref --verify --quiet "refs/heads/$candidate" 2>$null
        if ($LASTEXITCODE -eq 0) { return $candidate }
        & git -C $RepoPath show-ref --verify --quiet "refs/remotes/origin/$candidate" 2>$null
        if ($LASTEXITCODE -eq 0) { return $candidate }
    }

    return $null
}

$repoMap = Find-GitRepoMap -RootPath $Path -MaxDepth $Depth
$filterSet = @($Services | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })

$plan = [System.Collections.Generic.List[PSCustomObject]]::new()

if ($Branch) {
    foreach ($key in ($repoMap.Keys | Sort-Object)) {
        if ($filterSet.Count -gt 0 -and ($filterSet -notcontains $key)) { continue }
        $repo = $repoMap[$key]
        $plan.Add([PSCustomObject]@{ Service = $repo.Name; Repo = $repo; Target = $Branch })
    }
}
elseif ($TargetMain) {
    $reportHints = @{}
    if (Test-Path $ReportFile) {
        foreach ($r in (Read-BranchesReport -FilePath $ReportFile)) {
            $reportHints[$r.Service.ToLowerInvariant()] = $r.MainCol
        }
    }
    foreach ($key in ($repoMap.Keys | Sort-Object)) {
        if ($filterSet.Count -gt 0 -and ($filterSet -notcontains $key)) { continue }
        $repo = $repoMap[$key]
        $mainTarget = Resolve-MainBranch -RepoPath $repo.FullName -MainHint $reportHints[$key]
        $plan.Add([PSCustomObject]@{ Service = $repo.Name; Repo = $repo; Target = $mainTarget })
    }
}
else {
    $rows = Read-BranchesReport -FilePath $ReportFile
    foreach ($r in $rows) {
        $key = $r.Service.ToLowerInvariant()
        if ($filterSet.Count -gt 0 -and ($filterSet -notcontains $key)) { continue }
        $plan.Add([PSCustomObject]@{ Service = $r.Service; Repo = $repoMap[$key]; Target = $r.Target })
    }
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($item in $plan) {
    if (-not $item.Repo) {
        $results.Add([PSCustomObject]@{ Service = $item.Service; From = "-"; Target = $item.Target; Status = "Error: repo not found" })
        continue
    }

    $repoPath = $item.Repo.FullName
    $actual = (& git -C $repoPath branch --show-current 2>$null | Out-String).Trim()
    if (-not $actual) {
        $sha = (& git -C $repoPath rev-parse --short HEAD 2>$null | Out-String).Trim()
        $actual = if ($sha) { "detached@$sha" } else { "(unknown)" }
    }

    $target = $item.Target
    if (-not $target -or $target -eq "-" -or $target -eq "(unknown)") {
        $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = "-"; Status = "Error: no target branch" })
        continue
    }

    if ($actual -eq $target) {
        if ($Pull -and -not $DryRun) {
            $dirty = (& git -C $repoPath status --porcelain 2>$null | Out-String).Trim()
            if ($dirty) {
                $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = "Unchanged (dirty, pull skipped)" })
            }
            else {
                $pullOut = & git -C $repoPath pull --ff-only --quiet 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $err = ($pullOut | Out-String).Trim() -replace "\r?\n", " "
                    $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = "Error (pull): $err" })
                }
                else {
                    $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = "Unchanged (pulled)" })
                }
            }
        }
        else {
            $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = "Unchanged" })
        }
        continue
    }

    $dirty = (& git -C $repoPath status --porcelain 2>$null | Out-String).Trim()
    if ($dirty -and -not $Stash) {
        $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = "Skipped (dirty)" })
        continue
    }

    & git -C $repoPath show-ref --verify --quiet "refs/heads/$target" 2>$null
    $hasLocal = ($LASTEXITCODE -eq 0)
    & git -C $repoPath show-ref --verify --quiet "refs/remotes/origin/$target" 2>$null
    $hasRemote = ($LASTEXITCODE -eq 0)

    if (-not $hasLocal -and -not $hasRemote) {
        $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = "Error: branch not found" })
        continue
    }

    if ($DryRun) {
        $note = if ($dirty -and $Stash) { "Would switch (with stash)" } else { "Would switch" }
        $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = $note })
        continue
    }

    if ($dirty -and $Stash) {
        $stashOut = & git -C $repoPath stash push -u -m "switch-branches" 2>&1
        if ($LASTEXITCODE -ne 0) {
            $err = ($stashOut | Out-String).Trim() -replace "\r?\n", " "
            $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = "Error (stash): $err" })
            continue
        }
    }

    if ($hasLocal) {
        $swOut = & git -C $repoPath switch $target --quiet 2>&1
    }
    else {
        $swOut = & git -C $repoPath switch -c $target --track "origin/$target" --quiet 2>&1
    }

    if ($LASTEXITCODE -ne 0) {
        $err = ($swOut | Out-String).Trim() -replace "\r?\n", " "
        $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = "Error: $err" })
        continue
    }

    if ($Pull) {
        $pullOut = & git -C $repoPath pull --ff-only --quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            $err = ($pullOut | Out-String).Trim() -replace "\r?\n", " "
            $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = "Switched (pull error: $err)" })
            continue
        }
    }

    $results.Add([PSCustomObject]@{ Service = $item.Service; From = $actual; Target = $target; Status = "Switched" })
}

$switchedCount = @($results | Where-Object { $_.Status -like "Switched*" -or $_.Status -like "Would switch*" }).Count
$unchangedCount = @($results | Where-Object { $_.Status -like "Unchanged*" }).Count
$skippedCount = @($results | Where-Object { $_.Status -like "Skipped*" }).Count
$errorCount = @($results | Where-Object { $_.Status -like "Error*" }).Count

if ($Console) {
    foreach ($r in $results) {
        Write-Output "$($r.Service): $($r.From) -> $($r.Target) [$($r.Status)]"
    }
    exit 0
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$modeLabel = if ($DryRun) { "DryRun" } else { "Executed" }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Git Branch Switch Report ($modeLabel)")
$lines.Add("")
$lines.Add("Generated: $timestamp | Total: $($results.Count) | Switched: $switchedCount | Unchanged: $unchangedCount | Skipped: $skippedCount | Errors: $errorCount")
$lines.Add("")
$lines.Add("| Service | From | Target | Status |")
$lines.Add("| --- | --- | --- | --- |")

foreach ($r in $results) {
    $safeStatus = $r.Status -replace '\|', ' '
    $lines.Add("| ``$($r.Service)`` | ``$($r.From)`` | ``$($r.Target)`` | $safeStatus |")
}

$outFullPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path (Get-Location).Path $OutFile }
$outDir = Split-Path -Path $outFullPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$lines | Set-Content -Path $outFullPath -Encoding UTF8

Write-Output "Switch report written to $outFullPath ($($results.Count) repos: $switchedCount switched, $unchangedCount unchanged, $skippedCount skipped, $errorCount errors)"
