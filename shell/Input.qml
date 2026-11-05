pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "parse.js" as P

// Keyboard and pointer. The live compositor options are the source of truth, so changes made in user.lua show up here too.
Singleton {
    id: root
    property var layouts: []
    property var catalog: []
    property real speed: 0
    property bool natural: false
    property bool hasTouchpad: false
    property bool padNatural: false
    property bool padTap: true
    property bool padTyping: true
    property real padScroll: 1

    function nameOf(item) {
        const known = catalog.find(c => c.layout === item.layout && c.variant === item.variant)
        return known ? known.name : item.layout + (item.variant ? " (" + item.variant + ")" : "")
    }
    function addLayout(item) {
        if (!layouts.some(l => l.layout === item.layout && l.variant === item.variant)) layouts = layouts.concat([item])
        save()
    }
    function removeLayout(index) {
        if (layouts.length < 2) return
        layouts = layouts.filter((_, i) => i !== index)
        save()
    }
    function table() {
        const joined = P.joinLayouts(layouts)
        return `{ kb_layout = ${JSON.stringify(joined.layout)}, kb_variant = ${JSON.stringify(joined.variant)}, sensitivity = ${speed.toFixed(2)}, natural_scroll = ${natural},\n`
            + `    touchpad = { natural_scroll = ${padNatural}, tap_to_click = ${padTap}, disable_while_typing = ${padTyping}, scroll_factor = ${padScroll.toFixed(2)} } }`
    }
    function save() { saveTimer.restart() }
    // Sliders move in many small steps, and each change is a call to the compositor.
    Timer {
        id: saveTimer
        interval: 150
        onTriggered: {
            Quickshell.execDetached(["hyprctl", "eval", `hl.config({ input = ${root.table()} })`])
            file.setText(`-- Written by the Settings screen.\nreturn ${root.table()}\n`)
        }
    }
    FileView { id: file; path: Quickshell.env("HOME") + "/.config/atoll/input.lua"; atomicWrites: true; printErrors: false }
    FileView {
        path: "/usr/share/X11/xkb/rules/evdev.lst"
        printErrors: false
        onLoaded: root.catalog = P.xkbCatalog(text())
    }
    Process {
        running: true
        command: ["sh", "-c", `for o in input:kb_layout input:kb_variant input:sensitivity input:natural_scroll input:touchpad:natural_scroll input:touchpad:tap-to-click input:touchpad:disable_while_typing input:touchpad:scroll_factor; do hyprctl getoption "$o" -j; done | jq -cs 'map(.str // .float // .bool // .int)'; hyprctl devices -j | jq '[.mice[].name | select(test("touchpad"))] | length > 0'`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length < 2) return
                const [layout, variant, speed, natural, padNatural, padTap, padTyping, padScroll] = JSON.parse(lines[0])
                root.layouts = P.zipLayouts(layout, variant === "[[EMPTY]]" ? "" : variant)
                root.speed = speed || 0
                root.natural = natural === true
                root.padNatural = padNatural === true
                root.padTap = padTap === true
                root.padTyping = padTyping === true
                root.padScroll = padScroll || 1
                root.hasTouchpad = lines[1] === "true"
            }
        }
    }
}
