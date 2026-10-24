#!/usr/bin/env python3
"""Люк туннеля: дощатая крышка в земле с железными полосами и кольцом, мох по краю.

Заглушка до настоящей картинки (промпт в docs/art-prompts-map.md). Игра читает assets/village/hatch.png.
Запуск из корня репозитория: python3 tools/make_hatch.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

W, H = 192, 96
RNG = np.random.default_rng(31)


def noise(sigma: float, shape=(H, W)) -> np.ndarray:
    n = ndimage.gaussian_filter(RNG.random(shape).astype(np.float32), sigma)
    return (n - n.min()) / (n.max() - n.min() + 1e-6)


def main() -> None:
    img = np.zeros((H, W, 4), np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy = W / 2, H * 0.52
    # земля вокруг: тёмный влажный грунт, мягкий край
    ground = ((xx - cx) / 92.0) ** 2 + ((yy - cy) / 42.0) ** 2
    ground_a = np.clip(1.15 - ground, 0, 1) ** 0.8
    soil = 0.55 + 0.45 * noise(1.6)
    for c, v in enumerate((54, 42, 30)):
        img[..., c] = v * soil
    img[..., 3] = ground_a * 255

    # крышка: параллелограмм, доски вдоль длинной стороны
    lid = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(lid)
    poly = [(34, 30), (156, 30), (166, 70), (24, 70)]
    d.polygon(poly, fill=255)
    lid_m = np.asarray(lid.filter(ImageFilter.GaussianBlur(0.7))).astype(np.float32) / 255
    plank = np.clip((yy - 30) / 40.0, 0, 1)
    idx = np.floor(plank * 5)
    shade = 0.82 + 0.18 * np.sin(idx * 2.3 + 1.0)
    grain = noise(0.9, (H, W)) * 0.5 + ndimage.gaussian_filter(RNG.random((H, W)).astype(np.float32), (0.4, 7.0)) * 0.9
    grain = (grain - grain.min()) / (grain.max() - grain.min())
    gaps = (np.abs((plank * 5) - np.round(plank * 5)) < 0.045).astype(np.float32)
    base = np.array([112, 82, 54], np.float32)
    wood = base[None, None, :] * (shade * (0.62 + 0.55 * grain))[..., None]
    wood *= (1.0 - 0.7 * gaps)[..., None]
    # железные полосы
    for x0 in (62, 128):
        band = ((xx > x0 + (yy - 30) * 0.25) & (xx < x0 + 11 + (yy - 30) * 0.25) & (lid_m > 0.5)).astype(np.float32)
        iron = np.array([58, 60, 66], np.float32) * (0.8 + 0.4 * noise(1.2))[..., None]
        wood = wood * (1 - band[..., None]) + iron * band[..., None]
        for ry in (38, 62):
            rx = x0 + 5.5 + (ry - 30) * 0.25
            rr = ((xx - rx) ** 2 + (yy - ry) ** 2) < 2.6 ** 2
            wood[rr] = (96, 98, 104)
    # мох и грязь по краю крышки
    edge = np.clip(1.0 - ndimage.distance_transform_edt(lid_m > 0.5) / 7.0, 0, 1) * (lid_m > 0.5)
    moss = (noise(2.2) > 0.52).astype(np.float32) * edge
    wood = wood * (1 - 0.65 * moss[..., None]) + np.array([60, 78, 38], np.float32) * 0.65 * moss[..., None]
    for c in range(3):
        img[..., c] = img[..., c] * (1 - lid_m) + wood[..., c] * lid_m
    img[..., 3] = np.maximum(img[..., 3], lid_m * 255)

    # кольцо: железный обод и тень под ним
    ring_c = (cx + 8, 50)
    rr = np.sqrt(((xx - ring_c[0]) / 1.0) ** 2 + ((yy - ring_c[1]) / 0.7) ** 2)
    shadow = (np.abs(rr - 10) < 2.0)
    for c, v in enumerate((20, 16, 14)):
        img[..., c][np.roll(shadow, 3, axis=0) & (lid_m > 0.5)] = v
    ring = (np.abs(rr - 9) < 1.25)
    for c, v in enumerate((104, 104, 110)):
        img[..., c][ring] = v
    img[..., 3] = np.where(ring, 255, img[..., 3])

    # лёгкое размытие края и мягкая тень снизу
    out = np.clip(img, 0, 255).astype(np.uint8)
    pil = Image.fromarray(out, "RGBA")
    a = pil.split()[-1].filter(ImageFilter.GaussianBlur(0.8))
    pil.putalpha(a)
    path = os.path.join("game", "assets", "village", "hatch.png")
    pil.save(path)
    print("OK", path, W, "x", H)


if __name__ == "__main__":
    main()
