@echo off
setlocal
cd /d "%~dp0"
set "SCRIPT=%~dp0scripts\BLReviveUninstaller.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0BLReviveUninstaller.ps1"
if not exist "%SCRIPT%" (
  echo ERROR: BLRevive uninstaller support is missing.
  echo.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
  echo Uninstall did not complete successfully. Error code: %RC%
) else (
  echo Uninstall completed successfully.
)
echo.
pause
exit /b %RC%
