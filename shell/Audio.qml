pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Io

Singleton {
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.isSink && n.isStream)
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld")) // a proxy that duplicates the real player
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    // For players without native repeat, such as browsers: seek back just before the end.
    property bool repeatOne: false
    Timer {
        interval: 500; repeat: true
        running: repeatOne && (player?.isPlaying ?? false)
        onTriggered: {
            player.positionChanged()
            if (player.canSeek && player.length > 3 && player.position >= player.length - 1.5) player.position = 0
        }
    }
    readonly property string icon: !sink?.audio || sink.audio.muted ? "volMute" : sink.audio.volume < 0.34 ? "volLow" : sink.audio.volume < 0.67 ? "volMid" : "som"

    onPlayerChanged: if (!player) Ui.mediaOpen = false

    function label(n) { return n.nickname || n.description || n.name }
    function streamLabel(n) { return n.properties["application.name"] || n.description || n.name }

    PwObjectTracker { objects: Pipewire.nodes.values.filter(n => n.audio) }

    IpcHandler {
        target: "media"
        function toggle(): void { Audio.player?.togglePlaying() }
        function next(): void { Audio.player?.next() }
        function prev(): void { Audio.player?.previous() }
    }
}
