param(
    [string]$GameDirectory
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LauncherName = 'FoxGame-win32-Shipping_BE.exe'
$GameExeName = 'FoxGame-win32-Shipping.exe'
$BackupName = 'FoxGame-win32-Shipping_BE.official-backup.exe'
$WrapperProductName = 'BLRevive Steam Play Fix'
$UninstallLog = Join-Path $ScriptDir 'BLReviveSteamPlayFix-Uninstall.log'
$InstallInfoPath = Join-Path $ScriptDir 'install-info.txt'

function Write-Status([string]$Text, [ValidateSet('Info', 'Success', 'Warning')] [string]$Kind = 'Info') {
    $prefix = if ($Kind -eq 'Warning') { '[!]' } else { '[+]' }
    $color = if ($Kind -eq 'Warning') { 'Yellow' } elseif ($Kind -eq 'Success') { 'Green' } else { 'Cyan' }

    Write-Host ($prefix + ' ' + $Text) -ForegroundColor $color
    try {
        Add-Content -LiteralPath $UninstallLog -Encoding UTF8 -Value (
            '[{0}] {1} {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $prefix, $Text
        )
    } catch {
        # Logging is best-effort and must not prevent uninstall.
    }
}

function Get-ProductName([string]$Path) {
    try {
        return [Diagnostics.FileVersionInfo]::GetVersionInfo($Path).ProductName
    } catch {
        return $null
    }
}

function Test-UsableOfficialBackup([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }

    try {
        $item = Get-Item -LiteralPath $Path
        if ($item.Length -lt 2) { return $false }

        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try {
            if ($stream.ReadByte() -ne 0x4D -or $stream.ReadByte() -ne 0x5A) { return $false }
        } finally {
            $stream.Dispose()
        }

        return (Get-ProductName $Path) -ne $WrapperProductName
    } catch {
        return $false
    }
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

        # Notify the exact executable and its folder view, and synchronously
        # deliver documented association/icon-cache invalidation.
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
        Write-Status ('Windows shell icon refresh could not be requested: ' + $_.Exception.Message) 'Warning'
        Write-Status 'The launcher was handled successfully; its icon may update after Explorer refreshes naturally.' 'Warning'
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
        if ($fallback -and (Test-Path -LiteralPath $fallback)) { $roots.Add($fallback) }
    }

    return $roots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
}

function Get-SteamLibraries {
    $libraries = New-Object System.Collections.Generic.List[string]

    foreach ($steamRoot in Get-SteamRoots) {
        $libraries.Add($steamRoot)
        $vdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $vdf)) { continue }

        try {
            $text = Get-Content -Raw -LiteralPath $vdf

            foreach ($match in [regex]::Matches($text, '"path"\s*"([^"]+)"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                $path = Normalize-VdfPath $match.Groups[1].Value
                if ($path) { $libraries.Add($path) }
            }

            foreach ($match in [regex]::Matches($text, '^\s*"\d+"\s*"([A-Za-z]:\\[^"]+)"', ([Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Multiline))) {
                $path = Normalize-VdfPath $match.Groups[1].Value
                if ($path) { $libraries.Add($path) }
            }
        } catch {
            Write-Status ('Could not read Steam library list: ' + $vdf) 'Warning'
        }
    }

    return $libraries | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
}

function Find-SteamGameDirectories {
    $results = New-Object System.Collections.Generic.List[string]

    foreach ($library in Get-SteamLibraries) {
        $candidate = Resolve-GameDirectory (Join-Path $library 'steamapps\common\blacklightretribution')
        if ($candidate) { $results.Add($candidate) }
    }

    return $results | Select-Object -Unique
}

function Test-BLReviveInstallation([string]$Path) {
    $target = Join-Path $Path $LauncherName
    $support = Join-Path $Path 'BLReviveSteamPlayFix'
    $backup = Join-Path $Path $BackupName

    return ((Test-Path -LiteralPath $target -PathType Leaf) -and
            ((Get-ProductName $target) -eq $WrapperProductName)) -or
           (Test-Path -LiteralPath $support -PathType Container) -or
           (Test-Path -LiteralPath $backup -PathType Leaf)
}

