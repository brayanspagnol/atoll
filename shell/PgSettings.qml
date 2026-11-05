import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Page {
    id: pg
    title: Tr.t("Settings")
    Component.onCompleted: Bright.refresh()
    property var walls: []
    readonly property var monitors: Hyprland.monitors.values

    Process {
        running: true
        command: ["find", Quickshell.env("HOME") + "/.local/share/atoll/wallpapers", Quickshell.env("HOME") + "/Pictures/Wallpapers", "-maxdepth", "2", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")"]
        stderr: StdioCollector {}
        stdout: StdioCollector { onStreamFinished: pg.walls = text.trim().split("\n").filter(Boolean).sort() }
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
    Tx { visible: pg.walls.length === 0; text: Tr.t("Add images to ~/Pictures/Wallpapers"); dim: true }
    Flow {
        Layout.fillWidth: true; spacing: 8
        Repeater {
            model: pg.walls
            Rectangle {
                required property string modelData
                width: 268; height: 120; radius: Theme.radiusSmall; clip: true
                color: Theme.raised
                border.width: Cfg.v.wallpaper === modelData || activeFocus ? 2 : 0
                border.color: Theme.accent
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: Tr.t("Wallpaper %1").arg(modelData.split("/").pop())
                Keys.onSpacePressed: Cfg.v.wallpaper = modelData
                Image { anchors.fill: parent; anchors.margins: 2; source: "file://" + parent.modelData; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(536, 240); asynchronous: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.wallpaper = parent.modelData }
            }
        }
        Rectangle {
            width: 268; height: 120; radius: Theme.radiusSmall; color: Theme.ground
            border.width: !Cfg.v.wallpaper || activeFocus ? 2 : 1
            border.color: !Cfg.v.wallpaper || activeFocus ? Theme.accent : Theme.line
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: Tr.t("No image, solid color")
            Keys.onSpacePressed: Cfg.v.wallpaper = ""
            Tx { anchors.centerIn: parent; text: Tr.t("Solid color"); dim: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Cfg.v.wallpaper = "" }
        }
    }

    Sec { title: Tr.t("Calendar") }
    Line {
        label: Tr.t("Brazilian holidays in the calendar")
        Swt { a11y: Tr.t("Brazilian holidays in the calendar"); checked: Cfg.v.holidays === "on" || (Cfg.v.holidays !== "off" && Qt.locale().name.endsWith("_BR")); onToggled: Cfg.v.holidays = checked ? "on" : "off" }
    }

    Sec { title: Tr.t("Display") }
    Repeater {
        model: pg.monitors
        Line {
            required property var modelData
            label: modelData.name
            hint: modelData.width + "×" + modelData.height + " · " + Math.round(modelData.lastIpcObject?.refreshRate ?? 0) + " Hz · " + Tr.t("scale %1").arg(modelData.scale)
        }
    }
    Line {
        visible: Bright.external >= 0
        label: Tr.t("External monitor brightness")
        hint: Tr.t("Through DDC/CI")
        Sld { Layout.preferredWidth: 260; a11y: Tr.t("External brightness"); from: 0; to: 100; stepSize: 5; value: Bright.external; onPressedChanged: if (!pressed) Bright.setExternal(value) }
        Tx { mono: true; text: Bright.external + "%"; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
    }
    Line {
        visible: Bright.panel >= 0
        label: Tr.t("Laptop screen brightness")
        Sld { Layout.preferredWidth: 260; a11y: Tr.t("Laptop brightness"); from: 1; to: 100; value: Bright.panel; onMoved: Bright.setPanel(Math.round(value)) }
        Tx { mono: true; text: Bright.panel + "%"; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
    }
    Line {
        label: Tr.t("Night light")
        hint: Tr.t("Warmer screen, less blue")
        Sld { visible: Cfg.v.nightOn; Layout.preferredWidth: 180; a11y: Tr.t("Night light temperature"); from: 2500; to: 6000; stepSize: 100; value: Cfg.v.nightK; onMoved: { Cfg.v.nightK = value; Night.apply() } }
        Tx { visible: Cfg.v.nightOn; mono: true; text: Cfg.v.nightK + " K"; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
        Swt { a11y: Tr.t("Night light"); checked: Cfg.v.nightOn; onToggled: { Cfg.v.nightOn = checked; Night.apply() } }
    }

    Sec {
        title: Tr.t("Idle time (minutes, 0 = never)")
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
        Mins { key: "lockAc" } Mins { key: "dpmsAc" } Mins { key: "sleepAc" }
        Tx { text: Tr.t("On battery") }
        Mins { key: "lockBat" } Mins { key: "dpmsBat" } Mins { key: "sleepBat" }
    }
    component Mins: Fld {
        property string key: ""
        Layout.fillWidth: true
        font.family: Theme.mono
        text: Cfg.v[key]
        validator: IntValidator { bottom: 0; top: 240 }
        Accessible.name: key
        onTextEdited: if (acceptableInput) Cfg.v[key] = Number(text)
    }

    Sec { title: Tr.t("Shortcuts") }
    GridLayout {
        Layout.fillWidth: true; columns: 2; columnSpacing: 28; rowSpacing: 6
        Repeater {
            model: [["Super + R", Tr.t("Apps and commands")], ["Super + Z", Tr.t("Show the bottom bar")],
                    ["Super + Alt + A", Tr.t("Sound")], ["Super + Alt + I", "Internet"], ["Super + Alt + B", "Bluetooth"], ["Super + Alt + D", Tr.t("Performance")],
                    ["Super + Alt + C", Tr.t("Calendar")], ["Super + Alt + V", Tr.t("Notifications")], ["Super + Alt + J", Tr.t("Settings")], ["Super + Alt + E", Tr.t("Power")],
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

    Sec { title: Tr.t("About") }
    FileView { id: versionFile; path: Quickshell.env("HOME") + "/.local/share/atoll/VERSION"; blockLoading: true }
    Line {
        label: "Atoll " + (versionFile.text().trim() || "dev")
        hint: Tr.t("Free software under the MIT license")
        Btn { text: Tr.t("Open on GitHub"); onClicked: Qt.openUrlExternally("https://github.com/brayanspagnol/atoll") }
    }
}
