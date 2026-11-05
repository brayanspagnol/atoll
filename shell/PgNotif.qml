import QtQuick
import QtQuick.Layouts

Page {
    title: "Avisos"
    subtitle: Notifs.all.length ? Notifs.all.length + " aviso(s)" : "Tudo em dia"
    Sec {
        title: "Preferências"
    }
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Tx { text: "Não perturbe"; Layout.fillWidth: true }
            Tx { text: "Guarda avisos sem mostrar na tela. Críticos ainda aparecem."; dim: true; size: 13; Layout.fillWidth: true }
        }
        Swt { a11y: "Não perturbe"; checked: Cfg.v.dnd; onToggled: Cfg.v.dnd = checked }
    }
    Sec {
        title: "Recentes"
        Btn { visible: Notifs.all.length > 0; text: "Limpar tudo"; onClicked: Notifs.clear() }
    }
    Tx { visible: Notifs.all.length === 0; text: "Nenhum aviso."; dim: true }
    Repeater {
        model: [...Notifs.all].reverse()
        NotifCard { Layout.fillWidth: true }
    }
}
