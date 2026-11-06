pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Atoll profiles. Each one is a settings file, so a profile switches theme, dock, language and idle times together.
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string script: home + "/.local/share/atoll/scripts/profiles"
    readonly property string active: activeFile.text().trim() || "default"
    readonly property string path: home + "/.config/atoll/profiles/" + active + ".json"
    property var list: []
    property var photos: []
    property var wallpapers: []

    function refresh() { lister.running = false; lister.running = true; photoLister.running = true; wallpaperLister.running = true }
    // One at a time, in order: a second request must not take over the first one's callback.
    property var queue: []
    function run(args, then) {
        queue = queue.concat([{ args, then: then ?? null }])
        next()
    }
    function next() {
        if (!queue.length || task.running) return
        const job = queue[0]
        queue = queue.slice(1)
        task.then = job.then
        task.command = [script].concat(job.args)
        task.running = true
    }
    function select(id) {
        activeFile.setText(id + "\n")
        applied.restart()
    }
    // These two live outside the shell, so they follow the new profile by hand.
    Timer { id: applied; interval: 400; onTriggered: { Night.apply(); Idle.apply() } }
    function create(name) {
        const id = "p" + Date.now().toString(36)
        run(["create", id, active, name], () => select(id))
    }
    function removeActive() {
        const next = list.find(p => p.id !== active)
        if (!next) return
        const old = active
        select(next.id)
        run(["delete", old])
    }
    // The picker is a normal window, and the control center would cover it, so it closes meanwhile.
    function addPhoto() { pick("photo", Tr.t("Choose a photo")) }
    function addWallpaper() { pick("wallpaper", Tr.t("Choose a wallpaper")) }
    function pick(kind, title) {
        Ui.open = false
        picker.kind = kind
        picker.title = title
        picker.running = true
    }
    function forget(kind, path) {
        if (Cfg.v[kind] === path) Cfg.v[kind] = ""
        const screens = Object.assign({}, Cfg.v.wallpapers ?? {})
        for (const name in screens) if (screens[name] === path) delete screens[name]
        Cfg.v.wallpapers = screens
        run(["forget", kind, path])
    }
    // A wallpaper chosen before the gallery existed joins it, so it stays there after picking another one.
    function keepWallpaper() {
        const dir = home + "/.local/share/atoll/backgrounds/"
        if (Cfg.v.wallpaper && !Cfg.v.wallpaper.startsWith(dir)) run(["wallpaper", Cfg.v.wallpaper], out => Cfg.v.wallpaper = out)
    }

    FileView {
        id: activeFile
        path: root.home + "/.config/atoll/active-profile"
        blockLoading: true
        printErrors: false
    }
    Process {
        id: lister
        command: [root.script, "list"]
        running: true
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.list = JSON.parse(text) }
    }
    Process {
        id: photoLister
        command: [root.script, "photos"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.photos = text.split("\n").filter(Boolean) }
    }
    Process {
        id: wallpaperLister
        command: [root.script, "wallpapers"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.wallpapers = text.split("\n").filter(Boolean) }
    }
    Process {
        id: picker
        property string kind: ""
        property string title: ""
        command: ["zenity", "--file-selection", "--title=" + title, "--filename=" + root.home + "/Pictures/",
            "--file-filter=" + Tr.t("Images") + " | *.png *.PNG *.jpg *.JPG *.jpeg *.JPEG *.webp *.WEBP"]
        stdout: StdioCollector { id: picked }
        onExited: {
            Ui.show("ajustes")
            const image = picked.text.trim()
            if (image) root.run([kind, image], out => Cfg.v[kind] = out)
        }
    }
    Process {
        id: task
        property var then: null
        stdout: StdioCollector {
            id: taskOut
        }
        onExited: code => {
            if (code === 0 && then) then(taskOut.text.trim())
            root.refresh()
            root.next() // after the callback, which may queue more work
        }
    }
}
