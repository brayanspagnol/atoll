pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root
    // History, oldest first. It survives a shell restart, without the actions, which need the live notification.
    property var all: []
    property var toasts: []
    readonly property int limit: 100
    // Missing icons must fall back to a letter, not Qt's magenta placeholder.
    function iconOf(n) {
        const img = n.image || ""
        if (img.startsWith("image://icon/")) return Quickshell.iconPath(img.slice(13), true)
        return img || (n.appIcon ? Quickshell.iconPath(n.appIcon, true) : "")
    }
    function drop(n) { toasts = toasts.filter(t => t !== n) }
    function remove(n) { all = all.filter(t => t !== n); saver.restart() }
    function clear() { all.slice().forEach(n => n.dismiss()) }
    function clearApp(name) { all.filter(n => n.appName === name).forEach(n => n.dismiss()) }
    function restore(saved) {
        return {
            id: saved.id, time: saved.time, appName: saved.appName, summary: saved.summary, body: saved.body, appIcon: saved.appIcon, urgency: saved.urgency, expireTimeout: -1,
            // Generated images only exist in this run; icon names and files last.
            image: /^(image:\/\/icon\/|file:|\/)/.test(saved.image || "") ? saved.image : "",
            actions: [], dismiss() { root.remove(this) }
        }
    }
    function attach(t, n) {
        t.actions = n.actions.map(a => ({ text: a.text, invoke: () => a.invoke() }))
        t.dismiss = () => n.dismiss()
        n.closed.connect(() => { root.drop(t); root.remove(t) })
    }
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/atoll/notifications.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
    Timer {
        id: saver
        interval: 500
        // Messages are private, so their folder is for this user only: see Component.onCompleted.
        onTriggered: file.setText(JSON.stringify(root.all.map(t => ({ id: t.id, time: t.time, appName: t.appName, summary: t.summary, body: t.body, image: t.image, appIcon: t.appIcon, urgency: t.urgency }))))
    }
    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1"', "sh", Quickshell.env("HOME") + "/.local/state/atoll"])
        try { all = JSON.parse(file.text() || "[]").map(restore) } catch (e) { all = [] }
    }
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
            if (n.lastGeneration) { // carried over a shell reload: already shown once
                const same = root.all.find(t => t.id === n.id && t.summary === n.summary)
                if (same) root.attach(same, n)
                return
            }
            // A copy, because the sheet keeps drawing the card during its closing animation, after n is gone.
            const t = { id: n.id, time: Date.now(), appName: n.appName, summary: n.summary, body: n.body, image: n.image, appIcon: n.appIcon, urgency: n.urgency, expireTimeout: n.expireTimeout }
            root.attach(t, n)
            // An app replacing its notification updates this same object.
            const refresh = () => { t.summary = n.summary; t.body = n.body; root.all = root.all.slice(); saver.restart() }
            n.summaryChanged.connect(refresh)
            n.bodyChanged.connect(refresh)
            if (!n.transient) { root.all = root.all.concat([t]).slice(-root.limit); saver.restart() }
            if (Cfg.v.dnd && n.urgency !== NotificationUrgency.Critical) return
            if (root.toasts.length === 0 && !Ui.mediaOpen) Ui.sheetScreen = Ui.screen
            root.toasts = [t].concat(root.toasts)
        }
    }
}
