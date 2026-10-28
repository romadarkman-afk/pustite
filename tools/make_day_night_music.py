#!/usr/bin/env python3
"""Музыка для дня и ночи: game/assets/music/day.ogg и night.ogg.

День: тёплая мажорная тема, щипковая гитара и флейта, медленный ход, чуть танцевальный.
Ночь: тревожная тема в миноре с малой секундой и тритоном: расстроенная музыкальная шкатулка,
дрожащий кластер высоких «струн», редкие глухие удары и шорох. Без сердцебиения: оно играет отдельным звуком у двери.

Всё считается кодом (numpy + ffmpeg), без внешних записей: права на дорожки принадлежат проекту.
Дорожки замкнуты в петлю: хвост реверберации складывается с началом, периодические огибающие
укладываются в длину целое число раз. Громкость −16 LUFS (как требует tools/check_music.py).

Запуск из корня репозитория:  python3 tools/make_day_night_music.py [day|night]
"""
import os
import re
import subprocess
import sys

import numpy as np
from scipy.signal import butter, fftconvolve, lfilter

SR = 44100
OUT = os.path.join("game", "assets", "music")
TARGET_LUFS = -16.0


# ---------------------------------------------------------------- основа

def midi(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def n(name):
    """'F#5' -> номер MIDI; 'Bb4' -> номер MIDI."""
    m = re.fullmatch(r"([A-G])([#b]?)(\d)", name)
    base = NOTE[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0)
    return 12 * (int(m.group(3)) + 1) + base


def tvec(dur):
    return np.arange(int(dur * SR)) / SR


def lowpass(x, hz, order=2):
    b, a = butter(order, hz / (SR / 2), btype="low")
    return lfilter(b, a, x)


def highpass(x, hz, order=2):
    b, a = butter(order, hz / (SR / 2), btype="high")
    return lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return lfilter(b, a, x)


def put(buf, start, sig, gain=1.0, pan=0.0):
    """Кладёт моно-сигнал в стерео-буфер с позиции start (секунды); pan −1…1."""
    i = int(start * SR)
    if i >= buf.shape[0]:
        return
    sig = sig[: buf.shape[0] - i]
    l = gain * np.sqrt(0.5 * (1.0 - pan))
    r = gain * np.sqrt(0.5 * (1.0 + pan))
    buf[i:i + len(sig), 0] += sig * l
    buf[i:i + len(sig), 1] += sig * r


def reverb_ir(seconds, rng, damp=3500.0, pre=0.012):
    t = tvec(seconds)
    ir = []
    for _ in range(2):
        noise = rng.standard_normal(len(t))
        noise = lowpass(noise, damp, 1) * np.exp(-t * (6.9 / seconds))
        ir.append(noise)
    ir = np.stack(ir, axis=1)
    ir[: int(pre * SR)] = 0.0
    ir /= np.sqrt((ir ** 2).sum(axis=0, keepdims=True)) + 1e-9
    return ir


def apply_reverb(dry, wet, seconds, rng, damp=3500.0):
    """Свёртка с синтетическим откликом зала. Сухой сигнал остаётся, влажный добавляется на wet."""
    ir = reverb_ir(seconds, rng, damp)
    res = np.zeros((dry.shape[0] + len(ir) - 1, 2))
    for ch in range(2):
        res[:, ch] = fftconvolve(dry[:, ch], ir[:, ch])
    res *= wet
    res[: dry.shape[0]] += dry
    return res


def fold_loop(buf, length):
    """Хвост за пределами петли ложится на начало: стык без щелчка и без обрыва реверберации."""
    out = buf[:length].copy()
    tail = buf[length:]
    k = 0
    while k < len(tail):
        seg = tail[k:k + length]
        out[: len(seg)] += seg
        k += length
    return out


# ---------------------------------------------------------------- инструменты

def pluck(freq, dur=2.2, bright=0.55, rng=None):
    """Щипок струны: гармоники с разной скоростью затухания (верхние гаснут быстрее)."""
    t = tvec(dur)
    out = np.zeros_like(t)
    for k in range(1, 14):
        f = freq * k * (1.0 + 0.0004 * k * k)
        if f > 9000:
            break
        amp = (1.0 / k) * (bright ** (k - 1))
        tau = 0.9 / (1.0 + 0.55 * (k - 1))
        out += amp * np.sin(2 * np.pi * f * t) * np.exp(-t / tau)
    attack = np.minimum(1.0, t / 0.004)
    return out * attack * np.exp(-t / (dur * 0.6))


def flute(freq, dur, vib=5.2, vib_depth=0.006, breath=0.05, rng=None, soft=1.0):
    """Мягкая флейта: чистая основа, слабая октава, дыхание и неспешное вибрато."""
    t = tvec(dur)
    vib_env = np.clip((t - 0.18) / 0.35, 0.0, 1.0)
    phase = 2 * np.pi * np.cumsum(freq * (1.0 + vib_depth * vib_env * np.sin(2 * np.pi * vib * t))) / SR
    sig = np.sin(phase) + 0.28 * np.sin(2 * phase) * soft + 0.07 * np.sin(3 * phase)
    if rng is not None and breath > 0:
        sig += breath * bandpass(rng.standard_normal(len(t)), 1800, 5200, 1) * (1.0 - 0.6 * np.exp(-t / 0.2))
    atk = np.minimum(1.0, t / 0.07)
    rel = np.minimum(1.0, np.maximum(0.0, (dur - t)) / 0.12)
    return sig * atk * rel


def bell(freq, dur=3.0, detune_cents=0.0):
    """Шкатулка / колокольчик: неточные обертоны, как у металлической пластинки."""
    t = tvec(dur)
    f0 = freq * 2 ** (detune_cents / 1200.0)
    out = np.zeros_like(t)
    for ratio, amp, tau in ((1.0, 1.0, 1.8), (2.76, 0.42, 1.0), (5.4, 0.2, 0.55), (8.93, 0.09, 0.3)):
        out += amp * np.sin(2 * np.pi * f0 * ratio * t) * np.exp(-t / tau)
    return out * np.minimum(1.0, t / 0.002)


def warm_pad(freqs, dur, bright=0.5, detune=0.0025):
    """Тёплая подкладка: несколько расстроенных пил, срезанных по верху."""
    t = tvec(dur)
    out = np.zeros_like(t)
    for f in freqs:
        for d in (-detune, 0.0, detune):
            ff = f * (1.0 + d)
            for k in range(1, 7):
                out += (bright ** (k - 1)) / k * np.sin(2 * np.pi * ff * k * t + k * 1.3)
    out = lowpass(out, 2400, 1)
    return out / (len(freqs) * 2.0)


def swell(dur, attack, release):
    t = tvec(dur)
    return np.minimum(1.0, t / attack) * np.minimum(1.0, np.maximum(0.0, (dur - t)) / release)


# ---------------------------------------------------------------- день

def make_day():
    rng = np.random.default_rng(2026)
    bpm = 100.0
    beat = 60.0 / bpm
    bars = 32
    length = int(bars * 4 * beat * SR)
    tail = 3.0
    buf = np.zeros((length + int(tail * SR), 2))

    chords = {
        "D": ("D3", ["D4", "F#4", "A4"]), "A": ("A3", ["C#4", "E4", "A4"]), "Bm": ("B3", ["D4", "F#4", "B4"]),
        "G": ("G3", ["D4", "G4", "B4"]), "Em": ("E3", ["E4", "G4", "B4"]),
    }
    prog_a = ["D", "A", "Bm", "G", "D", "A", "G", "A"]
    prog_b = ["G", "D", "Em", "A", "G", "D", "A", "A"]
    prog = prog_a + prog_b + prog_a + prog_b

    # мелодия: (нота или None, длина в долях)
    mel_a = [
        [("F#5", 1), ("A5", 1), ("F#5", .5), ("E5", .5), ("D5", 1)],
        [("E5", 1), ("C#5", 1), ("E5", 2)],
        [("D5", 1), ("F#5", 1), ("B5", 1), ("A5", 1)],
        [("G5", 2), ("F#5", 1), ("E5", 1)],
        [("F#5", 1), ("A5", 1), ("F#5", .5), ("E5", .5), ("D5", 1)],
        [("E5", 1), ("C#5", 1), ("E5", 1), ("A4", 1)],
        [("B4", 1), ("D5", 1), ("G5", 1), ("F#5", 1)],
        [("E5", 3), (None, 1)],
    ]
    mel_b = [
        [("B5", 1), ("A5", 1), ("G5", 1), ("B5", 1)],
        [("A5", 2), ("F#5", 1), ("A5", 1)],
        [("G5", 1), ("E5", 1), ("G5", 1), ("B5", 1)],
        [("A5", 2), ("E5", 1), ("C#5", 1)],
        [("B5", 1), ("D6", 1), ("B5", 1), ("G5", 1)],
        [("A5", 1), ("F#5", 1), ("D5", 2)],
        [("E5", 1), ("F#5", 1), ("E5", 1), ("C#5", 1)],
        [("E5", 2), ("C#5", 1), ("E5", 1)],
    ]
    melody = mel_a + mel_b + mel_a + mel_b

    dry = np.zeros_like(buf)
    flute_dry = np.zeros_like(buf)
    for bar in range(bars):
        t0 = bar * 4 * beat
        root, tones = chords[prog[bar]]
        # бас: на раз и три, мягкий щипок
        for b in (0, 2):
            put(dry, t0 + b * beat, pluck(midi(n(root)), 1.6, 0.62), 0.42, -0.1)
        # арпеджио гитары: восьмые по кругу, на втором проходе плотнее
        pattern = [0, 1, 2, 1, 0, 1, 2, 1] if bar < 16 else [0, 2, 1, 2, 0, 2, 1, 2]
        for i, idx in enumerate(pattern):
            note = n(tones[idx])
            vel = 0.30 if i % 2 == 0 else 0.22
            put(dry, t0 + i * 0.5 * beat, pluck(midi(note), 1.4, 0.55), vel,
                -0.35 + 0.1 * idx)
        # подкладка: аккорд на весь такт
        pad = warm_pad([midi(n(x)) for x in tones], 4 * beat + 0.4, 0.45) * swell(4 * beat + 0.4, 0.5, 0.5)
        put(dry, t0 - 0.1 if bar else 0.0, pad, 0.17, 0.0)
        # мелодия
        pos = t0
        for note, dur in melody[bar]:
            if note is not None:
                f = midi(n(note))
                d = dur * beat
                if bar < 16 or bar >= 24:
                    put(flute_dry, pos, flute(f, d * 0.96 + 0.1, rng=rng), 0.50, 0.12)
                else:
                    # третья четверть: шкатулка поверх, флейта тише
                    put(flute_dry, pos, flute(f, d * 0.96 + 0.1, rng=rng), 0.30, 0.12)
                    put(dry, pos, bell(f * 2, 1.8), 0.11, 0.25)
            pos += dur * beat
        # лёгкий «эхо-колокольчик» на последней доле восьмого такта каждой секции
        if bar % 8 == 7:
            put(dry, t0 + 3.5 * beat, bell(midi(n("A5")), 2.4), 0.10, -0.3)

    dry += flute_dry
    wet = apply_reverb(dry, 0.28, 2.2, rng)
    mix = fold_loop(wet, length)
    return mix


# ---------------------------------------------------------------- ночь

def make_night():
    rng = np.random.default_rng(1347)
    length_s = 72.0
    length = int(length_s * SR)
    tail = 5.0
    buf = np.zeros((length + int(tail * SR), 2))
    dry = np.zeros_like(buf)
    T = tvec(length_s + tail)

    def cyc(k, phase=0.0):
        """Периодическая огибающая 0…1: k полных оборотов за петлю."""
        return 0.5 + 0.5 * np.sin(2 * np.pi * k * T / length_s + phase)

    # 1. гул: основа и квинта на нижнем регистре, расстроенные пилы; верхние гармоники слышны и на динамике телефона
    drone = np.zeros_like(T)
    for f, a in ((midi(n("E2")), 1.0), (midi(n("B2")), 0.6), (midi(n("E3")), 0.7)):
        for d in (-0.004, 0.0, 0.004):
            for k in range(1, 9):
                drone += a * (0.7 ** (k - 1)) / k * np.sin(2 * np.pi * f * (1 + d) * k * T + k)
    drone = lowpass(drone, 2200, 1) * (0.5 + 0.5 * cyc(3, -np.pi / 2))
    put(dry, 0.0, drone, 0.050)

    # 2. кластер «струн»: Е, F (малая секунда), Bb (тритон) выше, с дрожью и медленным дыханием по громкости
    cluster = np.zeros_like(T)
    for name, k, ph in (("E4", 4, 0.0), ("F4", 3, 0.5), ("Bb4", 5, 1.0), ("E5", 2, 0.3), ("F5", 3, 0.8)):
        f = midi(n(name))
        for d in (-0.003, 0.004):
            vib = 1.0 + 0.003 * np.sin(2 * np.pi * 5.5 * T + ph)
            sig = np.zeros_like(T)
            for h in range(1, 7):
                sig += (0.62 ** (h - 1)) * np.sin(2 * np.pi * f * (1 + d) * h * vib * T + h * ph)
            cluster += sig * (0.12 + 0.88 * cyc(k, ph - np.pi / 2) ** 2)
    cluster = bandpass(cluster, 280, 3800, 1) * (1.0 + 0.45 * np.sin(2 * np.pi * 7.0 * T))
    put(dry, 0.0, cluster, 0.115, 0.1)

    # 3. шкатулка: колыбельная, которая сбивается. Мотив в ми-фригийском, расстроен, тянется и дёргается
    motif = [("E5", 0.0), ("G5", 1.7), ("F5", 3.5), ("E5", 5.6), ("B4", 8.1), ("Bb4", 10.4)]
    motif_b = [("B5", 0.0), ("G5", 2.1), ("E5", 4.0), ("F5", 6.4), ("E5", 8.5)]
    starts = [2.0, 15.5, 28.0, 41.0, 54.5, 65.0]
    shapes = [motif, motif_b, motif, motif_b, motif, [("E5", 0.0), ("F5", 3.0), ("E5", 6.0)]]
    for s0, shape in zip(starts, shapes):
        stretch = rng.uniform(0.95, 1.12)
        for name, off in shape:
            when = s0 + off * stretch + rng.uniform(-0.08, 0.08)
            cents = rng.uniform(-35, -8)
            vel = 0.15 * rng.uniform(0.75, 1.1)
            put(dry, when, bell(midi(n(name)), 4.0, cents), vel, rng.uniform(-0.5, 0.5))
            if rng.random() < 0.28:
                put(dry, when + 0.18, bell(midi(n(name)) * 2, 2.5, cents + 12), vel * 0.4, rng.uniform(-0.6, 0.6))

    # 4. глухие удары: низкий тон с падением высоты и шумом, ушедшие в зал
    for when, strength in ((7.5, 1.0), (23.0, 0.8), (38.0, 1.0), (52.0, 0.8), (66.0, 0.9)):
        t = tvec(3.2)
        f = 78.0 + 70.0 * np.exp(-t / 0.08)
        body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.55)
        knock = lowpass(rng.standard_normal(len(t)), 700, 1) * np.exp(-t / 0.06)
        mid = np.sin(2 * np.pi * 210.0 * t) * np.exp(-t / 0.20) * 0.5
        put(dry, when, (0.55 * body + 0.5 * knock + 0.9 * mid) * strength, 0.26, rng.uniform(-0.2, 0.2))

    # 5. шорох: полосовой шум дышит перед ударами
    for when, dur in ((3.0, 6.0), (18.0, 7.0), (31.0, 6.5), (46.0, 6.0), (60.0, 7.0)):
        noise = bandpass(rng.standard_normal(int(dur * SR)), 1800, 4800, 1)
        env = np.sin(np.pi * np.linspace(0.0, 1.0, len(noise))) ** 2.2
        put(dry, when, noise * env, 0.060, rng.uniform(-0.6, 0.6))

    # 6. редкие низкие «стоны» струн вниз по полутонам: Е → Eb → D
    for when, a, b in ((12.0, "E3", "Eb3"), (34.0, "B3", "Bb3"), (58.0, "E3", "D3")):
        t = tvec(7.0)
        fa, fb = midi(n(a)), midi(n(b))
        glide = np.where(t < 3.0, fa, fa + (fb - fa) * np.clip((t - 3.0) / 3.0, 0.0, 1.0))
        sig = np.zeros_like(t)
        for h in range(1, 7):
            sig += (0.6 ** (h - 1)) * np.sin(2 * np.pi * np.cumsum(glide * h) / SR + h)
        put(dry, when, sig * swell(7.0, 2.5, 3.0), 0.060, rng.uniform(-0.3, 0.3))

    wet = apply_reverb(dry, 0.55, 3.8, rng, damp=2800.0)
    mix = fold_loop(wet, length)
    return mix


