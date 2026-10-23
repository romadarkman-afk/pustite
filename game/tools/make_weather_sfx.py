"""Слои фонового звука (TASK-069): погода (ветер, дождь, метель), жизнь (говор, собака, куры)
и колесо мельницы. Всё синтезом, без чужих записей, источники не нужны.
Запуск из папки game: python3 tools/make_weather_sfx.py .
Циклы бесшовные: медленные волны делают целое число периодов за длину цикла.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sfx as S  # noqa: E402

SR = S.SR
RNG = np.random.default_rng(1913)


def periodic(t, cycles, phase=0.0):
    """Синус с целым числом периодов на длине t: края цикла сходятся."""
    return np.sin(2 * np.pi * cycles * t / t[-1] + phase) if len(t) else t


def wrap_smooth(sec, hz):
    """Медленный случайный сигнал 0..1 без шва: шум, сглаженный по кольцу."""
    n = int(SR * sec)
    x = RNG.standard_normal(n)
    k = int(SR / hz)
    ext = np.concatenate([x[-k * 3:], x, x[:k * 3]])
    ker = np.hanning(k * 2 + 1)
    ker /= ker.sum()
    y = np.convolve(ext, ker, mode="same")[k * 3:k * 3 + n]
    y = (y - y.min()) / (y.max() - y.min() + 1e-9)
    return y


def seamless(x, fade=0.35):
    """Свести хвост с началом: шов исчезает, длина остаётся почти прежней."""
    return S.loopify(x, fade)


def amb_wind():
    """Ровный ветер с порывами: шум в полосе 120–1100 Гц, громкость гуляет."""
    sec = 12.0
    t = S.t_of(sec)
    base = S.lp(S.bp(S.noise(sec), 90, 900), 800)
    gust = 0.35 + 0.65 * wrap_smooth(sec, 0.35)
    hiss = S.bp(S.noise(sec), 1400, 3200) * 0.07 * gust
    return seamless(S.norm((base * gust + hiss) * (0.8 + 0.2 * periodic(t, 3)), 0.5))


def amb_rain():
    """Дождь по крышам и траве: ровное шипение и частые капли."""
    sec = 10.0
    t = S.t_of(sec)
    hiss = S.bp(S.noise(sec), 900, 9000) * 0.55
    hiss += S.hp(S.noise(sec), 5000) * 0.18
    drops = np.zeros_like(t)
    for _ in range(int(sec * 140)):
        s = int(RNG.uniform(0, len(t) - 400))
        n = int(SR * RNG.uniform(0.004, 0.012))
        tt = np.arange(n) / SR
        f = RNG.uniform(1800, 5200)
        drops[s:s + n] += np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.003) * RNG.uniform(0.05, 0.22)
    swell = 0.8 + 0.2 * wrap_smooth(sec, 0.5)
    return seamless(S.norm((hiss + drops) * swell, 0.5))


def amb_blizzard():
    """Метель: плотный низкий ветер, свистящая полоса гуляет по частоте, секущая крупа."""
    sec = 12.0
    t = S.t_of(sec)
    low = S.bp(S.noise(sec), 90, 700)
    gust = 0.45 + 0.55 * wrap_smooth(sec, 0.5)
    # свист: четыре узкие полосы, громкость каждой плывёт в своё время, ухо слышит гуляющий тон
    whistle = np.zeros_like(t)
    for k, c in enumerate((820, 1010, 1240, 1480)):
        band = S.bp(S.noise(sec), c * 0.92, c * 1.08, order=3)
        whistle += band * (0.5 + 0.5 * periodic(t, 2 + k, phase=1.7 * k)) ** 2
    grains = S.hp(S.noise(sec), 4500) * 0.12 * gust
    x = low * gust * 1.1 + whistle * 0.55 * gust + grains
    return seamless(S.norm(x, 0.55))


def life_murmur():
    """Далёкий говор: пять невнятных голосов, слоги 3–5 раз в секунду, гласные 300–2400 Гц."""
    sec = 14.0
    t = S.t_of(sec)
    mix = np.zeros_like(t)
    for v in range(5):
        pitch = RNG.uniform(105, 230)
        # источник голоса: гребень гармоник
        phase = 2 * np.pi * np.cumsum(pitch * (1 + 0.04 * np.sin(2 * np.pi * RNG.uniform(0.2, 0.7) * t))) / SR
        src = sum(np.sin(phase * k) / k for k in range(1, 14))
        # формантные полосы переключаются на каждом слоге
        out = np.zeros_like(t)
        syl = int(SR * RNG.uniform(0.17, 0.3))
        pos = int(RNG.uniform(0, syl))
        while pos < len(t) - syl:
            f1 = RNG.uniform(300, 800)
            f2 = RNG.uniform(900, 2300)
            seg = src[pos:pos + syl]
            a = S.bp(seg, f1 * 0.85, f1 * 1.2) + 0.55 * S.bp(seg, f2 * 0.85, f2 * 1.2)
            a *= np.sin(np.pi * np.arange(len(seg)) / len(seg)) ** 1.5
            out[pos:pos + syl] += a * RNG.uniform(0.4, 1.0)
            pos += syl + int(SR * RNG.choice([0.0, 0.0, 0.05, 0.25, 0.6]))
        mix += out * (0.6 + 0.4 * wrap_smooth(sec, 0.3))
    mix = S.lp(mix, 2600)
    return seamless(S.norm(mix, 0.5))


def life_dog():
    """Собака лает вдали: три хриплых «гав» с затуханием, через сопку и воздух."""
    sec = 3.2
    t = S.t_of(sec)
    x = np.zeros_like(t)
    for start, g in ((0.1, 1.0), (0.85, 0.85), (1.45, 0.7)):
        s = int(SR * start)
        n = int(SR * 0.28)
        tt = np.arange(n) / SR
        f = 420 - 220 * tt / 0.28 + 30 * np.sin(2 * np.pi * 31 * tt)
        ph = 2 * np.pi * np.cumsum(f) / SR
        src = np.sign(np.sin(ph)) * 0.35 + np.sin(ph) + 0.4 * np.sin(2 * ph)
        voiced = S.bp(src, 300, 1800) + 0.35 * S.bp(S.noise(0.28)[:n], 500, 2200)
        voiced *= np.minimum(1.0, tt / 0.015) * np.exp(-tt / 0.1)
        x[s:s + n] += voiced * g
    return S.norm(S.lp(x, 1800), 0.5)


def life_hens():
    """Куры во дворе: короткие «ко-ко» с растущим тоном и редкое «кудах»."""
    sec = 3.6
    t = S.t_of(sec)
    x = np.zeros_like(t)
    starts = (0.1, 0.38, 0.62, 1.4, 1.62, 2.2, 2.42, 2.64)
    for k, start in enumerate(starts):
        s = int(SR * start)
        n = int(SR * 0.13)
        tt = np.arange(n) / SR
        f = 520 + 380 * tt / 0.13 + 40 * k % 5
        ph = 2 * np.pi * np.cumsum(f) / SR
        src = np.sin(ph) + 0.6 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)
        c = S.bp(src, 450, 2600) * np.sin(np.pi * tt / 0.13) ** 0.8
        x[s:s + n] += c * (0.7 + 0.3 * ((k * 7) % 3) / 2)
    return S.norm(S.lp(x, 3200), 0.45)


def mill_wheel():
    """Колесо мельницы: вода по лопастям, редкий скрип оси и глухой стук жернова."""
    sec = 12.0
    t = S.t_of(sec)
    water = S.bp(S.noise(sec), 200, 2200) * (0.55 + 0.45 * periodic(t, 12))
    water = S.lp(water, 2000)
    creak = np.zeros_like(t)
    for start in (1.7, 5.9, 9.4):
        s = int(SR * start)
        n = int(SR * 0.9)
        tt = np.arange(n) / SR
        f = 180 + 90 * np.sin(2 * np.pi * 0.9 * tt) + 40 * tt
        ph = 2 * np.pi * np.cumsum(f) / SR
        c = (np.sign(np.sin(ph)) * 0.4 + np.sin(ph)) * np.sin(np.pi * tt / 0.9) ** 2
        creak[s:s + n] += S.bp(c, 160, 900) * 0.55
    thud = np.zeros_like(t)
    for k in range(12):
        s = int(SR * (k + 0.5))
        n = int(SR * 0.22)
        tt = np.arange(n) / SR
        thud[s:s + n] += np.sin(2 * np.pi * 58 * tt) * np.exp(-tt / 0.07) * 0.5
    return seamless(S.norm(water * 0.8 + creak + thud, 0.5))


def save(path, x, sr_out, q):
    """OGG моно. Низкая частота дискретизации для глухих звуков: файл втрое легче."""
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-ar", str(sr_out),
                    "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.remove(tmp)


def main() -> None:
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    out = os.path.join(root, "assets", "sfx")
    os.makedirs(out, exist_ok=True)
    jobs = [
        ("amb_wind", amb_wind, 16000, 1),
        ("amb_rain", amb_rain, 24000, 1),
        ("amb_blizzard", amb_blizzard, 16000, 1),
        ("life_murmur", life_murmur, 16000, 1),
        ("life_dog", life_dog, 16000, 2),
        ("life_hens", life_hens, 16000, 2),
        ("mill_wheel", mill_wheel, 16000, 1),
    ]
    for name, fn, sr_out, q in jobs:
        path = os.path.join(out, name + ".ogg")
        save(path, fn(), sr_out, q)
        print("OK", path, os.path.getsize(path) // 1024, "КБ")


if __name__ == "__main__":
    main()
