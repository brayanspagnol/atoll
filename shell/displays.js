.pragma library
// Pure logic for the Monitor screen. A monitor is { name, x, y, w, h, rate, scale, rot, on, mirror, vrr, bit, parked }.
const ROTATIONS = [0, 90, 180, 270]

function clone(value) { return JSON.parse(JSON.stringify(value)) }

function sizeOf(m) { // layout size: scaled, and swapped when rotated a quarter turn
    const w = Math.round(m.w / m.scale), h = Math.round(m.h / m.scale)
    return m.rot % 2 ? [h, w] : [w, h]
}

function placed(list) { return list.filter(m => m.on && !m.mirror) }

function overlaps(a, ax, ay, b) {
    const [aw, ah] = sizeOf(a), [bw, bh] = sizeOf(b)
    return ax < b.x + bw && ax + aw > b.x && ay < b.y + bh && ay + ah > b.y
}

// Moves one monitor to the nearest spot touching another, without overlaps. Edges and centers attract.
function settle(list, name) {
    const out = clone(list), m = out.find(o => o.name === name)
    const others = placed(out).filter(o => o.name !== name)
    if (!m || !m.on || m.mirror || !others.length) return out
    const [w, h] = sizeOf(m)
    const near = (value, targets) => { for (const t of targets) if (Math.abs(value - t) < 120) return t; return value }
    const spots = []
    for (const o of others) {
        const [ow, oh] = sizeOf(o)
        const y = near(Math.max(o.y - h + 40, Math.min(o.y + oh - 40, m.y)), [o.y, o.y + oh - h, Math.round(o.y + (oh - h) / 2)])
        const x = near(Math.max(o.x - w + 40, Math.min(o.x + ow - 40, m.x)), [o.x, o.x + ow - w, Math.round(o.x + (ow - w) / 2)])
        spots.push({ x: o.x + ow, y }, { x: o.x - w, y }, { x, y: o.y + oh }, { x, y: o.y - h })
    }
    const free = spots.filter(s => !others.some(o => overlaps(m, s.x, s.y, o)))
    free.sort((a, b) => Math.hypot(a.x - m.x, a.y - m.y) - Math.hypot(b.x - m.x, b.y - m.y))
    if (free.length) { m.x = free[0].x; m.y = free[0].y }
    return out
}

function normalize(list) { // top left at 0,0, because the layout only matters relatively
    const out = clone(list), p = placed(out)
    if (!p.length) return out
    const dx = Math.min(...p.map(m => m.x)), dy = Math.min(...p.map(m => m.y))
    for (const m of p) { m.x -= dx; m.y -= dy }
    return out
}

function row(list) { // all placed monitors side by side, keeping their order
    const out = clone(list)
    let x = 0
    for (const m of placed(out).sort((a, b) => a.x - b.x)) { m.x = x; m.y = 0; x += sizeOf(m)[0] }
    return out
}

// ["3440x1440@99.98Hz", ...] to [{ res: "3440x1440", rates: ["99.98", ...] }], without repeats.
function parseModes(available) {
    const out = []
    for (const text of available) {
        const hit = text.match(/^(\d+x\d+)@([\d.]+)Hz$/)
        if (!hit) continue
        let mode = out.find(o => o.res === hit[1])
        if (!mode) { mode = { res: hit[1], rates: [] }; out.push(mode) }
        if (!mode.rates.includes(hit[2])) mode.rates.push(hit[2])
    }
    return out
}

function ruleOf(m) { // the table for hl.monitor, as Lua source
    if (!m.on) return `{ output = ${JSON.stringify(m.name)}, disabled = true }`
    if (m.mirror) return `{ output = ${JSON.stringify(m.name)}, disabled = false, mirror = ${JSON.stringify(m.mirror)} }`
    return `{ output = ${JSON.stringify(m.name)}, disabled = false, mirror = "", mode = "${m.w}x${m.h}@${m.rate}", position = "${m.x}x${m.y}", scale = ${m.scale}, transform = ${m.rot}, vrr = ${m.vrr ? 1 : 0}, bitdepth = ${m.bit ? 10 : 8} }`
}

function differs(a, b) {
    const keys = ["x", "y", "w", "h", "rate", "scale", "rot", "on", "mirror", "vrr", "bit"]
    return keys.some(k => a[k] !== b[k])
}

// Lua that applies only what changed, turning screens on before others go off, so a screen stays lit.
function applyCode(before, after) {
    const changed = after.filter(m => { const old = before.find(o => o.name === m.name); return !old || differs(old, m) })
    // A parked panel stays parked, unless it would be the only screen left: then it has to light up.
    const othersLit = after.some(m => m.on && !m.parked)
    return changed.filter(m => m.on).concat(changed.filter(m => !m.on))
        .filter(m => !(m.parked && m.on && othersLit)).map(m => `hl.monitor(${ruleOf(m)})`).join("; ")
}

function configFile(list, lid, workspaces) { // the file hypr/monitors.lua reads at startup
    const lines = list.map(m => "        " + ruleOf(m) + ",")
    const rules = Object.keys(workspaces).sort((a, b) => a - b).map(w => `        [${JSON.stringify(w)}] = ${JSON.stringify(workspaces[w])},`)
    return `-- Written by the Monitor screen.\nreturn {\n    lid = ${JSON.stringify(lid)},\n    monitors = {\n${lines.join("\n")}\n    },\n    workspaces = {\n${rules.join("\n")}\n    },\n}\n`
}
