pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    readonly property var accents: ({
        gelo:   { name: Tr.t("Ice"),    hex: "#8CC8F5" },
        areia:  { name: Tr.t("Sand"),   hex: "#E8CFA6" },
        hortela:{ name: Tr.t("Mint"), hex: "#8FD9B6" },
        coral:  { name: Tr.t("Coral"),   hex: "#FF9F87" }
    })
    readonly property color accent: (accents[Cfg.v.accent] ?? accents.gelo).hex
    readonly property color accentInk: "#08131D"
    readonly property color ground: "#0D151F"
    readonly property color surface: Qt.rgba(12 / 255, 18 / 255, 26 / 255, 0.6)
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
    // The lock screen reads the wallpaper through this link, because it runs outside the shell.
    readonly property string wallpaper: Cfg.v.wallpaper
    function linkWallpaper() {
        Quickshell.execDetached(["sh", "-c", 'if [ -n "$1" ]; then ln -sfn "$1" "$2"; else rm -f "$2"; fi', "sh", wallpaper, Quickshell.env("HOME") + "/.local/share/atoll/current-wallpaper"])
    }
    onWallpaperChanged: linkWallpaper()
    // Backgrounds for screens with their own wallpaper. hyprlock draws them over the main one, from a file its config includes.
    readonly property var screenWallpapers: Cfg.v.wallpapers ?? ({})
    onScreenWallpapersChanged: writeLockScreens()
    function writeLockScreens() {
        const blocks = Object.keys(screenWallpapers).map(name => {
            const path = screenWallpapers[name]
            return `background {\n    monitor = ${name}\n    path = ${path || ""}\n    color = rgb(13, 21, 31)\n    blur_passes = 0\n    brightness = 0.82\n}\n`
        })
        lockScreens.setText("# Written by Atoll from the wallpapers chosen per screen.\n" + blocks.join(""))
    }
    FileView { id: lockScreens; path: Quickshell.env("HOME") + "/.config/atoll/hyprlock-screens.conf"; atomicWrites: true; printErrors: false }
    // Same for the picture. Without one of its own, a profile uses the system-wide ~/.face.
    readonly property string photo: Cfg.v.photo
    function linkPhoto() {
        Quickshell.execDetached(["sh", "-c", 'if [ -e "$1" ]; then ln -sfn "$1" "$2"; else rm -f "$2"; fi', "sh", photo || Quickshell.env("HOME") + "/.face", Quickshell.env("HOME") + "/.local/share/atoll/current-face"])
    }
    onPhotoChanged: linkPhoto()
    Component.onCompleted: { pushBorder(); linkWallpaper(); linkPhoto() }
}
