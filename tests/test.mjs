// Self-check for cal.js and parse.js: node test.mjs
import fs from "node:fs"; import vm from "node:vm"; import assert from "node:assert"
const load = (file, names) => {
    const ctx = {}; vm.createContext(ctx)
    vm.runInContext(fs.readFileSync(new URL("../shell/" + file, import.meta.url), "utf8").replace(".pragma library", "") + `;globalThis.x={${names}}`, ctx)
    return ctx.x
}
const C = load("cal.js", "key,addDays,easter,holidays,monthGrid,weekOf,isoWeek,occurs,on,upcoming,validTime,longDay")
const P = load("parse.js", "cpu,mem,net,top,bytes")
assert.equal(C.easter(2026), "2026-04-05"); assert.equal(C.easter(2027), "2027-03-28")
const h = C.holidays(2026)
assert.equal(h["2026-02-17"], "Carnaval"); assert.equal(h["2026-04-03"], "Sexta-feira Santa"); assert.equal(h["2026-06-04"], "Corpus Christi"); assert.equal(h["2026-11-20"], "Consciência Negra")
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
assert.equal(C.longDay("2026-11-05"), "quinta-feira, 5 de novembro")
const c = P.cpu("cpu  100 0 100 700 100 0 0 0 0 0\ncpu0 50 0 50 350 50 0 0 0 0 0\nintr 1\n"); assert.equal(c.length, 2); assert.equal(c[0].total, 1000); assert.equal(c[0].idle, 800)
const mm = P.mem("MemTotal: 1000 kB\nMemAvailable: 400 kB\nSwapTotal: 100 kB\nSwapFree: 75 kB\n"); assert.equal(mm.used, 614400); assert.equal(mm.swapUsed, 25600)
const nn = P.net("h\nh\n lo: 9 0 0 0 0 0 0 0 9 0\n wlp0: 100 1 0 0 0 0 0 0 200 1 0 0 0 0 0 0\ndocker0: 7 0 0 0 0 0 0 0 7\n"); assert.equal(nn.rx, 100); assert.equal(nn.tx, 200)
const t = P.top("    PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND\n 1 a 20 0 1 1 1 S 99.0 1.0 0:00.01 old\n\ntop\n    PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND\n 22 bob 20 0 1 1 1 R 12.5 3.2 0:01.00 Web Content\n", 5)
assert.equal(t.length, 1); assert.equal(t[0].name, "Web Content"); assert.equal(t[0].cpu, 12.5); assert.equal(P.top("nada", 5).length, 0)
assert.equal(P.bytes(1536), "1.5 KB"); assert.equal(P.bytes(500), "500 B")
console.log("ok")
