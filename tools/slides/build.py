#!/usr/bin/env python3
"""Сборка пакета комиксов из раскадровок.

Запуск из корня репозитория:  python3 tools/slides/build.py
Создаёт:
  docs/slides/README.md, 00_style.md, 01_cast.md, 02_locations.md, INDEX.md, storyboard_ru.md
  docs/slides/decks/NN_<колода>.md   промпты по колодам
  docs/slides/refs/ref_<id>.jpg      картинки-эталоны лиц (из игровых портретов)
  game/config/slides.json            данные для игры
  game/config/slides_text.json       тексты подписей (ru)
"""
from __future__ import annotations

import json
import os
import re
import sys
from collections import Counter, OrderedDict
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))

import dsl  # noqa: E402
from cast import CAST, EXTRA_WHO, HERO, UPYR, face_lock  # noqa: E402
import decks_world, decks_ch_a1a2, decks_ch_a3a4, decks_bios  # noqa: E402,F401

OUT = ROOT / "docs" / "slides"
SIZE_WORD = {"t": "tall portrait 2:3 (1024x1536)", "w": "wide landscape 3:2 (1536x1024)"}
SIZE_PX = {"t": (1024, 1536), "w": (1536, 1024)}
KIND_RU = {"prologue": "Предыстория", "act_intro": "Вход в акт", "act_outro": "Выход из акта", "ch_intro": "Вход в главу",
           "ch_win": "Победа в главе", "ch_twist": "Поворот после главы", "bio": "Предыстория жителя", "guest": "Гость",
           "npc": "Лицо сюжета", "finale": "Финал"}

STYLE_LOCK = """Photo-comic panel, noir graphic-novel look in the spirit of the Max Payne motion comic.
Staged live-action photography: real-looking actors in period costume and practical locations, then a heavy cinematic grade: crushed near-black shadows, one cold dominant tone (steel blue or teal-grey) and one warm light source (kerosene lantern, candle, fire, amber window), strong directional light, visible film grain, light haze, rain, snow or mist in the air.
Dramatic camera: low angles, high angles, Dutch tilt, extreme close-ups, over-the-shoulder, silhouettes in doorways, reflections.
Setting: rural Russia, 1890s: log houses, birch and spruce, river fog, kerosene lanterns, sheepskin, linen, felt boots, headscarves. Nothing modern: no plastic, no electric light, no zippers.
Faces: ordinary tired people with real skin texture and imperfections, never glamorous, never model-like.
The monster (upyr) is NEVER shown clearly: only a thin tall silhouette, pale long-fingered hands, wet bare footprints, eyes that catch the light like an animal's. No fangs, no gore, no blood spray: horror by implication.
The player character ("the hero") is NEVER shown from the front and never with a visible face: only from behind, a shoulder, hands, a silhouette or a reflection; sheepskin coat, hood or headscarf, a kerosene lantern in the left hand.
Strictly: no text, no letters, no numbers, no logos, no speech bubbles, no captions, no borders, no frames, no watermark, no signature.
Keep the key subject inside the central 70% of the frame (the game crops and slowly zooms into the picture)."""

STYLE_SHORT = ("Photo-comic noir panel in the spirit of the Max Payne motion comic: staged live-action photograph, real actors in 1890s rural Russian costume, "
               "heavy cinematic grade, crushed blacks, one cold dominant tone plus one warm light source, film grain, haze. "
               "No text, letters, numbers, logos, speech bubbles, borders or watermark. Key subject inside the central 70% of the frame.")

ACT_GRADES = [
    ("Акт I «Деревня», лето", "тёплое золото заката, которое уходит в стальной синий; свет окон и фонарей оранжевый"),
    ("Акт II «Мельница», осень", "ржавчина и сланцево-серый, мокрый блеск, дождь; тёплый только фонарь"),
    ("Акт III «Монастырь», зима", "сине-белая метель, чёрное дерево и камень, один оранжевый огонь, пар от дыхания"),
    ("Акт IV «Станция», весна", "серо-зелёная грязь оттепели, мокрые рельсы, жёлтый керосиновый свет в густом тумане"),
]

