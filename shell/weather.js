.pragma library
// Weather from Open-Meteo, and places from its geocoding or from ipapi.co. Every remote field is untrusted:
// numbers must be finite, text is capped and only ever shown as plain text.

// WMO weather codes, as Open-Meteo reports them. Labels are English keys for Tr.t.
const codes = [
    [[0], "sun", "moon", "Clear sky"],
    [[1], "sun", "moon", "Mainly clear"],
    [[2], "cloudSun", "cloudMoon", "Partly cloudy"],
    [[3], "cloud", "cloud", "Overcast"],
    [[45, 48], "cloudFog", "cloudFog", "Fog"],
    [[51, 53, 55, 56, 57], "cloudDrizzle", "cloudDrizzle", "Drizzle"],
    [[61, 63, 65, 66, 67], "cloudRain", "cloudRain", "Rain"],
    [[71, 73, 75, 77], "cloudSnow", "cloudSnow", "Snow"],
    [[80, 81, 82], "cloudRain", "cloudRain", "Showers"],
    [[85, 86], "cloudSnow", "cloudSnow", "Snow showers"],
    [[95, 96, 99], "cloudLightning", "cloudLightning", "Thunderstorm"]
]
const labels = codes.map(c => c[3]).concat(["Unknown weather"])

function condition(code, day) {
    const c = codes.find(c => c[0].includes(code))
    return c ? { icon: day === false ? c[2] : c[1], label: c[3] } : { icon: "cloud", label: "Unknown weather" }
}

function num(v) { return typeof v === "number" && isFinite(v) ? v : null }
function round(v) { return num(v) === null ? null : Math.round(v) }
function text(v) { return typeof v === "string" ? v.replace(/[\u0000-\u001f\u007f-\u009f]/g, "").trim().slice(0, 80) : "" }
function parse(json) {
    if (typeof json !== "string") return json
    try { return JSON.parse(json) } catch (e) { return null }
}
const isObject = v => !!v && typeof v === "object" && !Array.isArray(v)
const list = v => Array.isArray(v) ? v : []

// A place we can ask the forecast for, or null: { name, admin1, country, latitude, longitude }.
function place(p) {
    if (!isObject(p)) return null
    const lat = num(p.latitude), lon = num(p.longitude), name = text(p.name)
    if (!name || lat === null || lon === null || lat < -90 || lat > 90 || lon < -180 || lon > 180) return null
    return { name, admin1: text(p.admin1), country: text(p.country), latitude: lat, longitude: lon }
}
function same(a, b) { return !!a && !!b && a.latitude === b.latitude && a.longitude === b.longitude }
function where(p) { return p ? [p.admin1, p.country].filter(s => s && s !== p.name).join(", ") : "" }

// Open-Meteo geocoding's answer, as places (at most 6).
function geocode(json) {
    const d = parse(json)
    return list(isObject(d) ? d.results : null).map(place).filter(p => p).slice(0, 6)
}
// ipapi.co's answer, as a place. A rate limit comes back as { error: true }, which has no city.
function ipPlace(json) {
    const d = parse(json)
    if (!isObject(d) || d.error) return null
    return place({ name: d.city, admin1: d.region, country: d.country_name, latitude: d.latitude, longitude: d.longitude })
}

const curl = ["curl", "-fsS", "--max-time", "15", "--proto", "=https"]
function forecastCommand(p, unit) {
    return curl.concat(["https://api.open-meteo.com/v1/forecast?latitude=" + p.latitude + "&longitude=" + p.longitude
        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
        + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=7"
        + (unit === "f" ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "")])
}
// lang: Tr.code, such as "pt-BR"; the service takes the language part.
function geocodeCommand(name, lang) {
    const l = String(lang).split("-")[0]
    return curl.concat(["https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(String(name).slice(0, 80))
        + "&count=6&language=" + (/^[a-z]{2}$/.test(l) ? l : "en") + "&format=json"])
}
const ipCommand = curl.concat(["https://ipapi.co/json/"])

// "2026-11-06T15:00" or "2026-11-06", in the place's own time, to a Date that shows those same numbers.
function localDate(iso) {
    const m = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?$/.exec(String(iso))
    return m ? new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0)) : null
}

// The forecast's JSON to what the island and the card show, or null when it lacks the current weather.
// hours: now and the next 6. days: up to 7, with from/to placing each day's low..high on the week's range (0..1).
function forecast(json, unit, name) {
    const d = parse(json)
    const cur = isObject(d) ? d.current : null
    if (!isObject(cur) || round(cur.temperature_2m) === null || !localDate(cur.time) || !String(cur.time).includes("T")) return null
    const now = condition(cur.weather_code, cur.is_day !== 0)
    const h = isObject(d.hourly) ? d.hourly : {}, times = list(h.time)
    const hour = String(cur.time).slice(0, 13)
    const start = times.findIndex(t => typeof t === "string" && localDate(t) && t.slice(0, 13) >= hour)
    const hours = []
    for (let i = Math.max(0, start); start >= 0 && i < times.length && hours.length < 7; i++) {
        const temp = round(list(h.temperature_2m)[i])
        if (temp === null || !localDate(times[i])) continue
        const c = condition(list(h.weather_code)[i], list(h.is_day)[i] !== 0)
        hours.push({ time: times[i], temp, icon: c.icon, label: c.label, rain: round(list(h.precipitation_probability)[i]) })
    }
    if (hours.length) Object.assign(hours[0], { temp: round(cur.temperature_2m), icon: now.icon, label: now.label })
    const dl = isObject(d.daily) ? d.daily : {}
    const days = []
    list(dl.time).forEach((t, i) => {
        const high = round(list(dl.temperature_2m_max)[i]), low = round(list(dl.temperature_2m_min)[i])
        if (days.length >= 7 || high === null || low === null || !localDate(t) || String(t).includes("T")) return
        const c = condition(list(dl.weather_code)[i], true)
        days.push({ date: t, high: Math.max(high, low), low: Math.min(high, low), icon: c.icon, label: c.label, rain: round(list(dl.precipitation_probability_max)[i]) })
    })
    const min = Math.min(...days.map(x => x.low)), span = Math.max(...days.map(x => x.high)) - min
    days.forEach(x => { x.from = span > 0 ? (x.low - min) / span : 0; x.to = span > 0 ? (x.high - min) / span : 1 })
    return {
        place: text(name), unit: unit === "f" ? "f" : "c",
        temp: round(cur.temperature_2m), feels: round(cur.apparent_temperature),
        humidity: round(cur.relative_humidity_2m), wind: round(cur.wind_speed_10m),
        icon: now.icon, label: now.label,
        high: days.length ? days[0].high : null, low: days.length ? days[0].low : null,
        hours, days
    }
}
