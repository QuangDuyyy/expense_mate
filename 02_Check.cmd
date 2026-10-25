@echo off
cd /d "%~dp0"
call flutter doctor -v
call flutter devices
pause
