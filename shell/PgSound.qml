import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Page {
    title: "Som"
    subtitle: Audio.sink ? "Saída: " + Audio.label(Audio.sink) : "Nenhuma saída de áudio"

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
            a11y: "Volume de " + line.name
            to: 1.5
            value: line.node?.audio?.volume ?? 0
            onMoved: line.node.audio.volume = value
        }
        Tx { mono: true; text: Math.round((line.node?.audio?.volume ?? 0) * 100) + "%"; Layout.preferredWidth: 54; horizontalAlignment: Text.AlignRight }
        Swt { a11y: "Ativar " + line.name; checked: !(line.node?.audio?.muted ?? false); onToggled: line.node.audio.muted = !checked }
    }

    Sec { title: "Volume" }
    VolumeLine { visible: !!Audio.sink; node: Audio.sink; name: "Saída" }
    VolumeLine { visible: !!Audio.source; node: Audio.source; name: "Microfone"; onIcon: "mic"; offIcon: "micOff" }

    Sec { title: "Saída" }
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

    Sec { title: "Entrada" }
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
    Tx { visible: Audio.sources.length === 0; text: "Nenhum microfone encontrado"; dim: true }

    Sec { title: "Volume por aplicativo" }
    Repeater {
        model: Audio.streams
        VolumeLine { required property var modelData; node: modelData; name: Audio.streamLabel(modelData) }
    }
    Tx { visible: Audio.streams.length === 0; text: "Nenhum aplicativo com áudio agora."; dim: true }

    Sec { visible: !!Audio.player; title: "Tocando agora" }
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
            Tx { text: Audio.player?.trackTitle || "Sem título"; strong: true; Layout.fillWidth: true }
            Tx { text: (Audio.player?.trackArtist ?? "") + " · " + (Audio.player?.identity ?? ""); dim: true; Layout.fillWidth: true }
        }
        Btn { text: "Anterior"; enabledB: Audio.player?.canGoPrevious ?? false; onClicked: Audio.player.previous() }
        Btn { text: Audio.player?.isPlaying ? "Pausar" : "Tocar"; variant: "solid"; onClicked: Audio.player.togglePlaying() }
        Btn { text: "Próxima"; enabledB: Audio.player?.canGoNext ?? false; onClicked: Audio.player.next() }
    }
}
