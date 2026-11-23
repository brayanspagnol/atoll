-- The editable shortcuts are data in keys.lua. Changes made in Control center > Shortcuts are saved to
-- ~/.config/atoll/shortcuts.lua and applied here, after the defaults. For your own changes, call hl.unbind
-- and hl.bind for the same keys in ~/.config/atoll/user.lua, which loads after this file and has the last word.
local home = os.getenv("HOME")
local defaults = dofile(home .. "/.config/atoll/hypr/keys.lua")

-- "SUPER + SHIFT + Tab" and "SHIFT + SUPER + TAB" are the same shortcut.
local alias = { CONTROL = "CTRL", WIN = "SUPER", MOD4 = "SUPER", META = "SUPER" }
local function norm(keys)
    local parts = {}
    for part in keys:gmatch("[^+]+") do parts[#parts + 1] = part:match("^%s*(.-)%s*$") end
    local key = table.remove(parts) or ""
    for i, mod in ipairs(parts) do parts[i] = alias[mod:upper()] or mod:upper() end
    table.sort(parts)
    return table.concat(parts, "+") .. "|" .. key:lower()
end

-- Written by the shell, one entry per line: { id = "...", keys = "..." } moves a default to new keys
-- (keys = "" turns it off), and an id that is not a default adds a shortcut that runs exec.
local changes = {}
local chunk = loadfile(home .. "/.config/atoll/shortcuts.lua", "t", {})
if chunk then
    local ok, list = pcall(chunk)
    if ok and type(list) == "table" then changes = list end
end

local byId, changed, taken = {}, {}, {}
for _, s in ipairs(defaults) do byId[s.id] = s end
for _, c in ipairs(changes) do
    local valid = type(c) == "table" and type(c.id) == "string" and type(c.keys) == "string"
        and (byId[c.id] or (type(c.exec) == "string" and c.exec ~= ""))
    if valid and not changed[c.id] then
        changed[c.id] = c
        if c.keys ~= "" then taken[norm(c.keys)] = true end
    end
end
for _, s in ipairs(defaults) do
    local c = changed[s.id]
    if c then
        if c.keys ~= "" then hl.bind(c.keys, s.act, { description = "atoll:" .. s.id }) end
    elseif not taken[norm(s.keys)] then -- a key you gave to another shortcut stays yours after an update
        hl.bind(s.keys, s.act, { description = "atoll:" .. s.id })
    end
end
for _, c in ipairs(changes) do
    if changed[c.id] == c and not byId[c.id] and c.keys ~= "" then
        hl.bind(c.keys, hl.dsp.exec_cmd(c.exec), { description = "atoll:" .. c.id })
    end
end

-- The shortcut editor enters this empty submap while it records a combination, so the keys reach it
-- instead of running their shortcuts. It leaves on its own after a few seconds; Super+Escape also leaves.
hl.define_submap("atoll-record", function()
    hl.bind("SUPER + Escape", hl.dsp.submap("reset"))
end)

-- Not on the editor's keyboard map: mouse buttons and media keys.
local mainMod = "SUPER"
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -q s +10%"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q s 10%-"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("qs -c atoll ipc call media toggle"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("qs -c atoll ipc call media toggle"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("qs -c atoll ipc call media next"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("qs -c atoll ipc call media prev"), { locked = true })
