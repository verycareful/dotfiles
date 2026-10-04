"""The three music modes and the mapping from their output onto the real LEDs.

Each mode turns one frame of cava band levels (BANDS floats, 0..1, bass first) into a Scene:
a colour per LED of every fan ring and RAM stick, and one colour for the rest of the board.
compose() then lays a Scene onto each controller's LED array.
"""
import math
from dataclasses import dataclass

from palette import gradient

BANDS = 18
GAMMA = 2.2                   # LED output is linear; this makes fades look even to the eye


def smooth(current, target, dt, tau):
    """First-order low-pass: moves current toward target with time constant tau (seconds)."""
    return target + (current - target) * math.exp(-dt / tau)


def decay(value, dt, half_life):
    return value * 0.5 ** (dt / half_life)


def shade(rgb, level):
    k = max(0.0, min(1.0, level)) ** GAMMA
    return tuple(round(c * k) for c in rgb)


def mean(values):
    return sum(values) / len(values) if values else 0.0


def meter(n, level, colour):
    """n LEDs filled from index 0 up to level * n, the last one partly."""
    return [shade(colour, level * n - k) for k in range(n)]


@dataclass
class Scene:
    fans: list                # per fan ring: a colour per LED, in ring order
    sticks: list              # per RAM stick: a colour per LED, bottom to top
    board: tuple              # every other board LED


@dataclass
class Layout:
    fans: list                # per fan: [(controller index, LED index)] in ring order
    sticks: list              # per stick: [(controller index, LED index)] bottom to top
    board: list               # [(controller index, LED index)]
    sizes: dict               # controller index -> LED count

    @property
    def shape(self):
        return [len(f) for f in self.fans], [len(s) for s in self.sticks]


def valid_calibration(cal):
    if not isinstance(cal, dict):
        return False
    fans, per, order = cal.get("fans"), cal.get("leds_per_fan"), cal.get("order")
    return (isinstance(cal.get("fan_zone"), str) and isinstance(fans, int) and fans > 0
            and isinstance(per, int) and per > 0
            and isinstance(order, list) and sorted(order) == list(range(fans)))


def build_layout(controllers, calibration):
    """Split the server's controllers into fans, RAM sticks and the rest of the board.

    Uncalibrated, every addressable header is one long bar. A calibration (from `rgb-music
    calibrate`) names the header the fan hub is on, how many fans and LEDs per fan it has, the
    physical order of the fans (order[position] = fan index on the hub) and whether each stick's
    LED 0 is at the top or the bottom.
    """
    cal = calibration or {}
    fans, sticks, board = [], [], []
    for c in sorted((c for c in controllers if "DRAM" in c.name), key=lambda c: c.location):
        leds = [(c.index, i) for i in range(c.num_leds)]
        sticks.append(leds[::-1] if cal.get("ram_led0") == "top" else leds)
    for c in (c for c in controllers if "DRAM" not in c.name):
        for z in c.zones:
            leds = [(c.index, z.start + i) for i in range(z.count)]
            if calibration and z.name == cal.get("fan_zone"):
                k = cal["leds_per_fan"]
                fans += [leds[hub * k:(hub + 1) * k] for hub in cal["order"]]
            elif not calibration and "Addressable" in z.name:
                fans.append(leds)
            else:
                board += leds
    return Layout(fans, sticks, board, {c.index: c.num_leds for c in controllers})


def compose(layout, scene, gate):
    """Every controller's full colour array for a Scene, scaled by the silence gate. LEDs the
    layout does not use stay dark."""
    out = {dev: [(0, 0, 0)] * n for dev, n in layout.sizes.items()}

    def put(leds, colours):
        for (dev, i), rgb in zip(leds, colours):
            out[dev][i] = tuple(round(c * gate) for c in rgb)

    for leds, colours in zip(layout.fans, scene.fans):
        put(leds, colours)
    for leds, colours in zip(layout.sticks, scene.sticks):
        put(leds, colours)
    put(layout.board, [scene.board] * len(layout.board))
    return out


class Silence:
    """1.0 while there is sound; after HOLD seconds of silence fades to 0.0 over FADE seconds."""
    THRESHOLD = 0.02
    HOLD = 1.5
    FADE = 0.5

    def __init__(self):
        self.quiet = 0.0

    def update(self, bands, dt):
        self.quiet = 0.0 if max(bands) >= self.THRESHOLD else self.quiet + dt
        return max(0.0, min(1.0, 1.0 - (self.quiet - self.HOLD) / self.FADE))


class Mode:
    def __init__(self, fan_sizes, stick_sizes):
        self.fan_sizes, self.stick_sizes = fan_sizes, stick_sizes

    def uniform(self, colour):
        return Scene([[colour] * n for n in self.fan_sizes], [[colour] * n for n in self.stick_sizes], colour)


