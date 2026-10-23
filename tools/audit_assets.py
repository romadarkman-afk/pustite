#!/usr/bin/env python3
"""Аудит ассетов (TASK-099, область 8): файлы без ссылок и ссылки на несуществующие файлы.

Запуск из корня репозитория: python3 tools/audit_assets.py
Ссылка считается найденной, если в тексте проекта (gd, tscn, tres, json, cfg, godot) есть полный путь res://
или имя файла без расширения как отдельное слово (покрывает пути, собранные форматом).
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
TEXT_EXT = {".gd", ".tscn", ".tres", ".json", ".cfg", ".godot", ".gdshader", ".txt"}
ASSET_DIRS = ["assets", "fonts"]
SKIP_EXT = {".import", ".uid"}


def project_text() -> dict[Path, str]:
    out = {}
    for p in GAME.rglob("*"):
        if p.is_file() and p.suffix in TEXT_EXT and "android/build" not in str(p) and p.name != "MANIFEST.txt":
            out[p] = p.read_text(encoding="utf-8", errors="replace")
    return out


def dynamic_stems(texts: dict[Path, str]) -> set[str]:
    """Имена файлов, которые код собирает из частей (список правил: что и откуда берётся)."""
    stems: set[str] = set()
    fig = next(t for p, t in texts.items() if p.name == "villager_figure.gd")
    ids: list[str] = []
    for name in ("FOLK_FEMALE", "FOLK_MALE"):
        m = re.search(name + r": PackedInt32Array = \[([0-9, ]+)\]", fig)
        ids += re.findall(r"\d+", m.group(1)) if m else []
    stems |= {f"f{i}" for i in ids}                                   # жители: f<номер>
    hats = re.findall(r'"([a-z_]+)"', re.search(r"HERO_HAT_IDS[^=]*=\s*\[([^\]]*)\]", fig).group(1))
    for g in ("hero_m", "hero_f"):
        stems.add(g)
        stems |= {f"{g}_{h}" for h in hats}                           # герой и шапки
    guests = re.findall(r'"([a-z]+)":\s*20\d', re.search(r"GUEST_SPRITES := \{([^}]*)\}", fig).group(1))
    stems |= {f"guest_{g}" for g in guests}                           # гости кампании
    arts = set()
    for p, t in texts.items():
        if p.suffix == ".tres":
            arts |= set(re.findall(r'art = "([a-z_]+)"', t))
    for a in arts:
        stems |= {f"{a}_day", f"{a}_night"}                           # дома карт: <art>_day / _night
    stems |= {s + "_blink" for s in list(stems)}                      # закрытые глаза (необязательны)
    grounds = {"ground"}                                              # у стандартной карты значение по умолчанию
    for p, t in texts.items():
        if p.suffix == ".tres":
            grounds |= set(re.findall(r'ground = "([a-z_]*)"', t))
    stems |= {"water_" + g for g in grounds}                          # вода под картой: water_ + ground
    return stems


def main() -> int:
    texts = project_text()
    blob = "\n".join(texts.values())
    dyn = dynamic_stems(texts)
    assets = [p for d in ASSET_DIRS for p in (GAME / d).rglob("*") if p.is_file() and p.suffix not in SKIP_EXT]
    words = set(re.findall(r"[A-Za-z0-9_\-]+", blob))
    unref = []
    by_literal = 0
    for a in sorted(assets):
        rel = "res://" + a.relative_to(GAME).as_posix()
        if rel in blob:
            by_literal += 1
            continue
        if a.stem in words or (a.stem in dyn and a.parent.name in ("folk", "realistic", "maps", "village")):
            continue
        if a.suffix == ".txt" and a.parent.name == "fonts":   # тексты лицензий шрифтов лежат рядом со шрифтами
            continue
        unref.append(a)
    print(f"ассетов {len(assets)}, по полному пути найдено {by_literal}, без ссылок {len(unref)}")
    sizes = defaultdict(int)
    for a in unref:
        mib = a.stat().st_size / 1048576
        sizes[a.parent.relative_to(GAME).as_posix()] += a.stat().st_size
        print(f"  БЕЗ ССЫЛКИ {a.relative_to(GAME).as_posix()} ({mib:.2f} МиБ)")
    print("вес без ссылок по папкам:", {k: round(v / 1048576, 2) for k, v in sizes.items()})

    # ссылки res://assets|fonts|... на несуществующие файлы
    missing = []
    for p, t in texts.items():
        for m in re.finditer(r'res://([A-Za-z0-9_./\-]+\.(?:gdshader|png|jpg|jpeg|webp|ogg|wav|mp3|ttf|otf|svg|tres|tscn|gd|json))', t):
            target = GAME / m.group(1)
            if not target.exists():
                line = t.count("\n", 0, m.start()) + 1
                missing.append((p.relative_to(ROOT).as_posix(), line, m.group(1)))
    print(f"ссылок на несуществующие файлы: {len(missing)}")
    for f, line, path in missing:
        print(f"  НЕТ ФАЙЛА {f}:{line} -> {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
