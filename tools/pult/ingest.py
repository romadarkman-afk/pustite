#!/usr/bin/env python3
"""Разбор файлов, которые Влади сделал по промптам «Пульта»: картинки, песни, музыка, озвучка.

Запуск из корня репозитория:
  python3 tools/pult/ingest.py ПАПКА            разобрать всё, что нашлось в папке (рекурсивно)
  python3 tools/pult/ingest.py ПАПКА --dry      только показать, что куда пойдёт
  python3 tools/pult/ingest.py ПАПКА --only frames1,voice
  python3 tools/pult/ingest.py --status         сколько из 551 задач уже готово

Файл находится по имени из поля «Сохранить как» (расширение любое: png, jpg, webp для картинок;
wav, mp3, m4a, ogg, flac для звука). Куда что идёт:
  кадры комикса      game/assets/slides/<колода>/<NN>.webp  (3:2 или 2:3, WebP, импорт с потерями)
  листы героев, места, образы   art/refs/<имя>.webp        (в игру не попадают)
  портреты           art/portraits/<герой>.webp
  песни и музыка     game/assets/music/<имя>.ogg           (музыка зациклена кроссфейдом, громкость -16 LUFS)
  озвучка рассказчика и реплик   game/assets/voice/<колода>/<кадр>_<строка>.ogg  (файл режется по паузам)
  возгласы           game/assets/voice/bark/<тип>_<настроение>_<k>.ogg
Песню или музыкальный трек можно прислать кусками: song_mill_1, song_mill_2 и так далее склеиваются по порядку номеров.
Код возврата 1, если хоть один файл не принят.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT / "game"
ART = ROOT / "art"
VOICE_SR = 24000
MUSIC_SR = 44100
TARGET_LUFS = -16.0
IMG_EXT = {".png", ".jpg", ".jpeg", ".webp"}
AUD_EXT = {".wav", ".mp3", ".m4a", ".ogg", ".flac", ".aac", ".opus"}
PAUSE_TOKEN = "<short pause>"

FRAME_SIZE = {"широкая": (1536, 1024), "высокая": (1024, 1536)}


# ----------------------------------------------------------------- данные пульта

def load_tasks():
    out = pathlib.Path(tempfile.mkdtemp()) / "pult_data.json"
    subprocess.run([sys.executable, str(HERE / "build.py"), str(out)], check=True, capture_output=True)
    return json.loads(out.read_text(encoding="utf-8"))["tasks"]


def phrase_count(t):
    """Сколько фраз в озвучке: по числу пауз в промпте."""
    return t["prompt"].count(PAUSE_TOKEN) // 2 + 1


def voice_key_path(key):
    parts = key.split(".")
    return GAME / "assets" / "voice" / parts[1] / ("_".join(parts[2:]) + ".ogg")


def dests(t):
    g = t["g"]
    stem = pathlib.Path(t["save"]).stem
    if g in ("frames1", "frames2"):
        return [GAME / "assets" / "slides" / t["deck"] / (t["id"].rsplit("_", 1)[1] + ".webp")]
    if g in ("heroes", "places", "looks"):
        return [ART / "refs" / (stem + ".webp")]
    if g == "portraits":
        return [ART / "portraits" / (t["id"][len("portrait_"):] + ".webp")]
    if g in ("songs", "music"):
        return [GAME / "assets" / "music" / (stem + ".ogg")]
    if g == "voice":
        if t["id"].startswith("bark_"):
            return [GAME / "assets" / "voice" / "bark" / ("%s_%d.ogg" % (t["id"][5:], k)) for k in range(phrase_count(t))]
        return [voice_key_path(k) for k in t["keys"]]
    return []


def norm_stem(name):
    s = pathlib.Path(name).stem.lower().strip().replace(" ", "_")
    return re.sub(r"(_?\(\d+\))$", "", s)


def index_files(folder):
    found = {}
    for p in sorted(folder.rglob("*"), key=lambda q: q.stat().st_mtime if q.is_file() else 0):
        if p.is_file() and p.suffix.lower() in IMG_EXT | AUD_EXT:
            found[norm_stem(p.name)] = p     # новее перезаписывает старее
    return found


def parts_of(files, stem):
    """Куски одной дорожки: stem_1, stem_2, ... по порядку номеров. Пусто, если кусков нет."""
    out = []
    k = 1
    while (stem + "_" + str(k)) in files:
        out.append(files[stem + "_" + str(k)])
        k += 1
    return out


# ----------------------------------------------------------------- картинки

def load_image(src):
    im = Image.open(src)
    im.load()
    if im.mode in ("RGBA", "LA", "P"):
        bg = Image.new("RGB", im.size, (0, 0, 0))
        im = im.convert("RGBA")
        bg.paste(im, mask=im.split()[-1])
        return bg
    return im.convert("RGB")


def crop_to(im, ratio):
    w, h = im.size
    if w / h > ratio:
        nw = int(round(h * ratio))
        x = (w - nw) // 2
        return im.crop((x, 0, x + nw, h))
    nh = int(round(w / ratio))
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh))


def check_image(im, want):
    w, h = im.size
    problems = []
    if max(w, h) < 900:
        problems.append("мало пикселей: %d×%d, нужно длинная сторона от 900" % (w, h))
    a = np.asarray(im.resize((64, 64)), dtype=np.float32)
    if a.std() < 6.0:
        problems.append("кадр почти однотонный")
    tall = h > w
    if want and tall != (want == "высокая"):
        problems.append("%d×%d, а нужен %s кадр" % (w, h, want))
    return problems


IMPORT_LOSSY = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://%s"

[params]

compress/mode=1
compress/high_quality=false
compress/lossy_quality=%.2f
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
process/fix_alpha_border=false
process/premult_alpha=false
process/size_limit=0
detect_3d/compress_to=0
"""


