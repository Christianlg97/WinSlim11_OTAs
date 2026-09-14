#Requires AutoHotkey v2.0.28
#Include ..\Texts.ahk
#Include ..\UpdaterView.ahk

; Component-only test. Never includes the installer, CMD execution or elevation.
OnError((err, *) => (FileAppend(err.Message " at " err.Line "`n", "*"), ExitApp(1)))
for variant in ["WinSlim11", "WinSlim10"]
    LoadTexts(A_ScriptDir "\..\packages\" variant "\Resources\ui.ini")
resources := A_ScriptDir "\..\packages\WinSlim11\Resources"
texts := LoadTexts(resources "\ui.ini")
state := UpdaterState(true)
closing := false
view := UpdaterView(texts, resources, state, "9.9.9", (*) => 0, CloseView, (*) => 0)
if A_Args.Length && A_Args[1] = "--preview" {
    view.Show()
    return
}

Assert(value, message) {
    if !value
        throw Error(message)
}

SamplePixel(x, y) {
    return DllCall("GetPixel", "Ptr", dc, "Int", view.Physical(x), "Int", view.Physical(y), "UInt")
}

; Same teardown as the application: destroy the view first, then exit.
CloseView(*) {
    view.Destroy()
    if closing
        FileAppend("PASS: texts, notes formatting, wrap, layout, focus, scroll thumb, states, progress, repaint, hover and close`n", "*")
    ExitApp(0)
}

parsed := ChangelogView.Parse("## Subtítulo`nTexto **importante** con acentos: actualización.`n- Elemento")
Assert(parsed.Headings.Length = 1, "Missing Markdown heading")
Assert(parsed.Bold.Length = 1, "Missing inline bold")
Assert(InStr(parsed.Text, "• Elemento"), "Missing bullet")
Assert(!InStr(parsed.Text, "**"), "Unparsed Markdown")
Assert(InStr(ChangelogView.Read(A_Temp "\ws-ota-missing-" A_TickCount ".md"), "No se ha encontrado"), "Missing notes must produce a notice")
blankNotes := A_Temp "\ws-ota-blank-" A_TickCount ".md"
FileAppend("`r`n  `r`n", blankNotes)
try Assert(InStr(ChangelogView.Read(blankNotes), "Todavía no hay notas"), "Blank notes must produce a notice")
finally FileDelete(blankNotes)
Assert(!view.Install.Enabled, "Preview enabled installation")
Assert(!view.Recovery.Visible, "Unknown recovery must stay hidden")
Assert(view.VersionLabel.Text = StrReplace(texts["VersionLabel"], "{version}", "9.9.9"), "Version label incorrect")
Assert(view.Banner.Text = texts["PreviewStatus"], "Preview banner must show the disabled label")

view.Gui.Show("Hide w960 h620")
for size in [[860,560], [960,620], [1200,760]] {
    view.Gui.Show("Hide w" size[1] " h" size[2])
    view.Layout(size[1], size[2])
    view.Close.GetPos(&cx, &cy, &cw, &ch)
    view.Install.GetPos(&ix, &iy, &iw, &ih)
    Assert(ix + iw <= cx - 10, "Buttons overlap")
    Assert(cx + cw < size[1], "Close exceeds window")
    Assert(cy + ch < size[2], "Actions exceed window")
    style := DllCall("GetWindowLongPtr", "Ptr", view.Notes.Hwnd, "Int", -16, "Ptr")
    Assert(!(style & 0x100000), "Horizontal scroll style enabled")
    Assert(!(style & 0x200000), "Native vertical scroll bar must stay hidden")
    Assert(style & 0x800, "Notes must be read-only")
}
; Query the native heading charFormat, not only the parser output.
heading := view.Notes.Parsed.Headings[1]
SendMessage(0xB1, heading.Start, heading.Start + heading.Length, view.Notes.Hwnd)
charFormat := Buffer(116, 0)
NumPut("UInt", 116, charFormat)
SendMessage(0x43A, 1, charFormat.Ptr, view.Notes.Hwnd)
Assert(NumGet(charFormat, 8, "UInt") & 1, "Native heading is not bold")
Assert(NumGet(charFormat, 12, "Int") = 220, "Heading size incorrect")
SendMessage(0xB1, 0, 0, view.Notes.Hwnd)
view.Notes.Control.Focus()
selection := Buffer(8, 0)
SendMessage(0x434, 0, selection.Ptr, view.Notes.Hwnd) ; EM_EXGETSEL
Assert(NumGet(selection, 0, "Int") = 0 && NumGet(selection, 4, "Int") = 0, "Focus must not select the notes")
Assert(SendMessage(0xCE, 0, 0, view.Notes.Hwnd) = 0, "Focus must keep the notes at the top")

for value in UpdaterState.Names {
    state.Set(value)
    view.ApplyState()
    Assert(!view.Install.Enabled, "Preview unlocked by state " value)
}
state.Disabled := false
state.Set("ReadyToInstall")
view.ApplyState()
Assert(view.Install.Enabled, "Ready state cannot enable primary action")
state.Set("Installing")
view.ApplyState()
Assert(!view.Install.Enabled && !view.Close.Enabled, "Installing controls incorrect")
state.Set("RestartRequired")
view.ApplyState()
Assert(view.Install.Text = texts["RestartButton"], "Restart label incorrect")
state.RecoveryAvailable := 1
view.ApplyState()
Assert(view.Recovery.Visible, "Confirmed recovery not displayed")

; Status banner: engine messages replace the state label; short ones share the row with the buttons,
; long ones move to their own row (window is 1200 wide at this point).
Assert(view.Banner.Text = texts["StateRestartRequired"], "Banner must fall back to the state label")
view.SetMessage("Listo.")
Assert(view.Banner.Text = "Listo." && view.Rects["Actions"][4] = 60, "Short banner must share the row with the buttons")
view.ShowLogs(true)
view.Banner.GetPos(&bx, &by, &bw, &bh)
view.Install.GetPos(&ix, &iy, &iw, &ih)
view.Logs.GetPos(&lx, &ly, &lw, &lh)
Assert(bx >= lx + lw && bx + bw <= ix, "Inline banner overlaps the buttons")
view.SetMessage("La actualización ha terminado. Puedes reiniciar ahora o más tarde, pero guarda antes todo tu trabajo abierto.")
Assert(view.Rects["Actions"][4] > 60, "Long banner must move to its own row")
view.Banner.GetPos(&bx, &by, &bw, &bh)
view.Install.GetPos(&ix, &iy, &iw, &ih)
Assert(by + bh <= iy, "Stacked banner overlaps the buttons")
view.ShowLogs(false)
view.SetMessage("")
Assert(view.Banner.Text = texts["StateRestartRequired"], "Empty message must restore the state label")

; Notes scrolling: the painted thumb follows the scroll position, can be dragged and pages on track clicks.
longNotes := ""
Loop 40
    longNotes .= "- Línea " A_Index "`n"
view.Notes.SetMarkdown(longNotes)
metrics := view.Notes.Metrics()
Assert(metrics.Content > metrics.View, "Long notes must overflow the viewport")
gutter := view.PhysicalRect(view.Rects["Gutter"])
thumb := view.ThumbRect()
Assert(thumb != "" && thumb[2] = gutter[2] && thumb[4] < gutter[4], "Thumb must start at the top of the gutter")
view.Notes.ScrollTo(100000)
maxPos := view.Notes.Metrics().Pos
Assert(maxPos > 0 && Abs(maxPos - (metrics.Content - metrics.View)) <= 4, "ScrollTo must clamp to the end")
thumb := view.ThumbRect()
Assert(Abs(thumb[2] + thumb[4] - (gutter[2] + gutter[4])) <= 3, "Thumb must end at the bottom of the gutter")
view.Notes.ScrollTo(0)
thumb := view.ThumbRect()
px := thumb[1] + 2, py := thumb[2] + 4, travel := gutter[4] - thumb[4]
view.OnMouse(0, (py << 16) | px, 0x201, view.Gui.Hwnd)
Assert(view.Drag != "", "Pressing the thumb must start a drag")
view.OnMouse(0, ((py + travel // 2) << 16) | px, 0x200, view.Gui.Hwnd)
dragged := view.Notes.Metrics().Pos
Assert(Abs(dragged - maxPos / 2) <= 4, "Dragging the thumb must scroll proportionally")
view.OnMouse(0, ((py + travel // 2) << 16) | px, 0x202, view.Gui.Hwnd)
Assert(view.Drag = "", "Releasing must end the drag")
view.OnMouse(0, ((gutter[2] + gutter[4] - 2) << 16) | px, 0x201, view.Gui.Hwnd)
Assert(view.Notes.Metrics().Pos > dragged, "Clicking the track below the thumb must page down")
view.Notes.ScrollTo(0)
SendMessage(0x20A, (-120 << 16) & 0xFFFFFFFF, 0, view.Notes.Hwnd) ; one wheel notch down, unfocused
wheeled := view.Notes.Metrics().Pos
Assert(wheeled > 0, "Wheel over the notes must scroll them without focus")
SendMessage(0x20A, (120 << 16) & 0xFFFFFFFF, 0, view.Notes.Hwnd)
Assert(view.Notes.Metrics().Pos < wheeled, "Wheel up must scroll back")
view.Notes.SetMarkdown("## Titulo`n- Texto")
Assert(view.ThumbRect() = "", "Short notes must not show a thumb")
view.SetMarquee(true)
Assert(view.Progress.Marquee, "Marquee did not start")
view.SetMarquee(false)
view.SetProgress(150)
Assert(!view.Progress.Marquee && view.Progress.Value = 100, "Progress must stop the marquee and clamp to 100")

; Repaint regression: a simulated border drag must leave the painted panels intact (window surface, not screen).
state.RecoveryAvailable := -1
state.Set("Idle") ; short banner label, so the sampled area right of it stays plain panel
view.ApplyState()
view.Gui.Show("w960 h620 NoActivate")
Sleep(300)
delta := 0
Loop 60 {
    delta += A_Index <= 30 ? 3 : -3
    view.Gui.Show("w" (960 + delta) " h" (620 + delta) " NoActivate")
    Sleep(5)
}
Sleep(300)
actions := view.Rects["Actions"]
dc := DllCall("GetDCEx", "Ptr", view.Gui.Hwnd, "Ptr", 0, "UInt", 0x2, "Ptr") ; DCX_CACHE: the whole client surface, child controls included
try {
    Assert(SamplePixel(12, 300) = 0x111111, "Sidebar pixel sample failed")
    Assert(SamplePixel(actions[1] + 8, actions[2] + 30) = 0x222222, "Actions panel fill sample failed")
    Loop 5 {
        row := actions[2] + A_Index * 10
        Loop 9
            Assert(SamplePixel(actions[1] + 120 + A_Index * 20, row) = 0x222222, "Resize left artefacts in the actions panel")
    }
    ; Hover: a hot button is drawn with a different face; the subclass toggles the state on move/leave.
    view.Close.GetPos(&cx, &cy, &cw, &ch)
    idle := SamplePixel(cx + 10, cy + ch // 2)
    UpdaterView.HotButtons[view.Close.Hwnd] := true
    DllCall("InvalidateRect", "Ptr", view.Close.Hwnd, "Ptr", 0, "Int", 0)
    Sleep(200)
    Assert(SamplePixel(cx + 10, cy + ch // 2) != idle, "Hot button must change its face colour")
    UpdaterView.HotButtons.Delete(view.Close.Hwnd)
    UpdaterView.OnButtonMessage(view.Close.Hwnd, 0x200, 0, 0, 1, 0)
    Assert(UpdaterView.HotButtons.Has(view.Close.Hwnd), "Mouse move must mark the button hot")
    UpdaterView.OnButtonMessage(view.Close.Hwnd, 0x2A3, 0, 0, 1, 0)
    Assert(!UpdaterView.HotButtons.Has(view.Close.Hwnd), "Mouse leave must clear the hot state")
} finally {
    DllCall("ReleaseDC", "Ptr", view.Gui.Hwnd, "Ptr", dc)
}
view.Gui.Hide()

; Closing through the real button must tear the view down and end the process with code 0
; (regression: GDI+ used to be shut down by an exit callback before the window was destroyed).
closing := true
SetTimer(() => ExitApp(4), -5000)
view.Gui.Show("w960 h620 NoActivate")
SendMessage(0xF5, 0, 0, view.Close.Hwnd) ; BM_CLICK -> CloseView
return

