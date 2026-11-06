-- Windows that work better floating.
local floating = {
    { class = "^(blueman-manager)$" },
    { class = "^(nm-connection-editor)$" },
    { class = "^(org.pulseaudio.pavucontrol)$" },
    { title = "^(Open File|Open Folder|Save As|Select a File|File Upload)(.*)$" },
    { title = "^(Library)(.*)$" },
}
for _, match in ipairs(floating) do
    hl.window_rule({ match = match, float = true })
end

-- File choosers: floating and centered, or they would tile across the whole screen.
for _, class in ipairs({ "^(zenity)$", "^(xdg-desktop-portal-gtk)$" }) do
    hl.window_rule({ match = { class = class }, float = true, size = "1100 760", center = true })
end

-- Selection overlays must appear instantly.
hl.layer_rule({ match = { namespace = "selection" }, no_anim = true })

-- The Window rules screen's rules, after the defaults so they win. The handles let the screen switch one off live.
local user_rules = os.getenv("HOME") .. "/.config/atoll/rules.lua"
local probe = io.open(user_rules, "r")
if probe then
    probe:close()
    local ok, list = pcall(dofile, user_rules)
    atoll_user_rules = {}
    for _, entry in ipairs(ok and type(list) == "table" and list or {}) do
        -- One broken rule must not stop the others, or the rest of the config.
        local made, rule = pcall(function() return hl.window_rule(entry.rule) end)
        if made and entry.app then
            atoll_user_rules[entry.app] = rule
        end
    end
end
