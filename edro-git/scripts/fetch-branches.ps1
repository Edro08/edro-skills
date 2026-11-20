<#
.SYNOPSIS
    Runs git fetch across one or more service repositories and generates a Markdown branch report.
.DESCRIPTION
    Fetches all remotes with --prune --quiet for matching Git repositories under -Path,
    classifies their branches (Current, Main/Master, Intermediate, Tasks, Other), and writes
    a Markdown table to -OutFile (default: branches-report.md) so the agent only reads a
    single-line summary. Use -Console to print to stdout instead.
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string[]]$Services = @(),
    [string]$OutFile = "branches-report.md",
    [switch]$NoFetch,
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

function Get-RepoBranchSummary {
    param(
        [System.IO.DirectoryInfo]$RepoDir,
        [bool]$SkipFetch
    )

    $repoPath = $RepoDir.FullName
    $fetchError = $null

    if (-not $SkipFetch) {
        $fetchOut = & git -C $repoPath fetch --all --prune --quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            $fetchError = ($fetchOut | Out-String).Trim() -replace "\r?\n", " "
        }
    }

    $current = (& git -C $repoPath branch --show-current 2>$null | Out-String).Trim()
    if (-not $current) {
        $sha = (& git -C $repoPath rev-parse --short HEAD 2>$null | Out-String).Trim()
        $current = if ($sha) { "detached@$sha" } else { "(unknown)" }
    }

    $rawBranches = & git -C $repoPath branch -a --format="%(refname:short)" 2>$null
    $unique = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($raw in $rawBranches) {
        $b = $raw.Trim()
        if (-not $b -or $b -eq "origin/HEAD" -or $b -like "*->*" -or $b -eq "origin") { continue }
        if ($b -match "^origin/(.+)$") {
            $b = $Matches[1]
        }
        [void]$unique.Add($b)
    }

    $base = [System.Collections.Generic.List[string]]::new()
    $intermediate = [System.Collections.Generic.List[string]]::new()
    $tasks = [System.Collections.Generic.List[string]]::new()
    $other = [System.Collections.Generic.List[string]]::new()

    foreach ($b in ($unique | Sort-Object)) {
        if ($b -match "^(main|master)$") {
            $base.Add($b)
        }
        elseif ($b -match "^(sprint|release)([/_-]|\d|$)" -or $b -match "^(develop|dev|staging|qa|uat|preprod)$") {
            $intermediate.Add($b)
        }
        elseif ($b -match "^(feat|feature|fix|bug|bugfix|hotfix|task|chore)[/_-]" -or $b -match "^TASK[_-]") {
            $tasks.Add($b)
        }
        else {
            $other.Add($b)
        }
    }

    return [PSCustomObject]@{
        Name         = $RepoDir.Name
        Current      = $current
        Base         = $base
        Intermediate = $intermediate
        Tasks        = $tasks
        Other        = $other
        FetchError   = $fetchError
    }
}

function Format-BranchCell {
    param([System.Collections.Generic.List[string]]$Items)
    if (-not $Items -or $Items.Count -eq 0) { return "-" }
    return (($Items | ForEach-Object { "``$_``" }) -join ", ")
}

$repos = Find-GitRepos -RootPath $Path -FilterServices $Services -MaxDepth $Depth
if ($repos.Count -eq 0) {
    Write-Output "No Git repositories found."
    exit 0
}

$summaries = foreach ($repo in $repos) {
    Get-RepoBranchSummary -RepoDir $repo -SkipFetch:$NoFetch.IsPresent
}

$errorCount = @($summaries | Where-Object { $_.FetchError }).Count

if ($Console) {
    foreach ($s in $summaries) {
        Write-Output "[$($s.Name)]"
        Write-Output "  Current:      $($s.Current)"
        Write-Output "  Main/Master:  $(if ($s.Base.Count -gt 0) { $s.Base -join ', ' } else { '(none)' })"
        Write-Output "  Intermediate: $(if ($s.Intermediate.Count -gt 0) { $s.Intermediate -join ', ' } else { '(none)' })"
        Write-Output "  Tasks:        $(if ($s.Tasks.Count -gt 0) { $s.Tasks -join ', ' } else { '(none)' })"
        if ($s.Other.Count -gt 0) {
            Write-Output "  Other:        $($s.Other -join ', ')"
        }
        if ($s.FetchError) {
            Write-Output "  FetchError:   $($s.FetchError)"
        }
    }
    exit 0
}

$lines = [System.Collections.Generic.List[string]]::new()
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines.Add("# Git Branches Report")
$lines.Add("")
$lines.Add("Generated: $timestamp | Repositories: $($summaries.Count) | Fetch errors: $errorCount")
$lines.Add("")
$lines.Add("| Service | Current | Main/Master | Intermediate | Tasks | Other | Status |")
$lines.Add("| --- | --- | --- | --- | --- | --- | --- |")

foreach ($s in $summaries) {
    $status = if ($s.FetchError) { "Error: $($s.FetchError -replace '\|', ' ')" } else { "OK" }
    $row = "| ``$($s.Name)`` | ``$($s.Current)`` | $(Format-BranchCell $s.Base) | $(Format-BranchCell $s.Intermediate) | $(Format-BranchCell $s.Tasks) | $(Format-BranchCell $s.Other) | $status |"
    $lines.Add($row)
}

$outFullPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path (Get-Location).Path $OutFile }
$outDir = Split-Path -Path $outFullPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$lines | Set-Content -Path $outFullPath -Encoding UTF8

Write-Output "Report written to $outFullPath ($($summaries.Count) repos, $errorCount fetch errors)"
