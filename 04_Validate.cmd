@echo off
cd /d "%~dp0"
call flutter pub get
if errorlevel 1 goto failed
call flutter analyze
if errorlevel 1 goto failed
call flutter test
if errorlevel 1 goto failed
echo Checks passed. Camera and SQLite still need physical Android testing.
pause
exit /b 0
:failed
echo Validation failed. Share the error output.
pause
exit /b 1
