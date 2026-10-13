"""Синтез звуковых эффектов и музыки «Пустите».
Запуск из папки game: python3 tools/make_sfx.py .  → assets/sfx/*.ogg и assets/music/*.ogg
Меню и ночь генерируются как 60-секундные цикличные OGG 44,1 кГц.
Записанные звуковые эффекты остаются без изменений.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
try:
    from scipy import signal
except ImportError:
    signal = None

SR = 32000
MUSIC_SR = 44100
MUSIC_SECONDS = 60
## Эти звуки с v0.24.0 — записи, а не формулы: скрипт их не трогает.
RECORDED = {'knock', 'door_open', 'door_shut', 'bell', 'amb_night'}
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


def save_music(path, x, q=3):
    """Стерео музыка 44,1 кГц, OGG Vorbis. q=3 оставляет запас в общем лимите 3 МиБ."""
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        tmp = f.name
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(MUSIC_SR)
        w.writeframes(pcm.tobytes())
    ffmpeg = os.environ.get('FFMPEG_BIN', 'ffmpeg')
    subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-i', tmp,
                    '-c:a', 'libvorbis', '-q:a', str(q), path], check=True)
    os.remove(tmp)


def _music_freq(midi: int, detune_cents: float = 0.0) -> float:
    """Округляет ноту к целому числу колебаний за минуту, чтобы цикл замыкался."""
    hz = 440.0 * (2.0 ** ((midi - 69) / 12.0)) * (2.0 ** (detune_cents / 1200.0))
    return round(hz * MUSIC_SECONDS) / MUSIC_SECONDS


def _add_music_voice(out, t, midi: int, envelope, gain: float, pan: float, phase: float) -> None:
    """Мягкий аддитивный голос с лёгкой расстройкой и медленной цикличной модуляцией."""
    pan = float(np.clip(pan, -0.85, 0.85))
    left_gain = np.sqrt((1.0 - pan) * 0.5)
    right_gain = np.sqrt((1.0 + pan) * 0.5)
    breath = np.sin(2.0 * np.pi * 6.0 * t / MUSIC_SECONDS + phase * 0.37)
    for channel, detune, channel_phase, channel_gain in (
        (0, -3.0, phase, left_gain),
        (1, 3.0, phase + 0.13, right_gain),
    ):
        hz = _music_freq(midi, detune)
        theta = 2.0 * np.pi * hz * t + channel_phase + 0.025 * breath
        tone = (0.76 * np.sin(theta)
                + 0.19 * np.sin(2.0 * theta + 0.23)
                + 0.05 * np.sin(3.0 * theta + 0.51))
        out[:, channel] += (tone * envelope * gain * channel_gain).astype(np.float32)


def _note_envelope(t, start: float, attack: float = 1.5, release: float = 7.0):
    """Цикличная медленная огибающая одиночной ноты; хвост проходит через конец файла."""
    elapsed = np.mod(t - start, MUSIC_SECONDS)
    rise = 0.5 - 0.5 * np.cos(np.pi * np.minimum(elapsed / attack, 1.0))
    fall = 0.5 + 0.5 * np.cos(np.pi * np.clip((elapsed - attack) / release, 0.0, 1.0))
    envelope = np.where(elapsed < attack, rise,
                        np.where(elapsed < attack + release, fall, 0.0))
    return envelope.astype(np.float32)


def _compose_music(kind: str):
    """Минорная минутная петля. Конец содержит точную копию первых двух секунд."""
    count = MUSIC_SR * MUSIC_SECONDS
    t = np.arange(count, dtype=np.float32) / MUSIC_SR
    if kind == 'menu':
        chords = [
            [45, 52, 57, 59],  # Am(add9)
            [41, 48, 52, 57],  # Fmaj7
            [38, 45, 48, 52],  # Dm(add9)
            [40, 47, 50, 55],  # Em7
        ]
        high_notes = [(11.0, 76), (35.0, 74), (52.0, 71)]
        pad_gain = 0.075
        bass_gain = 0.095
        high_gain = 0.024
    elif kind == 'night':
        chords = [
            [38, 45, 48, 50],  # Dm(add9)
            [34, 41, 45, 50],  # Bbmaj7
            [31, 38, 41, 45],  # Gm7
            [33, 40, 43, 50],  # Asus4
        ]
        high_notes = [(16.0, 74), (39.0, 72), (54.0, 69)]
        pad_gain = 0.065
        bass_gain = 0.11
        high_gain = 0.014
    else:
        raise ValueError('неизвестная музыка: %s' % kind)

    out = np.zeros((count, 2), dtype=np.float32)
    bar = MUSIC_SECONDS / len(chords)
    fade = 2.8
    slot = np.floor(t / bar).astype(np.int8)
    in_bar = np.mod(t, bar)
    progress = np.clip(in_bar / fade, 0.0, 1.0)
    fade_in = (0.5 - 0.5 * np.cos(np.pi * progress)).astype(np.float32)
    for chord_index, chord in enumerate(chords):
        # Переход держит предыдущий аккорд первые секунды новой части.
        current = np.where(slot == chord_index, fade_in, 0.0).astype(np.float32)
        next_index = (chord_index + 1) % len(chords)
        previous = np.where(slot == next_index, 1.0 - fade_in, 0.0).astype(np.float32)
        weight = current + previous
        _add_music_voice(out, t, chord[0] - 12, weight, bass_gain, 0.0, chord_index * 0.21)
        for note_index, midi in enumerate(chord):
            pan = (note_index - 1.5) * 0.19
            _add_music_voice(out, t, midi, weight, pad_gain, pan,
                             chord_index * 0.31 + note_index * 0.47)

    for note_index, (start, midi) in enumerate(high_notes):
        _add_music_voice(out, t, midi, _note_envelope(t, start), high_gain,
                         (-0.25 if note_index % 2 == 0 else 0.25), note_index * 0.8)

    # Небольшой стерео хвост сглаживает пэды и остаётся цикличным.
    dry = out.copy()
    delay_left = int(0.37 * MUSIC_SR)
    delay_right = int(0.53 * MUSIC_SR)
    out[:, 0] += np.roll(dry[:, 1], delay_left) * 0.12
    out[:, 1] += np.roll(dry[:, 0], delay_right) * 0.12
    peak = float(np.max(np.abs(out)))
    if peak > 0.0:
        out *= min(1.0, 0.28 / peak)

    # На стыке используется та же форма волны: 2-секундный кроссфейд даёт ровно 60 с.
    overlap = 2 * MUSIC_SR
    raw = np.concatenate([out, out[:overlap]], axis=0)
    head = raw[:overlap]
    tail = raw[-overlap:]
    w = np.linspace(0.0, 1.0, overlap, dtype=np.float32)[:, None]
    start = tail * (1.0 - w) + head * w
    return np.concatenate([start, raw[overlap:-overlap]], axis=0)


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
    if '--music-only' in sys.argv[2:]:
        for name in ('menu', 'night'):
            save_music(os.path.join(mus, name + '.ogg'), _compose_music(name), q=3)
        print('созданы menu.ogg и night.ogg; дневной трек и звуки не менялись')
        return
    if signal is None:
        raise RuntimeError('для синтеза звуков установите scipy; меню/ночь можно создать с --music-only')
    jobs = {
        'knock': knock, 'door_open': door_open, 'door_shut': door_shut, 'tap': tap, 'blip': blip,
        'bell': bell, 'tick': tick, 'death': death, 'exile': exile, 'win': win, 'lose': lose,
        'reveal': reveal, 'dawn': dawn, 'heartbeat': heartbeat, 'amb_day': amb_day, 'amb_night': amb_night,
        'job_done': job_done, 'job_fail': job_fail,
    }
    for name, fn in jobs.items():
        if name in RECORDED:
            continue       # записанные звуки (стук, двери, колокол, ночной лес) — не перезаписываем
        save(os.path.join(sfx, name + '.ogg'), fn())
    music_jobs = {
        'day': ([CM, AM, [F, A, C], [196.0, 246.9, D]], 16.0, 0.35, 0.5, 3200, 100),
    }
    generated_music = 0
    for name, params in music_jobs.items():
        save(os.path.join(mus, name + '.ogg'), music(*params), q=3)
        generated_music += 1
    for name in ('menu', 'night'):
        save_music(os.path.join(mus, name + '.ogg'), _compose_music(name), q=3)
        generated_music += 1
    total = sum(os.path.getsize(os.path.join(d, f)) for d in (sfx, mus) for f in os.listdir(d) if f.endswith('.ogg'))
    print('звуков: %d, синтезированных музыкальных треков: %d, всего %.0f КБ' % (len(jobs), generated_music, total / 1024))


if __name__ == '__main__':
    main()
