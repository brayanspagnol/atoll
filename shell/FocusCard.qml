import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "focus.js" as F

// Focus mode, dropped from the island like the music card: the timer, its length and what it holds back.
Item {
    id: card
    property bool open: false
    property bool adding: false // choosing an app to let through
    readonly property int fullHeight: body.implicitHeight + 40
    height: open ? fullHeight : 0
    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    clip: true
    onOpenChanged: if (!open) adding = false
    readonly property var allow: Focus.allow
    readonly property bool pomodoro: Cfg.v.focusPomodoro
    // Minutes in the ring: left (or so far, with no end) while it runs; the chosen length before.
    readonly property string big: Focus.running ? String(Focus.session.endsAt ? Math.ceil(Focus.seconds / 60) : Math.floor(Focus.seconds / 60))
        : pomodoro ? "25" : Focus.minutes ? String(Focus.minutes) : "∞"
    // The newest icon the app sent, for its chip.
    function iconFor(name) {
        const n = Notifs.all.slice().reverse().find(n => n.appName === name)
        return n ? Notifs.iconOf(n) : ""
    }
    function go() { if (Focus.running) Focus.stop(); else Focus.startChosen() }

    component AppChip: Rectangle {
        id: chip
        property string name: ""
        property bool on: false
        property string a11y: name
        signal clicked()
        readonly property string icon: card.iconFor(name)
        readonly property color fg: on ? Theme.accentInk : Theme.ink
        implicitWidth: chipRow.implicitWidth + 20; implicitHeight: 40; radius: 20
        color: on ? Theme.accent : cm.containsMouse ? Theme.raisedHover : Theme.hover
        border.width: activeFocus ? 2 : on ? 0 : 1
        border.color: activeFocus ? Theme.ink : Theme.line
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: a11y
        Keys.onSpacePressed: clicked()
        Keys.onReturnPressed: clicked()
        RowLayout {
            id: chipRow; anchors.centerIn: parent; spacing: 8
            Item {
                implicitWidth: 28; implicitHeight: 28
                IconImage { anchors.fill: parent; source: chip.icon; visible: !!chip.icon }
                Tx { anchors.centerIn: parent; visible: !chip.icon; text: chip.name.charAt(0).toUpperCase(); strong: true; color: chip.fg }
            }
            Tx { text: chip.name; color: chip.fg; size: 14; Layout.maximumWidth: 150 }
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }
    component SwitchRow: Rectangle {
        id: sr
        property string title: ""
        property string sub: ""
        property alias checked: sw.checked
        property alias switchOn: sw.enabled
        signal flipped(bool on)
        Layout.fillWidth: true; implicitHeight: 52; radius: 14
        color: Theme.hover
        opacity: sw.enabled ? 1 : 0.5
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 12
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Tx { text: sr.title; Layout.fillWidth: true }
                Tx { visible: !!sr.sub; text: sr.sub; dim: true; size: 12; Layout.fillWidth: true }
            }
            Swt { id: sw; a11y: sr.title; onToggled: sr.flipped(checked) }
        }
    }

    ColumnLayout {
        id: body
        x: 24; y: 16; width: parent.width - 48
        spacing: 12
        Tx {
            Layout.fillWidth: true; Layout.minimumHeight: 32; horizontalAlignment: Text.AlignHCenter
            text: Focus.running && Focus.phase === "break" ? Tr.t("Break") : Tr.t("Focus")
            size: 14; strong: true; font.letterSpacing: 1.6; font.capitalization: Font.AllUppercase
            Accessible.role: Accessible.Heading; Accessible.name: text
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 22
            Item {
                implicitWidth: 136; implicitHeight: 136
                Accessible.role: Accessible.StaticText
                Accessible.name: Focus.running ? Focus.label : card.big + " " + Tr.t("min")
                FocusRing { anchors.fill: parent; value: Focus.fraction }
                Column {
                    anchors.centerIn: parent
                    Tx { anchors.horizontalCenter: parent.horizontalCenter; text: card.big; size: 44; strong: true; Accessible.ignored: true }
                    Tx { anchors.horizontalCenter: parent.horizontalCenter; visible: card.big !== "∞"; text: Tr.t("min"); dim: true; size: 13; Accessible.ignored: true }
                }
            }
            // The length, before it starts. Pomodoro has its own.
            GridLayout {
                visible: !Focus.running
                enabled: !card.pomodoro
                opacity: enabled ? 1 : 0.45
                Layout.fillWidth: true
                columns: 2; rowSpacing: 8; columnSpacing: 8
                Accessible.role: Accessible.Grouping
                Accessible.name: Tr.t("Duration")
                Repeater {
                    model: F.durations
                    Rectangle {
                        id: dur
                        required property int modelData
                        readonly property bool sel: Focus.minutes === modelData
                        Layout.fillWidth: true; implicitWidth: durT.implicitWidth + 24; implicitHeight: 40; radius: 20
                        color: sel ? Theme.accent : dm.containsMouse ? Theme.raisedHover : Theme.hover
                        border.width: activeFocus ? 2 : sel ? 0 : 1
                        border.color: activeFocus ? Theme.ink : Theme.line
                        activeFocusOnTab: enabled
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: durT.text
                        Accessible.checked: sel
                        Keys.onSpacePressed: Cfg.v.focusMinutes = modelData
                        Keys.onReturnPressed: Cfg.v.focusMinutes = modelData
                        Tx {
                            id: durT; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 16)
                            text: dur.modelData === 0 ? Tr.t("Until turned off") : dur.modelData === 60 ? Tr.t("1 h") : Tr.t("%1 min").arg(dur.modelData)
                            size: 14; strong: dur.sel; color: dur.sel ? Theme.accentInk : Theme.ink
                        }
                        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.focusMinutes = dur.modelData }
                    }
                }
            }
            ColumnLayout {
                visible: Focus.running
                Layout.fillWidth: true; spacing: 2
                Tx { text: Focus.clock; mono: true; strong: true; size: 28; color: Theme.accent; Accessible.ignored: true }
                Tx { visible: Focus.session?.pomodoro ?? false; text: Tr.t("Pomodoro"); dim: true }
            }
        }
        SwitchRow {
            title: Tr.t("Pomodoro"); sub: Tr.t("25 min + 5 min break")
            checked: card.pomodoro; switchOn: !Focus.running
            onFlipped: on => Cfg.v.focusPomodoro = on
        }
        SwitchRow {
            title: Tr.t("Hide music and notifications")
            checked: Cfg.v.focusHide
            onFlipped: on => Cfg.v.focusHide = on
        }
        Sec { title: Tr.t("Let through"); Layout.topMargin: 4 }
        Flow {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: card.allow
                AppChip {
                    required property string modelData
                    name: modelData; on: true
                    a11y: Tr.t("Remove %1").arg(modelData)
                    onClicked: Cfg.v.focusAllow = card.allow.filter(a => a !== modelData)
                }
            }
            Rectangle {
                implicitWidth: 40; implicitHeight: 40; radius: 20
                color: card.adding ? Theme.raised : am.containsMouse ? Theme.raisedHover : Theme.hover
                border.width: activeFocus ? 2 : 1
                border.color: activeFocus ? Theme.ink : Theme.line
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: Tr.t("Add app")
                Keys.onSpacePressed: card.adding = !card.adding
                Keys.onReturnPressed: card.adding = !card.adding
                Ic { anchors.centerIn: parent; name: card.adding ? "x" : "plus"; size: 18 }
                MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.adding = !card.adding }
            }
        }
        // The apps in the notification history, to pick from.
        Flow {
            visible: card.adding
            Layout.fillWidth: true; spacing: 8
            Repeater {
                id: seen
                model: card.adding ? F.seenApps(Notifs.all, card.allow) : []
                AppChip {
                    required property string modelData
                    name: modelData
                    onClicked: Cfg.v.focusAllow = card.allow.concat([modelData])
                }
            }
        }
        Tx { visible: card.adding && seen.count === 0; text: Tr.t("No apps in the notification history yet."); dim: true; size: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Rectangle {
            id: main
            readonly property bool primary: !Focus.running
            readonly property color fg: primary ? Theme.accentInk : Theme.ink
            Layout.fillWidth: true; Layout.topMargin: 4; implicitHeight: 50; radius: 25
            color: primary ? (pm.pressed ? Qt.darker(Theme.accent, 1.15) : pm.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                : pm.containsMouse ? Theme.raisedHover : Theme.hover
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            border.width: activeFocus ? 2 : primary ? 0 : 1
            border.color: activeFocus ? Theme.ink : Theme.line
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: mainT.text
            Keys.onSpacePressed: card.go()
            Keys.onReturnPressed: card.go()
            RowLayout {
                anchors.centerIn: parent; spacing: 8
                Ic { name: main.primary ? "playFill" : "x"; filled: main.primary; size: 18; color: main.fg }
                Tx { id: mainT; text: main.primary ? Tr.t("Start focus") : Tr.t("Stop"); strong: true; color: main.fg }
            }
            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.go() }
        }
    }
}
