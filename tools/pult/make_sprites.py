#!/usr/bin/env python3
"""Фигуры жителей, гостей и NPC для игры из листов героев (art/refs/cast_<id>.webp).

Запуск из корня репозитория:
  python3 tools/pult/make_sprites.py            все 24 героя
  python3 tools/pult/make_sprites.py ignat marina

С листа берётся фигура в полный рост (правая треть листа), фон убирает rembg (модель u2net, скачивается один раз).
Результат кладётся поверх прежних спрайтов того же имени (имена берутся из config/slides.json, раздел cast):
  game/assets/folk/realistic/<имя>.png   высота 640
  game/assets/folk/<имя>.png             высота как у прежнего спрайта (около 260), для фигур на карте
Прежние спрайты остаются в git.
"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
SHEETS = ROOT / "art" / "refs"
BIG = GAME / "assets" / "folk" / "realistic"
SMALL = GAME / "assets" / "folk"
BIG_H = 640

def load_cast_map():
    d = json.loads((GAME / "config" / "slides.json").read_text(encoding="utf-8"))
    return d["cast"]


def tallest_component(alpha, thr=40):
    """Фигура в полный рост: самая высокая связная область, а не самая большая (соседний портрет бывает крупнее)."""
    mask = alpha > thr
    lab, n = ndimage.label(mask)
    if n == 0:
        return mask
    best, best_h, best_area = 0, -1, -1
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        h = sl[0].stop - sl[0].start
        area = int((lab[sl] == i).sum())
        if area < 2000:
            continue
        if h > best_h or (h == best_h and area > best_area):
            best, best_h, best_area = i, h, area
    return lab == best


def cut(sheet_path, name):
    from rembg import remove, new_session
    im = Image.open(sheet_path).convert("RGB")
    w, h = im.size
    x0 = int(w * 0.60)
    crop = im.crop((x0, 0, w, h))
    session = new_session("u2net")
    out = remove(crop, session=session)
    a = np.asarray(out.getchannel("A")).astype(np.uint8)
    keep = tallest_component(a)
    a2 = np.where(keep, a, 0).astype(np.uint8)
    ys, xs = np.nonzero(a2 > 40)
    box = (max(0, xs.min() - 2), max(0, ys.min() - 2), min(a2.shape[1], xs.max() + 3), min(a2.shape[0], ys.max() + 3))
    rgba = out.copy()
    rgba.putalpha(Image.fromarray(a2))
    rgba = rgba.crop(box)
    # серая кайма от фона: срезаем край на пиксель и смягчаем
    al = np.asarray(rgba.getchannel("A")).astype(np.float32)
    al = ndimage.grey_erosion(al, size=(3, 3))
    al = ndimage.gaussian_filter(al, 0.6)
    rgba.putalpha(Image.fromarray(np.clip(al, 0, 255).astype(np.uint8)))
    return rgba


def save_sprite(img, dst, height):
    w, h = img.size
    nw = max(8, int(round(w * height / h)))
    out = img.resize((nw, height), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, "PNG", optimize=True)
    return out.size


def small_height(sprite):
    p = SMALL / (sprite + ".png")
    if p.exists():
        return Image.open(p).size[1]
    return 260


def main():
    cast = load_cast_map()
    want = sys.argv[1:] or list(cast)
    for cid in want:
        sprite = cast[cid]
        sheet = SHEETS / ("cast_%s.webp" % cid)
        if not sheet.exists():
            print("нет листа", sheet.name)
            continue
        img = cut(sheet, cid)
        hs = small_height(sprite)           # до перезаписи большого
        sb = save_sprite(img, BIG / (sprite + ".png"), BIG_H)
        ss = save_sprite(img, SMALL / (sprite + ".png"), hs)
        print("%-14s -> %-18s %s и %s" % (cid, sprite, sb, ss))


if __name__ == "__main__":
    main()
