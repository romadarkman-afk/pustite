"""Главы акта I и акта II: вход (5 картинок), победа (4), поворот (4)."""
from dsl import deck, S, N, D


def trio(cid, title, place, grade_in, grade_win, grade_tw):
    """Три колоды главы. Возвращает (вход, победа, поворот)."""
    a = deck(f"{cid}_intro", f"{title}: вход", "ch_intro", f"Перед главой «{title}» ({place})", grade_in,
             "Нарастающая тревога. Музыка: ночная или тревожная.", music="night")
    b = deck(f"{cid}_win", f"{title}: победа", "ch_win", f"После победы в главе «{title}»", grade_win,
             "Усталое облегчение. Музыка: светлая, рассвет.", music="dawn")
    c = deck(f"{cid}_twist", f"{title}: поворот", "ch_twist", f"После поражения или поворота в главе «{title}»", grade_tw,
             "Страх, горе, раскрытие. Музыка: грустная или траурная.", music="sad")
    return a, b, c


# ---------------------------------------------------------------- a1c1 Стук
a, b, c = trio("a1c1", "Стук", "Нижний Посад, лето, берег реки",
               "summer dusk: amber on the horizon fading into steel blue, river fog, one warm lantern",
               "first clean dawn light, pale gold on wet roofs, gentle mist, exhausted warmth",
               "cold blue pre-dawn, dew on dark ground, a single weak lantern, deep shadows")
a.add("w", "Extreme wide, locked-off, slightly high",
      "Dusk at a wide river: a dirt road ends at the water, a flat wooden ferry raft on a rope, fog on the water, spruce on both banks, a lantern on the raft.",
      [N("Сумерки. Дорога кончается у реки. Дальше только паром.")], S("river", "river"), tier="A", cam="pan_r")
a.add("t", "Over-the-shoulder, low",
      "From behind a hooded figure with a kerosene lantern on a ferry raft looking across the black water at a distant silhouette holding a lantern on the far bank, fog.",
      [N("С того берега кто-то зовёт меня по имени.")], S(fx=[("call_far", 0.6, -8)]), tier="A", cast=("hero",), cam="zoom_in")
a.add("t", "Tight close-up, lantern light from below",
      "A weathered woman ferry-keeper with her finger raised to her lips, her face lit from below by a lantern, oilskin cape wet with spray, eyes locked on the viewer.",
      [D("marina", "Не отвечай. Оно запоминает голоса.")], S(fx=[("breath", 0.4, -14)]), tier="A", cast=("marina",), cam="zoom_in")
a.add("t", "Close on hands, shallow depth of field",
      "A rope-scarred hand cupped over a lantern flame snuffing it out, last wisp of smoke, the river suddenly black with only a faint glimmer.",
      [N("Перевозчица гасит фонарь. До деревни идём молча.")], S("dusk", fx=[("tick", 0.8, -10)], music="tense"), tier="B", cast=("marina",), cam="zoom_in")
a.add("t", "POV from inside, door filling the frame",
      "Night inside an izba: the heavy wooden door in front of the camera, a hooded figure from behind with a lantern held low, three shadows of knocking knuckles trembling in the crack of light under the door.",
      [N("Ночь. В дверь стучат.")], S("night", "tense", fx=[("knock", 0.5, -4), ("knock", 1.1, -4), ("knock", 1.7, -3)]),
      tier="A", cast=("hero",), cam="zoom_in")

b.add("w", "Wide, dawn, slightly high",
      "A village at the first dawn light: wet thatched and plank roofs, mist in the lane, closed doors all intact, smoke starting from one chimney, a rooster on a fence.",
      [N("Рассвет. Двери целы, и это уже много.")], S("day", "dawn", fx=[("dawn", 0.3, -8), ("life_hens", 1.2, -14)]), tier="A", cam="pan_l")
b.add("t", "Medium, soft window light",
      "A stranger asleep by a cold brick stove, covered by a sheepskin coat, one boot off, a lantern burned down beside them on the floor, quiet morning light.",
      [N("Утро. Тот, кого я впустил, спит у печи под моим тулупом.")], S(), tier="A", cam="zoom_out")
b.add("t", "Close on hands, warm",
      "Two hands wrapped around a clay cup of hot water, a piece of dark bread, steam, a wooden table with a lit lamp not yet blown out.",
      [D("guest", "Я не забуду, кто открыл мне ночью.")], S(), tier="B", cam="zoom_in")
