#!/usr/bin/env python3
"""Проверка кадров, снятых настоящей отрисовкой (аудит F-07): ошибки шейдеров, скриптов и ресурсов в журнале,
пустые и чёрные кадры. Самотесты Godot идут без видеодрайвера и такого не видят.

Запуск: python3 tools/check_render.py ПАПКА_С_КАДРАМИ ЖУРНАЛ ширина высота метка [метка ...]
Проверка самой проверки: python3 tools/check_render.py --self-test
Выход 1, если нашлась хотя бы одна проблема. Нужен Pillow.
"""
import re
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageStat

# строки журнала, которые считаем безобидными: в Xvfb нет звука и ввода, а выход из Godot всегда ругается на утечки
HARMLESS = ("ERR_CANT_OPEN", "resources still in use", "ObjectDB", "leaked at exit", "ALSA", "pulse")
BAD = re.compile(r"SCRIPT ERROR|SHADER ERROR|Parse Error|Failed loading resource|Failed to load|Cannot open resource|"
                 r"Condition \"|Invalid (?:call|access|get index)|Nonexistent function|Identifier not found")
MIN_MEAN = 20.0     # у всех снятых кадров средняя яркость 32-73 из 255
MIN_STD = 15.0      # у настоящих кадров разброс 29-62; однотонный кадр даёт почти 0
MAX_DARK = 0.5      # доля почти чёрных точек; у самых тёмных (ночь у двери) около 0.09


def check_log(text: str) -> list[str]:
    out = []
    for line in text.splitlines():
        if (BAD.search(line) or line.startswith("ERROR")) and not any(h in line for h in HARMLESS):
            out.append("журнал: " + line.strip()[:200])
    if "DONE" not in text:
        out.append("журнал: нет строки DONE, съёмка оборвалась")
    return out


def check_image(path: Path, size: tuple[int, int]) -> list[str]:
    if not path.exists():
        return [f"{path.name}: кадра нет"]
    im = Image.open(path).convert("L")
    out = []
    if im.size != size:
        out.append(f"{path.name}: размер {im.size}, ожидался {size}")
    st = ImageStat.Stat(im)
    small = im.resize((max(1, im.width // 8), max(1, im.height // 8)))
    pixels = small.tobytes()
    dark = sum(1 for p in pixels if p < 12) / max(1, len(pixels))
    if st.mean[0] < MIN_MEAN:
        out.append(f"{path.name}: кадр слишком тёмный (яркость {st.mean[0]:.1f})")
    if st.stddev[0] < MIN_STD:
        out.append(f"{path.name}: кадр однотонный (разброс {st.stddev[0]:.1f})")
    if dark > MAX_DARK:
        out.append(f"{path.name}: {dark:.0%} кадра чёрные")
    return out


def self_test() -> int:
    """Чёрный и однотонный кадры и плохой журнал обязаны провалиться, нормальный кадр пройти."""
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        Image.new("RGB", (64, 64), (0, 0, 0)).save(t / "black.png")
        Image.new("RGB", (64, 64), (90, 90, 90)).save(t / "flat.png")
        noisy = Image.effect_noise((64, 64), 60).convert("RGB")
        noisy = Image.eval(noisy, lambda v: min(255, v + 10))
        noisy.save(t / "noisy.png")
        ok = bool(check_image(t / "black.png", (64, 64))) and bool(check_image(t / "flat.png", (64, 64))) \
            and not check_image(t / "noisy.png", (64, 64)) and bool(check_image(t / "missing.png", (64, 64)))
        ok = ok and bool(check_log("SHADER ERROR: x\nDONE")) and bool(check_log("SHOT a\n")) \
            and not check_log("SHOT a\nERROR: Condition \"status < 0\" is true. Returning: ERR_CANT_OPEN\nDONE")
    print("самопроверка:", "OK" if ok else "ОШИБКА")
    return 0 if ok else 1


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    folder, log, w, h, *labels = sys.argv[1:]
    problems = check_log(Path(log).read_text(encoding="utf-8", errors="replace"))
    for label in labels:
        problems += check_image(Path(folder) / f"{label}.png", (int(w), int(h)))
    if problems:
        print("ОШИБКИ:")
        for p in problems:
            print(" -", p)
        return 1
    print(f"ИТОГ: OK, кадров {len(labels)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