LOCS = [
    ("river", "Река предыстории", "A wide black river at dusk between spruce walls, a rope-ferry raft, fog on the water, a lantern on the far bank. No people."),
    ("a1c1", "Нижний Посад", "Riverside village Lower Posad in summer dusk: five log houses, a hay barn, a small wooden chapel with a carved name board, a smithy, an earth cellar, nets drying on poles, a muddy landing with a ferry raft."),
    ("a1c2", "Горелый Починок", "Burnt hamlet Gorely Pochinok in peat smoke and fog: an apiary house, a tar kiln, a drying barn, a black-style bathhouse, a crane well with a little roof, charred beams."),
    ("a1c3", "Старый Перевоз", "Old Ferry crossing in a storm: a ferryman's hut, a salt warehouse, a fishermen's net shed, a wooden watch tower with a lantern, a root cave stash on the bank, boats on ropes."),
    ("a2c1", "Мельничный Двор", "Mill yard in heavy autumn rain: a water mill with a big wheel, the miller's large house, a grain-crusher house, a wheelwright's shed, a hermit's hut, planks over mud, swollen river."),
    ("a2c2", "Затопленная Слобода", "Flooded village Sloboda: an inn, a stone distillery, a net-drying shed, a floating warehouse, a half-sunk bell tower, brown water up to the windows."),
    ("a2c3", "Гнилая Гать", "Rotten Gat, a frozen bog under a full moon: a hunter's winter hut on stilts, a charcoal kiln, a stage hut, a forest storehouse on posts, a wayside chapel, a corduroy log road."),
    ("a3c1", "Внешний Скит", "Outer Skit of a monastery in a blizzard: a pilgrims' hostel, a gate tower, a bakery, a candle shed, a woodshed with a bell frame, snow blowing sideways."),
    ("a3c2", "Монастырский Двор", "Monastery courtyard under deep untouched snow: a three-domed stone cathedral, brethren cells, a refectory hall, a great bell tower, the crypt entrance."),
    ("a3c3", "Пепелище", "The Ashes: a burning cathedral in deep snow, boarded cells, a besieged refectory, a cracked bell tower, an opened crypt; orange fire on blue snow."),
    ("a4c1", "Разъезд 14-я Верста", "Railway halt 14th Verst in thaw fog: track workers' barracks, a signal hut, a kerosene cellar, a telegraph station, a handcar shed, wet rails."),
    ("a4c2", "Грузовой Тупик", "Freight dead-end in coal mist: a water tower, a freight warehouse, coal heaps, a repair workshop, an abandoned boxcar on rusted rails."),
    ("a4c3", "Перрон Полночь", "Platform Polunoch in the last frost: a wooden station building, a third-class waiting hall, a baggage room, a stationmaster's booth, carriage No. 4, hanging lanterns."),
]

CHAPTER_OF = {}
for _c in ["a1c1", "a1c2", "a1c3", "a2c1", "a2c2", "a2c3", "a3c1", "a3c2", "a3c3", "a4c1", "a4c2", "a4c3"]:
    CHAPTER_OF[_c] = int(_c[1])


def wave(deck, panel) -> str:
    """Первая волна: ядро каждой колоды, чтобы игра выглядела цельно уже на 140 картинках."""
    k = panel.key
    kind = deck.kind
    if kind == "prologue":
        return "A"
    if kind == "act_intro":
        return "A" if k in ("01", "03") else "B"
    if kind == "act_outro":
        return "A" if k == "01" else "B"
    if kind == "ch_intro":
        return "A" if k in ("01", "03", "05") else "B"
    if kind in ("ch_win", "ch_twist"):
        return "A" if k in ("01", "04") else "B"
    if kind in ("bio", "guest", "npc"):
        if deck.id.endswith("_human") or deck.id.endswith("_upyr"):
            return "B"
        return "A" if k == "03" else "B"
    if kind == "finale":
        return "A" if k in ("01", "05") else "B"
    return "B"


# ------------------------------------------------------------------ проверка текста
BANNED = ["каша", "каши", "хаос", "жвачк", "методичк", "истерик", "дедлайн", "на стероидах", "на минималках",
          "честно", "нормальн", "большинств", "каждый", "каждая", "каждое", "важно понимать", "стоит отметить", "таким образом"]


def lint(text: str, where: str, errs: list):
    if "—" in text:
        errs.append(f"{where}: длинное тире")
    low = text.lower()
    for w in BANNED:
        if w in low:
            errs.append(f"{where}: слово «{w}»")
    if re.search(r"\bне [^.,;:!?]{1,40}, а\b", low) or re.search(r"\bэто не [^.,;:!?]{1,40}, это\b", low):
        errs.append(f"{where}: конструкция «не X, а Y»")
    if len(text) > 120:
        errs.append(f"{where}: подпись длиннее 120 знаков ({len(text)})")