b.add("w", "Wide, flat daylight, tension",
      "The village well in daylight, people standing around it and looking at each other with wary eyes, buckets on the ground, no one smiling.",
      [N("Одну ночь пережили. Теперь надо решить, кто из нас врёт.")], S("murmur"), tier="A", cam="pan_r")

c.add("w", "Wide, high angle, dew",
      "Long bare footprints in dew and mud leading to a closed door, a trampled spot where someone stood a long time, grey pre-dawn light.",
      [N("На земле у порога следы. Кто-то долго стоял на пороге.")], S("dusk", "sad"), tier="A", cam="zoom_in")
c.add("t", "Interior low angle at the door",
      "The inside of the door at floor level: a thin line of grey light under it broken by two long shadows of feet standing still outside.",
      [N("Стука больше нет. Я слышу, как за дверью кто-то дышит.")], S(fx=[("breath_2", 0.6, -8), ("floorboard", 2.0, -10)]), tier="A", cam="zoom_in")
c.add("t", "Close, low, roadside",
      "A pair of empty worn boots standing at the edge of the road in tall wet grass, laces untied, a lantern on its side with the glass cracked.",
      [N("Следы обрываются у дороги. Тот, кто стучал, не вернулся.")], S(), tier="B", cam="zoom_in")
c.add("t", "Group over-the-shoulder, accusing stares",
      "Villagers at the well turned toward the camera, their faces tight and accusing in cold pre-dawn light, in the foreground the back of a hooded head with a lantern.",
      [N("Все смотрят на меня. Никто не говорит вслух, что дверь осталась закрытой.")], S("murmur", fx=[("whisper", 1.0, -12)]), tier="A", cast=("hero",), cam="zoom_in")

# ---------------------------------------------------------------- a1c2 Туман
a, b, c = trio("a1c2", "Туман", "Горелый Починок, лето, торфяной дым",
               "summer day gone grey: peat smoke and river fog, sun a pale disc, burnt timbers, ash-grey light",
               "fog thinning, pale sun breaking through, ash-gold, relief",
               "thick fog lit from within by a lantern, black silhouettes, cold green-grey")
a.add("w", "Wide establishing, hazy",
      "A burned-out hamlet half-swallowed by peat smoke and fog, charred beams, a tar kiln and a barn-drying shed, a crane well, one thin line of smoke from a surviving izba.",
      [N("Горелый Починок. Здесь когда-то сгорело всё, что могло гореть. Торф дымит до сих пор.")], S("wind", "night"), tier="A", cam="pan_r")
a.add("t", "Medium, two figures on the road",
      "Two people arriving on a dirt road out of fog: a young soldier in an oversized greatcoat and a woman in a black shawl pulling a cart covered with sackcloth, seen from the front but small in the frame.",
      [N("Двое приходят с тракта. Солдат в шинели не по росту и вдова с телегой под рогожей.")], S(fx=[("tap", 1.0, -14)]), tier="A", cast=("gordey", "agafya"), cam="zoom_in")
a.add("t", "Close, sleeping soldier, hard side light",
      "A young shaved-headed soldier asleep sitting upright against a wall, a hunting knife gripped in his hand, his mouth tense even in sleep.",
      [D("gordey", "Мой полк стоит за рекой. Скоро за мной придут.")], S(fx=[("breath", 0.5, -14)]), tier="B", cast=("gordey",), cam="zoom_in")
a.add("t", "Medium low, lamp glow",
      "A widow in a black shawl bent over a cart covered in sackcloth, singing softly to what is under it, a lantern at her feet; across the street a dog stares and will not come close.",
      [N("По вечерам вдова поёт под рогожей. Ответа нет.")], S(fx=[("whisper", 0.8, -14), ("life_dog", 2.5, -12)]), tier="B", cast=("agafya",), cam="zoom_in")
a.add("w", "Wide, fog bank",
      "Thick white fog rolling off the river into the lane between houses, lantern lights only glowing blobs, a few dark upright shapes that could be people or posts.",
      [N("С реки поднимается туман. Упыря надо найти до третьей ночи.")], S("wind", "tense"), tier="A", cam="pan_l")

