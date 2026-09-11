# Themes

Colours live in `themes/<name>.theme` (one `key=hex` per line) and are rendered
into every app by `scripts/.local/bin/theme` from `themes/templates/`.
Generated files carry a "GENERATED" header — edit the template or the theme,
never the generated copy.

```sh
theme list            # harbour, mono
theme set mono        # render + live reload (wallpaper, Hyprland, Waybar, swaync, open kitty windows)
theme toggle          # next theme  (SUPER+Shift+T)
theme pick            # rofi menu
```
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

## Harbour
Near-black with a royal-blue tint; primary `#1f3799` / `#3b5fe0`, accent orange `#ff8c32`.

## Mono
Pure greys; primary `#6e6e6e` / `#a3a3a3`, accent white `#ffffff`. Green/red feedback unchanged.

Glass: surfaces use mantle/base at 55–78 % alpha with Hyprland blur behind.
To add a theme: copy a `.theme` file, change the values, add a wallpaper to `wallpapers/`.
