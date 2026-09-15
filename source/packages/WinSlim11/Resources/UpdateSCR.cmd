@echo off
setlocal
chcp 65001 >nul
rem Operaciones adicionales de este parche. Install_Update.exe importa primero basebandUPD.reg y despues
rem ejecuta este CMD elevado, guarda toda su salida en %WS_OTA_LOG% y da la instalacion por buena solo
rem si termina con codigo 0. No importes aqui el REG: el EXE ya lo ha aplicado.

set "DEST=C:\WSCore\Components\WinSlimUpdate"
set "SOURCE=%~dp0Content"

echo [%date% %time%] Actualizando WinSlimUpdate...

rem ============================================================
rem Comprobar que existe la carpeta Content
rem ============================================================
if not exist "%SOURCE%\" (
    echo ERROR: No se encuentra la carpeta Content:
    echo "%SOURCE%"
    exit /b 1
)

rem ============================================================
rem Si existe el destino, vaciarlo
rem Si no existe, crearlo
rem ============================================================
if exist "%DEST%\" (
    echo [%date% %time%] Limpiando carpeta existente...

    attrib -r -h -s "%DEST%\*" /s /d >nul 2>&1
    del /f /q /a "%DEST%\*" >nul 2>&1

    for /d %%D in ("%DEST%\*") do (
        rd /s /q "%%~fD"
    )
) else (
    echo [%date% %time%] La carpeta no existe. Creandola...

    mkdir "%DEST%"
    if errorlevel 1 (
        echo ERROR: No se pudo crear "%DEST%"
        exit /b 2
    )
)

rem ============================================================
rem Copiar el contenido de Content al destino
rem ============================================================
echo [%date% %time%] Copiando contenido...

robocopy "%SOURCE%" "%DEST%" /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XJ /NFL /NDL /NJH /NJS

set "RC=%ERRORLEVEL%"

if %RC% GEQ 8 (
    echo ERROR: Robocopy fallo con codigo %RC%
    exit /b 3
)

echo [%date% %time%] WinSlimUpdate actualizado correctamente.
exit /b 0