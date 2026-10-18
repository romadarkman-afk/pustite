"""Звуки станции (TASK-031–035): дальний гудок, лязг рельсов, пишущая машинка списка,
стук колёс подходящего поезда. Всё синтезом, без чужих записей.
Запуск из папки game: python3 tools/make_station_sfx.py .
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sfx as S  # noqa: E402

SR = S.SR


def whistle():
    """Паровозный гудок вдалеке: два голоса аккорда, медленная атака, эхо от леса."""
    sec = 3.2
    t = S.t_of(sec)
    e = np.clip(t / 0.5, 0, 1) * np.clip((2.6 - t) / 0.8, 0, 1)
    x = np.zeros_like(t)
    for f, g in ((311.0, 0.5), (370.0, 0.4), (466.0, 0.25)):
        x += g * np.sin(2 * np.pi * f * t + 0.6 * np.sin(2 * np.pi * 5.3 * t))
    x += 0.25 * S.bp(S.noise(sec), 250, 900)[:len(t)]
    x = S.lp(x * e, 1400)
    echo = np.zeros_like(x)
    d = int(SR * 0.45)
    echo[d:] = x[:-d] * 0.35
    return S.norm(x + echo, 0.5)


def rails():
    """Лязг рельсов: металлические удары с долгим звоном."""
    sec = 1.6
    t = S.t_of(sec)
    x = np.zeros_like(t)
    for start, g in ((0.0, 1.0), (0.32, 0.7)):
        s = int(SR * start)
        tt = t[: len(t) - s]
        ring = sum(np.sin(2 * np.pi * f * tt) * a for f, a in ((1180, 0.5), (1730, 0.3), (2610, 0.2)))
        x[s:] += g * ring * np.exp(-tt / 0.35) + g * S.hp(S.noise(sec), 2000)[: len(tt)] * np.exp(-tt / 0.02)
    return S.norm(x, 0.45)


def typewriter():
    """Пишущая машинка: пять ударов клавиш и звонок каретки."""
    sec = 1.5
    t = S.t_of(sec)
    x = np.zeros_like(t)
    rng = np.random.default_rng(7)
    pos = 0.05
    for _ in range(5):
        s = int(SR * pos)
        n = int(SR * 0.06)
        tt = np.arange(n) / SR
        click = S.bp(S.noise(0.06), 1500, 5000)[:n] * np.exp(-tt / 0.008)
        thud = np.sin(2 * np.pi * 180 * tt) * np.exp(-tt / 0.02) * 0.6
        x[s:s + n] += click + thud
        pos += rng.uniform(0.11, 0.18)
    s = int(SR * 1.1)
    tt = t[: len(t) - s]
    x[s:] += 0.35 * np.sin(2 * np.pi * 2350 * tt) * np.exp(-tt / 0.25)
    return S.norm(x, 0.45)


def train():
    """Подходящий поезд: стук колёс всё чаще и громче, гул, в конце шипение пара."""
    sec = 5.0
    t = S.t_of(sec)
    x = 0.4 * S.lp(S.noise(sec), 180) * (t / sec)
    beat = 0.0
    k = 0
    while beat < sec - 0.3:
        s = int(SR * beat)
        n = int(SR * 0.09)
        tt = np.arange(n) / SR
        hit = (S.bp(S.noise(0.09), 300, 1800)[:n] + np.sin(2 * np.pi * 90 * tt)) * np.exp(-tt / 0.03)
        x[s:s + n] += hit * (0.25 + 0.75 * beat / sec) * (1.0 if k % 2 == 0 else 0.7)
        beat += 0.42 - 0.3 * (beat / sec)
        k += 1
    s = int(SR * (sec - 1.4))
    tt = t[: len(t) - s]
    x[s:] += 0.5 * S.hp(S.noise(sec), 2500)[: len(tt)] * np.clip(tt / 0.2, 0, 1) * np.exp(-tt / 0.8)
    return S.norm(x, 0.55)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sfx = os.path.join(root, 'assets', 'sfx')
    for name, fn in (('whistle', whistle), ('rails', rails), ('typewriter', typewriter), ('train', train)):
        S.save(os.path.join(sfx, name + '.ogg'), fn(), q=0)
        print(name)


if __name__ == '__main__':
    main()
