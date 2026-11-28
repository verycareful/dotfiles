"""Tests for scripts/.local/bin/greet-times: the active time, install age and tagline in the terminal greeting.
Run from the repo root:  python3 -B -m unittest discover -s test
Login time, the pacman log and "now" are all passed in, and TZ is fixed, so the results never depend on the host."""
import os
import subprocess
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / ".local" / "bin" / "greet-times"
TZ = "Asia/Kolkata"


def epoch(text):
    return int(datetime.fromisoformat(text).replace(tzinfo=ZoneInfo(TZ)).timestamp())


class GreetTimes(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.log = Path(self.tmp.name) / "pacman.log"
        self.log.write_text("[2026-09-10T01:21:36+0530] [PACMAN] Running 'pacman -Sy base'\n"
                            "[2026-09-11T10:00:00+0530] [ALPM] upgraded x\n")

    def tearDown(self):
        self.tmp.cleanup()

    def run_it(self, what, now, login=None):
        env = dict(os.environ, TZ=TZ, GREET_PACMAN_LOG=str(self.log))
        if login is not None:
            env["GREET_LOGIN_EPOCH"] = str(epoch(login))
        out = subprocess.run([str(SCRIPT), what, "--now", str(epoch(now))], env=env, capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        return out.stdout.strip()

    def test_active_minutes_since_login(self):
        self.assertEqual(self.run_it("active", "2026-11-28T16:21:00", login="2026-11-28T16:14:00"), "7 min, since 16:14")

    def test_active_hours_and_minutes(self):
        self.assertEqual(self.run_it("active", "2026-11-28T16:19:00", login="2026-11-28T14:14:00"), "2 h 5 min, since 14:14")

    def test_installed_days_ago(self):
        self.assertEqual(self.run_it("installed", "2026-11-28T16:00:00"), "79 days ago")

    def test_installed_today(self):
        self.assertEqual(self.run_it("installed", "2026-09-10T23:00:00"), "today")

    def test_installed_one_day(self):
        self.assertEqual(self.run_it("installed", "2026-09-11T00:30:00"), "1 day ago")

    def test_tagline(self):
        self.assertEqual(self.run_it("tagline", "2026-11-28T16:00:00"), "A place in the sun, 79 days now")
        self.assertEqual(self.run_it("tagline", "2026-09-11T08:00:00"), "A place in the sun, 1 day now")
        self.assertEqual(self.run_it("tagline", "2026-09-10T08:00:00"), "A place in the sun, since today")


if __name__ == "__main__":
    unittest.main()
