#!/usr/bin/env python3
"""Готовит иконки достижений: убирает пурпурный фон (#FF00FF), обрезает по краям,
вписывает в квадрат 256x256 и кладёт в game/assets/ui/ach/<id>.png.

Использование: python3 tools/prepare_ach_icons.py ПАПКА_С_КАРТИНКАМИ
Имя файла в папке (без расширения) должно совпадать с номером достижения, например oil.png, act3.jpg.
Список номеров: Progress.ACHIEVEMENTS в game/scripts/core/progress.gd и docs/art-prompts-achievements.md.
"""
import sys
from pathlib import Path
from PIL import Image

IDS = ["night1", "open_door", "closed_door", "instinct", "mistake", "mourning", "last_one", "debtor", "oil", "forest_call",
       "guest_secret", "three_stars", "act1", "act2", "dark_side", "whole_family", "act3", "act4", "saved_bond"]
OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "ui" / "ach"
SIZE = 256
PAD = 14


def key_magenta(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # близость к #FF00FF: сильный красный и синий, слабый зелёный
            d = min(r, b) - g
            if d > 120 and r > 150 and b > 150:
                px[x, y] = (r, g, b, 0)
            elif d > 70 and r > 120 and b > 120:
                # кромка: полупрозрачная и без пурпурного оттенка
                k = max(0.0, min(1.0, (120 - d) / 50.0))
                px[x, y] = (min(r, int(g + 40)), g, min(b, int(g + 40)), int(a * k))
    return im


def fit(im: Image.Image) -> Image.Image:
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    inner = SIZE - 2 * PAD
    scale = min(inner / im.width, inner / im.height)
    im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.paste(im, ((SIZE - im.width) // 2, (SIZE - im.height) // 2), im)
    return canvas


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 1
    src = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    done, missing = [], []
    for id_ in IDS:
        found = next((p for p in src.glob(id_ + ".*") if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")), None)
        if found is None:
            missing.append(id_)
            continue
        fit(key_magenta(Image.open(found))).save(OUT / f"{id_}.png")
        done.append(id_)
    print(f"готово {len(done)}: {' '.join(done)}")
    if missing:
        print(f"нет файлов для {len(missing)}: {' '.join(missing)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
