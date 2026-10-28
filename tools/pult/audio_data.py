# -*- coding: utf-8 -*-
"""Песни и музыка для Lyria (Gemini): промпты и тексты.

Игровые тексты и тексты песен подчиняются правилам Влади: без длинного тире, без «не X, а Y»,
без шаблонных слов. Проверяет tools/pult/build.py.
"""

SONG_STYLE_COMMON = (
    "Russian lyrics, sung in Russian. Rural Russia in the 1890s, river fog, kerosene lantern light, "
    "folk horror. Warm analog recording, close and intimate, no electronic synths, no auto-tune. "
    "Follow the lyrics below exactly, in order, with the section tags."
)

SONGS = [
    dict(
        id="song_pustite",
        title="«Пустите» (главная песня)",
        where="Главное меню (играет, пока открыто меню) и последние кадры концовки «упырь». Главная песня игры, как в Alan Wake: узнаётся с первых нот.",
        file="song_pustite.mp3",
        style=(
            "Dark Slavic folk-rock ballad, 72 BPM, A minor. Male baritone, gravelly and tired, almost spoken in the verses, "
            "full-voiced in the chorus. Fingerpicked acoustic guitar, bayan accordion drone, low cello, frame drum like a "
            "slow heartbeat, a distant female choir only in the chorus, one church bell hit at the very end. "
            "Sparse verses, big chorus, quiet outro. About 3 minutes."
        ),
        lyrics="""[Verse 1]
Догорел закат над чёрною рекой,
Хлопнул ставень, лязгнул тяжкий крюк.
Я стою у двери, мокрый и худой,
Постучу ещё, пока не стих мой стук.

[Verse 2]
Вы считаете шаги по скрипучим полам,
В щель глядите, где пахнет рекой.
Вы же знали мой голос, вы звали меня,
Вы делили со мной хлеб и покой.

[Chorus]
Пустите, пустите, пока не рассвет,
Пока не погас ваш последний огонь.
Я свой, я с вами, мне некуда деться,
Положите на дверь свою тёплую ладонь.

[Verse 3]
Кто из вас живой, кто из вас уже нет,
Днём у всех одно лицо, ночью видней.
Я принёс вам имя, я принёс вам свет,
Только дверь откройте, и станет теплей.

[Bridge, whispered]
Раз стучу. Два стучу. Три.
Слышите, как бьётся там внутри?

[Final Chorus]
Пустите, пустите, пока не рассвет,
Пока не погас ваш последний огонь.
Я свой или чужой, вы решите сами,
Положите на дверь свою тёплую ладонь.

[Outro, one bell]
Пустите.""",
    ),
    dict(
        id="song_lullaby",
        title="«Колыбельная для тех, кто за дверью»",
        where="Конец акта I: играет под кадрами итога, когда акт закончен (любой исход). Поёт старая женщина, почти шёпотом.",
        file="song_lullaby.mp3",
        style=(
            "Slow Russian folk lullaby, 56 BPM, D dorian. Elderly female alto, warm, cracked, very close to the microphone, "
            "almost whispering. Hurdy-gurdy drone, soft gusli, a single low flute, faint creak of a wooden cradle as rhythm. "
            "No drums. Tender and unsettling at the same time. About 2 minutes 30 seconds."
        ),
        lyrics="""[Verse 1]
Баю-баю, спит река,
Спят над речкой облака.
Дверь закрыта на засов,
В печке тихий треск дров.

[Verse 2]
Кто-то ходит у ворот,
Кто-то ждёт, а кто-то врёт.
Ты не слушай, спи, дитя,
Ночь пройдёт, придёт заря.

[Chorus]
Ай-люли, ай-люли,
Сторожат нас фонари.
Если голос позовёт,
Ты молчи, он подведёт.

[Verse 3]
Баю-баю, спит вода,
Тёмный берег без следа.
Кто из нас живой, кто нет,
Знает только лунный свет.

[Outro, hummed]
Ай-люли... ай-люли...""",
    ),
    dict(
        id="song_mill",
        title="«Колесо» (акт II, мельница)",
        where="Конец акта II: играет под кадрами итога (любой исход). Осень, дождь, паводок.",
        file="song_mill.mp3",
        style=(
            "Melancholic Russian autumn waltz in 3/4, 88 BPM, G minor. Female mezzo-soprano with a slightly rough voice, "
            "restrained, never theatrical. Accordion, fiddle, pizzicato double bass, brushes on a wet wooden floor as percussion, "
            "rain in the far background, a wooden water-wheel creak as a recurring accent. "
            "The waltz keeps trying to dance and keeps stumbling. About 3 minutes."
        ),
        lyrics="""[Verse 1]
Поднялась вода у мельничных ворот,
Колесо скрипит и не даёт уснуть.
Кто-то чужой через брод идёт,
Мокрый до костей, и некуда свернуть.

[Verse 2]
Мы пустили троих, и осталось двое,
Мы пустили двоих, и остался один.
Мельник молчит, глядя на запоры,
Дождь стучит по стёклам, как чужой.

[Chorus]
Мели, мельница, мели,
Что осталось от земли?
Хлеб да слёзы, дождь да мгла,
И вода, что всё взяла.

[Verse 3]
Под водой остался чей-то старый дом,
Чьи-то письма плавают у плетня.
Если кто придёт, мы его спросим, кто он,
И запомним голос, что был до меня.

[Chorus]
Мели, мельница, мели,
Что осталось от земли?
Хлеб да слёзы, дождь да мгла,
И вода, что всё взяла.""",
    ),
    dict(
        id="song_bell",
        title="«Колокол» (акт III, монастырь)",
        where="Конец акта III: играет под кадрами итога (любой исход, в том числе суд). Зима, метель, каменные своды.",
        file="song_bell.mp3",
        style=(
            "Slow Russian liturgical-folk hymn with a dark rock undercurrent, 50 BPM, B phrygian. "
            "A low male bass-baritone lead with a men's choir answering in the refrain, no instruments in the first verse. "
            "Pipe organ pedal notes, deep monastery bell hits on the downbeat of each chorus, distant wind, stone-hall reverb. "
            "Solemn and cold. About 3 minutes."
        ),
        lyrics="""[Verse 1, solo voice, almost no music]
Метель замела дорогу к воротам,
Монахи считают дыханье в ночи.
Кто стукнул в калитку, откроем ли, нет?
Молчит у порога горящая свеча.

[Chorus, choir answers]
Колокол бьёт, колокол бьёт,
Один удар на каждый дом.
Колокол бьёт, колокол бьёт,
Кто-то уже за столом.

[Verse 2]
В крипте записаны наши имена,
Чёрные строки зачёркнуты вновь.
Совесть тяжелей, чем ключи от замка,
А вера ушла за последним огнём.

[Chorus, choir answers]
Колокол бьёт, колокол бьёт,
Один удар на каждый дом.
Колокол бьёт, колокол бьёт,
Кто-то уже за столом.

[Outro, three slow bell hits]
Один. Два. Три.""",
    ),
    dict(
        id="song_train",
        title="«Последний поезд» (акт IV, станция)",
        where="Концовки «многие» и «немногие»: начинается на третьем кадре финала и идёт до конца.",
        file="song_train.mp3",
        style=(
            "Bittersweet folk-pop ballad with a train rhythm, 96 BPM, E minor moving to E major in the last chorus. "
            "Female and male duet, tender, tired, honest. Upright piano, acoustic guitar, brushed snare imitating a steam train, "
            "a distant whistle, soft strings rising in the last chorus. Spring thaw, mud and fog, a little light at the end. "
            "About 3 minutes 30 seconds."
        ),
        lyrics="""[Verse 1, female]
Тает снег на шпалах, пахнет сыростью весны,
На перроне люди держат узелки.
Список на листочке, в нём не все имена,
И тебя в нём нет, хоть ты и рядом был.

[Verse 2, male]
Я держал фонарь всю эту долгую зиму,
Я считал твои шаги из-за двери.
Мы теперь не знаем, кто из нас какой,
Только поезд знает и молчит.

[Chorus, duet]
Поезд идёт на рассвете,
Свет на рельсах, дым над рекой.
Если уехать успели,
Значит, дорога была не зря такой.

[Verse 3, female]
Кто-то остался стоять на платформе,
Кто-то махнул из последнего окна.
Мы не вернёмся к этому берегу.
Он нас будет помнить всегда.

[Final Chorus, duet, major key]
Поезд идёт на рассвете,
Свет на рельсах, дым над рекой.
Если уехать успели,
Значит, дорога была не зря такой.

[Outro, piano alone]
Тихо. Тихо. Тихо.""",
    ),
    dict(
        id="song_shore",
        title="«Тот берег» (концовка)",
        where="Концовка «тот берег»: игрок уходит за реку. Тихая песня под последние три кадра.",
        file="song_shore.mp3",
        style=(
            "Quiet, eerie, beautiful ballad, 60 BPM, C minor. Duet of a young female voice and a male baritone, "
            "close and breathy, harmonizing in thirds. Soft piano, bowed double bass, reversed bell swells, "
            "water lapping. Slow build to a calm, unresolved ending. About 3 minutes."
        ),
        lyrics="""[Verse 1, female]
За рекой горит одна свеча,
Кто-то машет мне оттуда.
Я иду по воде, и вода молчит,
Я не слышу, что мне будет.

[Verse 2, male]
Там все те, кого я хоронил,
Там стоит накрытый стол.
Я иду на берег, где нет дверей,
Где никто уже не шёл.

[Chorus, duet]
Тот берег ближе, чем кажется нам,
Тот берег тихо зовёт.
Кто пустит нас, если мы сами там,
И кто за нами придёт?

[Verse 3, duet]
Позади остались двери и дома,
Лампа гаснет на крыльце.
Если кто-то спросит, откуда мы,
Мы ответим, что в конце.

[Outro, spoken softly]
Пустите.""",
    ),
]

