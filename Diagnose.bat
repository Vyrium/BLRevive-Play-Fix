@echo off
setlocal
cd /d "%~dp0"
set "SCRIPT=%~dp0scripts\BLReviveDiagnostics.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0BLReviveDiagnostics.ps1"
if not exist "%SCRIPT%" (
  echo ERROR: BLRevive diagnostic support is missing.
  echo.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
