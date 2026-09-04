param(
    [switch]$Install,
    [switch]$CheckOnly,
    [string]$DownloadDirectory,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

if (-not $DownloadDirectory) {
    $DownloadDirectory = Join-Path $env:LOCALAPPDATA 'BLReviveSteamPlayFix\Prerequisites'
}
if (-not $LogPath) {
    $LogPath = Join-Path $DownloadDirectory 'BLRevivePrerequisites.log'
}

$script:TranscriptStarted = $false
if ($Install) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $LogPath) -Force | Out-Null
    try {
        Start-Transcript -Path $LogPath -Append -Force | Out-Null
        $script:TranscriptStarted = $true
    } catch {
        Write-Host ('[!] The prerequisite log could not be started: ' + $_.Exception.Message) -ForegroundColor Yellow
    }
}

function Stop-PrerequisiteTranscript {
    if ($script:TranscriptStarted) {
        try { Stop-Transcript | Out-Null } catch {}
        $script:TranscriptStarted = $false
    }
}

trap {
    Write-Host ''
    Write-Host ('[!] Prerequisite setup stopped: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('[!] Detailed log: ' + $LogPath) -ForegroundColor Yellow
    Stop-PrerequisiteTranscript
    exit 1
}

function Write-Status([string]$Text, [ValidateSet('Info', 'Success', 'Warning')] [string]$Kind = 'Info') {
    $prefix = if ($Kind -eq 'Warning') { '[!]' } else { '[+]' }
    $color = if ($Kind -eq 'Warning') { 'Yellow' } elseif ($Kind -eq 'Success') { 'Green' } else { 'Cyan' }
    Write-Host ($prefix + ' ' + $Text) -ForegroundColor $color
}

function Format-ByteSize([long]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N1} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    return ($Bytes.ToString() + ' bytes')
}

function Invoke-VisibleDownload([string]$Name, [string]$Url, [string]$Destination) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $client = New-Object Net.WebClient
    $inputStream = $null
    $outputStream = $null

    try {
        $client.Headers.Add('User-Agent', 'BLRevive-Steam-Play-Fix/1.1')
        $inputStream = $client.OpenRead($Url)
        $lengthText = $client.ResponseHeaders['Content-Length']
        $totalBytes = 0L
        if ($lengthText) { [long]::TryParse($lengthText, [ref]$totalBytes) | Out-Null }

        $outputStream = [IO.File]::Open($Destination, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $buffer = New-Object byte[] 65536
        $downloaded = 0L

        while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $outputStream.Write($buffer, 0, $read)
            $downloaded += $read

            if ($totalBytes -gt 0) {
                $percent = [Math]::Min(100, [Math]::Floor(($downloaded * 100.0) / $totalBytes))
                $status = ('{0} of {1} ({2}%)' -f (Format-ByteSize $downloaded), (Format-ByteSize $totalBytes), $percent)
                Write-Progress -Activity ('Downloading ' + $Name) -Status $status -PercentComplete $percent
            } else {
                Write-Progress -Activity ('Downloading ' + $Name) -Status ((Format-ByteSize $downloaded) + ' received')
            }
        }

        Write-Progress -Activity ('Downloading ' + $Name) -Completed
        Write-Status ('Download complete: ' + (Format-ByteSize $downloaded) + ' saved to ' + $Destination) 'Success'
    } finally {
        Write-Progress -Activity ('Downloading ' + $Name) -Completed
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        $client.Dispose()
    }
}

function Get-X86SystemDirectory {
    if ([Environment]::Is64BitOperatingSystem) {
        return (Join-Path $env:WINDIR 'SysWOW64')
    }
    return (Join-Path $env:WINDIR 'System32')
}

function Test-Files([string[]]$Paths) {
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    }
    return $true
}

function Test-VersionedFiles([string[]]$Paths, [version]$MinimumVersion) {
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
        try {
            $versionText = (Get-Item -LiteralPath $path).VersionInfo.FileVersion
            if ([version]$versionText -lt $MinimumVersion) { return $false }
        } catch {
            return $false
        }
    }
    return $true
}

function Convert-ToFourPartVersion([string]$Text) {
    if ([String]::IsNullOrWhiteSpace($Text)) { return $null }
    $match = [regex]::Match($Text, '\d+(?:\.\d+){1,3}')
    if (-not $match.Success) { return $null }

    $parts = @($match.Value.Split('.'))
    while ($parts.Count -lt 4) { $parts += '0' }
    try { return [version](($parts[0..3]) -join '.') } catch { return $null }
}

