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

// pages: Ui.pages, already translated. tr: Tr.t. Screens first, then what is inside them, best match first.
function search(pages, query, tr) {
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
        const s = score(p.label, p.kw || "")
        if (s >= 0) out.push({ page: p.id, label: p.label, icon: p.icon, key: p.key, item: false, rank: s })
        for (const key of items[p.id] || []) {
            const label = tr(key)
            const t = score(label, key + " " + p.label)
            if (t >= 0) out.push({ page: p.id, label, icon: p.icon, key: "", sub: p.label, item: true, rank: t + 0.5 })
        }
    }
    return out.sort((a, b) => a.rank - b.rank).slice(0, 30)
}