b.add("w", "Wide, line of people, dawn",
      "At dawn a lone figure walks away from a line of villagers standing at the hamlet fence and into the fog, their lanterns hanging low, nobody speaks.",
      [N("Утром он уходит за околицу. Никто не кричит и не просит.")], S("wind", "sad", fx=[("exile", 0.5, -8)]), tier="A", cam="pan_r")
b.add("t", "Medium, hands at a pump",
      "Hands scrubbing in cold well water by a crane well, dirty water running off, in the background blurred figures avoiding eye contact.",
      [N("Мы смываем с рук ночь и не смотрим друг другу в глаза.")], S("day"), tier="B", cam="zoom_in")
b.add("t", "Medium, rooftops, light breaking",
      "Peat smoke thinning over burnt rafters, a first bar of sunlight on a wet plank roof and a blackened chimney.",
      [N("Дым редеет. Впервые за три дня видно солнце.")], S("day", "dawn"), tier="A", cam="pan_u")
b.add("w", "Wide, interior, long table",
      "A long table in a barn with people eating porridge in silence, an empty stool among them, lamp light, steam.",
      [N("Ужинаем вместе. Пустой стул никто не занимает.")], S("murmur"), tier="A", cam="pan_l")

c.add("w", "Wide, night, fence line",
      "A lone man standing outside a village fence at night, a lantern held by villagers behind the fence lighting his back, fog around his knees; he is looking in, not out.",
      [N("Мы выгнали человека. Ночью он стоит у ограды и зовёт нас по именам.")], S("night", "sad", fx=[("call_far", 1.0, -8)]), tier="A", cam="pan_r")
c.add("t", "Close-up, face pressed at a window",
      "A frightened thin old man's face pressed against a small window from outside, his breath fogging the glass, bruised, begging eyes, a lantern flame reflected in the pane.",
      [D("extra_thin", "Я человек! Я такой же, как вы!")], S(fx=[("human_cry_m", 0.4, -6), ("tap", 1.5, -10)]), tier="A", cast=("extra_thin",), cam="zoom_in")
c.add("t", "High angle on the floor",
      "Wet bare footprints crossing a plank floor inside an izba to a bed with a drawn curtain, a thin trail of river water, grey morning light.",
      [N("Утром в доме следы. Босые, мокрые. Они ведут к постели.")], S(fx=[("water_drip", 0.8, -10)]), tier="B", cam="zoom_in")
c.add("t", "Over-the-shoulder, fog",
      "From behind a hooded figure in thick fog, a tall slim dark silhouette standing just beyond the lantern's reach, two eyes catching the light like an animal's.",
      [N("Туман всё скрывает. Даже то, что стоит у меня за спиной.")], S(fx=[("breath_3", 0.8, -8)]), tier="A", cast=("hero",), cam="zoom_in")

# ---------------------------------------------------------------- a1c3 Прощание
a, b, c = trio("a1c3", "Прощание", "Старый Перевоз, лето, гроза на реке",
               "summer storm: bruised purple-grey sky, lightning flashes, cold rain, warm lantern points",
               "storm clearing at dawn, wet gold light on the water, small boats, relief",
               "grey morning after the storm, flat cold light, mud and torn rope, no warmth")
a.add("w", "Wide, storm on the river",
      "A river ferry crossing in a storm: boats tied to a wooden pier straining on ropes, lightning on the far bank, a watch tower with a lantern, dark spruce.",
      [N("Старый Перевоз. Последние ночи в деревне. Перед рассветом все уходят к мельнице.")], S("rain_heavy", "tense", fx=[("scare", 3.0, -18), ("thunder", 1.5, -6)]), tier="A", cam="pan_r")
a.add("t", "Medium close, warm friendly face",
      "A round-faced travelling merchant in a fur hat opening a wooden box full of thistle-and-salt amulets, smiling crookedly, rain on his hat brim, lantern light.",
      [D("efim", "Дёшево отдам. Бедным даром.")], S(fx=[("tap", 0.8, -12)]), tier="A", cast=("efim",), cam="zoom_in")
a.add("t", "Low angle, straining rope",
      "One small rowing boat slamming against a pier in rough water, the mooring rope pulled tight and dripping, waves breaking over the bow, too small for the crowd waiting behind.",
      [N("Лодка одна. Всех она не возьмёт.")], S("river", fx=[("creak", 0.5, -8)]), tier="B", cam="zoom_in")
