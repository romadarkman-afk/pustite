"""Render the menu's original 40-second folk-horror theme with NumPy only."""
from __future__ import annotations

import os
import sys
import wave

import numpy as np

RATE = 24000
OUTPUT_RATE = 13500
BPM = 72.0
BEAT = 60.0 / BPM
BAR = BEAT * 3.0
BARS = 16
SECONDS = BAR * BARS


def hz(note: int, cents: float = 0.0) -> float:
    return 440.0 * 2.0 ** ((note - 69 + cents / 100.0) / 12.0)


def pan(out: np.ndarray, signal: np.ndarray, start: int, side: float, gain: float) -> None:
    end = min(out.shape[0], start + signal.size)
    if end <= start:
        return
    signal = signal[:end - start] * gain
    side = float(np.clip(side, -0.85, 0.85))
    out[start:end, 0] += signal * np.sqrt((1.0 - side) * 0.5)
    out[start:end, 1] += signal * np.sqrt((1.0 + side) * 0.5)


def add_string(out: np.ndarray, start_s: float, note: int, length: float, gain: float, side: float) -> None:
    start = max(0, round(start_s * RATE))
    duration = min(round((length + 1.0) * RATE), out.shape[0] - start)
    if duration <= 0:
        return
    t = np.arange(duration, dtype=np.float32) / RATE
    attack = np.minimum(1.0, t / 0.75)
    release = np.clip((length + 1.0 - t) / 1.0, 0.0, 1.0)
    env = attack * release
    vibrato = 0.0023 * np.sin(2.0 * np.pi * 5.1 * t)
    phase = 2.0 * np.pi * hz(note) * t + 0.045 * np.sin(2.0 * np.pi * 0.22 * t)
    wave_a = (0.62 * np.sin(phase + vibrato)
              + 0.24 * np.sin(2.0 * phase + 0.2)
              + 0.095 * np.sin(3.0 * phase + 0.43)
              + 0.035 * np.sin(4.0 * phase + 0.7))
    phase_b = 2.0 * np.pi * hz(note, 4.2) * t + 0.04 * np.sin(2.0 * np.pi * 0.19 * t + 1.2)
    wave_b = (0.6 * np.sin(phase_b - vibrato)
              + 0.25 * np.sin(2.0 * phase_b + 0.1)
              + 0.1 * np.sin(3.0 * phase_b + 0.6))
    pan(out, (wave_a + wave_b) * env, start, side, gain)


def add_bell(out: np.ndarray, start_s: float, note: int, gain: float, side: float) -> None:
    start = max(0, round(start_s * RATE))
    duration = min(round(2.3 * RATE), out.shape[0] - start)
    if duration <= 0:
        return
    t = np.arange(duration, dtype=np.float32) / RATE
    f = hz(note)
    env = (1.0 - np.exp(-t / 0.014)) * np.exp(-t / 0.8)
    tone = (np.sin(2.0 * np.pi * f * t)
            + 0.42 * np.sin(2.0 * np.pi * f * 2.01 * t + 0.3) * np.exp(-t / 0.45)
            + 0.18 * np.sin(2.0 * np.pi * f * 3.92 * t + 0.8) * np.exp(-t / 0.2)
            + 0.06 * np.sin(2.0 * np.pi * f * 5.4 * t + 1.1) * np.exp(-t / 0.1))
    pan(out, tone * env, start, side, gain)


def add_low_pulse(out: np.ndarray, start_s: float, note: int, gain: float) -> None:
    start = max(0, round(start_s * RATE))
    duration = min(round(1.0 * RATE), out.shape[0] - start)
    if duration <= 0:
        return
    t = np.arange(duration, dtype=np.float32) / RATE
    f = hz(note)
    env = (1.0 - np.exp(-t / 0.025)) * np.exp(-t / 0.28)
    tone = np.sin(2.0 * np.pi * f * t) + 0.23 * np.sin(2.0 * np.pi * f * 2.0 * t + 0.3)
    pan(out, tone * env, start, 0.0, gain)


