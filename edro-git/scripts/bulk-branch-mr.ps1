<#
.SYNOPSIS
    Creates remote branches and Draft MRs/PRs across multiple repositories, then fetches and switches locally.
.DESCRIPTION
    Reads source branches (X) from -ReportFile (default: branches-report.md, Current column),
    or uses -FromMain / -SourceBranch. Auto-detects GitLab (glab) vs GitHub (gh) from origin URL,
    creates branch -NewBranch (Y) from X, opens a Draft MR/PR (Y -> X), and switches local clean repos to Y.
    Writes a Markdown summary to -OutFile (default: bulk-mr-report.md).
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string]$ReportFile = "branches-report.md",
    [string[]]$Services = @(),
    [string]$NewBranch = "",
    [string]$Title = "",
    [string]$Description = "",
    [string]$SourceBranch = "",
    [switch]$FromMain,
    [string]$TargetBranch = "",
    [ValidateSet("auto", "gh", "glab")]
    [string]$Provider = "auto",
    [switch]$AllowEmptyCommit,
    [switch]$NoDraft,
    [switch]$NoSwitch,
    [switch]$DryRun,
    [string]$OutFile = "bulk-mr-report.md",
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
    $newColIndex = -1

    foreach ($line in $lines) {
        if ($line -notmatch "^\|") { continue }
        if ($line -match "^\|\s*Service\s*\|") {
            $headers = $line.Trim().Trim("|") -split "\|"
            for ($i = 0; $i -lt $headers.Count; $i++) {
                if ($headers[$i].Trim() -ieq "New") { $newColIndex = $i }
            }
            continue
        }
        if ($line -match "^\|\s*---") { continue }

        $cells = $line.Trim().Trim("|") -split "\|"
        if ($cells.Count -lt 3) { continue }

        $svc = ($cells[0].Trim() -replace '`', '')
        $current = ($cells[1].Trim() -replace '`', '')
        $mainCol = ($cells[2].Trim() -replace '`', '')
        $newCol = if ($newColIndex -ge 0 -and $newColIndex -lt $cells.Count) { ($cells[$newColIndex].Trim() -replace '`', '') } else { "" }

        if ($svc) {
            $rows.Add([PSCustomObject]@{
                Service = $svc
                Current = $current
                MainCol = $mainCol
                NewCol  = $newCol
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
        & git -C $RepoPath show-ref --verify --quiet "refs/remotes/origin/$candidate" 2>$null
        if ($LASTEXITCODE -eq 0) { return $candidate }
        & git -C $RepoPath show-ref --verify --quiet "refs/heads/$candidate" 2>$null
        if ($LASTEXITCODE -eq 0) { return $candidate }
    }

    return $null
}

function Resolve-RepoProvider {
    param(
        [string]$RepoPath,
        [string]$Override
    )

    if ($Override -ne "auto") { return $Override }
    $url = (& git -C $RepoPath remote get-url origin 2>$null | Out-String).Trim()
    if ($url -match "github\.com") { return "gh" }
    if ($url -match "gitlab") { return "glab" }
    return "unknown"
}

$repoMap = Find-GitRepoMap -RootPath $Path -MaxDepth $Depth
$filterSet = @($Services | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })

$plan = [System.Collections.Generic.List[PSCustomObject]]::new()

if ($SourceBranch -or $FromMain) {
    $reportHints = @{}
    $reportNewHints = @{}
    if (Test-Path $ReportFile) {
        foreach ($r in (Read-BranchesReport -FilePath $ReportFile)) {
            $reportHints[$r.Service.ToLowerInvariant()] = $r.MainCol
            $reportNewHints[$r.Service.ToLowerInvariant()] = $r.NewCol
        }
    }
    foreach ($key in ($repoMap.Keys | Sort-Object)) {
        if ($filterSet.Count -gt 0 -and ($filterSet -notcontains $key)) { continue }
        $repo = $repoMap[$key]
        $src = if ($SourceBranch) { $SourceBranch } else { Resolve-MainBranch -RepoPath $repo.FullName -MainHint $reportHints[$key] }
        $targetNew = if ($NewBranch) { $NewBranch } else { $reportNewHints[$key] }
        $plan.Add([PSCustomObject]@{ Service = $repo.Name; Repo = $repo; Source = $src; NewBranch = $targetNew })
    }
}
else {
    $rows = Read-BranchesReport -FilePath $ReportFile
    foreach ($r in $rows) {
        $key = $r.Service.ToLowerInvariant()
        if ($filterSet.Count -gt 0 -and ($filterSet -notcontains $key)) { continue }
        $targetNew = if ($NewBranch) { $NewBranch } else { $r.NewCol }
        $plan.Add([PSCustomObject]@{ Service = $r.Service; Repo = $repoMap[$key]; Source = $r.Current; NewBranch = $targetNew })
    }
}

$hasGh = [bool](Get-Command gh -ErrorAction SilentlyContinue)
$hasGlab = [bool](Get-Command glab -ErrorAction SilentlyContinue)

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($item in $plan) {
    $targetNewBranch = $item.NewBranch
    if (-not $targetNewBranch -or $targetNewBranch -eq "-") {
        $results.Add([PSCustomObject]@{ Service = $item.Service; Provider = "-"; Source = $item.Source; NewBranch = "-"; LocalSwitch = "-"; Url = "-"; Status = "Skipped (no New branch)" })
        continue
    }

    $mrTitle = if ($Title) { $Title } else { "$targetNewBranch`: automated branch" }
    if (-not $NoDraft -and $mrTitle -notmatch "^Draft:") {
        $mrTitle = "Draft: $mrTitle"
    }

    if (-not $item.Repo) {
        $results.Add([PSCustomObject]@{ Service = $item.Service; Provider = "-"; Source = $item.Source; NewBranch = $targetNewBranch; LocalSwitch = "-"; Url = "-"; Status = "Error: repo not found" })
        continue
    }

    $repoPath = $item.Repo.FullName
    $prov = Resolve-RepoProvider -RepoPath $repoPath -Override $Provider
    $src = $item.Source
    $mrTarget = if ($TargetBranch) { $TargetBranch } else { $src }

    if (-not $src -or $src -eq "-" -or $src -eq "(unknown)" -or $src -like "detached@*") {
        $results.Add([PSCustomObject]@{ Service = $item.Service; Provider = $prov; Source = $src; NewBranch = $targetNewBranch; LocalSwitch = "-"; Url = "-"; Status = "Error: invalid source branch" })
        continue
    }

    if ($prov -eq "unknown") {
        $results.Add([PSCustomObject]@{ Service = $item.Service; Provider = "unknown"; Source = $src; NewBranch = $targetNewBranch; LocalSwitch = "-"; Url = "-"; Status = "Error: unknown provider (pass -Provider)" })
        continue
    }

    if ($prov -eq "gh" -and -not $hasGh) {
        $results.Add([PSCustomObject]@{ Service = $item.Service; Provider = "gh"; Source = $src; NewBranch = $targetNewBranch; LocalSwitch = "-"; Url = "-"; Status = "Error: gh CLI not installed" })
        continue
    }
    if ($prov -eq "glab" -and -not $hasGlab) {
        $results.Add([PSCustomObject]@{ Service = $item.Service; Provider = "glab"; Source = $src; NewBranch = $targetNewBranch; LocalSwitch = "-"; Url = "-"; Status = "Error: glab CLI not installed" })
        continue
    }

    $dirty = (& git -C $repoPath status --porcelain 2>$null | Out-String).Trim()
    $isClean = [string]::IsNullOrWhiteSpace($dirty)

    if ($DryRun) {
        $swNote = if ($NoSwitch) { "NoSwitch" } elseif ($isClean) { "Would switch" } else { "Skip (dirty)" }
        $prNote = if ($prov -eq "gh" -and -not $AllowEmptyCommit) { "Would create branch (PR needs commit)" } else { "Would create branch + MR/PR" }
        $results.Add([PSCustomObject]@{ Service = $item.Service; Provider = $prov; Source = $src; NewBranch = $targetNewBranch; LocalSwitch = $swNote; Url = "-"; Status = $prNote })
        continue
    }

    $mrUrl = "-"
    $localSwitchStatus = "NoSwitch"
    $finalStatus = "OK"

    Push-Location $repoPath
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($prov -eq "glab") {
            # Create remote branch Y from X via GitLab API (no empty commit needed)
            $apiOut = & glab api "projects/:fullpath/repository/branches" -X POST -f "branch=$targetNewBranch" -f "ref=$src" 2>&1
            if ($LASTEXITCODE -ne 0) {
                $err = (($apiOut | ForEach-Object { "$_" }) -join " ") -replace "\r?\n", " "
                if ($err -notmatch "already exists") {
                    throw "Branch create failed: $err"
                }
            }

            $mrArgs = @("mr", "create", "--source-branch", $targetNewBranch, "--target-branch", $mrTarget, "--title", $mrTitle, "--yes")
            if ($Description) { $mrArgs += @("--description", $Description) }
            if (-not $NoDraft) { $mrArgs += "--draft" }

            $mrOut = & glab @mrArgs 2>&1
            $mrText = (($mrOut | ForEach-Object { "$_" }) -join "`n").Trim()
            if ($LASTEXITCODE -ne 0) {
                throw "MR create failed: $($mrText -replace '\r?\n', ' ')"
            }
            if ($mrText -match "(https?://\S+)") {
                $mrUrl = $Matches[1]
            }

            if (-not $NoSwitch) {
                if (-not $isClean) {
                    $localSwitchStatus = "Skipped (dirty)"
                }
                else {
                    & git fetch origin $targetNewBranch --quiet 2>&1 | Out-Null
                    & git show-ref --verify --quiet "refs/heads/$targetNewBranch" 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        & git switch $targetNewBranch --quiet 2>&1 | Out-Null
                    }
                    else {
                        & git switch -c $targetNewBranch --track "origin/$targetNewBranch" --quiet 2>&1 | Out-Null
                    }
                    $localSwitchStatus = if ($LASTEXITCODE -eq 0) { "Switched" } else { "Switch error" }
                }
            }
        }
        elseif ($prov -eq "gh") {
            & git fetch origin $src --quiet 2>&1 | Out-Null

            if ($AllowEmptyCommit) {
                if (-not $isClean) {
                    throw "Local repo is dirty (cannot create empty commit for GitHub PR)"
                }
                & git show-ref --verify --quiet "refs/heads/$targetNewBranch" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    & git switch $targetNewBranch --quiet 2>&1 | Out-Null
                }
                else {
                    & git switch -c $targetNewBranch --track "origin/$src" --quiet 2>&1 | Out-Null
                }
                if ($LASTEXITCODE -ne 0) { throw "Failed to create local branch $targetNewBranch from origin/$src" }

                & git commit --allow-empty -m "$targetNewBranch`: init draft PR" --quiet 2>&1 | Out-Null
                & git push -u origin $targetNewBranch --quiet 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Failed to push $targetNewBranch" }
                $localSwitchStatus = if ($NoSwitch) { "Created & pushed" } else { "Switched" }

                $prArgs = @("pr", "create", "--base", $mrTarget, "--head", $targetNewBranch, "--title", $mrTitle, "--body", $(if ($Description) { $Description } else { "Automated draft PR" }))
                if (-not $NoDraft) { $prArgs += "--draft" }

                $prOut = & gh @prArgs 2>&1
                $prText = (($prOut | ForEach-Object { "$_" }) -join "`n").Trim()
                if ($LASTEXITCODE -ne 0) {
                    throw "PR create failed: $($prText -replace '\r?\n', ' ')"
                }
                if ($prText -match "(https?://\S+)") {
                    $mrUrl = $Matches[1]
                }
            }
            else {
                & git push origin "refs/remotes/origin/${src}:refs/heads/${targetNewBranch}" --quiet 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Failed to push remote branch $targetNewBranch from origin/$src" }
                $finalStatus = "Branch created (PR needs commit)"

                if (-not $NoSwitch) {
                    if (-not $isClean) {
                        $localSwitchStatus = "Skipped (dirty)"
                    }
                    else {
                        & git fetch origin $targetNewBranch --quiet 2>&1 | Out-Null
                        & git switch -c $targetNewBranch --track "origin/$targetNewBranch" --quiet 2>&1 | Out-Null
                        $localSwitchStatus = if ($LASTEXITCODE -eq 0) { "Switched" } else { "Switch error" }
                    }
                }
            }
        }
    }
    catch {
        $finalStatus = "Error: $($_.Exception.Message)"
    }
    finally {
        $ErrorActionPreference = $prevEAP
        Pop-Location
    }

    $results.Add([PSCustomObject]@{
        Service     = $item.Service
        Provider    = $prov
        Source      = $src
        NewBranch   = $targetNewBranch
        LocalSwitch = $localSwitchStatus
        Url         = $mrUrl
        Status      = $finalStatus
    })
}

