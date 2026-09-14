class ChangelogView {
    __New(gui, markdown) {
        static library := DllCall("LoadLibrary", "Str", "Msftedit.dll", "Ptr")
        if !library
            throw Error("No se pudo cargar el control de notas de Windows.")
        ; Native, read-only Rich Edit: multiline + autovscroll, no horizontal scroll.
        ; ES_SAVESEL (0x8000) keeps the selection when focused; without it the control selects
        ; all its text on focus and scrolls the notes to the end.
        this.Control := gui.AddCustom("ClassRICHEDIT50W x0 y0 w100 h100 +0x208844 -E0x200 -Border +Tabstop")
        this.Hwnd := this.Control.Hwnd
        SendMessage(0x443, 0, 0x222222, this.Hwnd) ; EM_SETBKGNDCOLOR
        SendMessage(0x448, 0, 0, this.Hwnd) ; EM_SETTARGETDEVICE: wrap to viewport
        try DllCall("uxtheme\SetWindowTheme", "Ptr", this.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        this.SetMarkdown(markdown)
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
        SendMessage(0xB6, 0, -100000, this.Hwnd)
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
}