function Test-RegisteredVisualCpp([string]$Year, [ValidateSet('x86', 'x64')] [string]$Architecture, [version]$MinimumVersion) {
    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $namePattern = 'Microsoft Visual C\+\+\s+' + [regex]::Escape($Year) + '\s+Redistributable.*\(' + $Architecture + '\)'

    foreach ($product in Get-ItemProperty -Path $uninstallRoots -ErrorAction SilentlyContinue) {
        if ($product.DisplayName -notmatch $namePattern) { continue }
        $installedVersion = Convert-ToFourPartVersion $product.DisplayVersion
        if (-not $installedVersion) { $installedVersion = Convert-ToFourPartVersion $product.DisplayName }
        if ($installedVersion -and $installedVersion -ge $MinimumVersion) { return $true }
    }
    return $false
}

function Test-DotNet4 {
    foreach ($key in @(
        'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full',
        'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Client'
    )) {
        try {
            $properties = Get-ItemProperty -Path $key -ErrorAction Stop
            if ($properties.Install -eq 1 -or $properties.Release) { return $true }
        } catch {}
    }
    return $false
}

function Test-PhysX {
    $roots = @(
        ${env:ProgramFiles(x86)},
        $env:ProgramFiles
    ) | Where-Object { $_ } | Select-Object -Unique

    foreach ($root in $roots) {
        if (Test-Path -LiteralPath (Join-Path $root 'NVIDIA Corporation\PhysX\Common\PhysXLoader.dll') -PathType Leaf) {
            return $true
        }
    }
    return $false
}

function Get-PrerequisiteState {
    $x86 = Get-X86SystemDirectory
    $system32 = Join-Path $env:WINDIR 'System32'
    $results = New-Object System.Collections.Generic.List[object]

    $results.Add([pscustomobject]@{
        Id = 'DirectX'; Name = 'DirectX End-User Runtimes (June 2010)';
        Installed = Test-Files @((Join-Path $x86 'd3dx9_43.dll'), (Join-Path $x86 'xinput1_3.dll'))
    })
    $results.Add([pscustomobject]@{
        Id = 'VC2010x86'; Name = 'Visual C++ 2010 SP1 Redistributable (x86)';
        Installed = Test-VersionedFiles @((Join-Path $x86 'msvcr100.dll'), (Join-Path $x86 'msvcp100.dll')) ([version]'10.0.40219.325')
    })
    $results.Add([pscustomobject]@{
        Id = 'VC2012x86'; Name = 'Visual C++ 2012 Update 4 Redistributable (x86)';
        Installed = ((Test-RegisteredVisualCpp '2012' 'x86' ([version]'11.0.61030.0')) -or
            (Test-VersionedFiles @((Join-Path $x86 'msvcr110.dll'), (Join-Path $x86 'msvcp110.dll')) ([version]'11.0.61030.0')))
    })
    $results.Add([pscustomobject]@{
        Id = 'VC2013x86'; Name = 'Visual C++ 2013 Redistributable (x86)';
        Installed = ((Test-RegisteredVisualCpp '2013' 'x86' ([version]'12.0.40664.0')) -or
            (Test-VersionedFiles @((Join-Path $x86 'msvcr120.dll'), (Join-Path $x86 'msvcp120.dll')) ([version]'12.0.40664.0')))
    })

    if ([Environment]::Is64BitOperatingSystem) {
        $results.Add([pscustomobject]@{
            Id = 'VC2010x64'; Name = 'Visual C++ 2010 SP1 Redistributable (x64)';
            Installed = Test-VersionedFiles @((Join-Path $system32 'msvcr100.dll'), (Join-Path $system32 'msvcp100.dll')) ([version]'10.0.40219.325')
        })
        $results.Add([pscustomobject]@{
            Id = 'VC2012x64'; Name = 'Visual C++ 2012 Update 4 Redistributable (x64)';
            Installed = ((Test-RegisteredVisualCpp '2012' 'x64' ([version]'11.0.61030.0')) -or
                (Test-VersionedFiles @((Join-Path $system32 'msvcr110.dll'), (Join-Path $system32 'msvcp110.dll')) ([version]'11.0.61030.0')))
        })
        $results.Add([pscustomobject]@{
            Id = 'VC2013x64'; Name = 'Visual C++ 2013 Redistributable (x64)';
            Installed = ((Test-RegisteredVisualCpp '2013' 'x64' ([version]'12.0.40664.0')) -or
                (Test-VersionedFiles @((Join-Path $system32 'msvcr120.dll'), (Join-Path $system32 'msvcp120.dll')) ([version]'12.0.40664.0')))
        })
    }

    $results.Add([pscustomobject]@{
        Id = 'DotNet4'; Name = '.NET Framework 4.x (satisfies .NET 4 Client Profile)'; Installed = Test-DotNet4
    })
    $results.Add([pscustomobject]@{
        Id = 'PhysX'; Name = 'NVIDIA PhysX System Software'; Installed = Test-PhysX
    })

    return $results
}

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator permission is required to install the missing game prerequisites.'
    }
}

