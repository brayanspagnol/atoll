pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "theme.js" as T
import "parse.js" as P

Singleton {
    // "dark", "light", or "auto": dark while the night light's schedule says night, or from 19:00 to 07:00 without one.
    readonly property string mode: Cfg.v.theme
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool night: {
        const now = Qt.formatTime(clock.date, "hh:mm")
        return Cfg.v.nightAuto ? P.inWindow(now, Cfg.v.nightFrom, Cfg.v.nightTo) : !P.inWindow(now, "07:00", "19:00")
    }
    readonly property string switchAt: Cfg.v.nightAuto ? (night ? Cfg.v.nightTo : Cfg.v.nightFrom) : (night ? "07:00" : "19:00") // when "auto" flips next
    readonly property bool light: mode === "light" || (mode === "auto" && !night)
    readonly property var sets: ({ dark: T.dark, light: T.light })
    readonly property var t: light ? T.light : T.dark
    readonly property var accents: ({
        gelo:   { name: Tr.t("Ice"),    hex: t.accents.gelo },
        areia:  { name: Tr.t("Sand"),   hex: t.accents.areia },
        hortela:{ name: Tr.t("Mint"), hex: t.accents.hortela },
        coral:  { name: Tr.t("Coral"),   hex: t.accents.coral }
    })
    readonly property color accent: (accents[Cfg.v.accent] ?? accents.gelo).hex
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.22) // selected rows and tiles
    readonly property color accentInk: t.accentInk
    readonly property color ground: t.ground
    readonly property color surface: t.surface // the glass
    readonly property color glassStrong: t.glassStrong
    readonly property color scrim: t.scrim
    readonly property color raised: t.raised
    readonly property color raisedHover: t.raisedHover
    readonly property color hover: t.hover
    readonly property color line: t.line
    readonly property color lineStrong: t.lineStrong
    readonly property color rim: t.rim
    readonly property color sheen: t.sheen
    readonly property color field: t.field
    readonly property color ink: t.ink
    readonly property color muted: t.muted
    readonly property color danger: t.danger
    readonly property color holiday: t.holiday
    readonly property color good: t.good
    readonly property color warn: t.warn
    readonly property string sans: "Instrument Sans"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int radius: 28
    readonly property int radiusSmall: 14
    readonly property int fast: 120

    function pushBorder() {
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ general = { col = { active_border = "rgb(${accent.toString().slice(1)})", inactive_border = "rgba(${t.inactiveBorder})" } } })`])
    }
    onAccentChanged: pushBorder()
    onLightChanged: pushBorder()
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
