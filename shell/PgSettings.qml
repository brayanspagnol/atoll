import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Page {
    id: pg
    title: Tr.t("Settings")
    Component.onCompleted: { Holidays.listCountries(); Profiles.keepWallpaper() }
    property bool creating: false
    property bool addingLayout: false
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
        color: sure ? Theme.danger : Qt.rgba(10 / 255, 16 / 255, 24 / 255, 0.85)
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

    Sec { title: Tr.t("Language") }
    Flow {
        Layout.fillWidth: true; spacing: 8
        Repeater {
            model: [{ code: "auto", name: Tr.t("Automatic") }].concat(Tr.languages)
            Btn {
                required property var modelData
                text: modelData.name
                variant: (Cfg.v.language || "auto") === modelData.code ? "solid" : "ghost"
                onClicked: Cfg.v.language = modelData.code
            }
        }
    }

    Sec { title: Tr.t("Appearance") }
    Line {
        label: Tr.t("Accent color")
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
        Layout.fillWidth: true; spacing: 8
        Repeater {
            model: Profiles.wallpapers
            Rectangle {
                required property string modelData
                width: 208; height: 112; radius: Theme.radiusSmall; clip: true
                color: Theme.raised
                border.width: Cfg.v.wallpaper === modelData || activeFocus ? 2 : 0
                border.color: Theme.accent
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: Tr.t("Wallpaper")
                Accessible.checked: Cfg.v.wallpaper === modelData
                Keys.onSpacePressed: Cfg.v.wallpaper = modelData
                Image { anchors.fill: parent; anchors.margins: 2; source: "file://" + parent.modelData; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(416, 224); asynchronous: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.wallpaper = parent.modelData }
                HoverHandler { id: wallHover }
                Keys.onDeletePressed: forgetWall.tap()
                Forget { id: forgetWall; anchors { right: parent.right; top: parent.top; margins: 6 } kind: "wallpaper"; path: parent.modelData; hovered: wallHover.hovered || parent.activeFocus }
            }
        }
        Rectangle {
            width: 208; height: 112; radius: Theme.radiusSmall; color: Theme.ground
            border.width: !Cfg.v.wallpaper || activeFocus ? 2 : 1
            border.color: !Cfg.v.wallpaper || activeFocus ? Theme.accent : Theme.line
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: Tr.t("No image, solid color")
            Keys.onSpacePressed: Cfg.v.wallpaper = ""
            Tx { anchors.centerIn: parent; text: Tr.t("Solid color"); dim: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.wallpaper = "" }
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

    Line {
        label: Tr.t("Night light")
        hint: Tr.t("Warmer screen, less blue")
        Sld { visible: Cfg.v.nightOn; Layout.preferredWidth: 180; a11y: Tr.t("Night light temperature"); from: 2500; to: 6000; stepSize: 100; value: Cfg.v.nightK; onMoved: { Cfg.v.nightK = value; Night.apply() } }
        Tx { visible: Cfg.v.nightOn; mono: true; text: Cfg.v.nightK + " K"; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
        Swt { a11y: Tr.t("Night light"); checked: Cfg.v.nightOn; onToggled: { Cfg.v.nightOn = checked; Night.apply() } }
    }

    Sec { title: Tr.t("Keyboard and mouse") }
    Tx { text: Tr.t("Keyboard layouts") }
    Tx { text: Tr.t("Switch between them with %1").arg(Tr.t("Super + Space")); dim: true; size: 13 }
    Flow {
        Layout.fillWidth: true; spacing: 8
        Repeater {
            model: Input.layouts
            Rectangle {
                id: chip
                required property var modelData
                required property int index
                width: chipRow.implicitWidth + 24; height: 36; radius: 18
                color: Theme.raised
                RowLayout {
                    id: chipRow
                    anchors.centerIn: parent; spacing: 8
                    Tx { text: Input.nameOf(chip.modelData); size: 14 }
                    Ic {
                        visible: Input.layouts.length > 1
                        name: "x"; size: 14; color: Theme.muted
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Input.removeLayout(chip.index) }
                    }
                }
            }
        }
        Btn { text: Tr.t("Add layout"); onClicked: { pg.addingLayout = !pg.addingLayout; layoutSearch.text = "" } }
    }
    Fld {
        id: layoutSearch
        visible: pg.addingLayout
        Layout.fillWidth: true
        placeholderText: Tr.t("Search layouts")
        Accessible.name: Tr.t("Search layouts")
        onVisibleChanged: if (visible) forceActiveFocus()
    }
    Repeater {
        model: pg.addingLayout ? Input.catalog.filter(c => c.name.toLowerCase().includes(layoutSearch.text.trim().toLowerCase())).slice(0, 6) : []
        Rowi {
            id: layoutRow
            required property var modelData
            implicitHeight: 40
            a11y: modelData.name
            onClicked: { Input.addLayout(modelData); pg.addingLayout = false }
            Tx { text: layoutRow.modelData.name; Layout.fillWidth: true }
        }
    }
    Line {
        label: Tr.t("Pointer speed")
        Sld { Layout.preferredWidth: 220; a11y: Tr.t("Pointer speed"); from: -1; to: 1; stepSize: 0.05; value: Input.speed; onMoved: { Input.speed = value; Input.save() } }
    }
    Line {
        label: Tr.t("Natural scrolling")
        hint: Tr.t("Content follows your fingers")
        Swt { a11y: Tr.t("Natural scrolling"); checked: Input.natural; onToggled: { Input.natural = checked; Input.save() } }
    }
    Tx { visible: Input.hasTouchpad; text: Tr.t("Touchpad"); Layout.topMargin: 6; strong: true }
    Line {
        visible: Input.hasTouchpad
        label: Tr.t("Natural scrolling")
        Swt { a11y: Tr.t("Touchpad") + ": " + Tr.t("Natural scrolling"); checked: Input.padNatural; onToggled: { Input.padNatural = checked; Input.save() } }
    }
    Line {
        visible: Input.hasTouchpad
        label: Tr.t("Tap to click")
        Swt { a11y: Tr.t("Tap to click"); checked: Input.padTap; onToggled: { Input.padTap = checked; Input.save() } }
    }
    Line {
        visible: Input.hasTouchpad
        label: Tr.t("Ignore while typing")
        Swt { a11y: Tr.t("Ignore while typing"); checked: Input.padTyping; onToggled: { Input.padTyping = checked; Input.save() } }
    }
    Line {
        visible: Input.hasTouchpad
        label: Tr.t("Scroll speed")
        Sld { Layout.preferredWidth: 220; a11y: Tr.t("Scroll speed"); from: 0.2; to: 3; stepSize: 0.1; value: Input.padScroll; onMoved: { Input.padScroll = value; Input.save() } }
    }

    Sec { title: Tr.t("Calendar") }
    Line {
        label: Tr.t("Public holidays")
        hint: Tr.t("Downloaded from date.nager.at")
        Cmb {
            id: holidayPick
            a11y: Tr.t("Public holidays")
            textRole: "name"
            model: [{ code: "off", name: Tr.t("None") }, { code: "auto", name: Tr.t("Automatic") }].concat(Holidays.countries.map(c => ({ code: c.countryCode, name: c.name })))
            currentIndex: Math.max(0, model.findIndex(o => o.code === (Cfg.v.holidays || "auto")))
            onActivated: i => Cfg.v.holidays = model[i].code
        }
    }


    Sec {
        title: Tr.t("Idle time")
        Btn { text: Tr.t("Apply"); variant: "solid"; onClicked: { Idle.apply(); applied.visible = true } }
    }
    Tx { id: applied; visible: false; text: Tr.t("Applied."); color: Theme.good }
    GridLayout {
        Layout.fillWidth: true; columns: 4; columnSpacing: 16; rowSpacing: 8
        Item { implicitWidth: 1 }
        Tx { text: Tr.t("Lock"); dim: true; size: 13; Layout.fillWidth: true }
        Tx { text: Tr.t("Turn off screen"); dim: true; size: 13; Layout.fillWidth: true }
        Tx { text: Tr.t("Suspend"); dim: true; size: 13; Layout.fillWidth: true }
        Tx { text: Tr.t("Plugged in") }
        Mins { key: "lockAc"; a11y: Tr.t("Plugged in") + ": " + Tr.t("Lock") }
        Mins { key: "dpmsAc"; a11y: Tr.t("Plugged in") + ": " + Tr.t("Turn off screen") }
        Mins { key: "sleepAc"; a11y: Tr.t("Plugged in") + ": " + Tr.t("Suspend") }
        Tx { text: Tr.t("On battery") }
        Mins { key: "lockBat"; a11y: Tr.t("On battery") + ": " + Tr.t("Lock") }
        Mins { key: "dpmsBat"; a11y: Tr.t("On battery") + ": " + Tr.t("Turn off screen") }
        Mins { key: "sleepBat"; a11y: Tr.t("On battery") + ": " + Tr.t("Suspend") }
    }
    component Mins: Cmb {
        property string key: ""
        readonly property int minutes: Cfg.v[key]
        // Times set by hand in an older version stay available.
        readonly property var choices: [...new Set([0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, minutes])].sort((a, b) => a - b)
        Layout.fillWidth: true
        implicitWidth: 120
        textRole: "name"
        model: choices.map(m => ({ name: m ? Tr.t("%1 min").arg(m) : Tr.t("Never") }))
        currentIndex: choices.indexOf(minutes)
        onActivated: i => Cfg.v[key] = choices[i]
    }

    Sec { title: Tr.t("Shortcuts") }
    GridLayout {
        Layout.fillWidth: true; columns: 2; columnSpacing: 28; rowSpacing: 6
        Repeater {
            model: [["Super + R", Tr.t("Apps and commands")], ["Super + Z", Tr.t("Show the bottom bar")],
                    ["Super + Alt + A", Tr.t("Sound")], ["Super + Alt + I", "Internet"], ["Super + Alt + B", "Bluetooth"], ["Super + Alt + D", Tr.t("Performance")],
                    ["Super + Alt + C", Tr.t("Calendar")], ["Super + Alt + V", Tr.t("Notifications")], ["Super + Alt + J", Tr.t("Settings")], ["Super + Alt + M", Tr.t("Monitor")], ["Super + Alt + O", Tr.t("About")], ["Super + Alt + E", Tr.t("Power")],
                    ["Super + L", Tr.t("Lock")], ["Super + Enter", Tr.t("Terminal")], ["Super + B", Tr.t("Browser")], ["Super + E", Tr.t("Files")],
                    ["Super + C", Tr.t("Close window")], ["Super + Shift + V", Tr.t("Clipboard history")], ["Print", Tr.t("Area screenshot")], [Tr.t("Super + Space"), Tr.t("Switch keyboard layout")]]
            RowLayout {
                required property var modelData
                Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 8
                Tx { text: parent.modelData[1]; dim: true; Layout.fillWidth: true }
                Tx { text: parent.modelData[0]; mono: true; size: 13 }
            }
        }
    }
}
