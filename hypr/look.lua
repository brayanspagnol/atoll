hl.config({
    general = {
        gaps_in = 6, gaps_out = 12, border_size = 1, layout = "dwindle",
        col = { active_border = "rgb(8CC8F5)", inactive_border = "rgba(ffffff24)" },
        snap = { enabled = false },
    },
    decoration = {
        rounding = 24, rounding_power = 2.0,
        blur = { enabled = true, size = 8, passes = 3, vibrancy = 0.2, noise = 0.01, xray = false }, -- only translucent shell layers use it
        shadow = { enabled = false },
    },
    input = {
        kb_layout = "us", repeat_rate = 25, repeat_delay = 600,
        follow_mouse = 1, float_switch_override_focus = 1,
    },
    misc = { vrr = 0, middle_click_paste = true, disable_hyprland_logo = true, disable_splash_rendering = true, key_press_enables_dpms = true, mouse_move_enables_dpms = true, allow_session_lock_restore = true },
})
hl.curve("out", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
for _, a in ipairs({
    { leaf = "windows", speed = 3, style = "popin 92%" },
    { leaf = "fade", speed = 3 },
    { leaf = "layers", speed = 2, style = "fade" },
    { leaf = "workspaces", speed = 3, style = "slide" },
    { leaf = "specialWorkspace", speed = 3, style = "fade" },
}) do
    hl.animation({ leaf = a.leaf, enabled = true, speed = a.speed, bezier = "out", style = a.style })
end
for _, ns in ipairs({ "atoll-.*", "selection", "noanim" }) do
    hl.layer_rule({ match = { namespace = ns }, no_anim = true })
end
for _, ns in ipairs({ "atoll-island", "atoll-dock", "atoll-central", "atoll-palette", "atoll-sheet", "atoll-osd" }) do
    hl.layer_rule({ match = { namespace = ns }, blur = true })
    hl.layer_rule({ match = { namespace = ns }, ignore_alpha = 0.2 })
end
