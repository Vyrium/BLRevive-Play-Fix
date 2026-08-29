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
exit /b 0
