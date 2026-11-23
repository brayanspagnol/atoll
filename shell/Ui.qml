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
    property bool overview: false
    property bool clipboard: false
    function openClipboard() { open = false; launcher = false; overview = false; clipboard = true }
    property string launcherMode: "" // "", "clip" or "emoji": what the search lists
    onLauncherChanged: { if (!launcher) launcherMode = ""; else askOpen = false }
    function openLauncher(mode) { open = false; launcher = true; launcherMode = mode }
    property bool dockPeek: false
    property bool dockEditor: false
    property bool mediaOpen: false
    property var sheetScreen: null
    property var sheetIsland: null
    // Each screen's island width, by output name: the assistant's bar grows out of it and shrinks back into it.
    property var islandWidths: ({})
    function setIslandWidth(name, w) { if (name && islandWidths[name] !== w) islandWidths = Object.assign({}, islandWidths, { [name]: w }) }
    function toggleMedia(screen, island) {
        if (!mediaOpen) { sheetScreen = screen; sheetIsland = island; open = false }
        mediaOpen = !mediaOpen
    }
    // The weather and focus cards drop from the same place as the music card, so only one is open.
    property bool weatherOpen: false
    property bool focusOpen: false
    function toggleWeather(screen, island) {
        if (!weatherOpen) { sheetScreen = screen; sheetIsland = island; open = false; mediaOpen = false; focusOpen = false }
        weatherOpen = !weatherOpen
    }
    function toggleFocus(screen, island) {
        if (!focusOpen) { sheetScreen = screen; sheetIsland = island; open = false; mediaOpen = false; weatherOpen = false }
        focusOpen = !focusOpen
    }
    onMediaOpenChanged: if (mediaOpen) { weatherOpen = false; focusOpen = false; askOpen = false }
    onOpenChanged: if (open) { weatherOpen = false; focusOpen = false; askOpen = false }
    onDockEditorChanged: if (dockEditor) { weatherOpen = false; focusOpen = false; askOpen = false }
    onWeatherOpenChanged: if (weatherOpen) askOpen = false
    onFocusOpenChanged: if (focusOpen) askOpen = false
    onOverviewChanged: if (overview) askOpen = false
    onClipboardChanged: if (clipboard) askOpen = false
    // The assistant takes the island's place, so it closes every other panel and they close it.
    property bool askOpen: false
    property var askScreen: null
    function toggleAsk(screen) {
        if (!askOpen) { askScreen = screen ?? null; open = false; launcher = false; overview = false; clipboard = false; mediaOpen = false; weatherOpen = false; focusOpen = false; dockEditor = false }
        askOpen = !askOpen
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
        { id: "clima", key: "Alt+W", label: Tr.t("Weather"), icon: "cloudSun", kw: "weather forecast temperature city " + Tr.t("forecast temperature city") },
        { id: "ia", key: "Alt+G", label: Tr.t("Assistant"), icon: "sparkle", kw: "assistant ai claude cursor openai codex chat lagu " + Tr.t("artificial intelligence chat") },
        { id: "avisos", key: "Alt+V", label: Tr.t("Notifications"), icon: "avisos", kw: "notifications do not disturb " + Tr.t("do not disturb") },
        { id: "monitor", key: "Alt+M", label: Tr.t("Monitor"), icon: "monitor", kw: "monitor display screen resolution rotation mirror " + Tr.t("display resolution rotation mirror") },
        { id: "ajustes", key: "Alt+J", label: Tr.t("Settings"), icon: "ajustes", kw: "settings language keyboard mouse touchpad idle calendar holidays night light " + Tr.t("language keyboard idle") },
        { id: "visual", key: "Alt+T", label: Tr.t("Personalization"), icon: "palette", kw: "profile photo theme dark light accent color wallpaper " + Tr.t("profile photo theme color wallpaper") },
        { id: "atalhos", key: "Alt+K", label: Tr.t("Shortcuts"), icon: "keyboard", kw: "shortcuts keys keybinds hotkeys " + Tr.t("shortcuts keys") },
        // A group: one card in the list (see groups), opening into these. parent names it in the search and the page's header.
        { id: "topo", key: "", group: "aplicativos", parent: Tr.t("Applications"), label: Tr.t("On top"), icon: "pin", kw: "island top bar pin unpin " + Tr.t("island pin unpin") },
        { id: "instalados", key: "", group: "aplicativos", parent: Tr.t("Applications"), label: Tr.t("Installed"), icon: "download", kw: "installed apps uninstall remove flatpak appimage " + Tr.t("apps uninstall remove") },
        { id: "apps", key: "", group: "aplicativos", parent: Tr.t("Applications"), label: Tr.t("Default"), icon: "grid", kw: "default apps browser terminal files " + Tr.t("browser terminal files") },
        { id: "regras", key: "Alt+R", label: Tr.t("Window rules"), icon: "window", kw: "window rules float workspace " + Tr.t("float workspace") },
        { id: "backup", key: "Alt+U", label: Tr.t("Backup"), icon: "archive", kw: "backup export import profile " + Tr.t("export import profile") },
        { id: "energia", key: "Alt+E", label: Tr.t("Power"), icon: "energia", kw: "power shut down suspend restart lock log out " + Tr.t("shut down suspend restart lock log out") },
        { id: "sobre", key: "Alt+O", label: Tr.t("About"), icon: "sobre", kw: "about version update github " + Tr.t("version update") }
    ].map(p => Object.assign({ full: p.parent ? p.parent + " › " + p.label : p.label }, p)) // full: the name outside the list, with its group
    // A group's card in the list. Its id also works as a page for toggle and show: the one last used in it.
    readonly property var groups: ({ aplicativos: { label: Tr.t("Applications"), icon: "grid", key: "Alt+N" } })
    property var lastIn: ({ aplicativos: "topo" })
    onPageChanged: { const g = pages.find(p => p.id === page)?.group; if (g) lastIn[g] = page }
    function resolve(p) { return lastIn.hasOwnProperty(p) ? lastIn[p] : p }
    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

    // Pages watch these to scroll to a label and mark it; the counter repeats the same request.
    property string revealLabel: ""
    property int revealCount: 0
    function reveal(p, label) { page = resolve(p); revealLabel = label; revealCount++ }
    function show(p) { page = resolve(p); launcher = false; overview = false; clipboard = false; mediaOpen = false; dockEditor = false; open = true }
    function editDock() { open = false; launcher = false; overview = false; mediaOpen = false; dockEditor = true }
    function toggle(p) { p = resolve(p); if (open && (!p || page === p)) open = false; else show(p || page) }
    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }

    readonly property string version: versionFile.text().trim()
    FileView { id: versionFile; path: Quickshell.env("HOME") + "/.local/share/atoll/VERSION"; blockLoading: true; printErrors: false }

    IpcHandler {
        target: "ui"
        function toggle(page: string): void { ui.toggle(page) }
        function launcher(): void { ui.open = false; ui.launcher = !ui.launcher }
        function overview(): void { ui.open = false; ui.launcher = false; ui.overview = !ui.overview }
        function clipboard(): void { if (ui.clipboard) ui.clipboard = false; else ui.openClipboard() }
        function emoji(): void { ui.openLauncher("emoji") }
        function dock(): void { ui.toggleDock() }
        function editDock(): void { ui.editDock() }
        function ask(): void { ui.toggleAsk() }
        function close(): void { ui.open = false; ui.launcher = false; ui.overview = false; ui.clipboard = false; ui.askOpen = false }
    }
}