class Pulse(Mode):
    """Everything flashes on a bass onset and fades out between beats; the colour steps to the
    next palette colour every BEATS_PER_COLOUR beats."""
    BASS = 3                  # lowest bands that make up the kick
    AVERAGE_TAU = 1.0         # the running bass level an onset has to stand out from
    ONSET_RATIO = 1.3
    ONSET_RISE = 0.15         # minimum jump from the previous frame
    ONSET_FLOOR = 0.15
    REFRACTORY = 0.15         # one kick drum is one beat
    FLASH_HALF_LIFE = 0.25
    REST = 0.4                # resting brightness at full loudness
    BEATS_PER_COLOUR = 4

    def __init__(self, fan_sizes, stick_sizes):
        super().__init__(fan_sizes, stick_sizes)
        self.average = self.previous = self.flash = 0.0
        self.since = self.REFRACTORY
        self.beats = 0

    def frame(self, bands, dt, palette):
        bass = mean(bands[:self.BASS])
        self.since += dt
        onset = (bass > self.ONSET_FLOOR and bass > self.ONSET_RATIO * self.average
                 and bass - self.previous > self.ONSET_RISE and self.since >= self.REFRACTORY)
        if onset:
            self.beats += 1
            self.since = 0.0
            self.flash = 1.0
        else:
            self.flash = decay(self.flash, dt, self.FLASH_HALF_LIFE)
        self.average = smooth(self.average, bass, dt, self.AVERAGE_TAU)
        self.previous = bass
        colour = palette[(max(self.beats, 1) - 1) // self.BEATS_PER_COLOUR % len(palette)]
        return self.uniform(shade(colour, max(self.flash, self.REST * mean(bands))))


class Spectrum(Mode):
    """Fans are frequency groups, bass to treble, each ring filled by its group's level; the two
    RAM sticks are meters for the low and high halves, with a held peak."""
    RING_FALL = 0.12          # half-life of a ring falling back
    STICK_FALL = 0.1
    PEAK_HOLD = 0.4
    PEAK_FALL = 1.5           # meter fractions per second once the hold is over

    def __init__(self, fan_sizes, stick_sizes):
        super().__init__(fan_sizes, stick_sizes)
        self.rings = [0.0] * len(fan_sizes)
        self.meters = [0.0] * len(stick_sizes)
        self.peaks = [0.0] * len(stick_sizes)
        self.held = [0.0] * len(stick_sizes)

    @staticmethod
    def groups(bands, n):
        return [mean(bands[i * len(bands) // n:(i + 1) * len(bands) // n]) for i in range(n)]

    def frame(self, bands, dt, palette):
        span = max(len(self.fan_sizes) - 1, 1)
        fans = []
        for i, (n, level) in enumerate(zip(self.fan_sizes, self.groups(bands, len(self.fan_sizes)))):
            self.rings[i] = max(level, decay(self.rings[i], dt, self.RING_FALL))
            fans.append(meter(n, self.rings[i], gradient(palette, i / span)))

        sticks = []
        for i, (n, level) in enumerate(zip(self.stick_sizes, self.groups(bands, len(self.stick_sizes)))):
            self.meters[i] = max(level, decay(self.meters[i], dt, self.STICK_FALL))
            if self.meters[i] >= self.peaks[i]:
                self.peaks[i], self.held[i] = self.meters[i], 0.0
            else:
                self.held[i] += dt
                if self.held[i] > self.PEAK_HOLD:
                    self.peaks[i] = max(self.meters[i], self.peaks[i] - self.PEAK_FALL * dt)
            colour = gradient(palette, (i + 0.5) / len(self.stick_sizes))
            leds = meter(n, self.meters[i], colour)
            if self.peaks[i] > 0:
                leds[min(n - 1, math.ceil(self.peaks[i] * n) - 1)] = colour
            sticks.append(leds)

        return Scene(fans, sticks, shade(gradient(palette, 0.5), mean(bands)))


class Colour(Mode):
    """One colour that glides along the palette with where the sound's energy sits (bass-heavy
    at the first colour, bright at the last), brightness following loudness. The fans are spread
    a little along the palette so the colour drifts across them."""
    CENTROID_LOW = 0.15       # spectral centroid mapped to the first palette colour
    CENTROID_HIGH = 0.6       # and to the last
    POSITION_TAU = 0.4
    LOUDNESS_TAU = 0.1
    FLOOR = 0.2               # brightness at the quietest audible sound
    SPREAD = 0.25             # palette distance from the first fan to the last

    def __init__(self, fan_sizes, stick_sizes):
        super().__init__(fan_sizes, stick_sizes)
        self.position = self.loudness = 0.0

    def frame(self, bands, dt, palette):
        total = sum(bands)
        if total > 0:
            centroid = sum(i * b for i, b in enumerate(bands)) / total / (len(bands) - 1)
            target = (centroid - self.CENTROID_LOW) / (self.CENTROID_HIGH - self.CENTROID_LOW)
            self.position = smooth(self.position, max(0.0, min(1.0, target)), dt, self.POSITION_TAU)
        self.loudness = smooth(self.loudness, mean(bands), dt, self.LOUDNESS_TAU)
        level = self.FLOOR + (1 - self.FLOOR) * self.loudness
        base = shade(gradient(palette, self.position), level)
        span = max(len(self.fan_sizes) - 1, 1)
        fans = [[shade(gradient(palette, self.position * (1 - self.SPREAD) + self.SPREAD * i / span), level)] * n
                for i, n in enumerate(self.fan_sizes)]
        return Scene(fans, [[base] * n for n in self.stick_sizes], base)


MODES = {"pulse": Pulse, "spectrum": Spectrum, "colour": Colour}
