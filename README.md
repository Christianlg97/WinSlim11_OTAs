# WinSlim OTA Updater

Aplicación AutoHotkey v2 para WinSlim 11 y WinSlim 10, con icono `wu.ico` y notas leídas desde Markdown.



<img width="957" height="651" alt="image" src="https://github.com/user-attachments/assets/6f381d44-3d8b-455d-9599-b0e352b70819" />







**Estado actual: motor habilitado** (`previewOnly := false` en `Install_Update.ahk`). Los EXE requieren administrador; **Instalar actualización** ejecuta `Resources\UpdateSCR.cmd` elevado, y ese CMD importa `Resources\basebandUPD.reg`. Al terminar se ofrece reiniciar ahora o más tarde. No se utiliza VBS, RunOnce ni notificación posterior al arranque. Con `previewOnly := true` el botón queda deshabilitado y no se ejecuta nada.

## Organización

```text
source/
  Install_Update.ahk              Arranque, elevación, instancia única y motor reservado
  UpdaterView.ahk                 Ventana: barra lateral, paneles, botones, progreso y layout
  Painter.ahk                     Dibujo GDI+ con antialiasing de paneles, pastilla y barra
  Changelog.ahk                   Panel de notas (Rich Edit) y lector de Markdown
  UpdaterState.ahk                Estados del updater y reglas de habilitación
  Texts.ahk                       Carga y validación de ui.ini
  build.ps1                       Compilación y preparación de paquetes
  assets/update.ico               Icono original elegido (wu.ico)
  packages/
    WinSlim11/Resources/          Archivos editables de WinSlim 11
    WinSlim10/Resources/          Archivos editables de WinSlim 10
  tests/ui-smoke.ahk              Test de componentes de la interfaz, sin instalador
build.cmd                         Lanzador del build con doble clic
Output/
  WinSlim11/                     EXE y Resources listos para distribuir
  WinSlim10/                     EXE y Resources listos para distribuir
.build/                          Directorio temporal del compilador y de los tests
```

**Edita source, distribuye Output.** Los recursos que antes estaban en Output se han trasladado a `source/packages` como fuentes de trabajo. El build sobrescribe sus copias generadas. `Install_Update.ahk` incluye el resto de módulos con `#Include`; el compilador los integra en un único EXE. El material heredado (instalador original, VBS, logos y documentación anterior) ya no está en el árbol de trabajo: se conserva en el historial de Git, en la carpeta `archive/` del commit `fc38b62`.

## Qué editar

Dentro de `source/packages/WinSlim11/Resources` o `source/packages/WinSlim10/Resources`:

| Archivo | Función |
| --- | --- |
| `changelog.md` | Descripción visible en la interfaz. Guardar como UTF-8. |
| `ui.ini` | Títulos, resumen, etiquetas y botones. Guardar como UTF-8. |
| `UpdateSCR.cmd` | Operaciones del parche. La plantilla importa `basebandUPD.reg`, comprueba el resultado y termina con código 0; añade ahí los pasos adicionales. |
| `basebandUPD.reg` | Cambios de registro que importa el CMD. Formato regedit 5.00 (UTF-16 LE) con raíces completas: `HKEY_LOCAL_MACHINE`, no `HKLM` (las abreviadas se ignoran en silencio). |
| Campo `Brand` de `ui.ini` | Marca de la variante: WinSlim 11 o WinSlim 10. |

El icono compartido se edita en `source/assets/update.ico`. El build lo incorpora al EXE y lo copia a cada paquete.

### Cambiar textos sin tocar AHK

Edita `source/packages/<variante>/Resources/ui.ini` con Bloc de notas. Conserva la sección `[UI]` y los nombres a la izquierda del signo `=`; cambia únicamente sus valores. Por ejemplo:

```ini
[UI]
Title=Actualización de {brand}
Subtitle=Consulta las novedades de esta versión.
PackageTitle=Paquete de septiembre
ChangelogTitle=Novedades y mejoras
Footer=Guarda tu trabajo antes de instalar.
```

