"""Layout mapping, the silence gate and the three music modes, on made-up band sequences."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts/.local/lib/rgb-music"))
import modes  # noqa: E402
from sdk import Controller, Zone  # noqa: E402

DT = 1 / 30
N = modes.BANDS
RED, BLUE = (255, 0, 0), (0, 0, 255)


def bands(low=0.0, high=0.0, split=3):
    return [low] * split + [high] * (N - split)


def run(mode, frames, value, palette=(RED,)):
    scene = None
    for _ in range(frames):
        scene = mode.frame(value, DT, list(palette))
    return scene


def lit(ring):
    return sum(1 for c in ring if max(c) > 0)


def board_controller(index=2):
    return Controller(index, "ASRock X670E Pro RS", "HID: /dev/hidraw0", ["Direct"], 0, [
        Zone("RGB LED 1 Header", 0, 1), Zone("Addressable Header 1", 1, 80),
        Zone("Addressable Header 2", 81, 80), Zone("PCB", 161, 5)], 166)


def dram(index, address):
    return Controller(index, "ENE DRAM", f"I2C: SMBus, address {address}", ["Direct"], 0, [Zone("DRAM", 0, 8)], 8)


class LayoutMapping(unittest.TestCase):
    def setUp(self):
        self.controllers = [dram(0, "0x73"), dram(1, "0x71"), board_controller()]

    def test_uncalibrated_every_addressable_header_is_one_bar(self):
        layout = modes.build_layout(self.controllers, None)
        self.assertEqual([len(f) for f in layout.fans], [80, 80])
        self.assertEqual(layout.fans[1][0], (2, 81))

    def test_sticks_are_ordered_by_location(self):
        layout = modes.build_layout(self.controllers, None)
        self.assertEqual([s[0][0] for s in layout.sticks], [1, 0])

    def test_board_group_holds_the_non_addressable_zones(self):
        layout = modes.build_layout(self.controllers, None)
        self.assertEqual(sorted(layout.board), [(2, 0)] + [(2, i) for i in range(161, 166)])

    def test_calibration_splits_the_fan_header_into_rings_in_physical_order(self):
        cal = {"fan_zone": "Addressable Header 2", "fans": 3, "leds_per_fan": 4, "order": [2, 0, 1], "ram_led0": "top"}
        layout = modes.build_layout(self.controllers, cal)
        self.assertEqual(layout.fans, [[(2, 89 + i) for i in range(4)],
                                       [(2, 81 + i) for i in range(4)],
                                       [(2, 85 + i) for i in range(4)]])

    def test_calibration_with_led0_at_the_top_runs_meters_upward_from_the_last_led(self):
        cal = {"fan_zone": "Addressable Header 2", "fans": 3, "leds_per_fan": 4, "order": [0, 1, 2], "ram_led0": "top"}
        layout = modes.build_layout(self.controllers, cal)
        self.assertEqual(layout.sticks[0][0], (1, 7))

    def test_unused_header_leds_are_left_dark(self):
        cal = {"fan_zone": "Addressable Header 2", "fans": 3, "leds_per_fan": 4, "order": [0, 1, 2]}
        layout = modes.build_layout(self.controllers, cal)
        out = modes.compose(layout, modes.Scene([[RED] * 4] * 3, [[RED] * 8] * 2, RED), 1.0)
        self.assertEqual(out[2][81 + 12], (0, 0, 0))
        self.assertEqual(out[2][1], RED)            # the other header is part of the board group

    def test_compose_scales_every_colour_by_the_gate(self):
        layout = modes.build_layout(self.controllers, None)
        out = modes.compose(layout, modes.Scene([[RED] * 80] * 2, [[RED] * 8] * 2, RED), 0.5)
        self.assertEqual(out[0][0], (128, 0, 0))
        self.assertEqual(len(out[2]), 166)


class CalibrationCheck(unittest.TestCase):
    GOOD = {"fan_zone": "Addressable Header 2", "fans": 3, "leds_per_fan": 4, "order": [2, 0, 1], "ram_led0": "top"}

    def test_accepts_a_complete_calibration(self):
        self.assertTrue(modes.valid_calibration(self.GOOD))

    def test_order_must_name_every_fan_once(self):
        self.assertFalse(modes.valid_calibration({**self.GOOD, "order": [0, 0, 1]}))
        self.assertFalse(modes.valid_calibration({**self.GOOD, "order": [0, 1]}))

    def test_needs_a_positive_led_count_and_a_zone(self):
        self.assertFalse(modes.valid_calibration({**self.GOOD, "leds_per_fan": 0}))
        self.assertFalse(modes.valid_calibration({k: v for k, v in self.GOOD.items() if k != "fan_zone"}))

    def test_rejects_non_objects(self):
        self.assertFalse(modes.valid_calibration([1, 2]))
        self.assertFalse(modes.valid_calibration(None))


class Silence(unittest.TestCase):
    def test_stays_on_through_short_gaps(self):
        gate = modes.Silence()
        for _ in range(30):
            level = gate.update(bands(0.0), DT)
        self.assertEqual(level, 1.0)

    def test_fades_to_dark_after_the_hold(self):
        gate = modes.Silence()
        levels = [gate.update(bands(0.0), DT) for _ in range(int(2.1 * 30))]
        self.assertEqual(levels[-1], 0.0)
        self.assertTrue(0.0 < levels[int(1.75 * 30)] < 1.0)

    def test_sound_brings_it_back_at_once(self):
        gate = modes.Silence()
        for _ in range(90):
            gate.update(bands(0.0), DT)
        self.assertEqual(gate.update(bands(0.5), DT), 1.0)


class Pulse(unittest.TestCase):
    def setUp(self):
        self.mode = modes.Pulse([16] * 6, [8, 8])

    def test_a_kick_after_quiet_bass_flashes_full(self):
        run(self.mode, 30, bands(0.1))
        scene = run(self.mode, 1, bands(0.9))
        self.assertEqual(scene.board, RED)
        self.assertEqual(self.mode.beats, 1)

    def test_steady_bass_does_not_keep_flashing(self):
        run(self.mode, 30, bands(0.1))
        scene = run(self.mode, 60, bands(0.9))
        self.assertEqual(self.mode.beats, 1)
        self.assertLess(scene.board[0], 200)

    def test_hits_inside_the_refractory_gap_count_once(self):
        run(self.mode, 30, bands(0.1))
        for value in (0.9, 0.1, 0.9):               # 33 ms apart
            run(self.mode, 1, bands(value))
        self.assertEqual(self.mode.beats, 1)

    def test_colour_steps_every_four_beats(self):
        palette = (RED, BLUE)
        colours = []
        for _ in range(5):
            run(self.mode, 15, bands(0.1), palette)
            colours.append(run(self.mode, 1, bands(0.9), palette).board)
        self.assertEqual(colours[:4], [RED] * 4)
        self.assertEqual(colours[4], BLUE)


class Spectrum(unittest.TestCase):
    def setUp(self):
        self.mode = modes.Spectrum([10] * 6, [8, 8])

    def test_bass_fills_the_first_fan_only(self):
        scene = run(self.mode, 1, [1.0] * 3 + [0.0] * (N - 3))
        self.assertEqual(lit(scene.fans[0]), 10)
        self.assertEqual(lit(scene.fans[5]), 0)

    def test_half_level_lights_half_the_ring(self):
        scene = run(self.mode, 1, [0.5] * N)
        self.assertEqual(lit(scene.fans[2]), 5)

    def test_fans_run_along_the_palette(self):
        scene = run(self.mode, 1, [1.0] * N, (RED, BLUE))
        self.assertEqual(scene.fans[0][0], RED)
        self.assertEqual(scene.fans[5][0], BLUE)

    def test_low_half_drives_the_first_stick(self):
        scene = run(self.mode, 1, [1.0] * (N // 2) + [0.0] * (N // 2))
        self.assertEqual(lit(scene.sticks[0]), 8)
        self.assertEqual(lit(scene.sticks[1]), 0)

    def test_peak_holds_after_the_level_drops(self):
        run(self.mode, 1, [1.0] * N)
        scene = run(self.mode, 6, [0.0] * N)        # 0.2 s later
        self.assertGreater(max(scene.sticks[0][7]), 0)
        self.assertEqual(max(scene.sticks[0][3]), 0)

    def test_rings_fall_back_gradually(self):
        run(self.mode, 1, [1.0] * N)
        scene = run(self.mode, 2, [0.0] * N)
        self.assertGreater(lit(scene.fans[0]), 0)


class Colour(unittest.TestCase):
    def setUp(self):
        self.mode = modes.Colour([16] * 6, [8, 8])

    def test_bass_heavy_sound_settles_on_the_first_colour(self):
        scene = run(self.mode, 90, bands(1.0, 0.0), (RED, BLUE))
        self.assertEqual(scene.board[2], 0)
        self.assertGreater(scene.board[0], 0)

    def test_bright_sound_settles_on_the_last_colour(self):
        scene = run(self.mode, 90, bands(0.0, 1.0, split=12), (RED, BLUE))
        self.assertEqual(scene.board[0], 0)

    def test_colour_glides_instead_of_jumping(self):
        run(self.mode, 90, bands(1.0, 0.0), (RED, BLUE))
        scene = run(self.mode, 1, bands(0.0, 1.0, split=12), (RED, BLUE))
        self.assertGreater(scene.board[0], scene.board[2])

    def test_louder_is_brighter(self):
        quiet = run(modes.Colour([16] * 6, [8, 8]), 30, [0.1] * N).board[0]
        loud = run(modes.Colour([16] * 6, [8, 8]), 30, [0.9] * N).board[0]
        self.assertGreater(loud, quiet)

    def test_fans_are_offset_along_the_palette(self):
        scene = run(self.mode, 90, bands(1.0, 0.0), (RED, BLUE))
        self.assertGreater(scene.fans[5][0][2], scene.fans[0][0][2])


if __name__ == "__main__":
    unittest.main()
