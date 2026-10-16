"""Звуки страха «Пустите» (v0.37): царапанье, шёпот, шаги по крыше, скрип, далёкий крик,
рык, хрип, зов из леса, резкий удар и плач у двери.
Запуск из папки game: python3 tools/make_dread.py .  → assets/sfx/<имя>.ogg
Остальные звуки этот скрипт не трогает. Любой файл можно заменить записью с тем же именем.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sfx as S  # noqa: E402

SR = S.SR
rng = np.random.default_rng(41)


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def place(out, x, at):
    s = int(SR * at)
    e = min(len(out), s + len(x))
    out[s:e] += x[:e - s]


def room(x, decay=0.35, mix=0.35):
    """Простая «комната»: несколько затухающих отражений."""
    out = x.copy()
    for d, g in [(0.031, 0.5), (0.047, 0.42), (0.071, 0.33), (0.113, 0.25), (0.167, 0.17)]:
        k = int(SR * d)
        sh = np.zeros_like(x)
        sh[k:] = x[:-k]
        out += sh * g * mix / 0.5
    return out * (1 - decay * 0.2)


def far(x, hz=1400):
    """Звук издалека: срез верха, отражения, тише."""
    return room(S.lp(x, hz, 2), mix=0.6)


def scratch():
    """Когти по доскам двери: три медленных проведения с прерывистым треском."""
    sec = 2.4
    out = np.zeros(int(SR * sec))
    for at, dur in [(0.05, 0.55), (0.8, 0.7), (1.65, 0.6)]:
        n = int(SR * dur)
        t = np.arange(n) / SR
        grain = (rng.random(n) < 0.04 + 0.05 * np.sin(np.pi * t / dur)).astype(float)
        grain = S.bp(grain + 0.15 * rng.standard_normal(n), 1800, 6500)
        body = S.bp(rng.standard_normal(n), 300, 1200) * 0.35
        e = np.sin(np.pi * t / dur) ** 0.7
        place(out, (grain + body) * e, at)
    return S.norm(room(out, mix=0.2), 0.7)


def whisper():
    """Шёпот за стеной: шумовые слоги с плывущими формантами."""
    sec = 2.6
    out = np.zeros(int(SR * sec))
    at = 0.1
    while at < sec - 0.3:
        dur = rng.uniform(0.12, 0.3)
        n = int(SR * dur)
        t = np.arange(n) / SR
        f1 = rng.uniform(600, 1100)
        f2 = rng.uniform(1600, 2800)
        x = S.bp(rng.standard_normal(n), f1 * 0.8, f1 * 1.25) + 0.7 * S.bp(rng.standard_normal(n), f2 * 0.85, f2 * 1.2)
        x += 0.5 * S.hp(rng.standard_normal(n), 4500)                 # «с», «ш»
        x *= np.sin(np.pi * t / dur) ** 1.5
        place(out, x, at)
        at += dur + rng.uniform(0.02, 0.18)
    return S.norm(far(out, 5200), 0.55)


def roof_steps():
    """Шаги по крыше: тяжёлые глухие удары, между ними скрип досок."""
    sec = 3.2
    out = np.zeros(int(SR * sec))
    for k, at in enumerate([0.1, 0.75, 1.35, 2.0, 2.55]):
        n = int(SR * 0.35)
        t = np.arange(n) / SR
        thud = np.sin(2 * np.pi * (70 - 30 * t) * t) * S.env(n, 0.004, 0.14, 4)
        thud += S.lp(rng.standard_normal(n), 500) * S.env(n, 0.002, 0.05, 6) * 0.6
        place(out, thud * (0.7 + 0.3 * (k % 2)), at)
    cn = int(SR * 0.5)
    t = np.arange(cn) / SR
    f = 300 + 120 * np.sin(2 * np.pi * 3 * t)
    creak = S.bp(np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)), 250, 1800) * np.sin(np.pi * t / 0.5) * 0.25
    place(out, creak, 1.55)
    return S.norm(S.lp(room(out, mix=0.5), 2500), 0.8)


def creak():
    """Скрип половицы рядом: медленная частотная модуляция трения."""
    sec = 1.3
    t = S.t_of(sec)
    f = 180 + 70 * np.sin(2 * np.pi * 0.9 * t) + 25 * np.sin(2 * np.pi * 13 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    stick = (np.sin(ph) > 0.6).astype(float) - 0.3
    x = S.bp(stick, 200, 2400) * np.sin(np.pi * t / sec) ** 0.8
    return S.norm(room(x, mix=0.25), 0.6)


def cry_far():
    """Далёкий крик в лесу: голос, срезанный расстоянием, с отражениями."""
    sec = 2.2
    t = S.t_of(sec)
    pitch = 420 * (1 + 0.25 * np.sin(np.pi * t / sec)) * (1 + 0.03 * np.sin(2 * np.pi * 6 * t))
    ph = 2 * np.pi * np.cumsum(pitch) / SR
    voice = sum(np.sin(ph * h) / h ** 0.9 for h in range(1, 10))
    voice = S.bp(voice, 500, 2600) + 0.2 * S.bp(rng.standard_normal(len(t)), 800, 3000)
    voice *= np.minimum(1, t / 0.08) * np.exp(-np.maximum(0, t - 0.9) * 2.4)
    return S.norm(far(voice, 1600), 0.5)


def growl():
    """Рык упыря: низкий модулированный шум и подголосок."""
    sec = 1.8
    t = S.t_of(sec)
    base = 70 + 15 * np.sin(2 * np.pi * 0.7 * t)
    ph = 2 * np.pi * np.cumsum(base) / SR
    tone = np.sign(np.sin(ph)) * 0.4 + np.sin(ph * 2) * 0.3
    rough = S.lp(rng.standard_normal(len(t)), 900) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t))
    x = S.lp(tone, 700) + rough * 0.8
    x *= np.minimum(1, t / 0.25) * np.minimum(1, (sec - t) / 0.4)
    return S.norm(room(x, mix=0.3), 0.85)


def gasp():
    """Захлёбывающееся дыхание: рваные вдохи, всё короче."""
    sec = 2.4
    out = np.zeros(int(SR * sec))
    at = 0.05
    dur = 0.38
    while at < sec - 0.2:
        n = int(SR * dur)
        t = np.arange(n) / SR
        x = S.bp(rng.standard_normal(n), 700, 3200) + 0.4 * S.bp(rng.standard_normal(n), 200, 600)
        x *= np.sin(np.pi * t / dur) ** 0.6 * (1 + 0.6 * (rng.random(n) < 0.02))
        place(out, x, at)
        at += dur + 0.12
        dur *= 0.8
    return S.norm(room(out, mix=0.15), 0.6)


def call_far():
    """Зов из леса: два протяжных слога, как имя, издалека."""
    sec = 2.8
    out = np.zeros(int(SR * sec))
    for at, dur, f0, glide in [(0.1, 0.55, 330, 1.05), (0.75, 0.95, 300, 0.82)]:
        n = int(SR * dur)
        t = np.arange(n) / SR
        pitch = f0 * (1 + (glide - 1) * t / dur) * (1 + 0.02 * np.sin(2 * np.pi * 5 * t))
        ph = 2 * np.pi * np.cumsum(pitch) / SR
        v = sum(np.sin(ph * h) * np.exp(-((f0 * h - 800) / 600) ** 2) for h in range(1, 12))
        v *= np.minimum(1, t / 0.06) * np.minimum(1, (dur - t) / 0.25)
        place(out, v, at)
    return S.norm(far(out, 1300), 0.45)


def scare():
    """Резкий удар: шумовой всплеск, низкий удар и визг струны вниз. Не чаще раза за ночь."""
    sec = 1.6
    n = int(SR * sec)
    t = np.arange(n) / SR
    hit = np.sin(2 * np.pi * (48 - 20 * t) * t) * S.env(n, 0.002, 0.5, 3)
    burst = S.bp(rng.standard_normal(n), 900, 7000) * S.env(n, 0.001, 0.12, 5)
    f = 1800 * np.exp(-t * 1.6) + 300
    screech = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * S.env(n, 0.005, 0.7, 2.5) * 0.3
    return S.norm(hit + burst * 0.8 + S.bp(screech, 300, 5000), 0.95)


def weep():
    """Плач у двери: всхлипы высоким голосом. Подражатель так зовёт к себе."""
    sec = 2.6
    out = np.zeros(int(SR * sec))
    at = 0.05
    while at < sec - 0.3:
        dur = rng.uniform(0.25, 0.45)
        n = int(SR * dur)
        t = np.arange(n) / SR
        pitch = rng.uniform(520, 620) * (1 - 0.18 * t / dur) * (1 + 0.04 * np.sin(2 * np.pi * 9 * t))
        ph = 2 * np.pi * np.cumsum(pitch) / SR
        v = sum(np.sin(ph * h) / h for h in range(1, 7))
        v = S.bp(v, 400, 3000) + 0.25 * S.bp(rng.standard_normal(n), 1500, 4000)
        v *= np.sin(np.pi * t / dur) ** 1.2
        place(out, v, at)
        at += dur + rng.uniform(0.1, 0.3)
    return S.norm(room(S.lp(out, 3000), mix=0.35), 0.5)


JOBS = {
    'scratch': scratch, 'whisper': whisper, 'roof_steps': roof_steps, 'creak': creak, 'cry_far': cry_far,
    'growl': growl, 'gasp': gasp, 'call_far': call_far, 'scare': scare, 'weep': weep,
}


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sfx = os.path.join(root, 'assets', 'sfx')
    total = 0
    for name, fn in JOBS.items():
        path = os.path.join(sfx, name + '.ogg')
        S.save(path, fn(), q=2)
        total += os.path.getsize(path)
    print('звуков страха: %d, %.0f КБ' % (len(JOBS), total / 1024))


if __name__ == '__main__':
    main()
