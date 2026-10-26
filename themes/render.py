#!/usr/bin/env python3
"""render.py: fill themes/templates with a theme's values. Called by scripts/.local/bin/theme.
  render.py all THEME CFG         check THEME, then render every template in TARGETS under CFG
  render.py one THEME TEMPLATE    print one template rendered (VS Code, Firefox, SDDM)
  render.py check [THEME...]      validate themes (default: all) against every template
  render.py json                  every theme's name, mode, colours and wallpaper path as JSON (the theme window)
THEME is a name (themes/NAME.theme) or a path to a .theme file.
A template names a value as {{key}}, or {{key|fallback}} when a theme may leave the key out."""
import json
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
THEMES = REPO / 'themes'
TEMPLATES = THEMES / 'templates'
WALLPAPERS = REPO / 'wallpapers'

# Every theme sets these; palette.md describes the colour roles.
META = ('name', 'mode', 'wallpaper', 'cursor')
COLOURS = ('base', 'mantle', 'surface', 'overlay', 'primary', 'primary_bright', 'accent', 'accent_dim',
           'text', 'subtext', 'muted', 'red', 'green', 'yellow', 'magenta', 'cyan',
           'red_bright', 'green_bright', 'yellow_bright', 'blue_bright', 'magenta_bright', 'cyan_bright')

# Colours a theme may set; values() derives them otherwise.
OPTIONAL_COLOURS = ('on_accent',)

# Values that follow from mode, so templates name them instead of branching on it.
MODES = {
    'dark':  {'gtk_theme': 'adw-gtk3-dark', 'gtk_prefer_dark': '1', 'icon_theme': 'Papirus-Dark',
              'color_scheme': 'prefer-dark'},
    'light': {'gtk_theme': 'adw-gtk3', 'gtk_prefer_dark': '0', 'icon_theme': 'Papirus',
              'color_scheme': 'prefer-light'},
}

# Colour roles whose meaning flips with mode: each name is set to the value of the named key. ANSI black and white
# stay dark and light on either background; Qt's bevel shades keep Light lighter than Dark.
MODE_ROLES = {
    'dark':  {'ansi_black': 'surface', 'ansi_black_bright': 'overlay', 'ansi_white': 'subtext', 'ansi_white_bright': 'text',
              'qt_light': 'overlay', 'qt_midlight': 'surface', 'qt_mid': 'mantle', 'qt_dark': 'base'},
    'light': {'ansi_black': 'subtext', 'ansi_black_bright': 'muted', 'ansi_white': 'overlay', 'ansi_white_bright': 'surface',
              'qt_light': 'base', 'qt_midlight': 'mantle', 'qt_mid': 'surface', 'qt_dark': 'overlay'},
}

TARGETS = {  # template -> destination(s) under $XDG_CONFIG_HOME
    'hypr/colors.lua':    ['hypr/lua/colors.lua'],
    'hypr/cursor.lua':    ['hypr/lua/cursor.lua'],
    'hypr/colors.conf':   ['hypr/conf.d/colors.conf'],   # hyprlang set, kept for `restore.sh hypr`
    'hypr/cursor.conf':   ['hypr/conf.d/cursor.conf'],
    'hypr/hyprlock.conf': ['hypr/hyprlock.conf'],
    'hypr/hyprtoolkit.conf': ['hypr/hyprtoolkit.conf'],
    'waybar/colors.css':  ['waybar/colors.css'],
    'quickshell/Theme.qml': ['quickshell/Theme.qml'],
    'wlogout/colors.css': ['wlogout/colors.css'],
    'rofi/colors.rasi':   ['rofi/themes/colors.rasi'],
    'kitty/colors.conf':  ['kitty/colors.conf'],
    'gtk/gtk.css':        ['gtk-3.0/gtk.css', 'gtk-4.0/gtk.css'],
    'gtk/settings.ini':   ['gtk-3.0/settings.ini', 'gtk-4.0/settings.ini'],
    'qt/colors.conf':     ['qt6ct/colors/current.conf', 'qt5ct/colors/current.conf'],
    'fish/colors.fish':   ['fish/conf.d/colors.fish'],
    'starship.toml':      ['starship.toml'],
    'fastfetch/config.jsonc': ['fastfetch/config.jsonc'],
    'btop/dotfiles.theme': ['btop/themes/dotfiles.theme'],
    'vesktop/dotfiles.theme.css': ['vesktop/themes/dotfiles.theme.css'],
}

HEX = re.compile(r'[0-9a-fA-F]{6}')
PLACEHOLDER = re.compile(r'\{\{(\w+)(?:\|([^}]*))?\}\}')


def theme_path(arg):
    return Path(arg) if arg.endswith('.theme') else THEMES / f'{arg}.theme'


def load(path):
    """key=value lines; '#' starts a comment."""
    raw = {}
    for line in Path(path).read_text().splitlines():
        line = line.split('#', 1)[0].strip()
        if '=' in line:
            k, val = line.split('=', 1)
            raw[k.strip()] = val.strip()
    return raw


