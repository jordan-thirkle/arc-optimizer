@echo off
title Arc Optimizer v1.1

if /I "%1"=="-Uninstall" goto uninstall
if /I "%1"=="--uninstall" goto uninstall

powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Arc-Optimizer.ps1"
if %ERRORLEVEL% neq 0 (
  echo Arc Optimizer exited with error code %ERRORLEVEL%
  pause
)
exit /b

:uninstall
echo Arc Optimizer - Clean Uninstall
echo This will remove Engine.ini and read-only flags from ARC Raiders config.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Arc-Optimizer.ps1" "-Uninstall"
pause