# ---------------------------------------------------------------- вывод

def lufs(path):
    r = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.findall(r"I:\s+(-?\d+\.\d+) LUFS", r.stderr)
    return float(m[-1]) if m else None


def write_ogg(mix, name, ar=32000, q=2, seam=0.0):
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join("/tmp", name + "_raw.wav")
    if seam > 0.0:
        # Vorbis начинает поток с задержкой в сотню отсчётов: первые отсчёты декодируются тишиной, последние отбрасываются.
        # Короткое затухание на обоих концах петли убирает щелчок на стыке у низких тонов.
        k = int(seam * SR)
        ramp = np.linspace(0.0, 1.0, k)[:, None]
        mix = mix.copy()
        mix[:k] *= ramp
        mix[-k:] *= ramp[::-1]
    peak = np.max(np.abs(mix)) + 1e-9
    mix = mix / peak * 0.5
    pcm = (np.clip(mix, -1.0, 1.0) * 32767).astype(np.int16)
    import wave
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    loud = lufs(wav)
    gain_db = TARGET_LUFS - loud
    out = os.path.join(OUT, name + ".ogg")
    # alimiter не даёт пикам уйти выше −1 дБ после подъёма громкости
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", wav, "-af", "volume=%.2fdB,alimiter=limit=0.89:level=false" % gain_db,
                    "-ar", str(ar), "-c:a", "libvorbis", "-q:a", str(q), out], check=True)   # 32 кГц: музыка ниже 6 кГц, 0,7 МБ на дорожку (бюджет звука 6 МиБ)
    print("%s: %.1f с, было %.1f LUFS, стало %.1f LUFS" % (out, len(mix) / SR, loud, lufs(out)))


def main():
    which = sys.argv[1:] or ["day", "night"]
    if "day" in which:
        write_ogg(make_day(), "day")
    if "night" in which:
        write_ogg(make_night(), "night")


if __name__ == "__main__":
    main()
