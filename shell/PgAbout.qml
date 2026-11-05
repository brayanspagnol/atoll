import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "parse.js" as P

Page {
    id: pg
    readonly property string repo: "https://github.com/brayanspagnol/atoll"
    property string facts: ""
    readonly property var info: {
        const out = {}
        facts.split("\n").forEach(l => { const i = l.indexOf("="); if (i > 0) out[l.slice(0, i)] = l.slice(i + 1) })
        return out
    }
    property string latest: ""
    property string updateState: "idle" // idle, checking, failed, done
    readonly property bool hasUpdate: !!latest && P.newerVersion(latest, Ui.version)
    readonly property string report: "Atoll " + Ui.version + "\n" + facts.trim() + "\nMemory=" + P.bytes(Sys.memInfo.total)

    component Fact: ColumnLayout {
        property string k: ""; property string val: ""
        Layout.fillWidth: true; Layout.preferredWidth: 1
        spacing: 2
        Tx { text: k; dim: true; size: 13; Layout.fillWidth: true }
        Tx { text: val || "—"; mono: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
    }
    component Link: Btn {
        property string url: ""
        implicitHeight: 44
        onClicked: Qt.openUrlExternally(url)
    }

    Process {
        running: true
        command: ["sh", "-c", `
            echo "Hyprland=$(hyprctl version | head -1 | awk '{print $2}')"
            echo "Quickshell=$(qs --version | head -1 | awk '{print $2}')"
            echo "Kernel=$(uname -r)"
            echo "Distribution=$(. /etc/os-release 2>/dev/null; echo "$NAME")"
            echo "GPU=$(command -v lspci >/dev/null && lspci | grep -Ei 'vga|3d' | head -1 | cut -d: -f3- | sed 's/^ *//; s/ Corporation//; s/ (rev.*//')"
        `]
        stdout: StdioCollector { onStreamFinished: pg.facts = text }
    }
    Process {
        id: checker
        command: ["sh", "-c", "curl -fsS -m 8 https://api.github.com/repos/brayanspagnol/atoll/releases/latest | jq -er .tag_name"]
        stdout: StdioCollector { id: checked }
        onExited: code => {
            pg.latest = code === 0 ? checked.text.trim() : ""
            pg.updateState = code === 0 ? "done" : "failed"
        }
    }

    RowLayout {
        Layout.fillWidth: true; Layout.topMargin: 6; spacing: 22
        Image { source: Qt.resolvedUrl("logo.svg"); sourceSize: Qt.size(104, 104); Layout.preferredWidth: 104; Layout.preferredHeight: 104; Accessible.ignored: true }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Tx { text: "Atoll"; size: 34; strong: true; Layout.fillWidth: true; Accessible.role: Accessible.Heading; Accessible.name: text }
            Tx { text: Tr.t("Version %1").arg(Ui.version || "dev"); mono: true; dim: true; Layout.fillWidth: true }
            Tx { text: Tr.t("A glass desktop shell for Hyprland"); dim: true; Layout.fillWidth: true }
        }
    }
    Rectangle {
        Layout.fillWidth: true; Layout.topMargin: 8
        implicitHeight: 68; radius: 16
        color: Theme.hover
        border.width: 1; border.color: Theme.line
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 12
            Tx {
                Layout.fillWidth: true; strong: true
                color: pg.updateState === "failed" ? Theme.danger : pg.updateState === "done" ? Theme.good : Theme.muted
                text: pg.updateState === "checking" ? Tr.t("Checking…")
                    : pg.updateState === "failed" ? Tr.t("Couldn't check. Check your connection.")
                    : pg.updateState !== "done" ? Tr.t("Not checked yet")
                    : pg.hasUpdate ? Tr.t("Version %1 is available").arg(pg.latest) : Tr.t("You have the latest version")
            }
            Link { visible: pg.hasUpdate; text: Tr.t("See what's new"); url: pg.repo + "/releases/latest" }
            Btn {
                text: Tr.t("Check for updates")
                enabledB: pg.updateState !== "checking"
                onClicked: { pg.updateState = "checking"; checker.running = true }
            }
        }
    }

    Sec { title: Tr.t("Project") }
    Flow {
        Layout.fillWidth: true; spacing: 8
        Link { icon: "github"; text: Tr.t("Code on GitHub"); url: pg.repo }
        Link { icon: "note"; text: Tr.t("What's new"); url: pg.repo + "/blob/main/CHANGELOG.md" }
        Link { icon: "bug"; text: Tr.t("Report a problem"); url: pg.repo + "/issues/new/choose" }
        Link { icon: "law"; text: Tr.t("MIT License"); url: pg.repo + "/blob/main/LICENSE" }
    }

    Sec {
        title: Tr.t("This system")
        Btn { icon: "copy"; text: Tr.t("Copy for a report"); onClicked: { Quickshell.execDetached(["wl-copy", pg.report]); copied.restart() } }
    }
    Tx { visible: copied.running; text: Tr.t("Copied."); color: Theme.good }
    Timer { id: copied; interval: 2500 }
    GridLayout {
        Layout.fillWidth: true; columns: 3; columnSpacing: 16; rowSpacing: 16
        Fact { k: "Hyprland"; val: pg.info.Hyprland ?? "" }
        Fact { k: "Quickshell"; val: pg.info.Quickshell ?? "" }
        Fact { k: Tr.t("Kernel"); val: pg.info.Kernel ?? "" }
        Fact { k: Tr.t("Distribution"); val: pg.info.Distribution ?? "" }
        Fact { k: Tr.t("Graphics card"); val: pg.info.GPU ?? "" }
        Fact { k: Tr.t("Memory"); val: P.bytes(Sys.memInfo.total) }
    }

    Sec { title: Tr.t("Credits") }
    Tx { text: Tr.t("Made by Brayan Spagnol. Free software under the MIT license, © 2026."); dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Tx { text: Tr.t("Uses Hyprland, Quickshell, Lucide and Papirus icons, the Instrument Sans and JetBrains Mono fonts, and holidays from date.nager.at."); dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
}
