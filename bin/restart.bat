@echo off
REM Reliable launcher: kills any running instance and starts the layout script.
taskkill /F /IM AutoHotkey64.exe >nul 2>&1
ping -n 2 127.0.0.1 >nul
start "" "%~dp0AutoHotkey64.exe" "%~dp0..\auto_layout.ahk"
