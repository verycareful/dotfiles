# Themes

Colours live in `themes/<name>.theme` (one `key=hex` per line) and are rendered
into every app by `scripts/.local/bin/theme` from `themes/templates/`.
Generated files are git-ignored (install.sh renders them) and carry a "GENERATED"
header — edit the template or the theme, never the generated copy.

```sh
theme list            # dusk, dusk-light, harbour, harbour-light, mono, mono-light
theme set mono        # render + live reload (wallpaper, Hyprland, Waybar, Quickshell, open kitty windows)
theme window          # the theme window (SUPER+Shift+T): a preview card per theme, dark and light side by side
theme toggle          # next theme
theme light           # light half of the current pair (dusk -> dusk-light); `theme dark` goes back
theme pick            # rofi menu
theme check           # validate every theme against every template (test/lint.sh runs it)
```
`theme set` checks the theme first and writes nothing if anything is wrong.
GTK and Qt apps read their colours at launch, so they change on next start.

## Roles

| Key             | Use                                                   |
|-----------------|-------------------------------------------------------|
| base            | deepest background (terminal, bar tint)               |
| mantle          | panels, popups                                        |
| surface         | cards, hovered rows, inactive borders                 |
| overlay         | dividers, muted chrome                                |
| primary         | primary tint: focused workspace pill, selection glass |
| primary_bright  | links, ANSI blue, hover of primary                    |
| accent          | the accent: active border, caret, urgent, active icon |
| accent_dim      | pressed / secondary accent                            |
| text / subtext / muted | text hierarchy                                  |
| red / green / yellow   | error / ok / warning — kept in every theme       |
| magenta, cyan, *_bright | terminal ANSI only                              |

Besides the colours every theme sets `name` (the file name), `wallpaper` (a file in `wallpapers/`), `cursor`
and `mode` (`dark` or `light`). Templates never branch on `mode`; they name the values that follow from it:
`{{gtk_theme}}`, `{{gtk_prefer_dark}}`, `{{icon_theme}}`, `{{color_scheme}}` (see `MODES` in `themes/render.py`).
`theme set` also sets GNOME's `color-scheme` from `mode`, so libadwaita apps switch while running.

A few colours are derived rather than set (see `MODE_ROLES` and `values()` in `themes/render.py`):
- `on_accent`: text and icons on an accent fill (urgent workspace, calendar day, buttons). The theme may set it;
  otherwise it is `base` or `text`, whichever contrasts more with `accent`.
- `ansi_black`, `ansi_white` and their `_bright` forms: ANSI 0, 7, 8 and 15. In a light theme black stays dark
  (`subtext`, `muted`) and white stays light (`overlay`, `surface`).
- `qt_light`, `qt_midlight`, `qt_mid`, `qt_dark`: Qt's bevel shades, lightest to darkest in either mode.

### Light themes
Every dark theme has a light sibling named `<name>-light`, with the same roles turned over: `base` is the lightest
background and `text` the darkest, `primary` is a pale selection tint and `primary_bright` the strong colour for
links. Feedback and ANSI colours are darker so they read on white. The tests hold every theme to WCAG AA for body
text on each background (4.5:1) and 3:1 for `on_accent` on `accent`.

## Harbour
Near-black with a royal-blue tint; primary `#1f3799` / `#3b5fe0`, accent orange `#ff8c32`.

## Mono
Pure greys; primary `#6e6e6e` / `#a3a3a3`, accent white `#ffffff`. Green/red feedback unchanged.

## Dusk
Black base `#000000`; primary dark grey `#2c3139` / `#a3abb5`, accent blue `#0660c6`. Wallpaper `dusk.jpg` (mountain photo), cursor Bibata-Modern-Ice, `glass=0.95`, `on_accent=000000` (black on the blue). Feedback colours unchanged.

## Harbour Light, Mono Light, Dusk Light
Blue-white `#f5f7fc` with royal-blue links `#1f3fbf` and orange `#e0670f`; white with black accent; near-white
`#f7f7f8` with grey `#4f5866` and the same blue `#0660c6`. Each keeps its sibling's wallpaper; mono-light and
dusk-light use the black Bibata-Modern-Classic cursor.

Glass: surfaces use mantle/base at 55–78 % alpha with Hyprland blur behind.
A theme may set `glass=0.95` (opacity of the mantle-based surfaces: panels, cards, Waybar, rofi, wlogout, hyprlock input, kitty);
without it each template falls back to its own value via `{{glass|0.74}}`. `{{glass_hex}}` is the same value as an alpha byte for `rgba(hexAA)`.
Selection tints and inset fields (primary/base glass) keep their own alpha.
To add a theme: copy a `.theme` file, change the values, add a wallpaper to `wallpapers/`, run `theme check`.
