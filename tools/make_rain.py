#!/usr/bin/env python3
"""Дождь и гром для игры из 13 бесплатных записей, которые скинул Влади (0.70.0).

Что делает:
  1. Берёт из каждой записи чистые участки без раскатов и щелчков (окна заданы в BEDS, времена в секундах исходника).
  2. Выравнивает уровень окон, склеивает их равномощными перекрытиями и замыкает петлю тем же перекрытием,
     поэтому шва нет: на стыке складываются два независимых куска шума, громкость не проседает.
  3. Срезает инфразвук, чуть приглушает выше 5 кГц (на динамике телефона шипение дождя режет слух),
     у широких стереозаписей уменьшает разностный канал, чтобы при сложении в моно дождь не терял 4 дБ.
  4. Из моно-записей делает стерео дополнительными гребёнками: L = x + g*d(x), R = x - g*d(x), в моно сумма равна x.
  5. Приводит громкость к целевому LUFS каждого слоя и пишет ogg.
  6. Раскаты грома вырезает из записи ливня, оставляет только низ и середину (шум дождя уходит),
     добавляет гармоники нижних частот: динамик телефона не играет ниже 150 Гц, без них гром звучал бы как тихий шорох.

Исходники (mp3) не лежат в репозитории: файлы Влади, их имена начинаются с хэша, он указан в SRC.
Запуск из корня репозитория:
  python3 tools/make_rain.py <папка_с_mp3>            собрать всё в game/assets/sfx
  python3 tools/make_rain.py <папка_с_mp3> --report   только цифры, без записи
  python3 tools/make_rain.py <папка_с_mp3> --only amb_rain_light,thunder
"""
import argparse
import pathlib
import subprocess
import sys

import numpy as np
from scipy import signal

ROOT = pathlib.Path(__file__).resolve().parents[1]
DST = ROOT / "game" / "assets" / "sfx"
SR = 32000

# Короткое имя -> начало имени файла.
SRC = {
    "drops": "384de863", "weak": "c7555cd6", "fine": "6d8bba8f", "storm": "4b306fc6", "rain": "62073af6",
    "roof": "0f8c1d19", "thunderwind": "738e0d77",
    "h1": "72bc6f68", "h2": "9e065484", "h3": "a2f6f860", "h4": "acf1d38e", "h5": "ecc23a65", "h6": "eec91326",
}

# Слои дождя. windows: куски исходника (с, с); lufs: целевая громкость файла; widen: сделать стерео из моно;
# shelf_db: срез выше 5 кГц; xf: перекрытие склеек и шва петли в секундах.
BEDS = {
    # мелкий дождь, 112 с моно, ровный шум с редкими каплями; ниже всех по уровню в исходнике
    "amb_rain_light": dict(src="h1", windows=[(2.0, 100.0)], lufs=-20.0, widen=True, shelf_db=-3.0, xf=4.0),
    # средний ровный дождь, 122 с моно, центр 300 Гц-5 кГц
    "amb_rain": dict(src="h2", windows=[(2.0, 100.0)], lufs=-17.0, widen=True, shelf_db=-3.0, xf=4.0),
    # ливень: пять чистых окон из записи на 15 минут (там раскаты каждые 25 секунд), у каждого свой уровень
    "amb_rain_heavy": dict(src="storm", windows=[(630.0, 669.0), (203.8, 235.5), (140.2, 166.0), (333.8, 360.8)],
                           lufs=-14.0, hp=38.0, shelf_db=-2.0, xf=4.0),
    # дождь по крыше, 64 с стерео
    "amb_rain_roof": dict(src="roof", windows=[(0.6, 62.8)], lufs=-17.0, shelf_db=-2.0, xf=4.0),
    # дождь с листвы и карниза: крупные капли с плеском выше 5 кГц (18.8, 55.0, 75.0, 87.2, 101.0 с в исходнике)
    "amb_rain_drops": dict(src="drops", windows=[(23.0, 98.0)], lufs=-18.0, shelf_db=-4.0, xf=4.5, comp=(5.0, 3.0)),
    # дождь за стеной: глухой, почти без верха, тихие капли в средних частотах
    "amb_rain_inside": dict(src="h4", windows=[(1.0, 100.0)], lufs=-19.0, widen=True, xf=4.0, comp=(6.0, 2.0)),
}

