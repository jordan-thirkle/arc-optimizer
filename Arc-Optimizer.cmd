@echo off
title Arc Optimizer v1.2
if /I "%1"=="-Uninstall" goto uninstall
if /I "%1"=="--uninstall" goto uninstall
start "" "%~dp0Arc-Optimizer.exe"
exit /b
:uninstall
echo Arc Optimizer - Clean Uninstall
"%~dp0Arc-Optimizer.exe" -Uninstall
pause
