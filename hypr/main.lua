-- Atoll: Hyprland configuration entry point.
local home = os.getenv("HOME")
local here = home .. "/.config/atoll/hypr/"

for _, file in ipairs({ "env", "look", "input", "rules", "binds", "monitors" }) do
    dofile(here .. file .. ".lua")
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
    dofile(user)
end