a.add("t", "Medium, doorway",
      "A man and a woman standing in a doorway holding each other's hands, anonymous peasants in wet clothes, their faces calm and frightened, a lantern between them.",
      [N("Двое держатся друг за друга. Потеряем одного, второй не дойдёт.")], S(), tier="A", cam="zoom_in")
a.add("w", "Wide, lightning",
      "A wooden watch tower on the river bank with a single lantern at the top lit by a lightning flash, two dark tiny silhouettes standing at its foot.",
      [N("На вышке горит фонарь. Упырей двое.")], S("rain_heavy", "tense", fx=[("upyr_cry", 2.0, -14), ("thunder", 4.5, -9)]), tier="A", cam="pan_l")

b.add("w", "Wide, dawn after the storm",
      "Rowing boats tied at a pier at dawn after the storm, people carrying sacks along the pier, golden wet light on the water, torn clouds.",
      [N("Рассвет. Лодки у берега, мешки на плечах.")], S("river", "dawn"), tier="A", cam="pan_r")
b.add("t", "Close, hand and key",
      "A hand turning an iron key in the lock of a ferryman's cabin door, the key left in the lock, a dry flower on the sill, soft light.",
      [N("Закрываю дверь на ключ. Возвращаться сюда некому.")], S(fx=[("latch", 0.6, -6)]), tier="A", cam="zoom_in")
b.add("t", "Medium, lantern line",
      "A line of villagers walking uphill on a dirt road at dawn with bundles and lanterns still lit, backs to the camera, nobody lagging.",
      [N("К мельнице идём вместе. Никто не отстаёт.")], S("day"), tier="B", cam="pan_u")
b.add("w", "Wide, looking back",
      "Looking back from a hill at the small distant village by the river, houses tiny, a single candle burning in one window, morning mist.",
      [N("В одном окне остаётся свеча. Пусть горит.")], S("wind", "hope"), tier="A", cam="pan_l")

c.add("t", "Wide-medium, river dawn",
      "An empty rowing boat drifting back to the pier in grey dawn, one oar trailing, a coat folded on the bench, nobody aboard.",
      [N("Лодка возвращается пустой. Никто не говорит, кто сел в неё последним.")], S("river", "sad"), tier="A", cam="zoom_in")
c.add("w", "Wide, crowd, silhouettes",
      "A group of travellers on a hillside road in grey light, one figure among them slightly apart with eyes catching the light like an animal's; everyone else is walking, unaware.",
      [N("Один из тех, кто идёт со мной, не человек. Второго мы так и не нашли.")], S("wind", "tense"), tier="A", cam="pan_r")
c.add("t", "Macro, mud",
      "A thistle-and-salt amulet cracked in two lying in wet mud beside a boot print, salt spilled and dissolving.",
      [N("Оберег треснул ещё в первую ночь. «Значит, плохо держали».")], S(fx=[("glass", 0.5, -10)]), tier="B", cam="zoom_in")
c.add("t", "Over-the-shoulder, counting backs",
      "From behind a hooded figure walking in a column and looking at the backs of the people ahead; the column has a gap where a person should be; grey flat light.",
      [N("Я иду между ними и считаю спины. Одной не хватает.")], S(), tier="A", cast=("hero",), cam="zoom_in")

# ---------------------------------------------------------------- a2c1 Брод
a, b, c = trio("a2c1", "Брод", "Мельничный Двор, осень, ливень",
               "autumn deluge: slate grey and rust, wet shine, lanterns dying one by one, the mill a dark mass",
               "rain stopping, a strip of pale gold under the clouds, wet but warm",
               "close dim interior, one candle, amber on grey, tears on a heavy face")
a.add("w", "Wide, rain, mill yard",
      "A mill yard in heavy rain, a dark water mill with a wheel, planks laid across mud, people crouched under sacks, lanterns guttering one after another.",
      [N("Третий день льёт дождь. Фонари гаснут один за другим.")], S("rain_drops", "sad", fx=[("water_drip", 1.0, -12)]), tier="A", cam="pan_r")
a.add("t", "Medium, heavy man at a doorway",
      "A heavy miller at his doorway with one palm held out, flour in his brows, a keys ring at his belt, rain behind him, face half in shadow.",
      [D("melnik", "Пущу. За плату.")], S("mill"), tier="A", cast=("melnik",), cam="zoom_in")
