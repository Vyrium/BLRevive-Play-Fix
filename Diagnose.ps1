$ErrorActionPreference = 'Continue'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GameExeName = 'FoxGame-win32-Shipping.exe'

function Find-GameDirectory {
    $parent = Split-Path -Parent $ScriptDir
    if (Test-Path (Join-Path $parent $GameExeName)) { return $parent }
    if (Test-Path (Join-Path $ScriptDir $GameExeName)) { return $ScriptDir }
    return $null
}

$GameDir = Find-GameDirectory
if (-not $GameDir) {
    Write-Host 'Could not determine the Blacklight Binaries\Win32 directory.' -ForegroundColor Red
    exit 1
}

$ReportPath = Join-Path $ScriptDir 'BLReviveSteamPlayFix-Diagnostic.txt'
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

Add-Line 'BLRevive Steam Play Fix 1.0.0 - Diagnostic Report'
Add-Line '============================================='
Add-Line ('Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
Add-Line ('Game directory: ' + $GameDir)
Add-Line ('Windows: ' + [Environment]::OSVersion.VersionString)
Add-Line ('64-bit OS: ' + [Environment]::Is64BitOperatingSystem)
Add-Line ''

Add-FileStatus 'Real game executable' (Join-Path $GameDir 'FoxGame-win32-Shipping.exe')
Add-FileStatus 'Steam _BE launcher/wrapper' (Join-Path $GameDir 'FoxGame-win32-Shipping_BE.exe')
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
        if ($line -match '^(BLRevive|Installed=|IconMode=|IconSource=|IconEmbedded=|ShellIconRefreshRequested=)') { Add-Line ('  ' + $line) }
    }
    Add-Line ''
}

$appId = Join-Path $GameDir 'steam_appid.txt'
if (Test-Path $appId) {
    Add-Line ('steam_appid.txt: PRESENT, value=' + ((Get-Content -Raw -LiteralPath $appId).Trim()))
    Add-Line '  Note: not required for the normal Steam Play-button path.'
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

$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host ''
Write-Host ('Diagnostic report saved to: ' + $ReportPath) -ForegroundColor Green
Write-Host 'Attach this report when asking the BLRevive community for launcher support.'
exit 0
