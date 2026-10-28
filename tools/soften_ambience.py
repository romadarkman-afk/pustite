#!/usr/bin/env python3
"""Смягчает два постоянных фона, которые резали слух на динамике телефона (отзыв Влади, 0.65.0).

  amb_night: ритмичный стрекот на 3,3 кГц и полосы около 7 кГц убраны фильтром, остаются низкий гул и шум.
  amb_day:   птицы 2-8 кГц тише на 9 дБ выше 2 кГц и срезаны выше 6 кГц, общий уровень ниже на 2 дБ.

Исходники лежат в art/refs/orig_sfx/. Запуск из корня репозитория:
  python3 tools/soften_ambience.py          обработать и записать в game/assets/sfx
  python3 tools/soften_ambience.py --report  только цифры до и после

Фильтр нулевой фазы, сигнал берётся трижды подряд и из середины вырезается один круг, поэтому шов петли не появляется.
"""
import pathlib
import subprocess
import sys

import numpy as np
from scipy import signal

ROOT = pathlib.Path(__file__).resolve().parents[1]
ORIG = ROOT / "art" / "refs" / "orig_sfx"
DST = ROOT / "game" / "assets" / "sfx"
SR = 32000


def decode(p):
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", str(p), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True)
    return np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64)


def encode(x, dst):
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    r = subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
                        "-c:a", "libvorbis", "-q:a", "3", str(dst)], input=pcm, capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode("utf-8", "replace")[:300])


def loopsafe(x, fn):
    n = len(x)
    y = fn(np.concatenate([x, x, x]))
    return y[n:2 * n]


def lowpass(x, hz, order=4):
    sos = signal.butter(order, hz, btype="low", fs=SR, output="sos")
    return signal.sosfiltfilt(sos, x)


def notch(x, hz, q, depth_db):
    b, a = signal.iirnotch(hz, q, fs=SR)
    y = signal.filtfilt(b, a, x)
    mix = 1.0 - 10 ** (-depth_db / 20.0)
    return x - mix * (x - y)


def night(x):
    return loopsafe(x, lambda s: lowpass(s, 1800.0, 6))


def day(x):
    def f(s):
        low = lowpass(s, 2000.0, 4)
        high = lowpass(s - low, 6000.0, 4)
        return low + high * 10 ** (-9.0 / 20.0)
    return loopsafe(x, f) * 10 ** (-2.0 / 20.0)


JOBS = {"amb_night": night, "amb_day": day}


def a_weighted_db(x):
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    s = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f2 = np.maximum(f, 1.0) ** 2
    ra = (12194.0 ** 2 * f2 ** 2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2)) * (f2 + 12194.0 ** 2))
    return 10 * np.log10(np.sum(s * ra ** 2) / np.sum(np.hanning(len(x)) ** 2) / len(x) * 2 + 1e-18)


def share_above(x, hz):
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    s = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    return 10 * np.log10(s[f >= hz].sum() / s.sum() + 1e-18)


def main():
    report = "--report" in sys.argv
    for name, fn in JOBS.items():
        x = decode(ORIG / (name + ".ogg"))
        y = fn(x)
        print("%-10s  уровень по А: %6.1f -> %6.1f дБ   доля энергии выше 2 кГц: %6.1f -> %6.1f дБ   выше 3 кГц: %6.1f -> %6.1f дБ" % (
            name, a_weighted_db(x), a_weighted_db(y), share_above(x, 2000), share_above(y, 2000), share_above(x, 3000), share_above(y, 3000)))
        if not report:
            encode(y, DST / (name + ".ogg"))


if __name__ == "__main__":
    main()