a.add("t", "Overhead close, ledger",
      "A big ledger on a table, a thick hand writing lines with a goose quill by candlelight, column after column of illegible marks, a stack of coins and tallow candle stubs beside it.",
      [N("Он записывает в книгу каждого, кого пускает. И каждого, кого не пускает.")], S(fx=[("page", 0.6, -10)]), tier="B", cam="zoom_in")
a.add("t", "Straight-on, heavy door",
      "A massive storeroom door wrapped in a thick iron chain and a padlock, rain streaming down the planks, a single key on a ring in the foreground.",
      [N("Кладовая заперта на цепь. Ключ у мельника на поясе.")], S(fx=[("chain", 0.5, -8)]), tier="A", cam="zoom_in")
a.add("w", "Wide, ford",
      "A river ford rising: a plank bridge half under brown water, the swollen river reaching the road, rain, a stranded cart wheel, the far bank lost in mist.",
      [N("Брод уходит под воду. Назад дороги нет.")], S("river", "tense"), tier="B", cam="pan_l")

b.add("w", "Wide, light after rain",
      "Rain stopping over a mill: a strip of pale gold light under the clouds, water dripping from the roof, people standing on the porch looking up.",
      [N("К утру дождь стихает.")], S("day", "dawn"), tier="A", cam="pan_u")
b.add("t", "Medium, keys",
      "The miller unlocking the mill gate, the heavy ring of keys in his hand, face tired, a queue of wet people waiting behind the gate.",
      [N("Мельник открывает ворота. Берёт плату и молчит.")], S(fx=[("latch", 0.8, -6)]), tier="A", cast=("melnik",), cam="zoom_in")
b.add("t", "Interior, sleeping on sacks",
      "People sleeping on flour sacks in a warm mill loft, sprinkles of flour dust in the lamplight, a child's cap, calm.",
      [N("Спим на мешках. Тепло, пахнет мукой.")], S("mill"), tier="B", cam="pan_l")
b.add("w", "Wide, wheel turning in sun",
      "The mill wheel starting to turn in sunlight, water sheeting off the paddles, rainbow in the spray, wet green meadow beyond.",
      [N("Колесо трогается с места. Мельница снова работает.")], S("mill", "hope"), tier="A", cam="pan_r")

c.add("t", "Medium close, night door",
      "The miller at night at a door holding a key, face lit by a small lantern, rain behind him, his eyes red.",
      [D("melnik", "У меня дочь была. Она ушла за реку.")], S("rain", "sad"), tier="A", cast=("melnik",), cam="zoom_in")
c.add("t", "Extreme close-up on face",
      "A heavy man's face, flour-streaked, tears running through the dust on his cheeks, looking aside, one candle flame in the corner of the frame.",
      [D("melnik", "В ту ночь я её голос узнал и открыл. Это была не она.")], S(fx=[("weep", 0.6, -10)]), tier="A", cast=("melnik",), cam="zoom_in")
c.add("w", "Wide, still life",
      "A table covered with many burnt-down candle stubs in rows, a girl's red hair ribbon in the middle, a ledger beside it, dim.",
      [N("Деньги на свечи для неё. Он зажигает их по вечерам.")], S(), tier="B", cam="pan_r")
c.add("t", "Close, hand and keys",
      "A trembling hand holding a key ring above a half-open storeroom door, darkness inside, the chain hanging loose.",
      [N("Ключ от кладовой дрожит в его руке.")], S(fx=[("chain", 0.6, -8), ("tick", 1.4, -12)]), tier="A", cam="zoom_in")

# ---------------------------------------------------------------- a2c2 Чужаки
a, b, c = trio("a2c2", "Чужаки", "Затопленная Слобода, осень, наводнение",
               "autumn flood: flat brown-grey water, reflected lantern lights, mist, rust-coloured roofs",
               "flat dawn light on still water, pale peach sky, quiet",
               "black water, torchlight reflected, cold blue moonlight, fear")
a.add("w", "Wide, high, flood",
      "A flooded village: roofs and chimneys above brown water, a bell tower standing in the flood with water at its windows, boats and planks as streets.",
      [N("Затопленная слобода. Вода стоит до подоконников.")], S("river", "sad"), tier="A", cam="pan_r")
