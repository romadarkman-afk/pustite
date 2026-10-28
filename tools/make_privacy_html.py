#!/usr/bin/env python3
"""Политика конфиденциальности в HTML для GitHub Pages (TASK-098).

Источник текста: docs/privacy-policy.md. Результат: docs/privacy-policy.html.
Запуск из корня репозитория: python3 tools/make_privacy_html.py
Нужен модуль markdown (pip install markdown).
"""
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "privacy-policy.md"
DST = ROOT / "docs" / "privacy-policy.html"

PAGE = """<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Политика конфиденциальности: Пустите / Let Me In</title>
<style>
:root {{ --bg: #ffffff; --fg: #1d1b24; --muted: #5d5a68; --link: #8a4b00; --rule: #d9d6df; }}
@media (prefers-color-scheme: dark) {{
  :root {{ --bg: #14121a; --fg: #ece8f2; --muted: #a8a3b4; --link: #ffb846; --rule: #3a3646; }}
}}
body {{ margin: 0; background: var(--bg); color: var(--fg); font: 17px/1.55 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }}
main {{ max-width: 720px; margin: 0 auto; padding: 24px 16px 64px; }}
h1 {{ font-size: 1.7rem; line-height: 1.25; }}
h2 {{ font-size: 1.2rem; margin-top: 2rem; }}
a {{ color: var(--link); }}
code {{ background: color-mix(in srgb, var(--fg) 10%, transparent); padding: 1px 5px; border-radius: 4px; font-size: .92em; }}
hr {{ border: 0; border-top: 1px solid var(--rule); margin: 2.5rem 0; }}
li {{ margin: .3rem 0; }}
</style>
</head>
<body>
<main>
{body}
</main>
</body>
</html>
"""


def render() -> str:
    body = markdown.markdown(SRC.read_text(encoding="utf-8"), extensions=["sane_lists"])
    # английская часть идёт после <hr>: помечаем её языком для браузеров и читалок
    head, sep, tail = body.partition("<hr />")
    if sep:
        body = head + sep + '<div lang="en">' + tail + "</div>"
    return PAGE.format(body=body)


if __name__ == "__main__":
    DST.write_text(render(), encoding="utf-8")
    print("записан", DST.relative_to(ROOT), DST.stat().st_size, "байт")
