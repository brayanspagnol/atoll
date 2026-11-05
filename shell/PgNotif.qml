import QtQuick
import QtQuick.Layouts

Page {
    title: Tr.t("Notifications")
    subtitle: Notifs.all.length ? Tr.t("Notifications: %1").arg(Notifs.all.length) : Tr.t("All caught up")
    Sec {
        title: Tr.t("Preferences")
    }
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Tx { text: Tr.t("Do not disturb"); Layout.fillWidth: true }
            Tx { text: Tr.t("Keeps notifications without showing them. Critical ones still appear."); dim: true; size: 13; Layout.fillWidth: true }
        }
        Swt { a11y: Tr.t("Do not disturb"); checked: Cfg.v.dnd; onToggled: Cfg.v.dnd = checked }
    }
    Sec {
        title: Tr.t("Recent")
        Btn { visible: Notifs.all.length > 0; text: Tr.t("Clear all"); onClicked: Notifs.clear() }
    }
    Tx { visible: Notifs.all.length === 0; text: Tr.t("No notifications."); dim: true }
    Repeater {
        model: [...Notifs.all].reverse()
        NotifCard { Layout.fillWidth: true }
    }
}