`{brand}` se sustituye automáticamente por la marca de la variante y `{version}` por la versión del programa (la del recurso de versión del EXE, fijada con `;@Ahk2Exe-SetVersion` en `Install_Update.ahk`). `WindowTitle` controla la barra de título; `AppName`, `SidebarSubtitle`, `Navigation` y `VersionLabel` la barra lateral; `InstallButton`, `LogButton` y `CloseButton` los botones. Todas las claves son explícitas: si falta una obligatoria se indica el error; no hay textos de respaldo ocultos en AHK. El archivo no contiene comandos ni activa la instalación.

La **franja de estado** del panel de acciones (en negrita, junto a los botones) muestra el mensaje operativo del motor cuando lo hay (`InstallingDetail`, `InstalledDetail` o el texto de un error) y, si no, la etiqueta del estado actual: `PreviewStatus` con el motor deshabilitado, o `StateIdle`…`StateError` según `source/UpdaterState.ahk`. Si el mensaje no cabe junto a los botones pasa a una fila propia encima de ellos. El INI cambia el texto, nunca el estado real; `RecoveryAvailable` y `RollbackAvailable` permanecen ocultas hasta que un componente real las confirme, y `RestartButton`, `LaterButton` y `RetryButton` sustituyen a los botones tras la instalación o un error.

Usa una sola línea por valor y textos breves: el título principal debe caber en unos 40 caracteres; subtítulo y pie en unos 80; identificador del paquete en unos 60; mensajes de la franja de estado en unos 70 (con más pasan a su propia fila); etiquetas laterales y botones en unos 22. Son orientaciones, pues la anchura depende de los caracteres. Las descripciones largas deben ir en `changelog.md`, que permite desplazamiento.

Después ejecuta `& .\source\build.ps1 -ResourcesOnly` y vuelve a abrir el EXE. No hace falta recompilar para cambiar el INI o el MD. Mientras el motor esté bloqueado la franja de estado muestra un único indicador fijo, **Instalación deshabilitada**; los mensajes operativos de error y seguridad siguen ligados al comportamiento del programa.

El panel de notas es un control Rich Edit nativo, desplazable y de solo lectura. Presenta un subconjunto sencillo de Markdown: títulos `#`…`######` en negrita y mayor tamaño, listas `-`/`*` como viñetas y `**negrita**` en línea. No es un navegador Markdown completo; no ejecuta HTML, RTF ni scripts. Lee el MD al abrir la aplicación y muestra un aviso si falta o está vacío. La ventana se puede redimensionar (mínimo 860×560) y el panel de notas crece con ella. El panel no usa la barra de desplazamiento nativa: cuando el texto desborda, un pulgar dibujado en el margen derecho indica la posición y se puede arrastrar (o pulsar la pista para avanzar una página); la rueda del ratón sobre las notas y el teclado también desplazan el texto. Los botones cambian de tono al pasar el ratón por encima.

Los paneles, la pastilla de navegación de la barra lateral, la barra de progreso y el pulgar de desplazamiento de las notas no son controles: `UpdaterView` los pinta en el `WM_PAINT` de la ventana con GDI+ (`Painter.ahk`), con esquinas redondeadas suavizadas y doble búfer. Los botones y el control de notas están subclasificados (`SetWindowSubclass`) para el estado *hover* y para la rueda del ratón, que el Rich Edit ignora sin barra propia. La ventana usa `WS_CLIPCHILDREN` y `WS_EX_COMPOSITED` para que el redimensionado no deje restos. Colores, radios y tipografía (Segoe UI) están centralizados al principio de `UpdaterView.ahk`. La barra de progreso ofrece `SetProgress(0-100)` y `SetMarquee(true|false)` para el motor. `UpdaterView.Destroy()` retira los manejadores de pintura, destruye la ventana y apaga GDI+ en ese orden; `CloseUI` la llama antes de `ExitApp`, porque los callbacks de salida se ejecutan antes de destruir la ventana y un repintado tardío fallaría.

## Cómo compilar

Puedes hacer doble clic en **`build.cmd`**, en la raíz: prepara ambas variantes y mantiene el resultado visible. Cierra antes los instaladores abiertos. También admite las opciones del script de PowerShell:

```bat
build.cmd
build.cmd -Variant WinSlim11
build.cmd -Variant WinSlim10
build.cmd -ResourcesOnly
```

Funciona desde cualquier directorio. Devuelve el código de salida del build y utiliza `ExecutionPolicy Bypass` solo para el proceso de PowerShell que lanza; no modifica la política global del equipo.

