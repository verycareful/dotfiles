"""Where the colours come from: the playing track's cover, the current theme, or a named palette.

A palette is a list of (r, g, b) tuples, dominant colour first.
"""
import colorsys
import hashlib
import re
import subprocess
import urllib.parse
import urllib.request
from pathlib import Path

PALETTES_FILE = Path(__file__).resolve().parent / "palettes"
REPO = Path(__file__).resolve().parents[4]

MAX_COLOURS = 5
MIN_SATURATION = 0.55         # LEDs wash weakly saturated colours out to white
GREY_SATURATION = 0.2         # below this a cover colour counts as grey and is dropped
DARK_VALUE = 0.15             # below this it counts as black and is dropped
HUE_MERGE = 0.06              # colours closer than this in hue are one colour on an LED
ART_MAX_BYTES = 10 * 1024 * 1024
WHITE = (255, 255, 255)

_HEX = re.compile(r"#?([0-9a-fA-F]{6})")
_HIST = re.compile(r"^\s*(\d+):\s*\(([^)]*)\)")


def hex_rgb(text):
    m = _HEX.fullmatch(text.strip())
    if not m:
        raise ValueError(f"not a colour: {text!r}")
    h = m.group(1)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def parse_palettes(text):
    """`name = #hex #hex ...`, one per line; a line starting with # is a comment."""
    out = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, colours = (part.strip() for part in line.split("=", 1))
        try:
            out[name.lower()] = [hex_rgb(c) for c in colours.split()]
        except ValueError:
            continue
    return out


def theme_palette(text):
    """primary_bright and accent from a themes/*.theme file (hex without '#', '#' starts a comment)."""
    values = {}
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if "=" in line:
            k, v = line.split("=", 1)
            values[k.strip()] = v.strip()
    out = []
    for key in ("primary_bright", "accent"):
        try:
            out.append(hex_rgb(values[key]))
        except (KeyError, ValueError):
            pass
    return out or [WHITE]


def current_theme_palette(state=Path.home() / ".local/state/theme/current"):
    try:
        name = state.read_text().strip() or "harbour"
    except OSError:
        name = "harbour"
    try:
        return theme_palette((REPO / "themes" / f"{name}.theme").read_text())
    except OSError:
        return [WHITE]


def parse_histogram(text):
    """`magick ... histogram:info:-` lines -> [(pixel count, (r, g, b))]."""
    out = []
    for line in text.splitlines():
        m = _HIST.match(line)
        if m:
            channels = [float(c) for c in m.group(2).split(",")[:3]]
            out.append((int(m.group(1)), tuple(int(c) if c.is_integer() else c for c in channels)))
    return out


def _hue_distance(a, b):
    d = abs(a - b) % 1.0
    return min(d, 1.0 - d)


def vivid(histogram):
    """The cover's colours as an LED can show them: greys and blacks dropped, near-identical hues
    merged, every colour at full value and at least MIN_SATURATION, most pixels first."""
    kept = []                                                     # (hue, saturation)
    for _count, rgb in sorted(histogram, key=lambda e: -e[0]):
        h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
        if s < GREY_SATURATION or v < DARK_VALUE:
            continue
        if any(_hue_distance(h, kh) < HUE_MERGE for kh, _ in kept):
            continue
        kept.append((h, max(s, MIN_SATURATION)))
        if len(kept) == MAX_COLOURS:
            break
    return [tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, s, 1.0)) for h, s in kept]


def extract(path):
    """Up to MAX_COLOURS vivid colours from an image; [] if it has none or cannot be read."""
    try:
        run = subprocess.run(
            ["magick", f"{path}[0]", "-resize", "64x64", "+dither", "-colors", "8",
             "-format", "%c", "histogram:info:-"],
            capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return []
    return vivid(parse_histogram(run.stdout)) if run.returncode == 0 else []


def _fetch(url):
    with urllib.request.urlopen(url, timeout=10) as r:
        return r.read(ART_MAX_BYTES)


def art_path(url, cache, fetch=_fetch):
    """A local file for an MPRIS artUrl: file:// as is, http(s) downloaded once into cache."""
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme == "file":
        path = Path(urllib.parse.unquote(parsed.path))
        return path if path.is_file() else None
    if parsed.scheme not in ("http", "https"):
        return None
    target = cache / hashlib.sha1(url.encode()).hexdigest()
    if target.is_file():
        return target
    try:
        data = fetch(url)
    except OSError:
        return None
    cache.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(".part")
    tmp.write_bytes(data)
    tmp.replace(target)
    return target


def playing_art_url(text):
    """From `playerctl -a metadata --format '{{status}}\\t{{mpris:artUrl}}'`: the first playing
    player's cover URL, or '' when nothing with a cover is playing."""
    for line in text.splitlines():
        status, _, url = line.partition("\t")
        if status == "Playing" and url.strip():
            return url.strip()
    return ""


def resolve(choice, cover, theme, named):
    """The palette to show: 'auto' is the cover, else the theme; 'theme' is always the theme;
    anything else names a palette from the palettes file (unknown names fall back to the theme)."""
    if choice == "auto":
        return cover or theme
    if choice == "theme":
        return theme
    return named.get(choice) or theme


def gradient(colours, t, wrap=False):
    """Colour at position t along the palette. Without wrap t runs 0..1 from the first colour to
    the last; with wrap the palette is a loop and t = 1 is back at the first colour."""
    n = len(colours)
    if n == 1:
        return colours[0]
    if wrap:
        x = (t % 1.0) * n
        i = int(x)
    else:
        x = max(0.0, min(1.0, t)) * (n - 1)
        i = min(int(x), n - 2)
    a, b = colours[i], colours[(i + 1) % n]
    return tuple(round(ca + (cb - ca) * (x - i)) for ca, cb in zip(a, b))
