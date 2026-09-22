@echo off
setlocal

set "AHK=%~dp0AutoHotkey64.exe"
set "MAIN=%~dp0..\auto_layout.ahk"
set "VERIFY=%~dp0_verify.ahk"

echo ==========================================================
echo   WinTile5: Automated Non-Interactive Verification
echo ==========================================================
echo.

echo [1/3] Validating auto_layout.ahk syntax...
"%AHK%" /ErrorStdOut /Validate "%MAIN%"
if errorlevel 1 goto :err_main
echo [PASS] auto_layout.ahk syntax OK.
echo.

echo [2/3] Validating _verify.ahk syntax...
"%AHK%" /ErrorStdOut /Validate "%VERIFY%"
if errorlevel 1 goto :err_verify
echo [PASS] _verify.ahk syntax OK.
echo.

echo [3/3] Running 50-assertion state machine and geometry test...
"%AHK%" /ErrorStdOut "%VERIFY%"
if errorlevel 1 goto :err_test

echo.
echo ==========================================================
echo  [SUCCESS] All 50 tests passed with 0 errors and 0 popups!
echo ==========================================================
goto :done

:err_main
echo [FAIL] Syntax check failed for auto_layout.ahk!
goto :err

:err_verify
echo [FAIL] Syntax check failed for _verify.ahk!
goto :err

:err_test
echo [FAIL] State machine assertions failed!
goto :err

:err
echo.
echo ==========================================================
echo  [ERROR] Verification encountered failures.
echo ==========================================================
exit /b 1

:done
endlocal
