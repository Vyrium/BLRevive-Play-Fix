@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if exist "BLReviveSteamLauncher.exe" del /q "BLReviveSteamLauncher.exe" >nul 2>nul

echo BLRevive Steam Play Fix - Build Launcher
echo.

set "ICON=%~1"
set "CSC="
if exist "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not defined CSC if exist "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if not defined CSC (
    echo ERROR: Could not find the .NET Framework C# compiler csc.exe.
    echo.
    echo Install/enable .NET Framework 4.x or build BLReviveSteamLauncher.cs
    echo with Visual Studio / Visual Studio Build Tools.
    exit /b 1
)

if not exist "BLReviveSteamLauncher.cs" (
    echo ERROR: BLReviveSteamLauncher.cs is missing.
    exit /b 1
)

set "ICONARG="
if defined ICON (
    if not exist "%ICON%" (
        echo ERROR: Requested launcher icon was not found:
        echo   %ICON%
        exit /b 1
    )
    set "ICONARG=/win32icon:"%ICON%""
    echo Icon: "%ICON%"
) else (
    echo Icon: none ^(generic Windows application icon^)
)

echo Compiler: "%CSC%"
"%CSC%" /nologo /target:winexe /platform:x86 /optimize+ /reference:System.Windows.Forms.dll %ICONARG% /out:"BLReviveSteamLauncher.exe" "BLReviveSteamLauncher.cs"
if errorlevel 1 (
    echo.
    echo ERROR: Launcher compilation failed.
    exit /b 1
)

if not exist "BLReviveSteamLauncher.exe" (
    echo ERROR: Compilation reported success but no EXE was produced.
    exit /b 1
)

echo.
echo Build successful: BLReviveSteamLauncher.exe
exit /b 0
