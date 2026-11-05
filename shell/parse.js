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

// For search: lowercase, no accents, and ligatures spelled out, since nobody types "cœur".
function fold(text) {
    return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
        .replace(/œ/g, "oe").replace(/æ/g, "ae").replace(/ß/g, "ss")
}
// english: lines of "<glyph> <name>". localized: lines of "<glyph>\t<name>\t<folded keywords, | between them>".
function emojiEntries(english, localized) {
    const local = {}
    for (const line of localized.split("\n")) local[line.split("\t")[0]] = line.split("\t")
    return english.split("\n").filter(Boolean).map(line => {
        const space = line.indexOf(" "), glyph = line.slice(0, space), en = line.slice(space + 1)
        const row = local[glyph] || [], label = row[1] || en
        return { glyph, label, name: fold(label), keys: row[2] || "", en: fold(en) }
    })
}
// Names starting with the query, then names containing it, then keywords, then the English name.
function emojiSearch(entries, query) {
    const q = fold(query), tiers = [[], [], [], []]
    for (const e of entries) {
        const tier = e.name.startsWith(q) ? 0 : e.name.includes(q) ? 1 : e.keys.includes(q) ? 2 : e.en.includes(q) ? 3 : -1
        if (tier >= 0) tiers[tier].push(e)
    }
    return tiers[0].concat(tiers[1], tiers[2], tiers[3])
}

// DMI names are often a part number ("82AB") with the marketing name in the version field, or placeholders.
function modelName(vendor, name, version) {
    const junk = /^(|none|n\/a|default string|system (product name|version)|to be filled by o\.e\.m\.|not applicable|0+|\d+(\.\d+)*)$/i
    const clean = s => (s || "").trim()
    let v = clean(vendor).replace(/,? (inc|corporation|co\.,? ltd|ltd|gmbh)\.?$/i, "")
    if (v === v.toUpperCase() && v.length > 3) v = v.charAt(0) + v.slice(1).toLowerCase()
    const n = clean(name), ver = clean(version)
    const coded = !/\s/.test(n) && n.length <= 8 && /\d/.test(n)
    const pick = coded && !junk.test(ver) ? ver : junk.test(n) ? "" : n
    if (!pick) return v
    return pick.toLowerCase().startsWith(v.toLowerCase()) ? pick : (v + " " + pick).trim()
}
// SMBIOS chassis types: the portable ones are laptops.
function chassisKind(code) {
    const c = Number(code)
    if ([8, 9, 10, 11, 14, 30, 31, 32].includes(c)) return "laptop"
    if ([3, 4, 5, 6, 7, 13, 15, 16, 35, 36].includes(c)) return "desktop"
    return ""
}
function cpuName(raw) {
    return (raw || "").trim().replace(/\((R|TM)\)/gi, "").replace(/^\d+(th|st|nd|rd) Gen /i, "").replace(/ CPU @.*$/i, "").replace(/ with Radeon.*$/i, "")
        .replace(/ \d+-Core Processor$/i, "").replace(/\s+/g, " ").trim()
}
// "2 d 3 h", "3 h 20 min" or "12 min".
function duration(seconds) {
    const m = Math.floor(seconds / 60), h = Math.floor(m / 60), d = Math.floor(h / 24)
    if (d) return d + " d " + (h % 24) + " h"
    if (h) return h + " h " + (m % 60) + " min"
    return m + " min"
}