# Раскаты: окно в исходнике, верхняя граница полосы, наращивание гармоник нижних частот.
THUNDER = {
    # окна выбраны по огибающей 30-600 Гц: резкий вход на 15-20 дБ над фоном шторма и спад на 14 дБ за 3-5 секунд
    "thunder": dict(src="storm", win=(107.6, 116.0), lp=1000.0, tail=2.5),       # раскат со второй волной
    "thunder_2": dict(src="storm", win=(192.7, 200.0), lp=1000.0, tail=2.5),     # самый сильный в записи
    "thunder_3": dict(src="storm", win=(315.0, 323.5), lp=1000.0, tail=2.5),     # двойной
    "thunder_4": dict(src="storm", win=(421.2, 427.0), lp=1000.0, tail=2.0),     # короткий
    # из записи, где всё слышно через стену (выше 3 кГц пусто): для сцен в доме
    "thunder_far": dict(src="h6", win=(66.8, 73.2), lp=700.0, tail=2.0),
}


def find_src(folder, key):
    hits = sorted(p for p in pathlib.Path(folder).iterdir() if p.name.startswith(SRC[key]) and p.suffix.lower() == ".mp3")
    if not hits:
        raise SystemExit("нет файла %s* в %s" % (SRC[key], folder))
    return hits[0]


_cache = {}


def decode(folder, key):
    if key in _cache:
        return _cache[key]
    p = find_src(folder, key)
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", str(p), "-f", "f32le", "-ar", str(SR), "-"], capture_output=True)
    if r.returncode != 0:
        raise SystemExit("ffmpeg не прочитал %s" % p)
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels",
                            "-of", "csv=p=0", str(p)], capture_output=True, text=True)
    ch = int(probe.stdout.strip().strip(",") or 1)
    x = np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64)
    x = x.reshape(-1, ch)
    _cache[key] = x
    return x


def rms(x):
    return float(np.sqrt(np.mean(np.square(x)) + 1e-18))


def db(v):
    return 20.0 * np.log10(max(v, 1e-12))


def mono_drop_db(x):
    if x.shape[1] < 2:
        return 0.0
    L, R = x[:, 0], x[:, 1]
    st = np.sqrt(np.mean((L ** 2 + R ** 2) / 2.0))
    mo = np.sqrt(np.mean(((L + R) / 2.0) ** 2))
    return db(mo / max(st, 1e-12))


def fix_side(x, limit_db=-1.5):
    """Уменьшает разностный канал, если в моно запись теряет больше limit_db."""
    if x.shape[1] < 2 or mono_drop_db(x) >= limit_db:
        return x
    M = (x[:, 0] + x[:, 1]) / 2.0
    S = (x[:, 0] - x[:, 1]) / 2.0
    want = 10 ** (limit_db / 20.0)
    f2 = (1.0 / want ** 2 - 1.0) * np.mean(M ** 2) / max(np.mean(S ** 2), 1e-18)
    f = min(1.0, np.sqrt(max(f2, 0.0)))
    return np.stack([M + f * S, M - f * S], axis=1)


def xfade(a, b, n):
    """Равномощное перекрытие хвоста a и начала b на n отсчётов."""
    t = np.linspace(0.0, np.pi / 2.0, n)[:, None]
    mid = a[-n:] * np.cos(t) + b[:n] * np.sin(t)
    return np.concatenate([a[:-n], mid, b[n:]], axis=0)


def chain(parts, xf):
    n = int(xf * SR)
    out = parts[0]
    for p in parts[1:]:
        out = xfade(out, p, n)
    return out