function Select-DiscoveredGameDirectory([string[]]$Directories) {
    $unique = @($Directories | Where-Object { $_ } | Select-Object -Unique)
    if ($unique.Count -eq 0) { return $null }

    $withFix = @($unique | Where-Object { Test-BLReviveInstallation $_ })
    if ($withFix.Count -eq 1) { return $withFix[0] }
    if ($unique.Count -eq 1) { return $unique[0] }

    $choices = if ($withFix.Count -gt 1) { $withFix } else { $unique }
    Write-Host 'Multiple Blacklight: Retribution installations were found:'
    for ($i = 0; $i -lt $choices.Count; $i++) {
        Write-Host ('  [{0}] {1}' -f ($i + 1), $choices[$i])
    }

    while ($true) {
        $answer = Read-Host 'Choose installation number'
        $number = 0
        if ([Int32]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $choices.Count) {
            return $choices[$number - 1]
        }
    }
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
        Write-Status ('Windows folder picker could not be opened: ' + $_.Exception.Message) 'Warning'
    }

    return $null
}

function Find-GameDirectory {
    if ($GameDirectory) {
        $explicit = Resolve-GameDirectory $GameDirectory
        if (-not $explicit) {
            throw "FoxGame-win32-Shipping.exe was not found under: $GameDirectory"
        }
        return $explicit
    }

    # Installed copy normally lives under Binaries\Win32\BLReviveSteamPlayFix.
    $parent = Resolve-GameDirectory (Split-Path -Parent $ScriptDir)
    if ($parent) { return $parent }

    # Source package may have been extracted directly into Binaries\Win32.
    $local = Resolve-GameDirectory $ScriptDir
    if ($local) { return $local }

    $discovered = Select-DiscoveredGameDirectory @(Find-SteamGameDirectories)
    if ($discovered) {
        Write-Status ('Found Blacklight through Steam: ' + $discovered) 'Success'
        return $discovered
    }

    Write-Status 'Blacklight was not found automatically. Opening a folder picker.' 'Warning'
    $selected = Select-GameDirectoryWithDialog
    if ($selected) { return $selected }

    Write-Host 'Enter the Blacklight: Retribution folder or its Binaries\Win32 folder:'
    $manual = Resolve-GameDirectory (Read-Host 'Path')
    if (-not $manual) {
        throw 'FoxGame-win32-Shipping.exe was not found in the selected location.'
    }
    return $manual
}

Write-Host 'BLRevive Steam Play Fix - Uninstall'
Write-Host '=================================='
Write-Host ''

$GameDir = Find-GameDirectory
$Target = Join-Path $GameDir $LauncherName
$Backup = Join-Path $GameDir $BackupName
$ArchiveMode = $false
$SteamAppIdManaged = $false
$ArchiveShortcut = $null

if (Test-Path -LiteralPath $InstallInfoPath -PathType Leaf) {
    foreach ($line in Get-Content -LiteralPath $InstallInfoPath) {
        if ($line -eq 'ArchiveMode=True') { $ArchiveMode = $true }
        if ($line -eq 'SteamAppIdManaged=True') { $SteamAppIdManaged = $true }
        if ($line -like 'ArchiveShortcut=*') { $ArchiveShortcut = $line.Substring('ArchiveShortcut='.Length) }
    }
}

Write-Host "Game directory: $GameDir"

$TargetExists = Test-Path -LiteralPath $Target -PathType Leaf
$TargetIsWrapper = $TargetExists -and ((Get-ProductName $Target) -eq $WrapperProductName)
$TargetIsUsableNonWrapper = $TargetExists -and (Test-UsableOfficialBackup $Target)
$BackupIsUsable = Test-UsableOfficialBackup $Backup
$OfficialLauncherPresent = $false
$OriginalRestored = $false