def compose() -> np.ndarray:
    out = np.zeros((round(RATE * SECONDS), 2), dtype=np.float32)
    chords = [
        ([50, 57, 60, 64, 65], 38),  # Dm(add9)
        ([46, 53, 57, 60, 62], 34),  # Bbmaj7
        ([48, 53, 57, 60, 64], 41),  # F(add9)/A
        ([45, 52, 55, 58, 60], 33),  # A7sus
        ([43, 50, 53, 57, 62], 31),  # Gm9
        ([41, 48, 53, 57, 60], 29),  # Dm/F
        ([46, 53, 57, 60, 65], 34),  # Bbmaj7
        ([45, 52, 55, 58, 61], 33),  # A7
    ]
    for bar in range(BARS):
        chord, bass = chords[(bar // 2) % len(chords)]
        start = bar * BAR
        for index, note in enumerate(chord):
            add_string(out, start, note, BAR * 2.0 + 0.15, 0.039 if index else 0.048, (index - 2) * 0.17)
        if bar % 2 == 0:
            add_string(out, start, bass, BAR * 2.0 + 0.25, 0.085, 0.0)

    # The repeated five-note hook gives the menu a clear, recognizable phrase.
    hook = [(0.0, 69), (0.75, 74), (1.5, 77), (2.0, 76), (2.5, 74),
            (3.5, 69), (4.0, 72), (4.5, 74), (5.0, 77), (5.75, 76), (6.5, 74), (7.0, 69)]
    variation = [(16.0, 69), (16.75, 74), (17.5, 77), (18.0, 79), (18.5, 77),
                 (19.0, 76), (20.0, 74), (20.75, 72), (21.5, 74), (22.0, 69), (23.0, 74)]
    for repeat in range(2):
        offset = repeat * BAR * 8.0
        for beat, note in hook + variation:
            add_bell(out, offset + beat * BEAT, note, 0.045, -0.22 if int(beat * 2) % 2 else 0.22)

    # A lower answer alternates with the hook, like a distant fiddle under the bell line.
    answer = [(9.0, 65), (9.75, 69), (10.5, 72), (11.0, 69), (11.5, 67),
              (12.5, 65), (13.0, 64), (13.5, 62), (14.0, 60), (15.0, 62),
              (16.0, 62), (16.75, 65), (17.5, 69), (18.0, 72), (18.5, 69),
              (19.0, 67), (20.0, 65), (20.75, 64), (21.5, 62), (22.0, 60), (23.0, 62)]
    for repeat in range(2):
        offset = repeat * BAR * 8.0
        for beat, note in answer:
            add_string(out, offset + beat * BEAT, note, 0.55, 0.035, 0.12 if int(beat) % 2 else -0.12)

    # Gentle three-beat pulse keeps the waltz moving without sounding like combat music.
    for bar in range(BARS):
        chord, bass = chords[(bar // 2) % len(chords)]
        for beat, gain in ((0.0, 0.017), (1.5, 0.009)):
            add_low_pulse(out, (bar + beat / 3.0) * BAR, bass, gain)

    # Short, dark room reflections soften the additive instruments and widen the image.
    dry = out.copy()
    for delay, gain, swap in ((0.13, 0.16, False), (0.23, 0.11, True), (0.37, 0.075, False), (0.51, 0.045, True)):
        shift = round(delay * RATE)
        if swap:
            out[shift:, 0] += dry[:-shift, 1] * gain
            out[shift:, 1] += dry[:-shift, 0] * gain
        else:
            out[shift:, :] += dry[:-shift, :] * gain

    # A short equal-power crossfade makes the ending resolve into the opening chord.
    fade = round(0.9 * RATE)
    x = np.linspace(0.0, np.pi * 0.5, fade, dtype=np.float32)
    tail = out[-fade:].copy()
    head = out[:fade].copy()
    bridge = tail * np.cos(x)[:, None] + head * np.sin(x)[:, None]
    out = np.concatenate((out[fade:-fade], bridge), axis=0)
    peak = float(np.max(np.abs(out))) or 1.0
    out *= min(1.0, 0.78 / peak)
    return np.tanh(out * 1.08) / np.tanh(1.08)


def resample_for_budget(audio: np.ndarray) -> np.ndarray:
    """Band-limit at the target Nyquist frequency, then resample in the FFT domain."""
    target_len = round(len(audio) * OUTPUT_RATE / RATE)
    spectrum = np.fft.rfft(audio, axis=0)
    spectrum = spectrum[:target_len // 2 + 1]
    spectrum *= target_len / len(audio)
    return np.fft.irfft(spectrum, n=target_len, axis=0).astype(np.float32)


def main() -> None:
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    path = os.path.join(root, "assets", "music", "menu_theme.wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    audio = resample_for_budget(compose())
    pcm = np.clip(audio * 32767.0, -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(OUTPUT_RATE)
        stream.writeframes(pcm.tobytes())
    print(f"{path}: {os.path.getsize(path) // 1024} KB, {len(pcm) / OUTPUT_RATE:.1f} sec, stereo {OUTPUT_RATE} Hz")


if __name__ == "__main__":
    main()
