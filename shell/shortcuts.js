.pragma library
// The shortcut editor's logic: reading hypr/keys.lua and ~/.config/atoll/shortcuts.lua, conflicts, free keys,
// and the Lua that saves and applies a change. Key strings look like "SUPER + SHIFT + K", as in hl.bind.

const MODS = ["SUPER", "CTRL", "ALT", "SHIFT"]
const ALIAS = { CONTROL: "CTRL", WIN: "SUPER", MOD4: "SUPER", META: "SUPER" }

// ABNT2, drawn row by row: [xkb keycode, key name for hl.bind, cap, width, modifier this key holds].
// A key without a name cannot be bound on its own (modifiers, Caps Lock, AltGr).
// shortcut: static ABNT2 caps and names, whatever the active layout is; label from xkb if other layouts need it.
var rows = [
    [[49, "apostrophe", "'"], [10, "1", "1"], [11, "2", "2"], [12, "3", "3"], [13, "4", "4"], [14, "5", "5"], [15, "6", "6"], [16, "7", "7"],
     [17, "8", "8"], [18, "9", "9"], [19, "0", "0"], [20, "minus", "-"], [21, "equal", "="], [22, "BackSpace", "⌫", 112]],
    [[23, "TAB", "Tab", 83], [24, "Q", "Q"], [25, "W", "W"], [26, "E", "E"], [27, "R", "R"], [28, "T", "T"], [29, "Y", "Y"], [30, "U", "U"],
     [31, "I", "I"], [32, "O", "O"], [33, "P", "P"], [34, "dead_acute", "´"], [35, "bracketleft", "["], [36, "Return", "Enter", 83]],
    [[66, "", "Caps", 98], [38, "A", "A"], [39, "S", "S"], [40, "D", "D"], [41, "F", "F"], [42, "G", "G"], [43, "H", "H"], [44, "J", "J"],
     [45, "K", "K"], [46, "L", "L"], [47, "ccedilla", "Ç"], [48, "dead_tilde", "~"], [51, "bracketright", "]"]],
    [[50, "", "Shift", 68, "SHIFT"], [94, "backslash", "\\"], [52, "Z", "Z"], [53, "X", "X"], [54, "C", "C"], [55, "V", "V"], [56, "B", "B"],
     [57, "N", "N"], [58, "M", "M"], [59, "comma", ","], [60, "period", "."], [61, "semicolon", ";"], [62, "", "Shift", 98, "SHIFT"], [111, "up", "↑"]],
    [[37, "", "Ctrl", 68, "CTRL"], [133, "", "Super", 68, "SUPER"], [64, "", "Alt", 68, "ALT"], [65, "SPACE", "Space", 344], [108, "", "AltGr", 68],
     [105, "", "Ctrl", 54, "CTRL"], [113, "left", "←"], [116, "down", "↓"], [114, "right", "→"]]
].map(row => row.map(([code, name, cap, w, holds]) => ({ code, name, cap, w: w ?? 54, holds: holds ?? "" })))
const extra = { 9: "Escape", 95: "F11", 96: "F12", 97: "slash", 107: "PRINT", 110: "Home", 112: "Prior", 115: "End", 117: "Next", 118: "Insert", 119: "Delete" }
for (let i = 0; i < 10; i++) extra[67 + i] = "F" + (i + 1)
const flat = [].concat(...rows)
const nameOf = {}, codeOf = {}
for (const k of flat) if (k.name) nameOf[k.code] = k.name
Object.assign(nameOf, extra)
for (const code in nameOf) codeOf[nameOf[code].toLowerCase()] = Number(code)
codeOf.tab = 23; codeOf.space = 65; codeOf.print = 107

// The QML engine lacks matchAll, flat and Object.fromEntries.
function all(re, text) { const out = []; let m; while ((m = re.exec(String(text)))) out.push(m); return out }
function byKey(list) { const out = {}; for (const e of list) out[e.id] = e; return out }
function values(map) { return Object.keys(map).map(k => map[k]) }

function split(keys) {
    const parts = String(keys).split("+").map(p => p.trim())
    const key = parts.pop() ?? ""
    const mods = parts.map(m => ALIAS[m.toUpperCase()] ?? m.toUpperCase())
    return { mods: MODS.filter(m => mods.includes(m)).concat(mods.filter(m => !MODS.includes(m))), key }
}
// The same shortcut whatever the spelling: "SHIFT + SUPER + tab", "SUPER + SHIFT + TAB" and "SUPER + SHIFT + code:23".
function norm(keys) {
    const { mods, key } = split(keys)
    const code = /^code:(\d+)$/.exec(key)?.[1] ?? codeOf[key.toLowerCase()]
    return mods.join("+") + "|" + (code !== undefined ? "#" + code : key.toLowerCase())
}
function combo(mods, name) { return MODS.filter(m => mods.includes(m)).concat([name]).join(" + ") }
function keyName(code) { return nameOf[code] ?? "code:" + code }
// How a combination reads on screen: Super + Shift + K.
function pretty(keys) {
    const { mods, key } = split(keys)
    const code = /^code:(\d+)$/.exec(key)?.[1] ?? codeOf[key.toLowerCase()]
    const cap = flat.find(k => k.code === Number(code) && k.name)?.cap ?? key
    return mods.map(m => m === "CTRL" ? "Ctrl" : m[0] + m.slice(1).toLowerCase()).concat([cap === "PRINT" ? "Print" : cap])
}

