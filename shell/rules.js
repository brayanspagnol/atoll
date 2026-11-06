.pragma library
// Pure logic for the Window rules screen. One rule per app, matched by its window class:
// { class, float, center, size: [w, h] | null, pin, maximize, fullscreen, opacity: 0.1-0.99 | null, noFocus, workspace: "1".."99" | "", monitor: "" }

function blank(cls) {
    return { class: cls ?? "", float: false, center: false, size: null, pin: false, maximize: false, fullscreen: false, opacity: null, noFocus: false, workspace: "", monitor: "" }
}

// Hyprland matches with RE2, where these are special.
function escapeRegex(text) { return String(text).replace(/[\\^$.|?*+()[\]{}]/g, "\\$&") }

function luaString(text) {
    return '"' + String(text).replace(/[\\"]/g, "\\$&").replace(/[\x00-\x1f\x7f]/g, c => "\\" + String(c.charCodeAt(0)).padStart(3, "0")) + '"'
}

const between = (n, lo, hi) => Number.isFinite(n) && n >= lo && n <= hi

// A clean copy, or null when there is no usable class. Effects that need floating turn it on.
function normalize(input) {
    const r = input ?? {}
    const cls = typeof r.class === "string" ? r.class.trim() : ""
    if (!cls || cls.length > 200 || /[\x00-\x1f\x7f]/.test(cls)) return null
    const out = blank(cls)
    for (const key of ["float", "center", "pin", "maximize", "fullscreen", "noFocus"]) out[key] = r[key] === true
    const size = Array.isArray(r.size) ? r.size.map(Number) : []
    if (size.length === 2 && size.every(n => Number.isInteger(n) && between(n, 50, 16384))) out.size = size
    const opacity = Number(r.opacity)
    if (r.opacity !== null && r.opacity !== undefined && between(opacity, 0.1, 0.99)) out.opacity = Math.round(opacity * 100) / 100
    if (out.fullscreen) out.maximize = false
    if (out.pin || out.center || out.size) out.float = true
    const ws = String(r.workspace ?? "")
    if (/^[1-9][0-9]?$/.test(ws)) out.workspace = ws
    else if (/^[A-Za-z0-9._-]{1,64}$/.test(String(r.monitor ?? ""))) out.monitor = r.monitor
    return out
}

function hasEffect(r) {
    return r.float || r.center || !!r.size || r.pin || r.maximize || r.fullscreen || r.opacity !== null || r.noFocus || !!r.workspace || !!r.monitor
}

// The hl.window_rule spec, as a Lua table literal.
function spec(r) {
    const parts = [`name = ${luaString("atoll-user: " + r.class)}`, `match = { class = ${luaString("^(" + escapeRegex(r.class) + ")$")} }`]
    if (r.float) parts.push("float = true")
    if (r.center) parts.push("center = true")
    if (r.size) parts.push(`size = "${r.size[0]} ${r.size[1]}"`)
    if (r.pin) parts.push("pin = true")
    if (r.maximize) parts.push("maximize = true")
    if (r.fullscreen) parts.push("fullscreen = true")
    if (r.opacity !== null) parts.push(`opacity = "${r.opacity}"`)
    if (r.noFocus) parts.push("no_initial_focus = true")
    if (r.workspace) parts.push(`workspace = "${r.workspace}"`)
    else if (r.monitor) parts.push(`monitor = ${luaString(r.monitor)}`)
    return "{ " + parts.join(", ") + " }"
}

// Reads rules.json; anything broken is dropped, and the last rule for a class wins.
function parse(text) {
    let data
    try { data = JSON.parse(text) } catch (e) { return [] }
    const list = Array.isArray(data?.rules) ? data.rules : []
    const byClass = new Map()
    for (const raw of list) {
        const r = normalize(raw)
        if (r && hasEffect(r)) { byClass.delete(r.class); byClass.set(r.class, r) }
    }
    return [...byClass.values()]
}

function upsert(list, rule) {
    const i = list.findIndex(r => r.class === rule.class)
    return i < 0 ? list.concat([rule]) : list.map((r, j) => j === i ? rule : r)
}
function remove(list, cls) { return list.filter(r => r.class !== cls) }

function jsonFile(list) { return JSON.stringify({ rules: list }, null, 1) + "\n" }

// The file hypr/rules.lua loads after the defaults. Data only: each rule goes to hl.window_rule.
function configFile(list) {
    return "-- Written by the Window rules screen. Edit the rules there; this file is replaced.\nreturn {\n" + list.map(r => `    { app = ${luaString(r.class)}, rule = ${spec(r)} },\n`).join("") + "}\n"
}

// For hyprctl eval: replaces the app's live rule, so windows opened from now on follow it.
function liveCode(r) {
    return `atoll_user_rules = atoll_user_rules or {}; local old = atoll_user_rules[${luaString(r.class)}]; if old then pcall(old.set_enabled, old, false) end; atoll_user_rules[${luaString(r.class)}] = hl.window_rule(${spec(r)})`
}
function removeCode(cls) {
    return `local old = atoll_user_rules and atoll_user_rules[${luaString(cls)}]; if old then pcall(old.set_enabled, old, false); atoll_user_rules[${luaString(cls)}] = nil end`
}

// Open windows from hyprctl -j clients, one per app, keyed by the class the window opened with.
function openApps(clients) {
    const seen = new Map()
    for (const c of Array.isArray(clients) ? clients : []) {
        const cls = String(c?.initialClass || c?.class || "").trim()
        if (!cls || seen.has(cls) || !c.mapped) continue
        seen.set(cls, { class: cls, title: String(c.title ?? ""), size: Array.isArray(c.size) ? c.size : null })
    }
    return [...seen.values()]
}
