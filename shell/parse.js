.pragma library
// Parsers for /proc and top output. Pure so they can be tested without a running shell.
function cpu(text) { // [{total, idle}], index 0 = aggregate
    return text.split("\n").filter(l => /^cpu\d* /.test(l)).map(l => {
        const n = l.trim().split(/\s+/).slice(1).map(Number)
        return { total: n.slice(0, 8).reduce((a, b) => a + b, 0), idle: n[3] + n[4] }
    })
}
function mem(text) { // bytes
    const g = k => { const m = text.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")); return m ? Number(m[1]) * 1024 : 0 }
    const total = g("MemTotal"), avail = g("MemAvailable"), st = g("SwapTotal"), sf = g("SwapFree")
    return { total, used: total - avail, swapTotal: st, swapUsed: st - sf }
}
function net(text) { // cumulative bytes over physical-ish interfaces
    let rx = 0, tx = 0
    text.split("\n").slice(2).forEach(l => {
        const m = l.trim().match(/^([^:]+):\s*(.*)$/)
        if (!m || /^(lo|docker|veth|br-|virbr|tailscale)/.test(m[1])) return
        const n = m[2].split(/\s+/).map(Number)
        rx += n[0]; tx += n[8]
    })
    return { rx, tx }
}
function top(text, limit) { // last batch of `top -b -n2`, default field order
    const lines = text.split("\n"), i = lines.map(l => /^\s*PID\s+USER/.test(l)).lastIndexOf(true)
    if (i < 0) return []
    const out = []
    for (const l of lines.slice(i + 1)) {
        const f = l.trim().split(/\s+/)
        if (f.length < 12) continue
        out.push({ pid: Number(f[0]), user: f[1], cpu: Number(f[8]), mem: Number(f[9]), name: f.slice(11).join(" ") })
    }
    return out.slice(0, limit)
}
function shQuote(text) { // one safe shell word
    return "'" + text.replace(/'/g, "'\\''") + "'"
}
function newerVersion(latest, current) { // "v1.10.0" against "1.9.2"
    const parts = text => text.replace(/^v/, "").split(".").map(Number)
    const a = parts(latest), b = parts(current)
    for (let i = 0; i < 3; i++) if ((a[i] || 0) !== (b[i] || 0)) return (a[i] || 0) > (b[i] || 0)
    return false
}
function bytes(n) {
    const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0
    while (n >= 1024 && i < 4) { n /= 1024; i++ }
    return n.toFixed(i && n < 100 ? 1 : 0) + " " + u[i]
}

// Hyprland keeps layouts and variants as two comma lists, matched by position.
function zipLayouts(layouts, variants) {
    const v = (variants || "").split(",")
    return (layouts || "").split(",").filter(Boolean).map((layout, i) => ({ layout, variant: v[i] || "" }))
}
function joinLayouts(list) {
    return { layout: list.map(l => l.layout).join(","), variant: list.map(l => l.variant).join(",") }
}
// Reads xkb's evdev.lst: "  br   Portuguese (Brazil)" under ! layout, "  nodeadkeys   br: Portuguese (Brazil, no dead keys)" under ! variant.
function xkbCatalog(text) {
    const out = []
    let section = ""
    for (const line of text.split("\n")) {
        if (line.startsWith("!")) { section = line.slice(1).trim(); continue }
        const m = line.match(/^\s+(\S+)\s+(.+)$/)
        if (!m) continue
        if (section === "layout") out.push({ layout: m[1], variant: "", name: m[2] })
        else if (section === "variant") {
            const v = m[2].match(/^(\S+): (.+)$/)
            if (v) out.push({ layout: v[1], variant: m[1], name: v[2] })
        }
    }
    return out.sort((a, b) => a.name.localeCompare(b.name))
}

// "  performance:" lines of powerprofilesctl list; the active one starts with "*".
function powerProfiles(text) {
    const order = ["power-saver", "balanced", "performance"], found = []
    let active = ""
    for (const line of text.split("\n")) {
        const m = line.match(/^(\*?)\s*([a-z-]+):\s*$/)
        if (!m) continue
        found.push(m[2])
        if (m[1]) active = m[2]
    }
    return { names: order.filter(n => found.includes(n)), active }
}

// Times as "HH:MM". A window ending before it starts runs past midnight.
function inWindow(now, from, to) {
    if (from === to) return false
    return from < to ? now >= from && now < to : now >= from || now < to
}

// nmcli -t output: fields split by ":", with ":" and "\\" escaped inside them.
function nmcliRows(text) {
    return text.split("\n").filter(Boolean).map(line => {
        const fields = [""]
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length) fields[fields.length - 1] += line[++i]
            else if (line[i] === ":") fields.push("")
            else fields[fields.length - 1] += line[i]
        }
        return fields
    })
}
