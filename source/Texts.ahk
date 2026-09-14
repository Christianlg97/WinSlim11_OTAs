; UI text source: UTF-8 ui.ini. No executable expressions or hidden defaults.
LoadTexts(path) {
    text := LTrim(FileRead(path, "UTF-8"), Chr(0xFEFF))
    fields := Map()
    active := false
    for line in StrSplit(StrReplace(text, "`r`n", "`n"), "`n") {
        line := Trim(line)
        if line = "" || SubStr(line, 1, 1) = ";"
            continue
        if SubStr(line, 1, 1) = "[" {
            active := line = "[UI]"
            continue
        }
        if !active
            continue
        pos := InStr(line, "=")
        if !pos
            throw Error("Campo inválido en ui.ini: " line)
        key := Trim(SubStr(line, 1, pos - 1))
        if fields.Has(key)
            throw Error("Campo duplicado en ui.ini: " key)
        fields[key] := Trim(SubStr(line, pos + 1))
    }
    for key in ["Brand", "WindowTitle", "AppName", "SidebarSubtitle", "Navigation", "Title", "Subtitle", "PackageTitle", "ChangelogTitle", "Footer", "InstallButton", "LogButton", "CloseButton", "PreviewStatus",
        "VersionLabel", "StateIdle", "StateChecking", "StateUpdateAvailable", "StateDownloading", "StateVerifying", "StateReadyToInstall", "StateInstalling", "StateRestartRequired", "StateUpToDate", "StateError",
        "RecoveryAvailable", "RollbackAvailable", "RestartButton", "LaterButton", "RetryButton", "InstallingDetail", "InstalledDetail"]
        if !fields.Has(key)
            throw Error("Falta el campo " key " en ui.ini")
    return fields
}
