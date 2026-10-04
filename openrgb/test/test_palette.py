"""Palette sources: the palettes file, the theme fallback, cover-art extraction and resolution."""
import colorsys
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts/.local/lib/rgb-music"))
import palette  # noqa: E402


def hsv(rgb):
    return colorsys.rgb_to_hsv(*(c / 255 for c in rgb))


class PalettesFile(unittest.TestCase):
    def test_parses_names_and_hex_colours_skipping_comments_and_blanks(self):
        text = "# plain\n\nred = #ff0000\nFire = #ff2000 #ff8000  #ffd000\n"
        self.assertEqual(palette.parse_palettes(text), {
            "red": [(255, 0, 0)],
            "fire": [(255, 32, 0), (255, 128, 0), (255, 208, 0)],
        })

    def test_skips_lines_with_bad_colours(self):
        self.assertEqual(palette.parse_palettes("bad = #12345\nok = #000001\n"), {"ok": [(0, 0, 1)]})

    def test_shipped_file_parses_with_plain_and_mixed_palettes(self):
        shipped = palette.parse_palettes(palette.PALETTES_FILE.read_text())
        for name in ("white", "red", "orange", "yellow", "green", "cyan", "blue", "purple", "pink",
                     "fire", "ocean", "neon"):
            self.assertIn(name, shipped)
        self.assertNotIn("auto", shipped)
        self.assertNotIn("theme", shipped)


class Theme(unittest.TestCase):
    def test_uses_primary_bright_then_accent(self):
        text = "# comment\nbase=000000\nprimary_bright=3b5fe0  # links\naccent=ff8c32\n"
        self.assertEqual(palette.theme_palette(text), [(0x3b, 0x5f, 0xe0), (0xff, 0x8c, 0x32)])

    def test_missing_keys_fall_back_to_white(self):
        self.assertEqual(palette.theme_palette("base=000000\n"), [(255, 255, 255)])


class Histogram(unittest.TestCase):
    def test_parses_magick_histogram_lines(self):
        text = ("      1200: (255,140,50) #FF8C32 srgb(255,140,50)\n"
                "        30: (12.5,0,255,255) #0D00FFFF srgba(12.5,0,255,1)\n")
        self.assertEqual(palette.parse_histogram(text), [(1200, (255, 140, 50)), (30, (12.5, 0, 255))])


class Vivid(unittest.TestCase):
    def test_drops_greys_and_near_blacks(self):
        self.assertEqual(palette.vivid([(900, (128, 128, 128)), (500, (10, 5, 5)), (100, (255, 255, 255))]), [])

    def test_boosts_a_dim_colour_to_full_value_and_keeps_its_hue(self):
        (out,) = palette.vivid([(10, (100, 20, 20))])
        h, s, v = hsv(out)
        self.assertAlmostEqual(v, 1.0, places=2)
        self.assertAlmostEqual(h, hsv((100, 20, 20))[0], places=2)

    def test_raises_weak_saturation_to_the_floor(self):
        (out,) = palette.vivid([(10, (200, 150, 150))])
        self.assertGreaterEqual(hsv(out)[1], palette.MIN_SATURATION - 0.01)

    def test_orders_by_pixel_count_and_merges_near_hues(self):
        out = palette.vivid([(10, (0, 0, 255)), (500, (255, 0, 0)), (400, (250, 10, 0)), (50, (0, 255, 0))])
        self.assertEqual(len(out), 3)
        self.assertGreater(out[0][0], 200)          # red first (both reds merged into one)
        self.assertGreater(out[1][1], 200)          # then green
        self.assertGreater(out[2][2], 200)          # then blue

    def test_keeps_at_most_five(self):
        colours = [(10 * (i + 1), tuple(int(c * 255) for c in colorsys.hsv_to_rgb(i / 8, 1, 1))) for i in range(8)]
        self.assertEqual(len(palette.vivid(colours)), palette.MAX_COLOURS)


