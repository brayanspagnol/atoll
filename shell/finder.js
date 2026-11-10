.pragma library
.import "parse.js" as P

// What the control center's search finds inside each screen. The keys are the screens' own English strings,
// so the translated label matches the text on the page, which is how the page finds it to scroll there.
const items = {
    som: ["Output", "Microphone", "Volume per app", "Now playing"],
    rede: ["Wi-Fi", "Cable", "VPN", "Other network…"],
    bt: ["Paired", "Nearby", "Adapter"],
    perf: ["Processes", "Battery", "Memory", "System disk"],
    cal: ["New event", "Today"],
    avisos: ["Do not disturb", "Clear all"],
    monitor: ["Layout", "Resolution", "Refresh rate", "Scale", "Rotation", "Mirror", "Brightness", "Identify screens", "When closing the lid", "Variable refresh rate (VRR)"],
    ajustes: ["Language", "Night light", "Keyboard layouts", "Pointer speed", "Natural scrolling", "Touchpad", "Tap to click", "Public holidays", "Idle time"],
    visual: ["Profile", "Photo", "Name", "New profile", "Theme", "Accent color", "Wallpaper"],
    atalhos: ["New shortcut"],
    apps: ["Web browser", "Terminal", "File manager", "Text editor", "Image viewer", "Video player", "Music player", "Email"],
    backup: ["Export", "Import"],
    energia: ["Lock", "Suspend", "Log out", "Restart", "Shut down", "Power mode"],
    sobre: ["Check for updates", "Copy for a report", "This system"]
}

// "PgMonitor.qml:Tr.t("Extend")" lines from grep, to labels per screen. files: screen id to its file.
// Sentences and texts with placeholders are left out: they are messages, not things to look for.
function labelsFrom(text, files) {
    const byFile = {}
    for (const id in files) byFile[files[id]] = id
    const out = {}
    for (const line of String(text).split("\n")) {
        const m = line.match(/^([^:]+):Tr\.t\("(.*)"\)$/)
        if (!m || !byFile[m[1]]) continue
        const key = m[2]
        if (!key || key.length > 40 || key.includes("%") || /[.!?:]$/.test(key)) continue
        const id = byFile[m[1]]
        if (!out[id]) out[id] = []
        if (!out[id].includes(key)) out[id].push(key)
    }
    return out
}

// The list with no search: the screens in order, a group's screens right under its card (groups: Ui.groups), where the first of them is.
// nth and last place a group's screen inside the card.
function tree(pages, groups) {
    const out = []
    for (const p of pages) {
        if (!p.group) { out.push({ page: p.id, label: p.label, icon: p.icon, key: p.key, item: false }); continue }
        if (out.some(r => r.group === p.group)) continue
        const g = groups[p.group], kids = pages.filter(o => o.group === p.group)
        out.push({ head: true, group: p.group, page: "", label: g.label, icon: g.icon, key: g.key, item: false, count: kids.length })
        kids.forEach((k, i) => out.push({ page: k.id, label: k.label, icon: k.icon, key: "", item: false, group: p.group, nth: i, last: i === kids.length - 1 }))
    }
    return out
}

// pages: Ui.pages, already translated. tr: Tr.t. extra: more labels per screen (labelsFrom). Screens first, then what is inside them, best match first.
// A screen in a group (parent) is found by the group's name too, and says which group it is in.
function search(pages, query, tr, extra) {
    const q = P.fold(String(query).trim())
    if (!q) return []
    const score = (label, extra) => {
        const l = P.fold(label)
        if (l.startsWith(q)) return 0
        if (l.split(/[\s\-(),.›]+/).some(w => w.startsWith(q))) return 1
        if (l.includes(q)) return 2
        return P.fold(extra).includes(q) ? 3 : -1
    }
    const out = []
    for (const p of pages) {
        const s = score(p.label, (p.kw || "") + " " + (p.parent || ""))
        if (s >= 0) out.push(Object.assign({ page: p.id, label: p.label, icon: p.icon, key: p.key, item: false, rank: s }, p.parent ? { sub: p.parent } : {}))
        const where = p.parent ? p.parent + " › " + p.label : p.label
        const seen = new Set()
        for (const key of (items[p.id] || []).concat((extra || {})[p.id] || [])) {
            if (seen.has(key)) continue
            seen.add(key)
            const label = tr(key)
            const t = score(label, key + " " + where)
            if (t >= 0) out.push({ page: p.id, label, icon: p.icon, key: "", sub: where, item: true, rank: t + 0.5 })
        }
    }
    return out.sort((a, b) => a.rank - b.rank).slice(0, 30)
}
