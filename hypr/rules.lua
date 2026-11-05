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

-- Selection overlays must appear instantly.
hl.layer_rule({ match = { namespace = "selection" }, no_anim = true })
