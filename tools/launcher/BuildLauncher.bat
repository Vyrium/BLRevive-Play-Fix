@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "ROOT=%%~fI"
set "SOURCE=%ROOT%\src\BLReviveSteamLauncher.cs"
set "OUTPUT=%SCRIPT_DIR%BLReviveSteamLauncher.exe"
set "ICON="
if not "%~1"=="" set "ICON=%~f1"

if exist "%OUTPUT%" del /q "%OUTPUT%" >nul 2>nul

echo BLRevive Steam Play Fix - Build Launcher
echo.

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

if not exist "%SOURCE%" (
    echo ERROR: Launcher source is missing:
    echo   "%SOURCE%"
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
"%CSC%" /nologo /target:winexe /platform:x86 /optimize+ /reference:System.Windows.Forms.dll %ICONARG% /out:"%OUTPUT%" "%SOURCE%"
if errorlevel 1 (
    echo.
    echo ERROR: Launcher compilation failed.
    exit /b 1
)

if not exist "%OUTPUT%" (
    echo ERROR: Compilation reported success but no EXE was produced.
    exit /b 1
)

echo.
echo Build successful: "%OUTPUT%"
exit /b 0
