"""One-off generator for the two answer-feedback tones (correct.wav /
incorrect.wav) checked into this folder. Not part of the app build --
kept only so the tones can be regenerated/tweaked later without needing
an audio editor. Pure stdlib (wave + math), 16-bit mono PCM 44100Hz.
"""

import math
import wave
import struct

SAMPLE_RATE = 44100


def _tone(freq, duration_s, amplitude=0.8, fade_s=0.01):
    n = int(SAMPLE_RATE * duration_s)
    fade_n = max(1, int(SAMPLE_RATE * fade_s))
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        envelope = 1.0
        if i < fade_n:
            envelope = i / fade_n
        elif i > n - fade_n:
            envelope = (n - i) / fade_n
        samples.append(amplitude * envelope * math.sin(2 * math.pi * freq * t))
    return samples


def _silence(duration_s):
    return [0.0] * int(SAMPLE_RATE * duration_s)


def _write(path, samples):
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(frames)


# Correct: a bright, quick two-note ascending chime (major third up) --
# reads as "nice".
correct = _tone(880.00, 0.09) + _tone(1174.66, 0.12)
_write("correct.wav", correct)

# Incorrect: two short low pulses -- a "buzz-buzz" that pairs with the
# double-pulse "zig zig" vibration pattern, reads as distinctly "off".
incorrect = _tone(196.00, 0.09) + _silence(0.04) + _tone(196.00, 0.09)
_write("incorrect.wav", incorrect)

print("wrote correct.wav and incorrect.wav")
