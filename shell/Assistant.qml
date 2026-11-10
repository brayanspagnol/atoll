pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "assistant.js" as A
import "term.js" as T

// Lagu's brain: runs the AI command-line tool the person already uses (see assistant.js) and keeps the conversation
// for the island and the page. Its own conversations are kept in ~/.local/state/atoll/assistant.json (see assistant.js),
// so they can be read again and continued; the tools' own session files are never read.
Singleton {
    id: root
    // { id, name, bin, installed }; bin is the full path once found.
    property var providers: [
        { id: "claude", name: "Claude Code", bin: "claude", installed: false },
        { id: "cursor", name: "Cursor", bin: "cursor-agent", installed: false },
        { id: "codex", name: "Codex", bin: "codex", installed: false }
    ]
    readonly property string provider: {
        const ok = providers.filter(p => p.installed)
        return (ok.find(p => p.id === Cfg.v.aiProvider) ?? ok[0])?.id ?? ""
    }
    // The model and effort the profile picked for the tool in use, checked again in A.argv; "" is the tool's default.
    readonly property string model: { const m = Cfg.v.aiModel; return A.modelOk(m?.[provider]) ? m[provider] : "" }
    readonly property string effort: provider === "claude" && A.effortOk(Cfg.v.aiEffort) ? Cfg.v.aiEffort : ""
    // Cursor's models for this account, listed once per shell when first asked for: [{ id, name }].
    property var cursorModels: []
    function listModels() { if (!cursorModels.length && !lister.running && info("cursor")?.installed) lister.running = true }
    function setModel(m) {
        if (!provider || m !== "" && !A.modelOk(m)) return
        const all = Cfg.v.aiModel && typeof Cfg.v.aiModel === "object" && !Array.isArray(Cfg.v.aiModel) ? Cfg.v.aiModel : {}
        Cfg.v.aiModel = Object.assign({}, all, { [provider]: m })
    }
    function setEffort(e) { if (e === "" || A.effortOk(e)) Cfg.v.aiEffort = e }
    // What the menus offer for the tool in use: [{ id, name }], "" first for the tool's default. Claude takes these aliases
    // for its latest models; Cursor lists its own (its "auto" is the default already); Codex has no list here.
    readonly property var modelChoices: {
        const known = provider === "claude" ? [{ id: "opus", name: "Opus" }, { id: "sonnet", name: "Sonnet" }, { id: "haiku", name: "Haiku" }, { id: "fable", name: "Fable" }]
            : provider === "cursor" ? cursorModels.filter(c => c.id !== "auto") : []
        const all = [{ id: "", name: Tr.t("Default") }].concat(known)
        return model && !all.some(c => c.id === model) ? all.concat([{ id: model, name: model }]) : all
    }
    readonly property var effortChoices: [{ id: "", name: Tr.t("Default") }, { id: "low", name: Tr.t("Low") }, { id: "medium", name: Tr.t("Medium") },
        { id: "high", name: Tr.t("High") }, { id: "xhigh", name: Tr.t("Extra high") }, { id: "max", name: Tr.t("Max") }]
    readonly property string modelName: model ? (modelChoices.find(c => c.id === model)?.name ?? model) : ""
    property bool busy: false
    property string mood: "idle" // idle, thinking, working, waiting, done, error; the UI sets listening and sleeping itself
    // { kind: user, step, text, card, denied or error, text, detail, card, denials, login }
    property var items: []
    property string session: ""
    property string sessionProvider: "" // the tool the session belongs to; another tool cannot resume it
    property var history: [] // past conversations, newest first: { id, provider, model, title, updated, items }
    property var pending: [] // the last turn's denials: { tool, input, spec }

    function info(id) { return providers.find(p => p.id === id) ?? null }
    function add(kind, o) {
        items = items.concat([Object.assign({ kind, text: "", detail: "", card: null, denials: [], login: false }, o)]).slice(-40)
    }
    function fail(text, login) { add("error", { text, login: !!login }); mood = "error" }

    function refresh() {
        if (!Cfg.ready) return
        detect.running = false
        detect.running = true
    }
    function ask(text) {
        const prompt = String(text ?? "").trim()
        if (!prompt || busy) return
        add("user", { text: prompt })
        pending = []
        if (!provider) return fail(Tr.t("No AI command-line tool is installed."))
        // The tool changed since this conversation began: it goes on in a new one, and the old one stays in the history.
        if (session && sessionProvider !== provider) { items = items.slice(-1); session = ""; sessionProvider = "" }
        run(prompt, [])
    }
    // The denied tools, allowed for one more turn of the same conversation.
    function allow() {
        const specs = pending.map(d => d.spec).filter(s => s)
        if (busy || !specs.length || !session || !provider) return
        pending = []
        run("Continue.", specs)
    }
    function deny() { pending = []; if (!busy) mood = "idle" }
    function stop() {
        if (!busy) return
        proc.stopped = true
        proc.running = false
        busy = false
        mood = "idle"
    }
    // A new conversation. The one before is already in the history: it is kept each time a turn ends.
    function reset() { stop(); items = []; session = ""; sessionProvider = ""; pending = []; mood = "idle" }
    // A past conversation, read back. The next question continues it with its own tool, picked again if still installed.
    function open(id) {
        const c = history.find(h => h.id === id)
        if (!c) return
        reset()
        items = c.items
        session = c.id
        sessionProvider = c.provider
        if (info(c.provider)?.installed) Cfg.v.aiProvider = c.provider
    }
    // Out of Atoll's list only; the tool's own session is left alone.
    function forget(id) { history = history.filter(h => h.id !== id); save() }
    function keep() {
        if (!session) return
        const said = items.find(i => i.kind === "user")
        history = A.remember(history, { id: session, provider: sessionProvider, model, title: said?.text ?? "", updated: Date.now(), items })
        save()
    }
    function save() { store.setText(JSON.stringify(history)) }
    onBusyChanged: if (!busy) keep()
    onProviderChanged: if (provider === "cursor") listModels()
    // The person logs in themselves, in a terminal; only fixed arguments reach the command.
    function login(id) {
        const p = info(id), args = A.loginArgs(id)
        if (!p?.installed || !args.length) return
        Quickshell.execDetached(T.argv([p.bin].concat(args.slice(1))))
    }

    function run(prompt, allowSpecs) {
        const p = info(provider)
        const cmd = A.argv(provider, { prompt, session, allow: allowSpecs, ask: Cfg.v.aiAsk, system: A.system(Ui.pages.map(x => x.id)), model, effort })
        cmd[0] = p.bin
        proc.who = provider
        proc.stopped = false
        proc.ended = false
        proc.said = false
        proc.err = ""
        proc.command = cmd
        busy = true
        mood = "thinking"
        quiet.restart()
        proc.running = true
    }
    function take(e) {
        if (e.kind === "session") {
            // A resumed conversation can come back under a new id: it is the same conversation, kept once.
            if (session && e.id !== session) history = history.filter(h => h.id !== session)
            session = e.id
            sessionProvider = proc.who
        }
        else if (e.kind === "step") { add("step", { text: Tr.t(e.label), detail: e.detail }); mood = "working" }
        else if (e.kind === "text") { show(e.text); mood = "thinking" }
        else if (e.kind === "error") { proc.ended = true; fail(e.login ? Tr.t("You are not logged in to %1.").arg(info(proc.who)?.name ?? proc.who) : e.text || Tr.t("The assistant stopped with an error."), e.login) }
        else if (e.kind === "done") {
            proc.ended = true
            if (!proc.said && e.text.trim()) show(e.text) // the result repeats the last message, so only when none came
            pending = e.denials
            if (e.denials.length) add("denied", { denials: e.denials })
            mood = e.denials.length ? "waiting" : "done"
        }
    }
    function show(text) {
        const c = A.card(text, Ui.pages.map(x => x.id))
        proc.said = true
        if (c.text) add("text", { text: c.text })
        if (c.card) add("card", { card: c.card })
    }

    Process {
        id: proc
        property string who: ""
        property bool stopped: false
        property bool ended: false
        property bool said: false
        property string err: ""
        workingDirectory: Quickshell.env("HOME")
        stdout: SplitParser {
            onRead: data => {
                if (proc.stopped) return
                quiet.restart()
                A.parse(proc.who, data).forEach(e => root.take(e))
            }
        }
        stderr: SplitParser { onRead: data => proc.err = (proc.err + "\n" + data).slice(-4000) }
        onExited: code => {
            quiet.stop()
            if (stopped) return
            root.busy = false
            if (ended) return
            if (code !== 0) {
                const e = A.failure(err)
                root.fail(e.login ? Tr.t("You are not logged in to %1.").arg(root.info(who)?.name ?? who) : e.text || Tr.t("The assistant stopped with an error."), e.login)
            } else root.fail(Tr.t("The assistant stopped without answering."))
        }
    }
    // No output for 2 minutes: the tool is stuck.
    Timer {
        id: quiet
        interval: 120000
        onTriggered: if (root.busy) { root.stop(); root.fail(Tr.t("The assistant took too long to answer.")) }
    }
    Timer { interval: 4000; running: root.mood === "done"; onTriggered: if (root.mood === "done") root.mood = "idle" }

    // Each installed tool's full path. ~/.local/bin is where they install themselves, and a session may not have it on PATH.
    Process {
        id: detect
        command: ["sh", "-c", 'for b in claude cursor-agent codex; do p=$(PATH="$PATH:$HOME/.local/bin" command -v "$b") && printf "%s\\t%s\\n" "$b" "$p"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {}
                text.split("\n").forEach(l => { const [b, path] = l.split("\t"); if (b && path?.startsWith("/")) found[b] = path })
                root.providers = root.providers.map(p => {
                    const bin = { claude: "claude", cursor: "cursor-agent", codex: "codex" }[p.id]
                    return { id: p.id, name: p.name, bin: found[bin] ?? bin, installed: !!found[bin] }
                })
            }
        }
    }
    Process {
        id: lister
        command: [root.info("cursor")?.bin ?? "cursor-agent", "--list-models"]
        workingDirectory: Quickshell.env("HOME")
        stdout: StdioCollector { onStreamFinished: root.cursorModels = A.models(text) }
    }

    // The history is private, so its folder and file are for this user only. The file is made 600 before the first write,
    // and an atomic write keeps the mode of the file it replaces.
    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.local/state/atoll/assistant.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
    Connections { target: Cfg; function onReadyChanged() { root.refresh() } }
    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c", 'umask 077 && mkdir -p "$1" && chmod 700 "$1" && touch "$1/assistant.json" && chmod 600 "$1/assistant.json"', "sh", Quickshell.env("HOME") + "/.local/state/atoll"])
        history = A.restore(store.text())
        refresh()
    }
}
