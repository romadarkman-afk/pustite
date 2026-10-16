"""Build short, stylized voice cries with the Python standard library."""

import math
import random
import struct
import wave
from pathlib import Path


RATE = 24000
OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"


def cry(name: str, duration: float, base: float, monster: bool) -> None:
    rng = random.Random(173 if monster else 91)
    phase = 0.0
    samples = bytearray()
    count = int(RATE * duration)
    for i in range(count):
        t = i / RATE
        x = i / count
        envelope = min(1.0, x * 18.0) * min(1.0, (1.0 - x) * 7.0)
        envelope *= 0.85 + 0.15 * math.sin(2 * math.pi * x)
        pitch = base * (1.55 - 0.57 * x) if monster else base * (1.0 + 0.20 * math.sin(math.pi * x))
        pitch *= 1.0 + (0.048 if monster else 0.022) * math.sin(2 * math.pi * (13 if monster else 7) * t)
        phase += 2 * math.pi * pitch / RATE
        voice = 0.0
        for harmonic in range(1, 13):
            hz = pitch * harmonic
            resonance = math.exp(-((hz - (780 if monster else 850)) / 350) ** 2)
            resonance += 0.7 * math.exp(-((hz - (1550 if monster else 1350)) / 500) ** 2)
            voice += math.sin(phase * harmonic) * (0.12 + resonance) / harmonic
        breath = (rng.random() * 2.0 - 1.0) * (0.16 if monster else 0.06)
        if monster:
            voice += 0.3 * math.sin(phase * 0.5)
        value = math.tanh((voice + breath) * 2.0) * envelope * (0.52 if monster else 0.40)
        samples.extend(struct.pack("<h", int(max(-1.0, min(1.0, value)) * 32767)))
    with wave.open(str(OUT / name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(samples)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    cry("human_cry.wav", 0.74, 335, False)
    cry("upyr_cry.wav", 1.02, 170, True)
