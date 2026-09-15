@echo off
setlocal
chcp 65001 >nul
rem Operaciones adicionales de este parche. Install_Update.exe importa primero basebandUPD.reg y despues
rem ejecuta este CMD elevado, guarda toda su salida en %WS_OTA_LOG% y da la instalacion por buena solo
rem si termina con codigo 0. No importes aqui el REG: el EXE ya lo ha aplicado.
rem %WS_OTA_RES% es la carpeta Resources (se rellena aqui si el CMD se ejecuta a mano).
if not defined WS_OTA_RES set "WS_OTA_RES=%~dp0."

rem Anade aqui las operaciones; cada una debe comprobar su resultado:
rem    comando
rem    if errorlevel 1 exit /b 1

echo [%date% %time%] Parche aplicado correctamente
exit /b 0