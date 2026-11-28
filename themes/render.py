#!/usr/bin/env python3
"""render.py: fill themes/templates with a theme's values. Called by scripts/.local/bin/theme.
  render.py all THEME CFG         check THEME, then render every template in TARGETS under CFG
  render.py one THEME TEMPLATE    print one template rendered (VS Code, Firefox, SDDM)
  render.py check [THEME...]      validate themes (default: all) against every template
  render.py json                  every theme's name, mode, colours and wallpaper path as JSON (the theme window)
  render.py wallpaper THEME       the path of the image THEME shows (wallpapers/local/THEME.* first)
THEME is a name (themes/NAME.theme) or a path to a .theme file.
A template names a value as {{key}}, or {{key|fallback}} when a theme may leave the key out."""
import colorsys
import json
import math
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
THEMES = REPO / 'themes'
TEMPLATES = THEMES / 'templates'
WALLPAPERS = REPO / 'wallpapers'
LOCAL_EXTS = ('jpg', 'png', 'webp')

# Every theme sets these; palette.md describes the colour roles.
META = ('name', 'mode', 'wallpaper', 'cursor')
COLOURS = ('base', 'mantle', 'surface', 'overlay', 'primary', 'primary_bright', 'accent', 'accent_dim',
           'text', 'subtext', 'muted', 'red', 'green', 'yellow', 'magenta', 'cyan',
           'red_bright', 'green_bright', 'yellow_bright', 'blue_bright', 'magenta_bright', 'cyan_bright')

# Colours a theme may set; values() derives them otherwise.
OPTIONAL_COLOURS = ('on_accent',)

# Values that follow from mode, so templates name them instead of branching on it. dim_opacity is how strongly kitty draws faint text (Claude Code draws removed diff lines faint; the 0.4 default washes
# out dark text on a light background). scrim_alpha is how opaque the
# base-coloured scrim behind a full-screen overlay is: a light theme needs it high so dark text stays legible.
MODES = {
    'dark':  {'gtk_theme': 'adw-gtk3-dark', 'gtk_prefer_dark': '1', 'icon_theme': 'Papirus-Dark',
              'color_scheme': 'prefer-dark', 'vscode_theme': 'Default Dark Modern', 'kitty_text': 'platform',
              'gtk_rgba': 'rgb', 'scrim_alpha': '0.55', 'terminal_opacity': '0.78', 'dim_opacity': '0.4'},
    'light': {'gtk_theme': 'adw-gtk3', 'gtk_prefer_dark': '0', 'icon_theme': 'Papirus',
              'color_scheme': 'prefer-light', 'vscode_theme': 'Default Light Modern', 'kitty_text': '1.4 20',
              'gtk_rgba': 'none', 'scrim_alpha': '0.78', 'terminal_opacity': '0.68', 'dim_opacity': '0.9'},
}

# Colour roles whose meaning flips with mode: each name is set to the value of the named key. ANSI black and white
# stay dark and light on either background; Qt's bevel shades keep Light lighter than Dark; the fill_* roles are the
# colours of a selected, hovered and input-field background and on_selected the text on a selected one; ANSI blue is the
# accent on a light theme (Claude Code's light-ansi inline code is the terminal's blue) and primary_bright on a dark one.
MODE_ROLES = {
    'dark':  {'ansi_black': 'surface', 'ansi_black_bright': 'overlay', 'ansi_white': 'subtext', 'ansi_white_bright': 'text',
              'qt_light': 'overlay', 'qt_midlight': 'surface', 'qt_mid': 'mantle', 'qt_dark': 'base',
              'ansi_blue': 'primary_bright',
              'fill_selected': 'primary', 'fill_hover': 'overlay', 'fill_field': 'base', 'on_selected': 'accent'},
    'light': {'ansi_black': 'subtext', 'ansi_black_bright': 'muted', 'ansi_white': 'overlay', 'ansi_white_bright': 'surface',
              'qt_light': 'base', 'qt_midlight': 'mantle', 'qt_mid': 'surface', 'qt_dark': 'overlay',
              'ansi_blue': 'accent',
              'fill_selected': 'accent', 'fill_hover': 'overlay', 'fill_field': 'surface', 'on_selected': 'text'},
}

