class UpdaterState {
    static Names := ["Idle", "Checking", "UpdateAvailable", "Downloading", "Verifying",
        "ReadyToInstall", "Installing", "RestartRequired", "UpToDate", "Disabled", "Error"]

    __New(disabled := true) {
        this.Disabled := disabled
        this.Value := disabled ? "Disabled" : "ReadyToInstall"
        ; Unknown until an actual recovery/installation component supplies evidence.
        this.RecoveryAvailable := -1
        this.RollbackAvailable := -1
        this.RestartRequired := false
    }

    Set(value) {
        valid := false
        for name in UpdaterState.Names
            if name = value
                valid := true
        if !valid
            throw Error("Estado de updater desconocido: " value)
        this.Value := value
        if value = "RestartRequired"
            this.RestartRequired := true
    }

    CanInstall() {
        return !this.Disabled && (this.Value = "ReadyToInstall" || this.Value = "Error")
    }
}
