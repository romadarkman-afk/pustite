"""Синтез всех звуков «Пустите» из формул — без чужих записей и лицензий.
Запуск из папки game: python3 tools/make_sfx.py .  → assets/sfx/*.ogg и assets/music/*.ogg
Циклы (ambience, музыка, сердце) бесшовные: хвост сведён с началом.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 32000
rng = np.random.default_rng(7)


def t_of(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, a=0.005, d=0.2, curve=4.0):
    """Атака a сек, затухание экспонентой за d сек."""
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-4))
    return e * np.exp(-np.maximum(0.0, t - a) * curve / max(d, 1e-4))


def lp(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), 'low')
    return signal.lfilter(b, a, x)


def hp(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), 'high')
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], 'band')
    return signal.lfilter(b, a, x)


def norm(x, peak=0.89):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def loopify(x, fade=0.5):
    """Бесшовный цикл: последние fade сек сводятся с началом."""
    n = int(SR * fade)
    head, body, tail = x[:n], x[n:-n] if n else x, x[-n:]
    w = np.linspace(0, 1, n)
    start = head * w + tail * (1 - w)
    return np.concatenate([start, x[n:-n]])


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def save(path, x, q=3):
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        tmp = f.name
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', str(q), path], check=True)
    os.remove(tmp)


# ---------------------------------------------------------------- одиночные звуки
def knock():
    """Удар костяшками по деревянной двери: глухой удар + деревянный резонанс."""
    n = int(SR * 0.28)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * 95 * t) * env(n, 0.002, 0.08, 5)
    wood = sum(np.sin(2 * np.pi * f * t) * env(n, 0.001, d, 6) * g
               for f, d, g in [(210, 0.12, 0.7), (380, 0.07, 0.4), (720, 0.04, 0.25)])
    click = bp(noise(0.28), 1500, 4500) * env(n, 0.0005, 0.012, 8) * 0.6
    return norm(thump * 0.9 + wood + click, 0.95)


def door_open():
    """Скрип петель (частотная модуляция) и щелчок засова."""
    sec = 1.1
    t = t_of(sec)
    latch_n = int(SR * 0.08)
    latch = np.zeros_like(t)
    latch[:latch_n] = bp(noise(0.08), 2000, 6000) * env(latch_n, 0.0005, 0.02, 6)
    f = 520 + 180 * np.sin(2 * np.pi * 1.7 * t) + 90 * np.sin(2 * np.pi * 11 * t)
    phase = 2 * np.pi * np.cumsum(f) / SR
    creak = np.sign(np.sin(phase)) * 0.3 + np.sin(phase * 2) * 0.2
    creak = bp(creak, 400, 3000) * np.clip((t - 0.1) / 0.15, 0, 1) * np.exp(-np.maximum(0, t - 0.6) * 5)
    return norm(latch * 1.2 + creak * 0.6, 0.85)


def door_shut():
    """Дверь не открыли: глухой хлопок и лязг засова."""
    sec = 0.7
    n = int(SR * sec)
    t = np.arange(n) / SR
    thud = (np.sin(2 * np.pi * 60 * t) + 0.5 * np.sin(2 * np.pi * 120 * t)) * env(n, 0.003, 0.18, 5)
    slam = lp(noise(sec), 900) * env(n, 0.001, 0.08, 6)
    bolt = np.zeros(n)
    k = int(SR * 0.22)
    m = int(SR * 0.06)
    bolt[k:k + m] = bp(noise(0.06), 2500, 7000) * env(m, 0.0005, 0.02, 6)
    return norm(thud + slam * 0.7 + bolt * 0.8, 0.95)


def tap():
    """Мягкий щелчок интерфейса."""
    n = int(SR * 0.06)
    t = np.arange(n) / SR
    return norm(np.sin(2 * np.pi * (1200 - 6000 * t) * t) * env(n, 0.001, 0.03, 6), 0.6)


def blip():
    """Слог «голоса» жителя: короткий квадратный писк с формантой. Высота задаётся в игре."""
    sec = 0.075
    n = int(SR * sec)
    t = np.arange(n) / SR
    f = 440 * (1 + 0.08 * np.sin(2 * np.pi * 28 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = signal.square(ph, 0.35) * 0.5 + np.sin(ph) * 0.5
    x = lp(x, 2600) * env(n, 0.004, 0.06, 3.5)
    return norm(x, 0.55)


def bell():
    """Колокол посёлка на закате: неравномерные обертоны, долгое затухание."""
    sec = 3.5
    n = int(SR * sec)
    t = np.arange(n) / SR
    base = 196.0
    parts = [(0.5, 0.35, 2.6), (1.0, 1.0, 2.2), (1.19, 0.6, 1.8), (1.5, 0.45, 1.5), (2.0, 0.4, 1.2), (2.76, 0.25, 0.9), (4.07, 0.12, 0.6)]
    x = sum(g * np.sin(2 * np.pi * base * r * t) * env(n, 0.003, d, 3) for r, g, d in parts)
    x += bp(noise(sec), 1500, 5000) * env(n, 0.0005, 0.02, 6) * 0.3
    return norm(x, 0.8)


def tick():
    """Последние секунды: сухой тик."""
    n = int(SR * 0.05)
    t = np.arange(n) / SR
    return norm(bp(noise(0.05), 2500, 6000) * env(n, 0.0005, 0.01, 6) + np.sin(2 * np.pi * 1800 * t) * env(n, 0.0005, 0.02, 6) * 0.5, 0.5)


def death():
    """Утро, найден погибший: низкий диссонирующий удар и шлейф."""
    sec = 2.6
    n = int(SR * sec)
    t = np.arange(n) / SR
    x = sum(np.sin(2 * np.pi * f * t + 3 * np.sin(2 * np.pi * f * 0.5 * t) * np.exp(-t * 3)) * g for f, g in [(55, 1.0), (58.3, 0.8), (110, 0.4), (164.8, 0.3), (233, 0.25)])
    x *= env(n, 0.01, 1.6, 2.5)
    x += lp(noise(sec), 400) * env(n, 0.002, 0.25, 4) * 0.6
    return norm(x, 0.9)


def exile():
    """Изгнание: свист-уход в туман."""
    sec = 1.6
    n = int(SR * sec)
    t = np.arange(n) / SR
    sweep = bp(noise(sec), 300, 3000)
    sweep = lp(sweep * np.interp(t, [0, 0.5, 1.6], [0.2, 1.0, 0.0]), 1500)
    tone = np.sin(2 * np.pi * (330 - 160 * t) * t) * np.interp(t, [0, 0.3, 1.6], [0, 0.4, 0])
    return norm(sweep + tone, 0.8)


def chord_sting(notes, sec, bright=True):
    n = int(SR * sec)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for i, f in enumerate(notes):
        start = int(SR * 0.09 * i)
        m = n - start
        tt = np.arange(m) / SR
        v = (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2 * f * tt) + (0.15 * np.sin(2 * np.pi * 3 * f * tt) if bright else 0))
        x[start:] += v * env(m, 0.005, sec * 0.8, 2.2)
    return norm(lp(x, 5000), 0.8)


def win():
    return chord_sting([261.6, 329.6, 392.0, 523.3, 659.3], 2.4)


def lose():
    return chord_sting([440.0, 349.2, 293.7, 220.0, 174.6], 2.6, bright=False)


def reveal():
    """Пролог, раскрытие роли: мерцающий подъём."""
    sec = 1.8
    n = int(SR * sec)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for i, f in enumerate([523.3, 659.3, 784.0, 987.8, 1174.7, 1568.0]):
        s = int(SR * 0.12 * i)
        m = n - s
        tt = np.arange(m) / SR
        x[s:] += np.sin(2 * np.pi * f * tt) * env(m, 0.003, 0.9, 3) * 0.5
    pad = np.sin(2 * np.pi * 130.8 * t) * np.interp(t, [0, 0.8, 1.8], [0, 0.4, 0])
    return norm(x + pad, 0.7)


def dawn():
    """Утро: мягкий тёплый перезвон."""
    return chord_sting([392.0, 493.9, 587.3, 784.0], 2.0)


def job_done():
    """Дело сделано: два тёплых коротких колокольчика вверх."""
    sec = 0.7
    n = int(SR * sec)
    x = np.zeros(n)
    for i, f in enumerate([784.0, 1174.7]):
        s0 = int(SR * 0.09 * i)
        m = n - s0
        tt = np.arange(m) / SR
        x[s0:] += (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2.76 * f * tt)) * env(m, 0.002, 0.35, 4)
    return norm(x, 0.7)


def job_fail():
    """Впустую: глухой стук пустого ведра и короткий спад."""
    sec = 0.5
    n = int(SR * sec)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * (240 - 120 * t) * t) * env(n, 0.002, 0.18, 4)
    x += bp(noise(sec), 300, 1200) * env(n, 0.001, 0.05, 6) * 0.5
    return norm(x, 0.7)


# ---------------------------------------------------------------- циклы
def heartbeat():
    """Сердцебиение 70 уд/мин, цикл ровно на один удар."""
    sec = 60 / 70
    n = int(SR * sec)
    x = np.zeros(n)
    for start, g in [(0.0, 1.0), (0.22, 0.7)]:
        s = int(SR * start)
        m = int(SR * 0.25)
        tt = np.arange(m) / SR
        thump = np.sin(2 * np.pi * (60 - 25 * tt) * tt) * env(m, 0.004, 0.12, 4)
        x[s:s + m] += thump[:n - s] * g
    return norm(lp(x, 180), 0.95)


def wind(sec, strength):
    x = noise(sec)
    tt = np.arange(len(x)) / SR
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * tt * 2.0 / sec)       # ровно два порыва за цикл — без шва
    slow = lp(rng.standard_normal(len(x)), 0.6, 1)
    slow = slow / (np.max(np.abs(slow)) or 1)
    w = bp(x, 150, 900) * (0.6 + 0.4 * slow) * gust
    return w * strength


def amb_day():
    """День: лёгкий ветер и редкие птицы."""
    sec = 16.0
    t = t_of(sec)
    x = norm(wind(sec, 1.0), 0.25)
    for start in [1.2, 4.8, 5.3, 9.1, 12.6, 13.0]:
        s = int(SR * start)
        for k in range(rng.integers(2, 4)):
            m = int(SR * 0.09)
            tt = np.arange(m) / SR
            f0 = rng.uniform(2600, 3600)
            chirp = np.sin(2 * np.pi * (f0 + 2500 * tt * (1 if k % 2 else -1)) * tt) * env(m, 0.005, 0.07, 3)
            a = s + int(SR * 0.13 * k)
            x[a:a + m] += chirp * 0.12
    return loopify(norm(x, 0.5), 0.6)


def amb_night():
    """Ночь: низкий ветер и сверчки."""
    sec = 16.0
    x = norm(wind(sec, 1.0), 0.22)
    x = lp(x, 500)
    n = len(x)
    # сверчки: группы по 3 стрекота, несущая 4.6–5 кГц
    for c in range(2):
        carrier = 4600 + 400 * c
        period = 0.9 + 0.25 * c
        t0 = 0.3 * c
        while t0 < sec - 0.4:
            for k in range(3):
                s = int(SR * (t0 + k * 0.045))
                m = int(SR * 0.03)
                tt = np.arange(m) / SR
                x[s:s + m] += np.sin(2 * np.pi * carrier * tt) * np.sin(np.pi * tt / 0.03) * 0.06
            t0 += period + rng.uniform(-0.1, 0.1)
    # далёкий вой ветра в лесу
    t = t_of(sec)
    howl = np.sin(2 * np.pi * (180 + 30 * np.sin(2 * np.pi * t / sec)) * t) * np.interp(t, [0, 6, 9, 16], [0, 0, 0.05, 0])
    return loopify(norm(x + howl, 0.5), 0.6)


def music(prog, sec, pad_gain, arp_gain, lowpass, bpm):
    """Заглушка музыки: пэд по аккордам и тихое арпеджио. Файл можно заменить своим треком."""
    n = int(SR * sec)
    t = np.arange(n) / SR
    x = np.zeros(n)
    per = sec / len(prog)
    for i, chord in enumerate(prog):
        s = int(SR * per * i)
        m = int(SR * per)
        tt = np.arange(m) / SR
        e = np.minimum(1, tt / 0.6) * np.minimum(1, (per - tt) / 0.6)
        for f in chord:
            for det in (-0.004, 0.004):
                ph = 2 * np.pi * f * (1 + det) * tt
                x[s:s + m] += (signal.sawtooth(ph) * 0.15 + np.sin(ph) * 0.5) * e * pad_gain
        step = 60 / bpm / 2
        k = 0
        while k * step < per - 0.05:
            f = chord[k % len(chord)] * 2
            a = s + int(SR * k * step)
            mm = int(SR * 0.4)
            ttt = np.arange(mm) / SR
            seg = np.sin(2 * np.pi * f * ttt) * env(mm, 0.003, 0.35, 4) * arp_gain
            x[a:a + mm] += seg[:max(0, n - a)]
            k += 1
    return loopify(norm(lp(x, lowpass), 0.6), 0.5)


A, C, D, E, F, G = 220.0, 261.6, 293.7, 329.6, 349.2, 392.0
AM = [A, C, E]
CM = [C, E, G]


def main():
    game = sys.argv[1]
    sfx = os.path.join(game, 'assets', 'sfx')
    mus = os.path.join(game, 'assets', 'music')
    os.makedirs(sfx, exist_ok=True)
    os.makedirs(mus, exist_ok=True)
    jobs = {
        'knock': knock, 'door_open': door_open, 'door_shut': door_shut, 'tap': tap, 'blip': blip,
        'bell': bell, 'tick': tick, 'death': death, 'exile': exile, 'win': win, 'lose': lose,
        'reveal': reveal, 'dawn': dawn, 'heartbeat': heartbeat, 'amb_day': amb_day, 'amb_night': amb_night,
        'job_done': job_done, 'job_fail': job_fail,
    }
    for name, fn in jobs.items():
        save(os.path.join(sfx, name + '.ogg'), fn())
    save(os.path.join(mus, 'menu.ogg'), music([AM, [F, A, C], CM, [196.0, 246.9, D]], 16.0, 0.6, 0.35, 2200, 84), q=3)
    save(os.path.join(mus, 'day.ogg'), music([CM, AM, [F, A, C], [196.0, 246.9, D]], 16.0, 0.35, 0.5, 3200, 100), q=3)
    total = sum(os.path.getsize(os.path.join(d, f)) for d in (sfx, mus) for f in os.listdir(d) if f.endswith('.ogg'))
    print('звуков: %d, музыки: 2, всего %.0f КБ' % (len(jobs), total / 1024))


if __name__ == '__main__':
    main()
