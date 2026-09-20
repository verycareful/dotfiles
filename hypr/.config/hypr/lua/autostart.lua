-- hyprland.start fires once at launch (the old exec-once).
-- A bare hl.exec_cmd() at file top level runs on every config reload instead (the old exec).
-- waybar/swaync/hypridle/… run as user units (systemd restarts them if they crash); see session-start
hl.on("hyprland.start", function()
    hl.exec_cmd("~/.local/bin/session-start")
    hl.exec_cmd("awww-daemon --no-cache")
    hl.exec_cmd("~/.local/bin/wall set")          -- waits for awww-daemon itself
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("easyeffects --gapplication-service")
end)
