#Include Changelog.ahk
#Include UpdaterState.ahk
#Include Painter.ahk

class UpdaterView {
    static MinWidth := 860
    static MinHeight := 560
    static SidebarWidth := 218
    static Gap := 16
    static Padding := 20
    static FontFace := "Segoe UI"
    ; Palette in RGB. Every entry is a grey, so the same values serve GDI COLORREF calls.
    static Colors := {Window: 0x191919, Sidebar: 0x111111, SidebarBorder: 0x303030,
        Panel: 0x222222, PanelBorder: 0x383838, Pill: 0x2B2B2B, PillText: 0xF0F0F0, Indicator: 0xFFFFFF,
        Track: 0x393939, Bar: 0xD8D8D8}
    static Radius := {Panel: 10, Pill: 8, Button: 8}

    __New(texts, resources, state, version, onInstall, onClose, onLog) {
        this.Texts := texts
        this.State := state
        this.AppVersion := version
        this.Message := ""
        this.ButtonStyles := Map()
        this.Rects := Map()
        this.Scale := A_ScreenDPI / 96
        this.Progress := {Value: 0, Marquee: false, Offset: 0}
        this.PillFont := UpdaterView.CreateFont(10, true)
        ; Panels, the navigation pill and the progress bar are painted by OnPaint with GDI+ instead of
        ; stacked Text controls. WS_CLIPCHILDREN keeps that painting off the controls and WS_EX_COMPOSITED
        ; double-buffers the window, so resizing never leaves half-painted frames behind.
        this.Gui := Gui("+Resize +MinSize" UpdaterView.MinWidth "x" UpdaterView.MinHeight " +0x2000000 +E0x2000000", this.Text("WindowTitle"))
        window := this.Gui
        window.BackColor := "191919"
        window.SetFont("s10 cEAEAEA", UpdaterView.FontFace)
        if FileExist(resources "\update.ico") {
            this.Icon := window.AddPicture("x24 y22 w64 h64 Icon1 Background111111", resources "\update.ico")
            SendMessage(0x80, 0, LoadPicture(resources "\update.ico", "w16 h16", &imageType), window.Hwnd)
        }
        window.SetFont("s11 Bold cF3F3F3")
        window.AddText("x24 y104 w184 h28 Background111111", this.Text("AppName"))
        window.SetFont("s9 Norm cB6B6B6")
        window.AddText("x24 y138 w184 h24 Background111111", this.Text("SidebarSubtitle"))
        this.VersionLabel := window.AddText("x24 y574 w184 h24 Background111111", this.Text("VersionLabel"))
        window.SetFont("s22 Bold cF4F4F4")
        this.Title := window.AddText("x246 y28 w680 h42", this.Text("Title"))
        window.SetFont("s10 Norm cB6B6B6")
        this.Subtitle := window.AddText("x246 y80 w680 h32", this.Text("Subtitle"))
        window.SetFont("s12 Bold cF0F0F0")
        this.PackageTitle := window.AddText("x0 y0 w100 h24 Background222222", this.Text("PackageTitle"))
        this.NotesTitle := window.AddText("x0 y0 w100 h28 Background222222", this.Text("ChangelogTitle"))
        this.Notes := ChangelogView(window, ChangelogView.Read(resources "\changelog.md"))
        window.SetFont("s9 Norm cB6B6B6")
        this.Detail := window.AddText("x0 y0 w100 h38 Background222222", this.Text("Footer"))
        this.Recovery := window.AddText("x0 y0 w100 h24 Hidden Background222222", "")
        window.SetFont("s9 Bold cF0F0F0")
        this.Banner := window.AddText("x0 y0 w100 h20 Background222222", "")
        window.SetFont("s10 Norm cEAEAEA")
        this.Install := this.Button(this.Text("InstallButton"), true)
        this.Logs := this.Button(this.Text("LogButton"))
        this.Logs.Visible := false
        this.Close := this.Button(this.Text("CloseButton"))
        this.Install.OnEvent("Click", onInstall)
        this.Close.OnEvent("Click", onClose)
        this.Logs.OnEvent("Click", onLog)
        window.OnEvent("Close", onClose)
        window.OnEvent("Escape", onClose)
        this.SizeHandler := ObjBindMethod(this, "OnSize")
        window.OnEvent("Size", this.SizeHandler)
        this.PaintHandler := ObjBindMethod(this, "OnPaint")
        OnMessage(0xF, this.PaintHandler)
        this.EraseHandler := ObjBindMethod(this, "OnEraseBackground")
        OnMessage(0x14, this.EraseHandler)
        this.DrawHandler := ObjBindMethod(this, "DrawButton")
        OnMessage(0x2B, this.DrawHandler)
        this.MarqueeHandler := ObjBindMethod(this, "AdvanceMarquee")
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", window.Hwnd, "UInt", 20, "Int*", 1, "UInt", 4) ; dark title bar
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", window.Hwnd, "UInt", 33, "Int*", 2, "UInt", 4) ; rounded frame on Windows 11
        this.ApplyState()
        this.Layout(960, 620)
    }

