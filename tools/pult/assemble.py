#!/usr/bin/env python3
"""Склеивает template.html и pult_data.json в готовую страницу: python3 assemble.py data.json out.html"""
import json, sys, pathlib
here = pathlib.Path(__file__).parent
data = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
html = (here / "template.html").read_text(encoding="utf-8")
obj = json.loads(data)
ledger = here / "ingested.json"
# принятые в игру задачи (tools/pult/ingest.py): страница отмечает их готовыми на любом устройстве
obj["accepted"] = json.loads(ledger.read_text(encoding="utf-8")) if ledger.exists() else []
safe = json.dumps(obj, ensure_ascii=False).replace("</", "<\\/").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
pathlib.Path(sys.argv[2]).write_text(html.replace("__DATA__", safe), encoding="utf-8")
print("ok", pathlib.Path(sys.argv[2]).stat().st_size)
