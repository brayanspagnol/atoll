// Self-check for cal.js and parse.js: node test.mjs
import fs from "node:fs"; import vm from "node:vm"; import assert from "node:assert"; import { spawnSync } from "node:child_process"
const load = (file, names) => {
    const ctx = {}; vm.createContext(ctx)
    vm.runInContext(fs.readFileSync(new URL("../shell/" + file, import.meta.url), "utf8").replace(".pragma library", "") + `;globalThis.x={${names}}`, ctx)
    return ctx.x
}
const C = load("cal.js", "key,addDays,monthGrid,weekOf,isoWeek,occurs,on,upcoming,validTime")
const P = load("parse.js", "cpu,mem,net,top,bytes,shQuote,newerVersion,zipLayouts,joinLayouts,xkbCatalog,powerProfiles,inWindow,nmcliRows")
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
const placeholders = text => (text.match(/%\d/g) || []).sort().join()
for (const file of fs.readdirSync(new URL("i18n/", shell))) {
    const dict = JSON.parse(fs.readFileSync(new URL("i18n/" + file, shell), "utf8"))
    for (const key of used) assert(key in dict, `${file} is missing: ${key}`)
    for (const [key, value] of Object.entries(dict)) {
        assert.equal(placeholders(value), placeholders(key), `${file}: placeholders differ in: ${key}`)
        assert(value.trim(), `${file}: empty translation: ${key}`)
    }
}

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

console.log("ok")
