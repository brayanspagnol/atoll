import QtQuick
import QtQuick.Layouts

Page {
    id: pg
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
    // Newest first, one group per app.
    readonly property var groups: {
        const out = []
        for (const n of [...Notifs.all].reverse()) {
            const g = out.find(o => o.app === n.appName)
            if (g) g.items.push(n)
            else out.push({ app: n.appName, items: [n] })
        }
        return out
    }
    property var expanded: ({})
    Repeater {
        model: pg.groups
        ColumnLayout {
            id: group
            required property var modelData
            readonly property bool open: !!pg.expanded[modelData.app]
            readonly property int hidden: open ? 0 : Math.max(0, modelData.items.length - 3)
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 6
                Tx { text: group.modelData.app || Tr.t("Other"); strong: true; Layout.fillWidth: true }
                Tx { visible: group.modelData.items.length > 1; mono: true; dim: true; size: 13; text: group.modelData.items.length }
                Btn { variant: "quiet"; visible: group.modelData.items.length > 1; text: Tr.t("Clear"); onClicked: Notifs.clearApp(group.modelData.app) }
            }
            Repeater {
                model: group.modelData.items.slice(0, group.modelData.items.length - group.hidden)
                NotifCard { Layout.fillWidth: true }
            }
            Btn {
                visible: group.hidden > 0
                text: Tr.t("Show %1 more").arg(group.hidden)
                onClicked: pg.expanded = Object.assign({}, pg.expanded, { [group.modelData.app]: true })
            }
        }
    }
}
