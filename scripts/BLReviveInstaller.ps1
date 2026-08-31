param(
    [string]$GameDirectory
)

$ErrorActionPreference = 'Stop'

$Version = '1.0.0'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackageDir = Split-Path -Parent $ScriptDir
$LauncherName = 'FoxGame-win32-Shipping_BE.exe'
$GameExeName = 'FoxGame-win32-Shipping.exe'
$CanonicalBackupName = 'FoxGame-win32-Shipping_BE.official-backup.exe'
$SupportDirName = 'BLReviveSteamPlayFix'

function Write-Step([string]$Text) {
    Write-Host ('[+] ' + $Text) -ForegroundColor Cyan
}

function Write-Warn([string]$Text) {
    Write-Host ('[!] ' + $Text) -ForegroundColor Yellow
}

function Request-WindowsShellIconRefresh([string]$Path) {
    try {
        if (-not ('BLRevive.ShellNativeMethods' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace BLRevive
{
    public static class ShellNativeMethods
    {
        [DllImport("shell32.dll", EntryPoint = "SHChangeNotify", CharSet = CharSet.Unicode, ExactSpelling = true)]
        public static extern void SHChangeNotifyPath(
            uint wEventId,
            uint uFlags,
            string dwItem1,
            IntPtr dwItem2);

        [DllImport("shell32.dll", EntryPoint = "SHChangeNotify", ExactSpelling = true)]
        public static extern void SHChangeNotifyIdList(
            uint wEventId,
            uint uFlags,
            IntPtr dwItem1,
            IntPtr dwItem2);
    }
}
'@
        }

        $SHCNE_UPDATEDIR = [uint32]0x00001000
        $SHCNE_UPDATEITEM = [uint32]0x00002000
        $SHCNE_ASSOCCHANGED = [uint32]0x08000000
        $SHCNF_IDLIST = [uint32]0x0000
        $SHCNF_PATHW = [uint32]0x0005
        $SHCNF_FLUSH = [uint32]0x1000
        $parent = Split-Path -Parent $Path

        # The file keeps Steam's fixed filename, so notify both the exact item
        # and its folder view. Association notification invalidates the Shell's
        # icon/thumbnail cache without deleting global cache files.
        [BLRevive.ShellNativeMethods]::SHChangeNotifyPath(
            $SHCNE_UPDATEITEM,
            ($SHCNF_PATHW -bor $SHCNF_FLUSH),
            $Path,
            [IntPtr]::Zero)
        [BLRevive.ShellNativeMethods]::SHChangeNotifyIdList(
            $SHCNE_ASSOCCHANGED,
            ($SHCNF_IDLIST -bor $SHCNF_FLUSH),
            [IntPtr]::Zero,
            [IntPtr]::Zero)
        [BLRevive.ShellNativeMethods]::SHChangeNotifyPath(
            $SHCNE_UPDATEDIR,
            ($SHCNF_PATHW -bor $SHCNF_FLUSH),
            $parent,
            [IntPtr]::Zero)

        return $true
    } catch {
        Write-Warn ('Windows shell icon refresh could not be requested: ' + $_.Exception.Message)
        Write-Warn 'The launcher is installed correctly; its icon may update after Explorer refreshes naturally.'
        return $false
    }
}

function Normalize-VdfPath([string]$Path) {
    if ([String]::IsNullOrWhiteSpace($Path)) { return $null }
    return $Path.Replace('\\', '\')
}

function Resolve-GameDirectory([string]$Path) {
    if ([String]::IsNullOrWhiteSpace($Path)) { return $null }

    $trimmed = $Path.Trim().Trim('"')
    if ([String]::IsNullOrWhiteSpace($trimmed)) { return $null }

    foreach ($candidate in @(
        $trimmed,
        (Join-Path $trimmed 'Binaries\Win32')
    )) {
        if (Test-Path -LiteralPath (Join-Path $candidate $GameExeName) -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Get-SteamRoots {
    $roots = New-Object System.Collections.Generic.List[string]

    try {
        $steamPath = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath
        if ($steamPath) { $roots.Add($steamPath) }
    } catch {}

    foreach ($fallback in @(
        "${env:ProgramFiles(x86)}\Steam",
        "$env:ProgramFiles\Steam"
    )) {
        if ($fallback -and (Test-Path $fallback)) { $roots.Add($fallback) }
    }

    return $roots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
}

function Get-SteamLibraries {
    $libraries = New-Object System.Collections.Generic.List[string]

    foreach ($steamRoot in Get-SteamRoots) {
        $libraries.Add($steamRoot)
        $vdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path $vdf)) { continue }

        $text = Get-Content -Raw -LiteralPath $vdf

        foreach ($m in [regex]::Matches($text, '"path"\s*"([^"]+)"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $p = Normalize-VdfPath $m.Groups[1].Value
            if ($p) { $libraries.Add($p) }
        }

        foreach ($m in [regex]::Matches($text, '^\s*"\d+"\s*"([A-Za-z]:\\[^"]+)"', ([Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Multiline))) {
            $p = Normalize-VdfPath $m.Groups[1].Value
            if ($p) { $libraries.Add($p) }
        }
    }

    return $libraries | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
}

function Find-BLRWin32Directories {
    $results = New-Object System.Collections.Generic.List[string]

    $local = Resolve-GameDirectory $PackageDir
    if ($local) { $results.Add($local) }

    foreach ($library in Get-SteamLibraries) {
        $candidate = Resolve-GameDirectory (Join-Path $library 'steamapps\common\blacklightretribution')
        if ($candidate) { $results.Add($candidate) }
    }

    return $results | Select-Object -Unique
}

function Select-GameDirectoryWithDialog {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the Blacklight: Retribution folder or its Binaries\Win32 folder.'
        $dialog.ShowNewFolderButton = $false

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return Resolve-GameDirectory $dialog.SelectedPath
        }
    } catch {
        Write-Warn ('Windows folder picker could not be opened: ' + $_.Exception.Message)
    }

    return $null
}

function Select-GameDirectory {
    if ($GameDirectory) {
        $explicit = Resolve-GameDirectory $GameDirectory
        if (-not $explicit) {
            throw "FoxGame-win32-Shipping.exe was not found under: $GameDirectory"
        }
        return $explicit
    }

    $dirs = @(Find-BLRWin32Directories)

    if ($dirs.Count -eq 1) { return $dirs[0] }

    if ($dirs.Count -gt 1) {
        Write-Host 'Multiple Blacklight: Retribution installations were found:'
        for ($i = 0; $i -lt $dirs.Count; $i++) {
            Write-Host ('  [{0}] {1}' -f ($i + 1), $dirs[$i])
        }

        while ($true) {
            $answer = Read-Host 'Choose installation number'
            $number = 0
            if ([Int32]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $dirs.Count) {
                return $dirs[$number - 1]
            }
        }
    }

    Write-Warn 'Blacklight: Retribution was not found automatically. Opening a folder picker.'
    $selected = Select-GameDirectoryWithDialog
    if ($selected) { return $selected }

    Write-Host 'Enter the Blacklight: Retribution folder or its Binaries\Win32 folder:'
    $manual = Resolve-GameDirectory (Read-Host 'Path')
    if (-not $manual) {
        throw 'FoxGame-win32-Shipping.exe was not found in the selected location.'
    }

    return $manual
}

function Get-ProductName([string]$Path) {
    try {
        return [Diagnostics.FileVersionInfo]::GetVersionInfo($Path).ProductName
    } catch {
        return $null
    }
}

Write-Host ("BLRevive Steam Play Fix " + $Version)
Write-Host '================================'
Write-Host ''

$GameDir = Select-GameDirectory
Write-Step "Blacklight installation: $GameDir"

$GameExe = Join-Path $GameDir $GameExeName
$TargetLauncher = Join-Path $GameDir $LauncherName
$BackupLauncher = Join-Path $GameDir $CanonicalBackupName
$SupportDir = Join-Path $GameDir $SupportDirName
$TargetConfig = Join-Path $GameDir 'BLReviveLauncher.ini'
$PayloadDir = Join-Path $PackageDir 'payload'
$PackageConfig = Join-Path $PayloadDir 'BLReviveLauncher.ini'
$PackagedLauncher = Join-Path $PayloadDir 'BLReviveSteamLauncher.exe'
$LauncherHashFile = Join-Path $PayloadDir 'BLReviveSteamLauncher.sha256'

foreach ($requiredFile in @($PackageConfig, $PackagedLauncher, $LauncherHashFile)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "The player payload is incomplete. Missing: $requiredFile"
    }
}

$expectedHash = ((Get-Content -Raw -LiteralPath $LauncherHashFile).Trim() -split '\s+')[0].ToUpperInvariant()
if ($expectedHash -notmatch '^[0-9A-F]{64}$') {
    throw 'The packaged launcher SHA-256 file is malformed.'
}

$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $PackagedLauncher).Hash.ToUpperInvariant()
if ($actualHash -ne $expectedHash) {
    throw 'The packaged launcher failed SHA-256 validation. Re-download the release before installing.'
}

$launcherInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($PackagedLauncher)
if ($launcherInfo.ProductName -ne 'BLRevive Steam Play Fix' -or $launcherInfo.FileVersion -ne '1.0.0.0') {
    throw 'The packaged launcher identity or version is incorrect.'
}


Write-Step "Validated prebuilt BLRevive launcher (SHA-256: $actualHash)"

# Recover one of the backup names used by earlier manual instructions if present.
if (-not (Test-Path $BackupLauncher)) {
    foreach ($legacyName in @(
        'FoxGame-win32-Shipping_BE.original.exe',
        'FoxGame-win32-Shipping_BE_original.exe',
        'FoxGame-win32-Shipping_BE.backup.exe',
        'FoxGame-win32-Shipping_BE.bak.exe'
    )) {
        $legacy = Join-Path $GameDir $legacyName
        if (Test-Path $legacy) {
            Write-Step "Found existing original launcher backup: $legacyName"
            Copy-Item -LiteralPath $legacy -Destination $BackupLauncher -Force
            break
        }
    }
}

if (Test-Path $TargetLauncher) {
    $product = Get-ProductName $TargetLauncher

    if ($product -eq 'BLRevive Steam Play Fix') {
        Write-Step 'An existing BLRevive Steam Play Fix launcher was detected; updating it.'
    }
    elseif (-not (Test-Path $BackupLauncher)) {
        Write-Step "Backing up the current Steam/BattlEye launcher as $CanonicalBackupName"
        Copy-Item -LiteralPath $TargetLauncher -Destination $BackupLauncher -Force
    }
    else {
        Write-Step 'Original launcher backup already exists; preserving it.'
    }
}
else {
    Write-Warn 'Steam BattlEye launcher is missing. Installing the wrapper anyway.'
    Write-Warn 'Steam Verify Integrity can restore the official launcher if required.'
}

if (Test-Path $BackupLauncher) {
    $backupProduct = Get-ProductName $BackupLauncher
    if ($backupProduct -eq 'BLRevive Steam Play Fix') {
        Write-Warn 'The canonical backup appears to be a BLRevive wrapper rather than the original Steam launcher.'
        Write-Warn 'Uninstall will still remove the wrapper, but Steam Verify Integrity may be needed to restore the official file.'
    }
}

Write-Step "Installing wrapper as $LauncherName"
Copy-Item -LiteralPath $PackagedLauncher -Destination $TargetLauncher -Force

if (-not (Test-Path $TargetConfig)) {
    Write-Step 'Installing BLReviveLauncher.ini'
    Copy-Item -LiteralPath $PackageConfig -Destination $TargetConfig -Force
} else {
    Write-Step 'Existing BLReviveLauncher.ini found; preserving your configured endpoint.'
}

Write-Step 'Installing uninstall and diagnostic support.'
New-Item -ItemType Directory -Path $SupportDir -Force | Out-Null
foreach ($file in @(
    @{ Source = 'Uninstall.bat'; Destination = 'Uninstall.bat' },
    @{ Source = 'scripts\BLReviveUninstaller.ps1'; Destination = 'BLReviveUninstaller.ps1' },
    @{ Source = 'Diagnose.bat'; Destination = 'Diagnose.bat' },
    @{ Source = 'scripts\BLReviveDiagnostics.ps1'; Destination = 'BLReviveDiagnostics.ps1' }
)) {
    Copy-Item -LiteralPath (Join-Path $PackageDir $file.Source) -Destination (Join-Path $SupportDir $file.Destination) -Force
}
Copy-Item -LiteralPath (Join-Path $PackageDir 'README.md') -Destination (Join-Path $SupportDir 'README.txt') -Force

$ShellIconRefreshRequested = Request-WindowsShellIconRefresh $TargetLauncher
if ($ShellIconRefreshRequested) {
    Write-Step 'Requested Windows shell icon refresh for the installed launcher.'
}

$installInfo = @(
    ('BLRevive Steam Play Fix ' + $Version),
    ('Installed=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')),
    ('GameDirectory=' + $GameDir),
    ('Wrapper=' + $TargetLauncher),
    ('Backup=' + $BackupLauncher),
    ('Config=' + $TargetConfig),
    ('RuntimeLog=' + (Join-Path $GameDir 'BLReviveSteamLauncher.log')),
    ('PayloadSHA256=' + $actualHash),

    ('IconMode=EmbeddedPrebuiltBLReviveLogo'),
    ('IconSource=' + $PackagedLauncher),
    ('IconEmbedded=True'),
    ('ShellIconRefreshRequested=' + $(if ($ShellIconRefreshRequested) { 'True' } else { 'False' }))
)
$installInfo | Set-Content -LiteralPath (Join-Path $SupportDir 'install-info.txt') -Encoding UTF8

Write-Host ''
Write-Host 'SUCCESS' -ForegroundColor Green
Write-Host '-------'
Write-Host 'Steam Play will now launch FoxGame-win32-Shipping.exe through the BLRevive wrapper.'
Write-Host 'You do not need custom ZCure/Presence Steam Launch Options.'
Write-Host ''
Write-Host 'Launcher icon:'
Write-Host '  Embedded in the validated prebuilt BLRevive launcher.'
Write-Host ''
Write-Host 'Runtime diagnostic log:'
Write-Host ('  ' + (Join-Path $GameDir 'BLReviveSteamLauncher.log'))
Write-Host ''
Write-Host 'Endpoint configuration:'
Write-Host ('  ' + $TargetConfig)
Write-Host ''
Write-Host 'Uninstaller:'
Write-Host ('  ' + (Join-Path $SupportDir 'Uninstall.bat'))
Write-Host ''
exit 0
