local mainMod = "SUPER"
local scripts = "$HOME/.local/share/atoll/scripts/"
local qs = "qs -c atoll ipc call "
local lock = "pidof hyprlock || hyprlock -c $HOME/.config/atoll/hyprlock.conf"
-- To change one, call hl.unbind and hl.bind for the same keys in ~/.config/atoll/user.lua.
local terminal = "kitty"
local browser = "xdg-open https://"
local fileManager = "xdg-open ~"
local shot = scripts .. "screenshot"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",      hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C",      hl.dsp.window.close())
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + R",      hl.dsp.exec_cmd(qs .. "ui launcher"))
hl.bind(mainMod .. " + N",      hl.dsp.exec_cmd(qs .. "ui toggle som"))
hl.bind(mainMod .. " + W",      hl.dsp.exec_cmd(qs .. "ui toggle som"))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd(qs .. "ui toggle ajustes"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(qs .. "ui toggle energia"))
hl.bind(mainMod .. " + Z",      hl.dsp.exec_cmd(qs .. "ui dock"))
for key, page in pairs({ A = "som", I = "rede", B = "bt", D = "perf", C = "cal", V = "avisos", J = "ajustes", E = "energia", M = "monitor", O = "sobre" }) do
    hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.exec_cmd(qs .. "ui toggle " .. page))
end
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("pkill -x qs"))
hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd(lock))
hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd(scripts .. "kb-layout"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(qs .. "ui clipboard"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(qs .. "ui emoji"))

hl.bind(mainMod .. " + M",         hl.dsp.window.move({ workspace = "special:minimized" }))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.workspace.toggle_special("minimized"))
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + ALT + S",   hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + V",       hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + T",       hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + ALT + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F",       hl.dsp.window.fullscreen({}))
hl.bind(mainMod .. " + G",       hl.dsp.group.toggle())
hl.bind(mainMod .. " + H",       hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J",       hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + TAB",         hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }))
for key, dir in pairs({ left = "l", right = "r", up = "u", down = "d" }) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
end
for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.window.center())
hl.bind(mainMod .. " + CTRL + down", hl.dsp.focus({ workspace = "empty" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
    hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind("PRINT",                   hl.dsp.exec_cmd(shot .. " region-file"))
hl.bind("SHIFT + PRINT",           hl.dsp.exec_cmd(shot .. " full-file"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(shot .. " region-file"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(shot .. " region-clip"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(shot .. " full-file"))

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -q s +10%"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q s 10%-"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(qs .. "media toggle"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(qs .. "media toggle"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(qs .. "media next"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(qs .. "media prev"), { locked = true })