# ---------------------------------------------------------------------------
# Инструментальная музыка. Профили глав взяты из tools/make_stage_music.py.
# ---------------------------------------------------------------------------

MUSIC_COMMON = (
    "Instrumental only, no vocals, no lyrics. Seamless loop: the last seconds fade down to the same texture as the first seconds. "
    "Length about 90 seconds. Loudness steady, no sudden peaks, no long silences. Cinematic folk horror, 1890s rural Russia. "
)

ACT_DAY = {
    1: "Lonely hurdy-gurdy, soft plucked gusli and a low wooden flute, sparse melody, warm and uneasy, slow walking pace",
    2: "Waltz in 3/4: accordion, fiddle and pizzicato bass, wooden clicks like a water wheel, damp and tired, a melody that keeps losing its way",
    3: "Pipe organ, wordless male choir, a far monastery bell, slow cold sustained notes, stone-hall reverb, winter silence between phrases",
    4: "Upright piano, cold glass bells, distant rail rhythm made of soft clacks, strings holding one warm note, fragile hope with a crack in it",
}
ACT_NIGHT = {
    1: "Low drone, wind, one hurdy-gurdy note every few seconds, a faint knock-like thump far away, no melody, slowly rising dread",
    2: "Deep drone, dripping water, creaking wood, one detuned fiddle note that appears and disappears, flood approaching",
    3: "Wordless low choir drone, stone-hall silence, two distant bell strikes, breath-like swells, no rhythm",
    4: "Metallic drone, distant rails, a single cold piano note repeated and slowly detuned, fog, a faraway whistle once",
}

