#!/usr/bin/env python3
"""Скриншоты телефона для Google Play: шесть кадров на язык (TASK-098).

Запуск из корня репозитория: python3 tools/make_store_screens.py ru en de ...
Без аргументов делает все 10 языков. Нужны godot 4.6 (переменная GODOT), xvfb-run, Pillow.
Каждый язык занимает 2-4 минуты. Результат: docs/store/screens/<язык>/NN-имя.jpg (1080x1920, RGB).
"""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LANGS = ["ru", "en", "de", "fr", "es", "pt", "tr", "hi", "vi", "zh"]
# метка кадра, спецификация для tools/store_shots.sh, имя файла в магазине (порядок = порядок показа)
SHOTS = [
    ("s3_winter", "s3_winter:day:a3c1", "01-zima"),
    ("s6_door_winter", "s6_door_winter:door:a3c1", "02-dver-zima"),
    ("s1_summer", "s1_summer:day:a1c3", "03-leto"),
    ("s2_autumn", "s2_autumn:day:a2c1", "04-osen"),
    ("s4_spring", "s4_spring:day:a4c1", "05-vesna"),
    ("s8_camp", "s8_camp:camp", "06-karta"),
]
QUALITY = 82


def make(lang: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        cmd = [str(ROOT / "tools" / "store_shots.sh"), tmp, lang] + [s[1] for s in SHOTS]
        subprocess.run(cmd, check=True, env=os.environ.copy())
        out = ROOT / "docs" / "store" / "screens" / lang
        out.mkdir(parents=True, exist_ok=True)
        for old in out.glob("*.jpg"):
            old.unlink()
        for label, _spec, name in SHOTS:
            src = Path(tmp) / f"{label}.png"
            if not src.exists():
                raise SystemExit(f"{lang}: кадр {label} не получился")
            im = Image.open(src).convert("RGB")
            if im.size != (1080, 1920):
                raise SystemExit(f"{lang}: {label} размером {im.size}")
            im.save(out / f"{name}.jpg", quality=QUALITY, optimize=True)
    print(lang, "готово")


def main() -> None:
    langs = sys.argv[1:] or LANGS
    for lang in langs:
        if lang not in LANGS:
            raise SystemExit(f"неизвестный язык {lang}")
        make(lang)


if __name__ == "__main__":
    main()