def all_panels():
    for d in dsl.DECKS:
        for p in d.panels:
            yield d, p


def check() -> list:
    errs: list = []
    ids = Counter(d.id for d in dsl.DECKS)
    for i, n in ids.items():
        if n > 1:
            errs.append(f"колода {i} задана {n} раза")
    for d, p in all_panels():
        where = f"{d.id}/{p.key}"
        for who, text in p.cap:
            lint(text, where, errs)
            if who and who not in CAST and who not in EXTRA_WHO:
                errs.append(f"{where}: неизвестный говорящий {who}")
        for c in p.cast:
            if c != "hero" and c not in CAST:
                errs.append(f"{where}: нет персонажа {c}")
        if p.sz not in ("t", "w"):
            errs.append(f"{where}: размер {p.sz}")
        if len(p.cap) > 2:
            errs.append(f"{where}: больше двух подписей")
        if re.search(r"[Ѐ-ӿ]", p.en):
            errs.append(f"{where}: русские буквы в английском промпте")
    return errs


# ------------------------------------------------------------------ промпты
def panel_prompt(d, p) -> tuple[str, list]:
    attach = []
    chars = []
    for c in p.cast:
        if c == "hero":
            continue
        chars.append(face_lock(c))
        attach.append(f"cast_{c}.png")
    rules = []
    if "hero" in p.cast or "hooded figure" in p.en.lower() or "hero" in p.en.lower():
        rules.append(HERO)
    low = p.en.lower()
    if any(w in low for w in ("upyr", "eyes catching", "bare foot", "bare-foot", "silhouette", "pale long")):
        rules.append(UPYR)
    out = [f"Create a {SIZE_WORD[p.sz]} image.",
           "STYLE: " + STYLE_SHORT,
           "GRADE: " + d.grade + ("." if not d.grade.endswith(".") else ""),
           "SHOT: " + p.shot + ".",
           "SCENE: " + p.en]
    if chars:
        out.append("CHARACTERS (keep every face identical to the attached reference sheet; same age, bones, eyes, hair, beard):\n- " + "\n- ".join(chars))
    if rules:
        out.append("RULES: " + " ".join(rules))
    return "\n".join(out), attach


def wave_label(w):
    return "волна 1" if w == "A" else "волна 2"


def write_deck_md(idx, d):
    lines = [f"# {d.ru}", "",
             f"- **Файлы:** `{d.id}/01 … {len(d.panels):02d}` (формат подписан у каждой картинки)",
             f"- **Где показывается:** {d.when}",
             f"- **Настроение:** {d.mood}",
             f"- **Свет и цвет колоды:** {d.grade}",
             f"- **Картинок:** {len(d.panels)}, из них волна 1: {sum(1 for p in d.panels if wave(d, p) == 'A')}",
             "", "Один чат ChatGPT на колоду. В начало чата приложите листы-эталоны персонажей колоды и (если есть) эталон места, "
             "вставьте блок «Стиль» из `00_style.md`, потом идите по картинкам сверху вниз.", ""]
    cast_all = []
    for p in d.panels:
        for c in p.cast:
            if c != "hero" and c not in cast_all:
                cast_all.append(c)
    if cast_all:
        lines.append("**Лица в этой колоде:** " + ", ".join(f"{CAST[c]['ru']} (`cast_{c}.png`)" for c in cast_all))
        lines.append("")
    for p in d.panels:
        w = wave(d, p)
        prompt, attach = panel_prompt(d, p)
        lines += [f"## {d.id} / {p.key} · {'высокая' if p.sz == 't' else 'широкая'} {SIZE_PX[p.sz][0]}x{SIZE_PX[p.sz][1]} · {wave_label(w)}", "",
                  f"**Сохранить как:** `{d.id}_{p.key}.png`" + (f"   **Приложить:** {', '.join('`'+a+'`' for a in attach)}" if attach else ""), "",
                  "```", prompt, "```", ""]
        caps = "  \n".join((f"{CAST[who]['ru']}: «{t}»" if who in CAST else (f"{who}: «{t}»" if who else t)) for who, t in p.cap)
        lines.append(f"- **Подпись в игре:** {caps}")
        snd = describe_sound(p.snd)
        lines.append(f"- **Звук:** {snd}")
        lines.append(f"- **Камера в игре:** {p.cam or ('наезд' if p.sz == 't' else 'проезд вбок')}")
        lines.append("")
    path = OUT / "decks" / f"{idx:02d}_{d.id}.md"
    path.write_text("\n".join(lines), encoding="utf8")