@unittest.skipUnless(shutil.which("magick"), "ImageMagick not installed")
class Extract(unittest.TestCase):
    def test_finds_both_halves_of_a_two_colour_image(self):
        with tempfile.TemporaryDirectory() as d:
            img = Path(d) / "art.png"
            subprocess.run(["magick", "-size", "64x32", "xc:#e01010", "-size", "64x32", "xc:#1030e0",
                            "-append", str(img)], check=True)
            out = palette.extract(img)
        hues = sorted(round(hsv(c)[0], 1) for c in out)
        self.assertEqual(len(out), 2)
        self.assertIn(0.0, hues)                    # red
        self.assertIn(0.6, hues)                    # blue

    def test_unreadable_file_gives_no_colours(self):
        with tempfile.NamedTemporaryFile(suffix=".jpg") as f:
            f.write(b"not an image")
            f.flush()
            self.assertEqual(palette.extract(Path(f.name)), [])


class ArtPath(unittest.TestCase):
    def test_file_url_points_at_the_file(self):
        with tempfile.NamedTemporaryFile() as f:
            self.assertEqual(palette.art_path("file://" + f.name, Path("/nonexistent")), Path(f.name))

    def test_http_url_is_fetched_once_then_cached(self):
        calls = []

        def fetch(url):
            calls.append(url)
            return b"image bytes"

        with tempfile.TemporaryDirectory() as d:
            first = palette.art_path("https://i.example/cover", Path(d), fetch)
            second = palette.art_path("https://i.example/cover", Path(d), fetch)
            self.assertEqual(first, second)
            self.assertEqual(first.read_bytes(), b"image bytes")
        self.assertEqual(calls, ["https://i.example/cover"])

    def test_failed_fetch_gives_none(self):
        def fetch(url):
            raise OSError("offline")

        with tempfile.TemporaryDirectory() as d:
            self.assertIsNone(palette.art_path("https://i.example/cover", Path(d), fetch))

    def test_other_schemes_and_empty_urls_give_none(self):
        self.assertIsNone(palette.art_path("data:image/png;base64,AAAA", Path("/tmp")))
        self.assertIsNone(palette.art_path("", Path("/tmp")))


class Players(unittest.TestCase):
    def test_picks_the_first_playing_player_with_art(self):
        text = "Paused\thttps://a\nPlaying\t\nPlaying\thttps://b\nPlaying\thttps://c\n"
        self.assertEqual(palette.playing_art_url(text), "https://b")

    def test_nothing_playing_gives_empty(self):
        self.assertEqual(palette.playing_art_url("Paused\thttps://a\n"), "")


class Resolve(unittest.TestCase):
    THEME = [(1, 2, 3)]
    NAMED = {"red": [(255, 0, 0)]}

    def test_auto_prefers_cover_colours(self):
        self.assertEqual(palette.resolve("auto", [(9, 9, 9)], self.THEME, self.NAMED), [(9, 9, 9)])

    def test_auto_without_cover_uses_theme(self):
        self.assertEqual(palette.resolve("auto", [], self.THEME, self.NAMED), self.THEME)

    def test_theme_ignores_the_cover(self):
        self.assertEqual(palette.resolve("theme", [(9, 9, 9)], self.THEME, self.NAMED), self.THEME)

    def test_named_palette(self):
        self.assertEqual(palette.resolve("red", [(9, 9, 9)], self.THEME, self.NAMED), [(255, 0, 0)])

    def test_unknown_name_uses_theme(self):
        self.assertEqual(palette.resolve("nope", [], self.THEME, self.NAMED), self.THEME)


class Gradient(unittest.TestCase):
    P = [(0, 0, 0), (200, 100, 0)]

    def test_ends_are_the_first_and_last_colours(self):
        self.assertEqual(palette.gradient(self.P, 0), (0, 0, 0))
        self.assertEqual(palette.gradient(self.P, 1), (200, 100, 0))

    def test_interpolates_between_neighbours(self):
        self.assertEqual(palette.gradient(self.P, 0.5), (100, 50, 0))

    def test_clamps_outside_the_range(self):
        self.assertEqual(palette.gradient(self.P, 1.7), (200, 100, 0))

    def test_wrap_runs_back_to_the_first_colour(self):
        self.assertEqual(palette.gradient(self.P, 1.0, wrap=True), (0, 0, 0))
        self.assertEqual(palette.gradient(self.P, 0.5, wrap=True), (200, 100, 0))
        self.assertEqual(palette.gradient(self.P, 1.5, wrap=True), (200, 100, 0))

    def test_single_colour_is_constant(self):
        self.assertEqual(palette.gradient([(5, 6, 7)], 0.3, wrap=True), (5, 6, 7))


if __name__ == "__main__":
    unittest.main()
