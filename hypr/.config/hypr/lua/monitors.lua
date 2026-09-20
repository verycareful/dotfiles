-- hl.monitor({ output, mode, position, scale })   — see `hyprctl monitors all`
-- Your display: DP-3, 2560x1440 at 165 Hz, no scaling.
hl.monitor({ output = "DP-3", mode = "2560x1440@165", position = "0x0", scale = 1 })
-- Fallback for anything else plugged in (and for the nested test window):
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
