#!/usr/bin/env python3
"""Музыка по главам (TASK-123): game/assets/music/day_<глава>.ogg и night_<глава>.ogg для a1c2 ... a4c3.

Первая глава (a1c1) играет прежние day.ogg и night.ogg. Остальным одиннадцати главам нужна своя музыка днём и ночью,
иначе игрок слышит одну и ту же дорожку час за часом. Всё считается кодом из тех же инструментов, что день и ночь
(tools/make_day_night_music.py) и темы комиксов (tools/make_comic_themes.py), внешних записей нет.

У каждого акта свой набор инструментов (место действия), у каждой главы своя тональность, лад, темп, оборот аккордов и мелодия:

  акт 1, посёлок   флейта, щипковые, тёплая подкладка; ночью смычки, фортепиано, ветер
  акт 2, мельница  вальс в три четверти, текучие арпеджио, капли колокольчика; ночью гул, вода, редкие щипки
  акт 3, монастырь орган и хор, медленно, колокола на концах фраз; ночью хоровой дрон и глубокий колокол
  акт 4, станция   фортепиано и холодные колокольчики, ровный ход «колёс», смычки; ночью металлический гул, часы, удары

Мелодия строится по правилам: два такта на фразу, сильные доли на звуках аккорда, ходы по ступеням, конец фразы на звуке аккорда,
первый круг оборота без мелодии (петля начинается тихо). Зерно у каждой главы своё, поэтому дорожки воспроизводятся одинаково.
Петли 60-90 секунд, громкость -16 LUFS, хвост реверберации сложен с началом (проверка tools/check_music.py).
Кодирование: 24 кГц, Vorbis q0, около 0,35 МБ на дорожку (бюджет APK в docs/budget.md).

Запуск из корня репозитория:
  python3 tools/make_stage_music.py                  все 22 дорожки
  python3 tools/make_stage_music.py day_a2c1 night_a3c2
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_day_night_music import (SR, apply_reverb, bandpass, bell, flute, fold_loop, highpass, lowpass, midi, n, pluck,  # noqa: E402
                                  put, swell, tvec, warm_pad, write_ogg)
from make_comic_themes import cello, choir, deep_bell, piano, strings_pad  # noqa: E402

SCALES = {
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "mixo": [0, 2, 4, 5, 7, 9, 10],
}
TAIL = 12.0           # запас за концом петли под хвост реверберации, сек


# ---------------------------------------------------------------- голоса

def organ(freq, dur):
    """Церковный орган: нечётные и несколько чётных гармоник, медленная атака, лёгкое дрожание."""
    t = tvec(dur)
    out = np.zeros_like(t)
    for k, a in ((1, 1.0), (2, 0.55), (3, 0.42), (4, 0.28), (6, 0.16), (8, 0.08)):
        out += a * np.sin(2 * np.pi * freq * k * t + 0.7 * k)
        out += 0.5 * a * np.sin(2 * np.pi * freq * k * 1.0025 * t)
    out *= 1.0 + 0.04 * np.sin(2 * np.pi * 5.1 * t)
    return lowpass(out, 1800, 1) * swell(dur, 0.35, 0.6) / 2.2


def clack(rng, dur=0.07):
    """Стук колеса: короткий шум со срезом по верху и низу."""
    t = tvec(dur)
    return bandpass(rng.standard_normal(len(t)), 1200, 3800, 1) * np.exp(-t / 0.012)


def thud(strength=1.0, rng=None):
    t = tvec(2.4)
    f = 46.0 + 60.0 * np.exp(-t / 0.08)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.5)
    sig = body
    if rng is not None:
        sig = sig + 0.4 * lowpass(rng.standard_normal(len(t)), 400, 1) * np.exp(-t / 0.05)
    return sig * strength


def drone(root_hz, dur, rng, dark=0.5, seed_ph=0.0):
    """Низкий гул: тоника и квинта, пила с медленно ходящим срезом (раз в 20-30 секунд туда-обратно)."""
    t = tvec(dur)
    sig = np.zeros_like(t)
    for f, a in ((root_hz, 1.0), (root_hz * 1.5, 0.45), (root_hz * 2.0, 0.35)):
        for d in (-0.004, 0.0, 0.004):
            for k in range(1, 10):
                sig += a * (0.76 ** (k - 1)) / k * np.sin(2 * np.pi * f * (1 + d) * k * t + 1.7 * k + seed_ph)
    cyc = 0.5 + 0.5 * np.sin(2 * np.pi * t / (dur / 3.0) + seed_ph)
    return lowpass(sig, 300, 2) * (1.0 - cyc) + lowpass(sig, 700 + 900 * dark, 1) * cyc


def noise_bed(kind, dur, rng):
    """Шумовая постель: ветер (низкий шорох с порывами) или вода (светлее, быстрее ходит)."""
    t = tvec(dur)
    src = rng.standard_normal(len(t))
    if kind == "wind":
        sig = bandpass(src, 180, 900, 1)
        gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / (dur / 4.0) + 1.0) ** 2
    else:
        sig = bandpass(src, 600, 3200, 1)
        gust = 0.6 + 0.4 * np.sin(2 * np.pi * t / (dur / 7.0)) * np.sin(2 * np.pi * t / (dur / 3.0) + 2.0)
    return sig * gust


# ---------------------------------------------------------------- ступени, аккорды, фразы

def pitch(root, scale, d):
    """Номер MIDI ступени d (может быть отрицательной или больше 6) от тоники root в ладу scale."""
    return root + scale[d % 7] + 12 * (d // 7)


def hz(root, scale, d):
    return midi(pitch(root, scale, d))


def tones(root, scale, d, seventh=False):
    ds = [d, d + 2, d + 4] + ([d + 6] if seventh else [])
    return [hz(root, scale, x) for x in ds]


def snap(deg, chord_d):
    """Ближайшая к deg ступень, звучащая в аккорде chord_d."""
    ok = {chord_d % 7, (chord_d + 2) % 7, (chord_d + 4) % 7}
    best = deg
    for c in sorted(range(deg - 3, deg + 4), key=lambda x: (abs(x - deg), x)):
        if c % 7 in ok:
            best = c
            break
    return best


RHYTHM4 = [[2, 1, 1, 2, 2], [3, 1, 2, 2], [1, 1, 2, 4], [2, 2, 4], [4, 2, 2], [2, 1, 1, 4], [1, 1, 1, 1, 2, 2]]   # 8 долей
RHYTHM3 = [[3, 1, 2], [2, 1, 3], [1, 1, 1, 3], [3, 3], [2, 2, 2]]                                                    # 6 долей


def make_phrase(rng, bpb, chords, lo, hi, start, end):
    """Фраза на два такта: [(доля от начала, длина в долях, ступень)]. chords: ступень аккорда на каждый из двух тактов."""
    rhy = list((RHYTHM4 if bpb == 4 else RHYTHM3)[int(rng.integers(0, len(RHYTHM4 if bpb == 4 else RHYTHM3)))])
    out = []
    pos = 0.0
    cur = snap(start, chords[0])
    for i, d in enumerate(rhy):
        bar = min(1, int(pos // bpb))
        if i == 0:
            deg = cur
        elif i == len(rhy) - 1:
            deg = snap(end, chords[1])
        else:
            deg = cur + int(rng.choice([-2, -1, -1, 0, 1, 1, 2]))
            if pos % bpb == 0:
                deg = snap(deg, chords[bar])
        deg = int(np.clip(deg, lo, hi))
        out.append((pos, float(d), deg))
        cur = deg
        pos += d
    return out


# ---------------------------------------------------------------- дорожки главы

# act: акт; root: тоника (нота); scale: лад; bpm; bpb: долей в такте; prog: ступени аккордов на четыре такта;
# dark: 0..1, насколько мрачнее ночь; seed
CHAPTERS = {
    "a1c2": dict(act=1, root="E3", scale="dorian", bpm=76, bpb=4, prog=[0, 3, 0, 4], dark=0.25, seed=1201),
    "a1c3": dict(act=1, root="A2", scale="minor", bpm=68, bpb=4, prog=[0, 5, 2, 6], dark=0.40, seed=1301),
    "a2c1": dict(act=2, root="D3", scale="dorian", bpm=96, bpb=3, prog=[0, 3, 6, 0], dark=0.30, seed=2101),
    "a2c2": dict(act=2, root="G2", scale="minor", bpm=88, bpb=3, prog=[0, 5, 3, 4], dark=0.45, seed=2201),
    "a2c3": dict(act=2, root="C#3", scale="minor", bpm=80, bpb=3, prog=[0, 6, 5, 4], dark=0.60, seed=2301),
    "a3c1": dict(act=3, root="D3", scale="phrygian", bpm=54, bpb=4, prog=[0, 1, 0, 6], dark=0.40, seed=3101),
    "a3c2": dict(act=3, root="F#2", scale="minor", bpm=50, bpb=4, prog=[0, 6, 5, 6], dark=0.55, seed=3201),
    "a3c3": dict(act=3, root="B2", scale="phrygian", bpm=48, bpb=4, prog=[0, 1, 6, 0], dark=0.70, seed=3301),
    "a4c1": dict(act=4, root="A2", scale="phrygian", bpm=90, bpb=4, prog=[0, 0, 5, 6], dark=0.55, seed=4101),
    "a4c2": dict(act=4, root="E3", scale="minor", bpm=96, bpb=4, prog=[0, 2, 5, 4], dark=0.70, seed=4201),
    "a4c3": dict(act=4, root="C3", scale="minor", bpm=100, bpb=4, prog=[0, 1, 0, 6], dark=0.85, seed=4301),
}


def timing(p, target=68.0):
    """Длина петли: целое число четырёхтактовых кругов, 60-86 секунд."""
    beat = 60.0 / p["bpm"]
    bar = p["bpb"] * beat
    cycles = max(4, int(round(target / (4 * bar))))
    while cycles * 4 * bar > 86.0:
        cycles -= 1
    while cycles * 4 * bar < 61.0:
        cycles += 1
    return beat, bar, cycles * 4, cycles


def lead_voice(act, freq, dur, rng):
    if act == 1:
        return flute(freq, dur, rng=rng, vib_depth=0.005)
    if act == 2:
        return flute(freq * 2.0, dur, rng=rng, vib_depth=0.004, soft=0.6)
    if act == 3:
        return choir(freq, dur, rng, "a") * 1.6
    return piano(freq, max(dur, 2.4), 0.5)


def put_loop(buf, sig, length, gain, pan=0.0, xf=4.0):
    """Сплошной слой в петлю: последние xf секунд (сигнал за концом петли) плавно переходят в начало, равной мощности."""
    k = int(xf * SR)
    head = sig[:length].copy()
    tail = sig[length:length + k]
    w = np.linspace(0.0, 1.0, len(tail))
    head[:len(tail)] = head[:len(tail)] * np.sqrt(w) + tail * np.sqrt(1.0 - w)
    put(buf, 0.0, head, gain, pan)


def make_day(key):
    p = CHAPTERS[key]
    rng = np.random.default_rng(p["seed"])
    act = p["act"]
    root = n(p["root"])
    scale = SCALES[p["scale"]]
    bpb = p["bpb"]
    beat, bar, bars, cycles = timing(p)
    length = int(bars * bar * SR)
    length_s = length / SR
    dry = np.zeros((length + int(TAIL * SR), 2))

    def at(x):
        return x if x >= 0.0 else x + length_s

    prog = p["prog"]
    lo, hi = {1: (7, 13), 2: (7, 13), 3: (0, 6), 4: (7, 13)}[act]
    # две фразы круга и вариант конца для следующих кругов
    ph1 = make_phrase(rng, bpb, [prog[0], prog[1]], lo, hi, hi - 2, hi - 3)
    ph2 = make_phrase(rng, bpb, [prog[2], prog[3]], lo, hi, hi - 3, lo + 2)
    ph2b = make_phrase(rng, bpb, [prog[2], prog[3]], lo, hi, hi - 1, lo + 4)

    for b in range(bars):
        t0 = b * bar
        d = prog[b % 4]
        cyc = b // 4
        ch = tones(root, scale, d, seventh=(act == 4 and b % 4 == 3))
        low = [f / 2.0 for f in ch]
        # подкладка
        if act == 3:
            for f in low:
                put(dry, at(t0 - 0.5), organ(f, bar + 1.4), 0.10, 0.0)
            put(dry, at(t0 - 0.5), strings_pad(ch, bar + 1.4, 1.2, 1.2), 0.07, 0.0)
        elif act == 4:
            put(dry, at(t0 - 0.4), strings_pad(low + [ch[0]], bar + 1.0, 0.9, 1.0), 0.14, 0.0)
        else:
            put(dry, at(t0 - 0.3), warm_pad(low + [ch[2]], bar + 0.8, 0.5) * swell(bar + 0.8, 0.9, 0.9), 0.15, 0.0)
        # бас
        bass_f = ch[0] / 2.0
        if act == 3:
            put(dry, t0, organ(bass_f / 2.0, bar * 0.98), 0.08, -0.1)
        elif act == 4:
            for i in range(int(bpb * 2)):
                put(dry, t0 + i * beat / 2.0, pluck(bass_f, 0.5, 0.4), 0.20 if i % 2 == 0 else 0.11, -0.1)
        else:
            put(dry, t0, pluck(bass_f, 2.0, 0.5), 0.34, -0.1)
            if bpb == 4:
                put(dry, t0 + 2 * beat, pluck(ch[2] / 2.0, 1.6, 0.5), 0.2, -0.1)
        # арпеджио или ход
        if act == 1:
            pat = [0, 1, 2, 1] * 2
            for i, k in enumerate(pat):
                put(dry, t0 + i * beat / 2.0, pluck(ch[k], 1.5, 0.5), 0.13 + 0.03 * (i % 2 == 0), -0.3 + 0.3 * k)
        elif act == 2:
            pat = [0, 1, 2, 1, 2, 1]
            step = bar / len(pat)
            for i, k in enumerate(pat):
                put(dry, t0 + i * step, pluck(ch[k] * 2.0, 1.2, 0.45), 0.12 + 0.03 * (i % 3 == 0), -0.4 + 0.4 * k)
            if rng.random() < 0.45:
                dn = hz(root, scale, int(rng.integers(14, 19)))
                put(dry, t0 + float(rng.uniform(0.2, 0.9)) * bar, bell(dn, 2.2), 0.05, float(rng.uniform(-0.6, 0.6)))
        elif act == 4:
            hits = [0, 1.5, 2, 3.5] if bpb == 4 else [0, 1.5]
            for h in hits:
                put(dry, t0 + h * beat, clack(rng), 0.10 if h in (0, 2) else 0.06, float(rng.uniform(-0.4, 0.4)))
            for i in range(bpb * 2):
                put(dry, t0 + i * beat / 2.0 + 0.25 * beat, clack(rng, 0.04), 0.03, float(rng.uniform(-0.6, 0.6)))
            for i in (0, 2):
                put(dry, t0 + i * beat, pluck(ch[i // 2 * 2 % 3] * 2.0, 1.0, 0.35), 0.10, 0.3)
        # колокол на конце круга (монастырь) и холодный колокольчик (станция)
        if act == 3 and b % 4 == 3:
            put(dry, t0 + bar - 1.2, deep_bell(hz(root, scale, 0) / 2.0, 9.0), 0.11, float(rng.uniform(-0.3, 0.3)))
        if act == 4 and b % 4 == 3:
            put(dry, t0 + bar * 0.6, bell(hz(root, scale, 14), 3.0), 0.06, 0.4)

    # мелодия: первый круг тихий, дальше три круга из четырёх
    for cyc in range(1, cycles):
        for half, ph in ((0, ph1), (1, ph2 if cyc % 2 else ph2b)):
            base = (cyc * 4 + half * 2) * bar
            for pos, dur, deg in ph:
                f = hz(root, scale, deg + (7 if (cyc % 4 == 3 and act in (1, 2)) else 0))
                dsec = dur * beat * 0.96 + (0.5 if act == 3 else 0.15)
                gain = {1: 0.40, 2: 0.30, 3: 0.20, 4: 0.34}[act]
                put(dry, base + pos * beat, lead_voice(act, f, dsec, rng), gain, 0.12)
                if act in (1, 2) and dur >= 2 and cyc >= 2:
                    put(dry, base + pos * beat, bell(f * 2.0, 2.2), 0.06, 0.3)
    wet = apply_reverb(dry, {1: 0.36, 2: 0.42, 3: 0.60, 4: 0.46}[act], {1: 2.8, 2: 3.2, 3: 4.6, 4: 3.4}[act], rng,
                       damp={1: 4200.0, 2: 4000.0, 3: 2800.0, 4: 3400.0}[act])
    return fold_loop(wet, length)


def make_night(key):
    p = CHAPTERS[key]
    rng = np.random.default_rng(p["seed"] + 7)
    act = p["act"]
    dark = p["dark"]
    root = n(p["root"])
    scale = SCALES[p["scale"]]
    secs = float(np.clip(round(66.0 + 6.0 * (p["seed"] % 5) / 4.0), 62, 76))
    length = int(secs * SR)
    length_s = length / SR
    dry = np.zeros((length + int(TAIL * SR), 2))

    def at(x):
        return x if x >= 0.0 else x + length_s

    root_hz = midi(root) / 2.0
    # 1. гул и шумовая постель: сплошные слои сводятся в петлю перекрёстным затуханием, а не хвостом
    put_loop(dry, drone(root_hz, length_s + 5.0, rng, dark, seed_ph=float(p["seed"] % 7)), length, 0.05 + 0.03 * dark)
    bed = {1: "wind", 2: "water", 3: None, 4: "wind"}[act]
    if bed:
        put_loop(dry, noise_bed(bed, length_s + 5.0, rng), length, {1: 0.05, 2: 0.07, 4: 0.035}[act])
    # 2. смена аккордов каждые 8-10 секунд (подкладка), последний аккорд заходит под начало
    changes = 7
    span = length_s / changes
    seq = [p["prog"][i % 4] for i in range(changes)]
    for i, d in enumerate(seq):
        ch = tones(root, scale, d, seventh=dark > 0.5)
        t0 = i * span
        dur = span + 3.0
        if act == 1:
            put(dry, at(t0 - 1.5), strings_pad([f / 2.0 for f in ch] + [ch[2]], dur, 2.4, 2.6), 0.16, 0.0)
        elif act == 2:
            put(dry, at(t0 - 1.5), warm_pad([f / 2.0 for f in ch], dur, 0.35) * swell(dur, 2.2, 2.4), 0.14, 0.0)
        elif act == 3:
            put(dry, at(t0 - 1.5), choir(ch[0] / 2.0, dur, rng, "o"), 0.20, -0.2)
            put(dry, at(t0 - 1.5), choir(ch[1], dur, rng, "o"), 0.14, 0.2)
            put(dry, at(t0 - 1.5), choir(ch[2], dur, rng, "a"), 0.10, 0.0)
        else:
            put(dry, at(t0 - 1.5), strings_pad([f / 2.0 for f in ch[:2]] + [ch[1]], dur, 2.0, 2.2, bright=0.45), 0.13, 0.0)
    # 3. редкие ноты: тип по акту, ступени из звуков аккорда, интервалы неровные
    t = float(rng.uniform(2.0, 5.0))
    last = 0
    while t < length_s - 6.0:
        i = min(changes - 1, int(t / span))
        d = seq[i]
        deg = snap(int(rng.integers(7, 13)), d)
        f = hz(root, scale, deg)
        pan = float(rng.uniform(-0.5, 0.5))
        if act == 1:
            put(dry, t, cello(f / 2.0, 3.4, rng=rng), 0.14, pan) if last % 2 == 0 else put(dry, t, piano(f, 3.4, 0.5), 0.12, pan)
        elif act == 2:
            put(dry, t, pluck(f, 2.6, 0.5), 0.20, pan)
        elif act == 3:
            put(dry, t, bell(f, 4.0), 0.06, pan)
        else:
            put(dry, t, piano(f, 3.4, 0.45), 0.13, pan)
        last += 1
        t += float(rng.uniform(4.5, 8.5)) * (1.25 - 0.5 * dark)
    # 4. то, что отличает акт
    if act == 3:
        for k in range(3):
            bt = (k * 0.31 + 0.12) * length_s
            put(dry, bt, deep_bell(root_hz * (1.0 if k != 1 else 0.75), 10.0), 0.17, float(rng.uniform(-0.3, 0.3)))
    if act == 4:
        tick = highpass(rng.standard_normal(int(0.09 * SR)), 2400, 1) * np.exp(-tvec(0.09) / 0.008)
        tt = 1.5
        period = 1.25 - 0.25 * dark
        while tt < length_s - 1.0:
            put(dry, tt, tick, 0.05, float(rng.uniform(-0.4, 0.4)))
            tt += period
        for k in range(2 + int(3 * dark)):
            put(dry, float(rng.uniform(6.0, length_s - 8.0)), thud(float(rng.uniform(0.6, 1.0)), rng), 0.22, float(rng.uniform(-0.2, 0.2)))
    if act == 2:
        for k in range(3 + int(3 * dark)):
            put(dry, float(rng.uniform(4.0, length_s - 6.0)), thud(0.5, rng), 0.12 + 0.1 * dark, float(rng.uniform(-0.3, 0.3)))
    if act == 1 and dark > 0.3:
        for k in range(1 + int(3 * dark)):
            put(dry, float(rng.uniform(8.0, length_s - 8.0)), thud(0.5, rng), 0.10, float(rng.uniform(-0.3, 0.3)))
    wet = apply_reverb(dry, {1: 0.5, 2: 0.55, 3: 0.65, 4: 0.5}[act], {1: 3.6, 2: 3.8, 3: 4.8, 4: 3.8}[act], rng,
                       damp={1: 3000.0, 2: 3200.0, 3: 2800.0, 4: 2800.0}[act])
    return fold_loop(wet, length)


def all_names():
    out = []
    for key in CHAPTERS:
        out += ["day_" + key, "night_" + key]
    return out


def make(name):
    kind, key = name.split("_", 1)
    return make_day(key) if kind == "day" else make_night(key)


def main():
    which = sys.argv[1:] or all_names()
    for name in which:
        write_ogg(make(name), name, ar=24000, q=0, seam=0.02)


if __name__ == "__main__":
    main()