a.add("t", "Medium, boat arrival",
      "A flat boat arriving at a flooded porch with three strangers aboard: a shaved-headed soldier, a widow in black, a merchant in a fur hat, lantern light, ripples.",
      [N("Чужие приходят на лодке. Теперь никто не знает, кем они стали по дороге.")], S(fx=[("water_drip", 0.8, -10)]), tier="A", cast=("gordey", "agafya", "efim"), cam="zoom_in")
a.add("t", "Interior, swaying floor",
      "People sleeping on a floating wooden storehouse that rocks on the water, hanging lanterns swinging, ripples across the floor boards.",
      [N("Сухих мест мало. Люди спят в лабазе, который качается на воде.")], S("river"), tier="B", cam="pan_l")
a.add("t", "Low angle, bell tower",
      "The bell of a half-sunk bell tower swinging with the rope hanging motionless, water lapping at the sill, night, moon through clouds.",
      [N("Колокол звонит под водой. Никто к нему не прикасался.")], S(fx=[("bell", 0.5, -6), ("bell", 3.5, -9), ("water_drip", 1.0, -10)]), tier="A", cam="zoom_in")
a.add("w", "Wide, night, reflected lights",
      "Night on the flood: a silent line of boats with lanterns drifting across the black water between roofs, their reflections long, nobody visible in them.",
      [N("Ночью по воде идёт огонь. Это не наши лодки.")], S("night", "tense"), tier="B", cam="pan_r")

b.add("w", "Wide, still water at dawn",
      "Dawn on the still flood, mirror water, the bell tower silent, a thin mist, roofs glowing peach.",
      [N("К утру вода перестаёт подниматься. Колокол молчит.")], S("river", "dawn"), tier="A", cam="pan_r")
b.add("t", "Medium, small boat leaving",
      "A single person in a small boat rowing away from the village into the mist, head down, a lantern at the bow, people on a roof watching.",
      [N("Выгнанный уходит на лодке. Вёсел не слышно.")], S(fx=[("exile", 0.5, -8)]), tier="A", cam="zoom_out")
b.add("t", "Close, soggy bread",
      "Hands breaking a soaked loaf of bread into equal pieces on a plank, water droplets, many outstretched hands.",
      [N("Хлеб мокрый. Делим на всех.")], S(), tier="B", cam="zoom_in")
b.add("w", "Wide, roof, sun",
      "People on a sloped roof in morning sun drying clothes on a line, a rare warm light, a few faint smiles.",
      [N("Сушим вещи на крыше. Первая тёплая минута за четыре дня.")], S("day", "hope"), tier="A", cam="pan_l")

c.add("t", "Medium, in water",
      "A frightened old man standing in black water to his chest reaching a hand toward the camera, torches on a dark roof behind him, his mouth open.",
      [N("Мы выгнали невиновного. Вода по грудь, и он всё ещё просит.")], S("night", "sad", fx=[("human_cry_m", 0.5, -6)]), tier="A", cast=("extra_thin",), cam="zoom_in")
c.add("w", "Wide, bell tower silhouette",
      "A half-sunk bell tower at night with a thin silhouette standing at the top beside the bell, moon behind, black water with ripples.",
      [N("Колокол звонит снова. На звоннице кто-то стоит.")], S(fx=[("bell", 0.6, -5), ("bell", 2.8, -7), ("upyr_cry", 4.0, -16)]), tier="A", cam="zoom_in")
c.add("t", "Close, cart",
      "Sackcloth pulled back from a cart bed to reveal only dry straw with dark brown stains, a small hole where something lay.",
      [N("Под рогожей солома. Сын вдовы «вышел погулять».")], S(), tier="B", cast=("agafya",), cam="zoom_in")
c.add("t", "Reflection shot, water",
      "A reflection in black water: a hooded figure with a lantern and, standing close behind it, a taller, thinner shadow with eyes catching the light.",
      [N("В воде я вижу себя и ещё одного.")], S(fx=[("breath_3", 0.6, -8)]), tier="A", cast=("hero",), cam="zoom_in")

