pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Volume and brightness feedback, drawn inside the island. Volume sliders in the Central already show their own value.
Singleton {
    id: osd
    property bool shown: false
    property bool armed: false
    property string kind: "volume" // or "brightness"
    readonly property real volume: Audio.sink?.audio?.volume ?? 0
    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    // 0 to 1.5 for volume (above 1 is boosted), 0 to 1 for brightness.
    readonly property real level: kind === "brightness" ? Math.max(0, Bright.panel) / 100 : muted ? 0 : volume
    function pulse(k) {
        if (!armed || Ui.open) return
        kind = k ?? "volume"
        if (!shown && !Ui.mediaOpen && Notifs.toasts.length === 0) Ui.sheetScreen = Ui.screen
        shown = true
        hide.restart()
    }
    Timer { running: true; interval: 1500; onTriggered: osd.armed = true } // ignore startup state
    Timer { id: hide; interval: 1400; onTriggered: osd.shown = false }
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() { osd.pulse("volume") }
        function onMutedChanged() { osd.pulse("volume") }
    }
    // The brightness keys run brightnessctl and then this (hypr/binds.lua): the panel has no change signal to watch.
    IpcHandler {
        target: "osd"
        function brightness(): void { Bright.refreshPanel(); osd.pulse("brightness") }
    }
}
