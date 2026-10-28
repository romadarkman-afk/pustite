#!/usr/bin/env python3
"""Аудит кода (TASK-099, область 1): функции без вызовов, файлы без ссылок, нетипизированные массивы.

Запуск из корня репозитория: python3 tools/audit_code.py
Поиск лексический: имя функции считается использованным, если встречается где-либо в проекте как слово
(вызов, имя сигнала, строка для call_deferred/Callable). Остальное кандидаты на ручную проверку.
"""
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
VIRTUAL = {"_init", "_ready", "_process", "_physics_process", "_draw", "_input", "_unhandled_input", "_unhandled_key_input",
           "_gui_input", "_notification", "_enter_tree", "_exit_tree", "_get_minimum_size", "_to_string", "_get",
           "_set", "_get_property_list", "_can_drop_data", "_drop_data", "_get_drag_data", "_make_custom_tooltip",
           "_has_point", "_shortcut_input", "_get_configuration_warnings", "_validate_property", "_initialize", "_finalize",
           "_iteration", "_property_can_revert", "_property_get_revert", "_run", "_integrate_forces"}


def main() -> int:
    files = [p for p in (GAME / "scripts").rglob("*.gd")]
    texts = {p: p.read_text(encoding="utf-8") for p in files}
    in_tests = lambda p: "/tests/" in p.as_posix()
    prod_blob = "\n".join(t for p, t in texts.items() if not in_tests(p))
    all_blob = "\n".join(texts.values()) + "\n" + "\n".join(
        p.read_text(encoding="utf-8", errors="replace") for p in list(GAME.rglob("*.tscn")) + list(GAME.rglob("*.tres")))
    words_prod = Counter(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", prod_blob))
    words_all = Counter(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", all_blob))

    only_tests, unused = [], []
    funcs = 0
    for p, t in texts.items():
        if in_tests(p):
            continue
        for m in re.finditer(r"^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\(", t, re.M):
            name = m.group(1)
            funcs += 1
            if name in VIRTUAL or name.startswith("_on_"):
                continue
            line = t.count("\n", 0, m.start()) + 1
            if words_all[name] <= 1:
                unused.append((p.relative_to(ROOT).as_posix(), line, name))
            elif words_prod[name] <= 1:
                only_tests.append((p.relative_to(ROOT).as_posix(), line, name))
    print(f"функций в рабочем коде: {funcs}")
    print(f"\nБЕЗ ЕДИНОГО ВЫЗОВА (имя встречается только в объявлении): {len(unused)}")
    for f, l, n in sorted(unused):
        print(f"  {f}:{l} {n}")
    print(f"\nВЫЗЫВАЮТСЯ ТОЛЬКО ИЗ ТЕСТОВ: {len(only_tests)}")
    for f, l, n in sorted(only_tests):
        print(f"  {f}:{l} {n}")

    # файлы с class_name, на которые нет ссылок
    print("\nКЛАССЫ БЕЗ ССЫЛОК:")
    for p, t in texts.items():
        m = re.search(r"^class_name ([A-Za-z0-9_]+)", t, re.M)
        if m and not in_tests(p):
            cls = m.group(1)
            uses = len(re.findall(r"\b" + cls + r"\b", prod_blob)) - 1
            if uses <= 0:
                print(f"  {p.relative_to(ROOT).as_posix()} класс {cls}")

    # нетипизированные массивы и словари
    untyped = []
    for p, t in texts.items():
        if in_tests(p):
            continue
        for m in re.finditer(r"^\s*(?:var|const)\s+\w+\s*(?::\s*Array\b(?!\[)|:=\s*\[\])", t, re.M):
            untyped.append((p.relative_to(ROOT).as_posix(), t.count("\n", 0, m.start()) + 1))
    print(f"\nНЕТИПИЗИРОВАННЫЕ МАССИВЫ (var x: Array или := []): {len(untyped)}")
    per_file = Counter(f for f, _ in untyped)
    for f, n in per_file.most_common(12):
        print(f"  {f}: {n}")

    # connect без disconnect (грубо: файлы, где connect больше disconnect и нет queue_free владельца)
    heavy = []
    for p, t in texts.items():
        if in_tests(p):
            continue
        c = len(re.findall(r"\.connect\(", t))
        d = len(re.findall(r"\.disconnect\(", t))
        if c >= 8 and d == 0:
            heavy.append((c, p.relative_to(ROOT).as_posix()))
    print("\nМНОГО connect БЕЗ ЕДИНОГО disconnect (информативно: узел и сигнал обычно умирают вместе):")
    for c, f in sorted(heavy, reverse=True)[:10]:
        print(f"  {f}: {c}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
