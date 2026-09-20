-- hl.bind("MODS + KEY", dispatcher | function, { flags })
-- Flags: repeating (hold to repeat), locked (works on lockscreen), release (fires on key-up), mouse
-- Dispatchers: hl.dsp.* — see /usr/share/hypr/stubs/hl.meta.lua and `hyprctl binds`
-- Every bind gets a description: SUPER+/ (keyhint) lists them, since `hyprctl binds` only shows "__lua" otherwise.
local mod      = "SUPER"
local term     = "kitty"
local browser  = "firefox"
local files    = "thunar"
local launcher = "rofi -show drun"
local editor   = "code"

-- bind("KEYS", dsp, "what it does", { flags })  → SUPER + KEYS
-- gbind("KEYS", …)                              → KEYS as written (no SUPER)
local function gbind(keys, dsp, desc, opts)
    opts = opts or {}; opts.description = desc
    return hl.bind(keys, dsp, opts)
end
local function bind(keys, dsp, desc, opts) return gbind(mod .. " + " .. keys, dsp, desc, opts) end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end

-- ── Apps ─────────────────────────────────────────────────────
bind("Return",         run(term),     "terminal")
bind("B",              run(browser),  "browser")
bind("E",              run(files),    "file manager")
bind("C",              run(editor),   "editor")
bind("Space",          run(launcher), "app launcher")
bind("V",              run("~/.local/bin/clip"),          "clipboard history (Alt+D delete, Alt+X clear)")
bind("SHIFT + N",      run("qs ipc call notifs toggle"),  "notification centre")
bind("A",              run("qs ipc call panel toggle"),   "widget panel")
bind("SHIFT + T",      run("~/.local/bin/theme toggle"),  "toggle theme (harbour/mono)")
bind("Escape",         run("hyprlock"),                   "lock screen")
bind("SHIFT + Escape", run("wlogout -b 5 -T 520 -B 520 -L 440 -R 440"), "power menu")
bind("slash",          run("~/.local/bin/keyhint"),       "this cheatsheet")

-- ── Screenshots (grim + slurp + satty) ───────────────────────
gbind("Print",         run("~/.local/bin/shot area"),   "screenshot: area")
gbind("SHIFT + Print", run("~/.local/bin/shot full"),   "screenshot: full screen")
bind("Print",          run("~/.local/bin/shot window"), "screenshot: window")

-- ── Windows ──────────────────────────────────────────────────
bind("Q",         hl.dsp.window.close(),                            "close window")
bind("F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }), "fullscreen")
bind("SHIFT + F", hl.dsp.window.float(),                            "toggle floating")
bind("W",         hl.dsp.window.float(),                            "toggle floating")
bind("P",         hl.dsp.window.pseudo(),                           "pseudo-tile")
bind("T",         hl.dsp.layout("togglesplit"),                     "toggle split direction")
bind("SHIFT + P", hl.dsp.window.pin(),                              "pin (show on all workspaces)")
bind("SHIFT + Q", hl.dsp.exit(),                                    "exit Hyprland")

-- Alt-Tab: Quickshell switcher (all windows, MRU, thumbnails); releasing Alt focuses the highlighted one
gbind("ALT + Tab",         run("qs ipc call switcher next"),  "alt-tab: next window")
gbind("ALT + SHIFT + Tab", run("qs ipc call switcher prev"),  "alt-tab: previous window")
gbind("ALT + Alt_L",       run("qs ipc call switcher apply"), "alt-tab: go", { release = true })
gbind("ALT + Alt_R",       run("qs ipc call switcher apply"), "alt-tab: go", { release = true })
gbind("ALT + Escape",      run("qs ipc call switcher cancel"), "alt-tab: cancel")

-- Focus / move (arrows + vim keys)
local dirs = {
    { "left", "left" }, { "right", "right" }, { "up", "up" }, { "down", "down" },
    { "H", "left" },    { "L", "right" },     { "K", "up" }, { "J", "down" },
}
for _, d in ipairs(dirs) do
    local key, dir = d[1], d[2]
    bind(key,               hl.dsp.focus({ direction = dir }),       "focus " .. dir)
    bind("SHIFT + " .. key, hl.dsp.window.move({ direction = dir }), "move window " .. dir)
end
-- Resize (hold to repeat)
local hold = { repeating = true }
bind("CTRL + left",  hl.dsp.window.resize({ x = -40, y =   0, relative = true }), "resize: narrower", hold)
bind("CTRL + right", hl.dsp.window.resize({ x =  40, y =   0, relative = true }), "resize: wider",    hold)
bind("CTRL + up",    hl.dsp.window.resize({ x =   0, y = -40, relative = true }), "resize: shorter",  hold)
bind("CTRL + down",  hl.dsp.window.resize({ x =   0, y =  40, relative = true }), "resize: taller",   hold)

-- Mouse: drag to move / resize
bind("mouse:272", hl.dsp.window.drag(),   "drag window (LMB)",   { mouse = true })
bind("mouse:273", hl.dsp.window.resize(), "resize window (RMB)", { mouse = true })

-- ── Workspaces ───────────────────────────────────────────────
for i = 1, 10 do
    local key = tostring(i % 10)                       -- 10 → key 0
    bind(key,            hl.dsp.focus({ workspace = i }),                     "workspace " .. i)
    bind("SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }), "move window to workspace " .. i)
end
bind("Tab",        hl.dsp.focus({ workspace = "previous" }),  "previous workspace")
bind("mouse_down", hl.dsp.focus({ workspace = "e+1" }),       "next workspace (scroll)")
bind("mouse_up",   hl.dsp.focus({ workspace = "e-1" }),       "previous workspace (scroll)")
bind("S",          hl.dsp.workspace.toggle_special("scratch"), "toggle scratchpad")
bind("SHIFT + S",  hl.dsp.window.move({ workspace = "special:scratch", follow = true }), "move window to scratchpad")
-- "close to tray": hide the window (keeps running) / pick a hidden one to bring back
bind("M",          hl.dsp.window.move({ workspace = "special:tray", follow = false }), "hide window to tray")
bind("SHIFT + M",  run("~/.local/bin/untray"),                                        "restore window from tray")

-- ── Hardware keys ────────────────────────────────────────────
local held = { repeating = true, locked = true }
local lock = { locked = true }
gbind("XF86AudioRaiseVolume",  run("pamixer -i 5"),                "volume up",        held)
gbind("XF86AudioLowerVolume",  run("pamixer -d 5"),                "volume down",      held)
gbind("XF86AudioMute",         run("pamixer -t"),                  "mute",             lock)
gbind("XF86AudioMicMute",      run("pamixer --default-source -t"), "mute microphone",  lock)
gbind("XF86MonBrightnessUp",   run("brightnessctl set +5%"),       "brightness up",    held)
gbind("XF86MonBrightnessDown", run("brightnessctl set 5%-"),       "brightness down",  held)
gbind("XF86AudioPlay",         run("playerctl play-pause"),        "media play/pause", lock)
gbind("XF86AudioNext",         run("playerctl next"),              "media next",       lock)
gbind("XF86AudioPrev",         run("playerctl previous"),          "media previous",   lock)