def write_import(path, quality=0.8):
    rel = path.relative_to(GAME).as_posix()
    imp = path.with_name(path.name + ".import")
    imp.write_text(IMPORT_LOSSY % (rel, quality), encoding="utf-8")


def do_frame(t, src, dry):
    want = t["shape"]
    im = load_image(src)
    problems = check_image(im, want)
    if problems:
        return None, problems
    tw, th = FRAME_SIZE[want]
    im = crop_to(im, tw / th)
    if im.size[0] > tw:
        im = im.resize((tw, th), Image.LANCZOS)
    dst = dests(t)[0]
    if not dry:
        dst.parent.mkdir(parents=True, exist_ok=True)
        im.save(dst, "WEBP", quality=84, method=6)
        write_import(dst)
    return [dst], []


def do_ref(t, src, dry, long_edge=1536, quality=86):
    im = load_image(src)
    problems = check_image(im, None)
    if problems:
        return None, problems
    w, h = im.size
    k = min(1.0, long_edge / max(w, h))
    if k < 1.0:
        im = im.resize((int(w * k), int(h * k)), Image.LANCZOS)
    dst = dests(t)[0]
    if not dry:
        dst.parent.mkdir(parents=True, exist_ok=True)
        im.save(dst, "WEBP", quality=quality, method=6)
    return [dst], []


# ----------------------------------------------------------------- звук

def decode(src, sr, channels):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(src), "-f", "f32le", "-ac", str(channels), "-ar", str(sr), "-"],
                         capture_output=True)
    if raw.returncode != 0 or not raw.stdout:
        raise RuntimeError("ffmpeg не прочитал файл: " + raw.stderr.decode("utf-8", "replace")[:200])
    x = np.frombuffer(raw.stdout, dtype=np.float32)
    return x.reshape(-1, channels) if channels > 1 else x