# The text colours Claude Code draws on a mouse selection, and the contrast each must keep. Only the background of a
# selection is themeable, so it is the strongest tint of the accent hue that leaves all of these readable.
SELECT_TEXT_CONTRAST = {'text': 7, 'subtext': 4.5, 'muted': 4.5, 'accent': 2.5}
SELECT_TEXT_CONTRAST_DARK = {**SELECT_TEXT_CONTRAST, 'muted': 3.0}  # dark themes' muted text is dim by design
SELECT_VISIBLE = 1.2  # a selection must differ at least this much from the theme's background to be seen

# Colours that get a lighter <name>_shimmer tint, for apps that animate a highlight across a colour.
SHIMMER_ROLES = ('accent', 'yellow', 'muted')
SHIMMER_MIX = 0.15  # how far the tint moves toward white: a hint of a highlight, not a different colour

# Colours that get <name>_tint, <name>_tint_strong and <name>_tint_faint: the colour's own hue and saturation at a high
# lightness on a light theme and a low one on a dark theme, for the background behind added and removed text (a pale
# wash, a stronger one for changed words, a fainter one for dimmed diffs, one for a selection). (light, dark)
# lightness for each. Claude Code's ANSI base quantises colours to the 256-colour cube, so each tint is snapped to a
# cube colour here, and what is written is what is drawn.
TINT_ROLES = ('green', 'red')
TINTS = {'tint': (0.84, 0.16), 'tint_strong': (0.77, 0.27), 'tint_faint': (0.91, 0.11)}
TINT_TEXT_CONTRAST = {'': 6, 'tint_strong': 3.5}  # the theme's text on each tint, at least
# The accent's hue and saturation at a very high (light theme) or low (dark theme) lightness, not snapped to the cube:
# the background of a large block, such as an expanded tool call, which is drawn in true colour.
ACCENT_WASH = (0.93, 0.14)
TINT_HUE_SHIFT = {'red': 14 / 360}  # the palette reds lean magenta, which reads as pink at a high lightness
TINT_SATURATION = {'red': 1.2}  # a pale red needs more saturation than a pale green to read as red

# Translucent fills for a selected item, a hovered item and an input field, laid over a card. A dark theme uses fixed
# alphas. On a light theme the selected and hover alphas are solved so each fill is a set contrast against the card
# (mantle), because the colours differ so much in strength between themes (black against orange): the selected fill
# must read clearly stronger than hover, yet text on it must stay readable.
FILL_DARK = {'select_alpha': 0.55, 'hover_alpha': 0.90, 'field_alpha': 0.55, 'empty_alpha': 0.45}
FILL_LIGHT_FIELD_ALPHA = 0.90
FILL_LIGHT_CONTRAST = {'select_alpha': 1.45, 'hover_alpha': 1.28, 'empty_alpha': 3.0}  # fill against the card

TARGETS = {  # template -> destination(s) under $XDG_CONFIG_HOME; a '~/' destination is under the home directory
    'hypr/colors.lua':    ['hypr/lua/colors.lua'],
    'hypr/cursor.lua':    ['hypr/lua/cursor.lua'],
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
    'vencord/dotfiles.theme.css': ['Vencord/themes/dotfiles.theme.css'],
    'claude/theme.json':  ['~/.claude/themes/dotfiles.json'],
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


def mix(a, b, t):
    """The hex colour t of the way from a to b (both six-digit hex)."""
    return ''.join('%02x' % round(int(a[i:i + 2], 16) * (1 - t) + int(b[i:i + 2], 16) * t) for i in (0, 2, 4))


CUBE_LEVELS = (0, 95, 135, 175, 215, 255)
CUBE_256 = ([(r, g, b) for r in CUBE_LEVELS for g in CUBE_LEVELS for b in CUBE_LEVELS]
            + [(v, v, v) for v in range(8, 239, 10)])  # the 6x6x6 cube and the 24 greys of xterm-256


def lab(rgb):
    """CIELAB of an (r, g, b) tuple of 0-255 values."""
    lin = [c / 255 / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4 for c in rgb]
    x = (0.4124 * lin[0] + 0.3576 * lin[1] + 0.1805 * lin[2]) / 0.95047
    y = 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
    z = (0.0193 * lin[0] + 0.1192 * lin[1] + 0.9505 * lin[2]) / 1.08883
    f = [t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116 for t in (x, y, z)]
    return 116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])


