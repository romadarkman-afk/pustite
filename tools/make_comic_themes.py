#!/usr/bin/env python3
"""Музыка комиксов (TASK-123): game/assets/music/theme_sad.ogg, theme_hope.ogg, theme_tense.ogg, theme_grief.ogg.

Те же инструменты и тот же вывод, что у дня и ночи (tools/make_day_night_music.py): всё считается кодом, внешних
записей нет, права на дорожки у проекта. Петли по 60-90 секунд, громкость -16 LUFS, хвост реверберации сложен с началом.

  theme_sad    скорбная: ре минор, 54 удара в минуту, смычковая подкладка, виолончельная линия, редкие ноты «пианино»
  theme_hope   светлая: соль мажор, 66 ударов, арпеджио, высокая флейта, колокольчики на концах фраз, подкладка растёт
  theme_tense  тревожная: низкий гул с ползущим фильтром, редкие удары, тонкий дрожащий кластер, шорох и нарастания
  theme_grief  траурная: хоровой дрон «а-а» (форманты), медленные минорные аккорды, далёкий колокол

Запуск из корня репозитория:  python3 tools/make_comic_themes.py [sad|hope|tense|grief]
Проверка:                     python3 tools/check_music.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
import make_day_night_music as M  # noqa: E402
from make_day_night_music import (SR, apply_reverb, bandpass, bell, flute, fold_loop, highpass, lowpass, midi, n, pluck,  # noqa: E402
                                  put, swell, tvec, warm_pad, write_ogg)


# ---------------------------------------------------------------- новые голоса

def cello(freq, dur, vib=4.6, vib_depth=0.0045, rng=None):
    """Смычковая нота: пила с мягким срезом, медленная атака, вибрато появляется не сразу."""
    t = tvec(dur)
    vib_env = np.clip((t - 0.35) / 0.8, 0.0, 1.0)
    phase = 2 * np.pi * np.cumsum(freq * (1.0 + vib_depth * vib_env * np.sin(2 * np.pi * vib * t))) / SR
    sig = np.zeros_like(t)
    for k in range(1, 12):
        sig += (0.72 ** (k - 1)) / k * np.sin(k * phase + 0.4 * k)
    sig = lowpass(sig, 2600, 1)
    if rng is not None:
        sig += 0.012 * bandpass(rng.standard_normal(len(t)), 900, 3200, 1)      # шорох смычка
    atk = np.minimum(1.0, t / 0.28)
    rel = np.minimum(1.0, np.maximum(0.0, (dur - t)) / 0.45)
    return sig * atk * rel


def piano(freq, dur=3.0, soft=0.5):
    """Глухая нота «пианино»: затухающие гармоники, короткий мягкий удар молоточка."""
    t = tvec(dur)
    out = np.zeros_like(t)
    for k in range(1, 9):
        f = freq * k * (1.0 + 0.0006 * k * k)
        if f > 6000:
            break
        out += (soft ** (k - 1)) / k * np.sin(2 * np.pi * f * t) * np.exp(-t / (1.9 / (1.0 + 0.7 * (k - 1))))
    return out * np.minimum(1.0, t / 0.006)


def strings_pad(freqs, dur, attack=1.4, release=1.6, bright=0.62):
    """Подкладка смычков: много расстроенных пил, срез по верху, медленный вдох и выдох."""
    t = tvec(dur)
    out = np.zeros_like(t)
    for f in freqs:
        for d in (-0.0035, -0.001, 0.001, 0.0035):
            ff = f * (1.0 + d)
            for k in range(1, 9):
                out += (bright ** (k - 1)) / k * np.sin(2 * np.pi * ff * k * t + 1.7 * k + 7 * d)
    out = lowpass(out, 2100, 1)
    return out / (len(freqs) * 3.0) * swell(dur, attack, release)


def choir(freq, dur, rng, vowel="a"):
    """Хоровой «а»: пила через три форманты, дыхание, вибрато с запозданием. Голоса разнесены по расстройке."""
    forms = {"a": ((750, 1.0), (1150, 0.55), (2600, 0.22)), "o": ((500, 1.0), (900, 0.5), (2500, 0.15))}[vowel]
    t = tvec(dur)
    vib_env = np.clip((t - 0.8) / 1.6, 0.0, 1.0)
    out = np.zeros_like(t)
    for d in (-0.006, 0.0, 0.007):
        phase = 2 * np.pi * np.cumsum(freq * (1.0 + d) * (1.0 + 0.004 * vib_env * np.sin(2 * np.pi * (4.6 + 8 * d) * t))) / SR
        src = np.zeros_like(t)
        for k in range(1, 28):
            src += (1.0 / k) * np.sin(k * phase + 0.9 * k)
        voice = np.zeros_like(t)
        for hz, amp in forms:
            voice += amp * bandpass(src, hz * 0.82, hz * 1.22, 1)
        out += voice
    out += 0.05 * bandpass(rng.standard_normal(len(t)), 1500, 4200, 1)
    return out / 3.0 * swell(dur, 1.8, 2.2)


def deep_bell(freq, dur=9.0):
    """Далёкий колокол: низкий, с долгим хвостом и биением двух близких частот."""
    t = tvec(dur)
    out = np.zeros_like(t)
    for ratio, amp, tau in ((0.5, 0.5, 4.5), (1.0, 1.0, 4.0), (1.19, 0.55, 3.0), (1.51, 0.4, 2.2), (2.0, 0.55, 2.4),
                            (2.51, 0.25, 1.4), (3.2, 0.15, 0.9), (4.2, 0.08, 0.5)):
        out += amp * np.sin(2 * np.pi * freq * ratio * t + ratio) * np.exp(-t / tau)
        out += 0.4 * amp * np.sin(2 * np.pi * freq * ratio * 1.0035 * t) * np.exp(-t / tau)
    return out * np.minimum(1.0, t / 0.004)


def chord(names):
    return [midi(n(x)) for x in names]


# ---------------------------------------------------------------- скорбная

def make_sad():
    rng = np.random.default_rng(54)
    bpm = 54.0
    beat = 60.0 / bpm
    bars = 16
    length = int(bars * 4 * beat * SR)
    buf = np.zeros((length + int(4.0 * SR), 2))
    dry = np.zeros_like(buf)
    mel = np.zeros_like(buf)

    # (название аккорда, бас, тоны подкладки)
    ch = {
        "Dm": ("D2", ["D3", "F3", "A3", "D4"]), "Bb": ("Bb1", ["Bb2", "D3", "F3", "Bb3"]),
        "F": ("F2", ["F3", "A3", "C4", "F4"]), "Gm": ("G2", ["G3", "Bb3", "D4", "G4"]),
        "A": ("A1", ["A2", "C#3", "E3", "A3"]), "C": ("C2", ["C3", "E3", "G3", "C4"]),
        "Dm/A": ("A1", ["A2", "D3", "F3", "A3"]), "A7": ("A1", ["A2", "C#3", "E3", "G3"]),
    }
    prog = ["Dm", "Dm", "Bb", "F", "Gm", "Dm", "A", "A",
            "Dm", "Bb", "F", "C", "Gm", "Dm/A", "A7", "Dm"]
    # линия виолончели: (нота, длина в долях), на такт четыре доли
    line = [
        [("A3", 4)],
        [("D4", 2), ("F4", 2)],
        [("D4", 4)],
        [("C4", 2), ("A3", 2)],
        [("Bb3", 3), ("A3", 1)],
        [("A3", 2), ("D4", 2)],
        [("E4", 3), ("C#4", 1)],
        [("E4", 4)],
        [("F4", 3), ("E4", 1)],
        [("D4", 2), ("Bb3", 2)],
        [("A3", 2), ("C4", 2)],
        [("E4", 3), ("D4", 1)],
        [("D4", 2), ("Bb3", 2)],
        [("A3", 2), ("F3", 2)],
        [("E4", 2), ("C#4", 2)],
        [("D4", 3), (None, 1)],
    ]
    for bar in range(bars):
        t0 = bar * 4 * beat
        root, tones = ch[prog[bar]]
        put(dry, max(0.0, t0 - 0.6), strings_pad(chord(tones), 4 * beat + 1.4, 1.6, 1.8), 0.20, 0.0)
        put(dry, t0, cello(midi(n(root)), 4 * beat * 0.98, rng=rng) * 0.9, 0.17, -0.1)
        pos = t0
        for name, d in line[bar]:
            if name is not None:
                f = midi(n(name))
                # верхний голос: виолончель, на втором проходе плюс октавой выше тише
                put(mel, pos, cello(f * 2.0, d * beat * 0.97 + 0.2, rng=rng), 0.12 if bar >= 8 else 0.09, 0.15)
                put(mel, pos, cello(f, d * beat * 0.97 + 0.2, rng=rng), 0.21, 0.1)
            pos += d * beat
        # редкие ноты «пианино»: на третьей доле каждого второго такта, на втором проходе чаще
        if bar % 2 == 1 or bar >= 8:
            top = tones[-1] if bar % 4 else tones[1]
            put(dry, t0 + 2 * beat + rng.uniform(-0.04, 0.04), piano(midi(n(top)) * 2.0, 3.4), 0.11 + 0.02 * (bar >= 8), 0.3)
    # последний такт каждой части: низкий удар по струне
    for bar in (7, 15):
        put(dry, bar * 4 * beat + 1.0, piano(midi(n("D2")), 5.0, 0.62), 0.20, -0.2)
    dry += mel
    wet = apply_reverb(dry, 0.5, 3.4, rng, damp=3000.0)
    return fold_loop(wet, length)


# ---------------------------------------------------------------- светлая

def make_hope():
    rng = np.random.default_rng(66)
    bpm = 66.0
    beat = 60.0 / bpm
    bars = 20
    length = int(bars * 4 * beat * SR)
    buf = np.zeros((length + int(3.5 * SR), 2))
    dry = np.zeros_like(buf)
    top = np.zeros_like(buf)

    ch = {
        "G": ("G2", ["B3", "D4", "G4"]), "D": ("D3", ["A3", "D4", "F#4"]), "Em": ("E2", ["G3", "B3", "E4"]),
        "C": ("C3", ["G3", "C4", "E4"]), "Am": ("A2", ["E3", "A3", "C4"]), "D7": ("D3", ["A3", "C4", "F#4"]),
        "Bm": ("B2", ["F#3", "B3", "D4"]),
    }
    prog = ["G", "D", "Em", "C", "G", "D", "C", "D",
            "G", "D", "Em", "C", "Am", "Bm", "C", "D7",
            "G", "D", "C", "G"]
    # мелодия флейты: восходящая, на втором проходе выше
    line = [
        [("D5", 2), ("G5", 2)],
        [("F#5", 3), ("A5", 1)],
        [("G5", 2), ("E5", 2)],
        [("E5", 2), ("G5", 2)],
        [("B5", 3), ("A5", 1)],
        [("A5", 2), ("F#5", 2)],
        [("G5", 2), ("E5", 2)],
        [("F#5", 3), (None, 1)],
        [("G5", 2), ("B5", 2)],
        [("A5", 3), ("F#5", 1)],
        [("G5", 2), ("E5", 2)],
        [("E5", 2), ("G5", 2)],
        [("A5", 2), ("C6", 2)],
        [("B5", 3), ("D6", 1)],
        [("C6", 2), ("G5", 2)],
        [("A5", 2), ("F#5", 2)],
        [("D6", 3), ("B5", 1)],
        [("A5", 2), ("F#5", 2)],
        [("G5", 2), ("E5", 2)],
        [("G5", 4)],
    ]
    for bar in range(bars):
        t0 = bar * 4 * beat
        root, tones = ch[prog[bar]]
        grow = 0.7 + 0.3 * min(1.0, bar / 10.0)                  # подкладка и арпеджио растут к середине
        put(dry, max(0.0, t0 - 0.3), warm_pad(chord(tones), 4 * beat + 0.8, 0.5) * swell(4 * beat + 0.8, 0.9, 0.9), 0.16 * grow, 0.0)
        put(dry, t0, pluck(midi(n(root)), 2.4, 0.5), 0.38, -0.1)
        # арпеджио: шесть щипков на такт, мягко
        idx = [0, 1, 2, 1, 2, 1]
        for i, k in enumerate(idx):
            put(dry, t0 + i * (4 * beat / 6.0), pluck(midi(n(tones[k])), 1.7, 0.5), 0.17 + 0.03 * (i % 2 == 0), -0.3 + 0.2 * k)
        pos = t0
        for name, d in line[bar]:
            if name is not None:
                f = midi(n(name))
                put(top, pos, flute(f, d * beat * 0.96 + 0.15, rng=rng, vib_depth=0.005), 0.42 if bar >= 4 else 0.0, 0.12)
                if bar >= 12 and d >= 2:
                    put(dry, pos, bell(f * 2.0, 2.4), 0.07, 0.3)
            pos += d * beat
        if bar % 4 == 3:
            put(dry, t0 + 3.0 * beat, bell(midi(n("G6")), 3.0), 0.07, -0.3)
            put(dry, t0 + 3.5 * beat, bell(midi(n("D6")), 3.0), 0.06, 0.3)
    dry += top
    wet = apply_reverb(dry, 0.36, 2.8, rng, damp=4200.0)
    return fold_loop(wet, length)


# ---------------------------------------------------------------- тревожная

def make_tense():
    rng = np.random.default_rng(1913)
    length_s = 70.0
    length = int(length_s * SR)
    buf = np.zeros((length + int(5.0 * SR), 2))
    dry = np.zeros_like(buf)
    T = tvec(length_s + 5.0)

    def cyc(k, phase=0.0):
        return 0.5 + 0.5 * np.sin(2 * np.pi * k * T / length_s + phase)

    # 1. гул: ре и ля в нижнем регистре, фильтр медленно ходит туда-сюда (два оборота за петлю)
    drone = np.zeros_like(T)
    for f, a in ((midi(n("D2")), 1.0), (midi(n("A2")), 0.55), (midi(n("D3")), 0.5)):
        for d in (-0.005, 0.0, 0.005):
            for k in range(1, 12):
                drone += a * (0.78 ** (k - 1)) / k * np.sin(2 * np.pi * f * (1 + d) * k * T + 1.9 * k)
    low = lowpass(drone, 380, 2)
    high = lowpass(drone, 2400, 1)
    mixf = cyc(2, -np.pi / 2)
    drone = low * (1.0 - mixf) + high * mixf
    put(dry, 0.0, drone, 0.06)

    # 2. тонкий кластер: ре, ми-бемоль, соль-диез, высоко, с дрожью (тремоло смычка)
    cluster = np.zeros_like(T)
    for name, k, ph in (("D5", 3, 0.0), ("Eb5", 4, 0.7), ("G#5", 2, 1.4), ("A4", 5, 2.1)):
        f = midi(n(name))
        for d in (-0.002, 0.003):
            sig = np.zeros_like(T)
            for h in range(1, 5):
                sig += (0.5 ** (h - 1)) * np.sin(2 * np.pi * f * (1 + d) * h * T + h * ph)
            cluster += sig * (0.05 + 0.95 * cyc(k, ph) ** 3)
    cluster = bandpass(cluster, 500, 5200, 1) * (1.0 + 0.6 * np.sin(2 * np.pi * 9.0 * T))
    put(dry, 0.0, cluster, 0.07, 0.0)

    # 3. удары: низкие, с задержкой между ними, неровно
    for when, strength in ((6.0, 0.9), (13.5, 0.7), (21.0, 1.0), (33.0, 0.8), (40.5, 1.0), (47.0, 0.7), (58.0, 1.0), (65.5, 0.8)):
        t = tvec(3.4)
        f = 52.0 + 68.0 * np.exp(-t / 0.07)
        body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.6)
        thud = lowpass(rng.standard_normal(len(t)), 500, 1) * np.exp(-t / 0.05)
        put(dry, when, (0.8 * body + 0.5 * thud) * strength, 0.34, rng.uniform(-0.15, 0.15))

    # 4. нарастания: шум, фильтр ползёт вверх, и обрыв перед ударом
    for start, dur, hit in ((0.5, 5.5, 6.0), (15.0, 6.0, 21.0), (27.0, 6.0, 33.0), (51.0, 7.0, 58.0)):
        noise = rng.standard_normal(int(dur * SR))
        out = np.zeros_like(noise)
        seg = int(0.25 * SR)
        for i in range(0, len(noise), seg):
            p = i / len(noise)
            lo = 250.0 + 2600.0 * p ** 2
            out[i:i + seg] = bandpass(noise[i:i + seg], lo, lo * 1.8, 1)
        env = np.linspace(0.0, 1.0, len(noise)) ** 2.4
        put(dry, start, out * env, 0.20, rng.uniform(-0.4, 0.4))

    # 5. тихое тиканье часов: раз в 1,4 секунды, чуть плывёт
    t = tvec(0.09)
    tick = (highpass(rng.standard_normal(len(t)), 2400, 1) * np.exp(-t / 0.008))
    tt = 2.0
    while tt < length_s - 1.0:
        put(dry, tt, tick, 0.06 if int(tt) % 2 else 0.045, rng.uniform(-0.5, 0.5))
        tt += 1.4 + rng.uniform(-0.01, 0.01)

    wet = apply_reverb(dry, 0.5, 3.6, rng, damp=2600.0)
    return fold_loop(wet, length)


# ---------------------------------------------------------------- траурная

def make_grief():
    rng = np.random.default_rng(1721)
    bpm = 48.0
    beat = 60.0 / bpm
    bars = 16
    length = int(bars * 4 * beat * SR)
    buf = np.zeros((length + int(14.0 * SR), 2))      # хвост длиннее самой долгой ноты: ничего не обрезается
    dry = np.zeros_like(buf)
    length_s = length / SR

    def at(x):
        """Вступление первого аккорда начинается до нуля и лежит в конце петли: стык без провала громкости."""
        return x if x >= 0.0 else x + length_s

    ch = {
        "Am": ["A2", "E3", "A3", "C4"], "Em": ["E2", "B2", "E3", "G3"], "F": ["F2", "C3", "F3", "A3"],
        "E": ["E2", "B2", "E3", "G#3"], "Dm": ["D2", "A2", "D3", "F3"], "G": ["G2", "D3", "G3", "B3"],
        "C": ["C3", "G3", "C4", "E4"],
    }
    prog = ["Am", "Am", "F", "E", "Am", "Em", "F", "E",
            "Dm", "Am", "C", "G", "F", "Dm", "E", "Am"]
    # верхний голос хора: по ноте на два такта (восемь долей)
    voice = ["E4", "B3", "C4", "G#3", "F4", "G4", "C4", "B3"]
    for idx in range(0, bars, 2):
        t0 = idx * 4 * beat
        names = ch[prog[idx]]
        dur = 8 * beat + 2.2
        # нижние голоса: бас и тенор, «о»
        put(dry, at(t0 - 0.8), choir(midi(n(names[0])), dur, rng, "o"), 0.22, -0.25)
        put(dry, at(t0 - 0.8), choir(midi(n(names[1])), dur, rng, "o"), 0.16, 0.25)
        put(dry, at(t0 - 0.6), choir(midi(n(names[2])), dur, rng, "a"), 0.15, -0.1)
        put(dry, at(t0 - 0.5), choir(midi(n(voice[idx // 2])), dur, rng, "a"), 0.18, 0.1)
        # подкладка смычков тихо под хором
        put(dry, at(t0 - 0.8), strings_pad(chord(names), dur, 2.0, 2.2), 0.10, 0.0)
    # колокол: низкий, раз в четыре такта (не на первом такте, чтобы начало петли не било громче конца); один тихий высокий в паузе
    for bar, name, gain in ((2, "A2", 0.20), (6, "A2", 0.18), (10, "D3", 0.18), (14, "A2", 0.20)):
        put(dry, bar * 4 * beat + 0.2, deep_bell(midi(n(name)), 10.0), gain, rng.uniform(-0.3, 0.3))
    for bar, name in ((6, "E5"), (14, "A4")):
        put(dry, bar * 4 * beat + 2.0 * beat, bell(midi(n(name)), 4.0, -18.0), 0.06, 0.35)
    wet = apply_reverb(dry, 0.62, 4.6, rng, damp=2700.0)
    return fold_loop(wet, length)


MAKERS = {"sad": make_sad, "hope": make_hope, "tense": make_tense, "grief": make_grief}


def main():
    which = sys.argv[1:] or list(MAKERS)
    for k in which:
        write_ogg(MAKERS[k](), "theme_" + k, ar=24000, q=0, seam=0.02)


if __name__ == "__main__":
    main()
