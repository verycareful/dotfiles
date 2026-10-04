"""The cava config rgb-music generates and the raw frames it reads back."""
import configparser
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts/.local/lib/rgb-music"))
import audio  # noqa: E402


class Config(unittest.TestCase):
    def setUp(self):
        self.cfg = configparser.ConfigParser()
        self.cfg.read_string(audio.cava_config(18, 30))

    def test_captures_the_default_output_through_pipewire(self):
        self.assertEqual(self.cfg["input"]["method"], "pipewire")
        self.assertEqual(self.cfg["input"]["source"], "auto")

    def test_streams_raw_16_bit_mono_bars_to_stdout(self):
        out = self.cfg["output"]
        self.assertEqual((out["method"], out["raw_target"], out["data_format"], out["bit_format"], out["channels"]),
                         ("raw", "/dev/stdout", "binary", "16bit", "mono"))

    def test_bar_count_and_rate_are_the_ones_asked_for(self):
        self.assertEqual((self.cfg["general"]["bars"], self.cfg["general"]["framerate"]), ("18", "30"))

    def test_never_sleeps_so_silence_still_produces_frames(self):
        self.assertEqual(self.cfg["general"]["sleep_timer"], "0")


class Frames(unittest.TestCase):
    def test_frame_size_is_two_bytes_per_band(self):
        self.assertEqual(audio.frame_size(18), 36)

    def test_decodes_little_endian_u16_to_unit_floats(self):
        self.assertEqual(audio.decode(struct.pack("<3H", 0, 65535, 32768)), [0.0, 1.0, 32768 / 65535])


if __name__ == "__main__":
    unittest.main()
