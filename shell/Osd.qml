pragma Singleton
import QtQuick
import Quickshell

// Volume feedback, drawn by Sheet. Volume sliders in the Central already show their own value.
Singleton {
    id: osd
    property bool shown: false
    property bool armed: false
    readonly property real volume: Audio.sink?.audio?.volume ?? 0
    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    function pulse() {
        if (!armed || Ui.open) return
        if (!shown && !Ui.mediaOpen && Notifs.toasts.length === 0) Ui.sheetScreen = Ui.screen
        shown = true
        hide.restart()
    }
    Timer { running: true; interval: 1500; onTriggered: osd.armed = true } // ignore startup state
    Timer { id: hide; interval: 1400; onTriggered: osd.shown = false }
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() { osd.pulse() }
        function onMutedChanged() { osd.pulse() }
    }
}