def describe_sound(events) -> str:
    if not events:
        return "без изменений"
    parts = []
    for e in events:
        op = e.get("do")
        if op == "start":
            parts.append(("фон " if e["layer"] == "amb" else "музыка ") + e["id"])
        elif op == "stop":
            parts.append("стоп " + e["layer"])
        elif op == "silence":
            parts.append("тишина")
        elif op == "play":
            new = " (новый, записать)" if e["id"] in dsl.NEW_FX else ""
            parts.append(f"{e['id']}{new} +{e['at']:.1f}с")
    new_loops = [e["id"] for e in events if e.get("do") == "start" and (e["id"] in dsl.NEW_AMB or e["id"] in dsl.NEW_MUSIC)]
    out = ", ".join(parts)
    if new_loops:
        out += " [нужна запись: " + ", ".join(new_loops) + "]"
    return out


# ------------------------------------------------------------------ документы
def write_style():
    t = ["# Стиль комикса (вставлять в ChatGPT один раз)", "",
         "Ориентир: Max Payne, графические вставки между уровнями. Постановочная фотография с настоящими лицами, "
         "тяжёлая кинематографическая цветокоррекция, чёрные тени, один холодный цвет и один тёплый источник света. "
         "Подписи, рамки и текст в картинках не рисуются: подписи рисует игра, поэтому на каждом языке они свои.", "",
         "## Блок «Стиль» (скопировать целиком)", "", "```", STYLE_LOCK, "```", "",
         "## Как вставлять",
         "- Лучше всего создать в ChatGPT **Проект** «Пустите комикс» и положить блок «Стиль» в его инструкции. Тогда каждый новый чат внутри проекта знает стиль.",
         "- Если проектов нет, вставляйте блок первым сообщением каждого нового чата, потом прикладывайте листы-эталоны и идите по промптам колоды.",
         "- В каждом промпте уже есть короткая версия стиля, цвет колоды, кадр, сцена и приметы лиц. Копировать нужно целиком.", "",
         "## Цвет по актам", ""]
    for name, g in ACT_GRADES:
        t.append(f"- **{name}:** {g}")
    t += ["", "## Что нельзя",
          "- Показывать лицо героя спереди. Герой игрока может быть мужчиной или женщиной, поэтому он только со спины, руки, плечо, силуэт, отражение.",
          "- Показывать упыря целиком. Только силуэт, бледные руки, босые мокрые следы, глаза, которые ловят свет.",
          "- Кровь, расчленёнка, клыки. Ужас строится на недосказанности, и рейтинг магазина от этого выше.",
          "- Любой текст в кадре. Если ChatGPT всё же нарисовал буквы или цифры, нужно перегенерировать: `Redo without any text or letters`.",
          "- Современные предметы: пластик, электрический свет, молнии, джинсы.",
          "", "## Чем пользоваться при сбоях",
          "- Лицо поплыло: `Keep the face exactly identical to the attached reference sheet`, приложите лист-эталон ещё раз.",
          "- Картинка вышла квадратной: `Regenerate as a tall portrait 2:3 / wide landscape 3:2`.",
          "- Слишком светло или цветасто: `Darker, near-black shadows, desaturated, one cold tone and one warm light`.",
          "- Чат «забыл» стиль после 10-15 картинок: откройте новый чат в проекте и продолжайте с места остановки."]
    (OUT / "00_style.md").write_text("\n".join(t), encoding="utf8")


