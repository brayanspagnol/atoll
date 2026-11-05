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

    function refresh() { lister.running = false; lister.running = true; photoLister.running = true }
    function run(args, then) {
        task.then = then ?? null
        task.command = [script].concat(args)
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
    function addPhoto() {
        Ui.open = false
        picker.running = true
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
        id: picker
        command: ["zenity", "--file-selection", "--title=" + Tr.t("Choose a photo"), "--filename=" + root.home + "/Pictures/",
            "--file-filter=" + Tr.t("Images") + " | *.png *.PNG *.jpg *.JPG *.jpeg *.JPEG *.webp *.WEBP"]
        stdout: StdioCollector { id: picked }
        onExited: {
            Ui.show("ajustes")
            const image = picked.text.trim()
            if (image) root.run(["photo", image], out => Cfg.v.photo = out)
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
        }
    }
}
