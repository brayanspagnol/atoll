.pragma library

function overlapping(list) {
    for (let i = 0; i < list.length; i++) {
        for (let j = i + 1; j < list.length; j++) {
            const a = list[i], b = list[j]
            const w = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x)
            const h = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y)
            if (w > 0 && h > 0 && w * h > 0.1 * Math.min(a.w * a.h, b.w * b.h)) return true
        }
    }
    return false
}

// Where each window goes in the overview, in an area of areaW x areaH.
// Tiled windows keep their arrangement. Overlapping ones (maximized, floating) go in a grid, or some would stay hidden.
function spread(list, screenW, screenH, areaW, areaH, gap) {
    if (!list.length) return []
    if (!overlapping(list)) {
        const k = Math.min(areaW / screenW, areaH / screenH)
        const ox = (areaW - screenW * k) / 2, oy = (areaH - screenH * k) / 2
        return list.map(r => ({ x: ox + r.x * k, y: oy + r.y * k, w: r.w * k, h: r.h * k }))
    }
    // Rows of the same height, as many as cover the most area, so no window ends up much smaller than its neighbors.
    let best = null
    for (let count = 1; count <= list.length; count++) {
        const rows = []
        for (let i = 0; i < count; i++) rows.push(list.slice(Math.floor(i * list.length / count), Math.floor((i + 1) * list.length / count)))
        const limit = (areaH - gap * (count - 1)) / count
        const heights = rows.map(row => Math.min(limit, (areaW - gap * (row.length - 1)) / row.reduce((sum, r) => sum + r.w / r.h, 0)))
        const covered = rows.reduce((sum, row, i) => sum + row.reduce((inner, r) => inner + heights[i] * heights[i] * r.w / r.h, 0), 0)
        if (!best || covered > best.covered) best = { covered, rows, heights }
    }
    const total = best.heights.reduce((sum, h) => sum + h, 0) + gap * (best.rows.length - 1)
    const out = []
    let y = (areaH - total) / 2
    best.rows.forEach((row, i) => {
        const h = best.heights[i]
        const width = row.reduce((sum, r) => sum + h * r.w / r.h, 0) + gap * (row.length - 1)
        let x = (areaW - width) / 2
        for (const r of row) {
            const w = h * r.w / r.h
            out.push({ x, y, w, h })
            x += w + gap
        }
        y += h + gap
    })
    return out
}