def write_cast():
    t = ["# Персонажи и лица", "",
         "Лица берутся с игровых портретов (`game/assets/folk/realistic`), поэтому герой в комиксе совпадает с тем, кто стоит на поле. "
         "Для каждого персонажа есть **картинка-эталон** `refs/ref_<id>.jpg` (портрет из игры, увеличенный) и **промпт листа-эталона**.", "",
         "## Как делать лист-эталон (шаг А, по одной на персонажа)",
         "1. Новый чат в проекте. Приложите `refs/ref_<id>.jpg`.",
         "2. Вставьте промпт листа ниже. ChatGPT нарисует фотографического «актёра» с тем же лицом: три ракурса головы и фигура в рост на сером фоне.",
         "3. Если лицо не то, напишите `Closer match to the reference: same age, same bones, same eyes, same hair and beard` и повторите.",
         "4. Сохраните как `cast_<id>.png`. Эти файлы потом прикладываются к каждой картинке с этим человеком.", "",
         "Лист-эталон каждого персонажа делается один раз и не идёт в игру.", "",
         "## Правило для сюжетных колод", "",
         "Именные жители могут погибнуть по ходу кампании (смерть насовсем), поэтому в колодах глав их нет. "
         "В главах работают гости, лица сюжета (мельник, Игнат, Анфиса, смотритель) и безымянная толпа. "
         "Лица именных жителей показаны в их предысторях. Игра сама подставит предысторию, когда игрок встретит или потеряет человека.", "",
         "## Привязка портретов (для игры, TASK-117)",
         "Сейчас игра выдаёт портрет жителю случайно из пула по полу. Чтобы Марина в комиксе совпадала с Мариной на поле, "
         "в кампании портрет должен закрепляться за именем. Таблица ниже уже согласована с предысториями.", "",
         "| id | Имя | Роль | Портрет в игре | Пол и возраст |", "|---|---|---|---|---|"]
    for cid, c in CAST.items():
        t.append(f"| {cid} | {c['ru']} | {c['role']} | `{c['sprite']}` | {c['sex']}, {c['age']} |")
    t.append("")
    for cid, c in CAST.items():
        t += [f"## {c['ru']} · {c['role']}", "",
              f"- Эталон из игры: `refs/ref_{cid}.jpg` (портрет `{c['sprite']}`)",
              f"- Лицо: {c['face']}", f"- Одежда: {c['wear']}", "",
              "Промпт листа-эталона:", "", "```",
              "Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, "
              "as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.",
              "Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.",
              f"The face must match the attached portrait exactly: {c['face']}.",
              f"Costume: {c['wear']}.",
              "Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.",
              "```", ""]
    (OUT / "01_cast.md").write_text("\n".join(t), encoding="utf8")


def write_locations():
    t = ["# Эталоны мест (шаг Б, 13 картинок)", "",
         "Чтобы деревня выглядела одинаково во всех кадрах главы, сначала делается один широкий эталонный кадр места. "
         "Его прикладывают к каждой картинке колод этой главы вместе с листами-эталонами лиц. Формат: широкая 1536x1024. Сохранить как `loc_<id>.png`.", ""]
    for lid, ru, en in LOCS:
        t += [f"## loc_{lid} · {ru}", "", "```",
              "Create a wide landscape 3:2 (1536x1024) image.", "STYLE: " + STYLE_SHORT,
              "SHOT: Wide establishing shot, slightly high angle, no people in the foreground.", "SCENE: " + en, "```", ""]
    (OUT / "02_locations.md").write_text("\n".join(t), encoding="utf8")


def write_index(deck_files):
    tot = sum(len(d.panels) for d in dsl.DECKS)
    a = sum(1 for d, p in all_panels() if wave(d, p) == "A")
    t = ["# Список колод", "",
         f"Всего колод: {len(dsl.DECKS)}, картинок: {tot}. Волна 1 (ядро): {a}. Волна 2: {tot - a}.", "",
         "Порядок работы: 1) листы-эталоны лиц ({cast}), 2) эталоны мест (13), 3) волна 1 по колодам сверху вниз, 4) волна 2.", "",
         "| № | Колода | Тип | Всего | Волна 1 | Готово |", "|---:|---|---|---:|---:|---|"]
    for i, d in enumerate(dsl.DECKS, 1):
        wa = sum(1 for p in d.panels if wave(d, p) == "A")
        t.append(f"| {i} | [{d.ru}](decks/{deck_files[d.id]}) | {KIND_RU[d.kind]} | {len(d.panels)} | {wa} | [ ] |")
    (OUT / "INDEX.md").write_text("\n".join(t), encoding="utf8")


def write_storyboard():
    t = ["# Раскадровка для чтения", "",
         "Все подписи комикса в порядке показа. Это то, что игрок прочитает. Править можно здесь: скажите, что поменять, и я внесу в данные.", ""]
    for d in dsl.DECKS:
        t += [f"## {d.ru}", f"*{KIND_RU[d.kind]}. {d.when}.*", ""]
        for p in d.panels:
            for who, text in p.cap:
                if who in CAST:
                    t.append(f"{p.key}. **{CAST[who]['ru']}:** «{text}»")
                elif who:
                    t.append(f"{p.key}. **{who}:** «{text}»")
                else:
                    t.append(f"{p.key}. {text}")
        t.append("")
    (OUT / "storyboard_ru.md").write_text("\n".join(t), encoding="utf8")