# ключ, название, акт, темп, лад, что происходит
CHAPTERS = [
    ("a1c1", "Стук", 1, 80, "D dorian", "первая ночь, первый стук в дверь"),
    ("a1c2", "Туман", 1, 76, "E dorian", "голоса в тумане над рекой"),
    ("a1c3", "Прощание", 1, 68, "A minor", "лодка уходит, тихая скорбь"),
    ("a2c1", "Брод", 2, 96, "D dorian", "мельница, брод, чужое присутствие"),
    ("a2c2", "Чужаки", 2, 88, "G minor", "чужие в доме, недоверие"),
    ("a2c3", "Половодье", 2, 80, "C-sharp minor", "вода у порога, паника"),
    ("a3c1", "Ворота", 3, 54, "D phrygian", "монастырские ворота, книга поручительств"),
    ("a3c2", "Колокол", 3, 50, "F-sharp minor", "колокол бьёт номер дома"),
    ("a3c3", "Крипта", 3, 48, "B phrygian", "суд в крипте"),
    ("a4c1", "Полустанок", 4, 90, "A phrygian", "станция, ожидание поезда"),
    ("a4c2", "Список", 4, 96, "E minor", "список на поезд, предательство"),
    ("a4c3", "Последний поезд", 4, 100, "C minor", "последняя ночь, поезд идёт на рассвете"),
]

DARK_NOTE = {
    1: "Mood: calm surface, small unease.",
    2: "Mood: unease grows, the weather is part of the music.",
    3: "Mood: heavy and solemn, almost no warmth.",
    4: "Mood: tense, pushing forward, tiny light far ahead.",
}


