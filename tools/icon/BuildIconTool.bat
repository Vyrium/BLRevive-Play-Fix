@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if exist "BLReviveIconTool.exe" del /q "BLReviveIconTool.exe" >nul 2>nul

echo BLRevive Steam Play Fix - Build Icon Tool
echo.

set "CSC="
if exist "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not defined CSC if exist "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if not defined CSC (
    echo ERROR: Could not find the .NET Framework C# compiler csc.exe.
    exit /b 1
)

if not exist "BLReviveIconTool.cs" (
    echo ERROR: BLReviveIconTool.cs is missing.
    exit /b 1
)

echo Compiler: "%CSC%"
"%CSC%" /nologo /target:exe /platform:anycpu /optimize+ /reference:System.Drawing.dll /out:"BLReviveIconTool.exe" "BLReviveIconTool.cs"
if errorlevel 1 (
    echo.
    echo ERROR: Icon tool compilation failed.
    exit /b 1
)

if not exist "BLReviveIconTool.exe" (
    echo ERROR: Compilation reported success but no icon tool EXE was produced.
    exit /b 1
)

echo.
echo Build successful: BLReviveIconTool.exe

set "SVG=%~dp0..\..\resources\BLReviveLogo.svg"
set "RENDER=%~dp0RenderSvgLogo.ps1"
set "PNG=%TEMP%\BLReviveSteamLauncher-icon.png"
set "ICO=%~dp0..\..\resources\BLReviveSteamLauncher.ico"

if not exist "%SVG%" (
    echo ERROR: BLReviveLogo.svg is missing.
    exit /b 1
)
if not exist "%RENDER%" (
    echo ERROR: RenderSvgLogo.ps1 is missing.
    exit /b 1
)

if exist "%PNG%" del /q "%PNG%" >nul 2>nul
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%RENDER%" -InputSvg "%SVG%" -OutputPng "%PNG%"
if errorlevel 1 (
    echo.
    echo ERROR: Could not render BLReviveLogo.svg.
    exit /b 1
)

"%~dp0BLReviveIconTool.exe" --input "%PNG%" --output "%ICO%"
set "RC=%ERRORLEVEL%"
if exist "%PNG%" del /q "%PNG%" >nul 2>nul
if not "%RC%"=="0" (
    echo.
    echo ERROR: Could not create BLReviveSteamLauncher.ico.
    exit /b %RC%
)

echo.
echo Icon generated: "%ICO%"
exit /b 0
