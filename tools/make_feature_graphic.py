#!/usr/bin/env python3
"""Баннер для Google Play 1024x500 на всех 10 языках (TASK-098).

Берёт обложку кампании, название (game.title) и подпись (menu.hint) из файлов локализации игры.
Результат: docs/store/feature/<язык>.png (24 бита, без прозрачности).
Запуск из корня репозитория: python3 tools/make_feature_graphic.py
"""
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
LANGS = ["ru", "en", "de", "fr", "es", "pt", "tr", "hi", "vi", "zh"]
FONTS = {
    "hi": ROOT / "game" / "fonts" / "NotoSansDevanagari.ttf",
    "zh": ROOT / "game" / "fonts" / "NotoSansSC.ttf",
}
DEFAULT_FONT = ROOT / "game" / "fonts" / "Nunito.ttf"
COVER = ROOT / "game" / "assets" / "ui" / "campaign_cover.png"
OUT = ROOT / "docs" / "store" / "feature"
TEXT_W = 520          # ширина колонки текста слева; церковь на обложке начинается правее x=560
TITLE_COLOR = (255, 236, 200)
TAG_COLOR = (255, 184, 70)
STROKE = (20, 10, 5)


def loc(lang: str, key: str) -> str:
    src = (ROOT / "game" / "scripts" / "loc" / f"{lang}.gd").read_text(encoding="utf-8")
    m = re.search(r'"' + re.escape(key) + r'":\s*"([^"]+)"', src)
    if not m:
        raise SystemExit(f"{lang}: нет ключа {key}")
    return m.group(1)


def font(lang: str, size: int, weight: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONTS.get(lang, DEFAULT_FONT)), size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def wrap(draw: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont, width: int) -> list[str]:
    """Перенос по словам; для китайского (нет пробелов) по знакам."""
    units = text.split(" ") if " " in text else list(text)
    sep = " " if " " in text else ""
    lines: list[str] = []
    cur = ""
    for u in units:
        trial = (cur + sep + u) if cur else u
        if draw.textlength(trial, font=f) <= width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = u
    if cur:
        lines.append(cur)
    return lines


def make(lang: str, cover: Image.Image) -> Path:
    img = cover.copy().convert("RGBA")
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for x in range(0, 700):
        d.line([(x, 0), (x, img.height)], fill=(8, 6, 16, int(200 * (1 - x / 700) ** 1.4)))
    img = Image.alpha_composite(img, ov).convert("RGB")
    d = ImageDraw.Draw(img)

    title = loc(lang, "game.title")
    tag = re.sub(r"\s+", " ", loc(lang, "menu.hint"))
    # название: самый крупный кегль, при котором оно помещается в одну строку, иначе две строки
    size, tl = 120, [title]
    while size > 56:
        f = font(lang, size, 800)
        if d.textlength(title, font=f) <= TEXT_W:
            break
        size -= 4
    else:
        f = font(lang, 84, 800)
        tl = wrap(d, title, f, TEXT_W)
        size = 84
    f = font(lang, size, 800)
    tag_f = font(lang, 30, 600)
    tag_lines: list[str] = []
    for part in re.split(r"(?<=[.。])\s*", tag):
        if part:
            tag_lines += wrap(d, part, tag_f, TEXT_W)
    line_h = int(size * 1.18)
    tag_h = 40
    block = len(tl) * line_h + 18 + len(tag_lines) * tag_h
    y = max(24, (img.height - block) // 2)
    for line in tl:
        d.text((52, y), line, font=f, fill=TITLE_COLOR, stroke_width=3, stroke_fill=STROKE)
        y += line_h
    y += 18
    for line in tag_lines:
        d.text((56, y), line, font=tag_f, fill=TAG_COLOR, stroke_width=2, stroke_fill=STROKE)
        y += tag_h
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{lang}.png"
    img.save(path, optimize=True)
    return path


def main() -> None:
    cover = Image.open(COVER).convert("RGB").crop((112, 170, 944, 576)).resize((1024, 500), Image.LANCZOS)
    for lang in LANGS:
        p = make(lang, cover)
        print(lang, p.relative_to(ROOT), p.stat().st_size // 1024, "КБ")


if __name__ == "__main__":
    main()