def wrap_loop(x, xf):
    """Склеивает конец с началом: после этого цикл можно крутить без шва."""
    n = int(xf * SR)
    head, tail, mid = x[:n], x[-n:], x[n:-n]
    t = np.linspace(0.0, np.pi / 2.0, n)[:, None]
    blend = tail * np.cos(t) + head * np.sin(t)
    return np.concatenate([blend, mid], axis=0)


def filt(x, kind, hz, order=2):
    sos = signal.butter(order, hz, btype=kind, fs=SR, output="sos")
    return signal.sosfiltfilt(sos, x, axis=0)


def widen(mono, g=0.45, delay_ms=13.0):
    """Из моно делает стерео, которое в сумме L+R снова равно исходному."""
    d = int(delay_ms / 1000.0 * SR)
    x = mono[:, 0]
    dx = np.concatenate([np.zeros(d), x[:-d]])
    # петля: задержка берётся из конца, поэтому на стыке нет провала
    dx[:d] = x[-d:]
    return np.stack([x + g * dx, x - g * dx], axis=1)


def compress(x, over_db, ratio, attack=0.006, release=0.25):
    """Сжимает выбросы над типичным уровнем: громкие капли и плески не должны пугать на фоне тихого дождя."""
    fr = 32
    n = len(x) // fr * fr
    lev = np.sqrt(np.mean(np.square(np.max(np.abs(x[:n]), axis=1)).reshape(-1, fr), axis=1) + 1e-18)
    ldb = 20.0 * np.log10(lev + 1e-9)
    thr = np.median(ldb) + over_db
    want = -np.maximum(ldb - thr, 0.0) * (1.0 - 1.0 / ratio)
    g = np.zeros_like(want)
    ka = np.exp(-fr / (attack * SR))
    kr = np.exp(-fr / (release * SR))
    cur = 0.0
    for i, w in enumerate(want):
        k = ka if w < cur else kr
        cur = k * cur + (1.0 - k) * w
        g[i] = cur
    gain = 10.0 ** (np.repeat(g, fr) / 20.0)
    gain = np.concatenate([gain, np.full(len(x) - n, gain[-1])])
    return x * gain[:, None]


def lufs(x):
    pcm = x if x.shape[1] == 2 else np.repeat(x, 2, axis=1)
    r = subprocess.run(["ffmpeg", "-nostats", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-", "-af", "ebur128=peak=true",
                        "-f", "null", "-"], input=pcm.astype("<f4").tobytes(), capture_output=True)
    txt = r.stderr.decode("utf-8", "replace")
    tail = txt[txt.rfind("Summary"):]
    i = float(tail.split("I:")[1].split("LUFS")[0])
    return i


def soft_limit(x, ceiling=0.89):
    pk = float(np.max(np.abs(x)))
    if pk <= ceiling:
        return x
    # мягкий предел: выше порога сжимаем tanh, чтобы не было щелчков
    k = ceiling
    over = np.abs(x) > k * 0.8
    y = x.copy()
    a = np.abs(x[over])
    y[over] = np.sign(x[over]) * (k * 0.8 + (k - k * 0.8) * np.tanh((a - k * 0.8) / (k - k * 0.8)))
    return y


def encode(x, dst, quality=3):
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    r = subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", str(x.shape[1]), "-i", "-",
                        "-c:a", "libvorbis", "-q:a", str(quality), str(dst)], input=pcm, capture_output=True)
    if r.returncode != 0:
        raise SystemExit(r.stderr.decode("utf-8", "replace")[:300])


def seam_report(x, xf):
    """Сравнивает уровень и спектр на шве петли (последние и первые 2 с) со средним по файлу."""
    n = int(2.0 * SR)
    m = x.mean(axis=1)
    a, b = m[-n:], m[:n]
    f1, p1 = signal.welch(a, SR, nperseg=4096)
    f2, p2 = signal.welch(b, SR, nperseg=4096)
    band = (f1 > 150) & (f1 < 8000)
    spec = float(np.mean(np.abs(10 * np.log10(p1[band] + 1e-18) - 10 * np.log10(p2[band] + 1e-18))))
    # уровень в окнах по 0,25 с вокруг шва против медианы
    h = int(0.25 * SR)
    seq = np.concatenate([m[-4 * h:], m[:4 * h]])
    local = [db(rms(seq[i * h:(i + 1) * h])) for i in range(8)]
    allw = [db(rms(m[i:i + h])) for i in range(0, len(m) - h, h)]
    return spec, max(local) - min(local), float(np.median(allw)), float(np.percentile(allw, 5))


