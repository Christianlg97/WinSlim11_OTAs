# WinSlim OTA — AutoHotkey 2.0.28 x64

## Paquetes

- `Output/Install_Update.exe`: WinSlim 11. Distribuir con `Output/Resources`.
- `Output/WinSlim10/Install_Update.exe`: WinSlim 10. Distribuir con su propia carpeta `Resources`.

Ambos ejecutables usan el mismo fuente y leen su marca desde `Resources/brand.ini`. Son aplicaciones x64. No requieren AutoHotkey instalado en el equipo destinatario.

## Estado actual: vista previa

`previewOnly := true` mantiene la instalación y el reinicio bloqueados. CMD y REG no contienen cambios. Abrir la aplicación exige permisos de administrador, incluso en vista previa, mediante el manifiesto `requireAdministrator`. Cancelar UAC impide abrirla.

## Archivos editables de cada paquete

- `Resources/UpdateSCR.cmd`: futuras operaciones del parche. Comprobar errores y devolver un código no cero si falla una operación. No se ejecuta en vista previa.
- `Resources/basebandUPD.reg`: futuros cambios del registro, actualmente vacío.
- `Resources/changelog.md`: descripción visible en la interfaz. Guardar como UTF-8. Se carga al abrir la aplicación, sin recompilar. Admite presentación textual de títulos, listas y negrita; no es un navegador Markdown completo y no ejecuta HTML. El panel permite desplazamiento para notas largas. Si falta o está vacío se muestra un mensaje informativo.
- `Resources/brand.ini`: WinSlim 11 o WinSlim 10.
- `Resources/update.ico`: icono de la interfaz, copiado del wu.ico proporcionado por el usuario.

No se utiliza VBS ni se crea RunOnce ni una tarea programada para las notas. Los originales de la raíz y de la antigua carpeta Resources quedan únicamente como referencia histórica, fuera de los nuevos paquetes.

## Compilación

Desde la raíz del proyecto:

```powershell
& .\source\build.ps1
```

Compila WinSlim 11 y copia el motor a la variante WinSlim 10. No sobrescribe CMD, REG, MD ni la configuración de marca. El icono del ejecutable se toma de `source/assets/update.ico`; recompilar si se cambia. En Ahk2Exe elegir AutoHotkey v2.0.28 x64 como base, aunque el compilador muestre su propia versión v1.

## Validación

Ambas variantes superaron la prueba `--self-test` después de añadir el MD y retirar el VBS, antes de exigir elevación. Se comprobó posteriormente que el manifiesto de ambos ejecutables contiene `requireAdministrator`. El mismo autotest sigue disponible pero ahora también solicita elevación. No se aplicó ningún parche al equipo. La variante WinSlim 10 requiere validación adicional en una máquina virtual con ese sistema.

Para preparar una actualización real será necesario habilitar explícitamente la instalación en el fuente y adaptar los estados de la interfaz. El motor conserva captura de logs y comprobación de códigos de salida, pero no incorpora aún rollback, firma del paquete ni validación de builds.