HUE_TOLERANCE = 25  # degrees a snapped tint may turn away from the colour it stands in for
CHROMATIC = 12      # below this CIELAB chroma a colour counts as grey and its hue is ignored


def _hue_gap(a, b):
    """Degrees between the hues of two CIELAB colours."""
    gap = abs(math.degrees(math.atan2(a[2], a[1]) - math.atan2(b[2], b[1]))) % 360
    return min(gap, 360 - gap)


def snap256(colour, keep=lambda c: True):
    """The xterm-256 colour nearest to a six-digit hex colour among those keep() accepts, as hex. A chromatic colour
    keeps its hue (within HUE_TOLERANCE) when any accepted cube colour allows it, and chroma errors cost four times
    what a lightness error does, so a green stays green rather than turning teal."""
    want = lab(tuple(int(colour[i:i + 2], 16) for i in (0, 2, 4)))
    pool = [c for c in CUBE_256 if keep(c)] or CUBE_256
    if math.hypot(want[1], want[2]) >= CHROMATIC:
        pool = [c for c in pool if math.hypot(*lab(c)[1:]) >= CHROMATIC
                and _hue_gap(lab(c), want) <= HUE_TOLERANCE] or pool

    def cost(c):
        got = lab(c)
        return (got[0] - want[0]) ** 2 + 4 * ((got[1] - want[1]) ** 2 + (got[2] - want[2]) ** 2)
    return '%02x%02x%02x' % min(pool, key=cost)


def tint(colour, lightness, hue_shift=0.0, saturation=1.0):
    """The colour with its lightness replaced, its saturation scaled and its hue turned by hue_shift (six-digit hex)."""
    h, _, sat = colorsys.rgb_to_hls(*(int(colour[i:i + 2], 16) / 255 for i in (0, 2, 4)))
    return ''.join('%02x' % round(c * 255)
                   for c in colorsys.hls_to_rgb((h + hue_shift) % 1, lightness, min(1.0, sat * saturation)))


def solve_alpha(fg, bg, target):
    """The alpha (two decimals) at which fg laid over bg first reaches the contrast target against bg."""
    for hundredths in range(2, 99):
        if contrast(mix(bg, fg, hundredths / 100), bg) >= target:
            return hundredths / 100
    return 0.98


def select_fill(raw, dark):
    """The accent hue at the strongest lightness that keeps every SELECT_TEXT_CONTRAST colour readable on it: scanning
    from the strong end (low lightness on a light theme, high on a dark one), the first tint that passes. If none
    does, the tint whose worst colour comes closest to its target. Tints too close to the background are skipped."""
    needs = SELECT_TEXT_CONTRAST_DARK if dark else SELECT_TEXT_CONTRAST
    best, best_score = None, 0.0
    for step in range(56):
        lightness = 0.60 - step * 0.01 if dark else 0.50 + step * 0.01
        fill = tint(raw['accent'], lightness)
        if contrast(fill, raw['base']) < SELECT_VISIBLE:
            continue
        score = min(contrast(raw[k], fill) / need for k, need in needs.items())
        if score >= 1:
            return fill
        if score > best_score:
            best, best_score = fill, score
    return best


