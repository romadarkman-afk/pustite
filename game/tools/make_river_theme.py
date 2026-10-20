"""Собирает 32-секундную музыкальную петлю вступления у реки. Нужен только NumPy."""
from __future__ import annotations

import os
import sys
import wave

import numpy as np

RATE = 22050
SECONDS = 32
BAR = SECONDS / 4


def frequency(note: int, cents: float = 0.0) -> float:
    hz = 440.0 * 2.0 ** ((note - 69) / 12.0 + cents / 1200.0)
    return round(hz * SECONDS) / SECONDS


def pan_add(out: np.ndarray, voice: np.ndarray, pan: float, gain: float) -> None:
    pan = float(np.clip(pan, -0.8, 0.8))
    out[:, 0] += voice * gain * np.sqrt((1.0 - pan) * 0.5)
    out[:, 1] += voice * gain * np.sqrt((1.0 + pan) * 0.5)


def add_pad(out: np.ndarray, t: np.ndarray, note: int, weight: np.ndarray, gain: float, pan: float) -> None:
    breath = 0.94 + 0.06 * np.sin(2.0 * np.pi * t / 6.7 + note * 0.13)
    for cents, channel, side in ((-3.5, 0, -1), (3.5, 1, 1)):
        hz = frequency(note, cents)
        phase = 2.0 * np.pi * hz * t + 0.025 * np.sin(2.0 * np.pi * 0.18 * t)
        tone = np.sin(phase) + 0.22 * np.sin(2.0 * phase + 0.2) + 0.065 * np.sin(3.0 * phase + 0.5)
        p = float(np.clip(pan + side * 0.07, -0.85, 0.85))
        out[:, channel] += tone * weight * breath * gain * np.sqrt((1.0 + side * p) * 0.5)


def add_pluck(out: np.ndarray, t: np.ndarray, start: float, note: int, gain: float, pan: float) -> None:
    elapsed = t - start
    active = (elapsed >= 0.0) & (elapsed < 2.9)
    local = np.maximum(elapsed, 0.0)
    attack = np.clip(local / 0.018, 0.0, 1.0)
    envelope = attack * np.exp(-local / 1.25) * active
    hz = frequency(note)
    # Мягкий щипок с быстрыми верхними обертонами и длинным низким хвостом.
    tone = (np.sin(2.0 * np.pi * hz * elapsed)
            + 0.31 * np.sin(2.0 * np.pi * hz * 2.0 * elapsed + 0.3) * np.exp(-local / 0.55)
            + 0.12 * np.sin(2.0 * np.pi * hz * 3.0 * elapsed + 0.7) * np.exp(-local / 0.3))
    pan_add(out, tone * envelope, pan, gain)


def compose() -> np.ndarray:
    count = RATE * SECONDS
    t = np.arange(count, dtype=np.float32) / RATE
    out = np.zeros((count, 2), dtype=np.float32)
    chords = [
        [50, 53, 57, 64],  # Dm(add9)
        [46, 50, 53, 57],  # Bbmaj7
        [43, 46, 50, 57],  # Gm(add9)
        [45, 50, 52, 55],  # Asus4
    ]
    slot = np.floor(t / BAR).astype(np.int8)
    inside = np.mod(t, BAR)
    fade = 1.4
    progress = np.clip(inside / fade, 0.0, 1.0)
    swell = (0.5 - 0.5 * np.cos(np.pi * progress)).astype(np.float32)
    for i, chord in enumerate(chords):
        weight = np.where(slot == i, swell, 0.0)
        weight += np.where(slot == (i + 1) % len(chords), 1.0 - swell, 0.0)
        weight = weight.astype(np.float32)
        add_pad(out, t, chord[0] - 12, weight, 0.07, 0.0)
        for j, note in enumerate(chord):
            add_pad(out, t, note, weight, 0.045, (j - 1.5) * 0.23)

    # Длинный низкий гул держит сцену, а смена басовых нот задаёт движение гармонии.
    drone = 0.035 * (np.sin(2.0 * np.pi * frequency(26) * t)
                     + 0.18 * np.sin(2.0 * np.pi * frequency(38) * t + 0.4))
    out[:, 0] += drone
    out[:, 1] += drone

    # Негромкая мелодия в низком регистре, с паузами между фразами.
    melody = [
        (0.8, 62), (3.0, 57), (5.0, 65), (7.0, 64),
        (8.8, 62), (11.0, 65), (13.0, 69), (15.0, 65),
        (16.8, 55), (19.0, 62), (21.0, 58), (23.0, 62),
        (24.8, 57), (27.0, 64), (29.0, 62), (30.7, 61),
    ]
    for i, (start, note) in enumerate(melody):
        add_pluck(out, t, start, note, 0.058, -0.18 if i % 2 else 0.18)

    # Тихие долгие ноты виолончели добавляют опору под фразами.
    for i, note in enumerate((38, 34, 31, 33)):
        start = i * BAR
        elapsed = np.mod(t - start, SECONDS)
        tail = np.clip((BAR - elapsed) / 2.0, 0.0, 1.0)
        env = np.where(elapsed < BAR, np.minimum(1.0, elapsed / 1.1) * np.exp(-elapsed / 9.0) * tail, 0.0)
        hz = frequency(note)
        bowed = np.sin(2.0 * np.pi * hz * t) + 0.17 * np.sin(2.0 * np.pi * hz * 2.0 * t + 0.25)
        pan_add(out, bowed * env.astype(np.float32), 0.0, 0.055)

    dry = out.copy()
    out[:, 0] += np.roll(dry[:, 1], int(0.31 * RATE)) * 0.12
    out[:, 1] += np.roll(dry[:, 0], int(0.43 * RATE)) * 0.1
    peak = float(np.max(np.abs(out))) or 1.0
    out *= min(1.0, 0.3 / peak)
    return np.clip(out, -0.95, 0.95)


def main() -> None:
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    path = os.path.join(root, "assets", "music", "river_theme.wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (compose() * 32767.0).astype("<i2")
    with wave.open(path, "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())
    print(f"{path}: {os.path.getsize(path) // 1024} KB, {SECONDS} sec, stereo {RATE} Hz")


if __name__ == "__main__":
    main()
