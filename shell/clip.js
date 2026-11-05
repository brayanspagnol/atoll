.pragma library

// What a cliphist preview is: text, link, color or image, with the image facts cliphist reports.
function classify(preview) {
    const img = /^\[\[ binary data (.+) (\w+) (\d+)x(\d+) \]\]$/.exec(preview)
    if (img) return { kind: "image", size: img[1], fmt: img[2].toLowerCase(), w: +img[3], h: +img[4] }
    const t = preview.trim()
    if (/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(t)) return { kind: "color", color: t }
    if (/^([a-z][a-z0-9+.-]*:\/\/|mailto:)\S+$/i.test(t)) return { kind: "link" }
    return { kind: "text" }
}

// `cliphist list` output: "id<TAB>preview" per line, newest first.
function parseList(text) {
    return text.split("\n").filter(l => /^\d+\t/.test(l)).map(l => {
        const tab = l.indexOf("\t"), preview = l.slice(tab + 1)
        return Object.assign({ id: l.slice(0, tab), preview: preview }, classify(preview))
    })
}

// chip: "all", "text" (colors are text too), "link", "image" or "pinned".
function filter(items, query, chip) {
    const q = query.trim().toLowerCase()
    return items.filter(it => (chip === "all" || (chip === "pinned" ? it.pinned : chip === "text" ? it.kind === "text" || it.kind === "color" : it.kind === chip))
        && (!q || it.preview.toLowerCase().includes(q)))
}