def encode_ogg(x, sr, dst, quality):
    """x: float32, моно (n) или стерео (n, 2)."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    ch = 1 if x.ndim == 1 else x.shape[1]
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name
    with wave.open(tmp_path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    r = subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp_path, "-c:a", "libvorbis", "-q:a", str(quality), str(dst)],
                       capture_output=True)
    pathlib.Path(tmp_path).unlink(missing_ok=True)
    if r.returncode != 0:
        raise RuntimeError("не закодировался ogg: " + r.stderr.decode("utf-8", "replace")[:200])


def lufs_of(x, sr):
    ch = 1 if x.ndim == 1 else x.shape[1]
    r = subprocess.run(["ffmpeg", "-nostats", "-f", "f32le", "-ar", str(sr), "-ac", str(ch), "-i", "-", "-af", "ebur128", "-f", "null", "-"],
                       input=x.astype("<f4").tobytes(), capture_output=True)
    m = re.findall(r"I:\s+(-?\d+\.\d+) LUFS", r.stderr.decode("utf-8", "replace"))
    return float(m[-1]) if m else None


def to_lufs(x, sr, target):
    cur = lufs_of(x, sr)
    if cur is None or cur < -60:
        return x, None
    g = 10 ** ((target - cur) / 20.0)
    y = x * g
    peak = float(np.abs(y).max())
    if peak > 0.97:                 # мягко не даём вылезти за 0 дБ
        y = np.tanh(y / peak * 1.2) / np.tanh(1.2) * 0.97
    return y, cur


def loop_crossfade(x, sr, sec):
    """Конец подмешивается в начало: после последнего отсчёта идёт первый без щелчка."""
    n = int(sr * sec)
    if len(x) < n * 4:
        return x
    head = x[:len(x) - n].copy()
    tail = x[len(x) - n:]
    w = np.linspace(0.0, 1.0, n, dtype=np.float32)
    if x.ndim == 2:
        w = w[:, None]
    head[:n] = head[:n] * w + tail * (1.0 - w)
    return head


def fade(x, sr, inn, out):
    y = x.copy()
    a = int(sr * inn)
    b = int(sr * out)
    if a > 0:
        w = np.linspace(0.0, 1.0, a, dtype=np.float32)
        y[:a] = y[:a] * (w[:, None] if y.ndim == 2 else w)
    if b > 0:
        w = np.linspace(1.0, 0.0, b, dtype=np.float32)
        y[-b:] = y[-b:] * (w[:, None] if y.ndim == 2 else w)
    return y


def stitch(xs, sr, sec=0.5):
    """Куски дорожки встык с коротким кроссфейдом, чтобы не было щелчка."""
    n = int(sr * sec)
    out = xs[0]
    for nxt in xs[1:]:
        if len(out) < n * 2 or len(nxt) < n * 2:
            out = np.concatenate([out, nxt])
            continue
        w = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
        mid = out[-n:] * (1.0 - w) + nxt[:n] * w
        out = np.concatenate([out[:-n], mid, nxt[n:]])
    return out


def trim_quiet(x, sr, head_db=12.0, tail_db=30.0, lead=0.4, tail_keep=0.6):
    """Песни Lyria начинаются секунд десять почти тишиной (-35 дБ и тише). В меню это значит «музыки нет».
    Начало обрезается там, где уровень впервые поднимается к верхнему (85-й процентиль окон по 0,25 с минус head_db).
    Хвост обрезается там, где затухание ниже верхнего уровня на tail_db."""
    mono = x.mean(axis=1) if x.ndim == 2 else x
    win = int(sr * 0.25)
    frames = len(mono) // win
    if frames < 8:
        return x
    rms = np.sqrt((mono[:frames * win].reshape(frames, win) ** 2).mean(axis=1)) + 1e-9
    db = 20 * np.log10(rms)
    ref = float(np.percentile(db, 85))
    loud = np.where(db > ref - head_db)[0]
    if len(loud) == 0:
        return x
    a = max(0, int(loud[0] * win - lead * sr))
    live = np.where(db > ref - tail_db)[0]
    b = min(len(x), int((live[-1] + 1) * win + tail_keep * sr))
    return x[a:b] if b - a > sr * 30 else x


def do_music(t, src, dry):
    srcs = src if isinstance(src, list) else [src]
    x = stitch([decode(p, MUSIC_SR, 2) for p in srcs], MUSIC_SR)
    sec = len(x) / MUSIC_SR
    problems = []
    song = t["g"] == "songs"
    if song and sec < 60:
        problems.append("песня %.0f с, ждали от 60" % sec)
    if not song and sec < 25:
        problems.append("трек %.0f с, ждали от 25 (лучше 60-90)" % sec)
    if sec > 600:
        problems.append("длиннее 10 минут")
    if problems:
        return None, problems
    if song:
        x = trim_quiet(x, MUSIC_SR)
        x = fade(x, MUSIC_SR, 0.35, 2.5)
    else:
        x = loop_crossfade(x, MUSIC_SR, min(4.0, sec * 0.1))
    x, cur = to_lufs(x, MUSIC_SR, TARGET_LUFS)
    dst = dests(t)[0]
    if not dry:
        encode_ogg(x, MUSIC_SR, dst, 5)
    return [dst], []


def segments(x, sr, n):
    """Режет озвучку на n фраз по тишине. Подбирает порог и длину паузы, при которых фраз ровно n."""
    hop = int(sr * 0.01)
    frames = len(x) // hop
    rms = np.sqrt((x[:frames * hop].reshape(frames, hop) ** 2).mean(axis=1))
    loud = float(np.percentile(rms, 95)) if frames else 0.0
    if loud < 1e-4:
        return None
    good = []
    for rel in (0.02, 0.035, 0.06, 0.1):
        thr = loud * rel
        active = rms > thr
        regs = []
        i = 0
        while i < frames:
            if active[i]:
                j = i
                while j < frames and active[j]:
                    j += 1
                regs.append([i, j])
                i = j
            else:
                i += 1
        for gap in np.arange(1.0, 0.18, -0.05):
            gf = int(gap * 100)
            merged = []
            for r in regs:
                if merged and r[0] - merged[-1][1] < gf:
                    merged[-1][1] = r[1]
                else:
                    merged.append(list(r))
            merged = [m for m in merged if m[1] - m[0] >= 8]
            if len(merged) == n:
                good.append((rel, gap, merged))
    if not good:
        return None
    rel, gap, merged = good[len(good) // 2]
    return [(m[0] * hop, m[1] * hop) for m in merged]


def finish_clip(x, sr, target_rms_db):
    """Тишина по краям, плавные края, уровень речи около target_rms_db dBFS."""
    pad_a = np.zeros(int(sr * 0.06), dtype=np.float32)
    pad_b = np.zeros(int(sr * 0.16), dtype=np.float32)
    rms = float(np.sqrt((x ** 2).mean()) + 1e-9)
    g = 10 ** (target_rms_db / 20.0) / rms
    peak = float(np.abs(x).max() * g)
    if peak > 0.95:
        g *= 0.95 / peak
    y = fade(x * g, sr, 0.008, 0.02)
    return np.concatenate([pad_a, y, pad_b])


def do_voice(t, src, dry):
    x = decode(src, VOICE_SR, 1)
    n = phrase_count(t)
    outs = dests(t)
    bark = t["id"].startswith("bark_")
    level = -19.0 if bark else -21.0
    if n == 1:
        segs = [(0, len(x))]
        act = np.abs(x) > max(0.01, float(np.abs(x).max()) * 0.03)
        idx = np.nonzero(act)[0]
        if len(idx) == 0:
            return None, ["файл тихий"]
        segs = [(int(idx[0]), int(idx[-1]) + 1)]
    else:
        segs = segments(x, VOICE_SR, n)
        if segs is None:
            return None, ["не нашёл %d фраз по паузам (проверь, что фразы разделены паузами, и сгенерируй заново)" % n]
    clips = [finish_clip(x[a:b], VOICE_SR, level) for a, b in segs]
    for c, k in zip(clips, range(n)):
        if len(c) / VOICE_SR > (6.0 if bark else 40.0):
            return None, ["фраза %d длится %.0f с, похоже на склейку" % (k + 1, len(c) / VOICE_SR)]
    if not dry:
        for c, dst in zip(clips, outs):
            encode_ogg(c, VOICE_SR, dst, 4)
    return outs, []


HANDLERS = {
    "frames1": do_frame, "frames2": do_frame,
    "heroes": do_ref, "places": do_ref, "looks": do_ref, "portraits": lambda t, s, d: do_ref(t, s, d, 1536, 88),
    "songs": do_music, "music": do_music, "voice": do_voice,
}


# ----------------------------------------------------------------- запуск

LEDGER = HERE / "ingested.json"


def ledger():
    return set(json.loads(LEDGER.read_text(encoding="utf-8"))) if LEDGER.exists() else set()


def ledger_add(ids):
    LEDGER.write_text(json.dumps(sorted(ledger() | set(ids)), ensure_ascii=False, indent=0), encoding="utf-8")


def status(tasks):
    total = {}
    done = {}
    mine = ledger()
    for t in tasks:
        d = dests(t)
        total[t["g"]] = total.get(t["g"], 0) + 1
        if t["id"] in mine and d and all(p.exists() for p in d):
            done[t["g"]] = done.get(t["g"], 0) + 1
    print("%-10s %6s / %-6s" % ("группа", "готово", "всего"))
    for g in total:
        print("%-10s %6d / %-6d" % (g, done.get(g, 0), total[g]))
    print("%-10s %6d / %-6d" % ("всего", sum(done.values()), sum(total.values())))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder", nargs="?")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--status", action="store_true")
    a = ap.parse_args()
    tasks = load_tasks()
    if a.status or not a.folder:
        status(tasks)
        return 0
    folder = pathlib.Path(a.folder)
    files = index_files(folder)
    only = set(x for x in a.only.split(",") if x)
    known = set()
    done = failed = 0
    problems = []
    ok_ids = []
    for t in tasks:
        if only and t["g"] not in only:
            continue
        stem = norm_stem(t["save"])
        known.add(stem)
        src = files.get(stem)
        if t["g"] in ("songs", "music"):
            parts = parts_of(files, stem)
            if src is None and parts:
                src = parts
                known.update(stem + "_" + str(k + 1) for k in range(len(parts)))
        if src is None:
            continue
        try:
            outs, bad = HANDLERS[t["g"]](t, src, a.dry)
        except Exception as e:      # битый файл: сообщаем и идём дальше
            outs, bad = None, [str(e)]
        if bad:
            failed += 1
            problems.append((t["save"], "; ".join(bad)))
            print("✗ %s: %s" % (t["save"], "; ".join(bad)))
        else:
            done += 1
            ok_ids.append(t["id"])
            print("✓ %s -> %s%s" % (t["save"], outs[0].relative_to(ROOT), " (+%d)" % (len(outs) - 1) if len(outs) > 1 else ""))
    extra = sorted(s for s in files if s not in known)
    if extra:
        print("Не нашёл в пульте (проверь имена): " + ", ".join(extra[:40]) + (" …" if len(extra) > 40 else ""))
    print("Принято %d, отклонено %d%s." % (done, failed, " (пробный запуск, файлы не записаны)" if a.dry else ""))
    if done and not a.dry:
        # *.import в .git/info/exclude: без -f настройки импорта кадров не попадают в коммит, и APK вырастает на 1,3 МиБ на кадр
        print("В коммит добавлять так: git add -A && git add -f $(find game/assets/slides -name '*.import')")
    if not a.dry:
        ledger_add(ok_ids)
        status(tasks)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
