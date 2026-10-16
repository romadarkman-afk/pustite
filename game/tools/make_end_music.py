"""Музыка финала «Пустите»: две цикличные петли по 40 с для экрана итога.
end_dawn — люди дожили до утра: светлая, но печальная (ля минор → до мажор), мелодия как старое пианино.
end_dark — посёлок пал: низкий гул, редкий колокол, расстроенная колыбельная.
Запуск из папки game: python3 tools/make_end_music.py .  → assets/music/end_dawn.ogg, end_dark.ogg
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sfx as S  # noqa: E402

SR = S.MUSIC_SR
SEC = 40


def hz(midi, cents=0.0):
    f = 440.0 * 2 ** ((midi - 69) / 12) * 2 ** (cents / 1200)
    return round(f * SEC) / SEC          # целое число периодов за петлю — шов не щёлкает


def pad(out, t, midi, w, gain, pan):
    lg, rg = np.sqrt((1 - pan) / 2), np.sqrt((1 + pan) / 2)
    for ch, det, g in ((0, -4.0, lg), (1, 4.0, rg)):
        th = 2 * np.pi * hz(midi, det) * t
        tone = 0.7 * np.sin(th) + 0.2 * np.sin(2 * th + 0.3) + 0.1 * np.sin(3 * th + 0.7)
        out[:, ch] += (tone * w * gain * g).astype(np.float32)


def pluck(out, t, start, midi, gain, pan, decay=2.4, bright=1.0):
    """Нота «старого пианино»: удар, обертоны гаснут быстрее основного тона. Циклично по петле."""
    el = np.mod(t - start, SEC)
    env = np.where(el < 6 * decay, np.exp(-el / decay) * np.minimum(1, el / 0.006), 0.0)
    f = hz(midi)
    x = np.zeros_like(t)
    for k, (h, g, d) in enumerate([(1, 1.0, 1.0), (2, 0.45 * bright, 0.55), (3, 0.22 * bright, 0.35), (4, 0.1 * bright, 0.25)]):
        x += g * np.sin(2 * np.pi * f * h * t + k) * np.exp(-el / (decay * d))
    x *= env
    lg, rg = np.sqrt((1 - pan) / 2), np.sqrt((1 + pan) / 2)
    out[:, 0] += (x * gain * lg).astype(np.float32)
    out[:, 1] += (x * gain * rg).astype(np.float32)


def chords_layer(out, t, chords, gain, bass_gain):
    bar = SEC / len(chords)
    slot = np.floor(t / bar).astype(int)
    inb = np.mod(t, bar)
    fin = (0.5 - 0.5 * np.cos(np.pi * np.clip(inb / 3.0, 0, 1))).astype(np.float32)
    for i, ch in enumerate(chords):
        cur = np.where(slot == i, fin, 0.0)
        prev = np.where(slot == (i + 1) % len(chords), 1 - fin, 0.0)
        w = (cur + prev).astype(np.float32)
        pad(out, t, ch[0] - 12, w, bass_gain, 0.0)
        for j, m in enumerate(ch):
            pad(out, t, m, w, gain, (j - 1.5) * 0.2)


def finish(out, delay=(0.31, 0.47), wet=0.18, peak=0.3):
    dry = out.copy()
    for ch, d in ((0, delay[0]), (1, delay[1])):
        k = int(d * SR)
        out[:, ch] += np.roll(dry[:, 1 - ch], k) * wet
        out[:, ch] += np.roll(dry[:, ch], 2 * k) * wet * 0.5
    m = float(np.max(np.abs(out))) or 1.0
    return out * (peak / m)


def end_dawn():
    t = np.arange(SR * SEC, dtype=np.float32) / SR
    out = np.zeros((len(t), 2), dtype=np.float32)
    # Am – F – C – G: печаль, которая к концу круга светлеет
    chords_layer(out, t, [[57, 60, 64, 67], [53, 57, 60, 64], [55, 60, 64, 67], [55, 59, 62, 67]], 0.05, 0.07)
    melody = [(0.5, 76), (2.0, 74), (3.5, 72), (5.0, 71), (6.5, 72), (8.5, 69),
              (10.5, 72), (12.0, 74), (13.5, 76), (15.0, 77), (16.5, 76), (18.5, 72),
              (20.5, 72), (22.0, 76), (23.5, 79), (25.0, 77), (26.5, 76), (28.5, 74),
              (30.5, 71), (32.0, 72), (33.5, 74), (35.0, 72), (37.0, 69)]
    for i, (s, m) in enumerate(melody):
        pluck(out, t, s, m, 0.09, -0.15 if i % 2 else 0.15, decay=2.2)
    for s, m in [(0.0, 45), (10.0, 41), (20.0, 48), (30.0, 43)]:
        pluck(out, t, s, m, 0.07, 0.0, decay=4.0, bright=0.4)
    return finish(out)


def end_dark():
    t = np.arange(SR * SEC, dtype=np.float32) / SR
    out = np.zeros((len(t), 2), dtype=np.float32)
    # Dm – Bb – Gm – A: тяжёлый минор, без разрешения
    chords_layer(out, t, [[50, 53, 57, 62], [46, 50, 53, 58], [43, 50, 55, 58], [45, 49, 52, 57]], 0.04, 0.1)
    drone = 0.06 * np.sin(2 * np.pi * hz(26) * t) * (0.7 + 0.3 * np.sin(2 * np.pi * t * 2 / SEC))
    out[:, 0] += drone.astype(np.float32)
    out[:, 1] += drone.astype(np.float32)
    # колыбельная на расстроенной музыкальной шкатулке: ноты чуть ниже, чем надо
    lull = [(1.0, 74), (2.2, 77), (3.4, 76), (4.6, 74), (6.4, 73), (8.0, 74),
            (11.0, 74), (12.2, 77), (13.4, 81), (14.6, 79), (16.4, 77), (18.0, 76),
            (21.0, 74), (22.2, 77), (23.4, 76), (24.6, 74), (26.4, 70), (28.0, 69),
            (31.0, 69), (32.4, 70), (33.8, 73), (35.4, 74)]
    for i, (s, m) in enumerate(lull):
        pluck(out, t, s, m, 0.055, 0.3 if i % 2 else -0.3, decay=1.4, bright=1.6)
    # колокол раз в 10 с, далеко
    for s in (5.0, 15.0, 25.0, 35.0):
        el = np.mod(t - s, SEC)
        env = np.where(el < 8, np.exp(-el / 2.5), 0.0)
        bell = sum(g * np.sin(2 * np.pi * hz(50) * r * t) for r, g in [(1, 1), (2.76, 0.4), (5.4, 0.2)])
        b = (bell * env * 0.05).astype(np.float32)
        out[:, 0] += b * 0.8
        out[:, 1] += b
    return finish(out, wet=0.24, peak=0.28)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    mus = os.path.join(root, 'assets', 'music')
    for name, fn in (('end_dawn', end_dawn), ('end_dark', end_dark)):
        path = os.path.join(mus, name + '.ogg')
        S.save_music(path, fn(), q=1)
        print('%s: %.0f КБ' % (name, os.path.getsize(path) / 1024))


if __name__ == '__main__':
    main()
