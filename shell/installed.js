.pragma library
.import "parse.js" as P
// The Installed page: what scripts/apps list prints, search, counts and sizes. Pure so it can be tested.

var sources = ["system", "flatpak", "appimage"]
var reasons = ["atoll", "default", "required"]

// Lines of "id, name, icon, source, ref, bytes, reason", tab separated. A line that does not fit is dropped,
// and so is a second line for the same app. names: desktop id -> the name in the person's language. Largest first.
function parse(text, names) {
    const out = [], seen = {}
    for (const line of String(text ?? "").split("\n")) {
        const f = line.split("\t")
        if (f.length !== 7) continue
        const [id, name, icon, source, ref, size, why] = f
        const key = source + "\t" + ref
        if (!id || !ref || !sources.includes(source) || !/^\d{1,15}$/.test(size) || (why && !reasons.includes(why)) || seen[key]) continue
        seen[key] = true
        out.push({ id, name: (names && names[id]) || name || id, icon, source, ref, size: Number(size), why })
    }
    return out.sort((a, b) => b.size - a.size || a.name.localeCompare(b.name))
}

function counts(apps) {
    const c = { all: apps.length, system: 0, flatpak: 0, appimage: 0 }
    for (const a of apps) c[a.source]++
    return c
}

// source: "all" or one of sources. The query matches the name or the id, without accents.
function filter(apps, query, source) {
    const q = P.fold(String(query ?? "").trim())
    return apps.filter(a => (source === "all" || a.source === source) && (!q || P.fold(a.name).includes(q) || P.fold(a.id).includes(q)))
}

// "412 MB", "3,8 GB": Atoll's binary units, with the decimal point of the person's language.
function size(bytes, point) { return P.bytes(bytes).replace(".", point || ".") }

// The command as someone would type it: arguments with spaces or symbols in single quotes.
function commandLine(argv) { return argv.map(a => /^[A-Za-z0-9@%+=:,./_-]+$/.test(a) ? a : P.shQuote(a)).join(" ") }
