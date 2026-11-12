<#
.SYNOPSIS
    Audits a repository for hardcoded host paths or non-portable file:// URIs.

.DESCRIPTION
    Scans text files under the target repository root for absolute host paths
    (e.g., Windows drive paths, /home/<user>/, /Users/<user>/, or file:/// URIs)
    while ignoring common VCS, dependency, and build output directories.
    Lines containing "portability-ignore" are skipped.

.PARAMETER Root
    Target directory to scan. Defaults to the current working directory.

.EXAMPLE
    .\audit-paths.ps1
    .\audit-paths.ps1 -Root .
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Write-Error "Target root directory does not exist: $Root"
    exit 2
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path

$excludedDirs = @(
    '.git', 'node_modules', 'dist', 'bin', 'obj', 'build',
    'target', '.gradle', '.idea', '.vs', '.venv', 'venv',
    '__pycache__', 'vendor', 'coverage'
)
$excludedRegex = '[\\/]+(' + (($excludedDirs | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')([\\/]+|$)'

$binaryExtensions = @(
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.svg',
    '.pdf', '.zip', '.tar', '.gz', '.7z', '.exe', '.dll',
    '.so', '.dylib', '.jar', '.apk', '.aab', '.woff', '.woff2',
    '.ttf', '.eot', '.mp3', '.mp4', '.mov', '.db', '.sqlite'
)

$patterns = @(
    '(?i)\b[A-Za-z]:[\\/]+(Users|Projects|home|Documents|Desktop|Downloads|OneDrive|Repos|Workspace|dev)\b',
    '(?i)file:///[A-Za-z]:',
    '(?i)file:///(home|Users)/',
    '(?<![A-Za-z0-9_])/(home|Users)/[A-Za-z0-9_.-]+/'
)

$violations = [System.Collections.Generic.List[string]]::new()

$files = Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch $excludedRegex -and
        $binaryExtensions -notcontains $_.Extension.ToLowerInvariant()
    }

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/')
    $lineNumber = 0

    try {
        $lines = [System.IO.File]::ReadLines($file.FullName)
        foreach ($line in $lines) {
            $lineNumber++
            if ($line -match 'portability-ignore') {
                continue
            }

            foreach ($pattern in $patterns) {
                if ($line -match $pattern) {
                    $trimmed = $line.Trim()
                    if ($trimmed.Length -gt 140) {
                        $trimmed = $trimmed.Substring(0, 140) + '...'
                    }
                    $violations.Add("${relativePath}:${lineNumber}: $trimmed")
                    break
                }
            }
        }
    }
    catch {
        # Skip unreadable or locked files gracefully
        continue
    }
}

if ($violations.Count -gt 0) {
    Write-Host "FAIL: Found $($violations.Count) potential non-portable path(s):" -ForegroundColor Red
    foreach ($v in $violations) {
        Write-Host "  - $v"
    }
    exit 1
}

Write-Host "PASS: No hardcoded host paths detected under '$resolvedRoot'." -ForegroundColor Green
exit 0
