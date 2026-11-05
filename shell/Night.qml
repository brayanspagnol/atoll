pragma Singleton
import QtQuick
import Quickshell

Singleton {
    function apply() {
        Quickshell.execDetached(Cfg.v.nightOn ? ["hyprctl", "hyprsunset", "temperature", String(Cfg.v.nightK)] : ["hyprctl", "hyprsunset", "identity"])
    }
}
