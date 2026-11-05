import QtQuick
import QtQuick.Layouts
import Quickshell

Page {
    id: pg
    title: "Energia"
    subtitle: "Reiniciar, desligar e sair fecham todos os aplicativos."
    property string armed: ""
    Timer { running: pg.armed; interval: 5000; onTriggered: pg.armed = "" }
    readonly property string lockCmd: "pidof hyprlock || hyprlock -c $HOME/.config/atoll/hyprlock.conf"
    readonly property var actions: [
        { id: "lock", label: "Bloquear", hint: "Protege a sessão", icon: "lock", confirm: false, cmd: `(${lockCmd}) &` },
        // Lock first so the session is protected when it wakes.
        { id: "sleep", label: "Suspender", hint: "Baixo consumo, volta de onde parou", icon: "moon", confirm: false, cmd: `(${lockCmd}) & sleep 0.5; systemctl suspend` },
        { id: "exit", label: "Sair da sessão", hint: "Encerra o Hyprland", icon: "exit", confirm: true, cmd: `hyprctl dispatch 'hl.dsp.exit()'` },
        { id: "reboot", label: "Reiniciar", hint: "Fecha tudo e religa", icon: "redo", confirm: true, cmd: "systemctl reboot" },
        { id: "off", label: "Desligar", hint: "Fecha tudo e desliga", icon: "energia", confirm: true, cmd: "systemctl poweroff" }
    ]
    Sec { title: "Ações" }
    Repeater {
        model: pg.actions
        Rowi {
            id: a
            required property var modelData
            readonly property bool sure: pg.armed === modelData.id
            implicitHeight: 68
            a11y: sure ? "Confirmar " + modelData.label : modelData.label
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
                Tx { text: a.sure ? "Clique de novo em 5 s para confirmar" : a.modelData.hint; color: a.sure ? Theme.danger : Theme.muted; size: 13; Layout.fillWidth: true }
            }
        }
    }
}
