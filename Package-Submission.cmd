@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\package-submission.ps1" %*
if errorlevel 1 echo Failed. Review the output above.
pause
