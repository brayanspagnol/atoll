-- Tell toolkits and apps they are running on Wayland.
for name, value in pairs({
    XDG_CURRENT_DESKTOP = "Hyprland",
    XDG_SESSION_TYPE = "wayland",
    XDG_SESSION_DESKTOP = "Hyprland",
    QT_QPA_PLATFORM = "wayland;xcb",
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
    MOZ_ENABLE_WAYLAND = "1",
    ELECTRON_OZONE_PLATFORM_HINT = "auto",
    XCURSOR_SIZE = "24",
}) do
    hl.env(name, value)
end
