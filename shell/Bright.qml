pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Laptop panel through brightnessctl; external monitor through DDC/CI.
Singleton {
    id: b
    property int panel: -1
    property int external: -1
    function refresh() { pp.running = true; ep.running = true }
    function setPanel(v) { panel = v; Quickshell.execDetached(["brightnessctl", "-q", "s", v + "%"]) }
    function setExternal(v) { external = v; Quickshell.execDetached(["ddcutil", "--noverify", "--sleep-multiplier=.2", "setvcp", "10", String(v)]) }
    Process {
        id: pp; command: ["brightnessctl", "-m"]
        stdout: StdioCollector { onStreamFinished: { const m = text.match(/(\d+)%/); b.panel = m ? Number(m[1]) : -1 } }
    }
    Process {
        id: ep; command: ["ddcutil", "--brief", "getvcp", "10"]
        stdout: StdioCollector { onStreamFinished: { const m = text.match(/VCP 10 C (\d+) (\d+)/); b.external = m ? Math.round(100 * m[1] / m[2]) : -1 } }
    }
}
