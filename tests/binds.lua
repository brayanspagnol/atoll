-- Loads hypr/binds.lua against a stand-in hl and prints the binds it leaves, sorted.
-- lua tests/binds.lua <binds.lua> [more.lua...]: the other files run afterwards, as hyprctl eval would.
local function ser(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys, out = {}, {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end
local function ns(path)
    return setmetatable({}, {
        __index = function(_, k) return ns(path .. "." .. k) end,
        __call = function(_, ...) return { dsp = path, args = ser({ ... }) } end,
    })
end
local binds, submaps = {}, {}
hl = { dsp = ns("dsp") }
function hl.bind(keys, act, opts) binds[#binds + 1] = { keys = keys, act = ser(act), opts = ser(opts or {}) } end
-- Like Hyprland: removes every bind made before with exactly this key string.
function hl.unbind(keys)
    local kept = {}
    for _, b in ipairs(binds) do if b.keys ~= keys then kept[#kept + 1] = b end end
    binds = kept
end
function hl.define_submap(name, reset, fn)
    local outer = binds
    binds = {}
    ;(fn or reset)()
    submaps[name] = binds
    binds = outer
end
for _, file in ipairs(arg) do dofile(file) end
local rows = {}
for _, b in ipairs(binds) do rows[#rows + 1] = b.keys .. " => " .. b.act .. " " .. b.opts end
for name, list in pairs(submaps) do
    for _, b in ipairs(list) do rows[#rows + 1] = "[" .. name .. "] " .. b.keys .. " => " .. b.act end
end
table.sort(rows)
print(table.concat(rows, "\n"))
