@echo off
REM Runs the getSysUsers.ps1 PowerShell script

REM Set script directory to the location of this batch file
cd /d "%~dp0"

REM Run the PowerShell script with default parameters
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "GetSystemUsers.ps1"