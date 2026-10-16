-- Screen capture permissions from the permissions window. `perms apply` writes the rules to
-- ~/.local/state/perms/hyprland.lua; until it has run once there is nothing to load, and Hyprland
-- keeps its default (no enforcement).
local rules = os.getenv("HOME") .. "/.local/state/perms/hyprland.lua"
local chunk = loadfile(rules)
if chunk then chunk() end