def values(raw):
    """The theme's own keys plus the derived ones: the MODE_ROLES colours, on_accent (text drawn on an accent
    fill: the theme's own, else whichever of base and text contrasts more with accent), x_rgb ('r, g, b' for
    rgba()) and x_ansi ('38;2;r;g;b') for every hex value, glass_hex (glass as an alpha byte for rgba(hexAA))
    the SHIMMER_ROLES and TINT_ROLES tints and the MODES set."""
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
    v.update({f'{k}_shimmer': mix(raw[k], 'ffffff', SHIMMER_MIX) for k in SHIMMER_ROLES
              if HEX.fullmatch(raw.get(k, ''))})
    if raw.get('mode') in MODES and HEX.fullmatch(raw.get('text', '')):
        dark = raw['mode'] == 'dark'
        for k in TINT_ROLES:
            if not HEX.fullmatch(raw.get(k, '')):
                continue
            wash = None
            for name, levels in TINTS.items():
                want = tint(raw[k], levels[dark], TINT_HUE_SHIFT.get(k, 0.0), TINT_SATURATION.get(k, 1.0))
                floor = TINT_TEXT_CONTRAST.get(name, TINT_TEXT_CONTRAST[''])

                def keep(c, name=name, wash=wash, floor=floor):
                    if contrast(raw['text'], '%02x%02x%02x' % c) < floor:
                        return False
                    if name == 'tint_strong' and wash is not None:  # a changed word must stand out from its line
                        return lab(c)[0] - wash > 3 if dark else wash - lab(c)[0] > 3
                    return True
                v[f'{k}_{name}'] = snap256(want, keep)
                if name == 'tint':
                    wash = lab(tuple(int(v[f'{k}_{name}'][i:i + 2], 16) for i in (0, 2, 4)))[0]
    if raw.get('mode') in MODES and HEX.fullmatch(raw.get('accent', '')):
        v['accent_wash'] = tint(raw['accent'], ACCENT_WASH[raw['mode'] == 'dark'])
        if all(HEX.fullmatch(raw.get(k, '')) for k in (*SELECT_TEXT_CONTRAST, 'base')):
            v['accent_select'] = select_fill(raw, raw['mode'] == 'dark')
    if raw.get('mode') in MODES and all(HEX.fullmatch(raw.get(k, '')) for k in ('mantle', 'accent', 'overlay', 'muted')):
        if raw['mode'] == 'dark':
            alphas = dict(FILL_DARK)
        else:
            alphas = {'select_alpha': solve_alpha(raw['accent'], raw['mantle'], FILL_LIGHT_CONTRAST['select_alpha']),
                      'hover_alpha': solve_alpha(raw['overlay'], raw['mantle'], FILL_LIGHT_CONTRAST['hover_alpha']),
                      'field_alpha': FILL_LIGHT_FIELD_ALPHA,
                      'empty_alpha': solve_alpha(raw['muted'], raw['mantle'], FILL_LIGHT_CONTRAST['empty_alpha'])}
        v.update({k: '%.2f' % a for k, a in alphas.items()})
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


def destination(d, cfg, home):
    """Where a TARGETS destination lands: under home if it starts with '~/', else under cfg."""
    return os.path.join(home, d[2:]) if d.startswith('~/') else os.path.join(cfg, d)


def render_all(path, cfg, tpl_root=TEMPLATES, wallpapers=WALLPAPERS, home=None):
    """Write every TARGETS file under cfg (or home, for '~/' destinations). A theme with problems writes nothing."""
    home = home or Path.home()
    bad = problems(path, tpl_root, wallpapers)
    if bad:
        return bad
    v = values(load(path))
    for src, dsts in TARGETS.items():
        text, _ = fill((Path(tpl_root) / src).read_text(), v)
        for d in dsts:
            p = destination(d, cfg, home)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            Path(p).write_text(text)
    return []


def wallpaper_path(name, file, wall_dir, wallpapers=WALLPAPERS):
    """The image a theme shows: wallpapers/local/NAME.(jpg|png|webp) when the machine has one (a gitignored
    per-machine choice, keyed by theme so two themes sharing a file can still differ), else FILE in wall_dir,
    else FILE in the repo."""
    for ext in LOCAL_EXTS:
        local = wallpapers / 'local' / f'{name}.{ext}'
        if local.is_file():
            return local
    wp = Path(wall_dir) / file
    return wp if wp.is_file() else wallpapers / file


def default_wall_dir():
    return os.environ.get('WALL_DIR', os.path.expanduser('~/Pictures/Wallpapers'))


def catalogue(wall_dir, wallpapers=WALLPAPERS):
    """Every theme as a dict of its META, COLOURS and on_accent values, with the wallpaper as a path
    (wallpaper_path)."""
    out = []
    for p in sorted(THEMES.glob('*.theme')):
        v = values(load(p))
        entry = {k: v.get(k, '') for k in META + COLOURS + OPTIONAL_COLOURS}
        entry['wallpaper'] = str(wallpaper_path(entry['name'], entry['wallpaper'], wall_dir, wallpapers))
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
        print(json.dumps(catalogue(default_wall_dir())))
        return 0
    if cmd == 'wallpaper' and len(args) == 1:
        path = theme_path(args[0])
        if not path.is_file():
            return report(args[0], [f'no such theme: {args[0]}'])
        v = load(path)
        print(wallpaper_path(v['name'], v['wallpaper'], default_wall_dir()))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
