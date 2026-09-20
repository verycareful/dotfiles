-- hl.window_rule({ match = { class = REGEX, title = REGEX, … }, effect = value, … })
-- Find a window's class/title with:  hyprctl clients

-- Float small utility windows
local utils = "^(pavucontrol|nwg-look|qt5ct|qt6ct|nm-connection-editor|blueman-manager|io.github.ilya_zlobintsev.LACT)$"
hl.window_rule({ match = { class = utils },                         float  = true })
hl.window_rule({ match = { class = "^(pavucontrol)$" },             size   = { 900, 600 } })
hl.window_rule({ match = { class = "^(pavucontrol|nwg-look|qt5ct|qt6ct|io.github.ilya_zlobintsev.LACT)$" }, center = true })
hl.window_rule({ match = { class = "^(io.github.ilya_zlobintsev.LACT)$" }, size = { 1100, 760 } })

-- File pickers / dialogs
local dialogs = "^(Open File|Save File|Open Folder|Select .*)$"
hl.window_rule({ match = { title = dialogs }, float = true, center = true })

-- Picture-in-picture always on top
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true })

-- Fix xwayland drag-n-drop ghosts
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Smart gaps: a lone tiled window (w[tv1]) or a fullscreen one (f[1]) fills the space
-- (border stays as a focus cue)
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
