#Requires AutoHotkey v2.0.28
#SingleInstance Off
#NoTrayIcon
#Include Texts.ahk
#Include UpdaterView.ahk
;@Ahk2Exe-SetName WinSlim OTA Updater
;@Ahk2Exe-SetVersion 1.0.0.0
;@Ahk2Exe-UpdateManifest 1

; Compiled builds request elevation through the executable manifest.
; The source script also requires elevation when launched directly.
if !A_IsAdmin {
    try {
        target := A_IsCompiled ? '"' A_ScriptFullPath '"' : '"' A_AhkPath '" "' A_ScriptFullPath '"'
        for argument in A_Args
            target .= ' "' argument '"'
        Run("*RunAs " target)
    } catch {
        MsgBox("Se necesitan permisos de administrador para abrir WinSlim Update.", "WinSlim Update", "Icon!")
    }
    ExitApp()
}

testMode := A_Args.Length && A_Args[1] = "--self-test"
; Administrator preview: no system changes or reboot.
previewOnly := false
base := A_IsCompiled ? A_ScriptDir : A_ScriptDir "\..\Output\WinSlim11"
resources := base "\Resources"
texts := LoadTexts(resources "\ui.ini")
brand := texts["Brand"]
busy := false
finished := false
logFile := ""
mutex := DllCall("CreateMutex", "Ptr", 0, "Int", 0, "Str", "Local\WinSlimOTAUpdater-" brand (testMode ? "-test" : ""), "Ptr")
if A_LastError = 183
    ExitApp()
OnExit(ReleaseMutex)

ReleaseMutex(*) {
    if mutex
        DllCall("CloseHandle", "Ptr", mutex)
    return 0
}

installState := UpdaterState(previewOnly)
view := UpdaterView(texts, resources, installState, AppVersion(), StartInstall, CloseUI,
    (*) => Run('notepad.exe "' logFile '"'))
view.Show()
if testMode {
    for name in ["UpdateSCR.cmd", "basebandUPD.reg", "ui.ini", "changelog.md", "update.ico"]
        if !FileExist(resources "\" name)
            ExitApp(2)
    SetTimer(CloseUI, -500)
}

CloseUI(*) {
    global busy
    if busy {
        MsgBox("Espera a que termine la instalación.", "WinSlim OTA", "Icon!")
        return
    }
    ; Release the painted window (and GDI+) before exit callbacks run, otherwise the last repaint fails.
    view.Destroy()
    ExitApp()
}

SetUpdaterState(value) {
    installState.Set(value)
    view.ApplyState()
}

AppVersion() {
    ; The compiled EXE carries the version resource written by ;@Ahk2Exe-SetVersion; the source reads the same directive.
    version := "0.0.0.0"
    try {
        if A_IsCompiled
            version := FileGetVersion(A_ScriptFullPath)
        else if RegExMatch(FileRead(A_ScriptFullPath), "m)^;@Ahk2Exe-SetVersion\s+(\S+)", &match)
            version := match[1]
    }
    return RegExReplace(version, "\.0$")
}

StartInstall(*) {
    global busy, finished, logFile
    if testMode || previewOnly
        return
    if finished {
        if MsgBox("¿Reiniciar ahora? Guarda antes tu trabajo.", "WinSlim OTA", "YesNo Icon?") = "Yes"
            Run(A_WinDir "\System32\shutdown.exe /r /t 0", , "Hide")
        return
    }
    busy := true
    SetUpdaterState("Installing")
    view.SetMessage(view.Text("InstallingDetail"))
    try {
        for name in ["UpdateSCR.cmd", "basebandUPD.reg"]
            if !FileExist(resources "\" name)
                throw Error("Falta el archivo obligatorio: " name)
        logDir := A_AppDataCommon "\WinSlim\OTA\Logs"
        DirCreate(logDir)
        logFile := logDir "\" FormatTime(, "yyyyMMdd-HHmmss") "-" DllCall("GetCurrentProcessId") ".log"
        view.SetMarquee(true)
        EnvSet("WS_OTA_RES", resources)
        EnvSet("WS_OTA_LOG", logFile)
        ; The updater imports the REG itself, before the CMD, so a package CMD can never skip it.
        LogLine("Importando basebandUPD.reg")
        code := RunLogged('chcp 65001 >nul & reg.exe import "%WS_OTA_RES%\basebandUPD.reg"')
        if code != 0
            throw Error("No se pudo importar basebandUPD.reg (código " code "). Consulta la actividad.")
        LogLine("Ejecutando UpdateSCR.cmd")
        code := RunLogged('"%WS_OTA_RES%\UpdateSCR.cmd"')
        if code != 0
            throw Error("El CMD terminó con el código " code ". Puede haber cambios parciales; consulta el registro.")
        SetUpdaterState("RestartRequired")
        view.SetMessage(view.Text("InstalledDetail"))
        finished := true
    } catch as failure {
        SetUpdaterState("Error")
        view.SetMessage(failure.Message)
    } finally {
        view.SetMarquee(false)
        view.SetProgress(finished ? 100 : 0)
        busy := false
        view.ShowLogs(logFile != "" && FileExist(logFile))
    }
}

; Appends a timestamped line to the activity log, in the same UTF-8 format as the CMD output.
LogLine(text) {
    FileAppend("[" FormatTime(, "dd/MM/yyyy HH:mm:ss") "] " text "`r`n", logFile, "UTF-8-RAW")
}

; Runs a command line through cmd.exe, hidden, appending its output to the activity log; returns the exit code.
RunLogged(command) {
    return RunWait(A_ComSpec ' /D /V:OFF /S /C "' command ' >> "%WS_OTA_LOG%" 2>&1"', resources, "Hide")
}

