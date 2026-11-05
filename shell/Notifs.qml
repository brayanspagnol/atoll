pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root
    readonly property var all: server.trackedNotifications.values
    property var toasts: []
    // Missing icons must fall back to a letter, not Qt's magenta placeholder.
    function iconOf(n) {
        const img = n.image || ""
        if (img.startsWith("image://icon/")) return Quickshell.iconPath(img.slice(13), true)
        return img || (n.appIcon ? Quickshell.iconPath(n.appIcon, true) : "")
    }
    function drop(n) { toasts = toasts.filter(t => t !== n) }
    function clear() { all.slice().forEach(n => n.dismiss()) }
    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        bodyHyperlinksSupported: false
        bodyMarkupSupported: false
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true
            if (n.lastGeneration) return // carried over a shell reload: already shown once
            if (Cfg.v.dnd && n.urgency !== NotificationUrgency.Critical) return
            // A copy, because the sheet keeps drawing the card during its closing animation, after n is gone.
            const t = { appName: n.appName, summary: n.summary, body: n.body, image: n.image, appIcon: n.appIcon, urgency: n.urgency, expireTimeout: n.expireTimeout,
                actions: n.actions.map(a => ({ text: a.text, invoke: () => a.invoke() })), dismiss: () => n.dismiss() }
            if (root.toasts.length === 0 && !Ui.mediaOpen) Ui.sheetScreen = Ui.screen
            root.toasts = [t].concat(root.toasts)
            n.closed.connect(() => root.drop(t))
        }
    }
}