    Text(key) {
        return StrReplace(StrReplace(this.Texts[key], "{brand}", this.Texts["Brand"]), "{version}", this.AppVersion)
    }

    Show() {
        this.Gui.Show("w960 h620")
        this.Close.Focus()
    }

    Destroy() {
        if this.Progress.Marquee
            SetTimer(this.MarqueeHandler, 0)
        OnMessage(0xF, this.PaintHandler, 0)
        OnMessage(0x14, this.EraseHandler, 0)
        OnMessage(0x2B, this.DrawHandler, 0)
        this.Gui.Destroy()
        DllCall("DeleteObject", "Ptr", this.PillFont)
        Painter.Shutdown()
    }

    static CreateFont(pointSize, bold) {
        return DllCall("CreateFont", "Int", -Round(pointSize * A_ScreenDPI / 72), "Int", 0, "Int", 0, "Int", 0,
            "Int", bold ? 700 : 400, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0,
            "UInt", 5, "UInt", 0, "Str", UpdaterView.FontFace, "Ptr") ; DEFAULT_CHARSET, CLEARTYPE_QUALITY
    }

    Physical(value) {
        return Round(value * this.Scale)
    }

    PhysicalRect(rect) {
        return [this.Physical(rect[1]), this.Physical(rect[2]), this.Physical(rect[3]), this.Physical(rect[4])]
    }

    OnSize(window, minMax, width, height) {
        if minMax != -1
            this.Layout(width, height)
    }

