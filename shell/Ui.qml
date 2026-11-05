pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: ui
    property bool open: false
    property string page: "som"
    property bool launcher: false
    property bool dockPeek: false
    property bool mediaOpen: false
    property var sheetScreen: null
    property var sheetIsland: null
    function toggleMedia(screen, island) {
        if (!mediaOpen) { sheetScreen = screen; sheetIsland = island; open = false }
        mediaOpen = !mediaOpen
    }
    function toggleDock() { dockPeek = !dockPeek }
    // A dock raised by shortcut goes away on its own; hovering keeps it up.
    Timer { interval: 4000; running: ui.dockPeek; onTriggered: ui.dockPeek = false }
    readonly property var pages: [
        { id: "som", key: "Alt+A", label: Tr.t("Sound"), icon: "som", kw: "volume audio microphone " + Tr.t("volume audio microphone") },
        { id: "rede", key: "Alt+I", label: Tr.t("Internet"), icon: "rede", kw: "wifi network cable " + Tr.t("wifi network cable") },
        { id: "bt", key: "Alt+B", label: "Bluetooth", icon: "bt", kw: "headphones pair " + Tr.t("headphones pair") },
        { id: "perf", key: "Alt+D", label: Tr.t("Performance"), icon: "perf", kw: "cpu memory processes temperature battery " + Tr.t("cpu memory processes temperature battery") },
        { id: "cal", key: "Alt+C", label: Tr.t("Calendar"), icon: "cal", kw: "agenda event date " + Tr.t("agenda event date") },
        { id: "avisos", key: "Alt+V", label: Tr.t("Notifications"), icon: "avisos", kw: "notifications do not disturb " + Tr.t("do not disturb") },
        { id: "ajustes", key: "Alt+J", label: Tr.t("Settings"), icon: "ajustes", kw: "settings display brightness wallpaper color language " + Tr.t("display brightness wallpaper color language") },
        { id: "energia", key: "Alt+E", label: Tr.t("Power"), icon: "energia", kw: "power shut down suspend restart lock log out " + Tr.t("shut down suspend restart lock log out") }
    ]
    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

    function show(p) { page = p; launcher = false; mediaOpen = false; open = true }
    function toggle(p) { if (open && (!p || page === p)) open = false; else show(p || page) }
    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }

    IpcHandler {
        target: "ui"
        function toggle(page: string): void { ui.toggle(page) }
        function launcher(): void { ui.open = false; ui.launcher = !ui.launcher }
        function dock(): void { ui.toggleDock() }
        function close(): void { ui.open = false; ui.launcher = false }
    }
}
