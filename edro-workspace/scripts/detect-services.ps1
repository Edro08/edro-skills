<#
.SYNOPSIS
    Detects the primary technology stack for each project/service directory in a workspace.
.DESCRIPTION
    Scans immediate subdirectories (or up to -Depth) of -Path for common project manifest files
    and writes a Markdown table to -OutFile (default: services-report.md) to minimize token usage.
    Use -Console to print "<folder> - <stack>" lines directly to stdout instead.
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string]$OutFile = "services-report.md",
    [switch]$Console,
    [int]$Depth = 1
)

$ErrorActionPreference = "SilentlyContinue"

$SkipDirs = @(
    ".git", ".github", ".gitlab", ".vscode", ".idea", ".gemini",
    "node_modules", "vendor", "target", "dist", "build", "out", "bin", "obj", "__pycache__"
)

function Get-PackageJsonStack {
    param([string]$FilePath)
    try {
        $json = Get-Content -Path $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $deps = @{}
        if ($json.dependencies) {
            $json.dependencies.PSObject.Properties | ForEach-Object { $deps[$_.Name] = $true }
        }
        if ($json.devDependencies) {
            $json.devDependencies.PSObject.Properties | ForEach-Object { $deps[$_.Name] = $true }
        }

        if ($deps.ContainsKey("nuxt")) { return "Nuxt (Vue)" }
        if ($deps.ContainsKey("vue")) { return "Vue" }
        if ($deps.ContainsKey("next")) { return "Next.js (React)" }
        if ($deps.ContainsKey("react")) { return "React" }
        if ($deps.ContainsKey("@angular/core")) { return "Angular" }
        if ($deps.ContainsKey("svelte")) { return "Svelte" }
        if ($deps.ContainsKey("@nestjs/core")) { return "NestJS" }
        return "Node.js"
    }
    catch {
        return "Node.js"
    }
}

function Get-DirectoryStack {
    param([string]$DirPath)

    $stacks = [System.Collections.Generic.List[string]]::new()

    if (Test-Path (Join-Path $DirPath "go.mod")) {
        $stacks.Add("Go")
    }
    if ((Test-Path (Join-Path $DirPath "pom.xml")) -or
        (Test-Path (Join-Path $DirPath "build.gradle")) -or
        (Test-Path (Join-Path $DirPath "build.gradle.kts"))) {
        $stacks.Add("Java")
    }
    $pkgJson = Join-Path $DirPath "package.json"
    if (Test-Path $pkgJson) {
        $stacks.Add((Get-PackageJsonStack -FilePath $pkgJson))
    }
    if ((Test-Path (Join-Path $DirPath "pyproject.toml")) -or
        (Test-Path (Join-Path $DirPath "requirements.txt")) -or
        (Test-Path (Join-Path $DirPath "Pipfile")) -or
        (Test-Path (Join-Path $DirPath "setup.py"))) {
        $stacks.Add("Python")
    }
    if (Test-Path (Join-Path $DirPath "Cargo.toml")) {
        $stacks.Add("Rust")
    }
    if ((Get-ChildItem -Path $DirPath -Filter "*.csproj" -File -ErrorAction SilentlyContinue) -or
        (Get-ChildItem -Path $DirPath -Filter "*.sln" -File -ErrorAction SilentlyContinue)) {
        $stacks.Add(".NET")
    }
    if (Test-Path (Join-Path $DirPath "composer.json")) {
        $stacks.Add("PHP")
    }
    if (Test-Path (Join-Path $DirPath "Gemfile")) {
        $stacks.Add("Ruby")
    }

    if ($stacks.Count -eq 0) {
        return "Unknown"
    }
    return ($stacks -join ", ")
}

$root = Resolve-Path -Path $Path -ErrorAction Stop
$dirs = Get-ChildItem -Path $root -Directory | Where-Object {
    $_.Name -notin $SkipDirs -and -not $_.Name.StartsWith(".")
} | Sort-Object Name

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($dir in $dirs) {
    $stack = Get-DirectoryStack -DirPath $dir.FullName
    if ($stack -eq "Unknown" -and $Depth -gt 1) {
        $subDirs = Get-ChildItem -Path $dir.FullName -Directory | Where-Object {
            $_.Name -notin $SkipDirs -and -not $_.Name.StartsWith(".")
        } | Sort-Object Name
        $foundSub = $false
        foreach ($sub in $subDirs) {
            $subStack = Get-DirectoryStack -DirPath $sub.FullName
            if ($subStack -ne "Unknown") {
                $results.Add([PSCustomObject]@{ Service = "$($dir.Name)/$($sub.Name)"; Stack = $subStack })
                $foundSub = $true
            }
        }
        if (-not $foundSub) {
            $results.Add([PSCustomObject]@{ Service = $dir.Name; Stack = "Unknown" })
        }
    }
    else {
        $results.Add([PSCustomObject]@{ Service = $dir.Name; Stack = $stack })
    }
}

if ($Console) {
    foreach ($r in $results) {
        Write-Output "$($r.Service) - $($r.Stack)"
    }
    exit 0
}

$unknownCount = @($results | Where-Object { $_.Stack -eq "Unknown" }).Count
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Workspace Services Report")
$lines.Add("")
$lines.Add("Generated: $timestamp | Services: $($results.Count) | Unknown: $unknownCount")
$lines.Add("")
$lines.Add("| Service | Stack |")
$lines.Add("| --- | --- |")

foreach ($r in $results) {
    $lines.Add("| ``$($r.Service)`` | $($r.Stack) |")
}

$outFullPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path (Get-Location).Path $OutFile }
$outDir = Split-Path -Path $outFullPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$lines | Set-Content -Path $outFullPath -Encoding UTF8

Write-Output "Report written to $outFullPath ($($results.Count) services, $unknownCount unknown)"
