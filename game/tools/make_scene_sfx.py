"""Звуки сцен (TASK-012–014): дыхание за дверью, разбитая чашка, молоток, щелчок засова,
шаги по половицам, фон реки. Всё синтезом, без чужих записей.
Запуск из папки game: python3 tools/make_scene_sfx.py .
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sfx as S  # noqa: E402

SR = S.SR


def env(t, pts):
    xs, ys = zip(*pts)
    return np.interp(t, xs, ys)


def breath():
    """Тяжёлое дыхание за дверью: два вдоха и два выдоха, глухо, через доски."""
    sec = 3.2
    t = S.t_of(sec)
    x = np.zeros_like(t)
    for start, dur, g in ((0.0, 0.7, 0.6), (0.8, 0.9, 0.8), (1.8, 0.65, 0.55), (2.5, 0.7, 0.75)):
        s = int(SR * start)
        n = int(SR * dur)
        tt = np.arange(n) / SR
        b = S.bp(S.noise(dur), 180, 900)[:n] * np.sin(np.pi * tt / dur) ** 1.5
        x[s:s + n] += b * g
    return S.norm(S.lp(x, 700), 0.5)


def cup_break():
    """Чашка падает на доски: короткий удар и осколки."""
    sec = 1.2
    t = S.t_of(sec)
    thud = np.sin(2 * np.pi * 140 * t) * np.exp(-t / 0.05)
    x = thud * 0.6
    rng = np.random.default_rng(7)
    for k in range(9):
        s = int(SR * (0.03 + rng.uniform(0, 0.5) * (k / 9 + 0.1)))
        n = int(SR * rng.uniform(0.03, 0.09))
        tt = np.arange(n) / SR
        f = rng.uniform(2200, 5200)
        piece = np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.02) * rng.uniform(0.2, 0.5)
        x[s:s + n] += piece[: len(x[s:s + n])]
    x += S.hp(S.noise(sec), 3000) * np.exp(-t / 0.08) * 0.3
    return S.norm(x, 0.55)


def hammer():
    """Два удара молотка по гвоздю и тишина."""
    sec = 1.8
    t = S.t_of(sec)
    x = np.zeros_like(t)
    for start in (0.0, 0.55):
        s = int(SR * start)
        n = int(SR * 0.4)
        tt = np.arange(n) / SR
        hit = (np.sin(2 * np.pi * 1800 * tt) * 0.4 + np.sin(2 * np.pi * 320 * tt)) * np.exp(-tt / 0.045)
        hit += S.noise(0.4)[:n] * np.exp(-tt / 0.01) * 0.5
        x[s:s + n] += hit
    return S.norm(x, 0.55)


def latch():
    """Щелчок засова."""
    sec = 0.4
    t = S.t_of(sec)
    x = S.hp(S.noise(sec), 1500) * np.exp(-t / 0.012)
    s = int(SR * 0.09)
    x[s:] += (S.hp(S.noise(sec), 900) * np.exp(-t / 0.02))[: len(x) - s] * 0.7
    return S.norm(x, 0.5)


def floorboard():
    """Скрип половицы под шагом."""
    sec = 0.9
    t = S.t_of(sec)
    f = 420 + 120 * np.sin(2 * np.pi * 1.3 * t)
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sign(np.sin(phase)) * 0.3 + np.sin(phase)
    x = S.bp(x, 300, 1600) * env(t, [(0, 0), (0.1, 0.8), (0.6, 0.5), (sec, 0)])
    return S.norm(x, 0.4)


def amb_river():
    """Река ночью: ровная вода у мостков и редкие всплески."""
    sec = 20.0
    t = S.t_of(sec)
    water = S.lp(S.bp(S.noise(sec), 200, 1400), 1200) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.11 * t))
    rng = np.random.default_rng(3)
    for _ in range(14):
        s = int(SR * rng.uniform(0.5, sec - 1))
        n = int(SR * 0.25)
        tt = np.arange(n) / SR
        drop = np.sin(2 * np.pi * rng.uniform(500, 900) * tt * (1 + 2 * tt)) * np.exp(-tt / 0.05) * 0.25
        water[s:s + n] += drop
    x = water * 0.6 + S.lp(S.norm(S.wind(sec, 1.0), 0.15), 400)
    return S.loopify(S.norm(x, 0.4), 0.8)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sfx = os.path.join(root, 'assets', 'sfx')
    for name, fn in (('breath', breath), ('cup_break', cup_break), ('hammer', hammer), ('latch', latch),
                     ('floorboard', floorboard), ('amb_river', amb_river)):
        S.save(os.path.join(sfx, name + '.ogg'), fn())
        print(name)


if __name__ == '__main__':
    main()
