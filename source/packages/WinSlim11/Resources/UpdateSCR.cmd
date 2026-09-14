@echo off
setlocal
chcp 65001 >nul
rem Operaciones de este parche. Install_Update.exe ejecuta el CMD elevado, guarda toda su salida en
rem %WS_OTA_LOG% y da la instalacion por buena solo si termina con codigo 0.
rem %WS_OTA_RES% es la carpeta Resources (se rellena aqui si el CMD se ejecuta a mano).
if not defined WS_OTA_RES set "WS_OTA_RES=%~dp0."

echo [%date% %time%] Importando basebandUPD.reg
reg import "%WS_OTA_RES%\basebandUPD.reg"
if errorlevel 1 (
    echo ERROR: no se pudo importar basebandUPD.reg
    exit /b 1
)

rem Anade aqui otras operaciones; cada una debe comprobar su resultado:
rem    comando
rem    if errorlevel 1 exit /b 2

echo [%date% %time%] Parche aplicado correctamente
exit /b 0