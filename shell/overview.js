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
    // The column count that leaves cells closest to the shape of the windows.
    const shape = list.reduce((sum, r) => sum + r.w / r.h, 0) / list.length
    let cols = 1, best = Infinity
    for (let c = 1; c <= list.length; c++) {
        const rows = Math.ceil(list.length / c)
        const cell = ((areaW - gap * (c - 1)) / c) / ((areaH - gap * (rows - 1)) / rows)
        const miss = Math.abs(Math.log(cell / shape))
        if (miss < best) { best = miss; cols = c }
    }
    const rows = Math.ceil(list.length / cols)
    const cellW = (areaW - gap * (cols - 1)) / cols, cellH = (areaH - gap * (rows - 1)) / rows
    return list.map((r, i) => {
        const row = Math.floor(i / cols), inRow = row === rows - 1 ? list.length - cols * (rows - 1) : cols
        const k = Math.min(cellW / r.w, cellH / r.h)
        // A shorter last row stays centered.
        const startX = (areaW - inRow * cellW - (inRow - 1) * gap) / 2
        const col = i - row * cols
        return {
            x: startX + col * (cellW + gap) + (cellW - r.w * k) / 2,
            y: row * (cellH + gap) + (cellH - r.h * k) / 2,
            w: r.w * k, h: r.h * k
        }
    })
}
