#!/usr/bin/env python3
"""Подготовка картинок для эффектов погоды из того, что нарисовал ChatGPT.

Нейросеть плохо держит прозрачность и ровную сетку. Поэтому просим рисовать спрайты на
однотонном фоне (чёрный для светлых и светящихся, зелёный #00FF00 или пурпурный #FF00FF для
цветных) в любом порядке, а этот
скрипт сам убирает фон, находит каждый спрайт и собирает ровный атлас.

Примеры:
  python3 tools/make_atlas.py sheet raw/leaves.png game/assets/weather/leaf_sheet.png --grid 4x2 --cell 128 --key green
  python3 tools/make_atlas.py sheet raw/embers.png game/assets/weather/ember_sheet.png --grid 4x2 --cell 64 --key black
  python3 tools/make_atlas.py strip raw/clouds.png game/assets/weather/clouds_day.png --size 2048x512 --key green
  python3 tools/make_atlas.py tile raw/snow.png game/assets/weather/snow_ground.jpg --size 1024x1024
"""
import argparse
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def key_alpha(img: Image.Image, key: str, tol: float, soft: float) -> Image.Image:
    """Фон в прозрачность. Цвет фона: green, magenta, black, white или auto (по углам картинки)."""
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    if key == "green":
        bg = np.array([0, 255, 0], np.float32)
    elif key == "black":
        bg = np.array([0, 0, 0], np.float32)
    elif key == "white":
        bg = np.array([255, 255, 255], np.float32)
    elif key == "magenta":
        bg = np.array([255, 0, 255], np.float32)
    else:
        h, w, _ = rgb.shape
        corners = np.array([rgb[0, 0], rgb[0, w - 1], rgb[h - 1, 0], rgb[h - 1, w - 1]])
        bg = np.median(corners, axis=0)
    dist = np.linalg.norm(rgb - bg, axis=2)
    alpha = np.clip((dist - tol) / max(soft, 1.0), 0.0, 1.0)
    if key == "black":
        # светящиеся спрайты на чёрном: яркость и есть прозрачность, цвет не трогаем
        lum = rgb.max(axis=2) / 255.0
        alpha = np.clip(lum * 1.6, 0.0, 1.0)
        out = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
        return Image.fromarray(out, "RGBA")
    if key == "green":
        # убрать зелёную кайму на краях: там, где фон просвечивает, зелёный канал не выше красного и синего
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        spill = np.clip(g - np.maximum(r, b), 0.0, None)
        edge = (alpha > 0.0) & (alpha < 1.0)
        g2 = np.where(edge, g - spill, g)
        rgb = np.dstack([r, g2, b])
    if key == "magenta":
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        spill = np.clip(np.minimum(r, b) - g, 0.0, None)
        edge = (alpha > 0.0) & (alpha < 1.0)
        rgb = np.dstack([np.where(edge, r - spill, r), g, np.where(edge, b - spill, b)])
    out = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def sprites(img: Image.Image, min_area: int):
    """Каждый связный кусок непрозрачного: рамка и картинка."""
    a = np.asarray(img)[..., 3] > 24
    a = ndimage.binary_dilation(a, iterations=3)       # соединяем части одного спрайта
    labels, count = ndimage.label(a)
    boxes = ndimage.find_objects(labels)
    found = []
    for i, sl in enumerate(boxes):
        area = int((labels[sl] == i + 1).sum())
        if area < min_area:
            continue
        y, x = sl
        found.append((y.start, x.start, y.stop, x.stop))
    found.sort(key=lambda b: (round(b[0] / 80), b[1]))        # слева направо, сверху вниз
    return [img.crop((b[1], b[0], b[3], b[2])) for b in found]


