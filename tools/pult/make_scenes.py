#!/usr/bin/env python3
"""Картинки глав и мест для игры из эталонов мест (art/refs/loc_<id>.webp).

Запуск из корня репозитория: python3 tools/pult/make_scenes.py
Каждый эталон 3:2 обрезается по центру до 16:9 и ложится в game/assets/scenes/<имя>.jpg (1280x720):
loc_a1c1..loc_a4c3 -> a1c1..a4c3.jpg, loc_river -> river.jpg. Их берут экран главы, сцены, фон меню и заглушки комиксов.
"""
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "art" / "refs"
DST = ROOT / "game" / "assets" / "scenes"
W, H = 1280, 720


def main():
    n = 0
    for p in sorted(SRC.glob("loc_*.webp")):
        name = p.stem[len("loc_"):]
        im = Image.open(p).convert("RGB")
        w, h = im.size
        nh = int(round(w * 9 / 16))
        y = int((h - nh) * 0.45)        # чуть выше центра: крыши и небо важнее земли
        im = im.crop((0, y, w, y + nh)).resize((W, H), Image.LANCZOS)
        out = DST / (name + ".jpg")
        im.save(out, "JPEG", quality=86, optimize=True, progressive=True)
        print("%-10s -> %s (%d КБ)" % (p.stem, out.relative_to(ROOT), out.stat().st_size // 1024))
        n += 1
    print("готово:", n)


if __name__ == "__main__":
    main()
