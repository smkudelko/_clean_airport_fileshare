@echo off
setlocal DisableDelayedExpansion
REM Keep clean_airport.ps1 beside this launcher. Scope is that folder, not the working directory.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0clean_airport.ps1" %*
exit /b %ERRORLEVEL%
