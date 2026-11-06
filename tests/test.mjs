// Self-check for cal.js and parse.js: node test.mjs
import fs from "node:fs"; import vm from "node:vm"; import assert from "node:assert"; import { spawnSync } from "node:child_process"
const load = (file, names) => {
    const ctx = {}; vm.createContext(ctx)
    vm.runInContext(fs.readFileSync(new URL("../shell/" + file, import.meta.url), "utf8").replace(".pragma library", "") + `;globalThis.x={${names}}`, ctx)
    return ctx.x
}
const C = load("cal.js", "key,addDays,monthGrid,weekOf,isoWeek,occurs,on,upcoming,validTime")
const P = load("parse.js", "cpu,mem,net,top,bytes,shQuote,newerVersion,zipLayouts,joinLayouts,xkbCatalog,powerProfiles,inWindow,nmcliRows,modelName,chassisKind,cpuName,duration,fold")
const g = C.monthGrid(2026, 10); assert.equal(g.length, 42); assert.equal(g[0], "2026-11-01"); assert.equal(g[41], "2026-12-12")
assert.equal(C.monthGrid(2026, 9)[0], "2026-09-27") // October 2026 starts on a Thursday
assert.deepEqual([C.isoWeek("2026-01-01"), C.isoWeek("2026-11-05"), C.isoWeek("2027-01-03")], [1, 45, 53])
assert.equal(C.weekOf("2026-11-05")[0], "2026-11-01")
const w = { date: "2026-11-05", repeat: "weekly", start: "10:00" }, m = { date: "2026-01-31", repeat: "monthly" }, y = { date: "2024-02-29", repeat: "yearly" }
assert(C.occurs(w, "2026-11-12") && !C.occurs(w, "2026-11-13") && !C.occurs(w, "2026-10-29"))
assert(C.occurs(m, "2026-03-31") && !C.occurs(m, "2026-02-28")); assert(C.occurs(y, "2028-02-29"))
assert.equal(C.on([{ date: "2026-11-05", start: "12:00", t: 1 }, { date: "2026-11-05", start: "09:00", t: 2 }], "2026-11-05")[0].t, 2)
assert.equal(C.upcoming([w], "2026-11-05", 15, 9).length, 3)
assert(C.validTime("23:59") && !C.validTime("24:00") && !C.validTime("9:00"))
assert.equal(C.monthGrid(2026, 10, 1)[0], "2026-10-26") // November 2026 on a Monday-first calendar
assert.equal(C.monthGrid(2026, 1, 0)[0], "2026-02-01")  // the 1st already falls on the week start
assert.equal(C.weekOf("2026-11-01", 1)[0], "2026-10-26") // a Sunday belongs to the week that began on Monday
assert.equal(C.weekOf("2026-11-02", 1)[0], "2026-11-02")
const c = P.cpu("cpu  100 0 100 700 100 0 0 0 0 0\ncpu0 50 0 50 350 50 0 0 0 0 0\nintr 1\n"); assert.equal(c.length, 2); assert.equal(c[0].total, 1000); assert.equal(c[0].idle, 800)
const mm = P.mem("MemTotal: 1000 kB\nMemAvailable: 400 kB\nSwapTotal: 100 kB\nSwapFree: 75 kB\n"); assert.equal(mm.used, 614400); assert.equal(mm.swapUsed, 25600)
const nn = P.net("h\nh\n lo: 9 0 0 0 0 0 0 0 9 0\n wlp0: 100 1 0 0 0 0 0 0 200 1 0 0 0 0 0 0\ndocker0: 7 0 0 0 0 0 0 0 7\n"); assert.equal(nn.rx, 100); assert.equal(nn.tx, 200)
const t = P.top("    PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND\n 1 a 20 0 1 1 1 S 99.0 1.0 0:00.01 old\n\ntop\n    PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND\n 22 bob 20 0 1 1 1 R 12.5 3.2 0:01.00 Web Content\n", 5)
assert.equal(t.length, 1); assert.equal(t[0].name, "Web Content"); assert.equal(t[0].cpu, 12.5); assert.equal(P.top("nada", 5).length, 0)
assert.equal(P.shQuote("/opt/my app"), "'/opt/my app'")
assert.equal(P.shQuote("it's"), "'it'\\''s'")
assert.equal(P.bytes(1536), "1.5 KB"); assert.equal(P.bytes(500), "500 B")
assert(P.newerVersion("v1.10.0", "1.9.2") && !P.newerVersion("v1.6.1", "1.6.1") && !P.newerVersion("v1.5.0", "1.6.1"))

// Screens: touching, never overlapping, and only changed screens get touched.
const D = load("displays.js", "settle,normalize,row,parseModes,ruleOf,applyCode,configFile,sizeOf")
const mon = (name, x, y, w, h, more) => ({ name, x, y, w, h, rate: "60.00", scale: 1, rot: 0, on: true, mirror: "", vrr: false, bit: false, parked: false, ...more })
const big = mon("A", 0, 0, 3440, 1440), small = mon("B", 3440, 0, 1920, 1080)
const moved = (x, y) => D.settle([big, { ...small, x, y }], "B").find(m => m.name === "B")
assert.equal(moved(500, 500).y, 1440) // dropped inside: pushed out below
assert.deepEqual([moved(3600, 30).x, moved(3600, 30).y], [3440, 0]) // near the top edge: snaps to it
assert.equal(moved(-1000, 100).x, -1920)
assert.deepEqual(D.sizeOf({ ...small, rot: 1 }), [1080, 1920])
assert.deepEqual(D.sizeOf({ ...big, scale: 2 }), [1720, 720])
assert.deepEqual(D.normalize([{ ...big, x: 1920 }, { ...small, x: 0 }]).map(m => m.x), [1920, 0])
assert.deepEqual(D.normalize([{ ...big, x: 5, y: 7 }]).map(m => [m.x, m.y]), [[0, 0]])
assert.deepEqual(D.row([{ ...small, x: 9000 }, { ...big, x: 100, y: 50 }]).map(m => m.x), [3440, 0])
const three = [big, small, mon("C", -1920, 0, 1920, 1080)]
const dropped = D.settle(three.map(m => m.name === "B" ? { ...m, x: 200, y: 100 } : m), "B")
const hit = (a, b) => { const [aw, ah] = D.sizeOf(a), [bw, bh] = D.sizeOf(b); return a.x < b.x + bw && a.x + aw > b.x && a.y < b.y + bh && a.y + ah > b.y }
assert(!dropped.some((a, i) => dropped.some((b, j) => i < j && hit(a, b))))
const modes = D.parseModes(["3440x1440@99.98Hz", "3440x1440@59.97Hz", "3440x1440@59.97Hz", "1920x1080@60.00Hz", "lixo"])
assert.deepEqual(JSON.parse(JSON.stringify(modes)), [{ res: "3440x1440", rates: ["99.98", "59.97"] }, { res: "1920x1080", rates: ["60.00"] }])
assert.equal(D.applyCode([big, small], [big, small]), "") // nothing changed, no modeset
const only = D.applyCode([big, small], [big, { ...small, y: 100 }]); assert(only.includes('"B"') && !only.includes('"A"'))
assert(only.includes('position = "3440x100"') && only.includes('mode = "1920x1080@60.00"'))
const order = D.applyCode([big, { ...small, on: false }], [{ ...big, on: false }, small]); assert(order.indexOf('"B"') < order.indexOf('"A"')) // lit first
assert(!D.applyCode([big, small], [big, { ...small, y: 5, parked: true }]).includes('"B"')) // a parked panel stays parked
const alone = D.applyCode([big, { ...small, parked: true }], [{ ...big, on: false }, { ...small, y: 5, parked: true }]); assert(alone.includes('"B"')) // the only screen left must light up
assert(D.ruleOf({ ...small, mirror: "A" }).includes('mirror = "A"')); assert(D.ruleOf({ ...small, on: false }).includes("disabled = true"))
fs.writeFileSync("/tmp/atoll-monitors.lua", D.configFile([big, { ...small, on: false }], "off", { 1: "A", 10: "B" }))
assert.equal(spawnSync("luac", ["-p", "/tmp/atoll-monitors.lua"]).status, 0); fs.rmSync("/tmp/atoll-monitors.lua")

// Window rules: what reaches Hyprland is a valid, escaped Lua table, and hypr/rules.lua loads it rule by rule.
const R = load("rules.js", "blank,escapeRegex,luaString,normalize,hasEffect,spec,parse,upsert,remove,jsonFile,configFile,liveCode,removeCode,openApps")
const js = v => JSON.parse(JSON.stringify(v))
assert.equal(R.escapeRegex("org.app(1)+[x]$"), "org\\.app\\(1\\)\\+\\[x\\]\\$")
assert.equal(R.luaString('a"b\\c\n'), '"a\\"b\\\\c\\010"')
assert.equal(R.normalize({ class: "  " }), null); assert.equal(R.normalize({ class: "a\nb" }), null); assert.equal(R.normalize(null), null)
const nr = R.normalize({ class: " mpv ", pin: true, maximize: true, fullscreen: true, size: [40, 300], opacity: 2, workspace: "3", monitor: "DP-1" })
assert.deepEqual(js(nr), { ...js(R.blank("mpv")), pin: true, float: true, fullscreen: true, workspace: "3" }) // pin floats, fullscreen wins, a workspace beats a screen
assert.deepEqual(js(R.normalize({ class: "a", size: [420, 640], opacity: 0.856, monitor: "HDMI-A-1" })), { ...js(R.blank("a")), float: true, size: [420, 640], opacity: 0.86, monitor: "HDMI-A-1" })
assert.equal(R.normalize({ class: "a", monitor: "x; os.exit()", workspace: "0" }).monitor, "")
assert.equal(R.hasEffect(R.blank("a")), false)
assert.deepEqual(js(R.parse("{oops")), []); assert.deepEqual(js(R.parse('{"rules": 3}')), [])
const parsed = R.parse(JSON.stringify({ rules: [{ class: "a", float: true }, { class: "b" }, { class: "a", noFocus: true }, 7] }))
assert.deepEqual(js(parsed.map(r => r.class + ":" + r.float + r.noFocus)), ["a:falsetrue"]) // the last one for a class wins; one with no effect is dropped
let rl = R.upsert([], R.normalize({ class: "a", float: true })); rl = R.upsert(rl, R.normalize({ class: "b", center: true })); rl = R.upsert(rl, R.normalize({ class: "a", pin: true }))
assert.deepEqual(js(rl.map(r => r.class + r.pin)), ["atrue", "bfalse"]); assert.deepEqual(js(R.remove(rl, "a").map(r => r.class)), ["b"])
assert.deepEqual(js(R.parse(R.jsonFile(rl))), js(rl))
const odd = R.normalize({ class: 'we"ird\\app.x', float: true, center: true, size: [800, 600], pin: true, maximize: true, opacity: 0.9, noFocus: true, monitor: "eDP-1" })
const sp = R.spec(odd)
for (const part of ['class = "^(we\\"ird\\\\\\\\app\\\\.x)$"', 'size = "800 600"', "pin = true", "center = true", 'opacity = "0.9"', "no_initial_focus = true", 'monitor = "eDP-1"', "maximize = true"]) assert(sp.includes(part), part)
const rdir = fs.mkdtempSync("/tmp/atoll-test-"), rulesLua = new URL("../hypr/rules.lua", import.meta.url).pathname
const luaRun = (code, home) => spawnSync("lua", ["-e", code], { encoding: "utf8", env: { ...process.env, HOME: home ?? rdir } })
fs.mkdirSync(rdir + "/.config/atoll", { recursive: true })
fs.writeFileSync(rdir + "/.config/atoll/rules.lua", R.configFile(R.upsert(rl, odd)))
assert.equal(spawnSync("luac", ["-p", rdir + "/.config/atoll/rules.lua"]).status, 0)
for (const code of [R.liveCode(odd), R.removeCode(odd.class)]) { fs.writeFileSync(rdir + "/eval.lua", code); assert.equal(spawnSync("luac", ["-p", rdir + "/eval.lua"]).status, 0, code) }
// The real hypr/rules.lua, against a stand-in hl that records the specs. Hyprland's regex is RE2; JS's agrees on these.
const stub = `seen = {}; off = {}; hl = { layer_rule = function() end, window_rule = function(s) assert(type(s) == "table" and s.match, "bad spec"); seen[#seen + 1] = s; return { set_enabled = function(self, on) off[#off + 1] = s.name .. "=" .. tostring(on) end } end }`
const show = `local out = {}; for k in pairs(atoll_user_rules or {}) do out[#out + 1] = k end; table.sort(out); print("KEYS " .. table.concat(out, ",")); for _, s in ipairs(seen) do if s.name then print("RULE " .. s.name .. " " .. s.match.class) end end; print("OFF " .. table.concat(off, ","))`
const boot = `${stub}; dofile(${JSON.stringify(rulesLua)}); `
const loaded = luaRun(boot + show)
assert.equal(loaded.status, 0, loaded.stderr)
assert(loaded.stdout.includes('KEYS a,b,we"ird\\app.x\n'), loaded.stdout)
const userRe = new RegExp(loaded.stdout.split("\n").find(l => l.startsWith('RULE atoll-user: we"ird')).split(" ").pop())
assert(userRe.test('we"ird\\app.x') && !userRe.test('we"ird\\appXx') && !userRe.test('xwe"ird\\app.x'))
// Live: replacing a rule switches the old one off, and so does removing one.
const live = luaRun(boot + `${R.liveCode(R.normalize({ class: "a", noFocus: true }))}; ${R.removeCode("b")}; ${R.removeCode("never")}; ${show}`)
assert.equal(live.status, 0, live.stderr); assert(live.stdout.includes('KEYS a,we"ird'), live.stdout); assert(live.stdout.includes("OFF atoll-user: a=false,atoll-user: b=false\n"), live.stdout)
assert.equal(luaRun(`${stub}; ${R.liveCode(odd)}; ${R.removeCode("a")}; ${show}`).status, 0) // before any file was loaded
// A broken entry loads nothing in its place, and a broken file or none at all is no error.
fs.writeFileSync(rdir + "/.config/atoll/rules.lua", 'return { 7, { app = "x", rule = "nope" }, { rule = { match = { class = "y" } } }, { app = "z", rule = { match = { class = "^(z)$" }, float = true } } }')
const broken = luaRun(boot + show)
assert.equal(broken.status, 0, broken.stderr); assert(broken.stdout.includes("KEYS z\n"), broken.stdout)
fs.writeFileSync(rdir + "/.config/atoll/rules.lua", "return {{{")
assert.equal(luaRun(boot + show).status, 0)
assert.equal(luaRun(boot + show, rdir + "/nobody").status, 0)
fs.rmSync(rdir, { recursive: true })
assert.deepEqual(js(R.openApps([{ class: "x", initialClass: "org.X", title: "A", mapped: true, size: [10, 20] }, { class: "org.X", initialClass: "org.X", mapped: true }, { class: "", mapped: true }, { class: "h", mapped: false }])), [{ class: "org.X", title: "A", size: [10, 20] }])

