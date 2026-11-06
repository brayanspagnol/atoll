pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "backup.js" as B

// The Backup page's state. Picking a file closes the control center, which unloads the page, so the state lives here.
Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string script: home + "/.local/share/atoll/scripts/backup"
    readonly property var screens: Quickshell.screens.map(s => s.name)

    // Export: a profile id or "all", and whether the pictures go too.
    property string which: "all"
    property bool images: true
    property var size: null
    // Import: "" (start), "target", "review" or "done".
    property string step: ""
    property string file: ""
    property var info: null
    property string from: ""
    property string into: "replace"
    property var picked: ({})
    property string error: ""
    property string saved: "" // the exported file, or the copy made before importing
    property var importedFiles: []
    readonly property bool busy: estimator.running || exporter.running || inspector.running || importer.running

    readonly property var review: info && step === "review" ? B.review(info, from, screens, s => Tr.t(s), Tr.languages, Theme.accents) : null
    readonly property var chosen: review ? B.choice(review, picked) : null
    function pick(id, on) { picked = Object.assign({}, picked, { [id]: on }) }

    function estimate() { estimator.running = false; estimator.running = true }
    function chooseExport() { pickFor("export") }
    function chooseImport() { pickFor("import") }
    function pickFor(kind) {
        error = ""
        Ui.open = false
        picker.kind = kind
        picker.running = true
    }
    function reset() { step = ""; info = null; file = ""; picked = {}; saved = "" }
    function back() { error = ""; if (step === "review") step = "target"; else reset() }
    function next() { picked = {}; step = "review" }
    function save(path) {
        exporter.command = [script, "export", which, path, images ? "images" : ""]
        exporter.target = path
        exporter.running = true
    }
    function inspect(path) {
        file = path
        inspector.command = [script, "inspect", path].concat(screens)
        inspector.running = true
    }
    function apply() {
        const c = chosen
        importedFiles = c.files
        importer.command = [script, "import", file, "--profile", from, "--into", into, "--keys", c.keys.join(","), "--files", c.files.join(","), "--screens", screens.join(",")]
        importer.running = true
    }

    Process {
        id: estimator
        command: [root.script, "estimate", root.which]
        stdout: StdioCollector { onStreamFinished: { try { root.size = JSON.parse(text) } catch (e) { root.size = null } } }
    }
    onWhichChanged: estimate()
    Process {
        id: picker
        property string kind: ""
        readonly property string stamp: Qt.formatDate(new Date(), "yyyy-MM-dd")
        command: kind === "export"
            ? ["zenity", "--file-selection", "--save", "--title=" + Tr.t("Save backup"), "--filename=" + root.home + "/atoll-backup-" + stamp + ".tar.gz"]
            : ["zenity", "--file-selection", "--title=" + Tr.t("Choose a backup"), "--filename=" + root.home + "/", "--file-filter=" + Tr.t("Atoll backup") + " | *.tar.gz *.tgz"]
        stdout: StdioCollector { id: pickedOut }
        onExited: {
            Ui.show("backup")
            const path = pickedOut.text.trim()
            if (!path) return
            if (kind === "export") root.save(path)
            else root.inspect(path)
        }
    }
    Process {
        id: exporter
        property string target: ""
        stderr: StdioCollector { id: exportErr }
        onExited: code => {
            root.saved = code === 0 ? target : ""
            root.error = code === 0 ? "" : Tr.t("Could not save the backup.") + " " + exportErr.text.trim()
        }
    }
    Process {
        id: inspector
        stdout: StdioCollector { id: inspectOut }
        stderr: StdioCollector { id: inspectErr }
        onExited: code => {
            let info = null
            try { if (code === 0) info = JSON.parse(inspectOut.text) } catch (e) {}
            if (!info) { root.error = Tr.t("This file is not an Atoll backup, or it is damaged or unsafe.") + " " + inspectErr.text.trim(); root.reset(); return }
            root.info = info
            const ids = Object.keys(info.profiles ?? {})
            root.from = ids.includes(info.manifest?.active) ? info.manifest.active : ids[0] ?? ""
            root.into = ids.length ? "replace" : "new"
            root.saved = ""
            root.step = "target"
        }
    }
    Process {
        id: importer
        stdout: StdioCollector { id: importOut }
        stderr: StdioCollector { id: importErr }
        onExited: code => {
            let out = null
            try { if (code === 0) out = JSON.parse(importOut.text) } catch (e) {}
            if (!out) { root.error = Tr.t("Nothing was imported.") + " " + importErr.text.trim(); return }
            root.saved = out.backup
            root.step = "done"
            Profiles.refresh()
            if (root.into === "new" && out.id) Profiles.select(out.id)
            else { Night.apply(); Idle.apply() }
        }
    }
}