def make_bed(folder, name, c):
    x = decode(folder, c["src"])
    parts = []
    for a, b in c["windows"]:
        w = x[int(a * SR):int(b * SR)]
        parts.append(w)
    target = np.mean([rms(p) for p in parts])
    parts = [p * (target / rms(p)) for p in parts]
    y = chain(parts, c["xf"]) if len(parts) > 1 else parts[0]
    if c.get("comp"):
        y = compress(y, *c["comp"])
    y = wrap_loop(y, c["xf"])
    y = fix_side(y)
    hp = c.get("hp", 30.0)
    y = filt(y, "highpass", hp)
    sh = c.get("shelf_db", 0.0)
    if sh:
        hi = filt(y, "highpass", 5000.0, 1)
        y = y + (10 ** (sh / 20.0) - 1.0) * hi
    if c.get("widen") and y.shape[1] == 1:
        y = widen(y)
    cur = lufs(y)
    y = y * 10 ** ((c["lufs"] - cur) / 20.0)
    y = soft_limit(y)
    return y


def make_thunder(folder, name, c):
    x = decode(folder, c["src"]).mean(axis=1)
    a, b = c["win"]
    y = x[int(a * SR):int(b * SR)]
    y = filt(y[:, None], "highpass", 28.0)[:, 0]
    low = filt(y[:, None], "lowpass", c["lp"], 4)[:, 0]
    sub = filt(y[:, None], "lowpass", 120.0, 4)[:, 0]
    # гармоники нижней части: динамик телефона не играет ниже 150 Гц
    harm = np.tanh(3.0 * sub / (rms(sub) + 1e-9))
    harm = signal.sosfiltfilt(signal.butter(2, [160.0, 520.0], btype="bandpass", fs=SR, output="sos"), harm)
    y = low + 0.35 * rms(sub) * harm / (rms(harm) + 1e-9)
    n_in = int(0.12 * SR)
    n_out = int(c["tail"] * SR)
    env = np.ones(len(y))
    env[:n_in] = np.linspace(0.0, 1.0, n_in) ** 1.5
    env[-n_out:] = np.cos(np.linspace(0.0, np.pi / 2.0, n_out)) ** 2
    y = y * env
    y = y / (np.max(np.abs(y)) + 1e-9) * 0.79   # пик -2 dBFS
    return y[:, None]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=str(DST), help="куда писать ogg (по умолчанию game/assets/sfx)")
    a = ap.parse_args()
    only = set(v for v in a.only.split(",") if v)
    out = {}
    for name, c in BEDS.items():
        if only and name not in only:
            continue
        y = make_bed(a.folder, name, c)
        spec, jump, med, p5 = seam_report(y, c["xf"])
        out[name] = y
        print("%-16s %6.1f с %d кан  LUFS %6.1f  пик %5.1f  шов: спектр %.2f дБ, скачок уровня %.2f дБ  (медиана %.1f, 5%% %.1f)"
              % (name, len(y) / SR, y.shape[1], lufs(y), db(float(np.max(np.abs(y)))), spec, jump, med, p5))
    for name, c in THUNDER.items():
        if only and name not in only:
            continue
        y = make_thunder(a.folder, name, c)
        out[name] = y
        print("%-16s %6.1f с  пик %5.1f  rms %5.1f дБ" % (name, len(y) / SR, db(float(np.max(np.abs(y)))), db(rms(y))))
    if a.report:
        return
    for name, y in out.items():
        dst = pathlib.Path(a.out) / (name + ".ogg")
        encode(y, dst, 3)
        print("записан", dst, dst.stat().st_size // 1024, "КБ")


if __name__ == "__main__":
    main()
