@echo off
setlocal

set "AHK=%~dp0bin\AutoHotkey64.exe"
set "LAUNCHER=%~dp0auto_layout.ahk"

echo ==========================================================
echo   WinTile5: Setup Auto-Start
echo ==========================================================
echo.

if not exist "%AHK%" goto :err_no_ahk

echo [1/3] Stopping previous instance...
taskkill /F /IM AutoHotkey64.exe >nul 2>&1
"%SystemRoot%\System32\ping.exe" -n 2 127.0.0.1 >nul

echo.
echo [2/3] Creating startup shortcut...
"%AHK%" "%~dp0bin\startup_shortcut.ahk"

echo.
echo [3/3] Starting WinTile5 in background...
start "" "%AHK%" "%LAUNCHER%"

echo.
echo ==========================================================
echo  Done. Auto-start configured and WinTile5 is running.
echo.
echo  Hotkeys:
echo    Win + Arrow        : Windows native 2x2 snap
echo    Win + Alt + Arrow  : Seamless 5-zone flow
echo    Win + Alt + A      : 5-window auto layout
echo    Win + Alt + Q      : Standard 2x2 layout
echo    Win + Numpad 1,2,7,8,6 : Jump to slots (7=TL, 8=TR, 1=BL, 2=BR, 6=Right)
echo ==========================================================
goto :done

:err_no_ahk
echo [ERROR] AutoHotkey runtime not found: %AHK%

:done
echo.
pause
endlocal
