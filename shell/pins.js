.pragma library
// What the island shows after the clock, in the profile's `island` key: an ordered list of these ids.
// The workspaces and the clock always stay. label is the English text, translated where shown; page is the screen it opens.
const items = [
    { id: "lagu", label: "Assistant", icon: "sparkle", page: "ia" },
    { id: "weather", label: "Weather", icon: "cloudSun", page: "clima" },
    { id: "media", label: "Now playing", icon: "music", page: "" },
    { id: "tray", label: "App tray", icon: "grid", page: "" },
    { id: "sound", label: "Sound", icon: "som", page: "som" },
    { id: "network", label: "Internet", icon: "rede", page: "rede" },
    { id: "bluetooth", label: "Bluetooth", icon: "bt", page: "bt" },
    { id: "clipboard", label: "Clipboard", icon: "clipboard", page: "" },
    { id: "notifications", label: "Notifications", icon: "avisos", page: "avisos" },
    { id: "focus", label: "Focus", icon: "timer", page: "" },
    { id: "power", label: "Power", icon: "energia", page: "energia" },
    { id: "battery", label: "Battery", icon: "bat", page: "perf" }
]
const ids = items.map(i => i.id)
function item(id) { return items.find(i => i.id === id) ?? null }

// The saved list, from a profile anything can have written: known ids, each once, in their order.
// Not a list, or a list with nothing known in it, gives the default; an empty list is a choice and stays.
function valid(saved) {
    // The settings file hands over a list-like object, not always an Array.
    if (!saved || typeof saved !== "object" || typeof saved.length !== "number") return ids.slice()
    const list = Array.from(saved)
    const out = list.filter((id, i) => ids.includes(id) && list.indexOf(id) === i)
    return out.length || !list.length ? out : ids.slice()
}
// A profile from before the list: its "Show in the island" switches for the weather and the assistant.
function migrate(saved) {
    return ids.filter(id => !(id === "weather" && saved?.weatherChip === false) && !(id === "lagu" && saved?.aiChip === false))
}
// Back in at a place (an undo), or else before the first pinned item that comes after it by default, so it lands near where it was.
function pin(list, id, place) {
    if (list.includes(id) || !ids.includes(id)) return list
    const by = list.findIndex(o => ids.indexOf(o) > ids.indexOf(id))
    const at = place >= 0 ? Math.min(place, list.length) : by < 0 ? list.length : by
    return list.slice(0, at).concat([id], list.slice(at))
}
function unpin(list, id) { return list.filter(o => o !== id) }
function set(list, id, on) { return on ? pin(list, id) : unpin(list, id) }
// by places to the right (negative: left), clamped to the list.
function move(list, id, by) {
    const from = list.indexOf(id), to = Math.max(0, Math.min(list.length - 1, from + by))
    if (from < 0 || to === from) return list
    const out = list.filter(o => o !== id)
    out.splice(to, 0, id)
    return out
}