Necesitas Windows, PowerShell, AutoHotkey **2.0.28 x64** y Ahk2Exe. La instalación utilizada está en `C:\Program Files\AutoHotkey`. Ahk2Exe puede mostrar su propia versión v1: la base del programa debe ser **v2/AutoHotkey64.exe**.

Abre PowerShell en la raíz del proyecto:

```powershell
# Compilar y preparar las dos variantes
& .\source\build.ps1

# Compilar solo una
& .\source\build.ps1 -Variant WinSlim11
& .\source\build.ps1 -Variant WinSlim10

# Copiar recursos nuevos sin recompilar el EXE existente
& .\source\build.ps1 -ResourcesOnly
& .\source\build.ps1 -ResourcesOnly -Variant WinSlim11

# Usar otra instalación de AutoHotkey
& .\source\build.ps1 -AutoHotkeyRoot 'D:\Herramientas\AutoHotkey'
```

Compilar no ejecuta el instalador ni aplica cambios. Cierra el EXE antes de reconstruirlo. El build valida los recursos de entrada y compila a un nombre temporal nuevo para no confundir un EXE antiguo con una compilación exitosa.

`-ResourcesOnly` exige que el EXE seleccionado exista. Úsalo para cambios en MD, CMD, REG o marca. Si modificas el AHK o el icono del ejecutable, ejecuta el build completo. No edites Output: esos cambios se sobrescribirán. El build no elimina archivos adicionales que hayas añadido manualmente al paquete; revisa su contenido antes de distribuir.

También puedes compilar con Ahk2Exe: fuente `source/Install_Update.ahk`, base `v2/AutoHotkey64.exe`, icono `source/assets/update.ico` y destino `Output/<variante>/Install_Update.exe`. Después prepara los recursos de la variante. El script de build automatiza ambos pasos y es el método recomendado.

## Cómo funciona

1. Windows exige permisos de administrador mediante el manifiesto `requireAdministrator`. Cancelar UAC impide abrir la aplicación.
2. El EXE lee todos los textos descriptivos y la marca desde `Resources/ui.ini`, el icono y las notas desde `Resources/changelog.md`, junto al ejecutable.
3. Muestra la variante, sus notas y la versión del programa. **Instalar actualización** ejecuta `Resources\UpdateSCR.cmd` elevado y guarda su salida en `%ProgramData%\WinSlim\OTA\Logs\<fecha>-<pid>.log` (botón **Ver actividad**).
4. Si el CMD devuelve 0, la franja muestra `InstalledDetail` y los botones pasan a **Reiniciar ahora** / **Más tarde**; si no, muestra el error y ofrece **Reintentar**. Cerrar termina la aplicación. No crea RunOnce, tareas programadas ni avisos para el siguiente arranque.

Para ejecutar la versión actual abre `Output/WinSlim11/Install_Update.exe` o `Output/WinSlim10/Install_Update.exe`. El equipo destinatario no necesita AutoHotkey instalado. Ambos son x64; WinSlim 10 tiene su marca y recursos separados, pero todavía requiere pruebas en ese sistema.

El fuente AHK también exige elevación y, al ejecutarlo directamente, utiliza por defecto los recursos generados de `Output/WinSlim11`.

## Flujo de trabajo y distribución

1. Edita el MD y los recursos de la variante en `source/packages`.
2. Ejecuta el build completo o `-ResourcesOnly` según lo que cambiaste.
3. Abre el resultado y revisa marca, icono, notas y caracteres especiales.
4. Distribuye **la carpeta completa** `Output/WinSlim11` o `Output/WinSlim10`, con su EXE y Resources juntos.

No distribuyas source ni .build. Los dos paquetes son independientes y pueden tener notas y operaciones diferentes.

## Motor de instalación

`previewOnly` en `Install_Update.ahk` decide si el motor está activo. Con `true` el botón queda deshabilitado y no se ejecuta nada; con `false` (estado actual) **Instalar actualización** lanza el motor.

