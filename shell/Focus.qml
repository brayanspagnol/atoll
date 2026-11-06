pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "focus.js" as F

// Focus mode: a timer in the island that can hold back music and notifications. A running one survives a shell restart.
Singleton {
    id: root
    property var session: null // see focus.js
    readonly property bool running: !!session
    readonly property string phase: session?.phase ?? "focus"
    readonly property bool hiding: running && phase === "focus" && Cfg.v.focusHide
    readonly property var allow: F.names(Cfg.v.focusAllow)
    readonly property int minutes: F.durations.includes(Cfg.v.focusMinutes) ? Cfg.v.focusMinutes : 25
    property real now: Date.now()
    readonly property real fraction: running ? F.fraction(session, now) : 1
    readonly property int seconds: running ? F.seconds(session, now) : 0
    readonly property string clock: F.clock(seconds)
    readonly property string label: (phase === "break" ? Tr.t("Break") : Tr.t("Focus")) + ", "
        + (session?.endsAt ? Tr.t("%1 min %2 s left") : Tr.t("%1 min %2 s elapsed")).arg(Math.floor(seconds / 60)).arg(seconds % 60)

    function lets(appName) { return F.allowed(appName, allow) }
    function begin(phase, minutes, pomodoro) { set(F.make(phase, minutes, Date.now(), pomodoro)) }
    function start(minutes) { begin("focus", minutes, false) }
    // The card's button: pomodoro, or the chosen length.
    function startChosen() { Cfg.v.focusPomodoro ? begin("focus", 25, true) : start(minutes) }
    function stop() { set(null) }
    function extend(minutes) { set(F.extend(session, minutes, Date.now())) }
    function set(s) {
        session = s
        now = Date.now()
        file.setText(s ? JSON.stringify(s) : "")
    }

    // Also runs right after a wake from suspend: a deadline that passed while asleep ends now.
    Timer { interval: 1000; repeat: true; running: root.running; onTriggered: root.tick() }
    function tick() {
        now = Date.now()
        if (!session?.endsAt || now < session.endsAt) return
        const done = session, after = F.next(done, now)
        set(after)
        const min = m => Tr.t("%1 min").arg(m)
        if (after) say(after.phase === "break" ? Tr.t("Break") : Tr.t("Focus"), min(F.minutes(after)), [])
        else if (done.phase === "focus") say(Tr.t("Focus finished"), min(F.minutes(done)), [
            { text: Tr.t("5 min break"), invoke: () => root.begin("break", 5, false) },
            { text: Tr.t("25 more min"), invoke: () => root.extend(25) }
        ])
        else say(Tr.t("Break finished"), min(F.minutes(done)), [{ text: Tr.t("Focus for %1 min").arg(25), invoke: () => root.start(25) }])
    }
    // A card among the notification toasts, never in the history. With buttons it waits to be answered.
    function say(summary, body, actions) {
        const t = { id: 0, time: Date.now(), appName: Tr.t("Focus"), icon: "timer", summary, body, image: "", appIcon: "", urgency: 1,
            expireTimeout: actions.length ? 3600000 : 6000, actions: [], dismiss: null, focus: true }
        t.dismiss = () => Notifs.drop(t)
        t.actions = actions.map(a => ({ text: a.text, invoke: () => { Notifs.drop(t); a.invoke() } }))
        Notifs.toasts.filter(o => o.focus).forEach(o => Notifs.drop(o))
        Notifs.pop(t)
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/atoll/focus.json"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
    Component.onCompleted: session = F.restore(file.text(), Date.now())

    IpcHandler {
        target: "focus"
        function start(minutes: int): void { root.start(minutes) }
        function stop(): void { root.stop() }
    }
}
