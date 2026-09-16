@echo off
setlocal
chcp 65001 >nul
rem Operaciones adicionales de este parche. Install_Update.exe importa primero basebandUPD.reg y despues
rem ejecuta este CMD elevado, guarda toda su salida en %WS_OTA_LOG% y da la instalacion por buena solo
rem si termina con codigo 0. No importes aqui el REG: el EXE ya lo ha aplicado.

echo [%date% %time%] Parche aplicado correctamente.
exit /b 0