if ($TargetIsUsableNonWrapper) {
    Write-Status 'The current Steam/BattlEye launcher is not the BLRevive wrapper; leaving it untouched.' 'Success'
    Write-Status 'Steam Verify may already have restored the official launcher.'
    $OfficialLauncherPresent = $true
}
elseif ($BackupIsUsable) {
    Write-Status 'Restoring the original Steam/BattlEye launcher...'

    if ($TargetExists) {
        # Both files are in the same directory, so File.Replace performs one
        # atomic filesystem replacement instead of deleting the target first.
        $rollback = Join-Path $GameDir ($LauncherName + '.blrevive-uninstall-rollback-' + [Guid]::NewGuid().ToString('N'))
        [IO.File]::Replace($Backup, $Target, $rollback, $true)
        try {
            Remove-Item -LiteralPath $rollback -Force
        } catch {
            Write-Status ('The restored launcher is safe, but the old wrapper rollback file could not be removed: ' + $rollback) 'Warning'
        }
    } else {
        [IO.File]::Move($Backup, $Target)
    }

    $OfficialLauncherPresent = $true
    $OriginalRestored = $true
    Write-Status 'Original Steam/BattlEye launcher restored.' 'Success'
} else {
    if (Test-Path -LiteralPath $Backup) {
        Write-Status 'The launcher backup is not a usable official executable and will not be restored.' 'Warning'
    } else {
        Write-Status 'No original launcher backup was found.' 'Warning'
    }

    if ($TargetIsWrapper) {
        Write-Status 'Removing the BLRevive Steam wrapper.'
        Remove-Item -LiteralPath $Target -Force
    } elseif ($TargetExists) {
        Write-Status 'The current launcher is not a usable BLRevive wrapper or official backup; leaving it untouched.' 'Warning'
    }

    if (-not $ArchiveMode) {
        Write-Status 'Use Steam -> Blacklight: Retribution -> Properties -> Installed Files -> Verify integrity' 'Warning'
        Write-Status 'to restore FoxGame-win32-Shipping_BE.exe.' 'Warning'
    }
}

if ($ArchiveMode -and $SteamAppIdManaged) {
    $steamAppId = Join-Path $GameDir 'steam_appid.txt'
    $steamAppIdBackup = Join-Path $ScriptDir 'steam_appid.original.txt'
    if (Test-Path -LiteralPath $steamAppIdBackup -PathType Leaf) {
        Copy-Item -LiteralPath $steamAppIdBackup -Destination $steamAppId -Force
        Write-Status 'Restored the previous steam_appid.txt.' 'Success'
    } elseif (Test-Path -LiteralPath $steamAppId -PathType Leaf) {
        if ((Get-Content -Raw -LiteralPath $steamAppId).Trim() -eq '480') {
            Remove-Item -LiteralPath $steamAppId -Force
            Write-Status 'Removed the archive compatibility steam_appid.txt.' 'Success'
        }
    }
}

if ($ArchiveMode -and $ArchiveShortcut) {
    try {
        $shortcutFull = [IO.Path]::GetFullPath($ArchiveShortcut)
        if ([IO.Path]::GetExtension($shortcutFull) -eq '.lnk' -and
            (Test-Path -LiteralPath $shortcutFull -PathType Leaf)) {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutFull)
            if ($shortcut.TargetPath -eq $Target) {
                Remove-Item -LiteralPath $shortcutFull -Force
                Write-Status 'Removed the Play BLRevive desktop shortcut.' 'Success'
            }
        }
    } catch {
        Write-Status ('The desktop shortcut could not be removed: ' + $_.Exception.Message) 'Warning'
    }
}

if ($OfficialLauncherPresent) {
    if (Request-WindowsShellIconRefresh $Target) {
        Write-Status 'Requested Windows shell icon refresh.' 'Success'
    }
}

Write-Host ''
if ($OriginalRestored) {
    Write-Status 'Uninstall completed; the original launcher is restored.' 'Success'
} elseif ($OfficialLauncherPresent) {
    Write-Status 'Uninstall cleanup completed; the existing non-BLRevive launcher was preserved.' 'Success'
} else {
    if ($ArchiveMode) {
        Write-Status 'BLRevive archive integration was removed.' 'Success'
    } else {
        Write-Status 'BLRevive wrapper removal completed without an original launcher backup.' 'Warning'
    }
}
Write-Host 'BLReviveLauncher.ini, launcher diagnostics, and uninstall logs were left in place intentionally.'
Write-Host 'They may be deleted manually.'
Write-Host ''
exit 0
