import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Page {
    id: pg
    title: Tr.t("Personalization")
    Component.onCompleted: Profiles.keepWallpaper()
    property bool creating: false
    property string wallScreen: "" // empty means every screen
    readonly property string wallNow: wallScreen ? (Cfg.v.wallpapers ?? {})[wallScreen] ?? Cfg.v.wallpaper : Cfg.v.wallpaper
    function setWall(path) {
        if (!wallScreen) { Cfg.v.wallpaper = path; Cfg.v.wallpapers = {}; return }
        Cfg.v.wallpapers = Object.assign({}, Cfg.v.wallpapers ?? {}, { [wallScreen]: path })
    }
    property bool armed: false
    Timer { running: pg.armed; interval: 5000; onTriggered: pg.armed = false }

    // Deleting asks for a second click, like the other destructive buttons here.
    property string armedImage: ""
    Timer { running: pg.armedImage !== ""; interval: 5000; onTriggered: pg.armedImage = "" }
    component Forget: Rectangle {
        id: badge
        property string kind: ""
        property string path: ""
        property bool hovered: false
        readonly property bool sure: pg.armedImage === path
        function tap() {
            if (sure) { pg.armedImage = ""; Profiles.forget(kind, path) }
            else pg.armedImage = path
        }
        visible: hovered || sure
        width: 28; height: 28; radius: 14
        color: sure ? Theme.danger : Theme.glassStrong
        border.width: 1; border.color: Theme.lineStrong
        Accessible.role: Accessible.Button
        Accessible.name: sure ? Tr.t("Click again within 5 s to confirm") : Tr.t("Remove")
        Ic { anchors.centerIn: parent; name: "x"; size: 15; color: badge.sure ? Theme.accentInk : Theme.ink }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: badge.tap() }
    }

    component Line: RowLayout {
        property string label: ""
        property string hint: ""
        Layout.fillWidth: true; spacing: 16
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Tx { text: label; Layout.fillWidth: true }
            Tx { visible: hint; text: hint; dim: true; size: 13; Layout.fillWidth: true }
        }
    }

    // One choice of the theme picker, with a small desktop drawn in the colors of each set it uses.
    component ThemeCard: Rectangle {
        id: card
        property string value: ""
        property string label: ""
        property string sub: ""
        property var looks: []
        readonly property bool on: Cfg.v.theme === value
        Layout.fillWidth: true; Layout.preferredWidth: 1
        implicitHeight: cardCol.implicitHeight + 16
        radius: Theme.radiusSmall
        color: on ? Theme.raisedHover : Theme.raised
        border.width: on || activeFocus ? 2 : 1
        border.color: activeFocus ? Theme.ink : on ? Theme.accent : Theme.line
        activeFocusOnTab: true
        Accessible.role: Accessible.RadioButton
        Accessible.name: label + ", " + sub
        Accessible.checked: on
        Keys.onSpacePressed: Cfg.v.theme = value
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.theme = card.value }
        ColumnLayout {
            id: cardCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 8
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 84; radius: 10; clip: true
                color: card.looks[0]?.ground ?? Theme.ground
                Image { anchors.fill: parent; visible: !!Cfg.v.wallpaper; source: Cfg.v.wallpaper ? "file://" + Cfg.v.wallpaper : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(240, 168); asynchronous: true }
                Row {
                    id: halves
                    anchors { fill: parent; margins: 14; topMargin: 16 }
                    spacing: 4
                    Repeater {
                        model: card.looks
                        Rectangle {
                            required property var modelData
                            width: (halves.width - halves.spacing * (card.looks.length - 1)) / card.looks.length; height: halves.height
                            radius: 7; color: modelData.surface; border.width: 1; border.color: modelData.rim
                            Column {
                                anchors { fill: parent; margins: 8 }
                                spacing: 5
                                Rectangle { width: parent.width * 0.5; height: 4; radius: 2; color: modelData.ink }
                                Rectangle { width: parent.width * 0.8; height: 3; radius: 2; color: modelData.muted }
                                Rectangle { width: 18; height: 8; radius: 3; color: modelData.accents[Cfg.v.accent] ?? modelData.accents.gelo }
                            }
                        }
                    }
                }
            }
            RowLayout {
                Layout.leftMargin: 4; spacing: 8
                Rectangle {
                    implicitWidth: 16; implicitHeight: 16; radius: 8
                    color: "transparent"; border.width: 2; border.color: card.on ? Theme.accent : Theme.muted
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.accent; visible: card.on }
                }
                ColumnLayout {
                    spacing: 0; Layout.fillWidth: true
                    Tx { text: card.label; strong: true; size: 14; Layout.fillWidth: true }
                    Tx { text: card.sub; dim: true; size: 12; Layout.fillWidth: true }
                }
            }
        }
    }

    Sec { title: Tr.t("Profile") }
    Flow {
        Layout.fillWidth: true; spacing: 8
        Repeater {
            model: Profiles.list
            ProfileChip {
                required property var modelData
                profile: modelData
            }
        }
        Btn { icon: "plus"; text: Tr.t("New profile"); implicitHeight: 56; onClicked: { pg.creating = !pg.creating; pg.armed = false } }
    }
    RowLayout {
        visible: pg.creating
        Layout.fillWidth: true; spacing: 8
        Fld {
            id: newName
            Layout.fillWidth: true
            placeholderText: Tr.t("Profile name")
            Accessible.name: Tr.t("Profile name")
            onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
            onAccepted: createBtn.clicked()
        }
        Btn {
            id: createBtn
            text: Tr.t("Create"); variant: "solid"; enabledB: newName.text.trim().length > 0
            onClicked: { Profiles.create(newName.text.trim()); pg.creating = false }
        }
    }
    Line {
        label: Tr.t("Name")
        Fld {
            Layout.preferredWidth: 260
            text: Cfg.v.name
            Accessible.name: Tr.t("Profile name")
            onEditingFinished: { if (text.trim()) { Cfg.v.name = text.trim(); nameSaved.restart() } else text = Cfg.v.name }
            Timer { id: nameSaved; interval: 300; onTriggered: Profiles.refresh() }
        }
        Btn {
            visible: Profiles.list.length > 1
            text: pg.armed ? Tr.t("Click again to delete") : Tr.t("Delete profile")
            variant: "danger"
            onClicked: {
                if (!pg.armed) { pg.armed = true; return }
                pg.armed = false
                Profiles.removeActive()
            }
        }
    }
    Tx { text: Tr.t("Photo"); Layout.topMargin: 6 }
    Tx { text: Tr.t("Shown on the lock screen"); dim: true; size: 13 }
    Flow {
        Layout.fillWidth: true; spacing: 12
        Repeater {
            model: Profiles.photos
            Rectangle {
                id: choice
                required property string modelData
                readonly property bool on: Cfg.v.photo === modelData
                width: 88; height: 88; radius: 44
                color: "transparent"
                border.width: on || activeFocus ? 3 : 0
                border.color: activeFocus ? Theme.ink : Theme.accent
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: Tr.t("Photo")
                Accessible.checked: on
                Keys.onSpacePressed: Cfg.v.photo = modelData
                ClippingRectangle {
                    anchors.fill: parent; anchors.margins: 5; radius: width / 2; color: Theme.raised
                    Image { anchors.fill: parent; source: "file://" + choice.modelData; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(160, 160); asynchronous: true }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.photo = choice.modelData }
                HoverHandler { id: choiceHover }
                Keys.onDeletePressed: forgetPhoto.tap()
                Forget { id: forgetPhoto; anchors { right: parent.right; top: parent.top } kind: "photo"; path: choice.modelData; hovered: choiceHover.hovered || choice.activeFocus }
            }
        }
        Rectangle {
            width: 88; height: 88; radius: 44
            color: addPhoto.containsMouse ? Theme.raised : Theme.hover
            border.width: activeFocus ? 3 : 1
            border.color: activeFocus ? Theme.ink : Theme.lineStrong
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: Tr.t("Add photo")
            Keys.onSpacePressed: Profiles.addPhoto()
            Keys.onReturnPressed: Profiles.addPhoto()
            Ic { anchors.centerIn: parent; name: "plus"; size: 32 }
            MouseArea { id: addPhoto; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Profiles.addPhoto() }
        }
    }

    Sec { title: Tr.t("Appearance") }
    Tx { text: Tr.t("Theme") }
    RowLayout {
        Layout.fillWidth: true; spacing: 10
        Accessible.role: Accessible.Grouping; Accessible.name: Tr.t("Theme")
        ThemeCard { value: "dark"; label: Tr.t("Dark"); sub: Tr.t("Always dark"); looks: [Theme.sets.dark] }
        ThemeCard { value: "light"; label: Tr.t("Light"); sub: Tr.t("Always light"); looks: [Theme.sets.light] }
        ThemeCard {
            value: "auto"; label: Tr.t("Automatic"); looks: [Theme.sets.light, Theme.sets.dark]
            sub: (Theme.night ? Tr.t("Now: dark, until %1") : Tr.t("Now: light, until %1")).arg(Theme.switchAt)
        }
    }
    Tx {
        text: Tr.t("Automatic follows the night light schedule when it is on, otherwise it is light from 07:00 to 19:00. The lock screen and apps keep their own colors.")
        dim: true; size: 13; wrapMode: Text.Wrap; Layout.fillWidth: true
    }
    Line {
        label: Tr.t("Accent color")
        hint: Tr.t("Deeper in the light theme, so it reads on white glass")
        Repeater {
            model: Object.keys(Theme.accents)
            Rectangle {
                required property string modelData
                implicitWidth: 32; implicitHeight: 32; radius: 16
                color: Theme.accents[modelData].hex
                border.width: Cfg.v.accent === modelData || activeFocus ? 2 : 0
                border.color: Theme.ink
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: Theme.accents[modelData].name
                Accessible.checked: Cfg.v.accent === modelData
                Keys.onSpacePressed: Cfg.v.accent = modelData
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.accent = parent.modelData }
            }
        }
    }
    Tx { text: Tr.t("Wallpaper"); Layout.topMargin: 6 }
    Flow {
        visible: Quickshell.screens.length > 1
        Layout.fillWidth: true; spacing: 8
        Btn { text: Tr.t("All screens"); variant: pg.wallScreen === "" ? "solid" : "ghost"; onClicked: pg.wallScreen = "" }
        Repeater {
            model: Quickshell.screens
            Btn {
                required property var modelData
                text: Displays.monitors.find(m => m.name === modelData.name) ? Displays.labelOf(Displays.monitors.find(m => m.name === modelData.name)) : modelData.name
                variant: pg.wallScreen === modelData.name ? "solid" : "ghost"
                onClicked: pg.wallScreen = modelData.name
            }
        }
    }
    Flow {
        Layout.fillWidth: true; spacing: 8
        Repeater {
            model: Profiles.wallpapers
            Rectangle {
                required property string modelData
                width: 208; height: 112; radius: Theme.radiusSmall; clip: true
                color: Theme.raised
                border.width: pg.wallNow === modelData || activeFocus ? 2 : 0
                border.color: Theme.accent
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: Tr.t("Wallpaper")
                Accessible.checked: pg.wallNow === modelData
                Keys.onSpacePressed: pg.setWall(modelData)
                Image { anchors.fill: parent; anchors.margins: 2; source: "file://" + parent.modelData; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(416, 224); asynchronous: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.setWall(parent.modelData) }
                HoverHandler { id: wallHover }
                Keys.onDeletePressed: forgetWall.tap()
                Forget { id: forgetWall; anchors { right: parent.right; top: parent.top; margins: 6 } kind: "wallpaper"; path: parent.modelData; hovered: wallHover.hovered || parent.activeFocus }
            }
        }
        Rectangle {
            width: 208; height: 112; radius: Theme.radiusSmall; color: Theme.ground
            border.width: !pg.wallNow || activeFocus ? 2 : 1
            border.color: !pg.wallNow || activeFocus ? Theme.accent : Theme.line
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: Tr.t("No image, solid color")
            Keys.onSpacePressed: pg.setWall("")
            Tx { anchors.centerIn: parent; text: Tr.t("Solid color"); dim: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.setWall("") }
        }
        Rectangle {
            width: 208; height: 112; radius: Theme.radiusSmall
            color: addWallpaper.containsMouse ? Theme.raised : Theme.hover
            border.width: activeFocus ? 2 : 1
            border.color: activeFocus ? Theme.ink : Theme.lineStrong
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: Tr.t("Add wallpaper")
            Keys.onSpacePressed: Profiles.addWallpaper()
            Keys.onReturnPressed: Profiles.addWallpaper()
            Ic { anchors.centerIn: parent; name: "plus"; size: 32 }
            MouseArea { id: addWallpaper; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Profiles.addWallpaper() }
        }
    }
}