# ---------------------------------------------------------------- a2c3 Половодье / Гнилая Гать
a, b, c = trio("a2c3", "Половодье", "Гнилая Гать, поздняя осень, полная луна",
               "late autumn frozen bog: huge pale full moon, silver-blue frost, black spruce, orange lantern",
               "blue dawn, hoarfrost on logs, first rose-gold light",
               "moonlit horror, bruised silver and black, one red-orange fire")
a.add("w", "Wide, moon over bog",
      "A corduroy road of logs across a frozen bog under an enormous full moon, mist, people in a line crossing it with lanterns, black spruce.",
      [N("Гнилая Гать. Дорога из брёвен через болото и полная луна.")], S("wind", "tense"), tier="A", cam="pan_r")
a.add("t", "Medium, stilt hut",
      "A hunter's winter hut on stilts above the frozen bog, moon above it like a lamp, long shadows of spruce, frost glitter.",
      [N("Сухих мест всё меньше, людей всё больше. Луна светит как днём.")], S("bog"), tier="B", cam="zoom_in")
a.add("t", "High angle, fresh grave",
      "A freshly dug grave mound behind an old mill under moonlight, a shovel stuck beside it, frost on the heap, long shadows.",
      [N("Свежая могила. Никто её не копал.")], S(fx=[("crow", 1.0, -12)]), tier="A", cam="zoom_in")
a.add("t", "Macro, earth",
      "A hunting knife with a stamped brand mark half-buried in loose black earth, moonlight on the blade, frost.",
      [N("В рыхлой земле нож с клеймом. Такой носит кто-то из нас.")], S(), tier="A", cam="zoom_in")
a.add("w", "Wide, grave interior",
      "A shallow open grave at night with a stranger in a travelling cloak lying in it, face turned away and covered with earth, boots visible, moonlight.",
      [N("В могиле чужой человек в дорожном плаще. Никто в посёлке его не знает.")], S(fx=[("scare", 1.2, -18)]), tier="B", cam="zoom_in")

b.add("w", "Wide, dawn over frozen bog",
      "Moon setting over a frozen bog at blue dawn, hoarfrost on the log road, mist in the hollows, a thin pink line on the horizon.",
      [N("Луна садится. На брёвнах иней.")], S("bog", "dawn"), tier="A", cam="pan_l")
b.add("t", "Medium, burial",
      "Two people burying the stranger with a simple cross made of two poles in a field of frost, bowed heads, breath fog.",
      [N("Хороним чужого по обычаю. Крест из двух жердей.")], S("wind"), tier="A", cam="zoom_out")
b.add("t", "Medium, chapel steps",
      "A man and a woman side by side on the steps of a small wayside chapel sharing one lantern, shoulders touching, faces tired, dawn light.",
      [N("Те двое дошли вместе. Пока этого хватает.")], S(), tier="B", cam="zoom_in")
b.add("w", "Wide, sunrise on the log road",
      "A line of people crossing the end of the log road at sunrise toward a distant hill with a monastery silhouette, long shadows, gold light on frost.",
      [N("Гать кончается. Впереди монастырь.")], S("wind", "hope"), tier="A", cam="pan_r")

c.add("t", "Medium, accusing finger",
      "A pointing finger and a torch in the foreground directed at a cowering figure in the shadows, moonlight, faces of an angry crowd blurred behind.",
      [N("«Это чужаки привели мертвеца». Палец тычет в тех, кто пришёл вчера.")], S("murmur", "tense", fx=[("whisper", 0.8, -12)]), tier="A", cam="zoom_in")
c.add("w", "Wide, fire at night",
      "A charcoal-burner's kiln and shed burning at night on the bog, orange flames against the black spruce, small running silhouettes, sparks.",
      [N("Ночью горит выжигальня. Тушить некому.")], S("fire", "tense", fx=[("fire_crackle", 0.5, -8)]), tier="A", cam="pan_r")
c.add("t", "High angle, footprints",
      "Wet bare footprints in frost leading from an open grave to a chapel door, moonlit, a single dropped shovel.",
      [N("Следы идут от могилы к часовне. Босые и влажные.")], S(), tier="B", cam="zoom_in")
c.add("t", "Interior, window",
      "A moonlit window with a thin tall shadow on the pane though nobody stands inside the room, a bed in the foreground, frost on the glass.",
      [N("Луна светит в окно. На стекле тень, которой в комнате нет.")], S(fx=[("scratch", 0.8, -10)]), tier="A", cam="zoom_in")
