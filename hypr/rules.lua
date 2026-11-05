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
