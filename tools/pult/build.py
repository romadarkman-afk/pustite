#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Собирает данные «Пульта» (pult_data.json) из docs/slides и tools/pult/audio_data.py.

Запуск: python3 tools/pult/build.py [out.json]
Проверяет русские тексты по правилам Влади (длинное тире, «не X, а Y», запрещённые слова).
"""
import json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SL = ROOT / "docs" / "slides"
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import audio_data as A  # noqa: E402

BAD_WORDS = ["каша", "хаос", "жвачка", "методичка", "истерика", "дедлайн", "на стероидах", "на минималках",
             "честно", "важно понимать", "стоит отметить", "таким образом", "в конечном итоге"]


def check_ru(text, where):
    errs = []
    if "—" in text:
        errs.append("длинное тире")
    if re.search(r"\bне [^.!?\n]{1,40}, а\b", text, re.I):
        errs.append("«не X, а Y»")
    low = text.lower()
    for w in BAD_WORDS:
        if w in low:
            errs.append("слово «%s»" % w)
    return ["%s: %s" % (where, e) for e in errs]


def parse_cast():
    txt = (SL / "01_cast.md").read_text(encoding="utf-8")
    parts = re.split(r"\n(?=## )", txt)
    out = []
    for p in parts:
        m = re.match(r"## (.+?) · (.+)", p)
        ref = re.search(r"refs/ref_(\w+)\.jpg", p)
        face = re.search(r"- Лицо: (.+)", p)
        dress = re.search(r"- Одежда: (.+)", p)
        if not (m and ref and face and dress):
            continue
        out.append(dict(id=ref.group(1), name=m.group(1), role=m.group(2), face=face.group(1).strip().rstrip("."),
                        dress=dress.group(1).strip().rstrip(".")))
    return out


def parse_locs():
    txt = (SL / "02_locations.md").read_text(encoding="utf-8")
    parts = re.split(r"\n(?=## loc_)", txt)
    out = []
    for p in parts:
        m = re.match(r"## (loc_\w+) · (.+)", p)
        code = re.search(r"```\n(.*?)\n```", p, re.S)
        if m and code:
            out.append(dict(id=m.group(1), title=m.group(2).strip(), prompt=code.group(1).strip()))
    return out


def parse_decks():
    frames = []
    for f in sorted((SL / "decks").glob("*.md")):
        txt = f.read_text(encoding="utf-8")
        title = txt.splitlines()[0].lstrip("# ").strip()
        where = (re.search(r"\*\*Где показывается:\*\* (.+)", txt) or [None, ""])[1]
        for sec in re.split(r"\n(?=## )", txt)[1:]:
            h = re.match(r"## (\S+) / (\d+) · (высокая|широкая) (\d+x\d+) · волна (\d)", sec)
            if not h:
                continue
            deck, num, shape, size, wave = h.groups()
            save = re.search(r"\*\*Сохранить как:\*\* `([^`]+)`", sec)
            att = re.search(r"\*\*Приложить:\*\* (.+)", sec)
            code = re.search(r"```\n(.*?)\n```", sec, re.S)
            cap = re.search(r"- \*\*Подпись в игре:\*\* (.+)", sec)
            snd = re.search(r"- \*\*Звук:\*\* (.+)", sec)
            attach = re.findall(r"`([^`]+)`", att.group(1)) if att else []
            frames.append(dict(
                id=Path_stem(save.group(1)), deck=deck, deck_title=title, deck_file=f.name, where=where.strip(),
                n=int(num), shape=shape, size=size, wave=int(wave), save=save.group(1),
                attach=attach, prompt=code.group(1).strip(), caption=cap.group(1).strip() if cap else "",
                sound=snd.group(1).strip() if snd else ""))
    return frames


def Path_stem(s):
    return s.rsplit(".", 1)[0]


def loc_for(deck):
    if deck == "prologue":
        return "loc_river.png"
    m = re.match(r"(a\dc\d)_", deck)
    if m:
        return "loc_%s.png" % m.group(1)
    m = re.match(r"act(\d)_", deck)
    if m:
        return "loc_a%sc1.png" % m.group(1)
    return ""


CAST_SHEET = """Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right. All four views show the same person.
The person: {face}.
Costume: {dress}.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described. Photograph, 85mm lens look, not an illustration, not a painting. No text, letters, numbers, logos or watermark."""

CAST_PORTRAIT = """Create a tall portrait 2:3 (1024x1536) photograph. The attached image is the character reference sheet of this person: same face, same age, same bones, eyes and hair.
Head-and-shoulders portrait in a dim log house, looking straight into the camera with controlled fear. One kerosene lamp off-frame lights half of the face, the other half falls into near-black.
Photo-comic noir look: crushed blacks, one cold steel-blue tone and one warm amber light, visible film grain, shallow depth of field. Real skin texture with pores, no glamour.
Costume as on the sheet: {dress}.
No text, letters, numbers, logos, borders or watermark."""

STYLE_BLOCK = """Photo-comic panel, noir graphic-novel look in the spirit of the Max Payne motion comic. Staged live-action photography: real-looking actors in period costume and practical locations, then a heavy cinematic grade: crushed near-black shadows, one cold dominant tone (steel blue or teal-grey) and one warm light source (kerosene lantern, candle, fire, amber window), strong directional light, visible film grain, light haze, rain, snow or mist in the air. Setting: rural Russia, 1890s. Nothing modern. Faces: ordinary tired people with real skin texture, never glamorous. The monster (upyr) is never shown clearly: only a thin tall silhouette, pale long-fingered hands, wet bare footprints, eyes that catch the light. No fangs, no gore. The hero is never shown from the front: only from behind, a shoulder, hands, a silhouette or a reflection; sheepskin coat, hood or headscarf, a kerosene lantern in the left hand. No text, letters, numbers, logos, speech bubbles, borders or watermark. Keep the key subject inside the central 70% of the frame."""

LOOKS = [
    dict(id="hero_back", title="Герой игрока со спины", shape="высокая", size="1024x1536", save="hero_back.png",
         note="Лицо героя не показывается никогда. Этот лист прикладывают к кадрам, где игрок в кадре.",
         prompt="""Create a tall portrait 2:3 (1024x1536) photographic reference sheet of the hero of a folk-horror game, seen ONLY from behind and from the side, never from the front, no face visible at all.
