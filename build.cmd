@echo off
setlocal
rem Run from any working directory; paths with spaces are supported.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0source\build.ps1" %*
set "BuildExit=%ERRORLEVEL%"
echo.
if "%BuildExit%"=="0" (
    echo Build completado. Paquetes disponibles en Output.
) else (
    echo El build ha fallado. Codigo: %BuildExit%
)
rem Keep results visible when launched by double-click, but not from a terminal.
echo(%CMDCMDLINE% | findstr /i /c:" /c " >nul
if not errorlevel 1 pause
exit /b %BuildExit%
