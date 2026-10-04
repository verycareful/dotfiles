"""Minimal OpenRGB SDK client: enough to read the device layout and stream Direct-mode colours.

Every packet is a 16-byte header ("ORGB", device index, packet id, payload size; little endian)
followed by the payload. The server is the only process that touches the hardware; this client
only ever talks to its socket.
"""
import select
import socket
import struct
from dataclasses import dataclass, field

PROTOCOL_VERSION = 4          # the controller-data layout parse_controller understands

REQUEST_CONTROLLER_COUNT = 0
REQUEST_CONTROLLER_DATA = 1
REQUEST_PROTOCOL_VERSION = 40
SET_CLIENT_NAME = 50
DEVICE_LIST_UPDATED = 100
LOAD_PROFILE = 152
UPDATE_LEDS = 1050
SET_CUSTOM_MODE = 1100

HEADER = struct.Struct("<4sIII")


def header(device, packet, size):
    return HEADER.pack(b"ORGB", device, packet, size)


def string_payload(text):
    return text.encode() + b"\0"


def update_leds_payload(colours):
    body = struct.pack("<H", len(colours)) + b"".join(
        bytes(max(0, min(255, round(c))) for c in rgb) + b"\0" for rgb in colours)
    return struct.pack("<I", len(body) + 4) + body


@dataclass
class Zone:
    name: str
    start: int                # index of the zone's first LED in the controller's LED array
    count: int


@dataclass
class Controller:
    index: int
    name: str
    location: str
    modes: list
    active_mode: int
    zones: list = field(default_factory=list)
    num_leds: int = 0


class _Reader:
    def __init__(self, blob):
        self.blob, self.pos = blob, 0

    def take(self, fmt):
        values = struct.unpack_from("<" + fmt, self.blob, self.pos)
        self.pos += struct.calcsize("<" + fmt)
        return values if len(values) > 1 else values[0]

    def skip(self, n):
        self.pos += n

    def string(self):
        n = self.take("H")
        raw = self.blob[self.pos:self.pos + n]
        self.pos += n
        return raw.rstrip(b"\0").decode(errors="replace")


def parse_controller(blob, version, index=0):
    """Decode a REQUEST_CONTROLLER_DATA reply. Only versions 3 and 4 have the layout read here."""
    if version not in (3, 4):
        raise ValueError(f"unsupported protocol version {version}")
    r = _Reader(blob)
    size = r.take("I")
    if size != len(blob):
        raise ValueError(f"controller data says {size} bytes, got {len(blob)}")
    r.take("i")                                   # device type
    name = r.string()
    for _ in range(4):                            # vendor, description, version, serial
        r.string()
    location = r.string()

    num_modes, active = r.take("Hi")
    modes = []
    for _ in range(num_modes):
        modes.append(r.string())
        r.skip(4 * 12)                            # value, flags, speed/brightness/colour ranges, settings
        r.skip(4 * r.take("H"))                   # mode colours

    zones, start = [], 0
    for _ in range(r.take("H")):
        zname = r.string()
        _type, _lo, _hi, count = r.take("iIII")
        r.skip(r.take("H"))                       # matrix map (height, width, map) when present
        if version >= 4:
            for _ in range(r.take("H")):          # segments
                r.string()
                r.skip(4 * 3)
        zones.append(Zone(zname, start, count))
        start += count

    num_leds = r.take("H")
    for _ in range(num_leds):
        r.string()
        r.skip(4)
    r.skip(4 * r.take("H"))                       # current colours
    if r.pos != len(blob):
        raise ValueError(f"controller data has {len(blob) - r.pos} unparsed bytes")
    return Controller(index, name, location, modes, active, zones, num_leds)


class Client:
    """One connection to the OpenRGB server. Replies are read synchronously; LED updates are
    fire-and-forget (the server hands each device's update to that device's own thread)."""

    def __init__(self, host="localhost", port=6742, name="rgb-music", timeout=5.0):
        self.sock = socket.create_connection((host, port), timeout=timeout)
        self.device_list_changed = False
        self._send(0, REQUEST_PROTOCOL_VERSION, struct.pack("<I", PROTOCOL_VERSION))
        server = struct.unpack("<I", self._reply(REQUEST_PROTOCOL_VERSION))[0]
        self.version = min(server, PROTOCOL_VERSION)
        if self.version < 3:
            raise RuntimeError(f"OpenRGB server speaks protocol {server}; need 3 or newer")
        self._send(0, SET_CLIENT_NAME, string_payload(name))

    def close(self):
        self.sock.close()

    def _send(self, device, packet, payload=b""):
        self.sock.sendall(header(device, packet, len(payload)) + payload)

    def _recv(self, n):
        data = b""
        while len(data) < n:
            chunk = self.sock.recv(n - len(data))
            if not chunk:
                raise ConnectionError("OpenRGB server closed the connection")
            data += chunk
        return data

    def _packet(self):
        magic, device, packet, size = HEADER.unpack(self._recv(HEADER.size))
        if magic != b"ORGB":
            raise ConnectionError("bad packet magic from OpenRGB server")
        return packet, self._recv(size)

    def _reply(self, want):
        while True:
            packet, payload = self._packet()
            if packet == DEVICE_LIST_UPDATED:
                self.device_list_changed = True
            elif packet == want:
                return payload

    def poll(self):
        """Drain unsolicited packets without blocking; sets device_list_changed on a hot-plug."""
        while select.select([self.sock], [], [], 0)[0]:
            packet, _ = self._packet()
            if packet == DEVICE_LIST_UPDATED:
                self.device_list_changed = True

    def controllers(self):
        self._send(0, REQUEST_CONTROLLER_COUNT)
        count = struct.unpack("<I", self._reply(REQUEST_CONTROLLER_COUNT))[0]
        out = []
        for i in range(count):
            self._send(i, REQUEST_CONTROLLER_DATA, struct.pack("<I", self.version))
            out.append(parse_controller(self._reply(REQUEST_CONTROLLER_DATA), self.version, i))
        self.device_list_changed = False
        return out

    def set_custom_mode(self, device):
        """Switch a device to Direct (the server falls back to Custom or Static if it has none)."""
        self._send(device, SET_CUSTOM_MODE)

    def update_leds(self, device, colours):
        self._send(device, UPDATE_LEDS, update_leds_payload(colours))

    def load_profile(self, name):
        self._send(0, LOAD_PROFILE, string_payload(name))
