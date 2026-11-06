import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Page {
    id: pg
    title: Tr.t("Settings")
    Component.onCompleted: Holidays.listCountries()
    property bool addingLayout: false

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

    Sec { title: Tr.t("Night light") }
    Line {
        label: Tr.t("Night light")
        hint: Tr.t("Warmer screen, less blue")
        Sld { visible: Cfg.v.nightOn; Layout.preferredWidth: 180; a11y: Tr.t("Night light temperature"); from: 2500; to: 6000; stepSize: 100; value: Cfg.v.nightK; onMoved: { Cfg.v.nightK = value; Night.apply() } }
        Tx { visible: Cfg.v.nightOn; mono: true; text: Cfg.v.nightK + " K"; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
        Swt { a11y: Tr.t("Night light"); checked: Cfg.v.nightOn; onToggled: { Cfg.v.nightOn = checked; Night.apply() } }
    }

    Line {
        label: Tr.t("Automatic")
        hint: Tr.t("Turns on and off by itself at these times")
        Fld {
            visible: Cfg.v.nightAuto; implicitWidth: 86; font.family: Theme.mono
            Accessible.name: Tr.t("Night light") + ": " + Tr.t("Start")
            text: Cfg.v.nightFrom
            validator: RegularExpressionValidator { regularExpression: /^([01][0-9]|2[0-3]):[0-5][0-9]$/ }
            onTextEdited: if (acceptableInput) Cfg.v.nightFrom = text
        }
        Fld {
            visible: Cfg.v.nightAuto; implicitWidth: 86; font.family: Theme.mono
            Accessible.name: Tr.t("Night light") + ": " + Tr.t("End")
            text: Cfg.v.nightTo
            validator: RegularExpressionValidator { regularExpression: /^([01][0-9]|2[0-3]):[0-5][0-9]$/ }
            onTextEdited: if (acceptableInput) Cfg.v.nightTo = text
        }
        Swt { a11y: Tr.t("Night light") + ": " + Tr.t("Automatic"); checked: Cfg.v.nightAuto; onToggled: Cfg.v.nightAuto = checked }
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
        onVisibleChanged: if (visible) { forceActiveFocus(); layoutScroll.restart() }
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
    // The results open below the field, which can be near the bottom of the page.
    Timer {
        id: layoutScroll
        interval: 60
        onTriggered: pg.contentY = Math.max(pg.contentY, Math.min(layoutSearch.mapToItem(pg.contentItem, 0, 0).y - 140, pg.contentHeight - pg.height))
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
}
