@echo off
setlocal

echo ==========================================================
echo   WinTile5: Migration Script (D:\new -^> D:\WinTile5)
echo ==========================================================
echo.

set "SRC=D:\new"
set "DST=D:\WinTile5"

echo [1/5] Stopping running AutoHotkey instances...
taskkill /F /IM AutoHotkey64.exe >nul 2>&1
"%SystemRoot%\System32\ping.exe" -n 2 127.0.0.1 >nul

echo [2/5] Migrating files to %DST% via robust copy...
echo (Notice: Active terminals/Claude sessions lock D:\new directory handles,
echo  so files are copied first to ensure zero downtime and zero data loss.)
echo.

robocopy "%SRC%" "%DST%" /E /COPY:DAT /DCOPY:DAT /R:2 /W:2 /XJ /XD ".git" >nul 2>&1
set "ROBO_EXIT=%errorlevel%"

if %ROBO_EXIT% GEQ 8 (
    echo [ERROR] Robocopy failed with exit code %ROBO_EXIT%.
    goto :copy_failed
)

echo [OK] Files successfully migrated to %DST%.
echo.

echo [3/5] Verifying critical files in %DST%...
if not exist "%DST%\auto_layout.ahk" goto :missing_critical
if not exist "%DST%\bin\AutoHotkey64.exe" goto :missing_critical
if not exist "%DST%\bin\startup_shortcut.ahk" goto :missing_critical
if not exist "%DST%\bin\verify.bat" goto :missing_critical
if not exist "%DST%\bin\_verify.ahk" goto :missing_critical
echo [PASS] All critical files verified in %DST%.
echo.

echo [4/5] Running syntax validation and 40-assertion tests in %DST%...
call "%DST%\bin\verify.bat"
if errorlevel 1 goto :verify_failed
echo.

echo [5/5] Updating startup shortcut and starting WinTile5 from %DST%...
cd /d "%DST%"
"%SystemRoot%\System32\ping.exe" -n 2 127.0.0.1 >nul
call "%DST%\bin\AutoHotkey64.exe" "%DST%\bin\startup_shortcut.ahk"
if errorlevel 1 goto :shortcut_failed

start "" "%DST%\bin\AutoHotkey64.exe" "%DST%\auto_layout.ahk"

echo.
echo ==========================================================
echo  [SUCCESS] WinTile5 migration and launch completed!
echo  Project folder: %DST%
echo ==========================================================
echo.
echo  Note regarding original folder (%SRC%):
echo  - %DST% is now the active, running installation.
echo  - Windows Startup now points to %DST%\auto_layout.ahk.
echo  - %SRC% is retained as a safe backup while current terminal/Claude
echo    sessions are still open. Once closed, you may safely delete %SRC%:
echo      rmdir /s /q "%SRC%"
echo ==========================================================
goto :done

:missing_critical
echo [ERROR] Critical files are missing in %DST%!
goto :err

:copy_failed
echo [ERROR] Failed to copy files from %SRC% to %DST%!
goto :err

:verify_failed
echo [ERROR] Verification failed in %DST%!
goto :err

:shortcut_failed
echo [ERROR] Failed to update startup shortcut!
goto :err

:err
echo.
echo ==========================================================
echo  [FAIL] Migration encountered an error.
echo ==========================================================

:done
echo.
pause
endlocal
