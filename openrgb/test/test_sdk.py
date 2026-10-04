"""OpenRGB SDK framing and controller-data parsing (protocol version 4)."""
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts/.local/lib/rgb-music"))
import sdk  # noqa: E402


def s(text):
    raw = text.encode() + b"\0"
    return struct.pack("<H", len(raw)) + raw


def mode(name):
    # name, value, flags, speed min/max, brightness min/max, colours min/max,
    # speed, brightness, direction, colour mode, then a colour list
    return s(name) + struct.pack("<i11IH", 0, *[0] * 11, 1) + b"\1\2\3\0"


def zone(name, count, matrix=None, segments=()):
    out = s(name) + struct.pack("<iIII", 1, 0, count, count)
    if matrix:
        h, w = matrix
        out += struct.pack("<HII", 8 + 4 * h * w, h, w) + b"\0" * (4 * h * w)
    else:
        out += struct.pack("<H", 0)
    out += struct.pack("<H", len(segments))
    for seg in segments:
        out += s(seg) + struct.pack("<iII", 0, 0, 1)
    return out


def controller(name, location, modes, active, zones, leds):
    body = struct.pack("<i", 7)
    for text in (name, "vendor", "desc", "1.0", "serial", location):
        body += s(text)
    body += struct.pack("<Hi", len(modes), active) + b"".join(mode(m) for m in modes)
    body += struct.pack("<H", len(zones)) + b"".join(zones)
    body += struct.pack("<H", leds) + b"".join(s(f"led{i}") + struct.pack("<I", i) for i in range(leds))
    body += struct.pack("<H", leds) + b"\0\0\0\0" * leds
    return struct.pack("<I", len(body) + 4) + body


class Framing(unittest.TestCase):
    def test_header_is_magic_then_three_little_endian_u32(self):
        self.assertEqual(sdk.header(2, 1050, 10), b"ORGB" + struct.pack("<III", 2, 1050, 10))

    def test_update_leds_payload_carries_size_count_and_rgb0_colours(self):
        payload = sdk.update_leds_payload([(255, 0, 16), (1, 2, 3)])
        self.assertEqual(payload, struct.pack("<IH", 14, 2) + b"\xff\x00\x10\x00\x01\x02\x03\x00")

    def test_update_leds_payload_clamps_and_rounds_channels(self):
        payload = sdk.update_leds_payload([(300.0, -4, 127.6)])
        self.assertEqual(payload[6:], b"\xff\x00\x80\x00")

    def test_string_payload_is_nul_terminated(self):
        self.assertEqual(sdk.string_payload("White"), b"White\0")


class ControllerData(unittest.TestCase):
    def setUp(self):
        blob = controller(
            "ASRock X670E Pro RS", "HID: /dev/hidraw0", ["Off", "Static", "Direct"], 1,
            [zone("PCB", 5), zone("Addressable Header 1", 3, segments=["a", "b"]), zone("Matrix", 2, matrix=(2, 3))],
            10,
        )
        self.c = sdk.parse_controller(blob, 4)

    def test_reads_name_location_and_modes(self):
        self.assertEqual(self.c.name, "ASRock X670E Pro RS")
        self.assertEqual(self.c.location, "HID: /dev/hidraw0")
        self.assertEqual(self.c.modes, ["Off", "Static", "Direct"])
        self.assertEqual(self.c.active_mode, 1)

    def test_zones_get_cumulative_start_offsets(self):
        self.assertEqual([(z.name, z.start, z.count) for z in self.c.zones],
                         [("PCB", 0, 5), ("Addressable Header 1", 5, 3), ("Matrix", 8, 2)])

    def test_counts_leds(self):
        self.assertEqual(self.c.num_leds, 10)

    def test_rejects_a_blob_whose_size_field_disagrees_with_its_content(self):
        blob = controller("x", "y", ["Direct"], 0, [zone("z", 1)], 1)
        with self.assertRaises(ValueError):
            sdk.parse_controller(blob + b"\0", 4)


if __name__ == "__main__":
    unittest.main()
