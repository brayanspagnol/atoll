.pragma library
// Parsers for /proc and top output. Pure so they can be tested without a running shell.
function cpu(text) { // [{total, idle}], index 0 = aggregate
    return text.split("\n").filter(l => /^cpu\d* /.test(l)).map(l => {
        const n = l.trim().split(/\s+/).slice(1).map(Number)
        return { total: n.slice(0, 8).reduce((a, b) => a + b, 0), idle: n[3] + n[4] }
    })
}
function mem(text) { // bytes
    const g = k => { const m = text.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")); return m ? Number(m[1]) * 1024 : 0 }
    const total = g("MemTotal"), avail = g("MemAvailable"), st = g("SwapTotal"), sf = g("SwapFree")
    return { total, used: total - avail, swapTotal: st, swapUsed: st - sf }
}
function net(text) { // cumulative bytes over physical-ish interfaces
    let rx = 0, tx = 0
    text.split("\n").slice(2).forEach(l => {
        const m = l.trim().match(/^([^:]+):\s*(.*)$/)
        if (!m || /^(lo|docker|veth|br-|virbr|tailscale)/.test(m[1])) return
        const n = m[2].split(/\s+/).map(Number)
        rx += n[0]; tx += n[8]
    })
    return { rx, tx }
}
function top(text, limit) { // last batch of `top -b -n2`, default field order
    const lines = text.split("\n"), i = lines.map(l => /^\s*PID\s+USER/.test(l)).lastIndexOf(true)
    if (i < 0) return []
    const out = []
    for (const l of lines.slice(i + 1)) {
        const f = l.trim().split(/\s+/)
        if (f.length < 12) continue
        out.push({ pid: Number(f[0]), user: f[1], cpu: Number(f[8]), mem: Number(f[9]), name: f.slice(11).join(" ") })
    }
    return out.slice(0, limit)
}
function bytes(n) {
    const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0
    while (n >= 1024 && i < 4) { n /= 1024; i++ }
    return n.toFixed(i && n < 100 ? 1 : 0) + " " + u[i]
}
