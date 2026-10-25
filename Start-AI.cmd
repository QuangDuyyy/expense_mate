@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-ai.ps1"
if errorlevel 1 echo Failed. Share the error text above, without keys or passwords.
pause
