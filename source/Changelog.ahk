class ChangelogView {
    static WheelProc := 0
    static Instances := Map()

    __New(gui, markdown, onScroll := (*) => 0) {
        static library := DllCall("LoadLibrary", "Str", "Msftedit.dll", "Ptr")
        if !library
            throw Error("No se pudo cargar el control de notas de Windows.")
        this.OnScroll := onScroll
        ; Native, read-only Rich Edit: multiline + autovscroll, no scroll bars of its own (the owner
        ; paints a thumb from Metrics and drives ScrollTo). ES_SAVESEL (0x8000) keeps the selection
        ; when focused; without it the control selects all its text on focus and scrolls to the end.
        this.Control := gui.AddCustom("ClassRICHEDIT50W x0 y0 w100 h100 +0x8844 -E0x200 -Border +Tabstop")
        this.Hwnd := this.Control.Hwnd
        SendMessage(0x443, 0, 0x222222, this.Hwnd) ; EM_SETBKGNDCOLOR
        SendMessage(0x448, 0, 0, this.Hwnd) ; EM_SETTARGETDEVICE: wrap to viewport
        ; ENM_SCROLL | ENM_SELCHANGE: wheel and keyboard scrolling report back through EN_VSCROLL / EN_SELCHANGE.
        SendMessage(0x445, 0, 0x80004, this.Hwnd) ; EM_SETEVENTMASK
        this.Control.OnCommand(0x602, (*) => this.OnScroll())
        this.Control.OnNotify(0x702, (*) => this.OnScroll())
        ; Without WS_VSCROLL the control ignores WM_MOUSEWHEEL: a subclass turns wheel notches into line scrolls.
        if !ChangelogView.WheelProc
            ChangelogView.WheelProc := CallbackCreate(ObjBindMethod(ChangelogView, "SubclassProc"), "F", 6)
        ChangelogView.Instances[this.Hwnd] := this
        DllCall("comctl32\SetWindowSubclass", "Ptr", this.Hwnd, "Ptr", ChangelogView.WheelProc, "Ptr", 1, "Ptr", 0)
        DllCall("SystemParametersInfo", "UInt", 0x68, "UInt", 0, "UInt*", &lines := 3, "UInt", 0) ; SPI_GETWHEELSCROLLLINES
        this.WheelLines := lines
        this.SetMarkdown(markdown)
    }

    Release() {
        ChangelogView.Instances.Delete(this.Hwnd)
    }

    static SubclassProc(hwnd, msg, wParam, lParam, id, refData) {
        if msg = 0x20A && ChangelogView.Instances.Has(hwnd) {
            ChangelogView.Instances[hwnd].Wheel((wParam >> 16) & 0xFFFF)
            return 0
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    ; One wheel notch (delta 120) scrolls the system's configured number of lines, or a page.
    Wheel(delta) {
        delta -= delta > 0x7FFF ? 0x10000 : 0
        if this.WheelLines = 0xFFFFFFFF {
            SendMessage(0x115, delta < 0 ? 3 : 2, 0, this.Hwnd) ; WM_VSCROLL SB_PAGEDOWN / SB_PAGEUP
        } else {
            Loop Max(1, Round(Abs(delta) / 120 * this.WheelLines))
                SendMessage(0x115, delta < 0 ? 1 : 0, 0, this.Hwnd) ; SB_LINEDOWN / SB_LINEUP
        }
        this.OnScroll()
    }

    ; Notes source: the Markdown text, or a readable notice when the file is missing or empty.
    static Read(path) {
        try text := FileRead(path, "UTF-8")
        catch
            return "No se ha encontrado el archivo de notas: " path
        if Trim(text, " `t`r`n" Chr(0xFEFF)) = ""
            return "Todavía no hay notas para esta actualización."
        return text
    }

    static Parse(markdown) {
        result := {Text: "", Headings: [], Bold: []}
        markdown := LTrim(StrReplace(markdown, "`r", ""), Chr(0xFEFF))
        for line in StrSplit(markdown, "`n") {
            heading := RegExMatch(line, "^#{1,6}\s+(.+)$", &match)
            if heading
                line := match[1]
            else
                line := RegExReplace(line, "^\s*[-*]\s+", "• ")
            start := StrLen(result.Text)
            ; Only explicit Markdown formatting is handled; no HTML/RTF execution.
            offset := 1
            while RegExMatch(line, "\*\*([^*]+)\*\*", &bold, offset) {
                result.Bold.Push({Start: start + bold.Pos - 1, Length: StrLen(bold[1])})
                line := SubStr(line, 1, bold.Pos - 1) bold[1] SubStr(line, bold.Pos + bold.Len)
                offset := bold.Pos + StrLen(bold[1])
            }
            if heading
                result.Headings.Push({Start: start, Length: StrLen(line)})
            result.Text .= line "`r"
        }
        return result
    }

    SetMarkdown(markdown) {
        parsed := ChangelogView.Parse(markdown)
        this.Parsed := parsed
        SendMessage(0xC, 0, StrPtr(parsed.Text), this.Hwnd) ; WM_SETTEXT
        this.Format(0, -1, 10, false, 0xD2D2D2)
        for span in parsed.Headings
            this.Format(span.Start, span.Start + span.Length, 11, true, 0xF0F0F0)
        for span in parsed.Bold
            this.Format(span.Start, span.Start + span.Length, 10, true, 0xEAEAEA)
        SendMessage(0xB1, 0, 0, this.Hwnd) ; no initial selected block
        this.ScrollTo(0)
    }

    Format(start, end, size, bold, color) {
        ; CHARFORMAT2W, with size/face/color and bold explicitly set.
        charFormat := Buffer(116, 0)
        NumPut("UInt", 116, "UInt", 0xE0000001, "UInt", bold ? 1 : 0,
            "Int", size * 20, "Int", 0, "UInt", color, charFormat)
        StrPut("Segoe UI", charFormat.Ptr + 26, 32, "UTF-16")
        SendMessage(0xB1, start, end, this.Hwnd)
        SendMessage(0x444, 1, charFormat.Ptr, this.Hwnd)
    }

    Move(x, y, w, h) {
        this.Control.Move(x, y, w, h)
        SendMessage(0x448, 0, 0, this.Hwnd)
    }

    ; Scroll state in pixels: current offset, viewport height and total text height.
    Metrics() {
        client := Buffer(16, 0)
        DllCall("GetClientRect", "Ptr", this.Hwnd, "Ptr", client)
        view := NumGet(client, 12, "Int")
        point := Buffer(8, 0)
        SendMessage(0x4DD, 0, point.Ptr, this.Hwnd) ; EM_GETSCROLLPOS
        pos := NumGet(point, 4, "Int")
        return {Pos: pos, View: view, Content: this.ContentHeight(pos, view)}
    }

    ContentHeight(scroll, view) {
        ; Top of the last visual line plus its height (taken from the previous line spacing).
        lines := SendMessage(0xBA, 0, 0, this.Hwnd) ; EM_GETLINECOUNT
        if lines < 2
            return 0 ; a single visual line never overflows
        point := Buffer(8, 0)
        SendMessage(0xD6, point.Ptr, SendMessage(0xBB, lines - 1, 0, this.Hwnd), this.Hwnd) ; EM_POSFROMCHAR(EM_LINEINDEX)
        last := NumGet(point, 4, "Int")
        lineHeight := view
        if lines > 1 {
            SendMessage(0xD6, point.Ptr, SendMessage(0xBB, lines - 2, 0, this.Hwnd), this.Hwnd)
            lineHeight := last - NumGet(point, 4, "Int")
        }
        return scroll + last + lineHeight
    }

    ScrollTo(pos) {
        metrics := this.Metrics()
        point := Buffer(8, 0)
        NumPut("Int", 0, "Int", Max(0, Min(pos, metrics.Content - metrics.View)), point)
        SendMessage(0x4DE, 0, point.Ptr, this.Hwnd) ; EM_SETSCROLLPOS
        this.OnScroll()
    }
}
