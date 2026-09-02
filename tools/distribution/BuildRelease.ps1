param(
    [string]$Version = '1.1.0',
    [switch]$SkipTest,
    [switch]$KeepStaging
)

$ErrorActionPreference = 'Stop'

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$DistDir = Join-Path $RepositoryRoot 'dist'
$PackageName = 'BLRevive-Steam-Play-Fix-' + $Version
$StageDir = Join-Path $DistDir $PackageName
$ArchivePath = Join-Path $DistDir ($PackageName + '.zip')
$ChecksumsPath = Join-Path $DistDir 'SHA256SUMS.txt'
$BuildScript = Join-Path $RepositoryRoot 'tools\launcher\BuildLauncher.bat'
$BuiltLauncher = Join-Path $RepositoryRoot 'tools\launcher\BLReviveSteamLauncher.exe'
$PackagedIcon = Join-Path $RepositoryRoot 'resources\BLReviveSteamLauncher.ico'
$LauncherSource = Join-Path $RepositoryRoot 'src\BLReviveSteamLauncher.cs'

foreach ($requiredFile in @($BuildScript, $PackagedIcon, $LauncherSource)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Release input is missing: $requiredFile"
    }
}

$distFullPath = [IO.Path]::GetFullPath($DistDir)
$rootFullPath = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
if (-not $distFullPath.StartsWith($rootFullPath + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to clean a release directory outside the repository.'
}

if (Test-Path -LiteralPath $DistDir) {
    Remove-Item -LiteralPath $DistDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StageDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $StageDir 'payload') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $StageDir 'scripts') -Force | Out-Null

try {
    & $BuildScript $PackagedIcon
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $BuiltLauncher -PathType Leaf)) {
        throw "Launcher build failed with exit code $LASTEXITCODE."
    }

    $launcherInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($BuiltLauncher)
    if ($launcherInfo.ProductName -ne 'BLRevive Steam Play Fix' -or $launcherInfo.FileVersion -ne ($Version + '.0')) {
        throw 'Built launcher identity or version does not match the requested release.'
    }


    foreach ($name in @(
        'Install BLRevive Steam Play Fix.bat',
        'Uninstall.bat',
        'Diagnose.bat',
        'README.md',
        'CHANGELOG.md',
        'LICENSE'
    )) {
        Copy-Item -LiteralPath (Join-Path $RepositoryRoot $name) -Destination (Join-Path $StageDir $name) -Force
    }

    foreach ($name in @(
        'BLReviveInstaller.ps1',
        'BLReviveUninstaller.ps1',
        'BLReviveDiagnostics.ps1',
        'BLRevivePrerequisites.ps1'
    )) {
        Copy-Item -LiteralPath (Join-Path $RepositoryRoot ('scripts\' + $name)) -Destination (Join-Path $StageDir ('scripts\' + $name)) -Force
    }

    $payloadDir = Join-Path $StageDir 'payload'
    $payloadLauncher = Join-Path $payloadDir 'BLReviveSteamLauncher.exe'
    Copy-Item -LiteralPath $BuiltLauncher -Destination $payloadLauncher -Force
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'resources\BLReviveLauncher.ini') -Destination (Join-Path $payloadDir 'BLReviveLauncher.ini') -Force

    $launcherHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $payloadLauncher).Hash.ToLowerInvariant()
    ($launcherHash + '  BLReviveSteamLauncher.exe') |
        Set-Content -LiteralPath (Join-Path $payloadDir 'BLReviveSteamLauncher.sha256') -Encoding ASCII

    Compress-Archive -Path $StageDir -DestinationPath $ArchivePath -CompressionLevel Optimal -Force
    $archiveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ArchivePath).Hash.ToLowerInvariant()
    ($archiveHash + '  ' + (Split-Path -Leaf $ArchivePath)) |
        Set-Content -LiteralPath $ChecksumsPath -Encoding ASCII

    if (-not $SkipTest) {
        & (Join-Path $PSScriptRoot 'TestRelease.ps1') -ArchivePath $ArchivePath
        if ($LASTEXITCODE -ne 0) {
            throw "Release smoke test failed with exit code $LASTEXITCODE."
        }
    }

    Write-Host ''
    Write-Host 'Release package created successfully.' -ForegroundColor Green
    Write-Host ('Archive:  ' + $ArchivePath)
    Write-Host ('SHA-256:  ' + $archiveHash)
    Write-Host ('Checksums: ' + $ChecksumsPath)
} finally {
    Remove-Item -LiteralPath $BuiltLauncher -Force -ErrorAction SilentlyContinue
    if (-not $KeepStaging) {
        Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
