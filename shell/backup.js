.pragma library
// The import review: each setting as it is here and as it would be after importing, from `backup inspect`.
// t translates; langs and accents are Tr.languages and Theme.accents. Mirrors what scripts/backup import does.

function arg(text, ...values) { return values.reduce((s, v, i) => s.split("%" + (i + 1)).join(String(v)), text) }
const groups = [
    { id: "name", keys: ["name"], label: "Name" },
    { id: "photo", keys: ["photo"], label: "Photo", image: true },
    { id: "language", keys: ["language"], label: "Language" },
    { id: "accent", keys: ["accent"], label: "Accent color" },
    { id: "wallpaper", keys: ["wallpaper"], label: "Wallpaper", image: true },
    { id: "wallpapers", keys: ["wallpapers"], label: "Wallpaper per screen" },
    { id: "dock", keys: ["dock"], label: "Dock" },
    { id: "idle", keys: ["lockAc", "dpmsAc", "sleepAc", "lockBat", "dpmsBat", "sleepBat"], label: "Idle times" },
    { id: "night", keys: ["nightOn", "nightK", "nightAuto", "nightFrom", "nightTo"], label: "Night light" },
    { id: "dnd", keys: ["dnd"], label: "Do not disturb" },
    { id: "holidays", keys: ["holidays"], label: "Holidays" }
]
const codeFile = name => name === "user.lua" || name.startsWith("shortcuts")
const lineCount = text => text ? text.replace(/\n$/, "").split("\n").length : 0
const kind = v => Array.isArray(v) ? "array" : v === null ? "null" : typeof v

function show(id, p, t, langs, accents, cur) {
    const v = p[id]
    const onOff = b => b ? t("On") : t("Off")
    const min = n => n > 0 ? n : "–"
    switch (id) {
    case "language": return !v || v === "auto" ? t("Automatic") : (langs.find(l => l.code === v)?.name ?? v)
    case "accent": return accents[v]?.name ?? String(v ?? "")
    case "dock": {
        const list = Array.isArray(v) ? v : []
        const known = new Set((Array.isArray(cur?.dock) ? cur.dock : []).map(a => a?.cmd))
        // A dock button runs its command, so commands new to this computer are named.
        const fresh = cur ? list.map(a => a?.cmd).filter(c => c && !known.has(c)) : []
        return arg(t("%1 apps"), list.length) + (fresh.length ? " · " + arg(t("new commands: %1"), fresh.join(", ")) : "")
    }
    case "idle": return arg(t("Plugged in %1 · battery %2 min"), [p.lockAc, p.dpmsAc, p.sleepAc].map(min).join("/"), [p.lockBat, p.dpmsBat, p.sleepBat].map(min).join("/"))
    case "night":
        if (p.nightAuto) return arg(t("Automatic, %1 to %2, %3 K"), p.nightFrom, p.nightTo, p.nightK)
        return p.nightOn ? arg(t("On, %1 K"), p.nightK) : t("Off")
    case "dnd": return onOff(v)
    case "holidays": return !v || v === "auto" ? t("Automatic") : v === "off" ? t("Off") : String(v)
    case "wallpapers": { const n = Object.keys(v ?? {}).length; return n ? arg(t("Own wallpaper on %1 screens"), n) : t("One for all screens") }
    case "photo": case "wallpaper": return v ? t("A picture") : t("None")
    case "name": return String(v ?? "")
    default: return JSON.stringify(v ?? null).slice(0, 80)
    }
}

