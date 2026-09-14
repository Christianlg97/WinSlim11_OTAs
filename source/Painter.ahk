; Minimal GDI+ wrapper: anti-aliased rectangles and rounded rectangles on a GDI device context.
; Colours are RGB (0xRRGGBB); rectangles are [x, y, w, h] arrays in pixels.
class Painter {
    static Token := 0

    static Startup() {
        if Painter.Token
            return
        DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
        input := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", 1, input)
        if DllCall("gdiplus\GdiplusStartup", "Ptr*", &token := 0, "Ptr", input, "Ptr", 0)
            throw Error("No se pudo iniciar GDI+.")
        Painter.Token := token
    }

    ; Deliberately not hooked to OnExit: exit callbacks run before the windows are destroyed, so the
    ; final repaints would fail. UpdaterView.Destroy calls this once its window is gone; a process
    ; that exits without it simply lets Windows reclaim GDI+.
    static Shutdown() {
        if !Painter.Token
            return
        DllCall("gdiplus\GdiplusShutdown", "Ptr", Painter.Token)
        Painter.Token := 0
    }

    __New(dc) {
        this.Graphics := 0
        Painter.Startup()
        if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", dc, "Ptr*", &graphics := 0)
            throw Error("No se pudo crear el lienzo GDI+.")
        this.Graphics := graphics
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4) ; AntiAlias
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4) ; Half: integer coordinates map to whole pixels
    }

    __Delete() {
        if this.Graphics
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", this.Graphics)
    }

    FillRect(rect, rgb) {
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000 | rgb, "Ptr*", &brush := 0)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", this.Graphics, "Ptr", brush,
            "Float", rect[1], "Float", rect[2], "Float", rect[3], "Float", rect[4])
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    }

    FillRoundRect(rect, radius, rgb) {
        path := Painter.RoundRectPath(rect[1], rect[2], rect[3], rect[4], radius)
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000 | rgb, "Ptr*", &brush := 0)
        DllCall("gdiplus\GdipFillPath", "Ptr", this.Graphics, "Ptr", brush, "Ptr", path)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
        DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    }

    StrokeRoundRect(rect, radius, rgb, width := 1) {
        ; Centre the stroke on the pixel grid so thin borders stay crisp.
        path := Painter.RoundRectPath(rect[1] + width / 2, rect[2] + width / 2, rect[3] - width, rect[4] - width, radius)
        DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFF000000 | rgb, "Float", width, "Int", 2, "Ptr*", &pen := 0) ; UnitPixel
        DllCall("gdiplus\GdipDrawPath", "Ptr", this.Graphics, "Ptr", pen, "Ptr", path)
        DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
        DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    }

    static RoundRectPath(x, y, w, h, radius) {
        d := Max(0.1, Min(radius * 2, w, h))
        DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path := 0)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y, "Float", d, "Float", d, "Float", 180, "Float", 90)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y, "Float", d, "Float", d, "Float", 270, "Float", 90)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x + w - d, "Float", y + h - d, "Float", d, "Float", d, "Float", 0, "Float", 90)
        DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y + h - d, "Float", d, "Float", d, "Float", 90, "Float", 90)
        DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
        return path
    }
}