function Get-SignedDownload([string]$Name, [string]$Url, [string]$FileName, [string]$SignerPattern) {
    New-Item -ItemType Directory -Path $DownloadDirectory -Force | Out-Null
    $path = Join-Path $DownloadDirectory $FileName

    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $cachedSignature = Get-AuthenticodeSignature -LiteralPath $path
        $cachedSigner = if ($cachedSignature.SignerCertificate) { $cachedSignature.SignerCertificate.Subject } else { '' }
        if ($cachedSignature.Status -ne [Management.Automation.SignatureStatus]::Valid -or $cachedSigner -notmatch $SignerPattern) {
            Write-Status ('Discarding an incomplete or untrusted cached copy of ' + $Name + '.') 'Warning'
            Remove-Item -LiteralPath $path -Force
        }
    }

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Status ('Downloading ' + $Name + '.')
        Write-Host ('    Source: ' + $Url)
        Write-Host ('    Save to: ' + $path)
        Write-Host '    Keep this window open and wait while the progress display is changing.'
        Write-Host '    If the window visibly waits after the download completes, press Enter once to continue.'
        try {
            Invoke-VisibleDownload $Name $Url $path
        } catch {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            throw "Could not download $Name from its publisher. Check the internet connection and run the installer again. $($_.Exception.Message)"
        }
    } else {
        Write-Status ('Using the cached download for ' + $Name + ': ' + $path)
    }

    Write-Status ('Verifying the publisher signature for ' + $Name + '...')
    $signature = Get-AuthenticodeSignature -LiteralPath $path
    $signer = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { '' }
    if ($signature.Status -ne [Management.Automation.SignatureStatus]::Valid -or $signer -notmatch $SignerPattern) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        throw "$Name did not have the expected valid publisher signature. The downloaded file was discarded."
    }
    Write-Status ('Publisher signature verified: ' + $signer) 'Success'

    return $path
}

function Invoke-Installer([string]$Name, [string]$FilePath, [string[]]$Arguments) {
    Write-Status ('Starting the silent installer for ' + $Name + '.')
    Write-Host ('    Installer: ' + $FilePath)
    Write-Host '    The installer normally needs no input, but follow any prompt that appears.'
    Write-Host '    It may take several minutes and may not show another window.'
    Write-Host '    Please keep this window open while the elapsed-time display is changing.'

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru
    $nextNotice = 15
    while (-not $process.HasExited) {
        $elapsed = [Math]::Floor($stopwatch.Elapsed.TotalSeconds)
        Write-Progress -Activity ('Installing ' + $Name) -Status ("Working... $elapsed seconds elapsed")
        if ($elapsed -ge $nextNotice) {
            Write-Host ("    Still installing $Name... $elapsed seconds elapsed. No action is needed.")
            $nextNotice += 15
        }
        Start-Sleep -Seconds 1
        $process.Refresh()
    }
    $stopwatch.Stop()
    Write-Progress -Activity ('Installing ' + $Name) -Completed

    if ($process.ExitCode -notin @(0, 1638, 3010)) {
        throw "$Name failed with installer exit code $($process.ExitCode)."
    }
    if ($process.ExitCode -eq 3010) { $script:RestartRequired = $true }
    Write-Status ("Finished $Name in $([Math]::Ceiling($stopwatch.Elapsed.TotalSeconds)) seconds (exit code $($process.ExitCode)).") 'Success'
}

function Install-DirectX {
    $redist = Get-SignedDownload 'DirectX End-User Runtimes (June 2010)' `
        'https://download.microsoft.com/download/8/4/a/84a35bf1-dafe-4ae8-82af-ad2ae20b6b14/directx_Jun2010_redist.exe' `
        'directx_Jun2010_redist.exe' 'Microsoft Corporation'
    $extract = Join-Path $DownloadDirectory 'DirectX-June-2010'
    New-Item -ItemType Directory -Path $extract -Force | Out-Null
    Invoke-Installer 'DirectX June 2010 package extraction' $redist @('/Q', ('/T:"' + $extract + '"'))
    Invoke-Installer 'DirectX End-User Runtimes (June 2010)' (Join-Path $extract 'DXSETUP.exe') @('/silent')
}

function Install-VisualCpp([string]$Name, [string]$Url, [string]$FileName, [string[]]$Arguments) {
    $installer = Get-SignedDownload $Name $Url $FileName 'Microsoft Corporation'
    Invoke-Installer $Name $installer $Arguments
}

