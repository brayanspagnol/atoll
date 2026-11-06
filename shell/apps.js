.pragma library
// Default apps: the roles, their MIME types, and what scripts/open-app --state prints. Pure so it can be tested.
// The first type is the one scripts/open-app asks the system about when Atoll has no choice.
var roles = [
    { id: "browser", icon: "globe", category: "WebBrowser", types: ["x-scheme-handler/https", "x-scheme-handler/http", "text/html"] },
    { id: "terminal", icon: "term", category: "TerminalEmulator", types: [], fallback: "kitty" },
    { id: "files", icon: "folder", category: "FileManager", types: ["inode/directory"] },
    { id: "text", icon: "note", category: "TextEditor", types: ["text/plain"] },
    { id: "images", icon: "image", category: "", types: ["image/png", "image/jpeg", "image/webp", "image/gif"] },
    { id: "video", icon: "film", category: "", types: ["video/mp4", "video/x-matroska", "video/webm"] },
    { id: "music", icon: "music", category: "", types: ["audio/mpeg", "audio/flac", "audio/ogg"] },
    { id: "email", icon: "mail", category: "Email", types: ["x-scheme-handler/mailto"] }
]
function allTypes() { return [].concat(...roles.map(r => r.types)) } // QML's JavaScript has no flatMap
function base(id) { return (id || "").replace(/\.desktop$/, "") }

// Lines: "atoll\trole\tid", "default\ttype\tid.desktop" (id may be empty), "entry\tid\ttype;type;". The first entry of an id wins.
function parseState(text) {
    const s = { atoll: {}, defaults: {}, mimes: {} }
    for (const line of text.split("\n")) {
        const f = line.split("\t")
        if (f.length !== 3) continue
        if (f[0] === "atoll" && f[2]) s.atoll[f[1]] = f[2]
        else if (f[0] === "default") s.defaults[f[1]] = base(f[2])
        else if (f[0] === "entry" && !(f[1] in s.mimes)) s.mimes[f[1]] = f[2].split(";").filter(Boolean)
    }
    return s
}

// What Atoll opens for the role: its own choice, else the system default, else today's fixed command's app.
function current(role, s) { return s.atoll[role.id] || (role.types.length ? s.defaults[role.types[0]] : "") || role.fallback || "" }

// Apps that can fill the role, by category or MIME type, by name. keep: ids that stay listed even if hidden or unrelated.
function candidates(role, entries, mimes, keep) {
    const fits = e => (role.category && (e.categories || []).includes(role.category)) || (mimes[e.id] || []).some(t => role.types.includes(t))
    return entries.filter(e => keep.includes(e.id) || (!e.noDisplay && fits(e))).sort((a, b) => a.name.localeCompare(b.name))
}

// Atoll chose an app but the system opens some of the role's types in another one: { app, all }, or null.
// A type with no system default is not a disagreement: choosing the app again just fills it.
function mismatch(role, s) {
    const id = s.atoll[role.id]
    if (!id) return null
    const other = role.types.map(t => s.defaults[t]).filter(d => d && d !== id)
    return other.length ? { app: other[0], all: other.length === role.types.length } : null
}
