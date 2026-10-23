#!/usr/bin/env python3
"""Проверка страницы магазина (TASK-098): длины текстов, языки, картинки, соответствие игре.

Запуск из корня репозитория: python3 tools/check_store.py [--release]
Нужны Pillow и markdown (pip install pillow markdown). Выход 1, если есть ошибки.
С --release дополнительно требует настоящие контакты в политике (перед выходом в магазин).
"""
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LISTING = ROOT / "docs" / "store" / "listing"
SCREENS = ROOT / "docs" / "store" / "screens"
LANGS = ["ru", "en", "de", "fr", "es", "pt", "tr", "hi", "vi", "zh"]
LIMITS = {"title": 30, "short": 80, "full": 4000}
LONG_DASH = "—"

errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def parse(path: Path) -> dict[str, str]:
    parts: dict[str, list[str]] = {}
    cur = None
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.fullmatch(r"# (title|short|full)", line)
        if m:
            cur = m.group(1)
            parts[cur] = []
        elif cur:
            parts[cur].append(line)
    return {k: "\n".join(v).strip() for k, v in parts.items()}


def check_texts() -> None:
    game_titles = {}
    loc_dir = ROOT / "game" / "scripts" / "loc"
    for lang in LANGS:
        src = (loc_dir / f"{lang}.gd").read_text(encoding="utf-8")
        m = re.search(r'"game\.title":\s*"([^"]+)"', src)
        game_titles[lang] = m.group(1) if m else None
    for lang in LANGS:
        path = LISTING / f"{lang}.txt"
        if not path.exists():
            err(f"{lang}: нет файла {path.name}")
            continue
        parts = parse(path)
        for key, limit in LIMITS.items():
            text = parts.get(key, "")
            if not text:
                err(f"{lang}: пустое поле {key}")
                continue
            if len(text) > limit:
                err(f"{lang}: {key} {len(text)} знаков, предел {limit}")
        if parts.get("title") != game_titles[lang]:
            err(f"{lang}: название {parts.get('title')!r} не совпадает с game.title {game_titles[lang]!r}")
        if "\n" in parts.get("title", "") or "\n" in parts.get("short", ""):
            err(f"{lang}: название и краткое описание должны быть в одну строку")
        whole = path.read_text(encoding="utf-8")
        if LONG_DASH in whole:
            err(f"{lang}: длинное тире U+2014")
        if "19" not in parts.get("full", ""):
            err(f"{lang}: в полном описании нет числа достижений 19")
        if "12" not in parts.get("full", ""):
            err(f"{lang}: в полном описании нет числа глав 12")
    ru = parse(LISTING / "ru.txt") if (LISTING / "ru.txt").exists() else {}
    for key, text in ru.items():
        if re.search(r"\bне\b[^.!?\n]{0,40}, а\b", text):
            err(f"ru: {key}: конструкция «не X, а Y»")
        for bad in ("честно", "важно понимать", "стоит отметить", "таким образом"):
            if bad in text.lower():
                err(f"ru: {key}: шаблонная фраза «{bad}»")


def check_game_facts() -> None:
    """Числа в описании должны совпадать с игрой."""
    ru_loc = (ROOT / "game" / "scripts" / "loc" / "ru.gd").read_text(encoding="utf-8")
    ach = set(re.findall(r'"ach\.([a-z_0-9]+)\.name"', ru_loc))
    if len(ach) != 19:
        err(f"в игре {len(ach)} достижений, в описании 19")
    camp = (ROOT / "game" / "scripts" / "core" / "campaign.gd").read_text(encoding="utf-8")
    chapters = set(re.findall(r'"(a[1-4]c[1-3])"', camp))
    if len(chapters) != 12:
        err(f"в игре {len(chapters)} глав, в описании 12")
    inspect = (ROOT / "game" / "scripts" / "core" / "match.gd").read_text(encoding="utf-8")
    if "func inspect_visitor(seat: Seat, vid: int, limit: int = 2)" not in inspect:
        err("лимит осмотров у двери изменился: поправить «дважды за ночь» в описаниях")


def check_images() -> None:
    if not (SCREENS / "ru").is_dir():
        err("нет папки скриншотов языка по умолчанию docs/store/screens/ru")
    for folder in sorted(p for p in SCREENS.iterdir() if p.is_dir()):
        if folder.name not in LANGS:
            err(f"папка скриншотов {folder.name}: такого языка нет в списке")
        shots = sorted(folder.glob("*.jpg"))
        if not 2 <= len(shots) <= 8:
            err(f"{folder.name}: скриншотов {len(shots)}, нужно от 2 до 8")
        for p in shots:
            im = Image.open(p)
            w, h = im.size
            if im.mode != "RGB":
                err(f"{folder.name}/{p.name}: режим {im.mode}, нужен RGB")
            if min(w, h) < 320 or max(w, h) > 3840 or max(w, h) > 2 * min(w, h):
                err(f"{folder.name}/{p.name}: размер {w}x{h} вне правил Google (стороны 320..3840, не более 2:1)")
            if p.stat().st_size > 8 * 1024 * 1024:
                err(f"{folder.name}/{p.name}: больше 8 МБ")
    for lang in LANGS:
        fg = ROOT / "docs" / "store" / "feature" / f"{lang}.png"
        if not fg.exists():
            err(f"нет баннера docs/store/feature/{lang}.png (tools/make_feature_graphic.py)")
            continue
        im = Image.open(fg)
        if im.size != (1024, 500):
            err(f"баннер {lang}: {im.size}, нужно 1024x500")
        if im.mode != "RGB":
            err(f"баннер {lang} в режиме {im.mode}: нужен 24-битный без прозрачности")
        if fg.stat().st_size > 15 * 1024 * 1024:
            err(f"баннер {lang} больше 15 МБ")
    icon = ROOT / "game" / "assets" / "icon" / "icon_512.png"
    if not icon.exists() or Image.open(icon).size != (512, 512):
        err("значок 512x512 не найден или другого размера")
    elif icon.stat().st_size > 1024 * 1024:
        err("значок больше 1 МБ")


def check_privacy() -> None:
    """HTML политики должен совпадать с docs/privacy-policy.md; в релизе нужны настоящие контакты."""
    sys.path.insert(0, str(ROOT / "tools"))
    import make_privacy_html

    html = make_privacy_html.DST
    if not html.exists() or html.read_text(encoding="utf-8") != make_privacy_html.render():
        err("docs/privacy-policy.html устарел: python3 tools/make_privacy_html.py")
    if not (ROOT / "docs" / ".nojekyll").exists():
        err("нет docs/.nojekyll: GitHub Pages испортит страницы")
    text = make_privacy_html.SRC.read_text(encoding="utf-8")
    if LONG_DASH in text:
        err("политика: длинное тире U+2014")
    if "--release" in sys.argv:
        left = re.findall(r"\[(?:ИМЯ РАЗРАБОТЧИКА|E-MAIL ДЛЯ СВЯЗИ|DEVELOPER NAME|CONTACT E-MAIL)\]", text)
        if left:
            err(f"политика: не заполнены контакты {sorted(set(left))}")


def main() -> int:
    check_texts()
    check_game_facts()
    check_images()
    check_privacy()
    for lang in LANGS:
        p = LISTING / f"{lang}.txt"
        if p.exists():
            parts = parse(p)
            print(f"{lang}: название {len(parts.get('title', ''))}/30, краткое {len(parts.get('short', ''))}/80, "
                  f"полное {len(parts.get('full', ''))}/4000")
    if errors:
        print("\nОШИБКИ:")
        for e in errors:
            print(" -", e)
        return 1
    print("\nИТОГ: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