def chapter_tracks():
    out = []
    for i, (key, name, act, bpm, mode, what) in enumerate(CHAPTERS):
        darker = {"a1c1": "", "a1c2": " A little darker than the first chapter.", "a1c3": " Sorrowful, ending the act.",
                  "a2c1": "", "a2c2": " A little darker than the first chapter.", "a2c3": " Frantic undertone, ending the act.",
                  "a3c1": "", "a3c2": " Darker than the first chapter.", "a3c3": " Darkest of the act, a verdict hangs in the air.",
                  "a4c1": "", "a4c2": " Darker than the first chapter, a betrayal is near.", "a4c3": " Darkest of the game, the finale."}[key]
        day = (f"{MUSIC_COMMON}Chapter «{name}» ({what}). DAY version. {ACT_DAY[act]}. "
               f"Tempo about {bpm} BPM, {mode}. {DARK_NOTE[act]}{darker}")
        night = (f"{MUSIC_COMMON}Chapter «{name}» ({what}). NIGHT version. {ACT_NIGHT[act]}. "
                 f"Root and mode as the day track ({mode}), but no steady tempo. Mood: waiting behind a locked door.{darker}")
        out.append(dict(id=f"day_{key}", title=f"{name}: день", key=key, kind="day", file=f"day_{key}.mp3", prompt=day))
        out.append(dict(id=f"night_{key}", title=f"{name}: ночь", key=key, kind="night", file=f"night_{key}.mp3", prompt=night))
    return out


THEMES = [
    ("theme_act1", "Тема акта I", "Пролог и итог акта I.",
     "Lonely hurdy-gurdy and a low bowed fiddle, slow sparse melody in minor, long silences, distant wind, a single plucked string now and then, cold anxious calm before a storm."),
    ("theme_act2", "Тема акта II", "Пролог и итог акта II.",
     "Water-wheel rhythm made of wooden clicks, deep drone, detuned folk fiddle melody that keeps losing its way, wet creaking wood, damp autumn dread."),
    ("theme_act3", "Тема акта III", "Пролог и итог акта III.",
     "Wordless male choir in a stone hall, slow cold sustained notes, one far bell, no melody beyond three notes, winter silence between phrases."),
    ("theme_act4", "Тема акта IV", "Пролог и итог акта IV.",
     "Steel rails rhythm far away, distant train whistle, warm string note slowly rising, fragile hope with a crack in it, spring morning in fog."),
    ("theme_pair", "Тема пары", "Утро, когда живой потерял пару.",
     "Solo cello with soft piano, one simple tender melody, very quiet, grief without melodrama, ends unresolved."),
    ("theme_climax", "Кульминация", "У двери в последнюю ночь главы.",
     "Pulse and slow build, no melody so that the knocking is not drowned, low strings tremolo, a heartbeat-like thump that gets slightly faster, dry and close."),
    ("theme_sad", "Грустная тема комиксов", "43 кадра комиксов.",
     "Sorrowful: bowed strings and rare notes of a piano, minor key, slow, intimate."),
    ("theme_hope", "Светлая тема комиксов", "12 кадров комиксов.",
     "Hopeful: warm major key, sunrise feeling, soft strings and a gentle piano, a little bell, never sugary."),
    ("theme_tense", "Тревожная тема комиксов", "27 кадров комиксов.",
     "Tense: low drone, rare hits, slow crescendo, no melody, breathing room between hits."),
    ("theme_grief", "Траурная тема комиксов", "8 кадров комиксов.",
     "Funereal: choral drone, very slow, one low bell far away, no melody."),
    ("menu_theme", "Музыка меню (инструментал)", "Меню, когда песня не играет.",
     "Slow dark folk instrumental that quotes no song: fingerpicked guitar, accordion drone, cello, distant bell, a lantern-lit room feeling, inviting and dangerous."),
    ("river_theme", "Тема реки", "Предыстория, кадры с рекой.",
     "River at dusk: slow low strings, reversed bell swells, water texture, a mournful distant fiddle, mystery."),
    ("end_dawn", "Рассвет после ночи", "Экран итога, когда пережили ночь.",
     "Soft relief after a terrible night: warm strings and a simple piano line, birds far away, major-ish but tired."),
    ("end_dark", "Тёмный конец", "Экран итога, когда проиграли.",
     "Cold empty finality: low drone, a single detuned piano note, wind, silence at the end."),
]


def theme_tracks():
    out = []
    for fid, title, where, body in THEMES:
        out.append(dict(id=fid, title=title, where=where, file=f"{fid}.mp3",
                        prompt=MUSIC_COMMON + body))
    return out
