-- Atoll: Hyprland configuration entry point.
local home = os.getenv("HOME")
local here = home .. "/.config/atoll/hypr/"

-- Error text can quote the broken file, so only plain characters reach the shell.
local function warn(message)
    hl.exec_cmd("notify-send -u critical Atoll '" .. tostring(message):gsub("[^%w%s%.%,%:%-_/]", " ") .. "'")
end

-- One file failing must not take the rest down with it: the session services below must still start.
for _, file in ipairs({ "env", "look", "input", "rules", "binds", "monitors" }) do
    local ok, err = pcall(dofile, here .. file .. ".lua")
    if not ok then
        warn("Config error in " .. file .. ".lua: " .. tostring(err))
    end
end

-- ATOLL_NESTED skips the session services when testing inside another compositor (see CONTRIBUTING.md).
if not os.getenv("ATOLL_NESTED") then
    local scripts = home .. "/.local/share/atoll/scripts/"
    hl.on("hyprland.start", function()
        hl.exec_cmd(scripts .. "session-env")
        hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
        hl.exec_cmd("wl-paste --watch cliphist store")
        hl.exec_cmd("hyprsunset")
        hl.exec_cmd("hypridle -c " .. home .. "/.config/atoll/hypridle.conf")
        hl.exec_cmd(scripts .. "atoll-start")
    end)
end

-- Personal overrides live here and survive updates.
local user = home .. "/.config/atoll/user.lua"
local probe = io.open(user, "r")
if probe then
    probe:close()
    local ok, err = pcall(dofile, user)
    if not ok then
        warn("Error in user.lua: " .. tostring(err))
    end
end
