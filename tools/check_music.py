#!/usr/bin/env python3
"""Проверка музыкальных тем: длина 60-90 с, громкость около -16 LUFS, стыки цикла без щелчка.

Запуск из корня репозитория:
  python3 tools/check_music.py                    все theme_*.ogg в game/assets/music
  python3 tools/check_music.py файл1.ogg файл2.ogg
Громкость меряет ffmpeg (фильтр ebur128). Допуск ±1.5 LUFS. Код возврата 1, если что-то не так.
"""
import glob
import os
import re
import subprocess
import sys

import numpy as np

DIR = os.path.join("game", "assets", "music")
SR = 22050


def lufs(path):
    r = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.findall(r"I:\s+(-?\d+\.\d+) LUFS", r.stderr)
    return float(m[-1]) if m else None


def samples(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def check(path):
    problems = []
    x = samples(path)
    sec = len(x) / SR
    if not 60.0 <= sec <= 90.0:
        problems.append("длина %.1f с, нужно 60-90" % sec)
    loud = lufs(path)
    if loud is None:
        problems.append("громкость не измерилась")
    elif abs(loud + 16.0) > 1.5:
        problems.append("громкость %.1f LUFS, нужно -16 ±1,5" % loud)
    # стык цикла: разница уровней последних и первых 0,5 с и скачок между последним и первым отсчётом
    k = int(SR * 0.5)
    head = float(np.sqrt(np.mean(x[:k] ** 2)) + 1e-6)
    tail = float(np.sqrt(np.mean(x[-k:] ** 2)) + 1e-6)
    ratio = max(head, tail) / min(head, tail)
    jump = abs(float(x[0] - x[-1]))
    if ratio > 2.0:
        problems.append("уровень конца и начала отличается в %.1f раза: цикл будет слышно" % ratio)
    if jump > 0.1:
        problems.append("скачок на стыке цикла %.2f: будет щелчок" % jump)
    print("%-6s %s  %.1f с, %s LUFS" % ("ок" if not problems else "ОШИБКА", os.path.basename(path), sec,
                                          "%.1f" % loud if loud is not None else "?"))
    for p in problems:
        print("       - " + p)
    return not problems


def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(DIR, "theme_*.ogg")))
    if not files:
        print("тем пока нет: положите theme_act1..4.ogg, theme_pair.ogg, theme_climax.ogg в %s" % DIR)
        return 0
    bad = sum(0 if check(f) else 1 for f in files)
    print("тем: %d, с замечаниями: %d" % (len(files), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
