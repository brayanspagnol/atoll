pragma Singleton
import QtQuick
import Quickshell
import "parse.js" as P

Singleton {
    id: root
    function apply() {
        Quickshell.execDetached(Cfg.v.nightOn ? ["hyprctl", "hyprsunset", "temperature", String(Cfg.v.nightK)] : ["hyprctl", "hyprsunset", "identity"])
    }
    // Acts only when the schedule changes its mind, so a manual toggle lasts until the next start or end.
    property var wanted: null
    function tick() {
        if (!Cfg.v.nightAuto) { wanted = null; return }
        const want = P.inWindow(Qt.formatTime(new Date(), "hh:mm"), Cfg.v.nightFrom, Cfg.v.nightTo)
        if (want === wanted) return
        wanted = want
        if (Cfg.v.nightOn !== want) { Cfg.v.nightOn = want; apply() }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.tick() }
    Connections { target: Cfg.v; function onNightAutoChanged() { root.tick() } function onNightFromChanged() { root.wanted = null; root.tick() } function onNightToChanged() { root.wanted = null; root.tick() } }
}
