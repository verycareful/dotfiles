-- hl.monitor({ output, mode, position, scale })   — see `hyprctl monitors all`
-- Your display: LG UltraGear, 2560x1440 at 165 Hz, no scaling. Matched by description,
-- not port name, so it applies on any DP port. A monitor no rule matches gets "preferred",
-- which for this panel is the EDID's 120 Hz mode, not 165.
hl.monitor({ output = "desc:LG Electronics LG ULTRAGEAR 305NTZN0P013", mode = "2560x1440@165", position = "0x0", scale = 1 })
-- Fallback for anything else plugged in (and for the nested test window):
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
