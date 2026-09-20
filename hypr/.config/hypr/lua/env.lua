-- Environment variables for apps launched from Hyprland (set before the display server starts).
hl.env("XCURSOR_SIZE",    "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Tell toolkits to use Wayland natively (fall back to X11/xwayland if needed)
hl.env("QT_QPA_PLATFORM",                    "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME",               "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND",                        "wayland,x11,*")
hl.env("MOZ_ENABLE_WAYLAND",                 "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT",       "auto")

-- Session type hints for portals/screensharing
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE",    "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
