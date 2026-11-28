"""Tests for scripts/.local/bin/lyrics: LRC parsing, picking a search result, the answer shape and the cache.
Run from the repo root:  python3 -B -m unittest discover -s test
The network is replaced by a stub, so nothing here talks to LRCLIB."""
import importlib.machinery
import importlib.util
import io
import json
import os
import tempfile
import time
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / ".local" / "bin" / "lyrics"
loader = importlib.machinery.SourceFileLoader("lyrics", str(SCRIPT))
spec = importlib.util.spec_from_loader("lyrics", loader)
lyrics = importlib.util.module_from_spec(spec)
loader.exec_module(lyrics)


class ParseLrc(unittest.TestCase):
    def test_timed_lines_in_order(self):
        text = "[00:12.50] second\n[00:01.00] first"
        self.assertEqual(lyrics.parse_lrc(text), [[1.0, "first"], [12.5, "second"]])

    def test_minutes_and_no_fraction(self):
        self.assertEqual(lyrics.parse_lrc("[02:03] line"), [[123.0, "line"]])

    def test_metadata_and_untimed_lines_dropped(self):
        self.assertEqual(lyrics.parse_lrc("[ar:Someone]\n[ti:Song]\nno stamp\n[00:05.00] sung"), [[5.0, "sung"]])

    def test_gap_line_kept_empty(self):
        self.assertEqual(lyrics.parse_lrc("[00:05.00] a\n[00:09.00]"), [[5.0, "a"], [9.0, ""]])

    def test_several_stamps_repeat_the_line(self):
        self.assertEqual(lyrics.parse_lrc("[00:10.00][00:50.00] chorus"), [[10.0, "chorus"], [50.0, "chorus"]])

    def test_empty_and_none(self):
        self.assertEqual(lyrics.parse_lrc(""), [])
        self.assertEqual(lyrics.parse_lrc(None), [])


class Pick(unittest.TestCase):
    def test_synced_preferred_over_closer_plain(self):
        plain = {"duration": 200, "plainLyrics": "x"}
        synced = {"duration": 202, "syncedLyrics": "[00:01.00] x"}
        self.assertIs(lyrics.pick([plain, synced], 200), synced)

    def test_far_lengths_rejected(self):
        self.assertIsNone(lyrics.pick([{"duration": 300, "syncedLyrics": "[00:01.00] x"}], 200))

    def test_unknown_length_takes_any(self):
        r = {"duration": 300, "plainLyrics": "x"}
        self.assertIs(lyrics.pick([r], 0), r)

    def test_empty(self):
        self.assertIsNone(lyrics.pick([], 200))


class Result(unittest.TestCase):
    def test_not_found(self):
        self.assertEqual(lyrics.result(None), {"synced": [], "plain": [], "instrumental": False, "found": False})

    def test_synced_wins_over_plain(self):
        r = lyrics.result({"syncedLyrics": "[00:01.00] a", "plainLyrics": "a"})
        self.assertEqual((r["synced"], r["plain"], r["found"]), ([[1.0, "a"]], [], True))

    def test_plain_only(self):
        r = lyrics.result({"plainLyrics": "a\nb"})
        self.assertEqual((r["synced"], r["plain"]), ([], ["a", "b"]))

    def test_instrumental(self):
        self.assertTrue(lyrics.result({"instrumental": True})["instrumental"])


class Main(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        patcher = mock.patch.object(lyrics, "CACHE", self.tmp.name)
        patcher.start()
        self.addCleanup(patcher.stop)

    def run_main(self, *args):
        out = io.StringIO()
        with redirect_stdout(out):
            code = lyrics.main(["lyrics", *args])
        return code, json.loads(out.getvalue())

    def test_found_is_cached_and_not_fetched_again(self):
        record = {"syncedLyrics": "[00:01.00] hi"}
        with mock.patch.object(lyrics, "fetch", return_value=record) as f:
            self.run_main("Song", "Artist", "Album", "200")
            code, out = self.run_main("Song", "Artist", "Album", "200")
        self.assertEqual(f.call_count, 1)
        self.assertEqual((code, out["synced"]), (0, [[1.0, "hi"]]))

    def test_get_miss_falls_back_to_search(self):
        hit = {"duration": 201, "syncedLyrics": "[00:02.00] yo"}
        with mock.patch.object(lyrics, "fetch", side_effect=[None, [hit]]) as f:
            _, out = self.run_main("Song", "Artist", "", "200")
        self.assertEqual(f.call_args_list[1].args[0], "search")
        self.assertEqual(out["synced"], [[2.0, "yo"]])

    def test_miss_is_retried_after_miss_days(self):
        with mock.patch.object(lyrics, "fetch", return_value=None) as f:
            self.run_main("Song", "Artist")
            self.run_main("Song", "Artist")
            self.assertEqual(f.call_count, 2)            # get + search, once
            path = next(Path(self.tmp.name).iterdir())
            old = time.time() - (lyrics.MISS_DAYS + 1) * 86400
            os.utime(path, (old, old))
            self.run_main("Song", "Artist")
            self.assertEqual(f.call_count, 4)

    def test_network_error_not_cached(self):
        with mock.patch.object(lyrics, "fetch", side_effect=OSError("offline")):
            code, out = self.run_main("Song", "Artist")
        self.assertEqual((code, out["found"], out["error"]), (0, False, "offline"))
        self.assertEqual(list(Path(self.tmp.name).iterdir()), [])

    def test_too_few_arguments(self):
        with redirect_stdout(io.StringIO()), mock.patch("sys.stderr", io.StringIO()):
            self.assertEqual(lyrics.main(["lyrics", "only-title"]), 2)


if __name__ == "__main__":
    unittest.main()
