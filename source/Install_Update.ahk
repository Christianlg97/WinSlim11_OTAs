#Requires AutoHotkey v2.0.28
#SingleInstance Off
#NoTrayIcon
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
previewOnly := true
base := A_IsCompiled ? A_ScriptDir : A_ScriptDir "\..\Output\WinSlim11"
resources := base "\Resources"
brand := IniRead(resources "\brand.ini", "Brand", "Name", "WinSlim 11")
if brand != "WinSlim 11" && brand != "WinSlim 10"
    brand := "WinSlim 11"
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

ui := Gui(, UiText("WindowTitle", "{brand} · Update"))
if FileExist(resources "\update.ico")
    TraySetIcon(resources "\update.ico")
ui.BackColor := "191919"
ui.SetFont("s10 cEAEAEA", "Segoe UI")
ui.AddText("x0 y0 w218 h620 Background111111", "")
ui.AddText("x218 y0 w1 h620 Background303030", "")
if FileExist(resources "\update.ico")
    ui.AddPicture("x24 y22 w64 h64 Icon1", resources "\update.ico")
ui.SetFont("s12 Bold cF3F3F3")
ui.AddText("x24 y104 w180 h25 Background111111", UiText("AppName", "WinSlim Update"))
ui.SetFont("s9 Norm cA6A6A6")
ui.AddText("x24 y134 w180 h20 Background111111", UiText("SidebarSubtitle", "{brand} / OTA"))
ui.AddText("x16 y190 w186 h44 Background2B2B2B", "")
ui.AddText("x20 y201 w3 h22 Background53D4ED", "")
ui.SetFont("s10 cFFFFFF")
ui.AddText("x38 y203 w150 h22 Background2B2B2B", UiText("Navigation", "Paquete OTA"))
ui.SetFont("s9 c929292")
ui.AddText("x24 y544 w180 h20 Background111111", UiText("AppName", "WinSlim Update"))
ui.AddText("x24 y566 w180 h20 Background111111", "Instalación deshabilitada")
ui.SetFont("s23 Bold cF4F4F4")
ui.AddText("x250 y28 w675 h44", UiText("Title", "Actualización de {brand}"))
ui.SetFont("s10 Norm cABABAB")
ui.AddText("x252 y82 w660 h28", UiText("Subtitle", "Consulta la información y las notas de este paquete."))
Panel(250, 128, 676, 60)
ui.SetFont("s10 Bold cEAEAEA")
ui.AddText("x268 y141 w420 h22 Background222222", UiText("PackageTitle", "Paquete de actualización"))
ui.SetFont("s9 Norm cAAAAAA")
ui.AddText("x268 y165 w610 h18 Background222222", UiText("PackageSummary", "Información del paquete OTA"))
Panel(250, 204, 676, 300)
ui.SetFont("s12 Bold cF0F0F0", "Segoe UI")
status := ui.AddText("x274 y220 w628 h26 Background222222", UiText("ChangelogTitle", "Descripción de la actualización"))
ui.SetFont("s10 Norm cABABAB")
notes := ui.AddEdit("x274 y255 w628 h182 ReadOnly -E0x200 -Border +VScroll Background222222 cD2D2D2", ReadChangelog())
detail := ui.AddText("x274 y449 w628 h24 Background222222", UiText("Footer", "Revisa las notas antes de continuar."))
bar := ui.AddProgress("x274 y485 w628 h3 c53D4ED Background393939", 0)
Panel(250, 520, 676, 70)
ui.SetFont("s10 cEAEAEA")
buttonStyles := Map()
OnMessage(0x2B, DrawButton)
install := FlatButton("x266 y537 w184 h36", UiText("InstallButton", "Instalar actualización"), true)
install.Enabled := false
logs := FlatButton("x462 y537 w145 h36 Hidden", UiText("LogButton", "Ver actividad"))
later := FlatButton("x768 y537 w142 h36", UiText("CloseButton", "Cerrar"))
install.OnEvent("Click", StartInstall)
logs.OnEvent("Click", (*) => Run('notepad.exe "' logFile '"'))
later.OnEvent("Click", CloseUI)
ui.OnEvent("Close", CloseUI)
ui.OnEvent("Escape", CloseUI)
; Native dark title bar; ignore unsupported DWM attributes on older Windows.
try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", ui.Hwnd, "UInt", 20, "Int*", 1, "UInt", 4)
ui.Show("w960 h620")
if testMode {
    for name in ["UpdateSCR.cmd", "basebandUPD.reg", "changelog.md", "brand.ini", "ui.ini", "update.ico"]
        if !FileExist(resources "\" name)
            ExitApp(2)
    SetTimer(() => ExitApp(0), -500)
}

CloseUI(*) {
    global busy
    if busy {
        MsgBox("Espera a que termine la instalación.", "WinSlim OTA", "Icon!")
        return
    }
    ExitApp()
}

Panel(x, y, w, h) {
    ui.AddText("x" x " y" y " w" w " h" h " Background383838", "")
    ui.AddText("x" (x+1) " y" (y+1) " w" (w-2) " h" (h-2) " Background222222", "")
}

UiText(key, fallback) {
    ; Plain strings only. Missing or empty fields use readable defaults.
    try value := IniRead(resources "\ui.ini", "UI", key, fallback)
    catch
        value := fallback
    if Trim(value) = ""
        value := fallback
    return StrReplace(value, "{brand}", brand)
}
ReadChangelog() {
    try text := FileRead(resources "\changelog.md", "UTF-8")
    catch
        return "No se ha encontrado Resources\changelog.md."
    if Trim(text, " `t`r`n") = ""
        return "Todavía no hay notas para esta actualización."
    ; Deliberately render a safe, readable subset as text, never HTML or script.
    text := RegExReplace(text, "m)^#{1,6}\s+", "")
    text := RegExReplace(text, "m)^\s*[-*]\s+", "• ")
    text := RegExReplace(text, "\*\*([^*]+)\*\*", "$1")
    return text
}

FlatButton(options, caption, primary := false) {
    ctrl := ui.AddButton(options, caption)
    buttonStyles[ctrl.Hwnd] := primary
    style := DllCall("GetWindowLongPtr", "Ptr", ctrl.Hwnd, "Int", -16, "Ptr")
    DllCall("SetWindowLongPtr", "Ptr", ctrl.Hwnd, "Int", -16, "Ptr", (style & ~0xF) | 0xB)
    return ctrl
}

DrawButton(wParam, lParam, *) {
    hwnd := NumGet(lParam, 24, "Ptr")
    if !buttonStyles.Has(hwnd)
        return
    dc := NumGet(lParam, 24 + A_PtrSize, "Ptr")
    rect := lParam + 24 + 2*A_PtrSize
    left := NumGet(rect, 0, "Int"), top := NumGet(rect, 4, "Int")
    right := NumGet(rect, 8, "Int"), bottom := NumGet(rect, 12, "Int")
    flags := NumGet(lParam, 16, "UInt")
    background := DllCall("CreateSolidBrush", "UInt", 0x222222, "Ptr")
    DllCall("FillRect", "Ptr", dc, "Ptr", rect, "Ptr", background)
    DllCall("DeleteObject", "Ptr", background)
    primary := buttonStyles[hwnd]
    disabled := flags & 4
    bg := disabled ? 0x292929 : (primary ? ((flags & 1) ? 0xBDBDBD : 0xE3E3E3) : ((flags & 1) ? 0x393939 : 0x2B2B2B))
    brush := DllCall("CreateSolidBrush", "UInt", bg, "Ptr")
    pen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", primary ? bg : 0x484848, "Ptr")
    oldBrush := DllCall("SelectObject", "Ptr", dc, "Ptr", brush, "Ptr")
    oldPen := DllCall("SelectObject", "Ptr", dc, "Ptr", pen, "Ptr")
    DllCall("RoundRect", "Ptr", dc, "Int", left, "Int", top, "Int", right, "Int", bottom, "Int", 12, "Int", 12)
    DllCall("SetBkMode", "Ptr", dc, "Int", 1)
    DllCall("SetTextColor", "Ptr", dc, "UInt", disabled ? 0x777777 : (primary ? 0x171717 : 0xDDDDDD))
    font := SendMessage(0x31, 0, 0, hwnd)
    oldFont := DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr")
    DllCall("DrawText", "Ptr", dc, "Str", GuiCtrlFromHwnd(hwnd).Text, "Int", -1, "Ptr", rect, "UInt", 0x25)
    if flags & 0x10 {
        focusRect := Buffer(16)
        NumPut("Int", left+4, "Int", top+4, "Int", right-4, "Int", bottom-4, focusRect)
        DllCall("DrawFocusRect", "Ptr", dc, "Ptr", focusRect)
    }
    DllCall("SelectObject", "Ptr", dc, "Ptr", oldFont)
    DllCall("SelectObject", "Ptr", dc, "Ptr", oldBrush)
    DllCall("SelectObject", "Ptr", dc, "Ptr", oldPen)
    DllCall("DeleteObject", "Ptr", brush)
    DllCall("DeleteObject", "Ptr", pen)
    return true
}

StartInstall(*) {
    global busy, finished, resources, base, logFile, mutex
    if testMode || previewOnly
        return
    if finished {
        if MsgBox("¿Reiniciar ahora? Guarda antes tu trabajo.", "WinSlim OTA", "YesNo Icon?") = "Yes"
            Run(A_WinDir "\System32\shutdown.exe /r /t 0", , "Hide")
        return
    }
    if !A_IsAdmin {
        try {
            target := A_IsCompiled ? '"' A_ScriptFullPath '"' : '"' A_AhkPath '" "' A_ScriptFullPath '"'
            DllCall("CloseHandle", "Ptr", mutex)
            mutex := 0
            Run("*RunAs " target, base)
            ExitApp()
        } catch {
            mutex := DllCall("CreateMutex", "Ptr", 0, "Int", 0, "Str", "Local\WinSlimOTAUpdater", "Ptr")
            MsgBox("No se concedieron permisos. Puedes volver a intentarlo.", "WinSlim OTA", "Icon!")
            return
        }
    }
    busy := true
    install.Enabled := false
    later.Enabled := false
    try {
        for name in ["UpdateSCR.cmd", "basebandUPD.reg"]
            if !FileExist(resources "\" name)
                throw Error("Falta el archivo obligatorio: " name)
        logDir := A_AppDataCommon "\WinSlim\OTA\Logs"
        DirCreate(logDir)
        logFile := logDir "\" FormatTime(, "yyyyMMdd-HHmmss") "-" DllCall("GetCurrentProcessId") ".log"
        status.Text := "Aplicando la actualización…"
        detail.Text := "No cierres el equipo. El registro recoge la salida del CMD."
        bar.Opt("+0x8")
        SendMessage(0x40A, 1, 30, bar)
        EnvSet("WS_OTA_RES", resources)
        EnvSet("WS_OTA_LOG", logFile)
        code := RunWait(A_ComSpec ' /D /V:OFF /S /C ""%WS_OTA_RES%\UpdateSCR.cmd" >> "%WS_OTA_LOG%" 2>&1"', resources, "Hide")
        if code != 0
            throw Error("El CMD terminó con el código " code ". Puede haber cambios parciales; consulta el registro.")
        status.Text := "Actualización instalada"
        detail.Text := "Puedes reiniciar ahora o continuar trabajando y hacerlo más tarde."
        finished := true
        install.Text := "Reiniciar ahora"
        later.Text := "Más tarde"
    } catch as failure {
        status.Text := "La actualización no se ha completado"
        detail.Text := failure.Message
        install.Text := "Reintentar"
    } finally {
        SendMessage(0x40A, 0, 0, bar)
        bar.Opt("-0x8")
        bar.Value := finished ? 100 : 0
        busy := false
        install.Enabled := true
        later.Enabled := true
        logs.Visible := logFile != "" && FileExist(logFile)
    }
}





