import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets

// Now playing, tinted by the cover. The three dots and the menu morph it into the sound and likes views.
Item {
    id: card
    property bool open: false
    readonly property int fullHeight: 656
    readonly property var player: Audio.player
    property string view: "player"
    property real t: view === "player" ? 0 : 1
    Behavior on t { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    function lerp(a, b) { return a + (b - a) * t }

    height: open && player ? fullHeight : 0
    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    clip: true
    onHeightChanged: if (height === 0) { view = "player"; sync() }

    readonly property string liveTitle: player?.trackTitle ?? ""
    property int dir: 1
    property string title: ""
    property string artist: ""
    property string art: ""
    readonly property bool liked: Likes.has(title, artist)
    function sync() {
        title = liveTitle
        artist = player?.trackArtist ?? ""
        art = player?.trackArtUrl ?? ""
    }
    Component.onCompleted: sync()
    onLiveTitleChanged: {
        if (open && height > 0 && title) swap.restart()
        else sync()
    }
    // Art and artist can arrive after the title.
    Connections {
        target: card.player
        function onTrackArtUrlChanged() { if (!swap.running) card.sync() }
        function onTrackArtistChanged() { if (!swap.running) card.sync() }
    }
    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation { target: moving; property: "x"; to: -40 * card.dir; duration: 130; easing.type: Easing.InCubic }
            NumberAnimation { target: moving; property: "opacity"; to: 0; duration: 130 }
        }
        ScriptAction { script: { card.sync(); moving.x = 40 * card.dir } }
        ParallelAnimation {
            NumberAnimation { target: moving; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: moving; property: "opacity"; to: 1; duration: 220 }
        }
        ScriptAction { script: card.sync() }
    }

    // Colors from the cover. Lightness is fixed so text contrast holds for any album.
    ColorQuantizer { id: quant; source: card.art; depth: 3; rescaleSize: 64 }
    readonly property color seed: {
        let best = null, score = -1
        for (const c of quant.colors) {
            const s = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5))
            if (s > score) { score = s; best = c }
        }
        return best ?? Theme.accent
    }
    // On light glass the tint washes the cover out instead of darkening it, and the accent goes deep enough for white on it.
    readonly property color tone: Qt.hsla(seed.hslHue, Math.min(seed.hslSaturation, 0.45), Theme.light ? 0.93 : 0.12, Theme.light ? 0.6 : 0.42)
    readonly property color accent: Qt.hsla(seed.hslHue, Math.max(0.55, seed.hslSaturation), Theme.light ? 0.28 : 0.66, 1)
    readonly property color accentInk: Theme.light ? Theme.accentInk : "#10151C"

    Item {
        width: card.width; height: card.fullHeight
        Image {
            id: backdrop
            anchors.fill: parent
            source: card.art
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(240, 240)
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: backdrop
            blurEnabled: true; blur: 1; blurMax: 64
            opacity: backdrop.status === Image.Ready ? 0.32 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        Rectangle {
            anchors.fill: parent
            color: card.tone
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Header
        Btn {
            x: 16; y: 12; variant: "quiet"; icon: card.view === "player" ? "menu" : "left"; implicitHeight: 44
            a11y: card.view === "player" ? Tr.t("See likes") : Tr.t("Back to the music")
            onClicked: card.view = card.view === "player" ? "likes" : "player"
        }
        Tx {
            y: 12; height: 44; width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: card.view === "player" ? Tr.t("NOW PLAYING") : card.view === "sound" ? Tr.t("SOUND") : Tr.t("LIKES")
            size: 14; strong: true; font.letterSpacing: 1.6
        }
        Btn {
            x: parent.width - 60; y: 12; variant: "quiet"; icon: "dots"; implicitHeight: 44
            visible: card.view === "player"
            a11y: Tr.t("Volume and sound output")
            onClicked: card.view = "sound"
        }

        // Cover and title: travel between the big centered layout and the compact one.
        Item {
            id: moving
            width: parent.width; height: parent.height
            ClippingRectangle {
                x: card.lerp((card.width - 300) / 2, 20); y: 64
                width: card.lerp(300, 72); height: width
                radius: card.lerp(18, 12); color: Theme.raised
                Ic { anchors.centerIn: parent; name: "music"; size: parent.width / 3; color: Theme.muted; visible: cover.status !== Image.Ready }
                Image {
                    id: cover
                    anchors.fill: parent
                    source: card.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(600, 600)
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
            }
            Column {
                x: 24; y: 380; width: parent.width - 48; spacing: 2
                opacity: 1 - card.t
                Tx { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: card.title || Tr.t("Untitled"); size: 24 }
                Tx { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: card.artist; size: 16; dim: true }
            }
            Column {
                x: 106; y: 74; width: parent.width - 130; spacing: 2
                opacity: card.t
                Tx { width: parent.width; text: card.title || Tr.t("Untitled"); size: 18 }
                Tx { width: parent.width; text: card.artist; dim: true }
            }
        }

        // Player view
        Item {
            id: controls
            y: 442 + 24 * card.t
            width: parent.width; height: 200
            opacity: 1 - card.t
            visible: opacity > 0
            property string hint: ""
            Timer { id: hintTimer; interval: 3500; onTriggered: controls.hint = "" }
            function say(text) { hint = text; hintTimer.restart() }

            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 36
                Btn {
                    variant: "quiet"; implicitHeight: 44; icon: Audio.icon
                    a11y: Audio.sink?.audio?.muted ? Tr.t("Unmute") : Tr.t("Mute")
                    onClicked: if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted
                }
                Btn {
                    id: repeatBtn
                    readonly property bool native_: card.player?.loopSupported ?? false
                    readonly property bool on: native_ ? card.player.loopState !== MprisLoopState.None : Audio.repeatOne
                    readonly property bool one: native_ ? card.player.loopState === MprisLoopState.Track : Audio.repeatOne
                    variant: "quiet"; implicitHeight: 44; icon: one ? "repeat1" : "repeat"; iconColor: on ? card.accent : Theme.ink
                    a11y: !on ? Tr.t("Repeat") : one ? Tr.t("Repeating this song") : Tr.t("Repeating the list")
                    onClicked: {
                        if (native_) {
                            const s = card.player.loopState
                            card.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                        } else if (!card.player?.canSeek) controls.say(Tr.t("%1 doesn't allow repeat from here.").arg(card.player.identity))
                        else Audio.repeatOne = !Audio.repeatOne
                    }
                }
                Btn {
                    id: shuffleBtn
                    readonly property bool on: card.player?.shuffle ?? false
                    readonly property string why: Tr.t("%1 doesn't allow shuffle from here. Use the site's button.").arg(card.player?.identity ?? Tr.t("This player"))
                    variant: "quiet"; implicitHeight: 44; icon: "shuffle"; iconColor: on ? card.accent : Theme.ink
                    enabledB: card.player?.shuffleSupported ?? false
                    a11y: !enabledB ? why : on ? Tr.t("Shuffle on") : Tr.t("Shuffle")
                    onClicked: card.player.shuffle = !on
                    // Over the button's own mouse area when disabled: no hover highlight, but a click still says why.
                    MouseArea { anchors.fill: parent; visible: !shuffleBtn.enabledB; hoverEnabled: true; onClicked: controls.say(shuffleBtn.why) }
                }
                Btn {
                    variant: "quiet"; implicitHeight: 44; icon: "heart"; iconFilled: card.liked; iconColor: card.liked ? card.accent : Theme.ink
                    a11y: card.liked ? Tr.t("Remove from likes") : Tr.t("Like")
                    onClicked: Likes.toggle(card.title, card.artist, card.art)
                }
            }

            Tx {
                visible: !!controls.hint
                y: 46; width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: controls.hint; size: 13; dim: true
            }
            Tx { visible: !controls.hint; x: 24; y: 48; text: card.clock(seek.pressed ? seek.value : card.position); mono: true; size: 13 }
            Tx { visible: !controls.hint; x: parent.width - 24 - width; y: 48; text: card.clock(card.player?.length ?? 0); mono: true; size: 13 }
            Sld {
                id: seek
                x: 24; y: 68; width: parent.width - 48
                a11y: Tr.t("Song position")
                fill: card.accent
                enabled: card.player?.canSeek ?? false
                to: Math.max(1, card.player?.length ?? 1)
                // Kept apart from value: on release the binding below restores value before this runs.
                property real target: 0
                onMoved: target = value
                onPressedChanged: if (!pressed && card.player?.canSeek) { card.player.position = target; card.position = target }
                Binding on value { when: !seek.pressed; value: card.position }
            }
            RowLayout {
                y: 104
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28
                Btn {
                    variant: "quiet"; implicitWidth: 64; implicitHeight: 64; icon: "fprev"; iconFilled: true; iconSize: 34
                    a11y: Tr.t("Previous song"); enabledB: card.player?.canGoPrevious ?? false
                    onClicked: { card.dir = -1; card.player.previous() }
                }
                Rectangle {
                    implicitWidth: 76; implicitHeight: 76; radius: 38
                    color: pm.pressed ? Qt.darker(card.accent, 1.15) : pm.containsMouse ? Qt.lighter(card.accent, 1.08) : card.accent
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Accessible.role: Accessible.Button
                    Accessible.name: card.player?.isPlaying ? Tr.t("Pause") : Tr.t("Play")
                    Ic { anchors.centerIn: parent; name: card.player?.isPlaying ? "pauseFill" : "playFill"; filled: true; size: 32; color: card.accentInk }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.player.togglePlaying() }
                }
                Btn {
                    variant: "quiet"; implicitWidth: 64; implicitHeight: 64; icon: "fnext"; iconFilled: true; iconSize: 34
                    a11y: Tr.t("Next song"); enabledB: card.player?.canGoNext ?? false
                    onClicked: { card.dir = 1; card.player.next() }
                }
            }
        }

        // Sound view
        ColumnLayout {
            x: 20; y: 152 + 24 * (1 - card.t)
            width: parent.width - 40; height: card.fullHeight - y - 20
            opacity: card.view === "sound" ? card.t : 0
            visible: card.view === "sound"
            spacing: 8
            Sec { title: Tr.t("Volume") }
            RowLayout {
                Layout.fillWidth: true; Layout.minimumHeight: 44; spacing: 12
                Btn {
                    variant: "quiet"; icon: Audio.icon; implicitHeight: 44
                    a11y: Audio.sink?.audio?.muted ? Tr.t("Unmute") : Tr.t("Mute")
                    onClicked: if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted
                }
                Sld {
                    Layout.fillWidth: true; a11y: Tr.t("Volume"); fill: card.accent; to: 1.5
                    value: Audio.sink?.audio?.volume ?? 0
                    onMoved: Audio.sink.audio.volume = value
                }
                Tx { mono: true; text: Math.round((Audio.sink?.audio?.volume ?? 0) * 100) + "%"; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignRight }
            }
            Sec { title: Tr.t("Sound output") }
            Repeater {
                model: Audio.sinks
                Rowi {
                    id: out
                    required property var modelData
                    selected: Audio.sink === modelData
                    a11y: Audio.label(modelData)
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    Ic { name: /blue/i.test(out.modelData.name) ? "head" : "speaker"; color: out.selected ? card.accent : Theme.muted }
                    Tx { text: Audio.label(out.modelData); Layout.fillWidth: true }
                    Ic { visible: out.selected; name: "check"; color: card.accent }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // Likes view
        Item {
            x: 20; y: 152 + 24 * (1 - card.t)
            width: parent.width - 40; height: card.fullHeight - y - 20
            opacity: card.view === "likes" ? card.t : 0
            visible: card.view === "likes"
            Tx {
                visible: Likes.items.length === 0
                anchors.horizontalCenter: parent.horizontalCenter; y: 40
                text: Tr.t("No likes yet. Tap the heart."); dim: true
            }
            ListView {
                anchors.fill: parent
                clip: true; spacing: 4
                model: Likes.items
                delegate: Rowi {
                    id: lk
                    required property var modelData
                    width: ListView.view.width
                    clickable: false
                    a11y: modelData.title + ", " + modelData.artist
                    ClippingRectangle {
                        implicitWidth: 44; implicitHeight: 44; radius: 8; color: Theme.raised
                        Ic { anchors.centerIn: parent; name: "music"; color: Theme.muted; visible: lkImg.status !== Image.Ready }
                        Image { id: lkImg; anchors.fill: parent; source: lk.modelData.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(88, 88); asynchronous: true }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Tx { text: lk.modelData.title; Layout.fillWidth: true }
                        Tx { text: lk.modelData.artist; dim: true; size: 13; Layout.fillWidth: true }
                    }
                    Btn {
                        variant: "quiet"; icon: "heart"; iconFilled: true; iconColor: card.accent; implicitHeight: 44
                        a11y: Tr.t("Remove %1 from likes").arg(lk.modelData.title)
                        onClicked: Likes.toggle(lk.modelData.title, lk.modelData.artist, "")
                    }
                }
            }
        }
    }

    // MPRIS only reports position on request.
    property real position: 0
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: card.open && (card.player?.isPlaying ?? false)
        onTriggered: { card.player.positionChanged(); card.position = card.player.position }
    }
    onOpenChanged: if (open && player) position = player.position
    Connections {
        target: card.player
        function onPositionChanged() { card.position = card.player.position }
    }
    function clock(s) {
        if (!(s > 0)) return "0:00"
        const m = Math.floor(s / 60), r = Math.floor(s % 60)
        return m + ":" + (r < 10 ? "0" : "") + r
    }
}
