import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Page {
    title: Tr.t("Sound")
    subtitle: Audio.sink ? Tr.t("Output: %1").arg(Audio.label(Audio.sink)) : Tr.t("No audio output")

    component VolumeLine: RowLayout {
        id: line
        required property var node
        property string name: ""
        property string offIcon: "volMute"
        property string onIcon: "som"
        Layout.fillWidth: true
        Layout.minimumHeight: 44
        spacing: 12
        Ic { name: line.node?.audio?.muted ? line.offIcon : line.onIcon; color: line.node?.audio?.muted ? Theme.muted : Theme.ink }
        Tx { visible: !!line.name; text: line.name; Layout.preferredWidth: 110 }
        Sld {
            Layout.fillWidth: true
            a11y: Tr.t("Volume of %1").arg(line.name)
            to: 1.5
            value: line.node?.audio?.volume ?? 0
            onMoved: line.node.audio.volume = value
        }
        Tx { mono: true; text: Math.round((line.node?.audio?.volume ?? 0) * 100) + "%"; Layout.preferredWidth: 54; horizontalAlignment: Text.AlignRight }
        Swt { a11y: Tr.t("Enable %1").arg(line.name); checked: !(line.node?.audio?.muted ?? false); onToggled: line.node.audio.muted = !checked }
    }

    Sec { title: Tr.t("Volume") }
    VolumeLine { visible: !!Audio.sink; node: Audio.sink; name: Tr.t("Output") }
    VolumeLine { visible: !!Audio.source; node: Audio.source; name: Tr.t("Microphone"); onIcon: "mic"; offIcon: "micOff" }

    Sec { title: Tr.t("Output") }
    Repeater {
        model: Audio.sinks
        Rowi {
            id: so
            required property var modelData
            selected: Audio.sink === modelData
            a11y: Audio.label(modelData)
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
            Ic { name: /blue/i.test(so.modelData.name) ? "head" : "speaker"; color: so.selected ? Theme.accent : Theme.muted; Layout.preferredWidth: 20 }
            Tx { text: Audio.label(so.modelData); Layout.fillWidth: true }
            Ic { visible: so.selected; name: "check"; color: Theme.accent }
        }
    }

    Sec { title: Tr.t("Input") }
    Repeater {
        model: Audio.sources
        Rowi {
            id: si
            required property var modelData
            selected: Audio.source === modelData
            a11y: Audio.label(modelData)
            onClicked: Pipewire.preferredDefaultAudioSource = modelData
            Ic { name: "mic"; color: si.selected ? Theme.accent : Theme.muted; Layout.preferredWidth: 20 }
            Tx { text: Audio.label(si.modelData); Layout.fillWidth: true }
            Ic { visible: si.selected; name: "check"; color: Theme.accent }
        }
    }
    Tx { visible: Audio.sources.length === 0; text: Tr.t("No microphone found"); dim: true }

    Sec { title: Tr.t("Volume per app") }
    Repeater {
        model: Audio.streams
        VolumeLine { required property var modelData; node: modelData; name: Audio.streamLabel(modelData) }
    }
    Tx { visible: Audio.streams.length === 0; text: Tr.t("No app is playing audio."); dim: true }

    Sec { visible: !!Audio.player; title: Tr.t("Now playing") }
    RowLayout {
        visible: !!Audio.player
        Layout.fillWidth: true
        spacing: 12
        ClippingRectangle {
            implicitWidth: 56; implicitHeight: 56; radius: Theme.radiusSmall; color: Theme.raised
            Image { anchors.fill: parent; source: Audio.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(112, 112) }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Tx { text: Audio.player?.trackTitle || Tr.t("Untitled"); strong: true; Layout.fillWidth: true }
            Tx { text: (Audio.player?.trackArtist ?? "") + " · " + (Audio.player?.identity ?? ""); dim: true; Layout.fillWidth: true }
        }
        Btn { text: Tr.t("Previous"); enabledB: Audio.player?.canGoPrevious ?? false; onClicked: Audio.player.previous() }
        Btn { text: Audio.player?.isPlaying ? Tr.t("Pause") : Tr.t("Play"); variant: "solid"; onClicked: Audio.player.togglePlaying() }
        Btn { text: Tr.t("Next track"); enabledB: Audio.player?.canGoNext ?? false; onClicked: Audio.player.next() }
    }
}