def fit(sprite: Image.Image, cell: int) -> Image.Image:
    """Спрайт в квадратную ячейку, по центру, с отступом в 6%."""
    pad = int(cell * 0.06)
    box = cell - 2 * pad
    scale = min(box / sprite.width, box / sprite.height)
    size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
    resized = sprite.resize(size, Image.LANCZOS)
    tile = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    tile.paste(resized, ((cell - size[0]) // 2, (cell - size[1]) // 2), resized)
    return tile


def cmd_sheet(a) -> int:
    cols, rows = (int(v) for v in a.grid.split("x"))
    img = key_alpha(Image.open(a.src), a.key, a.tol, a.soft)
    found = sprites(img, a.min_area)
    need = cols * rows
    if len(found) < need:
        print(f"найдено {len(found)} спрайтов, нужно {need}: нарисуйте ещё или уменьшите --grid", file=sys.stderr)
        if not found:
            return 1
    out = Image.new("RGBA", (cols * a.cell, rows * a.cell), (0, 0, 0, 0))
    for i in range(need):
        tile = fit(found[i % len(found)], a.cell)       # не хватило — повторяем с начала
        out.paste(tile, ((i % cols) * a.cell, (i // cols) * a.cell))
    out.save(a.dst)
    print(f"{a.dst}: {cols}x{rows} по {a.cell} px, найдено спрайтов {len(found)}")
    return 0


def cmd_strip(a) -> int:
    """Полоса, которая бесшовно повторяется по горизонтали (облака, туман)."""
    w, h = (int(v) for v in a.size.split("x"))
    img = key_alpha(Image.open(a.src), a.key, a.tol, a.soft) if a.key != "none" else Image.open(a.src).convert("RGBA")
    img = img.resize((w, h), Image.LANCZOS)
    arr = np.asarray(img).astype(np.float32)
    shifted = np.roll(arr, w // 2, axis=1)
    xx = np.arange(w, dtype=np.float32)
    wx = 1.0 - np.abs(xx / (w - 1) * 2.0 - 1.0)
    mask = np.clip(wx / max(a.blend * 2.0, 0.01), 0.0, 1.0)[None, :, None]
    out = arr * mask + shifted * (1.0 - mask)
    Image.fromarray(out.astype(np.uint8), "RGBA").save(a.dst)
    print(f"{a.dst}: {w}x{h}, шов сведён на {int(w * a.blend)} px с каждой стороны")
    return 0


def cmd_tile(a) -> int:
    """Плитка без шва по обеим осям: сдвиг на половину и плавное сведение крестом."""
    w, h = (int(v) for v in a.size.split("x"))
    img = Image.open(a.src).convert("RGB").resize((w, h), Image.LANCZOS)
    arr = np.asarray(img).astype(np.float32)
    shifted = np.roll(np.roll(arr, w // 2, axis=1), h // 2, axis=0)
    yy, xx = np.mgrid[0:h, 0:w]
    wx = 1.0 - np.abs(xx / (w - 1) * 2.0 - 1.0)
    wy = 1.0 - np.abs(yy / (h - 1) * 2.0 - 1.0)
    mask = np.clip(np.minimum(wx, wy) * 2.2, 0.0, 1.0)[..., None]
    out = arr * mask + shifted * (1.0 - mask)
    Image.fromarray(out.astype(np.uint8), "RGB").save(a.dst, quality=90)
    print(f"{a.dst}: {w}x{h}, шов сведён")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("sheet", help="спрайты на однотонном фоне в ровный атлас")
    s.add_argument("src")
    s.add_argument("dst")
    s.add_argument("--grid", default="4x2")
    s.add_argument("--cell", type=int, default=128)
    s.add_argument("--key", default="green", choices=["green", "magenta", "black", "white", "auto"])
    s.add_argument("--tol", type=float, default=90.0)
    s.add_argument("--soft", type=float, default=60.0)
    s.add_argument("--min-area", type=int, default=400)
    s.set_defaults(fn=cmd_sheet)
    t = sub.add_parser("strip", help="полоса без шва по горизонтали")
    t.add_argument("src")
    t.add_argument("dst")
    t.add_argument("--size", default="2048x512")
    t.add_argument("--key", default="none", choices=["green", "magenta", "black", "white", "auto", "none"])
    t.add_argument("--tol", type=float, default=90.0)
    t.add_argument("--soft", type=float, default=60.0)
    t.add_argument("--blend", type=float, default=0.15)
    t.set_defaults(fn=cmd_strip)
    u = sub.add_parser("tile", help="плитка без шва")
    u.add_argument("src")
    u.add_argument("dst")
    u.add_argument("--size", default="1024x1024")
    u.set_defaults(fn=cmd_tile)
    a = p.parse_args()
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