    Layout(width, height) {
        ; Coordinates are AHK logical units; OnPaint scales the painted rectangles to pixels.
        side := UpdaterView.SidebarWidth, padding := UpdaterView.Padding, gap := UpdaterView.Gap
        x := side + 28, w := width - x - 28, inner := w - 2 * padding
        packageY := 122, packageH := 54
        notesY := packageY + packageH + gap
        ; Status banner: beside the buttons when it fits, otherwise on its own row above them.
        buttonsW := 186 + 12 + 128
        bannerLeft := x + padding + (this.Logs.Visible ? 130 + 12 : 0)
        bannerRoom := x + w - padding - buttonsW - 12 - bannerLeft
        size := UpdaterView.MeasureText(SendMessage(0x31, 0, 0, this.Banner.Hwnd), this.Banner.Text)
        lineH := Max(16, Round(size[2] / this.Scale))
        textW := Round(size[1] / this.Scale) + 4
        stacked := textW > bannerRoom
        bannerH := stacked ? lineH * (textW > inner ? 2 : 1) : lineH
        actionsH := stacked ? bannerH + 70 : 60
        actionY := height - 20 - actionsH
        buttonY := actionY + actionsH - 48
        notesBottom := actionY - gap
        progressH := 8
        progressY := notesBottom - 12 - progressH
        hasRecovery := this.Recovery.Visible
        recoveryY := progressY - 8 - 24
        detailY := (hasRecovery ? recoveryY - 4 : progressY - 8) - 38
        noteTop := notesY + 50
        this.Rects["Pill"] := [16, 190, side - 32, 44]
        this.Rects["Package"] := [x, packageY, w, packageH]
        this.Rects["Notes"] := [x, notesY, w, notesBottom - notesY]
        this.Rects["Actions"] := [x, actionY, w, actionsH]
        this.Rects["Progress"] := [x + padding, progressY, inner, progressH]
        this.VersionLabel.Move(24, height - 46, 184, 24)
        this.Title.Move(x, 28, w, 42)
        this.Subtitle.Move(x, 80, w, 32)
        this.PackageTitle.Move(x + padding, packageY + 15, inner, 24)
        this.NotesTitle.Move(x + padding, notesY + 15, inner, 28)
        this.Notes.Move(x + padding, noteTop, inner, Max(80, detailY - 8 - noteTop))
        this.Detail.Move(x + padding, detailY, inner, 38)
        this.Recovery.Move(x + padding, recoveryY, inner, 24)
        if stacked
            this.Banner.Move(x + padding, actionY + 12, inner, bannerH)
        else
            this.Banner.Move(bannerLeft, actionY + (actionsH - lineH) // 2, Max(1, bannerRoom), lineH)
        this.Close.Move(x + w - padding - 128, buttonY, 128, 36)
        this.Install.Move(x + w - padding - buttonsW, buttonY, 186, 36)
        this.Logs.Move(x + padding, buttonY, 130, 36)
        this.LastSize := {Width: width, Height: height}
        ; The painted surfaces moved along with the controls: repaint the whole window once, children included.
        DllCall("RedrawWindow", "Ptr", this.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x85)
    }

    ApplyState() {
        state := this.State.Value
        ; Status banner: the engine message when there is one, otherwise the label of the current state.
        this.Banner.Text := this.Message != "" ? this.Message : this.Text(state = "Disabled" ? "PreviewStatus" : "State" state)
        this.Install.Enabled := this.State.CanInstall() || (!this.State.Disabled && state = "RestartRequired")
        this.Close.Enabled := state != "Installing"
        this.Install.Text := this.Text(state = "RestartRequired" ? "RestartButton" : (state = "Error" ? "RetryButton" : "InstallButton"))
        this.Close.Text := this.Text(state = "RestartRequired" ? "LaterButton" : "CloseButton")
        this.Recovery.Text := ""
        if this.State.RecoveryAvailable = 1
            this.Recovery.Text .= this.Text("RecoveryAvailable")
        if this.State.RollbackAvailable = 1
            this.Recovery.Text .= (this.Recovery.Text = "" ? "" : " · ") this.Text("RollbackAvailable")
        this.Recovery.Visible := this.Recovery.Text != ""
        if this.HasOwnProp("LastSize")
            this.Layout(this.LastSize.Width, this.LastSize.Height)
    }

    ; Operational message from the engine (installing, finished, failure); empty restores the state label.
    SetMessage(text) {
        this.Message := text
        this.ApplyState()
    }

    ShowLogs(visible) {
        this.Logs.Visible := !!visible
        if this.HasOwnProp("LastSize")
            this.Layout(this.LastSize.Width, this.LastSize.Height)
    }

    ; Single-line extent of text in a GDI font, in pixels: [width, height].
    static MeasureText(font, text) {
        dc := DllCall("GetDC", "Ptr", 0, "Ptr")
        previous := DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr")
        rect := Buffer(16, 0)
        DllCall("DrawText", "Ptr", dc, "Str", text, "Int", -1, "Ptr", rect, "UInt", 0x420) ; DT_CALCRECT | DT_SINGLELINE
        DllCall("SelectObject", "Ptr", dc, "Ptr", previous, "Ptr")
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", dc)
        return [NumGet(rect, 8, "Int"), NumGet(rect, 12, "Int")]
    }

    ; Progress bar: 0-100 determinate value, or an animated marquee while the engine runs a CMD.
    SetProgress(value) {
        this.Progress.Value := Max(0, Min(100, value))
        this.InvalidateProgress()
    }

    SetMarquee(active) {
        active := !!active
        if active != this.Progress.Marquee
            SetTimer(this.MarqueeHandler, active ? 30 : 0)
        this.Progress.Marquee := active
        this.Progress.Offset := 0
        this.InvalidateProgress()
    }

    AdvanceMarquee() {
        this.Progress.Offset += this.Physical(4)
        this.InvalidateProgress()
    }

    InvalidateProgress() {
        if !this.Rects.Has("Progress")
            return
        r := this.PhysicalRect(this.Rects["Progress"])
        rect := Buffer(16)
        NumPut("Int", r[1], "Int", r[2], "Int", r[1] + r[3], "Int", r[2] + r[4], rect)
        DllCall("InvalidateRect", "Ptr", this.Gui.Hwnd, "Ptr", rect, "Int", 0)
    }

    OnEraseBackground(wParam, lParam, msg, hwnd) {
        if hwnd = this.Gui.Hwnd
            return 1 ; OnPaint fills the client area itself
    }

    OnPaint(wParam, lParam, msg, hwnd) {
        if hwnd != this.Gui.Hwnd
            return
        client := Buffer(16, 0)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", client)
        width := NumGet(client, 8, "Int"), height := NumGet(client, 12, "Int")
        paint := Buffer(72, 0) ; PAINTSTRUCT
        dc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", paint, "Ptr")
        try {
            if width > 0 && height > 0 {
                ; Compose in memory and copy once, so the parent never shows a partly drawn frame.
                memory := DllCall("CreateCompatibleDC", "Ptr", dc, "Ptr")
                bitmap := DllCall("CreateCompatibleBitmap", "Ptr", dc, "Int", width, "Int", height, "Ptr")
                previous := DllCall("SelectObject", "Ptr", memory, "Ptr", bitmap, "Ptr")
                try this.Draw(memory, width, height)
                finally {
                    DllCall("BitBlt", "Ptr", dc, "Int", 0, "Int", 0, "Int", width, "Int", height, "Ptr", memory, "Int", 0, "Int", 0, "UInt", 0xCC0020)
                    DllCall("SelectObject", "Ptr", memory, "Ptr", previous, "Ptr")
                    DllCall("DeleteObject", "Ptr", bitmap)
                    DllCall("DeleteDC", "Ptr", memory)
                }
            }
        } finally {
            DllCall("EndPaint", "Ptr", hwnd, "Ptr", paint)
        }
        return 0
    }

    Draw(dc, width, height) {
        colors := UpdaterView.Colors, radius := UpdaterView.Radius
        canvas := Painter(dc)
        canvas.FillRect([0, 0, width, height], colors.Window)
        side := this.Physical(UpdaterView.SidebarWidth)
        canvas.FillRect([0, 0, side, height], colors.Sidebar)
        canvas.FillRect([side, 0, this.Physical(1), height], colors.SidebarBorder)
        for name in ["Package", "Notes", "Actions"] {
            panel := this.PhysicalRect(this.Rects[name])
            canvas.FillRoundRect(panel, this.Physical(radius.Panel), colors.Panel)
            canvas.StrokeRoundRect(panel, this.Physical(radius.Panel), colors.PanelBorder)
        }
        pill := this.PhysicalRect(this.Rects["Pill"])
        canvas.FillRoundRect(pill, this.Physical(radius.Pill), colors.Pill)
        markHeight := this.Physical(20)
        canvas.FillRoundRect([pill[1] + this.Physical(4), pill[2] + (pill[4] - markHeight) // 2, this.Physical(3), markHeight],
            this.Physical(1.5), colors.Indicator)
        this.DrawProgress(canvas, colors)
        canvas := "" ; flush GDI+ before drawing text with GDI
        this.DrawPillText(dc, pill, colors)
    }

    DrawProgress(canvas, colors) {
        r := this.PhysicalRect(this.Rects["Progress"])
        radius := r[4] / 2
        canvas.FillRoundRect(r, radius, colors.Track)
        if this.Progress.Marquee {
            span := Max(r[4], Round(r[3] * 0.3))
            start := r[1] + Mod(this.Progress.Offset, r[3] + span) - span
            left := Max(r[1], start), right := Min(r[1] + r[3], start + span)
            if right - left >= r[4]
                canvas.FillRoundRect([left, r[2], right - left, r[4]], radius, colors.Bar)
        } else if this.Progress.Value > 0 {
            canvas.FillRoundRect([r[1], r[2], Max(r[4], Round(r[3] * this.Progress.Value / 100)), r[4]], radius, colors.Bar)
        }
    }

    DrawPillText(dc, pill, colors) {
        previous := DllCall("SelectObject", "Ptr", dc, "Ptr", this.PillFont, "Ptr")
        DllCall("SetBkMode", "Ptr", dc, "Int", 1)
        DllCall("SetTextColor", "Ptr", dc, "UInt", colors.PillText)
        rect := Buffer(16)
        NumPut("Int", pill[1] + this.Physical(20), "Int", pill[2], "Int", pill[1] + pill[3] - this.Physical(12), "Int", pill[2] + pill[4], rect)
        DllCall("DrawText", "Ptr", dc, "Str", this.Text("Navigation"), "Int", -1, "Ptr", rect, "UInt", 0x8824) ; left, vcenter, single line, no prefix, ellipsis
        DllCall("SelectObject", "Ptr", dc, "Ptr", previous, "Ptr")
    }

    Button(caption, primary := false) {
        ctrl := this.Gui.AddButton("x0 y0 w100 h36", caption)
        this.ButtonStyles[ctrl.Hwnd] := primary
        style := DllCall("GetWindowLongPtr", "Ptr", ctrl.Hwnd, "Int", -16, "Ptr")
        DllCall("SetWindowLongPtr", "Ptr", ctrl.Hwnd, "Int", -16, "Ptr", (style & ~0xF) | 0xB) ; BS_OWNERDRAW
        return ctrl
    }

    DrawButton(wParam, lParam, *) {
        hwnd := NumGet(lParam, 24, "Ptr")
        if !this.ButtonStyles.Has(hwnd)
            return
        dc := NumGet(lParam, 24 + A_PtrSize, "Ptr")
        rect := lParam + 24 + 2 * A_PtrSize
        left := NumGet(rect, 0, "Int"), top := NumGet(rect, 4, "Int")
        right := NumGet(rect, 8, "Int"), bottom := NumGet(rect, 12, "Int")
        flags := NumGet(lParam, 16, "UInt")
        primary := this.ButtonStyles[hwnd], disabled := flags & 4, pressed := flags & 1
        face := disabled ? 0x292929 : (primary ? (pressed ? 0xBDBDBD : 0xE3E3E3) : (pressed ? 0x393939 : 0x2B2B2B))
        box := [left, top, right - left, bottom - top]
        radius := this.Physical(UpdaterView.Radius.Button)
        canvas := Painter(dc)
        canvas.FillRect(box, UpdaterView.Colors.Panel) ; buttons sit on a panel: keep the corners seamless
        canvas.FillRoundRect(box, radius, face)
        if !primary && !disabled
            canvas.StrokeRoundRect(box, radius, 0x555555)
        if flags & 0x10 ; keyboard focus ring
            canvas.StrokeRoundRect([left + 2, top + 2, right - left - 4, bottom - top - 4], Max(1, radius - 2), primary ? 0x171717 : 0xDDDDDD)
        canvas := ""
        DllCall("SetBkMode", "Ptr", dc, "Int", 1)
        DllCall("SetTextColor", "Ptr", dc, "UInt", disabled ? 0x999999 : (primary ? 0x171717 : 0xDDDDDD))
        font := SendMessage(0x31, 0, 0, hwnd)
        previous := DllCall("SelectObject", "Ptr", dc, "Ptr", font, "Ptr")
        DllCall("DrawText", "Ptr", dc, "Str", GuiCtrlFromHwnd(hwnd).Text, "Int", -1, "Ptr", rect, "UInt", 0x825) ; centred, single line, no prefix
        DllCall("SelectObject", "Ptr", dc, "Ptr", previous, "Ptr")
        return true
    }
}
