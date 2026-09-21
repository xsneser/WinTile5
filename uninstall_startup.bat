@echo off
setlocal

set "AHK=%~dp0bin\AutoHotkey64.exe"

echo ==========================================================
echo   WinTile5: Remove Auto-Start
echo ==========================================================
echo.

echo [1/2] Stopping running instance...
taskkill /F /IM AutoHotkey64.exe >nul 2>&1

echo.
echo [2/2] Removing startup shortcut...
if exist "%AHK%" (
    "%AHK%" "%~dp0bin\startup_shortcut.ahk" remove
)

echo.
echo Done. Windows native 2x2 snapping is unaffected.
echo.
pause
endlocal
