"""Звуки пролога «Пустите»: тихое раскрытие роли в трёх вариантах и фон сумерек без сверчков.
reveal, reveal_2, reveal_3 — короткие и низкие, вместо прежнего звенящего подъёма.
amb_dusk — пролог: ровный низкий ветер, далёкая сова, без высоких частот.
Запуск из папки game: python3 tools/make_prologue_sfx.py .
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sfx as S  # noqa: E402

SR = S.SR


def bell_tone(f, sec, decay, partials=((1, 1.0), (2.01, 0.25), (2.76, 0.12))):
    n = int(SR * sec)
    t = np.arange(n) / SR
    x = sum(g * np.sin(2 * np.pi * f * r * t) * np.exp(-t / (decay / r ** 0.5)) for r, g in partials)
    return x * np.minimum(1, t / 0.01)


def reveal_low_bell():
    """Один низкий удар колокола вдалеке."""
    x = bell_tone(146.8, 1.4, 0.7) + 0.5 * bell_tone(220.0, 1.4, 0.45)
    return S.norm(S.lp(x, 1800), 0.5)


def reveal_wood():
    """Два глухих деревянных тона, как стук по бревну в тишине."""
    n = int(SR * 1.1)
    x = np.zeros(n)
    for start, f in ((0.0, 196.0), (0.22, 164.8)):
        s = int(SR * start)
        y = bell_tone(f, 1.1 - start, 0.22, ((1, 1.0), (2.4, 0.3)))
        x[s:s + len(y)] += y
    return S.norm(S.lp(x, 1400), 0.5)


def reveal_breath():
    """Выдох и низкий гул: короткий, без звона."""
    sec = 1.3
    n = int(SR * sec)
    t = np.arange(n) / SR
    breath = S.bp(S.noise(sec), 250, 1200) * np.interp(t, [0, 0.25, 1.0, sec], [0, 0.6, 0.15, 0])
    hum = np.sin(2 * np.pi * 110 * t) * np.interp(t, [0, 0.3, sec], [0, 0.5, 0])
    return S.norm(S.lp(breath * 0.6 + hum, 1200), 0.45)


def amb_dusk():
    """Сумерки: низкий ветер, раз за цикл далёкая сова."""
    sec = 20.0
    x = S.lp(S.norm(S.wind(sec, 1.0), 0.2), 420)
    t = S.t_of(sec)
    for start in (6.0, 6.55):
        s = int(SR * start)
        m = int(SR * 0.42)
        tt = np.arange(m) / SR
        hoot = np.sin(2 * np.pi * (390 - 40 * tt) * tt) * np.sin(np.pi * tt / 0.42) ** 2
        x[s:s + m] += hoot * 0.035
    return S.loopify(S.norm(x, 0.4), 0.8)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sfx = os.path.join(root, 'assets', 'sfx')
    for name, fn in (('reveal', reveal_low_bell), ('reveal_2', reveal_wood), ('reveal_3', reveal_breath), ('amb_dusk', amb_dusk)):
        S.save(os.path.join(sfx, name + '.ogg'), fn())
        print(name)


if __name__ == '__main__':
    main()
