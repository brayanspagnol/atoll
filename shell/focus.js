.pragma library
// Focus mode, the logic behind Focus.qml. A session is { phase: "focus" | "break", startedAt, endsAt, pomodoro },
// times in epoch ms; endsAt 0 means until turned off. Everything is derived from the clock, so a suspend can't stretch it.

const MIN = 60000, DAY = 24 * 60 * MIN
var durations = [25, 50, 60, 0] // the card's choices; 0 = until turned off

function make(phase, minutes, now, pomodoro) {
    const m = Math.min(1440, Math.max(0, Math.round(Number(minutes)) || 0))
    return { phase, startedAt: now, endsAt: m ? now + m * MIN : 0, pomodoro: !!pomodoro && m > 0 }
}
// What follows a phase that ran out: pomodoro alternates 25 min of focus and 5 of break; otherwise nothing.
function next(s, now) {
    if (!s.pomodoro) return null
    return s.phase === "focus" ? make("break", 5, now, true) : make("focus", 25, now, true)
}
// More time on a running timer, or a new focus of that length once it has ended. One with no end stays as it is.
function extend(s, minutes, now) {
    if (!s) return make("focus", minutes, now, false)
    if (!s.endsAt) return s
    const add = Math.min(1440, Math.max(0, Math.round(Number(minutes)) || 0)) * MIN
    return Object.assign({}, s, { endsAt: Math.min(Math.max(s.endsAt, now) + add, s.startedAt + DAY) })
}
function minutes(s) { return s.endsAt ? Math.round((s.endsAt - s.startedAt) / MIN) : 0 }
// Whole seconds on the clock: left, rounded up so it starts at 25:00; or elapsed when it runs until turned off.
function seconds(s, now) {
    return s.endsAt ? Math.ceil(Math.max(0, s.endsAt - now) / 1000) : Math.floor(Math.max(0, now - s.startedAt) / 1000)
}
// How much of the ring is left, 0 to 1. Full when there is no end.
function fraction(s, now) {
    const total = s.endsAt - s.startedAt
    return s.endsAt && total > 0 ? Math.min(1, Math.max(0, (s.endsAt - now) / total)) : 1
}
function clock(sec) {
    const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), r = sec % 60
    const two = n => (n < 10 ? "0" : "") + n
    return h ? h + ":" + two(m) + ":" + two(r) : m + ":" + two(r)
}
// The let-through list from the profile: only names, whatever the file holds.
function names(v) { return Array.isArray(v) ? v.filter(a => typeof a === "string" && a.trim()) : [] }
function allowed(appName, allow) {
    const name = String(appName ?? "").trim().toLowerCase()
    return !!name && names(allow).some(a => a.trim().toLowerCase() === name)
}
// Apps in the notification history (oldest first) not let through yet, newest first.
function seenApps(history, allow) {
    const out = []
    for (const n of (Array.isArray(history) ? history : []).slice().reverse()) {
        const name = typeof n?.appName === "string" ? n.appName.trim() : ""
        if (name && !out.includes(name) && !allowed(name, allow)) out.push(name)
    }
    return out
}
// A saved session, or null when the file is unreadable, odd, or the session is over.
function restore(text, now) {
    let s = null
    try { s = JSON.parse(text) } catch (e) { return null }
    if (!s || typeof s !== "object") return null
    const num = v => typeof v === "number" && isFinite(v)
    const ok = (s.phase === "focus" || s.phase === "break") && num(s.startedAt) && num(s.endsAt)
        && s.startedAt <= now + MIN && now - s.startedAt < DAY
        && (s.endsAt === 0 ? s.phase === "focus" && s.pomodoro !== true : s.endsAt > now && s.endsAt - s.startedAt <= DAY)
    return ok ? { phase: s.phase, startedAt: s.startedAt, endsAt: s.endsAt, pomodoro: s.pomodoro === true && s.endsAt > 0 } : null
}
