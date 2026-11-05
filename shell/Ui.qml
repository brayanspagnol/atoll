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
        { id: "som", key: "Alt+A", label: "Som", icon: "som", kw: "volume audio microfone" },
        { id: "rede", key: "Alt+I", label: "Internet", icon: "rede", kw: "wifi rede cabo" },
        { id: "bt", key: "Alt+B", label: "Bluetooth", icon: "bt", kw: "fone parear" },
        { id: "perf", key: "Alt+D", label: "Desempenho", icon: "perf", kw: "cpu memoria processos temperatura bateria" },
        { id: "cal", key: "Alt+C", label: "Calendário", icon: "cal", kw: "agenda evento data" },
        { id: "avisos", key: "Alt+V", label: "Avisos", icon: "avisos", kw: "notificacoes nao perturbe" },
        { id: "ajustes", key: "Alt+J", label: "Ajustes", icon: "ajustes", kw: "configuracoes tela brilho papel de parede cor" },
        { id: "energia", key: "Alt+E", label: "Energia", icon: "energia", kw: "desligar suspender reiniciar bloquear sair" }
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