// "" when the combination can be bound, otherwise why not.
function problem(keys) {
    const { mods, key } = split(keys)
    if (!key) return "empty"
    if (!/^(code:\d+|[A-Za-z0-9_]+)$/.test(key) || mods.some(m => !MODS.includes(m))) return "invalid"
    if (norm(keys) === norm("SUPER + Escape")) return "reserved" // leaves the recording submap
    if (!mods.some(m => m !== "SHIFT") && norm(key) !== norm("PRINT")) return "typing" // would steal a key from every app
    return ""
}

// Text that ends up inside a Lua string: one line, no control characters, valid UTF-16.
function safeText(text) {
    if (typeof text !== "string" || text.length > 500 || /[\u0000-\u001f\u007f]/.test(text)) return false
    try { encodeURIComponent(text); return true } catch (e) { return false }
}

function parseDefaults(text) {
    return all(/^S\("([\w-]+)", "([^"]+)", "(\w+)", "([^"]*)"/gm, text).map(m => ({
        id: m[1], keys: m[2], group: m[3], label: m[4], arg: m[4].includes("%1") ? (/\d+$/.exec(m[1])?.[0] ?? "") : ""
    }))
}

// shortcuts.lua, written by toLua below: one { field = "string", ... } table per line.
function parseChanges(text) {
    const out = []
    for (const line of String(text).split("\n")) {
        if (!/^\s*\{.*\},?\s*$/.test(line)) continue
        const c = {}
        try { for (const m of all(/(\w+) = ("(?:[^"\\]|\\.)*")/g, line)) c[m[1]] = JSON.parse(m[2]) } catch (e) { continue }
        if (!/^[\w-]+$/.test(c.id ?? "") || typeof c.keys !== "string" || (c.keys && problem(c.keys))) continue
        if (["label", "exec", "group", "app"].some(f => f in c && !safeText(c[f]))) continue
        if (!out.some(o => o.id === c.id)) out.push(c)
    }
    return out
}
function toLua(changes) {
    const field = (c, f) => f in c ? `${f} = ${JSON.stringify(String(c[f]))}` : ""
    const lines = changes.filter(c => /^[\w-]+$/.test(c.id) && (c.keys === "" || !problem(c.keys)) && ["label", "exec", "group", "app"].every(f => !(f in c) || safeText(c[f])))
        .map(c => "    { " + ["id", "keys", "label", "exec", "group", "app"].map(f => field(c, f)).filter(Boolean).join(", ") + " },")
    return "-- Written by Atoll from Control center > Shortcuts. Your own changes go in user.lua, which loads after this file.\nreturn {\n" + lines.join("\n") + (lines.length ? "\n" : "") + "}\n"
}

// hyprctl -j binds: the keyboard shortcuts on the global map.
function parseLive(text) {
    let list
    try { list = JSON.parse(text) } catch (e) { return null }
    if (!Array.isArray(list)) return null
    const bits = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]
    return list.filter(b => !b.mouse && (!b.submap || b.submap === "global") && (b.key || b.keycode))
        .map(b => ({ keys: combo(bits.filter(([bit]) => b.modmask & bit).map(([, m]) => m), b.key || "code:" + b.keycode), desc: String(b.description ?? ""), what: [b.dispatcher, b.arg].filter(Boolean).join(" ") }))
        .filter(b => !/^xf86/i.test(split(b.keys).key))
}

// Every shortcut with what it does now. state: default, changed, custom, off (no keys), gone (user.lua removed it), user (from user.lua).
function effective(defaults, changes, live) {
    const byId = byKey(changes)
    const taken = new Set(changes.filter(c => c.keys).map(c => norm(c.keys)))
    // Without any Atoll description the binds are not ours to judge (another config, or descriptions unsupported).
    const ours = live && live.some(b => b.desc.startsWith("atoll:")) ? new Set(live.filter(b => b.desc.startsWith("atoll:")).map(b => b.desc.slice(6))) : null
    const out = defaults.map(d => {
        const c = byId[d.id]
        const keys = c ? c.keys : taken.has(norm(d.keys)) ? "" : d.keys
        const state = !keys ? "off" : c && norm(c.keys) !== norm(d.keys) ? "changed" : "default"
        return Object.assign({}, d, { keys, def: d.keys, state, custom: false })
    })
    for (const c of changes) if (c.keys && !defaults.some(d => d.id === c.id)) out.push({ id: c.id, keys: c.keys, def: "", group: c.group || "apps", label: c.label || c.exec || "", arg: "", exec: c.exec || "", app: c.app || "", state: "custom", custom: true })
    if (ours) {
        for (const e of out) if (e.keys && !ours.has(e.id)) e.state = "gone"
        live.filter(b => !b.desc.startsWith("atoll:")).forEach((b, i) => out.push({ id: "user-" + i, keys: b.keys, def: "", group: "user", label: b.desc || b.what, arg: "", state: "user", custom: false }))
    }
    return out
}
function active(entries) { return entries.filter(e => e.keys && e.state !== "off" && e.state !== "gone") }
function conflicts(entries, keys, selfId) { const n = norm(keys); return active(entries).filter(e => e.id !== selfId && norm(e.keys) === n) }
function free(entries, mods, limit) {
    const used = new Set(active(entries).map(e => norm(e.keys)))
    const order = [].concat(rows[1], rows[2], rows[3], rows[0], rows[4]).filter(k => k.name.length === 1)
    return order.map(k => combo(mods, k.name)).filter(keys => !used.has(norm(keys)) && !problem(keys)).slice(0, limit)
}

// The layers on the map: an exact set of modifiers, or "no Super" for everything else.
var layers = [["SUPER"], ["SUPER", "SHIFT"], ["SUPER", "ALT"], ["SUPER", "CTRL"], null]
function inLayer(keys, layer) {
    const { mods } = split(keys)
    return layer ? mods.length === layer.length && layer.every(m => mods.includes(m)) : !mods.includes("SUPER")
}
function onKey(entries, layer, code) { return active(entries).find(e => inLayer(e.keys, layer) && norm(e.keys).endsWith("|#" + code)) ?? null }
function offMap(entries, layer) {
    const mapped = new Set(flat.filter(k => k.name).map(k => "#" + k.code))
    return active(entries).filter(e => inLayer(e.keys, layer) && !mapped.has(norm(e.keys).split("|")[1]))
}

// The changes after giving keys to id. Whatever used those keys loses them: a default is turned off, a custom one is removed.
// fields: label, exec, group, app, for a new or custom shortcut.
function setKeys(defaults, changes, entries, id, keys, fields) {
    const lost = conflicts(entries, keys, id)
    let out = changes.filter(c => c.id !== id && !lost.some(e => e.id === c.id))
    for (const e of lost) if (!e.custom && e.state !== "user") out.push({ id: e.id, keys: "" })
    const d = defaults.find(x => x.id === id)
    if (!d) out.push(Object.assign({ id, keys }, fields || {}))
    else if (norm(keys) !== norm(d.keys)) out.push({ id, keys })
    return out
}
function newId(changes) { return "custom-" + (Math.max(0, ...changes.map(c => Number(/^custom-(\d+)$/.exec(c.id)?.[1] ?? 0))) + 1) }

// Lua for hyprctl eval that turns the binds of `before` into those of `after`, without a reload. Unbinds go first,
// since hl.unbind removes every bind on those exact keys.
function liveCode(before, after) {
    const prev = byKey(before)
    const was = byKey(active(before).filter(e => e.state !== "user"))
    // Still removed by user.lua unless it got new keys, which user.lua does not know about.
    const now = byKey(after.filter(e => e.keys && e.state !== "off" && e.state !== "user" && (e.state !== "gone" || prev[e.id]?.keys !== e.keys)))
    const same = (x, y) => x && y && x.keys === y.keys && x.exec === y.exec
    const unbind = values(was).filter(e => !same(e, now[e.id])).map(e => `hl.unbind(${JSON.stringify(e.keys)})`)
    const bind = values(now).filter(e => !same(e, was[e.id]) && !problem(e.keys) && (!e.custom || safeText(e.exec)))
    if (!unbind.length && !bind.length) return ""
    const head = bind.some(e => !e.custom) ? ['local d = {}\nfor _, s in ipairs(dofile(os.getenv("HOME") .. "/.config/atoll/hypr/keys.lua")) do d[s.id] = s.act end'] : []
    return head.concat(unbind, bind.map(e => `hl.bind(${JSON.stringify(e.keys)}, ${e.custom ? `hl.dsp.exec_cmd(${JSON.stringify(e.exec)})` : `d[${JSON.stringify(e.id)}]`}, { description = ${JSON.stringify("atoll:" + e.id)} })`)).join("\n")
}
// While recording: an empty submap, so keys reach the editor instead of running shortcuts. It always times out.
var recordCode = 'atoll_record = hl.timer(function() if hl.get_current_submap() == "atoll-record" then hl.dispatch(hl.dsp.submap("reset")) end end, { timeout = 8000, type = "oneshot" })'
var enterRecord = 'hl.dsp.submap("atoll-record")'
var leaveRecord = 'hl.dsp.submap("reset")'