function Install-PhysX {
    $name = 'NVIDIA PhysX System Software 9.12.1031'
    $installer = Get-SignedDownload $name `
        'https://us.download.nvidia.com/Windows/9.12.1031/PhysX-9.12.1031-SystemSoftware.msi' `
        'PhysX-9.12.1031-SystemSoftware.msi' 'NVIDIA Corporation'
    Invoke-Installer $name 'msiexec.exe' @('/i', ('"' + $installer + '"'), '/quiet', '/norestart')
}

function Install-DotNet4 {
    $name = '.NET Framework 4.8 Runtime'
    $installer = Get-SignedDownload $name `
        'https://go.microsoft.com/fwlink/?linkid=2088631' `
        'ndp48-x86-x64-allos-enu.exe' 'Microsoft Corporation'
    Invoke-Installer $name $installer @('/q', '/norestart')
}

Write-Host 'Blacklight: Retribution prerequisites'
Write-Host '========================================'
Write-Host ''

$state = @(Get-PrerequisiteState)
foreach ($item in $state) {
    if ($item.Installed) {
        Write-Status ($item.Name + ': ready') 'Success'
    } else {
        Write-Status ($item.Name + ': missing') 'Warning'
    }
}

$missing = @($state | Where-Object { -not $_.Installed })
if ($missing.Count -eq 0) {
    Write-Status 'All Blacklight prerequisites are ready.' 'Success'
    Stop-PrerequisiteTranscript
    exit 0
}

if ($CheckOnly -or -not $Install) { exit 2 }

Assert-Administrator
$script:RestartRequired = $false

Write-Host ''
Write-Host 'Installation information' -ForegroundColor White
Write-Host '------------------------'
Write-Host ('Missing components: ' + $missing.Count)
Write-Host ('Download cache: ' + $DownloadDirectory)
Write-Host 'Downloads come directly from Microsoft or NVIDIA using the URLs shown below.'
Write-Host 'Most steps advance automatically. Follow a prompt if PowerShell or an installer displays one.'
Write-Host 'Wait while percentages or elapsed-time messages are changing.'
Write-Host 'If PowerShell visibly waits after a completed download, click the window and press Enter once.'
Write-Host 'If selecting console text paused the window, press Escape or Enter to resume it.'
Write-Host 'Do not close this window before a success or error message appears.'
Write-Host ''

for ($itemIndex = 0; $itemIndex -lt $missing.Count; $itemIndex++) {
    $item = $missing[$itemIndex]
    Write-Host ('[{0}/{1}] {2}' -f ($itemIndex + 1), $missing.Count, $item.Name) -ForegroundColor White
    switch ($item.Id) {
        'DirectX' { Install-DirectX }
        'VC2010x86' {
            Install-VisualCpp $item.Name 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe' 'vcredist_2010_x86.exe' @('/q', '/norestart')
        }
        'VC2010x64' {
            Install-VisualCpp $item.Name 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe' 'vcredist_2010_x64.exe' @('/q', '/norestart')
        }
        'VC2012x86' {
            Install-VisualCpp $item.Name 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe' 'vcredist_2012_x86.exe' @('/install', '/quiet', '/norestart')
        }
        'VC2012x64' {
            Install-VisualCpp $item.Name 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe' 'vcredist_2012_x64.exe' @('/install', '/quiet', '/norestart')
        }
        'VC2013x86' {
            Install-VisualCpp $item.Name 'https://aka.ms/highdpimfc2013x86enu' 'vcredist_2013_x86.exe' @('/install', '/quiet', '/norestart')
        }
        'VC2013x64' {
            Install-VisualCpp $item.Name 'https://aka.ms/highdpimfc2013x64enu' 'vcredist_2013_x64.exe' @('/install', '/quiet', '/norestart')
        }
        'DotNet4' { Install-DotNet4 }
        'PhysX' { Install-PhysX }
    }
    Write-Host ''
}

$remaining = @(Get-PrerequisiteState | Where-Object { -not $_.Installed })
if ($remaining.Count -gt 0) {
    throw ('These prerequisites still appear to be missing: ' + (($remaining | Select-Object -ExpandProperty Name) -join ', '))
}

Write-Host ''
Write-Status 'All Blacklight prerequisites were installed successfully.' 'Success'
if ($script:RestartRequired) {
    Write-Status 'Windows requested a restart. Restart before playing Blacklight.' 'Warning'
}
Write-Status ('Prerequisite log saved to: ' + $LogPath) 'Success'
Stop-PrerequisiteTranscript
exit 0
