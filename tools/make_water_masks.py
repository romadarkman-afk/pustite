#!/usr/bin/env python3
"""Маски воды для карт: белое там, где на земле нарисована река.

Нужны проверке расстановки (дома не стоят на воде) и эффектам у воды.
Маски делаются по картинкам земли из assets/village/realistic: вода холоднее берега
(синего больше, чем красного). Для карты с тёплым закатным светом вода обведена вручную.
Запуск из корня репозитория: python3 tools/make_water_masks.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

SRC = os.path.join("game", "assets", "village", "realistic")
OUT = os.path.join("game", "assets", "village")
# имя земли в VillageDef -> файл картинки, рамка земли на поле посёлка (x, y, w, h)
MAPS = {
    "ground": ("ground_day.jpg", (-88.8, 31.6, 816.0, 609.3)),
    "ground_mill": ("ground_mill_day.jpg", (-55.3, 57.4, 816.0, 609.3)),
    "ground_monastery": ("ground_monastery_day.jpg", (-50.0, 20.0, 819.2, 612.0)),
    "ground_station": ("ground_station_day.jpg", (-88.8, 31.6, 816.0, 609.3)),
}
# вода, обведённая вручную (координаты поля посёлка): у закатной карты берег тёплый
MANUAL = {
    "ground": [
        [(-30, 60), (0, 66), (27, 70), (44, 85), (48, 97), (32, 101), (14, 104), (0, 126), (-30, 130)],
        [(-30, 190), (0, 191), (23, 199), (43, 215), (41, 228), (27, 240), (23, 254), (11, 278), (7, 286), (0, 294), (-30, 300)],
    ],
}
SCALE = 4


def auto_mask(path: str) -> np.ndarray:
    im = Image.open(path).convert("RGB")
    im = im.resize((im.width // 3, im.height // 3)).filter(ImageFilter.GaussianBlur(1.5))
    a = np.asarray(im).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (b - r >= 6) & (r < 110) & (b >= g - 2)
    m = ndimage.binary_closing(m, iterations=3)
    m = ndimage.binary_opening(m, iterations=2)
    lab, n = ndimage.label(m)
    keep = np.zeros_like(m)
    for i in range(1, n + 1):
        c = lab == i
        ys, xs = np.nonzero(c)
        # настоящая река крупная и упирается в край картинки; лужи на камнях отсекаем
        if c.sum() > 400 and (xs.min() <= 10 or ys.max() >= m.shape[0] - 10):
            keep |= c
    return ndimage.binary_fill_holes(keep)


def main() -> None:
    for name, (file, gr) in MAPS.items():
        w, h = int(gr[2] / SCALE * 2), int(gr[3] / SCALE * 2)
        if name in MANUAL:
            im = Image.new("L", (w, h), 0)
            d = ImageDraw.Draw(im)
            for poly in MANUAL[name]:
                d.polygon([((x - gr[0]) / gr[2] * w, (y - gr[1]) / gr[3] * h) for x, y in poly], fill=255)
            mask = np.asarray(im) > 128
        else:
            m = auto_mask(os.path.join(SRC, file))
            mask = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((w, h))) > 128
        out = os.path.join(OUT, "water_%s.png" % name)
        if mask.any():
            Image.fromarray((mask * 255).astype(np.uint8)).save(out)
            print("OK", out, w, "x", h, "вода %.1f%%" % (mask.mean() * 100))
        elif os.path.exists(out):
            os.remove(out)


if __name__ == "__main__":
    main()
