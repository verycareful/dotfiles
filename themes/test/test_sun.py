"""Tests for themes/sun.py: parsing wttr.in's answer, the daily cache and its fallbacks, day or night.
Run from the repo root:  python3 -B -m unittest discover -s themes/test
No network: every fetch is a stub."""
import datetime as dt
import importlib.util
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('sun', REPO / 'themes' / 'sun.py')
sun = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sun)

TODAY = dt.date(2026, 11, 27)
YESTERDAY = TODAY - dt.timedelta(days=1)


def offline():
    return None


class Parse(unittest.TestCase):
    def test_two_times(self):
        self.assertEqual(sun.parse('06:13:29 17:39:44\n'), ('06:13', '17:39'))

    def test_anything_else_is_none(self):
        for text in ('', 'Unknown location', '06:13:29', '06:13 17:39', '25:00:00 17:39:44'):
            self.assertIsNone(sun.parse(text), text)

    def test_sunset_before_sunrise_is_none(self):
        self.assertIsNone(sun.parse('17:39:44 06:13:29'))


class Times(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.cache = Path(self._tmp.name) / 'sub' / 'theme-sun'

    def tearDown(self):
        self._tmp.cleanup()

    def test_fetch_is_cached_for_the_day(self):
        self.assertEqual(sun.times(TODAY, self.cache, lambda: ('06:00', '18:00')), ('06:00', '18:00'))
        self.assertEqual(self.cache.read_text().split(), ['2026-11-27', '06:00', '18:00'])

    def test_todays_cache_skips_the_fetch(self):
        self.cache.parent.mkdir()
        self.cache.write_text('2026-11-27 06:10 17:40\n')
        self.assertEqual(sun.times(TODAY, self.cache, lambda: self.fail('fetched')), ('06:10', '17:40'))

    def test_stale_cache_is_refreshed(self):
        self.cache.parent.mkdir()
        self.cache.write_text(f'{YESTERDAY.isoformat()} 06:10 17:40\n')
        self.assertEqual(sun.times(TODAY, self.cache, lambda: ('06:11', '17:39')), ('06:11', '17:39'))

    def test_offline_uses_the_last_cache(self):
        self.cache.parent.mkdir()
        self.cache.write_text(f'{YESTERDAY.isoformat()} 06:10 17:40\n')
        self.assertEqual(sun.times(TODAY, self.cache, offline), ('06:10', '17:40'))

    def test_offline_and_no_cache_uses_the_fallback(self):
        self.assertEqual(sun.times(TODAY, self.cache, offline), sun.FALLBACK)
        self.assertFalse(self.cache.exists())

    def test_corrupt_cache_is_ignored(self):
        self.cache.parent.mkdir()
        self.cache.write_text('garbage\n')
        self.assertEqual(sun.times(TODAY, self.cache, offline), sun.FALLBACK)


class Phase(unittest.TestCase):
    def test_day_and_night(self):
        for now, want in (('00:00', 'dark'), ('06:12', 'dark'), ('06:13', 'light'), ('12:00', 'light'),
                          ('17:38', 'light'), ('17:39', 'dark'), ('23:59', 'dark')):
            self.assertEqual(sun.phase(now, '06:13', '17:39'), want, now)


if __name__ == '__main__':
    unittest.main()
