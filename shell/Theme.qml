pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property var accents: ({
        gelo:   { name: "Gelo",    hex: "#8CC8F5" },
        areia:  { name: "Areia",   hex: "#E8CFA6" },
        hortela:{ name: "Hortelã", hex: "#8FD9B6" },
        coral:  { name: "Coral",   hex: "#FF9F87" }
    })
    readonly property color accent: (accents[Cfg.v.accent] ?? accents.gelo).hex
    readonly property color accentInk: "#08131D"
    readonly property color ground: "#0D151F"
    readonly property color surface: Qt.rgba(12 / 255, 18 / 255, 26 / 255, 0.5)
    readonly property color raised: Qt.rgba(1, 1, 1, 0.12)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.08)
    readonly property color line: Qt.rgba(1, 1, 1, 0.16)
    readonly property color lineStrong: Qt.rgba(1, 1, 1, 0.26)
    readonly property color field: Qt.rgba(0, 0, 0, 0.22)
    readonly property color ink: "#F3F7FB"
    readonly property color muted: "#D5DDE6"
    readonly property color danger: "#FF9A8F"
    readonly property color holiday: "#FFB4A8"
    readonly property color good: "#8FD9B6"
    readonly property color warn: "#E9C46A"
    readonly property string sans: "Instrument Sans"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int radius: 28
    readonly property int radiusSmall: 14
    readonly property int fast: 120

    function pushBorder() {
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ general = { col = { active_border = "rgb(${accent.toString().slice(1)})", inactive_border = "rgba(ffffff24)" } } })`])
    }
    onAccentChanged: pushBorder()
    Component.onCompleted: pushBorder()
}
