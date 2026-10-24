#!/usr/bin/env python3
"""Сверка дневной и ночной картинок: здание не должно сдвигаться при смене фазы.

Для PNG с прозрачностью берётся маска (альфа выше 32) и сравнивается XOR масок к их объединению.
Для JPG земли маски нет: берутся контуры (сильные перепады яркости), и дневные и ночные
контуры сравниваются с допуском 2 пикселя. Размеры картинок должны совпасть до пикселя.

Запуск из корня репозитория:
  python3 tools/check_pair.py                        все пары в game/assets/village
  python3 tools/check_pair.py day.png night.png      одна пара
  python3 tools/check_pair.py --max 3 --ground 12    допуски в процентах (здание 3, земля 12)
Код возврата 1, если хоть одна пара вышла за допуск или размеры разные.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join("game", "assets", "village")
EXT = (".png", ".jpg", ".jpeg")


def load(path):
    return Image.open(path)


def alpha_mask(im):
    return np.asarray(im.convert("RGBA").split()[3]) > 32


def edge_mask(im):
    """Контуры земли: верхние 8% перепадов яркости на уменьшенной до 256 px картинке."""
    g = im.convert("L")
    w = 256
    g = g.resize((w, max(1, round(g.height * w / g.width))), Image.BILINEAR)
    a = np.asarray(g, dtype=np.float32)
    a = (a - a.mean()) / (a.std() + 1e-6)          # яркость ночи выравниваем под день
    gx = ndimage.sobel(a, axis=1)
    gy = ndimage.sobel(a, axis=0)
    mag = np.hypot(gx, gy)
    return mag > np.percentile(mag, 92)


def shift_px(d, n):
    """Сдвиг ночи относительно дня в пикселях оригинала (фазовая корреляция по яркости, 256 px по ширине)."""
    w = 256
    def prep(im):
        g = im.convert("L")
        g = g.resize((w, max(1, round(g.height * w / g.width))), Image.BILINEAR)
        a = np.asarray(g, dtype=np.float32)
        return (a - a.mean()) / (a.std() + 1e-6)
    a, b = prep(d), prep(n)
    fa, fb = np.fft.fft2(a), np.fft.fft2(b)
    r = fa * np.conj(fb)
    r /= np.abs(r) + 1e-9
    corr = np.fft.ifft2(r).real
    y, x = np.unravel_index(np.argmax(corr), corr.shape)
    if y > a.shape[0] // 2:
        y -= a.shape[0]
    if x > a.shape[1] // 2:
        x -= a.shape[1]
    k = d.width / w
    return x * k, y * k


SHIFT_MAX = 12.0     # px оригинала: больше сдвиг земли между днём и ночью заметен глазом


def compare(day_path, night_path):
    """-> (расхождение в процентах, пояснение, считается ли картинка землёй)."""
    d, n = load(day_path), load(night_path)
    if d.size != n.size:
        return 100.0, "размеры разные: %s и %s" % (d.size, n.size), False
    ground = d.mode == "RGB" and n.mode == "RGB"
    if ground:
        a, b = edge_mask(d), edge_mask(n)
        # допуск 2 px: контур ночи считается совпавшим, если рядом есть контур дня
        da = ndimage.binary_dilation(a, iterations=2)
        db = ndimage.binary_dilation(b, iterations=2)
        miss = (a & ~db).sum() + (b & ~da).sum()
        total = max(1, a.sum() + b.sum())
        sx, sy = shift_px(d, n)
        shifted = max(abs(sx), abs(sy)) > SHIFT_MAX
        note = "контуры земли, сдвиг ночи (%+.0f, %+.0f) px%s" % (sx, sy, " СДВИНУТА" if shifted else "")
        return (100.0 if shifted else 100.0 * miss / total), note, True
    a, b = alpha_mask(d), alpha_mask(n)
    union = max(1, (a | b).sum())
    return 100.0 * (a ^ b).sum() / union, "маска здания", False


# небо и кромка леса: ночные картинки другого размера по замыслу, к зданиям не относятся
SKIP = ("sky_", "treeline_")


def find_pairs(root):
    """Пары день-ночь. Если рядом в realistic/ лежит такая же пара, старая не используется игрой и не проверяется."""
    pairs = []
    for folder, _, files in os.walk(root):
        names = set(files)
        for f in sorted(files):
            base, ext = os.path.splitext(f)
            if ext.lower() not in EXT or not base.endswith("_day") or base.startswith(SKIP):
                continue
            stem = base[:-4]
            for e2 in EXT:
                night = stem + "_night" + e2
                if night in names:
                    rel = os.path.relpath(folder, root)
                    shadow = os.path.join(root, "realistic", rel, f) if not rel.startswith("realistic") else ""
                    if shadow and rel != "." and os.path.exists(shadow):
                        break
                    if rel == "." and os.path.exists(os.path.join(root, "realistic", f)):
                        break
                    pairs.append((os.path.join(folder, f), os.path.join(folder, night)))
                    break
    return sorted(pairs)


def missing_nights(root):
    """Здания realistic/maps с дневной картинкой, у которых нет ночной: ночью они темнеют и теплеют программно."""
    out = []
    folder = os.path.join(root, "realistic", "maps")
    if not os.path.isdir(folder):
        return out
    for f in sorted(os.listdir(folder)):
        if f.endswith("_day.png") and not os.path.exists(os.path.join(folder, f[:-8] + "_night.png")):
            out.append(f[:-8])
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", help="день.png ночь.png; без аргументов проверяются все пары")
    ap.add_argument("--max", type=float, default=3.0, help="допуск для зданий, %% (по умолчанию 3)")
    ap.add_argument("--ground", type=float, default=100.0, help="допуск для земли, %% (по умолчанию не проверяется)")
    ap.add_argument("--root", default=ROOT)
    args = ap.parse_args()
    if args.files:
        if len(args.files) != 2:
            ap.error("нужны ровно два файла: день и ночь")
        pairs = [(args.files[0], args.files[1])]
    else:
        pairs = find_pairs(args.root)
    bad = 0
    for day, night in pairs:
        diff, what, ground = compare(day, night)
        limit = args.ground if ground else args.max
        flag = "ок " if diff <= limit else "ОШИБКА"
        bad += diff > limit
        print("%-6s %5.1f%% (до %.0f%%)  %s  %s" % (flag, diff, limit, what, os.path.relpath(day, args.root) if not args.files else day))
    print("пар: %d, вышли за допуск: %d" % (len(pairs), bad))
    if not args.files:
        miss = missing_nights(args.root)
        if miss:
            print("без ночной пары (realistic/maps, %d): %s" % (len(miss), ", ".join(miss)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
