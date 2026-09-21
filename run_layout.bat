@echo off
setlocal

echo Executing WinTile5 5-window layout...
start "" "%~dp0bin\AutoHotkey64.exe" "%~dp0bin\arrange_now.ahk"

endlocal