Four views on a plain mid-grey studio background: from directly behind, from behind at three-quarter left, side view from the left shoulder with the hood hiding the face, and a close view of the left hand holding a kerosene lantern.
Costume: long sheepskin coat with a thick wool hood or headscarf pulled forward, felt boots, a rope belt. Build: ordinary, can read as either a man or a woman.
Photograph, real fabric texture, soft even light. No text, letters, numbers, logos or watermark."""),
    dict(id="upyr_ref", title="Упырь: что можно показывать", shape="широкая", size="1536x1024", save="upyr_ref.png",
         note="Упырь целиком не показывается. Только то, что на этом листе.",
         prompt="""Create a wide landscape 3:2 (1536x1024) image: a visual reference sheet of a folk-horror creature that is never shown clearly, in four photographic panels with thin black gaps between them.
Panel 1: a thin, very tall silhouette standing in a foggy doorway at night, backlit, no face detail.
Panel 2: pale long-fingered hands resting on a frosted window sill from outside.
Panel 3: wet bare footprints crossing dark wooden planks, glistening, amber lantern light from the left.
Panel 4: two eyes catching lantern light like an animal's, out of a pitch-black doorway.
Strictly: no fangs, no blood, no gore, no full body in light. Photographic, heavy cinematic grade, crushed blacks, film grain. No text, letters, numbers, logos or watermark."""),
    dict(id="door_ref", title="Дверь изнутри", shape="высокая", size="1024x1536", save="door_ref.png",
         note="Одна и та же дверь во всех кадрах «стука». Прикладывать к кадрам у двери.",
         prompt="""Create a tall portrait 2:3 (1024x1536) photograph of a heavy plank front door of a Russian log house seen from inside at night: iron strap hinges, a wooden crossbar latch, a small window frosted by breath, a strip of cold blue light under the door, a kerosene lantern glow from the left on the plank floor.
Photo-comic noir look, crushed blacks, one cold tone and one warm light, film grain. No people. No text, letters, numbers, logos or watermark."""),
    dict(id="lantern_ref", title="Керосиновый фонарь", shape="высокая", size="1024x1536", save="lantern_ref.png",
         note="Главный предмет игры. Один и тот же фонарь в руке героя во всех кадрах.",
         prompt="""Create a tall portrait 2:3 (1024x1536) photograph of an old kerosene hurricane lantern held low in a gloved hand, glass slightly sooty, a small steady flame, a circle of amber light on frosted wooden planks, everything else in near-black.