$errorCount = @($results | Where-Object { $_.Status -like "Error*" }).Count

if ($Console) {
    foreach ($r in $results) {
        Write-Output "$($r.Service) [$($r.Provider)]: $($r.Source) -> $($r.NewBranch) | switch=$($r.LocalSwitch) | $($r.Url) [$($r.Status)]"
    }
    exit $(if ($errorCount -gt 0) { 1 } else { 0 })
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$modeLabel = if ($DryRun) { "DryRun" } else { "Executed" }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Bulk Branch & MR/PR Report ($modeLabel)")
$lines.Add("")
$lines.Add("Generated: $timestamp | Repositories: $($results.Count) | Errors: $errorCount")
$lines.Add("")
$lines.Add("| Service | Provider | Source (X) | New Branch (Y) | Local Switch | MR/PR URL | Status |")
$lines.Add("| --- | --- | --- | --- | --- | --- | --- |")

foreach ($r in $results) {
    $safeStatus = $r.Status -replace '\|', ' '
    $lines.Add("| ``$($r.Service)`` | $($r.Provider) | ``$($r.Source)`` | ``$($r.NewBranch)`` | $($r.LocalSwitch) | $($r.Url) | $safeStatus |")
}

$outFullPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path (Get-Location).Path $OutFile }
$outDir = Split-Path -Path $outFullPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$lines | Set-Content -Path $outFullPath -Encoding UTF8

Write-Output "Bulk MR/PR report ($modeLabel) written to $outFullPath ($($results.Count) repos, $errorCount errors)"
