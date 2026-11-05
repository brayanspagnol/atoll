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
    property string launcherMode: "" // "", "clip" or "emoji": what the search lists
    onLauncherChanged: if (!launcher) launcherMode = ""
    function openLauncher(mode) { open = false; launcher = true; launcherMode = mode }
    property bool dockPeek: false
    property bool dockEditor: false
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
        { id: "monitor", key: "Alt+M", label: Tr.t("Monitor"), icon: "monitor", kw: "monitor display screen resolution rotation mirror " + Tr.t("display resolution rotation mirror") },
        { id: "ajustes", key: "Alt+J", label: Tr.t("Settings"), icon: "ajustes", kw: "settings wallpaper color language profile " + Tr.t("wallpaper color language profile") },
        { id: "energia", key: "Alt+E", label: Tr.t("Power"), icon: "energia", kw: "power shut down suspend restart lock log out " + Tr.t("shut down suspend restart lock log out") },
        { id: "sobre", key: "Alt+O", label: Tr.t("About"), icon: "sobre", kw: "about version update github " + Tr.t("version update") }
    ]
    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

    function show(p) { page = p; launcher = false; mediaOpen = false; dockEditor = false; open = true }
    function editDock() { open = false; launcher = false; mediaOpen = false; dockEditor = true }
    function toggle(p) { if (open && (!p || page === p)) open = false; else show(p || page) }
    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }

    readonly property string version: versionFile.text().trim()
    FileView { id: versionFile; path: Quickshell.env("HOME") + "/.local/share/atoll/VERSION"; blockLoading: true; printErrors: false }

    IpcHandler {
        target: "ui"
        function toggle(page: string): void { ui.toggle(page) }
        function launcher(): void { ui.open = false; ui.launcher = !ui.launcher }
        function clipboard(): void { ui.openLauncher("clip") }
        function emoji(): void { ui.openLauncher("emoji") }
        function dock(): void { ui.toggleDock() }
        function editDock(): void { ui.editDock() }
        function close(): void { ui.open = false; ui.launcher = false }
    }
}
