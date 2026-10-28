#!/usr/bin/env python3
"""Заглушки для картинок погоды: те же имена и сетки, что в docs/art-prompts-weather.md.

Игра читает эти файлы. Когда ChatGPT нарисует настоящие, они просто заменяют заглушки.
Запуск: python3 tools/make_weather_placeholders.py  (из корня репозитория)
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

OUT = os.path.join("game", "assets", "weather")
RNG = np.random.default_rng(7)


def save(arr: np.ndarray, name: str) -> None:
    os.makedirs(OUT, exist_ok=True)
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    mode = "RGBA" if arr.shape[2] == 4 else "RGB"
    path = os.path.join(OUT, name)
    Image.fromarray(arr, mode).save(path, quality=88) if name.endswith(".jpg") else Image.fromarray(arr, mode).save(path)
    print("OK", path, arr.shape[1], "x", arr.shape[0])


def grid(frames: list[np.ndarray], cols: int, rows: int, cell: int) -> np.ndarray:
    sheet = np.zeros((rows * cell, cols * cell, 4), np.float32)
    for i, f in enumerate(frames[: cols * rows]):
        r, c = divmod(i, cols)
        sheet[r * cell : (r + 1) * cell, c * cell : (c + 1) * cell] = f
    return sheet


def coords(n: int) -> tuple[np.ndarray, np.ndarray]:
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    return (xs - n / 2) / (n / 2), (ys - n / 2) / (n / 2)


def rgba(color: tuple[int, int, int], alpha: np.ndarray) -> np.ndarray:
    out = np.zeros(alpha.shape + (4,), np.float32)
    out[..., 0], out[..., 1], out[..., 2] = color
    out[..., 3] = np.clip(alpha, 0, 1) * 255
    return out


def soft_disc(n: int, radius: float, cx=0.0, cy=0.0, power=2.0) -> np.ndarray:
    x, y = coords(n)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / radius
    return np.clip(1.0 - d, 0, 1) ** power


def flake(n: int, i: int) -> np.ndarray:
    x, y = coords(n)
    if i % 3 == 0:
        a = soft_disc(n, 0.55 + 0.05 * (i % 4), power=1.6)
    else:
        ang = np.arctan2(y, x)
        r = np.sqrt(x * x + y * y)
        arms = np.clip(np.cos(ang * 6) * 0.5 + 0.5, 0, 1) ** 6
        a = np.clip(1.0 - r / 0.8, 0, 1) ** 1.3 * (0.35 + 0.65 * arms) + soft_disc(n, 0.22, power=1.4)
    return rgba((236, 244, 255), a)


def rain(n: int, i: int) -> np.ndarray:
    x, y = coords(n)
    w = 0.05 + 0.02 * (i % 3)
    length = 0.95 - 0.1 * (i % 2)
    inside = np.clip(1.0 - np.abs(x) / w, 0, 1) ** 1.5
    along = np.clip((y + length) / (2 * length), 0, 1) ** 1.8
    return rgba((205, 220, 240), inside * along * (np.abs(y) < length))


def splash(n: int, i: int, total: int = 8) -> np.ndarray:
    x, y = coords(n)
    t = i / (total - 1)
    rx, ry = 0.18 + 0.6 * t, (0.18 + 0.6 * t) * 0.38
    d = np.sqrt((x / rx) ** 2 + ((y + 0.1) / ry) ** 2)
    ring = np.clip(1.0 - np.abs(d - 1.0) / 0.18, 0, 1)
    a = ring * (1.0 - t) ** 0.8
    for k in range(5):
        ang = 1.1 + k * 0.5
        px, py = np.cos(ang) * rx * 0.9 * t, -np.sin(ang) * (0.25 + 0.5 * t) * (1 - t * 0.4)
        a = a + soft_disc(n, 0.07, px, py - 0.1) * (1 - t) * 0.9
    return rgba((225, 238, 250), a)


def ripple(n: int, i: int, total: int = 8) -> np.ndarray:
    x, y = coords(n)
    t = i / (total - 1)
    rx = 0.12 + 0.8 * t
    d = np.sqrt((x / rx) ** 2 + (y / (rx * 0.4)) ** 2)
    ring = np.clip(1.0 - np.abs(d - 1.0) / 0.12, 0, 1)
    return rgba((200, 222, 240), ring * (1.0 - t) ** 1.2 * 0.9)


LEAVES = [(214, 170, 50), (200, 100, 40), (140, 90, 50), (150, 40, 35)]


def leaf(n: int, i: int) -> np.ndarray:
    x, y = coords(n)
    ang = 0.5 + i * 0.7
    xr = x * np.cos(ang) + y * np.sin(ang)
    yr = -x * np.sin(ang) + y * np.cos(ang)
    shape = np.clip(1.0 - np.sqrt((xr / 0.34) ** 2 + (yr / 0.7) ** 2), 0, 1)
    a = (shape > 0).astype(np.float32) * np.clip(shape * 8, 0, 1)
    vein = np.abs(xr) < 0.025
    out = rgba(LEAVES[i % 4], a)
    out[..., :3] = out[..., :3] * np.where(vein, 0.7, 1.0)[..., None]
    return out


def fluff(n: int, i: int) -> np.ndarray:
    a = soft_disc(n, 0.5, power=2.2) * 0.8
    for k in range(7):
        ang = k * 0.9 + i
        a = a + soft_disc(n, 0.12, np.cos(ang) * 0.3, np.sin(ang) * 0.3) * 0.5
    return rgba((250, 250, 248), a)


def ember(n: int, i: int) -> np.ndarray:
    core = soft_disc(n, 0.16 + 0.03 * (i % 3), power=1.2)
    glow = soft_disc(n, 0.5, power=2.5)
    out = rgba((255, 150, 60), glow * 0.7 + core)
    out[..., 1] = 150 + 80 * core
    out[..., 2] = 60 + 120 * core
    return out


def wrap_noise(h: int, w: int, scales: list[tuple[float, float]]) -> np.ndarray:
    total = np.zeros((h, w), np.float32)
    for sigma, weight in scales:
        n = ndimage.gaussian_filter(RNG.random((h, w)).astype(np.float32), sigma=sigma, mode="wrap")
        n = (n - n.min()) / (n.max() - n.min() + 1e-6)
        total += n * weight
    return total / sum(w_ for _, w_ in scales)


def clouds() -> np.ndarray:
    h, w = 512, 2048
    n = wrap_noise(h, w, [(70, 1.0), (28, 0.6), (10, 0.3)])
    n = np.clip((n - 0.45) * 3.2, 0, 1)
    ys = np.linspace(-1, 1, h)[:, None]
    n = n * np.clip(1.0 - np.abs(ys) ** 2, 0, 1)
    return rgba((255, 255, 255), n * 0.95)


def mist_billow(n: int) -> np.ndarray:
    x, y = coords(n)
    mask = np.clip(1.0 - np.sqrt(x * x + y * y), 0, 1) ** 1.2
    noise = wrap_noise(n, n, [(40, 1.0), (14, 0.5)])
    return rgba((235, 238, 240), mask * np.clip(noise * 1.4, 0, 1) * 0.8)


def grass_tuft(n: int, i: int, dry: bool) -> np.ndarray:
    img = np.zeros((n, n), np.float32)
    shade = np.zeros((n, n), np.float32)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    blades = 9 + (i % 4) * 2
    for b in range(blades):
        base = n * (0.5 + (RNG.random() - 0.5) * 0.5)
        height = n * (0.35 + 0.5 * RNG.random()) * (0.6 + 0.12 * (i % 5))
        lean = (RNG.random() - 0.5) * n * 0.35
        t = np.clip((n - ys) / height, 0, 1)
        cx = base + lean * t * t
        width = 3.2 * (1.0 - t) + 0.6
        m = (np.abs(xs - cx) < width) & (n - ys < height) & (ys < n)
        img = np.maximum(img, m.astype(np.float32))
        shade = np.maximum(shade, m * (0.45 + 0.55 * t) * (0.7 + 0.3 * RNG.random()))
    if dry:
        col = np.stack([128 + 60 * shade, 104 + 50 * shade, 62 + 26 * shade], -1)
    else:
        col = np.stack([58 + 42 * shade, 70 + 52 * shade, 36 + 22 * shade], -1)
    out = np.dstack([col, img * 255])
    out[..., 3] = ndimage.gaussian_filter(out[..., 3], 0.6)
    return out


def snow_ground() -> np.ndarray:
    n = 1024
    low = wrap_noise(n, n, [(90, 1.0), (30, 0.6)])
    fine = wrap_noise(n, n, [(2.0, 1.0)])
    v = 0.88 + 0.08 * low + 0.05 * (fine - 0.5)
    col = np.stack([v * 245, v * 250, v * 255], -1)
    return col


def main() -> None:
    save(clouds(), "clouds.png")
    save(grid([flake(128, i) for i in range(16)], 4, 4, 128), "flake_sheet.png")
    save(grid([rain(128, i) for i in range(4)], 4, 1, 128), "rain_sheet.png")
    save(grid([splash(128, i) for i in range(8)], 4, 2, 128), "splash_sheet.png")
    save(grid([ripple(128, i) for i in range(8)], 4, 2, 128), "ripple_sheet.png")
    save(grid([leaf(128, i) for i in range(8)], 4, 2, 128), "leaf_sheet.png")
    save(grid([fluff(64, i) for i in range(8)], 4, 2, 64), "fluff_sheet.png")
    save(grid([ember(64, i) for i in range(8)], 4, 2, 64), "ember_sheet.png")
    save(grid([mist_billow(512) for _ in range(4)], 2, 2, 512), "mist_sheet.png")
    save(grid([grass_tuft(256, i, False) for i in range(8)], 4, 2, 256), "grass_green_sheet.png")
    save(grid([grass_tuft(256, i, True) for i in range(8)], 4, 2, 256), "grass_dry_sheet.png")
    save(snow_ground(), "snow_ground.jpg")


if __name__ == "__main__":
    main()
