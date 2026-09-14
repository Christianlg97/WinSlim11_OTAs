@echo off
setlocal enabledelayedexpansion

:: --- Elevación a administrador (robusta) ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%COMSPEC%' -ArgumentList '/k','""%~f0""' -Verb RunAs"
    exit /b
)

:: --- Definir ruta base (donde está este CMD o el EXE) ---
set "BaseDir=%~dp0"
set "ResDir=%BaseDir%"
set "LogDir=%BaseDir%log"

set "LogFile=%LogDir%\UpdateLOG.log"

:: Fecha ISO (YYYY-MM-DD)
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd'"`) do set "FECHA=%%I"

:: Crear carpeta de logs si no existe
if not exist "%LogDir%" mkdir "%LogDir%"

:: Iniciar log
(
  echo ==================================================
  echo [Inicio] %date% %time%
  echo [FECHA] %FECHA%
  echo ==================================================
) > "%LogFile%"

:: Ejecutar todo el proceso de actualizacion y mandar salida al log
call :UpdaterTask >> "%LogFile%" 2>&1

:: --- Log global de verificación de OTA ---
echo [%date% %time%] UpdateSCR ejecutado. Changelog VBS creado en RunOnce. Parche aplicado exitosamente. >> "C:\WSCore\Logs\OTA_Update.log"

endlocal
echo.
echo ==================================================
echo Script finalizado. Revisa el log en: %LogFile%
echo ==================================================
exit /b

:UpdaterTask

echo.
echo Aplicando parche de registro basebandUPD...
if exist "%BaseDir%basebandUPD.reg" (
    reg import "%BaseDir%basebandUPD.reg"
) else (
    echo AVISO: No se encontro basebandUPD.reg
)

:: ###########################################################################################################################
:: ###########################################################################################################################


echo.
echo Preparando VBScript de RunOnce...
if not exist "C:\WSCore\Temp" mkdir "C:\WSCore\Temp"
if not exist "C:\WSCore\Logs" mkdir "C:\WSCore\Logs"

if exist "%ResDir%OTA_Changelog.vbs" (
    copy /y "%ResDir%OTA_Changelog.vbs" "C:\WSCore\Temp\OTA_Msg.vbs" >nul
    :: Crear tarea programada para el arranque en lugar de RunOnce para evitar solapamientos
    schtasks /Create /TN "WinSlimOTA_Changelog" /TR "wscript.exe \"C:\WSCore\Temp\OTA_Msg.vbs\"" /SC ONLOGON /RL HIGHEST /F >nul 2>&1
)


echo.
echo Tarea de actualizacion interna finalizada.
exit /b