// Scripts take values from settings files, so they must refuse anything that could reach a path or a URL.
const script = (name, ...args) => spawnSync(new URL("../scripts/" + name, import.meta.url).pathname, args).status
assert.equal(script("holidays", "../x", "2026"), 2)
assert.equal(script("holidays", "BR", "20;26"), 2)
assert.equal(script("profiles", "delete", "../settings"), 2)
assert.equal(script("profiles", "create", "A B", "default", "x"), 2)

const pp = P.powerProfiles("  performance:\n    CpuDriver: intel_pstate\n    Degraded: no\n\n* balanced:\n    CpuDriver: intel_pstate\n\n  power-saver:\n    Degraded: no\n")
assert.deepEqual(Array.from(pp.names), ["power-saver", "balanced", "performance"]); assert.equal(pp.active, "balanced")
assert.equal(P.powerProfiles("").names.length, 0)
assert.ok(P.inWindow("23:00", "20:00", "07:00") && P.inWindow("03:00", "20:00", "07:00"))
assert.ok(!P.inWindow("07:00", "20:00", "07:00") && !P.inWindow("12:00", "20:00", "07:00"))
assert.ok(P.inWindow("09:00", "08:00", "17:00") && !P.inWindow("17:00", "08:00", "17:00"))
assert.ok(!P.inWindow("08:00", "08:00", "08:00"))
assert.deepEqual(JSON.parse(JSON.stringify(P.nmcliRows("Home\\: VPN:abc:wireguard:yes\nback\\\\slash:def:vpn:no\n"))), [["Home: VPN", "abc", "wireguard", "yes"], ["back\\slash", "def", "vpn", "no"]])
// Theme sets: the same keys in both, and text that reads on the glass (WCAG 4.5:1), over the plain
// background and over black, the darkest a wallpaper can make the blurred glass.
const T = load("theme.js", "dark,light")
assert.deepEqual(Object.keys(T.dark).sort(), Object.keys(T.light).sort())
assert.deepEqual(Object.keys(T.dark.accents).sort(), Object.keys(T.light.accents).sort())
const rgba = hex => { const h = hex.slice(1), a = h.length === 8 ? parseInt(h.slice(0, 2), 16) / 255 : 1; return [0, 2, 4].map(i => parseInt(h.slice(-6).slice(i, i + 2), 16)).concat(a) }
const over = (top, under) => top.slice(0, 3).map((c, i) => c * top[3] + under[i] * (1 - top[3])).concat(1)
const luminance = c => c.slice(0, 3).map(v => (v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4).reduce((s, v, i) => s + v * [0.2126, 0.7152, 0.0722][i], 0)
const contrast = (a, b) => { const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x); return (hi + 0.05) / (lo + 0.05) }
for (const [name, set] of Object.entries({ dark: T.dark, light: T.light })) {
    for (const [key, value] of Object.entries(set)) if (key !== "accents" && key !== "inactiveBorder") assert.match(value, /^#([0-9A-F]{6}|[0-9A-F]{8})$/, `${name}.${key}`)
    for (const back of [rgba(set.ground), [0, 0, 0, 1]]) {
        const glass = over(rgba(set.surface), back)
        for (const key of ["ink", "muted", "danger", "holiday", "good", "warn"]) {
            const r = contrast(rgba(set[key]), glass); assert(r >= 4.5, `${name}.${key} on glass: ${r.toFixed(2)}`)
        }
        assert(contrast(rgba(set.ink), over(rgba(set.glassStrong), back)) >= 4.5, `${name}.ink on glassStrong`)
        assert(contrast(rgba(set.ink), over(rgba(set.scrim), back)) >= 4.5, `${name}.ink on scrim`)
    }
    for (const [key, hex] of Object.entries(set.accents)) {
        assert(contrast(rgba(hex), over(rgba(set.surface), rgba(set.ground))) >= 4.5, `${name} accent ${key} on glass`)
        assert(contrast(rgba(set.accentInk), rgba(hex)) >= 4.5, `${name} text on accent ${key}`)
    }
    assert(contrast(rgba(set.accentInk), rgba(set.danger)) >= 4.5, `${name} text on danger`)
}
const O = load("overview.js", "spread")
const plain = v => JSON.parse(JSON.stringify(v))
// Tiled windows keep their arrangement, centered at the scale that fits.
assert.deepEqual(plain(O.spread([{ x: 0, y: 0, w: 50, h: 100 }, { x: 50, y: 0, w: 50, h: 100 }], 100, 100, 200, 100, 10)),
    [{ x: 50, y: 0, w: 50, h: 100 }, { x: 100, y: 0, w: 50, h: 100 }])
// Overlapping windows never overlap afterwards, and stay inside the area.
const full = { x: 0, y: 0, w: 1920, h: 1080 }
for (const n of [2, 3, 5, 7]) {
    const r = O.spread(Array(n).fill(full), 1920, 1080, 1200, 800, 16)
    assert.equal(r.length, n)
    r.forEach((a, i) => {
        assert.ok(a.x >= -0.01 && a.y >= -0.01 && a.x + a.w <= 1200.01 && a.y + a.h <= 800.01)
        r.slice(i + 1).forEach(b => assert.ok(a.x + a.w <= b.x + 0.01 || b.x + b.w <= a.x + 0.01 || a.y + a.h <= b.y + 0.01 || b.y + b.h <= a.y + 0.01))
    })
}
assert.equal(O.spread([], 100, 100, 100, 100, 10).length, 0)
assert.equal(P.modelName("LENOVO", "82AB", "Lenovo IdeaPad 5 14"), "Lenovo IdeaPad 5 14")
assert.equal(P.modelName("Dell Inc.", "XPS 13 9310", ""), "Dell XPS 13 9310")
assert.equal(P.modelName("ASUSTeK COMPUTER INC.", "ROG Strix G15", "1.0"), "ASUSTeK COMPUTER ROG Strix G15")
assert.equal(P.modelName("System manufacturer", "System Product Name", "System Version"), "System manufacturer")
assert.equal(P.modelName("HP", "HP Pavilion Laptop 15-eg0xxx", "Type1ProductConfigId"), "HP Pavilion Laptop 15-eg0xxx")
assert.equal(P.chassisKind("10"), "laptop"); assert.equal(P.chassisKind("3"), "desktop"); assert.equal(P.chassisKind(""), "")
assert.equal(P.cpuName("13th Gen Intel(R) Core(TM) i5-13420H"), "Intel Core i5-13420H")
assert.equal(P.cpuName("AMD Ryzen 7 5800H with Radeon Graphics"), "AMD Ryzen 7 5800H")
assert.equal(P.cpuName("Intel(R) Core(TM) i7-8650U CPU @ 1.90GHz"), "Intel Core i7-8650U")
assert.deepEqual([P.duration(720), P.duration(12000), P.duration(190000)], ["12 min", "3 h 20 min", "2 d 4 h"])
// The control center's search: screens and what is inside them, accents ignored, best match first.
const F = (() => {
    const ctx = { P }; vm.createContext(ctx)
    vm.runInContext(fs.readFileSync(new URL("../shell/finder.js", import.meta.url), "utf8").replace(".pragma library", "").replace(/^\.import .*$/m, "") + ";this.x={search,items,labelsFrom}", ctx)
    return ctx.x
})()
const pagesForTest = [{ id: "ajustes", label: "Ajustes", icon: "ajustes", key: "Alt+J", kw: "settings" }, { id: "energia", label: "Energia", icon: "energia", key: "Alt+E", kw: "power" }]
const trPt = k => ({ "Night light": "Luz noturna", "Language": "Idioma", "Shut down": "Desligar", "Suspend": "Suspender" })[k] ?? k
assert.deepEqual(F.search(pagesForTest, "", trPt).length, 0)
assert.deepEqual(F.search(pagesForTest, "luz", trPt).map(r => r.label), ["Luz noturna"])
assert.deepEqual(F.search(pagesForTest, "ENER", trPt)[0], { page: "energia", label: "Energia", icon: "energia", key: "Alt+E", item: false, rank: 0 })
assert.ok(F.search(pagesForTest, "noturna", trPt).some(r => r.item && r.page === "ajustes")) // a word inside the label
assert.ok(F.search(pagesForTest, "night", trPt).some(r => r.label === "Luz noturna")) // the English key still finds it
{
    // Labels read from the screens' files: buttons are found, sentences and placeholders are not.
    const grep = ['PgMonitor.qml:Tr.t("Extend")', 'PgMonitor.qml:Tr.t("Extend")', 'PgMonitor.qml:Tr.t("Screens: %1")', 'PgMonitor.qml:Tr.t("Drag the screens to position them.")', 'Other.qml:Tr.t("Nope")'].join("\n")
    const got = F.labelsFrom(grep, { monitor: "PgMonitor.qml" })
    assert.deepEqual(JSON.parse(JSON.stringify(got)), { monitor: ["Extend"] })
    const tr = k => ({ Extend: "Estender" })[k] ?? k
    const hits = F.search([{ id: "monitor", label: "Monitor", icon: "monitor", key: "Alt+M", kw: "" }], "estender", tr, got)
    assert.deepEqual(hits.map(h => h.label + "@" + h.page), ["Estender@monitor"])
    // Every screen file holds some labels, so the real grep output feeds the search.
    const real = spawnSync("sh", ["-c", 'cd "$1" && grep -oH "Tr\\.t(\\"[^\\"]*\\")" Pg*.qml', "sh", new URL("../shell/", import.meta.url).pathname], { encoding: "utf8" }).stdout
    const all = F.labelsFrom(real, { monitor: "PgMonitor.qml", ajustes: "PgSettings.qml" })
    assert.ok(all.monitor.includes("Extend") && all.ajustes.includes("Pointer speed"))
}
assert.ok(Object.keys(F.items).every(id => ["som", "rede", "bt", "perf", "cal", "avisos", "monitor", "ajustes", "visual", "atalhos", "apps", "regras", "backup", "energia", "sobre"].includes(id)))
const kb = P.zipLayouts("br,us", "abnt2,")
assert.deepEqual(JSON.parse(JSON.stringify(kb)), [{ layout: "br", variant: "abnt2" }, { layout: "us", variant: "" }])
assert.deepEqual(JSON.parse(JSON.stringify(P.joinLayouts(kb))), { layout: "br,us", variant: "abnt2," })
assert.equal(P.zipLayouts("us", "").length, 1)
const xkb = P.xkbCatalog("! model\n  pc105  Generic\n\n! layout\n  us   English (US)\n  br   Portuguese (Brazil)\n\n! variant\n  intl   us: English (US, intl.)\n\n! option\n  grp   Switching\n")
assert.deepEqual(xkb.map(x => x.layout + ":" + x.variant).sort(), ["br:", "us:", "us:intl"])
// Saving the same picture twice keeps one copy, and listing shows it.
const home = fs.mkdtempSync("/tmp/atoll-test-")
const profiles = (...args) => spawnSync(new URL("../scripts/profiles", import.meta.url).pathname, args, { env: { ...process.env, HOME: home }, encoding: "utf8" })
fs.writeFileSync(home + "/a.png", "one"); fs.writeFileSync(home + "/b.png", "two")
const first = profiles("photo", home + "/a.png").stdout.trim()
assert.equal(profiles("photo", home + "/a.png").stdout.trim(), first)
assert.notEqual(profiles("photo", home + "/b.png").stdout.trim(), first)
assert.equal(profiles("photos").stdout.trim().split("\n").length, 2)
assert.equal(profiles("photo", home + "/missing.png").status, 1)
// Wallpapers keep their own gallery, the same way.
const wall = profiles("wallpaper", home + "/a.png").stdout.trim()
assert.equal(profiles("wallpaper", home + "/a.png").stdout.trim(), wall)
assert.notEqual(wall, first)
assert.deepEqual(profiles("wallpapers").stdout.trim().split("\n"), [wall])
assert.equal(profiles("wallpaper", home + "/missing.png").status, 1)
// Forgetting deletes only gallery files, and profiles using the image let go of it.
fs.mkdirSync(home + "/.config/atoll/profiles", { recursive: true })
fs.writeFileSync(home + "/.config/atoll/profiles/a.json", JSON.stringify({ wallpaper: wall, photo: first }))
assert.equal(profiles("forget", "wallpaper", home + "/a.png").status, 1)
assert.ok(fs.existsSync(home + "/a.png"))
assert.equal(profiles("forget", "photo", wall).status, 1)
assert.equal(profiles("forget", "wallpaper", wall).status, 0)
assert.equal(profiles("wallpapers").stdout.trim(), "")
assert.deepEqual(JSON.parse(fs.readFileSync(home + "/.config/atoll/profiles/a.json")), { wallpaper: "", photo: first })
const wall2 = profiles("wallpaper", home + "/b.png").stdout.trim()
fs.writeFileSync(home + "/.config/atoll/profiles/a.json", JSON.stringify({ wallpaper: "", wallpapers: { "DP-1": wall2, "DP-2": "/keep" } }))
assert.equal(profiles("forget", "wallpaper", wall2).status, 0)
assert.deepEqual(JSON.parse(fs.readFileSync(home + "/.config/atoll/profiles/a.json")).wallpapers, { "DP-2": "/keep" })
fs.rmSync(home, { recursive: true })

// Settings and restored notifications, on the real QML in a throwaway offscreen instance with its own HOME and D-Bus session.
const haveQs = ["qs", "dbus-run-session", "notify-send"].every(tool => spawnSync("sh", ["-c", `command -v ${tool}`]).status === 0)
const runQml = (dir, shellQml, files = {}) => {
    fs.writeFileSync(dir + "/shell.qml", shellQml)
    for (const [name, text] of Object.entries(files)) fs.writeFileSync(dir + "/" + name, text)
    const { WAYLAND_DISPLAY, DISPLAY, HYPRLAND_INSTANCE_SIGNATURE, ...env } = process.env
    const run = spawnSync("dbus-run-session", ["--", "qs", "-p", dir + "/shell.qml"], { encoding: "utf8", timeout: 30000, env: { ...env, LANG: "C.UTF-8", LC_ALL: "C.UTF-8", LANGUAGE: "en", QT_QPA_PLATFORM: "offscreen", HOME: dir + "/home", XDG_DATA_HOME: dir + "/home/share", XDG_CONFIG_HOME: dir + "/home/config", XDG_STATE_HOME: dir + "/home/state", XDG_DATA_DIRS: dir + "/data" } })
    return Object.fromEntries([...(run.stdout + run.stderr).matchAll(/RESULT (\w+) (.*)/g)].map(m => [m[1], JSON.parse(m[2])]))
}
if (haveQs) {
    // A key the file lacks gets its default, not the previous profile's value, and what the file has is kept.
    const dir = fs.mkdtempSync("/tmp/atoll-test-")
    fs.cpSync(new URL("../shell/Cfg.qml", import.meta.url), dir + "/Cfg.qml")
    fs.writeFileSync(dir + "/a.json", JSON.stringify({ accent: "rosa", lockAc: 9, dnd: true, dock: [{ label: "X" }] }))
    fs.writeFileSync(dir + "/b.json", JSON.stringify({ accent: "verde", wallpapers: { "DP-1": "/w" }, dnd: false }))
    fs.writeFileSync(dir + "/d.json", "{oops")
    const out = runQml(dir, `import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    property int step: 0
    property int writes: 0
    property var early: Cfg.v // singletons start when first used
    FileView { path: "${dir}/b.json"; watchChanges: true; onFileChanged: { writes++; reload() } }
    function show(tag) { console.log("RESULT " + tag + " " + JSON.stringify({ accent: Cfg.v.accent, lockAc: Cfg.v.lockAc, dnd: Cfg.v.dnd, docks: Cfg.v.dock.length, wallpapers: Cfg.v.wallpapers })) }
    Timer {
        running: true; repeat: true; interval: 400
        onTriggered: {
            step++
            if (step === 1) { show("a"); Profiles.path = "${dir}/b.json" }
            if (step === 2) { show("b"); Profiles.path = "${dir}/c.json" }
            if (step === 3) { show("c"); Profiles.path = "${dir}/d.json" }
            if (step === 4) { show("d"); Profiles.path = "${dir}/b.json" }
            if (step === 5) { show("back"); Cfg.v.nightK = 3000 }
            if (step === 7) { console.log("RESULT writes " + writes); Qt.quit() }
        }
    }
}
`, { "Profiles.qml": `pragma Singleton\nimport Quickshell\nSingleton { property string path: "${dir}/a.json" }\n` })
    const file = name => JSON.parse(fs.readFileSync(`${dir}/${name}.json`))
    assert.deepEqual(out.a, { accent: "rosa", lockAc: 9, dnd: true, docks: 1, wallpapers: {} })
    assert.deepEqual(out.b, { accent: "verde", lockAc: 5, dnd: false, docks: 6, wallpapers: { "DP-1": "/w" } })
    assert.deepEqual(out.c, { accent: "gelo", lockAc: 5, dnd: false, docks: 6, wallpapers: {} }) // no file at all
    assert.deepEqual(out.d, out.c) // a broken file
    assert.deepEqual(out.back, out.b)
    assert.equal(file("a").lockAc, 9)
    assert.equal(file("b").lockAc, 5); assert.equal(file("b").dock.length, 6); assert.equal(file("b").accent, "verde")
    assert.equal(file("b").nightK, 3000); assert.equal(file("c").accent, "gelo")
    assert(out.writes <= 4, `settings file written ${out.writes} times`) // no loop between the write and the reload it causes
    fs.rmSync(dir, { recursive: true })

    // "Open app" appears only on restored cards with an app to open, and old history files still load.
    const root = fs.mkdtempSync("/tmp/atoll-test-")
    fs.cpSync(new URL("../shell/", import.meta.url), root, { recursive: true })
    const state = root + "/home/.local/state/atoll"
    fs.mkdirSync(state, { recursive: true }); fs.mkdirSync(root + "/data/applications", { recursive: true })
    const entry = (id, hidden) => fs.writeFileSync(`${root}/data/applications/${id}.desktop`, `[Desktop Entry]\nType=Application\nName=${id}\nExec=touch ${root}/launched-${id}\nNoDisplay=${hidden}\n`)
    entry("fake-app", false); entry("hidden-app", true)
    const saved = (summary, appName, desktopEntry) => ({ id: 1, time: 1, appName, summary, body: "", image: "", appIcon: "", urgency: 1, ...(desktopEntry ? { desktopEntry } : {}) })
    fs.writeFileSync(state + "/notifications.json", JSON.stringify([saved("old", "fake-app"), saved("new", "other", "fake-app"), saved("none", "nothing-like-this"), saved("hidden", "nothing-like-this", "hidden-app")]))
    const cards = runQml(root, `import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    property int step: 0
    Item { Repeater { id: rep; model: step > 0 ? Notifs.all : []; NotifCard { } } }
    function button(item) {
        for (const c of item.children) {
            if (c.text === "Open app") return c
            const inner = button(c)
            if (inner) return inner
        }
        return null
    }
    Process { id: send; command: ["notify-send", "-a", "fake-app", "-h", "string:desktop-entry:fake-app", "-A", "go=Go", "-t", "0", "live"] }
    Timer {
        running: true; repeat: true; interval: 500
        onTriggered: {
            step++
            if (step === 1) send.running = true
            if (step === 4) {
                const shown = {}
                for (let i = 0; i < rep.count; i++) shown[rep.itemAt(i).modelData.summary] = { button: button(rep.itemAt(i)).visible, actions: rep.itemAt(i).modelData.actions.length }
                console.log("RESULT cards " + JSON.stringify(shown))
                button(rep.itemAt(0)).clicked()
                console.log("RESULT kept " + Notifs.all.length)
            }
            if (step === 7) Qt.quit()
        }
    }
}
`, { "Ui.qml": `pragma Singleton\nimport Quickshell\nSingleton { property bool open: true; property bool mediaOpen: false; property var sheetScreen; property var screen }\n` })
    assert.deepEqual(cards.cards, {
        old: { button: true, actions: 0 }, new: { button: true, actions: 0 }, none: { button: false, actions: 0 }, hidden: { button: false, actions: 0 },
        live: { button: false, actions: 1 }
    })
    assert.equal(cards.kept, 5)
    assert(fs.existsSync(root + "/launched-fake-app"))
    const history = JSON.parse(fs.readFileSync(state + "/notifications.json"))
    assert.equal(history.find(n => n.summary === "live").desktopEntry, "fake-app")
    fs.rmSync(root, { recursive: true })

    // Clipboard panel, against a throwaway cliphist database: the default one is the user's real history.
    const realCliphist = spawnSync("sh", ["-c", "command -v cliphist"], { encoding: "utf8" }).stdout.trim()
    if (realCliphist) {
        const cb = fs.mkdtempSync("/tmp/atoll-test-"), bin = cb + "/bin", db = cb + "/db"
        fs.cpSync(new URL("../shell/", import.meta.url), cb, { recursive: true })
        fs.mkdirSync(bin); fs.mkdirSync(cb + "/run", { mode: 0o700 })
        const store = input => assert.equal(spawnSync(realCliphist, ["-db-path", db, "-config-path", cb + "/none", "store"], { input }).status, 0)
        const png = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", "base64")
        store("hello world"); store("https://example.com/a"); store("#8CC8F5"); store(png); store("it's $(touch " + cb + "/pwned) `x`")
        fs.writeFileSync(bin + "/cliphist", `#!/bin/sh\nexec '${realCliphist}' -db-path '${db}' -config-path '${cb}/none' "$@"\n`, { mode: 0o755 })
        fs.writeFileSync(bin + "/wl-copy", `#!/bin/sh\nprintf '%s\\n' "$*" > '${cb}/copied-args'\ncat > '${cb}/copied'\n`, { mode: 0o755 })
        // No layer shell offscreen: a plain window stands in, and the loaded window is exposed to the test.
        const qml = fs.readFileSync(cb + "/Clipboard.qml", "utf8")
            .replace("PanelWindow {", "FloatingWindow { implicitWidth: 1600; implicitHeight: 1000")
            .replace("    LazyLoader {", "    readonly property var win: loader.item\n    LazyLoader {\n    id: loader")
            .split("\n").filter(l => !/^\s*(anchors \{ top|exclusionMode|WlrLayershell)/.test(l)).join("\n")
        fs.writeFileSync(cb + "/Clipboard.qml", qml)
        const env = { PATH: process.env.PATH, XDG_RUNTIME_DIR: process.env.XDG_RUNTIME_DIR }
        Object.assign(process.env, { PATH: bin + ":" + process.env.PATH, XDG_RUNTIME_DIR: cb + "/run" })
        const clip = runQml(cb, `import QtQuick
import Quickshell
ShellRoot {
    Clipboard { id: clip }
    property int step: 0
    readonly property var win: clip.win
    function rows() { return win.rows.map(r => r.kind + (r.pinned ? "*" : "") + " " + r.preview) }
    function say(tag, v) { console.log("RESULT " + tag + " " + JSON.stringify(v)) }
    Timer {
        running: true; repeat: true; interval: 500
        onTriggered: {
            step++
            if (step === 2) { say("open", { rows: rows(), meta: win.meta(win.rows[1]), tmp: win.tmp }); win.sel = 1 }
            if (step === 3) { say("image", win.shownImage); win.sel = 0 }
            if (step === 4) { say("full", win.full); win.pin(win.rows[0]) }
            if (step === 5) win.pin(win.rows.find(r => r.kind === "image"))
            if (step === 6) {
                say("pinned", rows())
                win.chip = "image"; say("images", rows()); win.chip = "all"
                win.remove(win.rows.find(r => r.kind === "link"))
            }
            if (step === 7) { say("removed", rows()); win.wipe(); win.wipe() }
            if (step === 8) { say("wiped", rows()); win.copy(win.rows.find(r => r.kind === "image")) }
            if (step === 10) Ui.clipboard = true
            if (step === 11) { say("reopened", rows()); win.unpin(win.rows[0]); win.remove(win.rows[0]); say("unpinned", rows()); Ui.clipboard = false }
            if (step === 13) Qt.quit()
        }
    }
}
`, { "Ui.qml": `pragma Singleton\nimport Quickshell\nSingleton { property bool clipboard: true; readonly property var screen: Quickshell.screens[0] ?? null }\n` })
        Object.assign(process.env, env)
        const evil = "it's $(touch " + cb + "/pwned) `x`"
        assert.deepEqual(clip.open.rows, ["text " + evil, "image [[ binary data 70 B png 1x1 ]]", "color #8CC8F5", "link https://example.com/a", "text hello world"])
        assert.equal(clip.open.meta, "Image · PNG · 70 B · 1×1")
        assert.equal(clip.image, "file://" + clip.open.tmp + "/0-4.png")
        assert.equal(clip.full, evil)
        assert.deepEqual(clip.pinned.slice(0, 2), ["image* [[ binary data 70 B png 1x1 ]]", "text* " + evil])
        assert.deepEqual(clip.images, ["image* [[ binary data 70 B png 1x1 ]]"])
        assert(!clip.removed.some(r => r.startsWith("link")))
        assert.deepEqual(clip.wiped, clip.pinned.slice(0, 2)) // pins outlive the history
        assert.deepEqual(clip.reopened, clip.wiped) // and a new window
        assert.deepEqual(clip.unpinned, [])
        assert.equal(fs.readFileSync(cb + "/copied-args", "utf8"), "--type image/png\n")
        assert(fs.readFileSync(cb + "/copied").equals(png))
        const pins = cb + "/home/.local/state/atoll"
        assert.equal(fs.statSync(pins).mode & 0o777, 0o700); assert.equal(fs.statSync(pins + "/pins").mode & 0o777, 0o700)
        assert.deepEqual(fs.readdirSync(pins + "/pins"), []); assert.equal(fs.readFileSync(pins + "/clipboard-pins.json", "utf8"), "[]")
        assert(!fs.existsSync(clip.open.tmp)) // decoded images go with the window
        assert(!fs.existsSync(cb + "/pwned"))
        fs.rmSync(cb, { recursive: true })
    } else console.log("skipped the clipboard check: it needs cliphist")
} else console.log("skipped the QML checks: they need qs, dbus-run-session and notify-send")
// Certificate Wi-Fi, against a stand-in nmcli: the real one is the machine's live network.
const nm = fs.mkdtempSync("/tmp/atoll-test-")
fs.writeFileSync(nm + "/nmcli", `#!/usr/bin/env bash
echo "ARGV $*" >>"$NM_LOG"
case "$*" in
    *"connection add"*) echo "Connection (00000000-0000-0000-0000-000000000001) successfully added." ;;
    *"connection edit"*) cat >>"$NM_LOG"; echo "\${NM_SAY:-}" ;;
esac
`, { mode: 0o755 })
fs.mkdirSync(nm + "/my dir")
for (const f of ["c.pem", "k.pem", "my dir/k.pem", "ca.pem"]) fs.writeFileSync(nm + "/" + f, "x")
const log = nm + "/log"
const tls = (args, input, say = "") => {
    fs.writeFileSync(log, "")
    const r = spawnSync(new URL("../scripts/net", import.meta.url).pathname, ["wifi-eap", "Net", "no", "tls", ...args], { input, cwd: nm, encoding: "utf8", env: { ...process.env, PATH: nm + ":" + process.env.PATH, NM_LOG: log, NM_SAY: say } })
    return { status: r.status, out: r.stdout.trim(), log: fs.readFileSync(log, "utf8") }
}
const [cc, kk, ca] = [nm + "/c.pem", nm + "/k.pem", nm + "/ca.pem"]
// Bad input never reaches nmcli, so no profile is left behind.
for (const args of [["me", nm + "/none.pem", kk], ["me", cc, nm], ["me", cc, kk, nm + "/none.pem"], ["", cc, kk], ["a\nsave", cc, kk], ["me", cc, kk, "", "a\nsave"]]) {
    const r = tls(args, "pw\n")
    assert.equal(r.status, 2, args.join()); assert.equal(r.log, "")
}
for (const input of ["   \n", " pw\n", "pw \n"]) { const r = tls(["me", cc, kk], input); assert.equal(r.status, 2); assert.equal(r.log, "") }
const saved = tls(["me", "c.pem", "my dir/k.pem", "", "corp.example"], "s3 cr#t\n")
assert.equal(saved.status, 0); assert.equal(saved.out, "00000000-0000-0000-0000-000000000001")
assert(!saved.log.split("\n").some(l => l.startsWith("ARGV") && l.includes("s3 cr#t"))) // never on the command line
const lines = saved.log.split("\n")
for (const l of ["set 802-1x.eap tls", "set 802-1x.identity me", `set 802-1x.client-cert ${cc}`, "set 802-1x.private-key-password s3 cr#t", "set 802-1x.system-ca-certs yes", "set 802-1x.domain-suffix-match corp.example"]) assert(lines.includes(l), l)
assert(lines.includes(`set 802-1x.private-key ${nm}/my\\ dir/k.pem`))
assert(lines.indexOf("set 802-1x.private-key-password s3 cr#t") > lines.findIndex(l => l.startsWith("set 802-1x.private-key "))) // setting the key clears its password
const own = tls(["me", cc, kk, ca], "\n").log
assert(own.includes(`set 802-1x.ca-cert ${ca}\n`)); assert(!own.includes("system-ca-certs"))
assert(!own.includes("private-key-password")) // empty, the editor would ask and take the next command as the answer
assert(!own.includes("domain-suffix-match"))
assert(!tls(["me", cc, kk], "").log.includes("ca-cert")) // no stdin at all still works, and nothing is checked
// nmcli's editor exits 0 after rejecting a value, so the half-made profile goes because of what it said.
const bad = tls(["me", cc, kk, ca], "\n", "Error: failed to set 'ca-cert' property")
assert.equal(bad.status, 1); assert.equal(bad.out, ""); assert(bad.log.includes("ARGV connection delete uuid 00000000-0000-0000-0000-000000000001"))
fs.rmSync(nm, { recursive: true })

// Every string the interface asks for must exist in every language, with the same placeholders.
const shell = new URL("../shell/", import.meta.url)
const used = new Set()
for (const file of fs.readdirSync(shell).filter(f => f.endsWith(".qml"))) {
    const code = fs.readFileSync(new URL(file, shell), "utf8")
    for (const m of code.matchAll(/Tr\.t\("((?:[^"\\]|\\.)+)"\)/g)) used.add(m[1])
    for (const m of code.matchAll(/Tr\.date\([^"]*"([^"]+)"\)/g)) used.add(m[1])
}
for (const label of ["Browser", "Code", "Files", "Terminal"]) used.add(label) // default dock labels in Cfg.qml
for (const m of fs.readFileSync(new URL("backup.js", shell), "utf8").matchAll(/\bt\("((?:[^"\\]|\\.)+)"\)|label: "([^"]+)"/g)) used.add(m[1] ?? m[2]) // the import review's labels
const placeholders = text => (text.match(/%\d/g) || []).sort().join()
for (const file of fs.readdirSync(new URL("i18n/", shell))) {
    const dict = JSON.parse(fs.readFileSync(new URL("i18n/" + file, shell), "utf8"))
    for (const key of used) assert(key in dict, `${file} is missing: ${key}`)
    for (const [key, value] of Object.entries(dict)) {
        assert.equal(placeholders(value), placeholders(key), `${file}: placeholders differ in: ${key}`)
        assert(value.trim(), `${file}: empty translation: ${key}`)
    }
}

// Clipboard: what a cliphist line is, and the filters.
const K = load("clip.js", "classify,parseList,filter")
const kinds = K.parseList("9\t[[ binary data 1.2 MiB png 3440x1440 ]]\n8\t #8CC8F5 \n7\thttps://a.example/x?y=1\n6\tmailto:a@b.c\n5\tsee https://a.example\n4\t#12345\n3\t#abc\n2\t[[ binary data 3 KiB ]]\n\nnot a line\n")
assert.deepEqual(kinds.map(k => k.id + k.kind), ["9image", "8color", "7link", "6link", "5text", "4text", "3color", "2text"])
assert.deepEqual(plain(kinds[0]), { id: "9", preview: "[[ binary data 1.2 MiB png 3440x1440 ]]", kind: "image", size: "1.2 MiB", fmt: "png", w: 3440, h: 1440 })
assert.equal(kinds[1].color, "#8CC8F5")
assert.deepEqual(K.parseList("1\ta\tb").map(k => k.preview), ["a\tb"])
const pool = kinds.concat([{ id: "1", preview: "Pinned NOTE", kind: "text", pinned: true }])
const ids = (q, chip) => K.filter(pool, q, chip).map(k => k.id).join()
assert.equal(ids("", "all"), "9,8,7,6,5,4,3,2,1"); assert.equal(ids("", "text"), "8,5,4,3,2,1"); assert.equal(ids("", "link"), "7,6")
assert.equal(ids("", "image"), "9"); assert.equal(ids("", "pinned"), "1"); assert.equal(ids("  note ", "all"), "1"); assert.equal(ids("example", "text"), "5")

// Emoji search: localized names and keywords, accents ignored, ranked, English as the fallback.
const E = load("parse.js", "fold,emojiEntries,emojiSearch")
assert.equal(E.fold("Coração"), "coracao"); assert.equal(E.fold("CŒUR"), "coeur"); assert.equal(E.fold("Fuß"), "fuss"); assert.equal(E.fold("Ёлка"), "елка")
const glyphs = (entries, q) => E.emojiSearch(entries, q).map(e => e.glyph).join(" ")
const toy = E.emojiEntries("🅰 pie\n🅱 rocket\n🆎 crab\n🆑 plain\n🆒 fruit\n", "🅰\ttorta\tmaca|doce\n🅱\tfoguete\tespaco\n🆎\tcaranguejo maçã\t\n🆒\tMaçã verde\t\n")
assert.equal(glyphs(toy, "MAÇA"), "🆒 🆎 🅰") // name start, then name, then keyword
assert.equal(glyphs(toy, "rocket"), "🅱") // English still finds it...
assert.equal(toy.find(e => e.glyph === "🅱").label, "foguete") // ...under the localized name
assert.equal(toy.find(e => e.glyph === "🆑").label, "plain") // no annotation: the English name
assert.equal(glyphs(toy, "plain"), "🆑"); assert.equal(glyphs(toy, "nada"), "")
assert.equal(E.emojiEntries("🅰 pie\n", "").length, 1) // the language file failed to load
const read = file => fs.readFileSync(new URL(file, shell), "utf8")
const english = read("emoji.txt"), known = new Set(english.split("\n").map(l => l.split(" ")[0]))
for (const lang of ["en", "pt", "es", "fr", "de", "ru", "zh"]) {
    for (const row of read(`emoji/${lang}.txt`).split("\n").filter(Boolean)) {
        const f = row.split("\t")
        assert.equal(f.length, 3, `${lang}: ${row}`); assert(known.has(f[0]), `${lang}: not in emoji.txt: ${row}`)
        assert.equal(E.fold(f[2]), f[2], `${lang}: keywords must be folded: ${row}`) // they are not folded when loaded
    }
}
const real = lang => E.emojiEntries(english, read(`emoji/${lang}.txt`))
const pt = real("pt"), best = (entries, q) => E.emojiSearch(entries, q)[0]
assert.equal(best(pt, "foguete").glyph, "🚀"); assert.equal(best(pt, "foguete").label, "foguete")
assert.equal(best(pt, "rocket").label, "foguete")
assert(E.emojiSearch(pt, "coracao").some(e => e.label === "coração vermelho"))
assert.equal(pt.find(e => e.glyph === "🌢").label, "black droplet") // CLDR has no annotation for it
for (const [lang, q] of [["en", "rocket"], ["es", "cohete"], ["fr", "fusee"], ["de", "RAKETE"], ["ru", "ракета"], ["zh", "火箭"]]) assert.equal(best(real(lang), q).glyph, "🚀", `${lang}: ${q}`)

// Default apps: what open-app --state says, the candidates per role, and when Atoll and the system disagree.
const A = load("apps.js", "roles,allTypes,parseState,current,candidates,mismatch")
const role = id => A.roles.find(r => r.id === id)
const st = A.parseState("atoll\tbrowser\tchromium\natoll\ttext\tcode\ndefault\tx-scheme-handler/https\tfirefox.desktop\ndefault\tx-scheme-handler/http\tchromium.desktop\ndefault\ttext/html\t\ndefault\ttext/plain\tcode.desktop\ndefault\timage/png\tloupe.desktop\nentry\tloupe\timage/png;image/gif;\nentry\tloupe\ttext/plain;\nbroken line\n")
assert.deepEqual(plain(st.mimes), { loupe: ["image/png", "image/gif"] }) // the first file of an id wins
assert.equal(st.defaults["text/html"], "")
assert.deepEqual([A.current(role("browser"), st), A.current(role("images"), st), A.current(role("terminal"), st), A.current(role("email"), st)], ["chromium", "loupe", "kitty", ""])
assert.deepEqual(plain(A.mismatch(role("browser"), st)), { app: "firefox", all: false })
assert.equal(A.mismatch(role("text"), st), null); assert.equal(A.mismatch(role("images"), st), null) // agrees; no choice of Atoll's
assert.equal(A.mismatch(role("terminal"), { ...st, atoll: { terminal: "foot" } }), null) // no system side at all
assert.equal(A.mismatch(role("text"), { ...st, defaults: { "text/plain": "gedit" } }).all, true)
const apps = [{ id: "loupe", name: "Loupe", categories: ["Graphics"] }, { id: "foot", name: "Foot", categories: ["System", "TerminalEmulator"] },
    { id: "secret", name: "Secret", categories: ["TerminalEmulator"], noDisplay: true }, { id: "alacritty", name: "Alacritty", categories: ["TerminalEmulator"] }]
assert.deepEqual(A.candidates(role("terminal"), apps, st.mimes, []).map(e => e.id), ["alacritty", "foot"])
assert.deepEqual(A.candidates(role("terminal"), apps, st.mimes, ["secret"]).map(e => e.id), ["alacritty", "foot", "secret"])
assert.deepEqual(A.candidates(role("images"), apps, st.mimes, []).map(e => e.id), ["loupe"])
assert.equal(A.candidates(role("video"), apps, st.mimes, []).length, 0)
assert.equal(new Set(A.allTypes()).size, A.allTypes().length)

// open-app, with a fake HOME: never the real one, whose mimeapps.list is the user's.
const oa = fs.mkdtempSync("/tmp/atoll-test-")
fs.mkdirSync(oa + "/data/applications", { recursive: true })
const app = (id, more = "") => fs.writeFileSync(`${oa}/data/applications/${id}.desktop`, `[Desktop Entry]\nType=Application\nName=${id}\nExec=touch ${oa}/ran-${id} %U\n${more}`)
app("web-a", "MimeType=x-scheme-handler/http;x-scheme-handler/https;text/html;\n"); app("web-b", "MimeType=x-scheme-handler/https;\n"); app("term-a")
const { DE, KDE_SESSION_VERSION, GNOME_DESKTOP_SESSION_ID, XDG_CURRENT_DESKTOP, DESKTOP_SESSION, ...clean } = process.env
const openApp = (...args) => spawnSync(new URL("../scripts/open-app", import.meta.url).pathname, args, { encoding: "utf8", env: { ...clean, HOME: oa + "/home", XDG_CONFIG_HOME: oa + "/home/.config", XDG_DATA_HOME: oa + "/home/.local/share", XDG_DATA_DIRS: oa + "/data" } })
const ran = id => fs.existsSync(`${oa}/ran-${id}`)
const haveXdgMime = spawnSync("sh", ["-c", "command -v xdg-mime"]).status === 0
for (const args of [["nope"], ["--set", "nope", "web-a"], ["--set", "browser", "../web-a"], ["--set", "browser", "missing"], ["--set", "browser", "web-a", "not a type"]]) assert.equal(openApp(...args).status, 2, args.join())
assert(!fs.existsSync(oa + "/home/.config/atoll/apps.json")) // refused before writing anything
assert.equal(openApp("email").status, 1) // nothing chosen, no system default, no old command
if (haveXdgMime) {
    assert.equal(openApp("--set", "browser", "web-a", "x-scheme-handler/http", "x-scheme-handler/https", "text/html").status, 0)
    assert.equal(openApp("--set", "terminal", "term-a").status, 0)
    assert.deepEqual(JSON.parse(fs.readFileSync(oa + "/home/.config/atoll/apps.json")), { browser: "web-a", terminal: "term-a" })
    const s = A.parseState(openApp("--state", ...A.allTypes()).stdout)
    assert.deepEqual(plain(s.atoll), { browser: "web-a", terminal: "term-a" })
    assert.deepEqual([s.defaults["x-scheme-handler/http"], s.defaults["text/html"], s.defaults["text/plain"]], ["web-a", "web-a", ""])
    assert.deepEqual(plain(s.mimes), { "web-a": ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"], "web-b": ["x-scheme-handler/https"] })
    assert.equal(openApp("browser").status, 0); assert(ran("web-a"))
    assert.equal(openApp("terminal").status, 0); assert(ran("term-a"))
    // Atoll's choice uninstalled: the system default opens instead.
    fs.writeFileSync(oa + "/home/.config/atoll/apps.json", JSON.stringify({ browser: "gone" }))
    spawnSync("xdg-mime", ["default", "web-b.desktop", "x-scheme-handler/https"], { env: { ...clean, HOME: oa + "/home", XDG_CONFIG_HOME: oa + "/home/.config", XDG_DATA_DIRS: oa + "/data" } })
    assert.equal(openApp("browser").status, 0); assert(ran("web-b"))
    fs.writeFileSync(oa + "/home/.config/atoll/apps.json", "{oops")
    assert.equal(openApp("--set", "text", "web-b", "text/plain").status, 0)
    assert.deepEqual(JSON.parse(fs.readFileSync(oa + "/home/.config/atoll/apps.json")), { text: "web-b" })
} else console.log("skipped the open-app checks that need xdg-mime")
fs.rmSync(oa, { recursive: true })

// The Default apps page: a disagreement shows a warning, and picking an app fixes both sides in one click.
if (haveQs && haveXdgMime) {
    const root = fs.mkdtempSync("/tmp/atoll-test-")
    fs.cpSync(new URL("../shell/", import.meta.url), root, { recursive: true })
    fs.mkdirSync(root + "/data/applications", { recursive: true }); fs.mkdirSync(root + "/home/.local/share/atoll/scripts", { recursive: true }); fs.mkdirSync(root + "/home/config/atoll", { recursive: true })
    fs.cpSync(new URL("../scripts/open-app", import.meta.url), root + "/home/.local/share/atoll/scripts/open-app")
    const desk = (id, more) => fs.writeFileSync(`${root}/data/applications/${id}.desktop`, `[Desktop Entry]\nType=Application\nName=${id}\nExec=touch ${root}/ran-${id}\n${more}\n`) // xdg-mime skips defaults whose program it cannot find
    desk("web-a", "Categories=Network;WebBrowser;\nMimeType=x-scheme-handler/http;x-scheme-handler/https;text/html;"); desk("web-b", "MimeType=x-scheme-handler/https;")
    desk("term-a", "Categories=System;TerminalEmulator;"); desk("term-hidden", "Categories=TerminalEmulator;\nNoDisplay=true")
    fs.mkdirSync(root + "/home/.config/atoll", { recursive: true }); fs.writeFileSync(root + "/home/.config/atoll/apps.json", JSON.stringify({ browser: "web-a" }))
    const fake = { ...clean, HOME: root + "/home", XDG_CONFIG_HOME: root + "/home/config", XDG_DATA_DIRS: root + "/data" }
    spawnSync("xdg-mime", ["default", "web-b.desktop", "x-scheme-handler/https"], { env: fake })
    const page = runQml(root, `import QtQuick
import Quickshell
import "apps.js" as A
ShellRoot {
    property int step: 0
    FloatingWindow { implicitWidth: 1000; implicitHeight: 900; PgApps { id: pg; anchors.fill: parent } }
    function find(item, test) {
        for (const c of item.children) {
            if (c.visible && test(c)) return c
            const inner = find(c, test)
            if (inner) return inner
        }
        return null
    }
    function all(item, test, out) { for (const c of item.children) { if (c.visible && test(c)) out.push(c); all(c, test, out) } return out }
    function say(tag, v) { console.log("RESULT " + tag + " " + JSON.stringify(v)) }
    Timer {
        running: true; repeat: true; interval: 500
        onTriggered: {
            step++
            if (step === 4) {
                say("before", { warn: all(pg.contentItem, c => c.name === "alert" && c.visible, []).length, changes: all(pg.contentItem, c => c.text === "Change" && c.a11y !== undefined, []).length })
                all(pg.contentItem, c => c.text === "Change" && c.a11y !== undefined, [])[0].clicked()
            }
            if (step === 5) {
                say("cards", all(pg.contentItem, c => c.chosen !== undefined && c.modelData, []).map(c => c.modelData.id + (c.chosen ? "*" : "") + (c.system ? "+" : "")))
                pg.choose(A.roles.find(r => r.id === "browser"), "web-a")
            }
            if (step === 9) {
                say("after", { warn: all(pg.contentItem, c => c.name === "alert" && c.visible, []).length, open: pg.openRole })
                const term = all(pg.contentItem, c => c.text === "Change" && c.a11y !== undefined, [])[1]
                term.clicked()
            }
            if (step === 10) { say("terms", all(pg.contentItem, c => c.chosen !== undefined && c.modelData, []).map(c => c.modelData.id)); Qt.quit() }
        }
    }
}
`, { "Ui.qml": `pragma Singleton\nimport Quickshell\nSingleton { property bool open: true; property var screen }\n` })
    assert.deepEqual(page.before, { warn: 1, changes: 8 })
    assert.deepEqual(page.cards, ["web-a", "web-b+"]) // Atoll says web-a, the system web-b: neither is checked until they agree
    assert.deepEqual(page.after, { warn: 0, open: "" })
    assert.deepEqual(page.terms, ["term-a"]) // the second Change, after the browser's, is the terminal's; hidden apps stay out
    assert.equal(spawnSync("xdg-mime", ["query", "default", "x-scheme-handler/https"], { env: fake, encoding: "utf8" }).stdout.trim(), "web-a.desktop")
    assert.deepEqual(JSON.parse(fs.readFileSync(root + "/home/.config/atoll/apps.json")), { browser: "web-a" })
    fs.rmSync(root, { recursive: true })
}

// Backup: export, then import on "another computer", each with its own throwaway HOME.
{
    const root = fs.mkdtempSync("/tmp/atoll-test-")
    const run = (home, name, ...args) => spawnSync(new URL("../scripts/" + name, import.meta.url).pathname, args, { env: { ...process.env, HOME: home }, encoding: "utf8" })
    const json = path => JSON.parse(fs.readFileSync(path, "utf8"))
    const [a, b, c] = ["a", "b", "c"].map(n => { fs.mkdirSync(`${root}/${n}/.config/atoll/profiles`, { recursive: true }); return `${root}/${n}` })
    fs.writeFileSync(root + "/wall.png", "wall"); fs.writeFileSync(root + "/face.png", "face")
    const wall = run(a, "profiles", "wallpaper", root + "/wall.png").stdout.trim(), face = run(a, "profiles", "photo", root + "/face.png").stdout.trim()
    fs.writeFileSync(a + "/.config/atoll/profiles/alex.json", JSON.stringify({ name: "Alex", accent: "hortela", lockAc: 10, wallpaper: wall, photo: face,
        wallpapers: { "DP-1": wall, "HDMI-A-1": wall }, dock: [{ label: "Steam", cmd: "steam" }], extra: "x" }))
    fs.writeFileSync(a + "/.config/atoll/profiles/work.json", JSON.stringify({ name: "Work" }))
    fs.writeFileSync(a + "/.config/atoll/active-profile", "alex\n")
    fs.writeFileSync(a + "/.config/atoll/input.lua", '-- Written by the Settings screen.\nreturn { kb_layout = "br,us", kb_variant = "abnt2,", sensitivity = -0.20, natural_scroll = false,\n    touchpad = { natural_scroll = false, tap_to_click = true, disable_while_typing = true, scroll_factor = 1.00 } }\n')
    const mon = (name, x, more) => ({ name, x, y: 0, w: 1920, h: 1080, rate: "60.00", scale: 1, rot: 0, on: true, mirror: "", vrr: false, bit: false, ...more })
    fs.writeFileSync(a + "/.config/atoll/monitors.lua", D.configFile([mon("DP-1", 0), mon("eDP-1", 1920, { on: false })], "off", { 1: "DP-1" }))
    fs.writeFileSync(a + "/.config/atoll/user.lua", Array.from({ length: 9 }, (_, i) => `hl.exec_cmd("app${i}")`).join("\n") + "\n")
    fs.writeFileSync(a + "/.config/atoll/rules.json", "[]\n")
    fs.writeFileSync(a + "/.config/atoll/notes.txt", "not ours")

    const size = JSON.parse(run(a, "backup", "estimate", "alex").stdout)
    assert(size.base > 0 && size.images === 8); assert.deepEqual(size.files, ["input.lua", "monitors.lua", "rules.json", "user.lua"])
    const one = root + "/out/alex.tar.gz", all = root + "/out/all.tar.gz"
    assert.equal(run(a, "backup", "export", "alex", one, "images").status, 0)
    assert.equal(run(a, "backup", "export", "all", all).status, 0)
    const members = file => spawnSync("tar", ["-tzf", file], { encoding: "utf8" }).stdout.split("\n").filter(Boolean)
    assert(members(one).includes("images/backgrounds/" + wall.split("/").pop()) && members(one).includes("profiles/alex.json") && !members(one).includes("profiles/work.json"))
    assert(!members(all).some(m => m.startsWith("images/")) && members(all).includes("profiles/work.json") && !members(all).includes("config/notes.txt"))
    assert.equal(run(a, "backup", "export", "../x", one).status, 2)

    // The other computer: one screen of the same name, its own profile.
    fs.writeFileSync(b + "/.config/atoll/profiles/default.json", JSON.stringify({ name: "Me", accent: "gelo", lockAc: 5, dock: [{ label: "Term", cmd: "kitty" }], extra: 3 }))
    const seen = JSON.parse(run(b, "backup", "inspect", one, "DP-1").stdout)
    assert.deepEqual(seen.screens, { layout: ["DP-1"], match: true }); assert.equal(seen.current.id, "default")
    assert.equal(seen.images[wall], "file"); assert.equal(seen.files.find(f => f.name === "input.lua").data, true)
    assert.equal(JSON.parse(run(b, "backup", "inspect", one, "HDMI-A-1").stdout).screens.match, false)

    // The review, line by line, mirrors what the import will do.
    const R = load("backup.js", "review,choice")
    const t = s => s, rows = R.review(seen, "alex", ["DP-1"], t, [{ code: "en", name: "English" }], { hortela: { name: "Mint" }, gelo: { name: "Ice" } })
    const row = id => rows.profile.concat(rows.files, rows.code).find(r => r.id === id)
    assert.deepEqual([row("p:accent").before, row("p:accent").after], ["Ice", "Mint"])
    assert(row("p:dock").after.includes("steam")) // a command new to this computer is named
    assert(row("p:wallpapers").after.includes("HDMI-A-1")); assert.equal(row("p:wallpapers").skip, "")
    assert(row("p:extra").skip) // another type than the setting here
    assert.equal(row("f:screens").skip, ""); assert.equal(row("f:input.lua").after, "br, us, pointer -0.20")
    assert.equal(row("f:user.lua").lines, 9)
    assert(R.review(seen, "alex", ["HDMI-A-1"], t, [], {}).files.find(r => r.id === "f:screens").skip.includes("DP-1"))
    const plain = v => JSON.parse(JSON.stringify(v))
    assert(!plain(R.choice(rows, {})).files.includes("user.lua")) // code needs an explicit yes
    assert.deepEqual(plain(R.choice(rows, { "f:user.lua": true, "p:dock": false, "f:rules.json": false })).files, ["monitors.lua", "input.lua", "user.lua"])
    assert(!plain(R.choice(rows, { "p:dock": false })).keys.includes("dock"))
    // A dock with commands new here runs them when clicked: it starts unticked and needs its own yes; the same commands do not.
    assert(row("p:dock").ask && !plain(R.choice(rows, {})).keys.includes("dock") && plain(R.choice(rows, { "p:dock": true })).keys.includes("dock"))
    const sameDock = R.review({ ...seen, current: { ...seen.current, profile: { ...seen.current.profile, dock: [{ label: "S", cmd: "steam" }] } } }, "alex", ["DP-1"], t, [], {})
    assert(!sameDock.profile.find(r => r.id === "p:dock").ask && plain(R.choice(sameDock, {})).keys.includes("dock"))

    // As a new profile: pictures land in this computer's galleries, screens it lacks are dropped, nothing to back up.
    const added = JSON.parse(run(b, "backup", "import", one, "--into", "new", "--files", "input.lua", "--screens", "DP-1").stdout)
    assert.equal(added.backup, "")
    const made = json(`${b}/.config/atoll/profiles/${added.id}.json`), galleryB = b + "/.local/share/atoll/backgrounds/"
    assert(made.wallpaper.startsWith(galleryB) && fs.readFileSync(made.wallpaper, "utf8") === "wall")
    assert(made.photo.startsWith(b + "/.local/share/atoll/faces/") && fs.readFileSync(made.photo, "utf8") === "face")
    assert.deepEqual(made.wallpapers, { "DP-1": made.wallpaper })
    assert.equal(made.name, "Alex"); assert.equal(made.extra, 3) // a value of another type is not taken
    assert.deepEqual(made.dock, [{ label: "Term", cmd: "kitty" }]) // without --keys, the dock stays this computer's
    const docked = JSON.parse(run(b, "backup", "import", one, "--into", "new", "--keys", "dock", "--screens", "DP-1").stdout)
    assert.deepEqual(json(`${b}/.config/atoll/profiles/${docked.id}.json`).dock, [{ label: "Steam", cmd: "steam" }])
    assert.equal(fs.readFileSync(b + "/.config/atoll/input.lua", "utf8"), fs.readFileSync(a + "/.config/atoll/input.lua", "utf8"))
    assert.equal(json(b + "/.config/atoll/profiles/default.json").name, "Me")
    // Replacing: only the chosen keys, and the state before is saved next to the imported file.
    const before = fs.readFileSync(b + "/.config/atoll/profiles/default.json", "utf8")
    const replaced = JSON.parse(run(b, "backup", "import", one, "--into", "replace", "--keys", "accent,lockAc", "--files", "monitors.lua", "--screens", "DP-1").stdout)
    assert.equal(replaced.id, "default"); assert(replaced.backup.startsWith(root + "/out/atoll-before-import-"))
    assert.deepEqual(json(b + "/.config/atoll/profiles/default.json"), { ...JSON.parse(before), accent: "hortela", lockAc: 10 })
    assert(fs.existsSync(b + "/.config/atoll/monitors.lua"))
    const safety = JSON.parse(run(c, "backup", "inspect", replaced.backup).stdout)
    assert.equal(safety.profiles.default.accent, "gelo"); assert(safety.files.some(f => f.name === "input.lua"))
    assert.equal(run(b, "backup", "import", one, "--files", "monitors.lua", "--screens", "HDMI-A-1").status, 1) // other screens
    // Without images: a picture already here (same content, same name) is used; one that is nowhere keeps the current one.
    const fromAll = JSON.parse(run(b, "backup", "import", all, "--profile", "alex", "--into", "new", "--screens", "DP-1").stdout)
    assert.equal(json(`${b}/.config/atoll/profiles/${fromAll.id}.json`).wallpaper, made.wallpaper)
    fs.writeFileSync(c + "/.config/atoll/profiles/default.json", JSON.stringify({ wallpaper: "/mine.png" }))
    const bare = JSON.parse(run(c, "backup", "import", all, "--profile", "alex", "--into", "replace").stdout)
    assert.equal(json(c + "/.config/atoll/profiles/default.json").wallpaper, "/mine.png"); assert(fs.existsSync(bare.backup))
    assert.equal(json(c + "/.config/atoll/profiles/default.json").wallpapers, undefined)

    // Untrusted archives: absolute paths, .., links, unknown names, Lua that runs code. Nothing is written.
    const evil = (name, setup, ...tarArgs) => {
        const stage = `${root}/stage-${name}`
        fs.mkdirSync(stage + "/config", { recursive: true }); fs.mkdirSync(stage + "/profiles")
        fs.writeFileSync(stage + "/manifest.json", JSON.stringify({ format: "atoll-backup", version: 1, images: {} }))
        fs.writeFileSync(stage + "/profiles/x.json", "{}")
        setup(stage)
        const out = `${root}/${name}.tar.gz`
        assert.equal(spawnSync("tar", ["-czf", out, "-C", stage, ...tarArgs]).status, 0)
        return out
    }
    const target = root + "/escaped"
    const bad = [
        evil("abs", () => {}, "-P", "--transform", `s,^profiles/x.json,${target}/x.json,`, "manifest.json", "profiles"),
        evil("dots", () => {}, "-P", "--transform", "s,^profiles/x.json,profiles/../../escaped.json,", "manifest.json", "profiles"),
        evil("link", s => fs.symlinkSync("/etc/passwd", s + "/config/user.lua"), "manifest.json", "config"),
        evil("hard", s => { fs.writeFileSync(s + "/config/input.lua", "return {}"); fs.linkSync(s + "/config/input.lua", s + "/config/user.lua") }, "manifest.json", "config"),
        evil("name", s => fs.writeFileSync(s + "/config/evil.sh", "x"), "manifest.json", "config"),
        evil("manifest", s => fs.writeFileSync(s + "/manifest.json", "{}"), "manifest.json", "profiles")
    ]
    fs.writeFileSync(root + "/plain.tar.gz", "not an archive"); bad.push(root + "/plain.tar.gz")
    const listed = member => spawnSync("tar", ["-tzf", bad[member]], { encoding: "utf8" }).stdout
    assert(listed(0).includes(target) && listed(1).includes("..")) // the archives really hold what they claim
    const untouched = fs.readFileSync(c + "/.config/atoll/profiles/default.json", "utf8")
    for (const file of bad) {
        assert.equal(run(c, "backup", "inspect", file).status, 1, file)
        assert.equal(run(c, "backup", "import", file, "--into", "replace", "--files", "user.lua").status, 1, file)
    }
    assert(!fs.existsSync(target) && !fs.existsSync(root + "/escaped.json") && !fs.existsSync(c + "/.config/atoll/user.lua"))
    assert.equal(fs.readFileSync(c + "/.config/atoll/profiles/default.json", "utf8"), untouched)
    for (const [name, code] of [["exec", 'return os.execute("touch pwned")'], ["call", 'return { a = dofile"x" }'], ["long", 'return { a = 1 } --[[x]] dofile"y"'], ["global", 'x = 1 return {}']]) {
        const file = evil(name, s => fs.writeFileSync(s + "/config/input.lua", code), "manifest.json", "config")
        assert.equal(JSON.parse(run(c, "backup", "inspect", file).stdout).files[0].data, false, name)
        assert.equal(run(c, "backup", "import", file, "--files", "input.lua").status, 1, name)
    }
    assert(!fs.existsSync(c + "/.config/atoll/input.lua"))
    // A code file longer than the review shows: what hides past the cut never lands, and the page cannot accept it.
    const long = evil("big", s => fs.writeFileSync(s + "/config/user.lua", "-- notes\n".repeat(8400) + 'hl.exec_cmd("touch pwned")\n'), "manifest.json", "config")
    const longInfo = JSON.parse(run(c, "backup", "inspect", long).stdout)
    assert(longInfo.files[0].bytes > 75000 && longInfo.files[0].big === true && !longInfo.files[0].text.includes("pwned"))
    const longRows = R.review(longInfo, "x", [], t, [], {})
    assert(longRows.code[0].skip.includes("never imported")); assert(!plain(R.choice(longRows, { "f:user.lua": true })).files.includes("user.lua"))
    assert.equal(run(c, "backup", "import", long, "--files", "user.lua").status, 1)
    assert(!fs.existsSync(c + "/.config/atoll/user.lua"))
    fs.rmSync(root, { recursive: true })
}
// Liking a song copies the cover the player names: a regular file of at most 20 MB, never a device, a pipe or a link.
{
    const root = fs.mkdtempSync("/tmp/atoll-test-")
    const script = fs.readFileSync(new URL("../shell/Likes.qml", import.meta.url), "utf8").match(/\["sh", "-c", '([^']+)'/)[1]
    const copy = (src, name) => spawnSync("sh", ["-c", script, "sh", src, `${root}/likes/${name}`]).status
    fs.writeFileSync(root + "/cover.png", "png"); fs.symlinkSync(root + "/cover.png", root + "/link.png"); fs.writeFileSync(root + "/huge.png", ""); fs.truncateSync(root + "/huge.png", 20971521)
    spawnSync("mkfifo", [root + "/pipe"])
    assert.equal(copy(root + "/cover.png", "a"), 0); assert.equal(fs.readFileSync(root + "/likes/a", "utf8"), "png")
    for (const [src, name] of [["/dev/zero", "z"], [root + "/link.png", "l"], [root + "/huge.png", "h"], [root + "/pipe", "p"], [root + "/nowhere", "n"]]) {
        assert.notEqual(copy(src, name), 0, src); assert(!fs.existsSync(`${root}/likes/${name}`) && !fs.existsSync(`${root}/likes/${name}.part`), src)
    }
    fs.rmSync(root, { recursive: true })
}
// The Backup page on the real QML: pick a file, review it, replace. user.lua waits for its own yes.
if (haveQs) {
    const root = fs.mkdtempSync("/tmp/atoll-test-"), home = root + "/home", other = root + "/other", file = root + "/alex.tar.gz"
    fs.cpSync(new URL("../shell/", import.meta.url), root, { recursive: true })
    for (const dir of [home + "/.local/share/atoll", home + "/.config/atoll/profiles", other + "/.config/atoll/profiles"]) fs.mkdirSync(dir, { recursive: true })
    fs.symlinkSync(new URL("../scripts", import.meta.url).pathname, home + "/.local/share/atoll/scripts")
    fs.writeFileSync(home + "/.config/atoll/profiles/default.json", JSON.stringify({ name: "Me", accent: "gelo" }))
    fs.writeFileSync(other + "/.config/atoll/profiles/alex.json", JSON.stringify({ name: "Alex", accent: "hortela", wallpapers: { "DP-9": "/x" } }))
    fs.writeFileSync(other + "/.config/atoll/user.lua", 'hl.exec_cmd("app")\n')
    assert.equal(spawnSync(new URL("../scripts/backup", import.meta.url).pathname, ["export", "all", file], { env: { ...process.env, HOME: other } }).status, 0)
    const stub = body => `pragma Singleton\nimport Quickshell\nSingleton { ${body} }\n`
    const out = runQml(root, `import QtQuick
import Quickshell
ShellRoot {
    FloatingWindow { implicitWidth: 1100; implicitHeight: 1400; PgBackup { anchors.fill: parent } }
    property int step: 0
    function say(tag, v) { console.log("RESULT " + tag + " " + JSON.stringify(v)) }
    Timer {
        running: true; repeat: true; interval: 500
        onTriggered: {
            step++
            if (step === 1) Backup.inspect("${file}")
            if (step === 3) { say("target", [Backup.step, Backup.from, Backup.into]); Backup.next() }
            if (step === 4) {
                say("review", { rows: Backup.review.profile.map(r => r.id + (r.skip ? "!" : "")), code: Backup.review.code.map(r => r.id), files: Backup.chosen.files })
                Backup.pick("f:user.lua", true)
                Backup.pick("p:name", false)
            }
            if (step === 5) { say("chosen", Backup.chosen); Backup.apply() }
            if (step === 7) { say("done", [Backup.step, Backup.saved, Backup.error]); Qt.quit() }
        }
    }
}
`, { "Ui.qml": stub(`property bool open: true; function show(p) { open = true }`), "Night.qml": stub("function apply() {}"), "Idle.qml": stub("function apply() {}") })
    assert.deepEqual(out.target, ["target", "alex", "replace"])
    assert.deepEqual(out.review, { rows: ["p:name", "p:accent", "p:wallpapers!"], code: ["f:user.lua"], files: [] })
    assert.deepEqual(out.chosen, { keys: ["accent"], files: ["user.lua"], changes: 1, changedFiles: 1 })
    assert.equal(out.done[0], "done"); assert(fs.existsSync(out.done[1]) && out.done[1].startsWith(root + "/atoll-before-import-")); assert.equal(out.done[2], "")
    const now = JSON.parse(fs.readFileSync(home + "/.config/atoll/profiles/default.json"))
    assert.deepEqual([now.name, now.accent, now.wallpapers], ["Me", "hortela", {}])
    assert.equal(fs.readFileSync(home + "/.config/atoll/user.lua", "utf8"), 'hl.exec_cmd("app")\n')
    fs.rmSync(root, { recursive: true })
}

// Shortcuts: the editor reads the same defaults Hyprland binds, and what it saves or applies live gives the same binds.
const S = load("shortcuts.js", "rows,norm,combo,keyName,pretty,problem,safeText,parseDefaults,parseChanges,toLua,parseLive,effective,active,conflicts,free,layers,inLayer,onKey,offMap,setKeys,newId,liveCode,recordCode,enterRecord,leaveRecord")
const keysLua = fs.readFileSync(new URL("../hypr/keys.lua", import.meta.url), "utf8")
const defs = S.parseDefaults(keysLua)
assert.equal(defs.length, (keysLua.match(/^S\(/gm) || []).length) // every line is readable
assert.equal(new Set(defs.map(d => d.id)).size, defs.length)
assert.equal(new Set(defs.map(d => S.norm(d.keys))).size, defs.length) // no two defaults on one key
defs.forEach(d => assert.equal(S.problem(d.keys), "", d.keys))
assert(defs.every(d => ["atoll", "windows", "workspaces", "apps", "shots"].includes(d.group)))
assert.deepEqual(plain(defs.find(d => d.id === "ws10")), { id: "ws10", keys: "SUPER + 0", group: "workspaces", label: "Workspace %1", arg: "10" })
assert.equal(S.norm("SHIFT + SUPER + tab"), S.norm("SUPER + SHIFT + TAB")); assert.equal(S.norm("SUPER + code:60"), S.norm("SUPER + period"))
assert.notEqual(S.norm("SUPER + K"), S.norm("SUPER + SHIFT + K"))
assert.equal(S.combo(["SHIFT", "SUPER"], S.keyName(45)), "SUPER + SHIFT + K"); assert.equal(S.keyName(191), "code:191")
assert.deepEqual(plain(S.pretty("SUPER + SHIFT + period")), ["Super", "Shift", "."])
assert.deepEqual(["SUPER + K", "K", "SHIFT + K", "SHIFT + PRINT", "SUPER + Escape", "SUPER + x\"y", "HYPER + K", "CTRL + code:191"].map(S.problem), ["", "typing", "typing", "", "reserved", "invalid", "invalid", ""])
assert(S.safeText("Firefox «x» 🚀") && !S.safeText("a\nb") && !S.safeText("\ud800") && !S.safeText(7))
const evil = 'notify-send "a\\" ]] end os.execute(\'touch /tmp/x\') --[['
const saved1 = S.toLua([{ id: "terminal", keys: "SUPER + T" }, { id: "custom-1", keys: "SUPER + SHIFT + K", label: "Calc «1»", exec: evil, group: "apps" }, { id: "bad id", keys: "" }, { id: "x", keys: "", exec: "a\nb" }])
assert.deepEqual(plain(S.parseChanges(saved1)), [{ id: "terminal", keys: "SUPER + T" }, { id: "custom-1", keys: "SUPER + SHIFT + K", label: "Calc «1»", exec: evil, group: "apps" }])
assert.deepEqual(plain(S.parseChanges('{ id = "a", keys = "K" }\n{ id = "b", keys = "SUPER + B", exec = "x\\u0000" }\nnot a line\n')), [])
// Giving Super+Shift+C (Center) to a new app turns Center off; giving it back removes the app.
let ch = [], ent = S.effective(defs, ch, null)
assert.deepEqual(S.conflicts(ent, "SHIFT + SUPER + c", "").map(e => e.id), ["center"])
assert(S.free(ent, ["SUPER", "SHIFT"], 6).every(k => !S.conflicts(ent, k, "").length)); assert.equal(S.free(ent, ["SUPER", "SHIFT"], 6).length, 6)
const id1 = S.newId(ch); assert.equal(id1, "custom-1")
ch = S.setKeys(defs, ch, ent, id1, "SUPER + SHIFT + C", { label: "Calculator", exec: "gnome-calculator", group: "apps" })
ch = S.setKeys(defs, ch, S.effective(defs, ch, null), "terminal", "SUPER + SHIFT + Return")
let after = S.effective(defs, ch, null)
assert.equal(after.find(e => e.id === "center").state, "off"); assert.equal(after.find(e => e.id === "terminal").state, "changed")
assert.equal(S.onKey(after, ["SUPER", "SHIFT"], 54).id, id1); assert.equal(S.onKey(after, ["SUPER"], 36), null)
assert.deepEqual(S.offMap(after, null).map(e => e.id), ["shot-print", "shot-print-full"])
assert(S.inLayer("SUPER + CTRL + down", S.layers[3]) && !S.inLayer("SUPER + CTRL + SHIFT + down", S.layers[3]) && S.inLayer("SHIFT + PRINT", S.layers[4]))
const restored = S.setKeys(defs, ch, after, "center", "SUPER + SHIFT + C")
assert.deepEqual(plain(restored), [{ id: "terminal", keys: "SUPER + SHIFT + Return" }])
assert.equal(S.newId([{ id: "custom-4" }, { id: "terminal" }]), "custom-5")
// Live: binds not made by Atoll are someone else's, and an Atoll bind user.lua removed is gone.
const liveJson = JSON.stringify([
    { modmask: 64, key: "Return", description: "atoll:terminal", submap: "" }, { modmask: 65, key: "X", description: "", dispatcher: "exec", arg: "foot", submap: "" },
    { modmask: 64, key: "mouse:272", mouse: true }, { modmask: 0, key: "XF86AudioMute" }, { modmask: 64, key: "Escape", submap: "atoll-record" }
].concat(defs.filter(d => d.id !== "browser" && d.id !== "terminal").map(d => ({ modmask: 0, key: "?", description: "atoll:" + d.id }))))
const liveBinds = S.parseLive(liveJson)
assert.equal(liveBinds.length, 2 + defs.length - 2); assert.equal(S.parseLive("oops"), null)
const withLive = S.effective(defs, [], liveBinds)
assert.equal(withLive.find(e => e.id === "browser").state, "gone"); assert.equal(withLive.find(e => e.id === "terminal").state, "default")
assert.deepEqual(S.conflicts(withLive, "SUPER + SHIFT + X", "").map(e => e.state), ["user"])
// Applying live gives the binds a reload would: run binds.lua with the old file, then the eval code, against a stand-in hl.
const hyprBinds = (changes, ...evals) => {
    const h = fs.mkdtempSync("/tmp/atoll-test-")
    fs.mkdirSync(h + "/.config/atoll/hypr", { recursive: true }); fs.writeFileSync(h + "/.config/atoll/hypr/keys.lua", keysLua)
    fs.writeFileSync(h + "/.config/atoll/shortcuts.lua", S.toLua(changes))
    assert.equal(spawnSync("luac", ["-p", h + "/.config/atoll/shortcuts.lua"]).status, 0)
    evals.forEach((code, i) => fs.writeFileSync(`${h}/eval${i}.lua`, code))
    const run = spawnSync("lua", [new URL("binds.lua", import.meta.url).pathname, new URL("../hypr/binds.lua", import.meta.url).pathname, ...evals.map((_, i) => `${h}/eval${i}.lua`)], { encoding: "utf8", env: { ...process.env, HOME: h } })
    fs.rmSync(h, { recursive: true })
    assert.equal(run.status, 0, run.stderr)
    return run.stdout
}
const fresh = hyprBinds([])
assert.equal(fresh.split("\n").filter(l => l.includes("description=atoll:")).length, defs.length)
for (const keys of ["SUPER + Return", "SUPER + ALT + K", "SUPER + CTRL + 0", "SHIFT + PRINT", "SUPER + mouse:272", "XF86AudioMute"]) assert(fresh.includes("\n" + keys + " => ") || fresh.startsWith(keys + " => "), keys)
const reloaded = hyprBinds(ch)
assert(reloaded.includes("SUPER + SHIFT + C => {args={1=gnome-calculator},dsp=dsp.exec_cmd} {description=atoll:custom-1}"))
assert(!reloaded.includes("description=atoll:center") && !reloaded.includes("SUPER + Return =>"))
const code = S.liveCode(S.effective(defs, [], null), after)
assert.equal(hyprBinds([], code), reloaded)
assert.equal(hyprBinds(ch, S.liveCode(after, S.effective(defs, restored, null))), hyprBinds(restored))
assert.equal(S.liveCode(after, after), "")
// A default someone else's change already holds, after an update, stays theirs.
assert(!hyprBinds([{ id: "custom-1", keys: "SUPER + period", exec: "foot" }]).includes("description=atoll:emoji"))
// The page itself, against a stand-in hyprctl: it reads both files, saves, applies live and pauses shortcuts while recording.
if (haveQs) {
    const sc = fs.mkdtempSync("/tmp/atoll-test-"), cfg = sc + "/home/.config/atoll"
    fs.cpSync(new URL("../shell/", import.meta.url), sc, { recursive: true })
    fs.mkdirSync(cfg + "/hypr", { recursive: true }); fs.mkdirSync(sc + "/bin")
    fs.writeFileSync(cfg + "/hypr/keys.lua", keysLua)
    fs.writeFileSync(cfg + "/shortcuts.lua", S.toLua([{ id: "terminal", keys: "SUPER + SHIFT + Return" }]))
    const liveBinds = S.active(S.effective(defs, [{ id: "terminal", keys: "SUPER + SHIFT + Return" }], null)).map(e => ({ modmask: 64 + (e.keys.includes("SHIFT") ? 1 : 0) + (e.keys.includes("ALT") ? 8 : 0) + (e.keys.includes("CTRL") ? 4 : 0) + (e.keys.includes("SUPER") ? 0 : -64), key: e.keys.split(" + ").pop(), description: "atoll:" + e.id, submap: "" }))
        .concat([{ modmask: 65, key: "X", description: "", dispatcher: "exec", arg: "foot", submap: "" }, { modmask: 65, key: "C", description: "atoll:custom-1", submap: "" }]) // as after the save below
    fs.writeFileSync(sc + "/binds.json", JSON.stringify(liveBinds))
    fs.writeFileSync(sc + "/bin/hyprctl", `#!/bin/sh\nprintf '%s\\037' "$@" >> '${sc}/hyprctl.log'; printf '\\036' >> '${sc}/hyprctl.log'\n[ "$1 $2" = "-j binds" ] && cat '${sc}/binds.json'\nexit 0\n`, { mode: 0o755 })
    const qmlRoot = `import QtQuick
import Quickshell
ShellRoot {
    FloatingWindow { implicitWidth: 1000; implicitHeight: 1600; PgShortcuts { id: pg; anchors.fill: parent } }
    property int step: 0
    function say(tag, v) { console.log("RESULT " + tag + " " + JSON.stringify(v)) }
    Timer {
        running: true; repeat: true; interval: 500
        onTriggered: {
            step++
            if (step === 2) {
                pg.pick("SUPER + SHIFT + X")
                const user = pg.selEntry?.state
                pg.pick("SUPER + SHIFT + Return")
                say("read", { defaults: pg.defaults.length, changes: pg.changes.length, live: !!pg.live, sel: pg.labelOf(pg.selEntry), user, layer: pg.layerIndex })
                pg.startNew("SUPER + SHIFT + C")
                pg.edit = Object.assign({}, pg.edit, { kind: 1, cmd: "notify-send hi" })
                say("form", { conflicts: pg.editConflicts.map(e => e.id), canSave: pg.canSave, label: pg.editLabel })
                pg.save()
            }
            if (step === 3) {
                pg.startNew("SUPER + SHIFT + X")
                pg.edit = Object.assign({}, pg.edit, { kind: 1, cmd: "foot" })
                say("blocked", { canSave: pg.canSave, blocked: pg.editBlocked })
                pg.startRecording()
                say("recording", pg.recording)
            }
            if (step === 4) { pg.stopRecording(); pg.edit = null; pg.restore("center"); pg.restore("center") }
            if (step === 5) { say("restored", pg.changes.map(c => c.id + "=" + c.keys)); Qt.quit() }
        }
    }
}
`
    fs.writeFileSync(sc + "/shell.qml", qmlRoot)
    fs.writeFileSync(sc + "/Ui.qml", `pragma Singleton\nimport Quickshell\nSingleton { property bool open: true; readonly property var pages: [{ id: "som", label: "Sound" }] }\n`)
    const { WAYLAND_DISPLAY, DISPLAY, HYPRLAND_INSTANCE_SIGNATURE, ...env } = process.env
    const run = spawnSync("dbus-run-session", ["--", "qs", "-p", sc + "/shell.qml"], { encoding: "utf8", timeout: 30000, env: { ...env, PATH: sc + "/bin:" + env.PATH, LANG: "C.UTF-8", LC_ALL: "C.UTF-8", LANGUAGE: "en", QT_QPA_PLATFORM: "offscreen", HOME: sc + "/home", XDG_DATA_HOME: sc + "/home/share", XDG_CONFIG_HOME: sc + "/home/config", XDG_STATE_HOME: sc + "/home/state", XDG_DATA_DIRS: sc + "/data" } })
    const said = Object.fromEntries([...(run.stdout + run.stderr).matchAll(/RESULT (\w+) (.*)/g)].map(m => [m[1], JSON.parse(m[2])]))
    const warnings = (run.stdout + run.stderr).split("\n").filter(l => /PgShortcuts\.qml|shortcuts\.js/.test(l))
    assert.deepEqual(warnings, [])
    assert.deepEqual(said.read, { defaults: defs.length, changes: 1, live: true, sel: "Terminal", user: "user", layer: 1 })
    assert.deepEqual(said.form, { conflicts: ["center"], canSave: true, label: "notify-send hi" })
    assert.deepEqual(said.blocked, { canSave: false, blocked: true }); assert.equal(said.recording, true)
    assert.deepEqual(said.restored, ["terminal=SUPER + SHIFT + Return"])
    const calls = fs.readFileSync(sc + "/hyprctl.log", "utf8").split("\x1e").filter(Boolean).map(l => l.split("\x1f").filter(Boolean))
    const evals = calls.filter(c => c[0] === "eval").map(c => c[1])
    assert(evals.some(c => c.includes('hl.unbind("SUPER + SHIFT + C")') && c.includes('hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("notify-send hi"), { description = "atoll:custom-1" })')))
    assert(evals.some(c => c === S.recordCode))
    assert.deepEqual(calls.filter(c => c[0] === "dispatch").map(c => c[1]), [S.enterRecord, S.leaveRecord])
    assert(evals.some(c => c.includes('hl.unbind("SUPER + SHIFT + C")') && c.includes('d["center"]'))) // restored over the new one
    assert.deepEqual(plain(S.parseChanges(fs.readFileSync(cfg + "/shortcuts.lua", "utf8"))), [{ id: "terminal", keys: "SUPER + SHIFT + Return" }])
    fs.rmSync(sc, { recursive: true })
}

console.log("ok")
