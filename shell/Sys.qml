pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "parse.js" as P

Singleton {
    id: sys
    readonly property int window: 150 // samples at 2 s = 5 min
    property real cpu: 0
    property var cores: []
    property var cpuHist: []
    property var memInfo: ({ total: 1, used: 0, swapTotal: 0, swapUsed: 0 })
    property var memHist: []
    property real rxRate: 0
    property real txRate: 0
    property var rxHist: []
    property var txHist: []
    property real temp: 0
    property var tempHist: []
    property var disk: ({ used: 0, size: 1 })
    property var procs: []
    property string procSort: "cpu"
    property bool procsActive: false
    property var _cpuPrev: []
    property var _netPrev: null

    function push(a, v) { const o = a.concat([v]); return o.length > window ? o.slice(o.length - window) : o }

    FileView {
        id: stat; path: "/proc/stat"
        onLoaded: {
            const now = P.cpu(text())
            if (sys._cpuPrev.length === now.length) {
                const pct = now.map((c, i) => {
                    const dt = c.total - sys._cpuPrev[i].total
                    return dt > 0 ? Math.max(0, 100 * (1 - (c.idle - sys._cpuPrev[i].idle) / dt)) : 0
                })
                sys.cpu = pct[0]; sys.cores = pct.slice(1); sys.cpuHist = sys.push(sys.cpuHist, pct[0])
            }
            sys._cpuPrev = now
        }
    }
    FileView {
        id: mem; path: "/proc/meminfo"
        onLoaded: { const m = P.mem(text()); sys.memInfo = m; sys.memHist = sys.push(sys.memHist, 100 * m.used / m.total) }
    }
    FileView {
        id: netdev; path: "/proc/net/dev"
        onLoaded: {
            const n = P.net(text())
            if (sys._netPrev) {
                // Counters can restart after suspend; a negative delta is not traffic.
                sys.rxRate = Math.max(0, n.rx - sys._netPrev.rx) / 2; sys.txRate = Math.max(0, n.tx - sys._netPrev.tx) / 2
                sys.rxHist = sys.push(sys.rxHist, sys.rxRate); sys.txHist = sys.push(sys.txHist, sys.txRate)
            }
            sys._netPrev = n
        }
    }
    FileView {
        id: thermal; path: ""
        onLoaded: { sys.temp = Number(text()) / 1000; sys.tempHist = sys.push(sys.tempHist, sys.temp) }
    }
    Process {
        running: true
        command: [Quickshell.env("HOME") + "/.local/share/atoll/scripts/cpu-temp-path"]
        stdout: StdioCollector { onStreamFinished: thermal.path = text.trim().split("\n")[0] }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { stat.reload(); mem.reload(); netdev.reload(); if (thermal.path.toString()) thermal.reload() }
    }
    Process {
        id: dfp
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector { onStreamFinished: { const f = text.trim().split("\n").pop().trim().split(/\s+/).map(Number); if (f[1]) sys.disk = { used: f[0], size: f[1] } } }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: dfp.running = true }

    Process {
        id: topp
        // Isolated HOME/locale: the user's toprc could reorder the columns the parser relies on.
        environment: ({ HOME: "/nonexistent", XDG_CONFIG_HOME: "/nonexistent", LC_ALL: "C", COLUMNS: "200" })
        command: ["top", "-b", "-n2", "-d0.5", "-w200", "-o", sys.procSort === "cpu" ? "%CPU" : "%MEM"]
        stdout: StdioCollector { onStreamFinished: sys.procs = P.top(text, 10) }
    }
    Timer { interval: 3000; running: sys.procsActive; repeat: true; triggeredOnStart: true; onTriggered: topp.running = true }
}
