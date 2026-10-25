@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\update.ps1" %*
if errorlevel 1 echo Update failed. Share the error output without secrets.
pause
