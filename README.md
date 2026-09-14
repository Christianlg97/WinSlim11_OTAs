# WinSlim OTA Updater

Aplicación AutoHotkey v2 para WinSlim 11 y WinSlim 10, con icono `wu.ico` y notas leídas desde Markdown.



<img width="953" height="647" alt="image" src="https://github.com/user-attachments/assets/d3572f3c-5f17-4fa8-aede-ccd0dc6e0439" />





**Estado actual: vista previa.** Los EXE requieren administrador, pero no ejecutan actualizaciones ni reinicios. CMD y REG no contienen cambios. No se utiliza VBS, RunOnce ni notificación posterior al arranque.

## Organización

```text
source/
  Install_Update.ahk              Código común de la aplicación
  build.ps1                       Compilación y preparación de paquetes
  assets/update.ico               Icono original elegido (wu.ico)
  packages/
    WinSlim11/Resources/          Archivos editables de WinSlim 11
    WinSlim10/Resources/          Archivos editables de WinSlim 10
Output/
  WinSlim11/                     EXE y Resources listos para distribuir
  WinSlim10/                     EXE y Resources listos para distribuir
archive/
  legacy/                        Instalador original y sus recursos
  previous-layout/               Documentación anterior y logos retirados
.build/                          Directorio temporal del compilador
```

**Edita source, distribuye Output.** Los recursos que antes estaban en Output se han trasladado a `source/packages` como fuentes de trabajo. El build sobrescribe sus copias generadas. `archive` no interviene en la compilación y no se distribuye.

## Qué editar

Dentro de `source/packages/WinSlim11/Resources` o `source/packages/WinSlim10/Resources`:

| Archivo | Función |
| --- | --- |
| `changelog.md` | Descripción visible en la interfaz. Guardar como UTF-8. |
| `ui.ini` | Títulos, resumen, etiquetas y botones. Guardar como UTF-16 LE (Unicode). |
| `UpdateSCR.cmd` | Operaciones del futuro parche; ahora no hace cambios. |
| `basebandUPD.reg` | Cambios de registro del futuro parche; ahora vacío. |
| `brand.ini` | Marca de la variante: WinSlim 11 o WinSlim 10. |

El icono compartido se edita en `source/assets/update.ico`. El build lo incorpora al EXE y lo copia a cada paquete.

### Cambiar textos sin tocar AHK

Edita `source/packages/<variante>/Resources/ui.ini` con Bloc de notas. Conserva la sección `[UI]` y los nombres a la izquierda del signo `=`; cambia únicamente sus valores. Por ejemplo:

```ini
[UI]
Title=Actualización de {brand}
Subtitle=Consulta las novedades de esta versión.
PackageTitle=Paquete de septiembre
PackageSummary=Versión 1.2 · Notas de publicación
ChangelogTitle=Novedades y mejoras
Footer=Guarda tu trabajo antes de instalar.
```

`{brand}` se sustituye automáticamente por la marca de la variante. `WindowTitle` controla la barra de título; `AppName`, `SidebarSubtitle` y `Navigation` la barra lateral; `InstallButton`, `LogButton` y `CloseButton` los botones. Si falta una clave o está vacía se usa su texto predeterminado. El archivo no contiene comandos ni activa la instalación.

Usa una sola línea por valor y textos breves: el título principal debe caber en unos 40 caracteres; subtítulo, resumen y pie en unos 80; etiquetas laterales y botones en unos 22. Son orientaciones, pues la anchura depende de los caracteres. Las descripciones largas deben ir en `changelog.md`, que permite desplazamiento.

Después ejecuta `& .\source\build.ps1 -ResourcesOnly` y vuelve a abrir el EXE. No hace falta recompilar para cambiar el INI o el MD. Se mantiene un único indicador fijo de **Instalación deshabilitada** mientras el motor esté bloqueado; los mensajes operativos de error y seguridad siguen ligados al comportamiento del programa.

El panel de notas es desplazable y de solo lectura. Presenta un subconjunto sencillo de Markdown como texto legible: títulos, listas y negrita. No es un navegador Markdown completo; no ejecuta HTML ni scripts. Lee el MD al abrir la aplicación y muestra un mensaje informativo si falta o está vacío.

## Cómo compilar

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
2. El EXE lee `Resources/brand.ini`, el icono y `Resources/changelog.md` junto al ejecutable.
3. Muestra la variante y sus notas. Actualmente Instalar permanece deshabilitado.
4. Cerrar termina la aplicación. No crea RunOnce, tareas programadas ni avisos para el siguiente arranque.

Para ejecutar la versión actual abre `Output/WinSlim11/Install_Update.exe` o `Output/WinSlim10/Install_Update.exe`. El equipo destinatario no necesita AutoHotkey instalado. Ambos son x64; WinSlim 10 tiene su marca y recursos separados, pero todavía requiere pruebas en ese sistema.

El fuente AHK también exige elevación y, al ejecutarlo directamente, utiliza por defecto los recursos generados de `Output/WinSlim11`.

## Flujo de trabajo y distribución

1. Edita el MD y los recursos de la variante en `source/packages`.
2. Ejecuta el build completo o `-ResourcesOnly` según lo que cambiaste.
3. Abre el resultado y revisa marca, icono, notas y caracteres especiales.
4. Distribuye **la carpeta completa** `Output/WinSlim11` o `Output/WinSlim10`, con su EXE y Resources juntos.

No distribuyas source, archive ni .build. Los dos paquetes son independientes y pueden tener notas y operaciones diferentes.

## Activación futura de una OTA real

Cambiar el CMD o REG **no activa la instalación**. El fuente mantiene `previewOnly := true` y el botón deshabilitado. Para una entrega real hay que habilitar explícitamente el motor y adaptar los textos y estados de la interfaz; no basta con cambiar una variable para considerar terminado el producto.

El motor reservado ejecuta el CMD elevado de forma síncrona, captura salida en `%ProgramData%\WinSlim\OTA\Logs` y comprueba su código de salida. El CMD será responsable de importar el REG cuando proceda, comprobar cada operación (`if errorlevel 1 exit /b N`) y devolver cero únicamente al terminar correctamente. El EXE no importa el REG por separado.

La barra es indeterminada mientras se ejecuta un CMD arbitrario. En una entrega activa, tras el éxito se podrá elegir reiniciar o hacerlo más tarde. No hay rollback automático, recuperación transaccional, firma del paquete ni validación de builds. Un fallo podría dejar cambios parciales: deben resolverse y probarse esos aspectos antes de distribuir parches reales.

## Comprobaciones

`Install_Update.exe --self-test` construye la interfaz, verifica archivos obligatorios y sale sin instalar. También exige administrador. Las variantes superaron este test antes de añadir la exigencia de elevación; después se verificó el manifiesto de ambos EXE. No se aplicaron parches al equipo durante el desarrollo.

Para una actualización real, probar en máquinas virtuales desechables de cada sistema: éxito, error del CMD, recurso ausente, cancelación de UAC, rutas con espacios, notas largas y reinicio diferido. No utilizar los archivos de archive para estas pruebas.
