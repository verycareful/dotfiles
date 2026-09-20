hl.config({
    input = {
        kb_layout          = "us",
        follow_mouse       = 1,        -- focus follows mouse, but clicking still focuses
        sensitivity        = 0,        -- -1.0 .. 1.0, 0 = no change
        accel_profile      = "flat",   -- no mouse acceleration (gaming-friendly)
        repeat_rate        = 40,
        repeat_delay       = 300,
        numlock_by_default = true,
        touchpad = {
            natural_scroll = true,
            tap_to_click   = true,
        },
    },
})

-- Trackpad gestures: hl.gesture({ fingers, direction, action, ... })
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "pinchin",    action = "float", mode = "tile"  })
hl.gesture({ fingers = 3, direction = "pinchout",   action = "float", mode = "float" })
