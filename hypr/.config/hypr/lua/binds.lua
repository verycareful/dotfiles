-- hl.bind("MODS + KEY", dispatcher | function, { flags })
-- Flags: repeating (hold to repeat), locked (works on lockscreen), release (fires on key-up), mouse
-- Dispatchers: hl.dsp.* — see /usr/share/hypr/stubs/hl.meta.lua and `hyprctl binds`
-- Every bind gets a description: SUPER+/ (keyhint) lists them, since `hyprctl binds` only shows "__lua" otherwise.
--
-- SUPER + a letter or digit goes to the workspace with that station key (quickshell/services/Station.qml); window
-- and app actions sit on SUPER + SHIFT. A tap of SUPER alone opens the station.
local mod      = "SUPER"
local term     = "kitty"
local browser  = "firefox"
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
-- Apps start through station-launch, which keeps their windows on the workspace they were started from and passes
-- them through the permissions launch gate.
local function app(cmd) return run("~/.local/bin/station-launch " .. cmd) end
local function station(cmd) return run("qs ipc call station " .. cmd) end

-- ── Station ──────────────────────────────────────────────────
-- The tap: a release bind on SUPER itself fires only when no other key was pressed while SUPER was held.
gbind("SUPER + SUPER_L", station("toggle"), "Station: workspaces around the dashboard", { release = true })
local letters = "BCDEFGHIJKLMNOPRSUVWXYZ"   -- every letter but Q (close window) and the T and A prefixes
for i = 1, #letters do
    local key = letters:sub(i, i)
    bind(key, station("jump " .. key), "Go to station key " .. key)
end
for i = 0, 9 do
    bind(tostring(i), station("jump " .. i), "Go to Mix workspace " .. i)
end
-- Terminals and shots: SUPER+T or SUPER+A opens the station with the letter typed; the station takes the number.
bind("T", station("prefix T"), "Terminals: open the station, then a number")
bind("A", station("prefix A"), "Shots: open the station, then a number")
-- Move only the focused window: hold Home, press Shift + the target's key. Home still reaches the app, and a
-- Home release ends the hold.
hl.define_submap("station-move", function()
    local keys = letters .. "0123456789"
    for i = 1, #keys do
        local key = keys:sub(i, i)
        gbind("SHIFT + " .. key, function()
            hl.dispatch(station("move " .. key))
            hl.dispatch(hl.dsp.submap("reset"))
        end, "Move the focused window to station key " .. key)
    end
    gbind("Home", hl.dsp.submap("reset"), "End the move hold", { release = true, non_consuming = true })
end)
gbind("Home", hl.dsp.submap("station-move"), "Hold to move a window (then Shift + its key)", { non_consuming = true })

-- ── Apps ─────────────────────────────────────────────────────
bind("Return",         app(term),     "Terminal")
bind("Space",          run(launcher), "App launcher")
bind("ALT + F",        app(browser),          "Firefox")
bind("ALT + C",        app("claude-desktop"), "Claude")
bind("ALT + V",        app(editor),           "VS Code")
bind("ALT + O",        app("spotify"),        "Spotify")
bind("ALT + D",        app("discord"),        "Discord")
bind("ALT + G",        app("signal-desktop"), "Signal")
bind("SHIFT + V",      run("~/.local/bin/clip"),          "Clipboard history (Alt+D delete, Alt+X clear)")
bind("SHIFT + X",      run("~/.local/bin/actions"),       "Actions menu (theme, wallpaper, record, snapshot, firewall, restarts)")
bind("period",         run("rofimoji --action copy"),     "Emoji picker (copies)")
bind("SHIFT + C",      run("rofi -show calc -modi calc -no-show-match -no-sort -calc-command 'echo -n {result} | wl-copy'"), "Calculator (Enter copies the result)")
bind("comma",          run("qs ipc call settings toggle"), "Settings")
bind("Escape",         run("~/.local/bin/lockscreen"),    "Lock screen")
bind("SHIFT + Escape", run("wlogout -b 5 -T 520 -B 520 -L 440 -R 440"), "Power menu")
bind("slash",          run("~/.local/bin/keyhint"),       "This cheatsheet")

-- ── Screenshots (grim + slurp + satty) ───────────────────────
gbind("Print",         run("~/.local/bin/shot area"),   "Screenshot: area")
gbind("SHIFT + Print", run("~/.local/bin/shot full"),   "Screenshot: full screen")
bind("Print",          run("~/.local/bin/shot window"), "Screenshot: window")
-- ── Screen recording (gpu-screen-recorder): the same key again stops ──
gbind("ALT + Print",         run("~/.local/bin/screenrec area"),        "Record: area (again to stop)")
gbind("ALT + SHIFT + Print", run("~/.local/bin/screenrec full"),        "Record: full screen (again to stop)")
bind("ALT + Print",          run("~/.local/bin/screenrec window"),      "Record: window (again to stop)")
gbind("CTRL + ALT + Print",  run("~/.local/bin/screenrec area --mic"),  "Record: area with microphone")
bind("SHIFT + R",            run("~/.local/bin/screenrec replay"),      "Instant replay on/off (last 60 s)")
bind("ALT + R",              run("~/.local/bin/screenrec save"),        "Instant replay: save")

