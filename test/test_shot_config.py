"""Tests for `shot config`: the screenshot settings the Settings page reads and writes.
Run from the repo root:  python3 -B -m unittest discover -s test
XDG_CONFIG_HOME points at a temporary directory, so the real settings file is never touched."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SHOT = Path(__file__).resolve().parents[1] / "scripts" / ".local" / "bin" / "shot"


class ShotConfig(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = dict(os.environ, XDG_CONFIG_HOME=self.tmp.name, HOME=self.tmp.name, XDG_PICTURES_DIR="")

    def tearDown(self):
        self.tmp.cleanup()

    def shot(self, *args):
        return subprocess.run([str(SHOT), "config", *args], env=self.env, capture_output=True, text=True)

    def settings(self):
        out = self.shot()
        self.assertEqual(out.returncode, 0, out.stderr)
        return dict(line.split("=", 1) for line in out.stdout.splitlines())

    def test_defaults_without_a_settings_file(self):
        self.assertEqual(self.settings(), {
            "annotate": "on", "notify": "on", "dir": str(Path(self.tmp.name) / "Pictures" / "Screenshots")})

    def test_a_set_value_is_read_back(self):
        self.assertEqual(self.shot("annotate", "off").returncode, 0)
        self.assertEqual(self.settings()["annotate"], "off")
        self.assertEqual(self.settings()["notify"], "on")

    def test_a_folder_with_spaces_survives(self):
        self.assertEqual(self.shot("dir", "/tmp/My Shots").returncode, 0)
        self.assertEqual(self.settings()["dir"], "/tmp/My Shots")

    def test_an_unknown_key_is_refused(self):
        out = self.shot("colour", "red")
        self.assertEqual(out.returncode, 2)
        self.assertIn("unknown setting", out.stderr)

    def test_a_bad_switch_value_is_refused(self):
        out = self.shot("annotate", "maybe")
        self.assertEqual(out.returncode, 2)
        self.assertEqual(self.settings()["annotate"], "on")


if __name__ == "__main__":
    unittest.main()