El motor ejecuta el CMD elevado de forma síncrona, captura su salida en `%ProgramData%\WinSlim\OTA\Logs` y comprueba el código de salida. **El EXE no importa el REG por separado**: es el CMD quien lo hace. La plantilla de `UpdateSCR.cmd` importa `basebandUPD.reg` con `reg import`, comprueba `errorlevel` y termina con 0; cualquier operación adicional debe ir detrás con su propia comprobación (`if errorlevel 1 exit /b N`). El CMD recibe `%WS_OTA_RES%` (carpeta Resources) y `%WS_OTA_LOG%` (archivo de registro) y fuerza UTF-8 (`chcp 65001`) para que el log se lea bien. Al ejecutarse elevado, las claves `HKEY_CURRENT_USER` del REG se aplican al perfil de la cuenta que aprobó el UAC.

Para probar un CMD sin tocar el equipo, copia la plantilla a una carpeta temporal con un `basebandUPD.reg` inofensivo (por ejemplo una clave bajo `HKEY_CURRENT_USER\Software`), define `WS_OTA_RES` y `WS_OTA_LOG` y ejecútalo con la misma orden que usa el motor: `cmd /D /V:OFF /S /C ""%WS_OTA_RES%\UpdateSCR.cmd" >> "%WS_OTA_LOG%" 2>&1"`.

La barra es indeterminada (marquesina) mientras se ejecuta un CMD arbitrario y pasa al 100 % al terminar. No hay rollback automático, recuperación transaccional, firma del paquete ni validación de builds. Un fallo podría dejar cambios parciales: deben resolverse y probarse esos aspectos antes de distribuir parches reales.

## Comprobaciones

`source/tests/ui-smoke.ahk` es un test de componentes: construye la vista con los recursos de `source/packages` sin incluir el instalador, la ejecución del CMD ni la elevación, por lo que no requiere administrador. Valida que los `ui.ini` de ambas variantes contengan todas las claves, el formato nativo de las notas, el aviso cuando el MD falta o está vacío, el layout en varios tamaños, que enfocar el panel de notas no lo desplace, el pulgar de desplazamiento (geometría, arrastre, paginación y rueda), las reglas de habilitación de cada estado, la API de progreso, el estado *hover* de los botones y que un arrastre simulado del borde no deje restos de pintura (muestrea píxeles de la propia ventana; esta parte la muestra brevemente en pantalla). Imprime `PASS` y devuelve 0; con `--preview` deja la ventana abierta para revisarla a mano:

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /ErrorStdOut .\source\tests\ui-smoke.ahk | Write-Output
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' .\source\tests\ui-smoke.ahk --preview
```

`Install_Update.exe --self-test` construye la interfaz, verifica archivos obligatorios y sale sin instalar. También exige administrador. Ejecútalo sobre `Output/<variante>/Install_Update.exe` tras cada build completo y comprueba que el código de salida es 0 (2 indica un recurso ausente). No se aplicaron parches al equipo durante el desarrollo.

Para una actualización real, probar en máquinas virtuales desechables de cada sistema: éxito, error del CMD, recurso ausente, cancelación de UAC, rutas con espacios, notas largas y reinicio diferido.

## Fuente única de los textos descriptivos

`source/packages/<variante>/Resources/ui.ini` contiene **todos los textos descriptivos de la interfaz**, incluida la marca (`Brand`), la etiqueta de estado (`PreviewStatus`) y el rótulo de versión (`VersionLabel`). `changelog.md` contiene **únicamente las notas del parche**. Ya no existe un `brand.ini` activo ni se leen descripciones de respaldo desde AHK. Los mensajes operativos de errores del motor siguen en el código.

Los cambios anteriores en los textos de respaldo del AHK no aparecían porque el INI tenía prioridad. Se han trasladado al INI las etiquetas editadas y el identificador del paquete de WinSlim 11. La configuración previa (`brand.ini` y los textos de respaldo del AHK) puede consultarse en el historial de Git; no se utiliza.

Editar los archivos de `source/packages`, ejecutar `& .\source\build.ps1 -ResourcesOnly` y **cerrar y volver a abrir el EXE de Output de esa variante**. Una ventana ya abierta conserva los textos cargados al arrancar. Editar un EXE antiguo o una copia fuera de `source/packages` no afecta al paquete actual. El build completo solo es necesario para cambios de código o del icono integrado.

La esquina transparente del control del logo utiliza `#111111`, el color de la muestra, igual que la barra lateral. El archivo ICO original no se ha alterado.