README = """# Комикс «Пустите»: как делать картинки в ChatGPT

Задача: для каждой главы, предыстории и финала нарисовать серию кадров в стиле Max Payne (постановочное фото, чёрные тени, фонарь против холода), с узнаваемыми лицами. Игра сама наложит подписи, звук, музыку и движение камеры.

## Объём

- Колод: {decks}. Картинок: {tot}.
- Волна 1 (ядро каждой колоды): {a}. Игра с ними уже выглядит цельно. Волна 2: {b}.
- Перед ними: {cast} листов-эталонов лиц и 13 эталонов мест. Это не идёт в игру, но от них зависит узнаваемость.
- Лимиты ChatGPT на картинки меняются и зависят от тарифа. Если упёрлись, продолжайте на следующий день с того же места.

## Порядок

1. **Проект в ChatGPT.** Создайте проект «Пустите комикс», в инструкции положите блок «Стиль» из `00_style.md`.
2. **Листы-эталоны лиц** (`01_cast.md`). Для каждого человека приложите `refs/ref_<id>.jpg` и вставьте промпт листа. Сохраните как `cast_<id>.png`. Начинайте с гостей и сюжетных лиц (Гордей, Агафья, Ефим, Степан, Аркадий, Игнат, Анфиса, смотритель, Савелий): они в главах.
3. **Эталоны мест** (`02_locations.md`). 13 широких кадров.
4. **Колоды.** Откройте `INDEX.md`, идите по колодам сверху вниз. На колоду один чат: приложите нужные `cast_*.png` и `loc_*.png`, вставьте промпт панели, сохраните файл под указанным именем.
5. **Отдайте мне картинки пачками в чат.** Я сожму их под игру, разложу по папкам и добавлю в сборку. Имена можно не править: пишите в сообщении, какая колода и в каком порядке. Либо используйте имена `a1c1_intro_01.png`, как указано в промптах.

## Требования к файлам

- Высокая картинка 1024x1536, широкая 1536x1024. Формат PNG или JPG из ChatGPT, сжимать самим не нужно.
- В картинке нет текста, рамок и подписей. Если они появились, перегенерируйте.
- Лицо героя игрока не видно (он со спины). Упырь виден только силуэтом.

## Что игра сделает сама

- Подпись внизу, как в Max Payne: тёмная плашка, машинка текста, имя говорящего другим цветом. Текст берётся из `storyboard_ru.md`, на других языках он переводится отдельно.
- Камера: медленный наезд на высоких кадрах, проезд вбок на широких, тряска на ударах, затемнение по краям, зерно и полутон поверх фото, чтобы кадры от разных генераций выглядели одним комиксом.
- Звуковая карта кадра: ветер, дождь, плач, колокол, стук, сердце, музыка (грустная или светлая). Звуков и тем, которых ещё нет, мало: список в `docs/slides/needs_audio.md`.
- Показ: перед главой (вход), после победы (победа), после поражения (поворот), перед актом, после акта (всё сводится к тому, сколько людей дошло), в Книге посёлка (предыстории), в конце кампании (финал).

## Где что лежит

| Файл | Что внутри |
|---|---|
| `00_style.md` | блок «Стиль», запреты, цвет по актам |
| `01_cast.md` | персонажи, приметы лиц, промпты листов-эталонов |
| `02_locations.md` | промпты эталонов мест |
| `INDEX.md` | список колод с отметкой «готово» |
| `decks/` | промпты по колодам, подпись и звук к каждой картинке |
| `storyboard_ru.md` | вся история текстом, для чтения и правок |
| `refs/` | картинки-эталоны лиц из игры |
"""


def write_readme():
    tot = sum(len(d.panels) for d in dsl.DECKS)
    a = sum(1 for d, p in all_panels() if wave(d, p) == "A")
    (OUT / "README.md").write_text(README.format(decks=len(dsl.DECKS), tot=tot, a=a, b=tot - a, cast=len(CAST)), encoding="utf8")


