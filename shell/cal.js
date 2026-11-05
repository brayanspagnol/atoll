.pragma library
// Pure calendar logic. Dates travel as local "YYYY-MM-DD" strings so timezone shifts cannot move a day.
function pad(n) { return (n < 10 ? "0" : "") + n }
function key(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
function parse(k) { const p = k.split("-").map(Number); return new Date(p[0], p[1] - 1, p[2]) }
function addDays(k, n) { const d = parse(k); d.setDate(d.getDate() + n); return key(d) }

function monthGrid(y, m, weekStart) { // 42 day keys; weekStart: 0 = Sunday ... 6 = Saturday
    const offset = (new Date(y, m, 1).getDay() - (weekStart || 0) + 7) % 7
    const start = key(new Date(y, m, 1 - offset)), out = []
    for (let i = 0; i < 42; i++) out.push(addDays(start, i))
    return out
}

function weekOf(k, weekStart) { const s = addDays(k, -((parse(k).getDay() - (weekStart || 0) + 7) % 7)), o = []; for (let i = 0; i < 7; i++) o.push(addDays(s, i)); return o }

function isoWeek(k) {
    const d = parse(k); d.setDate(d.getDate() + 3 - (d.getDay() + 6) % 7)
    const w1 = new Date(d.getFullYear(), 0, 4)
    return 1 + Math.round(((d - w1) / 86400000 - 3 + (w1.getDay() + 6) % 7) / 7)
}

function occurs(ev, k) {
    if (k < ev.date) return false
    if (ev.date === k) return true
    const a = parse(ev.date), b = parse(k)
    switch (ev.repeat) {
    case "weekly": return a.getDay() === b.getDay()
    case "monthly": return a.getDate() === b.getDate()
    case "yearly": return a.getDate() === b.getDate() && a.getMonth() === b.getMonth()
    default: return false
    }
}

function on(events, k) {
    return events.filter(e => occurs(e, k)).sort((x, y) => (x.start || "").localeCompare(y.start || ""))
}

function upcoming(events, from, days, limit) {
    const out = []
    for (let i = 0; i < days && out.length < limit; i++) {
        const k = addDays(from, i)
        on(events, k).forEach(e => out.push({ day: k, ev: e }))
    }
    return out.slice(0, limit)
}

function validTime(t) { return /^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(t) }
