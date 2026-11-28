"""Tests for scripts/.local/bin/viz-wave: the sample windows the waveform look draws.
Run from the repo root:  python3 -B -m unittest discover -s test
Nothing here starts parec: the relay is fed bytes through a stream."""
import array
import importlib.machinery
import importlib.util
import io
import math
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / ".local" / "bin" / "viz-wave"
loader = importlib.machinery.SourceFileLoader("viz_wave", str(SCRIPT))
spec = importlib.util.spec_from_loader("viz_wave", loader)
wave = importlib.util.module_from_spec(spec)
loader.exec_module(wave)

UNIT = wave.FULL / 32768


def pcm(samples):
    """Little-endian signed 16-bit bytes, as parec writes them."""
    a = array.array("h", samples)
    if wave.sys.byteorder == "big":
        a.byteswap()
    return a.tobytes()


def values(line):
    return [int(v) for v in line.split(";")]


def sine(freq, n, amp=10000, offset=0):
    return [round(amp * math.sin(2 * math.pi * freq * (i + offset) / wave.RATE)) for i in range(n)]


class Trace(unittest.TestCase):
    def test_trace_has_points_values(self):
        self.assertEqual(len(wave.trace([0] * wave.CAPTURE)), wave.POINTS)

    def test_high_frequency_noise_is_smoothed_away(self):
        noise = [10000 if i % 2 else -10000 for i in range(wave.CAPTURE)]
        self.assertLess(max(abs(v) for v in wave.trace(noise)), 100)

    def test_a_bass_tone_keeps_most_of_its_height(self):
        self.assertGreater(max(wave.trace(sine(100, wave.CAPTURE))), 7000)

    def test_a_high_tone_is_smoothed_away(self):
        self.assertLess(max(abs(v) for v in wave.trace(sine(2000, wave.CAPTURE))), 500)

    def test_the_trace_starts_on_a_rising_crossing(self):
        first = wave.trace(sine(220, wave.CAPTURE, offset=300))[0]
        self.assertLess(abs(first), 600)

    def test_the_same_tone_at_any_offset_gives_the_same_trace(self):
        a = wave.trace(sine(100, wave.CAPTURE, offset=0))
        b = wave.trace(sine(100, wave.CAPTURE, offset=137))
        self.assertLess(max(abs(x - y) for x, y in zip(a, b)), 300)

    def test_silence_is_flat(self):
        self.assertEqual(set(wave.trace([0] * wave.CAPTURE)), {0})


class TriggerStart(unittest.TestCase):
    def test_first_rising_crossing(self):
        self.assertEqual(wave.trigger_start([-3, -2, -1, 4, 5, -1, 2], 7), 3)

    def test_no_crossing_starts_at_zero(self):
        self.assertEqual(wave.trigger_start([5, 6, 7, 8], 4), 0)

    def test_a_crossing_beyond_the_search_range_is_ignored(self):
        self.assertEqual(wave.trigger_start([-1, -1, -1, -1, 3], 4), 0)


class FormatLine(unittest.TestCase):
    def test_one_value_per_point_with_sign(self):
        out = values(wave.format_line([100.0, -20000.0, 0.0], UNIT))
        self.assertEqual(out, [round(100 * UNIT), round(-20000 * UNIT), 0])

    def test_values_are_clamped_to_full(self):
        out = values(wave.format_line([32767.0, -32768.0], wave.FULL / wave.GAIN_FLOOR))
        self.assertEqual(out, [wave.FULL, -wave.FULL])


class Smoother(unittest.TestCase):
    def test_the_first_frame_passes_a_fraction_of_the_target(self):
        out = wave.Smoother().step([1000.0, -1000.0])
        self.assertEqual(out, [1000.0 * wave.EASE, -1000.0 * wave.EASE])

    def test_it_converges_on_a_steady_target(self):
        smoother = wave.Smoother()
        for _ in range(40):
            out = smoother.step([500.0])
        self.assertAlmostEqual(out[0], 500.0, delta=5)

    def test_a_single_spike_is_spread_over_frames(self):
        smoother = wave.Smoother()
        self.assertLess(smoother.step([1000.0])[0], 500)


class GainFollower(unittest.TestCase):
    def test_gain_does_not_amplify_the_noise_floor(self):
        scale = wave.Gain().scale(100)
        self.assertAlmostEqual(scale, wave.FULL / wave.GAIN_FLOOR)
        self.assertEqual(round(100 * scale), 50)

    def test_gain_fills_the_range_for_a_quiet_song(self):
        scale = wave.Gain().scale(4000)
        self.assertEqual(round(4000 * scale), wave.FULL)

    def test_gain_releases_slowly(self):
        gain = wave.Gain()
        gain.scale(20000)
        last = gain.scale(0)
        for _ in range(50):
            now = gain.scale(0)
            self.assertLessEqual(now, last / wave.GAIN_RELEASE + 1e-9)
            self.assertLessEqual(now, wave.FULL / wave.GAIN_FLOOR)
            last = now


class Relay(unittest.TestCase):
    def test_relay_prints_one_line_per_hop(self):
        out = io.StringIO()
        wave.relay(io.BytesIO(pcm([1000] * (3 * wave.HOP))), out)
        lines = out.getvalue().splitlines()
        self.assertEqual(len(lines), 3)
        self.assertTrue(all(len(values(line)) == wave.POINTS for line in lines))

    def test_a_partial_hop_adds_no_line(self):
        out = io.StringIO()
        wave.relay(io.BytesIO(pcm([1000] * (wave.HOP + wave.HOP // 2))), out)
        self.assertEqual(len(out.getvalue().splitlines()), 1)

    def test_the_first_hop_already_prints_a_line(self):
        out = io.StringIO()
        wave.relay(io.BytesIO(pcm([8000] * wave.HOP)), out)
        self.assertEqual(len(out.getvalue().splitlines()), 1)

    def test_a_sustained_level_shows_on_the_line(self):
        out = io.StringIO()
        wave.relay(io.BytesIO(pcm([8000] * (10 * wave.HOP))), out)
        self.assertGreater(max(values(out.getvalue().splitlines()[-1])), 500)


class ParecCommand(unittest.TestCase):
    def test_parec_command_reads_the_default_monitor(self):
        cmd = wave.parec_command()
        for part in ("@DEFAULT_MONITOR@", "--format=s16le", "--rate=48000", "--channels=1", "--raw", "--latency-msec=5"):
            self.assertIn(part, cmd)


if __name__ == "__main__":
    unittest.main()