def write_needs_audio():
    amb = Counter(); music = Counter(); fx = Counter()
    for d, p in all_panels():
        for e in p.snd:
            if e.get("do") == "start":
                if e["id"] in dsl.NEW_AMB:
                    amb[e["id"]] += 1
                if e["id"] in dsl.NEW_MUSIC:
                    music[e["id"]] += 1
            if e.get("do") == "play" and e["id"] in dsl.NEW_FX:
                fx[e["id"]] += 1
    for d in dsl.DECKS:
        if d.music in dsl.MUSIC.values() and d.music in dsl.NEW_MUSIC:
            music[d.music] += 0
    t = ["# Звук для комиксов: чего не хватает", "",
         "Раскадровки используют готовые звуки игры и несколько новых. Пока файла нет, игра пропускает событие и играет то, что уже звучало. "
         "Подробнее о звуковой карте: `game/scripts/core/scenes.gd`.", "",
         "## Новая музыка (TASK-123)", "| Имя файла | Настроение | Кадров |", "|---|---|---:|",
         f"| `theme_sad` | скорбная: смычки и редкие ноты фортепиано, минор, медленно, 60-90 с, цикл | {music['theme_sad']} |",
         f"| `theme_hope` | светлая: мажор, тёплый, рассветный, 60-90 с | {music['theme_hope']} |",
         f"| `theme_tense` | тревожная: низкий гул, редкие удары, нарастание | {music['theme_tense']} |",
         f"| `theme_grief` | траурная: хоровой дрон, очень медленно | {music['theme_grief']} |", "",
         "Готовые темы, которые уже в игре: `day`, `night`, `river_theme`, `end_dawn`, `end_dark`, `menu_theme`.", "",
         "## Новые фоновые слои (петли)", "| Имя | Что | Кадров |", "|---|---|---:|"]
    descr = {"amb_fire": "треск большого огня, ветер", "amb_bog": "болото ночью: капли, далёкие птицы, лёгкий ветер",
             "amb_church": "каменный зал: гулкая тишина, дальний хор, капли", "amb_crowd": "толпа: приглушённый ропот"}
    for k, v in sorted(amb.items()):
        t.append(f"| `{k}` | {descr[k]} | {v} |")
    t += ["", "## Новые разовые звуки", "| Имя | Что | Раз в кадрах |", "|---|---|---:|"]
    fd = {"wolf": "вой волка вдали", "crow": "ворона, два-три крика", "fire_crackle": "треск и хлопок углей", "water_drip": "капли в пустом помещении",
          "steps_snow": "шаги по снегу", "chain": "звон цепи и замка", "match": "чирканье спички", "page": "шелест страницы",
          "glass": "звон треснувшего стекла", "wind_gust": "порыв ветра"}
    for k, v in sorted(fx.items()):
        t.append(f"| `{k}` | {fd[k]} | {v} |")
    (OUT / "needs_audio.md").write_text("\n".join(t), encoding="utf8")


# ------------------------------------------------------------------ данные игры
ACT_NAMES = {1: "Деревня", 2: "Мельница", 3: "Монастырь", 4: "Станция"}
ROMAN = {1: "I", 2: "II", 3: "III", 4: "IV"}


def act_of(deck_id: str) -> int:
    """Акт колоды по её имени: a2c1_*, act3_*; колоды без акта дают 0."""
    import re
    m = re.match(r"^a(\d)c\d_", deck_id) or re.match(r"^act(\d)_", deck_id)
    return int(m.group(1)) if m else 0


def flash_to(d) -> int:
    """Сколько первых кадров колоды идёт как воспоминание (сепия): пролог и предыстории без разоблачений."""
    if d.id == "prologue":
        return 6
    if d.kind in ("bio", "guest", "npc") and not d.id.endswith(("_human", "_upyr")):
        return max(0, len(d.panels) - 1)
    return 0


def card_text(d) -> str:
    """Титульная плашка колоды: показывается чёрным экраном перед первым кадром. Только у входов и финалов."""
    if d.id == "prologue":
        return "Предыстория\nТот берег"
    a = act_of(d.id)
    if d.kind == "act_intro":
        return f"Акт {ROMAN[a]}\n{ACT_NAMES[a]}"
    if d.kind == "ch_intro":
        name = d.ru.split(":")[0]
        n = int(d.id[3])
        return f"Акт {ROMAN[a]}, глава {n}\n{name}"
    if d.kind == "finale":
        return "Финал\n" + d.ru.split(": ", 1)[1].capitalize()
    return ""


