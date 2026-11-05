.pragma library
// Pure calendar logic. Dates travel as local "YYYY-MM-DD" strings so timezone shifts cannot move a day.
function pad(n) { return (n < 10 ? "0" : "") + n }
function key(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
function parse(k) { const p = k.split("-").map(Number); return new Date(p[0], p[1] - 1, p[2]) }
function addDays(k, n) { const d = parse(k); d.setDate(d.getDate() + n); return key(d) }

function easter(y) { // Anonymous Gregorian algorithm
    const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4
    const f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3)
    const h = (19 * a + b - d - g + 15) % 30, i = Math.floor(c / 4), k2 = c % 4
    const l = (32 + 2 * e + 2 * i - h - k2) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451)
    const month = Math.floor((h + l - 7 * m + 114) / 31), day = ((h + l - 7 * m + 114) % 31) + 1
    return key(new Date(y, month - 1, day))
}

function holidays(y) { // National holidays; Carnaval and Corpus Christi are "ponto facultativo"
    const e = easter(y), out = {}
    const fixed = { "01-01": "Confraternização Universal", "04-21": "Tiradentes", "05-01": "Dia do Trabalho",
        "09-07": "Independência", "10-12": "Nossa Senhora Aparecida", "11-02": "Finados",
        "11-15": "Proclamação da República", "11-20": "Consciência Negra", "12-25": "Natal" }
    for (const k in fixed) out[y + "-" + k] = fixed[k]
    out[addDays(e, -47)] = "Carnaval"
    out[addDays(e, -2)] = "Sexta-feira Santa"
    out[addDays(e, 60)] = "Corpus Christi"
    return out
}

function monthGrid(y, m) { // 42 day keys, weeks start on Sunday (BR convention)
    const first = new Date(y, m, 1), start = key(new Date(y, m, 1 - first.getDay())), out = []
    for (let i = 0; i < 42; i++) out.push(addDays(start, i))
    return out
}

function weekOf(k) { const s = addDays(k, -parse(k).getDay()), o = []; for (let i = 0; i < 7; i++) o.push(addDays(s, i)); return o }

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

const months = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
const weekdays = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
const weekdaysLong = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]
function longDay(k) { const d = parse(k); return weekdaysLong[d.getDay()] + ", " + d.getDate() + " de " + months[d.getMonth()] }
