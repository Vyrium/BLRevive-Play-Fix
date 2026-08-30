param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath
)

$ErrorActionPreference = 'Stop'

$resolvedArchive = (Resolve-Path -LiteralPath $ArchivePath).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('BLRevive Release Test ' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null

try {
    Expand-Archive -LiteralPath $resolvedArchive -DestinationPath $testRoot -Force
    $packages = @(Get-ChildItem -LiteralPath $testRoot -Directory)
    if ($packages.Count -ne 1) {
        throw 'Release archive must contain exactly one top-level package directory.'
    }
    $packageDir = $packages[0].FullName

    $rootRunnables = @(Get-ChildItem -LiteralPath $packageDir -File |
        Where-Object { $_.Extension -in @('.bat', '.cmd', '.com', '.exe', '.ps1') } |
        Select-Object -ExpandProperty Name |
        Sort-Object)
    $expectedRunnables = @(
        'Diagnose.bat',
        'Install BLRevive Steam Play Fix.bat',
        'Uninstall.bat'
    ) | Sort-Object
    if (@(Compare-Object $expectedRunnables $rootRunnables).Count -ne 0) {
        throw 'Release root does not contain exactly the three player entry points.'
    }

    foreach ($developerDir in @('src', 'resources', 'tools')) {
        if (Test-Path -LiteralPath (Join-Path $packageDir $developerDir)) {
            throw "Developer directory leaked into player release: $developerDir"
        }
    }

    $payloadDir = Join-Path $packageDir 'payload'
    $payloadLauncher = Join-Path $payloadDir 'BLReviveSteamLauncher.exe'
    $hashFile = Join-Path $payloadDir 'BLReviveSteamLauncher.sha256'
    $expectedHash = ((Get-Content -Raw -LiteralPath $hashFile).Trim() -split '\s+')[0]
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $payloadLauncher).Hash
    if ($actualHash -ne $expectedHash) {
        throw 'Payload hash validation failed after extracting the release archive.'
    }

    $gameDir = Join-Path $testRoot 'Fresh Blacklight Install (x86)\blacklightretribution\Binaries\Win32'
    New-Item -ItemType Directory -Path $gameDir -Force | Out-Null
    $official = Join-Path $env:WINDIR 'System32\notepad.exe'
    $officialHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $official).Hash
    Copy-Item -LiteralPath $official -Destination (Join-Path $gameDir 'FoxGame-win32-Shipping.exe')
    Copy-Item -LiteralPath $official -Destination (Join-Path $gameDir 'FoxGame-win32-Shipping_BE.exe')

    $originalPayloadBytes = [IO.File]::ReadAllBytes($payloadLauncher)
    [byte[]]$tamperedPayloadBytes = $originalPayloadBytes.Clone()
    $tamperedPayloadBytes[0] = $tamperedPayloadBytes[0] -bxor 1
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        [IO.File]::WriteAllBytes($payloadLauncher, $tamperedPayloadBytes)
        $ErrorActionPreference = 'Continue'
        $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $packageDir 'scripts\BLReviveInstaller.ps1') -GameDirectory $gameDir 2>&1
        $tamperExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorActionPreference
        [IO.File]::WriteAllBytes($payloadLauncher, $originalPayloadBytes)
    }
    if ($tamperExit -eq 0) {
        throw 'Installer accepted a launcher whose bytes did not match the release hash.'
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $packageDir 'scripts\BLReviveInstaller.ps1') -GameDirectory $gameDir
    $installExit = $LASTEXITCODE
    if ($installExit -ne 0) { throw "Install test failed with exit code $installExit." }

    $installedLauncher = Join-Path $gameDir 'FoxGame-win32-Shipping_BE.exe'
    $backupLauncher = Join-Path $gameDir 'FoxGame-win32-Shipping_BE.official-backup.exe'
    $supportDir = Join-Path $gameDir 'BLReviveSteamPlayFix'
    $installedInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($installedLauncher)
    if ($installedInfo.ProductName -ne 'BLRevive Steam Play Fix') {
        throw 'Installed launcher identity is incorrect.'
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $backupLauncher).Hash -ne $officialHash) {
        throw 'Install test did not preserve the official launcher correctly.'
    }

    $supportNames = @(Get-ChildItem -LiteralPath $supportDir -File | Select-Object -ExpandProperty Name | Sort-Object)
    $expectedSupport = @(
        'BLReviveDiagnostics.ps1',
        'BLReviveUninstaller.ps1',
        'Diagnose.bat',
        'install-info.txt',
        'README.txt',
        'Uninstall.bat'
    ) | Sort-Object
    if (@(Compare-Object $expectedSupport $supportNames).Count -ne 0) {
        throw 'Installed support payload is not the expected minimal set.'
    }

    $installInfo = Get-Content -Raw -LiteralPath (Join-Path $supportDir 'install-info.txt')
    if ($installInfo -notmatch ('PayloadSHA256=' + [regex]::Escape($actualHash))) {
        throw 'Install metadata does not record the validated payload hash.'
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $supportDir 'BLReviveDiagnostics.ps1')
    $diagnoseExit = $LASTEXITCODE
    if ($diagnoseExit -ne 0) { throw "Diagnostic test failed with exit code $diagnoseExit." }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $supportDir 'BLReviveUninstaller.ps1')
    $uninstallExit = $LASTEXITCODE
    if ($uninstallExit -ne 0) { throw "Uninstall test failed with exit code $uninstallExit." }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $installedLauncher).Hash -ne $officialHash) {
        throw 'Uninstall test did not restore the official launcher.'
    }

    [pscustomobject]@{
        Archive = $resolvedArchive
        RootEntryPoints = ($rootRunnables -join ', ')
        PayloadSHA256 = $actualHash.ToLowerInvariant()
        TamperedPayloadRejected = $true
        InstallExit = $installExit
        DiagnoseExit = $diagnoseExit
        UninstallExit = $uninstallExit
        OfficialLauncherRestored = $true
    } | Format-List

    Write-Host 'Release smoke test passed.' -ForegroundColor Green
} finally {
    $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot -ErrorAction SilentlyContinue).Path
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if ($resolvedTestRoot -and $resolvedTestRoot.StartsWith($tempBase + '\', [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