def write_game_json():
    decks = OrderedDict()
    text = OrderedDict()
    for d in dsl.DECKS:
        key_title = f"sl.{d.id}.title"
        text[key_title] = d.ru
        pan = []
        for p in d.panels:
            lines = []
            for i, (who, t) in enumerate(p.cap):
                k = f"sl.{d.id}.{p.key}.{i}"
                text[k] = t
                lines.append({"who": who, "key": k})
            pan.append(OrderedDict([("file", f"{d.id}/{p.key}"), ("size", p.sz), ("cam", p.cam or ("zoom_in" if p.sz == "t" else "pan_r")),
                                    ("wave", wave(d, p)), ("lines", lines), ("sound", p.snd), ("cast", [c for c in p.cast if c != "hero"])]))
        card = card_text(d)
        entry = OrderedDict([("kind", d.kind), ("act", act_of(d.id)), ("title_key", key_title), ("music", dsl.MUSIC.get(d.music, "")),
                             ("flash_to", flash_to(d)), ("panels", pan)])
        if card:
            text[f"sl.{d.id}.card"] = card
            entry["card_key"] = f"sl.{d.id}.card"
        decks[d.id] = entry
    who = OrderedDict((cid, c["ru"]) for cid, c in CAST.items())
    who.update(EXTRA_WHO)
    cast = OrderedDict((cid, c["sprite"]) for cid, c in CAST.items())
    data = OrderedDict([("schema_version", 1), ("dir", "res://assets/slides/"), ("cast", cast), ("decks", decks)])
    (ROOT / "game" / "config").mkdir(exist_ok=True)
    (ROOT / "game" / "config" / "slides.json").write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf8")
    (ROOT / "game" / "config" / "slides_text.json").write_text(
        json.dumps(OrderedDict([("schema_version", 1), ("who", who), ("ru", text)]), ensure_ascii=False, indent=1), encoding="utf8")


# ------------------------------------------------------------------ картинки-эталоны
def write_refs():
    try:
        from PIL import Image, ImageFilter
    except ImportError:
        print("Pillow нет, refs пропущены")
        return
    refs = OUT / "refs"
    refs.mkdir(parents=True, exist_ok=True)
    base = ROOT / "game" / "assets" / "folk" / "realistic"
    for old in refs.glob("ref_*.jpg"):          # эталоны убранных из состава лиц не должны остаться в папке
        if old.stem[4:] not in CAST:
            old.unlink()
    for cid, c in CAST.items():
        src = base / f"{c['sprite']}.png"
        if not src.exists():
            print("нет спрайта", src)
            continue
        im = Image.open(src).convert("RGBA")
        bg = Image.new("RGBA", im.size, (92, 92, 100, 255))
        bg.alpha_composite(im)
        im = bg.convert("RGB")
        w, h = im.size
        canvas = Image.new("RGB", (1280, 800), (92, 92, 100))
        full = im.resize((int(w * 760 / h), 760), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 80, 2))
        canvas.paste(full, (20, 20))
        head = im.crop((0, 0, w, int(h * 0.24)))
        k = 720 / head.width
        head = head.resize((720, int(head.height * k)), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.6, 90, 2))
        canvas.paste(head, (520, 40))
        canvas.save(refs / f"ref_{cid}.jpg", quality=88)
    print("refs:", len(list(refs.glob("*.jpg"))))


def main():
    errs = check()
    if errs:
        print("\n".join(errs[:80]))
        print(f"ОШИБОК: {len(errs)}")
        sys.exit(1)
    (OUT / "decks").mkdir(parents=True, exist_ok=True)
    for old in (OUT / "decks").glob("*.md"):
        old.unlink()
    deck_files = {}
    for i, d in enumerate(dsl.DECKS, 1):
        write_deck_md(i, d)
        deck_files[d.id] = f"{i:02d}_{d.id}.md"
    write_style(); write_cast(); write_locations(); write_index(deck_files); write_storyboard(); write_readme(); write_needs_audio()
    write_game_json(); write_refs()
    tot = sum(len(d.panels) for d in dsl.DECKS)
    a = sum(1 for d, p in all_panels() if wave(d, p) == "A")
    print(f"колод {len(dsl.DECKS)}, картинок {tot}, волна 1: {a}")


if __name__ == "__main__":
    main()