-- ── Windows ──────────────────────────────────────────────────
bind("Q",         hl.dsp.window.close(),                            "Close window")
bind("SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Fullscreen")
bind("SHIFT + W", hl.dsp.window.float(),                            "Toggle floating")
bind("SHIFT + P", hl.dsp.window.pseudo(),                           "Pseudo-tile")
bind("SHIFT + T", hl.dsp.layout("togglesplit"),                     "Toggle split direction")
bind("SHIFT + M", hl.dsp.window.move({ workspace = "special:tray", follow = false }), "Hide window (Hidden, in the station)")

-- Alt-Tab: Quickshell switcher (all windows, MRU, thumbnails); releasing Alt focuses the highlighted one.
-- The release is read from the raw key event, not a release bind: once Tab has been pressed under Alt,
-- a release bind on Alt_L/Alt_R never fires (with or without ignore_mods), so the popup would stay open.
-- The event arrives as (xkb keycode, time_ms, state) with state 0 = released.
local ALT_KEYCODES = { [64] = true, [108] = true }   -- Alt_L, Alt_R
local switching = false                              -- set by Alt-Tab so plain Alt releases cost nothing
local function switcher(cmd, opening)
    return function()
        switching = opening
        hl.dispatch(run("qs ipc call switcher " .. cmd))
    end
end
gbind("ALT + Tab",         switcher("next", true),     "Alt-Tab: next window")
gbind("ALT + SHIFT + Tab", switcher("prev", true),     "Alt-Tab: previous window")
gbind("ALT + Escape",      switcher("cancel", false),  "Alt-Tab: cancel")
hl.on("input.keyboard.key", function(keycode, _, state)
    if switching and state == 0 and ALT_KEYCODES[keycode] then switcher("apply", false)() end
end)

-- Focus on the arrows; move a window with Shift + an arrow or a vim key. Plain SUPER + a vim key is a station key.
local dirs = { { "left", "left" }, { "right", "right" }, { "up", "up" }, { "down", "down" } }
for _, d in ipairs(dirs) do
    bind(d[1], hl.dsp.focus({ direction = d[2] }), "Focus " .. d[2])
end
local moves = {
    { "left", "left" }, { "right", "right" }, { "up", "up" }, { "down", "down" },
    { "H", "left" },    { "L", "right" },     { "K", "up" }, { "J", "down" },
}
for _, d in ipairs(moves) do
    bind("SHIFT + " .. d[1], hl.dsp.window.move({ direction = d[2] }), "Move window " .. d[2])
end
-- Resize (hold to repeat)
local hold = { repeating = true }
bind("CTRL + left",  hl.dsp.window.resize({ x = -40, y =   0, relative = true }), "Resize: narrower", hold)
bind("CTRL + right", hl.dsp.window.resize({ x =  40, y =   0, relative = true }), "Resize: wider",    hold)
bind("CTRL + up",    hl.dsp.window.resize({ x =   0, y = -40, relative = true }), "Resize: shorter",  hold)
bind("CTRL + down",  hl.dsp.window.resize({ x =   0, y =  40, relative = true }), "Resize: taller",   hold)

-- Mouse: drag to move / resize
bind("mouse:272", hl.dsp.window.drag(),   "Drag window (LMB)",   { mouse = true })
bind("mouse:273", hl.dsp.window.resize(), "Resize window (RMB)", { mouse = true })

-- ── Workspaces ───────────────────────────────────────────────
bind("Tab",        hl.dsp.focus({ workspace = "previous" }),  "Previous workspace")
bind("mouse_down", hl.dsp.focus({ workspace = "e+1" }),       "Next workspace (scroll)")
bind("mouse_up",   hl.dsp.focus({ workspace = "e-1" }),       "Previous workspace (scroll)")

-- ── Hardware keys ────────────────────────────────────────────
local held = { repeating = true, locked = true }
local lock = { locked = true }
gbind("XF86AudioRaiseVolume",  run("pamixer -i 5"),                "Volume up",        held)
gbind("XF86AudioLowerVolume",  run("pamixer -d 5"),                "Volume down",      held)
gbind("XF86AudioMute",         run("pamixer -t"),                  "Mute",             lock)
gbind("XF86AudioMicMute",      run("pamixer --default-source -t"), "Mute microphone",  lock)
gbind("XF86MonBrightnessUp",   run("brightnessctl set +5% && qs ipc call osd brightness"), "Brightness up",   held)
gbind("XF86MonBrightnessDown", run("brightnessctl set 5%- && qs ipc call osd brightness"), "Brightness down", held)
gbind("XF86AudioPlay",         run("playerctl play-pause"),        "Media play/pause", lock)
gbind("XF86AudioNext",         run("playerctl next"),              "Media next",       lock)
gbind("XF86AudioPrev",         run("playerctl previous"),          "Media previous",   lock)
