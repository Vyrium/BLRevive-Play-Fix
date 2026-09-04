param(
    [string]$GameDirectory
)

$ErrorActionPreference = 'Continue'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GameExeName = 'FoxGame-win32-Shipping.exe'

function Resolve-GameDirectory([string]$Path) {
    if ([String]::IsNullOrWhiteSpace($Path)) { return $null }
    $trimmed = $Path.Trim().Trim('"')

    foreach ($candidate in @($trimmed, (Join-Path $trimmed 'Binaries\Win32'))) {
        if (Test-Path -LiteralPath (Join-Path $candidate $GameExeName) -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
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
        Write-Host ('The Windows folder picker could not be opened: ' + $_.Exception.Message) -ForegroundColor Yellow
    }
    return $null
}

function Find-GameDirectory {
    $explicit = Resolve-GameDirectory $GameDirectory
    if ($explicit) { return $explicit }

    $parent = Split-Path -Parent $ScriptDir
    foreach ($candidate in @($parent, $ScriptDir)) {
        $resolved = Resolve-GameDirectory $candidate
        if ($resolved) { return $resolved }
    }

    $installInfo = Join-Path $ScriptDir 'install-info.txt'
    if (Test-Path -LiteralPath $installInfo -PathType Leaf) {
        $savedDirectory = Get-Content -LiteralPath $installInfo |
            Where-Object { $_ -like 'GameDirectory=*' } |
            Select-Object -First 1
        if ($savedDirectory) {
            $resolved = Resolve-GameDirectory $savedDirectory.Substring('GameDirectory='.Length)
            if ($resolved) { return $resolved }
        }
    }

    return $null
}

$GameDir = Find-GameDirectory
if (-not $GameDir) {
    Write-Host 'Blacklight: Retribution was not found automatically.' -ForegroundColor Yellow
    Write-Host 'Opening a folder picker. Select the game folder or its Binaries\Win32 folder.'
    $GameDir = Select-GameDirectoryWithDialog
}
if (-not $GameDir) {
    Write-Host 'Enter the Blacklight: Retribution folder or its Binaries\Win32 folder:'
    $GameDir = Resolve-GameDirectory (Read-Host 'Path')
}
if (-not $GameDir) {
    Write-Host 'FoxGame-win32-Shipping.exe was not found in the selected location.' -ForegroundColor Red
    exit 1
}

$ReportDirectory = if ((Split-Path -Leaf $ScriptDir) -eq 'scripts') { Split-Path -Parent $ScriptDir } else { $ScriptDir }
$ReportPath = Join-Path $ReportDirectory 'BLReviveSteamPlayFix-Diagnostic.txt'
$lines = New-Object System.Collections.Generic.List[string]

function Add-Line([string]$Text = '') {
    $lines.Add($Text)
    Write-Host $Text
}

function Add-FileStatus([string]$Label, [string]$Path) {
    if (Test-Path $Path) {
        $item = Get-Item -LiteralPath $Path
        Add-Line ("{0}: PRESENT ({1} bytes)" -f $Label, $item.Length)
        try {
            $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
            if ($v.ProductName) { Add-Line ("  Product: " + $v.ProductName) }
            if ($v.FileVersion) { Add-Line ("  Version: " + $v.FileVersion) }
        } catch {}
    } else {
        Add-Line ($Label + ': MISSING')
    }
}

Add-Line 'BLRevive Steam Play Fix 1.1.0 - Diagnostic Report'
Add-Line '============================================='
Add-Line ('Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
Add-Line ('Game directory: ' + $GameDir)
Add-Line ('Windows: ' + [Environment]::OSVersion.VersionString)
Add-Line ('64-bit OS: ' + [Environment]::Is64BitOperatingSystem)
Add-Line ''

$prerequisiteScript = Join-Path $ScriptDir 'BLRevivePrerequisites.ps1'
if (Test-Path -LiteralPath $prerequisiteScript -PathType Leaf) {
    Add-Line 'Blacklight prerequisite check:'
    Add-Line '------------------------------'
    $prerequisiteOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $prerequisiteScript -CheckOnly 2>&1
    foreach ($outputLine in $prerequisiteOutput) { Add-Line ([string]$outputLine) }
    Add-Line ('Prerequisite check exit code: ' + $LASTEXITCODE + ' (0=ready, 2=one or more missing)')
} else {
    Add-Line 'Blacklight prerequisite checker: MISSING'
}
Add-Line ''

Add-FileStatus 'Real game executable' (Join-Path $GameDir 'FoxGame-win32-Shipping.exe')
Add-FileStatus 'Steam _BE launcher/wrapper' (Join-Path $GameDir 'FoxGame-win32-Shipping_BE.exe')
Add-FileStatus 'Archive Play BLRevive launcher' (Join-Path $GameDir 'Play BLRevive.exe')
Add-FileStatus 'Original _BE backup' (Join-Path $GameDir 'FoxGame-win32-Shipping_BE.official-backup.exe')
Add-FileStatus 'BLRevive DINPUT8 loader' (Join-Path $GameDir 'DINPUT8.dll')
Add-FileStatus 'BLRevive DLL' (Join-Path $GameDir 'BLRevive.dll')
Add-Line ''

$config = Join-Path $GameDir 'BLReviveLauncher.ini'
Add-FileStatus 'Launcher config' $config
if (Test-Path $config) {
    Add-Line 'Config contents:'
    foreach ($line in Get-Content -LiteralPath $config) {
        if ($line -match '^\s*(Host|Port)\s*=') { Add-Line ('  ' + $line.Trim()) }
    }
}
Add-Line ''


$installInfo = Join-Path $ScriptDir 'install-info.txt'
if (Test-Path $installInfo) {
    Add-Line 'Install metadata:'
    foreach ($line in Get-Content -LiteralPath $installInfo) {
        if ($line -match '^(BLRevive|Installed=|PayloadSHA256=|ArchiveMode=|ArchiveLauncher=|SteamAppIdManaged=|ArchiveShortcut=|IconMode=|IconSource=|IconEmbedded=|ShellIconRefreshRequested=)') { Add-Line ('  ' + $line) }
    }
    Add-Line ''
}

$appId = Join-Path $GameDir 'steam_appid.txt'
if (Test-Path $appId) {
    $appIdValue = (Get-Content -Raw -LiteralPath $appId).Trim()
    Add-Line ('steam_appid.txt: PRESENT, value=' + $appIdValue)
    if ($appIdValue -eq '480') {
        Add-Line '  Note: expected for a BLRevive archive installation.'
    } else {
        Add-Line '  Note: not required for the licensed Steam Play-button path.'
    }
} else {
    Add-Line 'steam_appid.txt: not present (normal for Steam Play-button use)'
}
Add-Line ''

$log = Join-Path $GameDir 'BLReviveSteamLauncher.log'
if (Test-Path $log) {
    Add-Line ('Runtime log: PRESENT (' + (Get-Item -LiteralPath $log).Length + ' bytes)')
    Add-Line ''
    Add-Line 'Last 80 runtime-log lines:'
    Add-Line '--------------------------'
    foreach ($line in Get-Content -LiteralPath $log -Tail 80) { Add-Line $line }
} else {
    Add-Line 'Runtime log: MISSING (launch the game through Steam once after installing the fix)'
}

Add-Line ''
$uninstallLog = Join-Path $ScriptDir 'BLReviveSteamPlayFix-Uninstall.log'
if (Test-Path $uninstallLog) {
    Add-Line ('Uninstall log: PRESENT (' + (Get-Item -LiteralPath $uninstallLog).Length + ' bytes)')
    Add-Line ''
    Add-Line 'Last 30 uninstall-log lines:'
    Add-Line '----------------------------'
    foreach ($line in Get-Content -LiteralPath $uninstallLog -Tail 30) { Add-Line $line }
} else {
    Add-Line 'Uninstall log: not present (created when Uninstall.bat is run)'
}

Add-Line ''
$prerequisiteLog = Join-Path $env:LOCALAPPDATA 'BLReviveSteamPlayFix\Prerequisites\BLRevivePrerequisites.log'
if (Test-Path -LiteralPath $prerequisiteLog -PathType Leaf) {
    Add-Line ('Prerequisite install log: PRESENT (' + (Get-Item -LiteralPath $prerequisiteLog).Length + ' bytes)')
    Add-Line ('  Location: ' + $prerequisiteLog)
    Add-Line ''
    Add-Line 'Last 50 prerequisite-log lines:'
    Add-Line '-------------------------------'
    foreach ($line in Get-Content -LiteralPath $prerequisiteLog -Tail 50) { Add-Line $line }
} else {
    Add-Line ('Prerequisite install log: not present at ' + $prerequisiteLog)
}

$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host ''
Write-Host ('Diagnostic report saved to: ' + $ReportPath) -ForegroundColor Green
Write-Host 'Attach this report when asking the BLRevive community for launcher support.'
exit 0