def luminance(hexval):
    """WCAG relative luminance of a six-digit hex colour."""
    def channel(c):
        c = int(c, 16) / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(hexval[i:i + 2]) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def values(raw):
    """The theme's own keys plus the derived ones: the MODE_ROLES colours, on_accent (text drawn on an accent
    fill: the theme's own, else whichever of base and text contrasts more with accent), x_rgb ('r, g, b' for
    rgba()) and x_ansi ('38;2;r;g;b') for every hex value, glass_hex (glass as an alpha byte for rgba(hexAA))
    and the MODES set."""
    v = dict(raw)
    v.update({role: raw[k] for role, k in MODE_ROLES.get(raw.get('mode'), {}).items() if k in raw})
    if 'on_accent' not in raw and all(HEX.fullmatch(raw.get(k, '')) for k in ('accent', 'base', 'text')):
        v['on_accent'] = max(('base', 'text'), key=lambda k: contrast(raw[k], raw['accent']))
        v['on_accent'] = raw[v['on_accent']]
    for k, val in list(v.items()):
        if HEX.fullmatch(val):
            rgb = [str(int(val[i:i + 2], 16)) for i in (0, 2, 4)]
            v[k + '_rgb'] = ', '.join(rgb)
            v[k + '_ansi'] = '38;2;' + ';'.join(rgb)
    if 'glass' in raw:
        v['glass_hex'] = '%02x' % round(float(raw['glass']) * 255)
    v.update(MODES.get(raw.get('mode'), {}))
    return v


def fill(text, v):
    """Template text with placeholders replaced, and the keys that had neither a value nor a fallback."""
    missing = set()

    def sub(m):
        k, fallback = m.groups()
        if k in v:
            return v[k]
        if fallback is not None:
            return fallback
        missing.add(k)
        return m.group(0)
    return PLACEHOLDER.sub(sub, text), missing


def templates(root=TEMPLATES):
    return sorted(p for p in Path(root).rglob('*') if p.is_file())


def problems(path, tpl_root=TEMPLATES, wallpapers=WALLPAPERS):
    """Everything wrong with one theme file, as readable lines; empty when it renders cleanly."""
    path = Path(path)
    if not path.is_file():
        return [f'no such theme: {path.stem}']
    raw = load(path)
    absent = [k for k in META + COLOURS if k not in raw]
    out = [f'missing key: {k}' for k in absent]
    out += [f'{k}={raw[k]} is not six hex digits' for k in COLOURS + OPTIONAL_COLOURS
            if k in raw and not HEX.fullmatch(raw[k])]
    if 'name' in raw and raw['name'] != path.stem:
        out.append(f'name={raw["name"]} does not match the file name {path.name}')
    if 'mode' in raw and raw['mode'] not in MODES:
        out.append(f'mode={raw["mode"]} is not one of {", ".join(MODES)}')
    if 'wallpaper' in raw and not (Path(wallpapers) / raw['wallpaper']).is_file():
        out.append(f'wallpaper {raw["wallpaper"]} is not in {Path(wallpapers).name}/')
    if 'glass' in raw:
        try:
            ok = 0 <= float(raw['glass']) <= 1
        except ValueError:
            ok = False
        if not ok:
            out.append(f'glass={raw["glass"]} is not a number from 0 to 1')
            raw = {k: val for k, val in raw.items() if k != 'glass'}
    v = values(raw)
    for tpl in templates(tpl_root):
        _, missing = fill(tpl.read_text(), v)
        out += [f'{tpl.relative_to(tpl_root)} needs {k}' for k in sorted(missing) if k not in absent]
    return out


def render_all(path, cfg, tpl_root=TEMPLATES, wallpapers=WALLPAPERS):
    """Write every TARGETS file under cfg. A theme with problems writes nothing."""
    bad = problems(path, tpl_root, wallpapers)
    if bad:
        return bad
    v = values(load(path))
    for src, dsts in TARGETS.items():
        text, _ = fill((Path(tpl_root) / src).read_text(), v)
        for d in dsts:
            p = os.path.join(cfg, d)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            Path(p).write_text(text)
    return []


def catalogue(wall_dir):
    """Every theme as a dict of its META, COLOURS and on_accent values, with the wallpaper as a path: the copy in
    wall_dir when there is one, else the repo's."""
    out = []
    for p in sorted(THEMES.glob('*.theme')):
        v = values(load(p))
        entry = {k: v.get(k, '') for k in META + COLOURS + OPTIONAL_COLOURS}
        wp = Path(wall_dir) / entry['wallpaper']
        entry['wallpaper'] = str(wp if wp.is_file() else WALLPAPERS / entry['wallpaper'])
        out.append(entry)
    return out


def report(name, bad):
    for line in bad:
        print(f'{name}: {line}', file=sys.stderr)
    return 1 if bad else 0


def main(argv):
    cmd, args = (argv[0], argv[1:]) if argv else ('', [])
    if cmd == 'all' and len(args) == 2:
        return report(args[0], render_all(theme_path(args[0]), args[1]))
    if cmd == 'one' and len(args) == 2:
        path = theme_path(args[0])
        if not path.is_file():
            return report(args[0], [f'no such theme: {args[0]}'])
        text, _ = fill(Path(args[1]).read_text(), values(load(path)))
        print(text, end='')
        return 0
    if cmd == 'check':
        names = args or sorted(p.stem for p in THEMES.glob('*.theme'))
        failed = sum(report(n, problems(theme_path(n))) for n in names)
        if not failed:
            print(f'{len(names)} themes ok against {len(templates())} templates')
        return 1 if failed else 0
    if cmd == 'json' and not args:
        wall_dir = os.environ.get('WALL_DIR', os.path.expanduser('~/Pictures/Wallpapers'))
        print(json.dumps(catalogue(wall_dir)))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
