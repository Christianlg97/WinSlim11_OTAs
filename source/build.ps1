param(
    [ValidateSet('All','WinSlim11','WinSlim10')][string]$Variant = 'All',
    [switch]$ResourcesOnly,
    [string]$AutoHotkeyRoot = 'C:\Program Files\AutoHotkey'
)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $AutoHotkeyRoot 'Compiler\Ahk2Exe.exe'
$base = Join-Path $AutoHotkeyRoot 'v2\AutoHotkey64.exe'
$inputFile = Join-Path $PSScriptRoot 'Install_Update.ahk'
$buildDir = Join-Path $project '.build'
New-Item -ItemType Directory -Force $buildDir | Out-Null
$outputFile = Join-Path $buildDir ([guid]::NewGuid().ToString('N') + '.exe')
$icon = Join-Path $PSScriptRoot 'assets\update.ico'
$variants = if ($Variant -eq 'All') { @('WinSlim11','WinSlim10') } else { @($Variant) }
$files = @('UpdateSCR.cmd','basebandUPD.reg','ui.ini','changelog.md')
foreach ($name in $variants) {
    foreach ($file in $files) {
        $path = Join-Path $PSScriptRoot "packages\$name\Resources\$file"
        if (!(Test-Path -LiteralPath $path)) { throw "Falta: $path" }
    }
    if ($ResourcesOnly -and !(Test-Path -LiteralPath (Join-Path $project "Output\$name\Install_Update.exe"))) {
        throw "Primero debes compilar $name."
    }
}
if (!(Test-Path -LiteralPath $icon)) { throw "Falta: $icon" }
if (!$ResourcesOnly) {
foreach ($file in @($compiler, $base, $inputFile)) {
    if (!(Test-Path -LiteralPath $file)) { throw "No se encuentra: $file" }
}
$compilerLog = Join-Path $buildDir 'ahk2exe.log'
$process = Start-Process -FilePath $compiler -ArgumentList @('/in', "`"$inputFile`"", '/out', "`"$outputFile`"", '/base', "`"$base`"", '/icon', "`"$icon`"", '/compress', '0', '/silent', 'verbose') -NoNewWindow -Wait -PassThru -RedirectStandardOutput $compilerLog
if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $outputFile)) {
    if (Test-Path -LiteralPath $compilerLog) { Get-Content -LiteralPath $compilerLog | Write-Host }
    throw "Fallo de compilacion: $($process.ExitCode)"
}
}
try {
    foreach ($name in $variants) {
        $destination = Join-Path $project "Output\$name"
        $resources = Join-Path $destination 'Resources'
        New-Item -ItemType Directory -Force $resources | Out-Null
        if (!$ResourcesOnly) {
            Copy-Item -LiteralPath $outputFile -Destination (Join-Path $destination 'Install_Update.exe') -Force
        }
        foreach ($file in $files) {
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot "packages\$name\Resources\$file") -Destination $resources -Force
        }
        Copy-Item -LiteralPath $icon -Destination $resources -Force
        Write-Host "Paquete preparado: $destination"
    }
} finally {
    if (Test-Path -LiteralPath $outputFile) { Remove-Item -LiteralPath $outputFile }
}
Write-Host 'Edita source/packages; los archivos gestionados de Output se regeneran.'
