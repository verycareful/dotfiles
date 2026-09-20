-- hl.layer_rule({ match = { namespace = REGEX }, effect = value })  — layer-shell surfaces (bars, menus)
-- Blur behind the glass surfaces; ignore_alpha stops fully transparent pixels from being blurred.
local glass = "^(waybar|rofi|qs-notif-center|qs-notif-popups|qs-panel|qs-switcher|logout_dialog)$"
hl.layer_rule({ match = { namespace = glass },          blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "^(selection)$" }, no_anim = true })