Photo-comic noir look, shallow depth of field, film grain. No face visible. No text, letters, numbers, logos or watermark."""),
]



# ---------------------------------------------------------------------------
# Озвучка (Gemini TTS в Google AI Studio, бесплатно)
# ---------------------------------------------------------------------------
PAUSE = "\n<short pause> <short pause>\n"
NARRATOR = dict(voice="Algenib", style=(
    "Speak in Russian in a low, tired, intimate voice close to the microphone, like the inner monologue of a noir story. "
    "Slow pace, quiet, restrained emotion, no theatrical acting, a little breath between sentences."))
SPEAKERS = {
    "ignat":     ("Rasalgethi", "an old monk of about 75, slow, warm and weary, speaks calmly like a man who has seen everything"),
    "melnik":    ("Alnilam", "a gruff miller of about 60, short phrases, guarded, tired"),
    "pisar":     ("Schedar", "a dry clerk of about 50, even and precise, slightly condescending"),
    "marina":    ("Achernar", "a woman of about 34, soft and tired, a listening quality"),
    "guest":     ("Achird", "a stranger at the door, friendly on the surface, with something held back"),
    "gordey":    ("Orus", "a young soldier of about 25, hoarse from lack of sleep, wary"),
    "extra_thin":("Rasalgethi", "a thin old man of about 72, dry and quiet"),
    "efim":      ("Zubenelgenubi", "a merchant of about 50, casual and wheedling, selling something"),
    "smotritel": ("Iapetus", "a station keeper of about 60, clear, official, tired of waiting"),
}
BARK_TYPES = [
    ("f_old", "Старуха", "Gacrux", "an old village woman of about 65"),
    ("f_mid", "Женщина", "Sulafat", "a woman of about 40"),
    ("f_young", "Девушка", "Leda", "a young woman of about 20"),
    ("m_old", "Старик", "Rasalgethi", "an old village man of about 70"),
    ("m_mid", "Мужчина", "Alnilam", "a man of about 45"),
    ("m_young", "Парень", "Puck", "a young man of about 22"),
    ("boy", "Мальчик", "Leda", "a boy of about 12, a light high voice"),
    ("whisper", "Шёпот", "Enceladus", "a whisperer, only breath and whisper, genderless"),
]
BARK_MOODS = [
    ("calm", "спокойно", ["Хм.", "Ну...", "Так.", "Ага.", "Угу.", "М-м.", "Ну-ну.", "А?"],
     "calm, thoughtful, everyday conversation"),
    ("fear", "страх", ["Ой...", "Тсс...", "Ах!", "Ох...", "Э-э...", "Ай!", "Тише...", "Господи..."],
     "afraid, breathless, voice trembling, quieter"),
    ("grief", "горе", ["Ох...", "Эх...", "Ах...", "Господи...", "М-м...", "Боже...", "О-ох...", "Эх, ты..."],
     "heavy with grief, slow, voice breaking, sighing"),
    ("rage", "гнев", ["Тьфу!", "Эй!", "Ну!", "А ну!", "Хватит!", "Брось!", "Да ну!", "Тьфу ты!"],
     "angry, sharp, loud, clipped"),
]


def voice_tasks(frames_json, text_json):
    d = json.loads(pathlib.Path(frames_json).read_text(encoding="utf-8"))
    ru = json.loads(pathlib.Path(text_json).read_text(encoding="utf-8"))["ru"]
    tasks = []
    for deck, dk in d["decks"].items():
        lines = []
        spoken = []
        for p in dk["panels"]:
            for ln in p["lines"]:
                txt = ru.get(ln["key"], "").strip()
                if not txt:
                    continue
                if ln["who"]:
                    spoken.append((ln["who"], ln["key"], txt))
                else:
                    lines.append((ln["key"], txt))
        title = ru.get(dk["title_key"], deck)
        if lines:
            tasks.append(dict(
                id="vo_" + deck, g="voice", title="%s: рассказчик, %d фраз" % (title, len(lines)), tool="tts",
                shape="озвучка", size="", save="vo_%s.wav" % deck, attach=[],
                voice=NARRATOR["voice"], style=NARRATOR["style"],
                prompt=PAUSE.join(t for _, t in lines),
                note="Число фраз в файле: %d. Между фразами пауза, я разрежу файл по тишине и разложу по кадрам." % len(lines),
                keys=[k for k, _ in lines]))
        for who, key, txt in spoken:
            voice, desc = SPEAKERS.get(who, ("Achird", "a villager"))
            tasks.append(dict(
                id="vo_%s_%s" % (deck, key.split(".")[-2]), g="voice", title="%s: реплика (%s)" % (title, who), tool="tts",
                shape="озвучка", size="", save="vo_%s_%s.wav" % (deck, key.split(".")[-2]), attach=[],
                voice=voice, style="Speak in Russian as %s." % desc, prompt=txt, note="Одна реплика персонажа.", keys=[key]))
    for tcode, tname, voice, desc in BARK_TYPES:
        for mcode, mname, words, mdesc in BARK_MOODS:
            tasks.append(dict(
                id="bark_%s_%s" % (tcode, mcode), g="voice", title="Возгласы: %s, %s" % (tname, mname), tool="tts",
                shape="озвучка", size="", save="bark_%s_%s.wav" % (tcode, mcode), attach=[],
                voice=voice,
                style="Speak in Russian as %s, %s. Each interjection is a separate short sound, spoken naturally, with a pause between them." % (desc, mdesc),
                prompt=PAUSE.join(words),
                note="8 коротких возгласов. Звучат над головой жителя, когда он говорит в чате. Я разрежу файл на 8 звуков.",
                keys=[]))
    return tasks


def main():
    out_path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path("pult_data.json")
    cast = parse_cast()
    locs = parse_locs()
    frames = parse_decks()
    errors = []
    tasks = []

    # порядок героев: сначала те, кто в главах
    first = ["gordey", "agafya", "efim", "stepan", "pisar", "ignat", "anfisa", "smotritel", "melnik"]
    cast.sort(key=lambda c: (0, first.index(c["id"])) if c["id"] in first else (1, 0))

    for c in cast:
        tasks.append(dict(id="cast_" + c["id"], g="heroes", title="%s · %s" % (c["name"], c["role"]), tool="img",
                          shape="широкая", size="1536x1024", save="cast_%s.png" % c["id"],
                          attach=[], prompt=CAST_SHEET.format(face=c["face"], dress=c["dress"]),
                          note="Лист-эталон. Новое лицо в фотореализме: из него все кадры берут внешность."))
    for c in cast:
        tasks.append(dict(id="portrait_" + c["id"], g="portraits", title="Портрет: %s" % c["name"], tool="img",
                          shape="высокая", size="1024x1536", save="portrait_%s.png" % c["id"],
                          attach=["cast_%s.png" % c["id"]], prompt=CAST_PORTRAIT.format(dress=c["dress"]),
                          note="Портрет для карточки жителя, двери и Книги посёлка. Приложи лист героя."))
    for l in LOOKS:
        tasks.append(dict(id=l["id"], g="looks", title=l["title"], tool="img", shape=l["shape"], size=l["size"],
                          save=l["save"], attach=[], prompt=l["prompt"], note=l["note"]))
    for l in locs:
        tasks.append(dict(id=l["id"], g="places", title=l["title"], tool="img", shape="широкая", size="1536x1024",
                          save=l["id"] + ".png", attach=[], prompt=l["prompt"],
                          note="Эталон места: приложи к кадрам этой главы, чтобы деревня везде выглядела одинаково."))
    for s in A.SONGS:
        full = ("Create a full song with vocals.\nSTYLE: %s\n%s\n\nLYRICS (keep the section tags and sing the lyrics in order):\n%s"
                % (s["style"], A.SONG_STYLE_COMMON, s["lyrics"]))
        errors += check_ru(s["lyrics"], s["id"])
        tasks.append(dict(id=s["id"], g="songs", title=s["title"], tool="music", shape="песня", size="", save=s["file"],
                          attach=[], prompt=full, lyrics=s["lyrics"], note=s["where"]))
    for t in A.theme_tracks():
        tasks.append(dict(id=t["id"], g="music", title=t["title"], tool="music", shape="трек", size="~90 с",
                          save=t["file"], attach=[], prompt=t["prompt"], note=t["where"]))
    for t in A.chapter_tracks():
        tasks.append(dict(id=t["id"], g="music", title=t["title"], tool="music", shape="трек", size="~90 с",
                          save=t["file"], attach=[], prompt=t["prompt"],
                          note="Звучит в главе в течение дня" if t["kind"] == "day" else "Звучит ночью, пока стучат"))
    for fr in frames:
        att = list(fr["attach"])
        loc = loc_for(fr["deck"])
        note = fr["caption"]
        g = "frames1" if fr["wave"] == 1 else "frames2"
        errors += check_ru(fr["caption"], fr["id"])
        tasks.append(dict(id=fr["id"], g=g, deck=fr["deck"], deck_title=fr["deck_title"], where=fr["where"],
                          title="%s · кадр %02d" % (fr["deck_title"], fr["n"]), tool="img", shape=fr["shape"],
                          size=fr["size"], save=fr["save"], attach=att, loc=loc, prompt=fr["prompt"], note=note,
                          sound=fr["sound"]))

    vt = voice_tasks(ROOT / "game" / "config" / "slides.json", ROOT / "game" / "config" / "slides_text.json")
    tasks += vt
    data = dict(version=1, style_block=STYLE_BLOCK, tasks=tasks)
    out_path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    by = {}
    for t in tasks:
        by[t["g"]] = by.get(t["g"], 0) + 1
    print("задач:", len(tasks), by)
    if errors:
        print("НАРУШЕНИЯ ТЕКСТА:")
        for e in errors:
            print(" ", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
