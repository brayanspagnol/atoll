import QtQuick
import QtQuick.Layouts
import Quickshell

Page {
    id: pg
    title: Tr.t("Power")
    subtitle: Tr.t("Restart, shut down and log out close all apps.")
    property string armed: ""
    Timer { running: pg.armed; interval: 5000; onTriggered: pg.armed = "" }
    readonly property string lockCmd: "pidof hyprlock || hyprlock -c $HOME/.config/atoll/hyprlock.conf"
    readonly property var actions: [
        { id: "lock", label: Tr.t("Lock"), hint: Tr.t("Protects the session"), icon: "lock", confirm: false, cmd: `(${lockCmd}) &` },
        // Lock first so the session is protected when it wakes.
        { id: "sleep", label: Tr.t("Suspend"), hint: Tr.t("Low power, resumes where you left off"), icon: "moon", confirm: false, cmd: `(${lockCmd}) & sleep 0.5; systemctl suspend` },
        { id: "exit", label: Tr.t("Log out"), hint: Tr.t("Ends Hyprland"), icon: "exit", confirm: true, cmd: `hyprctl dispatch 'hl.dsp.exit()'` },
        { id: "reboot", label: Tr.t("Restart"), hint: Tr.t("Closes everything and restarts"), icon: "redo", confirm: true, cmd: "systemctl reboot" },
        { id: "off", label: Tr.t("Shut down"), hint: Tr.t("Closes everything and shuts down"), icon: "energia", confirm: true, cmd: "systemctl poweroff" }
    ]
    Sec { title: Tr.t("Actions") }
    Repeater {
        model: pg.actions
        Rowi {
            id: a
            required property var modelData
            readonly property bool sure: pg.armed === modelData.id
            implicitHeight: 68
            a11y: sure ? Tr.t("Confirm %1").arg(modelData.label) : modelData.label
            selected: sure
            onClicked: {
                if (modelData.confirm && !sure) { pg.armed = modelData.id; return }
                pg.armed = ""; Ui.open = false
                Ui.sh(modelData.cmd)
            }
            Ic { name: a.modelData.icon; size: 24; color: a.sure ? Theme.danger : Theme.ink }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Tx { text: a.modelData.label; size: 17; strong: true; Layout.fillWidth: true }
                Tx { text: a.sure ? Tr.t("Click again within 5 s to confirm") : a.modelData.hint; color: a.sure ? Theme.danger : Theme.muted; size: 13; Layout.fillWidth: true }
            }
        }
    }
}
