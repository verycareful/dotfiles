"""cava as the audio front end: it captures the default output's monitor through PipeWire (and
follows it when the output changes), runs the FFT with its own auto-gain, and streams one frame
of bar levels at a time to stdout.
"""
import struct

NOISE_REDUCTION = 30          # cava's own smoothing, kept low so Pulse still sees sharp onsets


def cava_config(bands, fps):
    return f"""[general]
framerate = {fps}
bars = {bands}
autosens = 1
sleep_timer = 0

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = binary
bit_format = 16bit
channels = mono
mono_option = average

[smoothing]
noise_reduction = {NOISE_REDUCTION}
"""


def frame_size(bands):
    return 2 * bands


def decode(frame):
    return [v / 65535 for v in struct.unpack(f"<{len(frame) // 2}H", frame)]