// rows: { profile: [...], files: [...], code: [...] }; a row is { id, label, before, after, same, skip, keys | file(s) }.
function review(info, from, screens, t, langs, accents) {
    const cur = info.current?.profile ?? {}, imp = info.profiles?.[from] ?? {}
    const status = path => {
        const s = info.images?.[path] ?? "missing"
        return s.startsWith("here") ? "here" : s
    }
    const profile = []
    const all = groups.concat(Object.keys(imp).filter(k => !groups.some(g => g.keys.includes(k))).map(k => ({ id: k, keys: [k], label: k, raw: true })))
    for (const g of all) {
        const keys = g.keys.filter(k => k in imp && (cur[k] === undefined || cur[k] === null || kind(cur[k]) === kind(imp[k])))
        if (!g.keys.some(k => k in imp)) continue
        const after = Object.assign({}, cur)
        keys.forEach(k => after[k] = imp[k])
        let skip = "", text = null
        if (g.image) {
            const v = imp[g.id]
            if (v && status(v) === "missing") skip = t("Not in the file: the current one stays")
            else text = !v ? t("None") : status(v) === "file" ? t("From the file") : t("Already on this computer")
        }
        if (g.id === "wallpapers") {
            const entries = Object.entries(imp.wallpapers ?? {})
            const away = entries.filter(([s, p]) => !screens.includes(s)).map(([s]) => s)
            const kept = entries.filter(([s, p]) => screens.includes(s) && status(p) !== "missing")
            after.wallpapers = kept.reduce((o, [s, p]) => Object.assign(o, { [s]: p }), {}) // no Object.fromEntries in QML
            if (entries.length && !kept.length) skip = away.length ? arg(t("%1 not on this computer: ignored"), away.join(", ")) : t("Not in the file: the current one stays")
            else if (away.length) text = show("wallpapers", after, t) + " · " + arg(t("%1 ignored"), away.join(", "))
        }
        if (!keys.length && !skip) skip = t("Not valid here: the current one stays")
        const before = show(g.id, cur, t, langs, accents)
        const same = !skip && JSON.stringify(g.keys.map(k => cur[k] ?? null)) === JSON.stringify(g.keys.map(k => after[k] ?? null))
        profile.push({ id: "p:" + g.id, label: g.raw ? g.label : t(g.label), keys, before, after: skip || (text ?? show(g.id, after, t, langs, accents, cur)), same, skip })
    }

    const files = [], code = []
    const list = info.files ?? []
    const lua = list.find(f => f.name === "monitors.lua"), layout = list.filter(f => f.name.startsWith("monitors."))
    if (layout.length) {
        const here = lua?.here ?? null, lit = text => (text.match(/output = "[^"]*"/g) ?? []).length - (text.match(/disabled = true/g) ?? []).length
        // Same rule as the script: the layout's lit screens are exactly the screens here.
        const match = [...new Set(info.screens?.layout ?? [])].sort().join() === [...new Set(screens)].sort().join() && !!lua
        const skip = lua?.data === false ? t("Holds code, not settings: never imported")
            : !match ? arg(t("Layout for other screens (%1): never applied here"), (info.screens?.layout ?? []).join(", ") || "?") : ""
        files.push({ id: "f:screens", label: t("Screens"), files: layout.map(f => f.name), before: here ? arg(t("%1 screens"), lit(here)) : t("Automatic"),
            after: skip || arg(t("%1 screens"), info.screens.layout.length), same: !skip && layout.every(f => f.text === f.here), skip })
    }
    const keyboard = text => {
        const layout = (text.match(/kb_layout = "([^"]*)"/)?.[1] ?? "").split(",").filter(Boolean).join(", ")
        const speed = text.match(/sensitivity = (-?[0-9.]+)/)?.[1]
        return arg(t("%1, pointer %2"), layout || "?", speed ?? "0")
    }
    for (const f of list) {
        if (f.name.startsWith("monitors.")) continue
        const lines = arg(t("%1 lines"), lineCount(f.text))
        if (codeFile(f.name)) {
            code.push({ id: "f:" + f.name, label: f.name, files: [f.name], before: f.here !== null ? arg(t("%1 lines"), lineCount(f.here)) : t("None"),
                after: lines, same: f.text === f.here, skip: f.big ? t("Too large to review in full (over 64 KB): never imported") : "", text: f.text, lines: lineCount(f.text) })
            continue
        }
        const input = f.name === "input.lua"
        const skip = f.data === false ? t("Holds code, not settings: never imported") : ""
        files.push({ id: "f:" + f.name, label: input ? t("Keyboard and mouse") : f.name, files: [f.name],
            before: f.here === null ? t("None") : input ? keyboard(f.here) : arg(t("%1 lines"), lineCount(f.here)),
            after: skip || (input ? keyboard(f.text) : lines), same: !skip && f.text === f.here, skip })
    }
    return { profile, files, code }
}

// What the rows the person left checked ask the script for. Code files need their own explicit yes.
function choice(r, picked) {
    const on = row => !row.skip && picked[row.id] !== false
    const flat = rows => [].concat(...rows)
    const keys = flat(r.profile.filter(on).map(row => row.keys))
    const files = flat(r.files.filter(on).map(row => row.files).concat(r.code.filter(row => !row.skip && picked[row.id] === true).map(row => row.files)))
    const changes = r.profile.filter(row => on(row) && !row.same).length
    const changedFiles = r.files.filter(row => on(row) && !row.same).length + r.code.filter(row => !row.skip && picked[row.id] === true && !row.same).length
    return { keys, files, changes, changedFiles }
}
