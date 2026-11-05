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
    property string updateState: "idle" // idle, checking, failed, done, updating
    property string updateError: ""
    property bool packaged: false // installed by a package manager, which then owns updates
    readonly property bool hasUpdate: !!latest && P.newerVersion(latest, Ui.version)
    readonly property string model: P.modelName(info.Vendor, info.Product, info.ProductVersion)
    readonly property string kind: P.chassisKind(info.Chassis)
    readonly property string cpu: P.cpuName(info.CPU) + (info.Threads ? " · " + Tr.t("%1 cores, %2 threads").arg(info.Cores || "?").arg(info.Threads) : "")
    readonly property string disk: info.DiskSize ? (info.Disk ? info.Disk + " · " : "") + Tr.t("%1 of %2 used").arg(P.bytes(Number(info.DiskUsed))).arg(P.bytes(Number(info.DiskSize))) : ""
    readonly property string battery: info.BatteryHealth ? Tr.t("%1% of its original capacity").arg(info.BatteryHealth) + (info.BatteryCycles && info.BatteryCycles !== "0" ? " · " + Tr.t("%1 cycles").arg(info.BatteryCycles) : "") : ""
    readonly property string screens: Displays.monitors.filter(m => m.on).map(m => Displays.labelOf(m) + " · " + m.w + "×" + m.h + " @ " + Math.round(Number(m.rate)) + " Hz").join("\n")
    readonly property string report: ["Atoll " + Ui.version, "Model=" + model, "CPU=" + cpu, "GPU=" + (info.GPU ?? ""), "Memory=" + P.bytes(Sys.memInfo.total),
        "Disk=" + disk, "Battery=" + battery, "Screens=" + screens.replace(/\n/g, "; "), "Firmware=" + (info.Firmware ?? "").trim(),
        "Distribution=" + (info.Distribution ?? ""), "Kernel=" + (info.Kernel ?? ""), "Hyprland=" + (info.Hyprland ?? ""), "Quickshell=" + (info.Quickshell ?? "")].join("\n")

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
            d=/sys/class/dmi/id
            echo "Vendor=$(cat $d/sys_vendor 2>/dev/null)"
            echo "Product=$(cat $d/product_name 2>/dev/null)"
            echo "ProductVersion=$(cat $d/product_version 2>/dev/null)"
            echo "Chassis=$(cat $d/chassis_type 2>/dev/null)"
            echo "Firmware=$(cat $d/bios_version 2>/dev/null) $(cat $d/bios_date 2>/dev/null)"
            echo "CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-)"
            echo "Cores=$(lscpu -p=CORE,SOCKET 2>/dev/null | grep -v '^#' | sort -u | wc -l)"
            echo "Threads=$(nproc)"
            root=$(findmnt -no SOURCE / | cut -d[ -f1); disk=$(lsblk -no PKNAME "$root" 2>/dev/null | head -1)
            echo "Disk=$(lsblk -dno MODEL "/dev/\${disk:-x}" 2>/dev/null | sed 's/ *$//')"
            echo "DiskSize=$(df -B1 --output=size / | tail -1 | tr -d ' ')"
            echo "DiskUsed=$(df -B1 --output=used / | tail -1 | tr -d ' ')"
            for b in /sys/class/power_supply/BAT*; do
                [ -e "$b" ] || continue
                full=$(cat $b/energy_full $b/charge_full 2>/dev/null | head -1); design=$(cat $b/energy_full_design $b/charge_full_design 2>/dev/null | head -1)
                echo "BatteryHealth=$([ -n "$design" ] && [ "$design" -gt 0 ] && echo $((full * 100 / design)))"
                echo "BatteryCycles=$(cat $b/cycle_count 2>/dev/null)"
                break
            done
            echo "Uptime=$(cut -d. -f1 /proc/uptime)"
        `]
        stdout: StdioCollector { onStreamFinished: pg.facts = text }
    }
    Process {
        running: true
        command: ["test", "-e", "/usr/share/atoll/VERSION"]
        onExited: code => pg.packaged = code === 0
    }
    Process {
        id: updater
        command: [Quickshell.env("HOME") + "/.local/share/atoll/scripts/self-update", pg.latest]
        stderr: StdioCollector {}
        // On success the script restarts the shell, so this page only ever sees failures.
        onExited: code => {
            if (code === 0) return
            pg.updateError = Tr.t("Couldn't update. Check your connection.")
            pg.updateState = "done"
        }
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
                color: pg.updateState === "failed" || pg.updateError ? Theme.danger : pg.updateState === "done" ? Theme.good : Theme.muted
                text: pg.updateState === "checking" ? Tr.t("Checking…")
                    : pg.updateState === "updating" ? Tr.t("Updating…")
                    : pg.updateError ? pg.updateError
                    : pg.hasUpdate && pg.packaged ? Tr.t("Version %1 is available. Update the package, then run atoll-setup.").arg(pg.latest)
                    : pg.updateState === "failed" ? Tr.t("Couldn't check. Check your connection.")
                    : pg.updateState !== "done" ? Tr.t("Not checked yet")
                    : pg.hasUpdate ? Tr.t("Version %1 is available").arg(pg.latest) : Tr.t("You have the latest version")
            }
            Link { visible: pg.hasUpdate; text: Tr.t("See what's new"); url: pg.repo + "/releases/latest" }
            Btn {
                visible: pg.hasUpdate && !pg.packaged
                variant: "solid"
                text: Tr.t("Update now")
                enabledB: pg.updateState === "done"
                onClicked: { pg.updateError = ""; pg.updateState = "updating"; updater.running = true }
            }
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
    Tx { text: pg.kind === "laptop" ? Tr.t("Laptop") : pg.kind === "desktop" ? Tr.t("Desktop") : Tr.t("Computer"); dim: true; size: 13; Layout.topMargin: 2 }
    Tx { text: pg.model || "—"; size: 22; strong: true; Layout.fillWidth: true; wrapMode: Text.Wrap }
    GridLayout {
        Layout.fillWidth: true; Layout.topMargin: 6; columns: 3; columnSpacing: 16; rowSpacing: 16
        Fact { k: Tr.t("Processor"); val: pg.cpu }
        Fact { k: Tr.t("Graphics card"); val: pg.info.GPU ?? "" }
        Fact { k: Tr.t("Memory"); val: P.bytes(Sys.memInfo.total) }
        Fact { k: Tr.t("Storage"); val: pg.disk }
        Fact { visible: !!pg.battery; k: Tr.t("Battery"); val: pg.battery }
        Fact { k: Tr.t("Screens"); val: pg.screens }
    }
    Tx { text: Tr.t("Software").toUpperCase(); dim: true; size: 12; strong: true; font.letterSpacing: 1; Layout.topMargin: 10 }
    GridLayout {
        Layout.fillWidth: true; columns: 3; columnSpacing: 16; rowSpacing: 16
        Fact { k: Tr.t("Distribution"); val: pg.info.Distribution ?? "" }
        Fact { k: Tr.t("Kernel"); val: pg.info.Kernel ?? "" }
        Fact { k: Tr.t("Uptime"); val: pg.info.Uptime ? P.duration(Number(pg.info.Uptime)) : "" }
        Fact { k: "Hyprland"; val: pg.info.Hyprland ?? "" }
        Fact { k: "Quickshell"; val: pg.info.Quickshell ?? "" }
        Fact { k: Tr.t("Firmware"); val: (pg.info.Firmware ?? "").trim() }
    }

    Sec { title: Tr.t("Credits") }
    Tx { text: Tr.t("Made by Brayan Spagnol. Free software under the MIT license, © 2026."); dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
    Tx { text: Tr.t("Uses Hyprland, Quickshell, Lucide and Papirus icons, the Instrument Sans and JetBrains Mono fonts, and holidays from date.nager.at."); dim: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
}
