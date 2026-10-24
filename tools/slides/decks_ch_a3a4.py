"""Главы акта III и акта IV: вход (5), победа (4), поворот (4)."""
from dsl import deck, S, N, D
from decks_ch_a1a2 import trio

# ---------------------------------------------------------------- a3c1 Ворота
a, b, c = trio("a3c1", "Ворота", "Внешний Скит, зима, метель",
               "winter blizzard: blue-white snow, black timber, orange window lights, breath fog",
               "soft white morning, pink-gold snow light, steam from porridge",
               "cold blue dark, a single orange keyhole glow, frost, swamp fog")
a.add("w", "Wide, blizzard, hostel lights",
      "A monastery outer hostel in a blizzard: long low log buildings with warm orange windows, a heavy gate tower, snow blowing sideways, tiny people at the gate.",
      [N("Внешний скит. Монахи пускают за стену, но на ночь запирают кельи.")], S("blizzard", "tense"), tier="A", cam="pan_r")
a.add("t", "Long corridor, low angle",
      "A young novice in a black habit locking cell doors along a narrow log corridor with a ring of iron keys, candle in a wall niche, long perspective.",
      [N("Кельи запирают снаружи. Выйти ночью нельзя.")], S(fx=[("latch", 0.8, -6), ("latch", 1.8, -6), ("latch", 2.8, -6)]), tier="A", cast=("anfisa",), cam="zoom_in")
a.add("t", "Medium, bakery oven",
      "The glowing mouth of a big brick bread oven, a monk's silhouette with a long wooden peel, loaves on racks, orange light on frosty windows.",
      [N("В пекарне тепло. Хлеба на всех не хватит.")], S("wind"), tier="B", cam="zoom_in")
a.add("t", "Wide-medium, gate in fog",
      "A heavy gate at night with a thick swamp fog creeping through the gap beneath it, a lantern on a post, shapes in the fog.",
      [N("С болот идёт туман. У двери придётся спрашивать.")], S("wind", fx=[("whisper", 1.2, -12)]), tier="A", cam="zoom_in")
a.add("w", "Wide, window, cart outside",
      "A hostel window with a widow in a black shawl looking out at a cart covered with sackcloth left in the falling snow, snow on its edges, a lantern.",
      [N("Вдова не отходит от окна. Телегу с рогожей внутрь не пустили.")], S("blizzard"), tier="B", cast=("agafya",), cam="pan_l")

b.add("w", "Wide, courtyard morning",
      "A snowy monastery courtyard in the morning with monks unlocking cell doors one by one, steam of breath, pink-gold light on snow.",
      [N("Утром монахи отпирают кельи. Все на месте.")], S("wind", "dawn"), tier="A", cam="pan_r")
b.add("t", "Medium, refectory",
      "People sitting in a log refectory eating hot soup from wooden bowls, steam rising, hunched shoulders, orange stove light.",
      [N("Похлёбка горячая. Едим молча.")], S("murmur"), tier="A", cam="zoom_in")
b.add("t", "Low angle, bell tower",
      "A snow-laden bell tower with a still bell against a pale morning sky, snow falling slowly.",
      [N("Колокол молчит. Игнат говорит, что так лучше.")], S("wind"), tier="B", cam="pan_u")
b.add("w", "Wide, gate open",
      "An open monastery gate with morning sun on the road beyond and a line of footprints leading out, lanterns snuffed.",
      [N("Ворота остаются открытыми до вечера.")], S("wind", "hope"), tier="A", cam="pan_r")

c.add("t", "Low angle at a door",
      "A heavy cell door with deep scratches on its inner face visible through the crack, a pale hand reaching out under the door, dawn blue.",
      [N("Утром одна келья заперта изнутри. На двери царапины.")], S("night", "tense", fx=[("scratch", 0.5, -6), ("scratch", 1.5, -8)]), tier="A", cam="zoom_in")
c.add("w", "Wide, monks in a row",
      "A line of black-robed monks holding lanterns in a snowy yard staring toward the camera in silence, faces hidden in hoods, breath fog.",
      [N("Монахи молчат. Это молчание хуже криков.")], S("blizzard", "sad"), tier="A", cam="pan_l")
c.add("t", "Macro, keys",
      "An iron ring of keys on a stone floor with one empty loop where a key should hang, a faint trail of wet prints leading away.",
      [N("Одного ключа нет. Кто-то ходил ночью.")], S(fx=[("tick", 0.5, -10)]), tier="B", cam="zoom_in")
c.add("t", "Wide-medium, gate fog",
      "Dense white fog standing motionless at the monastery gate, two pale reflective points deep inside it, a lantern on a post flickering.",
      [N("Туман стоит у ворот и никуда не уходит.")], S(fx=[("breath_3", 0.8, -10)]), tier="A", cam="zoom_in")

# ---------------------------------------------------------------- a3c2 Колокол
a, b, c = trio("a3c2", "Колокол", "Монастырский Двор, зима, снегопад",
               "heavy snowfall, cold blue-grey, orange candlelight in windows, cathedral gold glints",
               "gentle morning blue and gold, snow crunch, steam",
               "black night, torchlight, cold bronze green, bell shadows")
a.add("w", "Wide, high, courtyard in snow",
      "A monastery courtyard covered in untouched deep snow, a three-domed stone cathedral, a bell tower, monk cells with dark windows, not a single footprint.",
      [N("Монастырский двор. Снег по колено, и ни одного следа.")], S("blizzard", "tense"), tier="A", cam="pan_r")
a.add("t", "Low angle, bell",
      "A huge bronze bell swinging violently in a tower at night, the rope hanging motionless in the foreground, snow blown in through the openings.",
      [N("Ночью колокол звонит сам.")], S("night", fx=[("bell", 0.4, -3), ("bell", 2.0, -4), ("bell", 3.6, -5)]), tier="A", cam="shake")
a.add("t", "Medium, candlelit order",
      "An old monk with a white beard speaking in a stone hall full of tense listeners, one hand raised, candles, shadows on a vaulted ceiling.",
      [D("ignat", "Игумен велит найти упыря до третьего утра. Потом ворота запрут.")], S("church"), tier="A", cast=("ignat",), cam="zoom_in")
a.add("t", "Corridor, cells",
      "A long dark corridor of monk cells with lanterns on the floor outside each door and faces peering from cracks in the doors.",
      [N("В кельях шепчутся. Ночью все слушают одно и то же: колокол.")], S(fx=[("whisper", 0.5, -10)]), tier="B", cam="zoom_in")
a.add("w", "Wide, refectory",
      "A long refectory with benches and tables with several empty places with bowls still full, lamp light, nobody talking.",
      [N("В трапезной пустые места. Никто не говорит, чьи.")], S("church"), tier="B", cam="pan_r")

b.add("w", "Wide, bell tower dawn",
      "A monastery bell tower at dawn with a cut rope end dangling in the foreground, pale gold light, snow falling gently.",
      [N("На рассвете колокол молчит. Верёвка перерезана.")], S("wind", "dawn"), tier="A", cam="pan_u")
b.add("t", "Close, accused",
      "A monk with bare hands held out before him in a courtyard, calm and looking at the ground, a ring of lanterns around him, snow.",
      [N("Мы нашли того, кто звонил. Он не отпирался.")], S("church"), tier="A", cam="zoom_in")
b.add("t", "Medium, shovels",
      "People clearing snow from the courtyard with wooden shovels, breath fog, the creak of snow.",
      [N("Двор чистят от снега. Впервые слышно, как скрипят лопаты.")], S("wind"), tier="B", cam="pan_l")
b.add("w", "Wide, open gate sunrise",
      "A monastery gate opened at sunrise, long blue shadows on the snow, people standing in the gateway looking out at the road.",
      [N("Ворота остаются открытыми.")], S("wind", "hope"), tier="A", cam="pan_r")

c.add("t", "Medium, gate from inside",
      "People pressed to the inside of a closing monastery gate seen from the courtyard while through the gap outside stand shapes pounding on the planks.",
      [N("Игумен велит запереть ворота. Те, кто остался снаружи, стучат.")], S("blizzard", "sad", fx=[("knock", 0.5, -3), ("knock", 1.0, -3), ("door_shut", 1.8, -4), ("latch", 2.5, -4)]), tier="A", cam="zoom_in")
c.add("w", "Wide, midnight bell",
      "A bell tower at midnight with a thin shadow hanging from the bell rope, torchlight below in the courtyard, snow whirling.",
      [N("Звонят снова. На верёвке висит тень.")], S("night", "tense", fx=[("bell", 0.5, -3), ("bell", 2.2, -5)]), tier="A", cam="pan_u")
c.add("t", "Close, hands with beads",
      "Hands counting wooden prayer beads very fast, a bowed head in a black hood, candlelight on the wall behind.",
      [N("Монахи считают чётки и не поднимают глаз.")], S("church"), tier="B", cam="zoom_in")
c.add("t", "Macro, frost on bronze",
      "A gloved hand pressed against a bronze bell, frost crystals around the fingers, an eerie green-bronze shine.",
      [N("Бронза холодная, как лёд. Колокол звонил не руками.")], S(fx=[("tick", 0.4, -10)]), tier="A", cast=("hero",), cam="zoom_in")

# ---------------------------------------------------------------- a3c3 Крипта
a, b, c = trio("a3c3", "Крипта", "Пепелище, зима, горящий собор и подземелье",
               "orange fire on blue snow, black ash, deep crypt shadows with a single candle, cold stone",
               "pale dawn over ash and snow, a thin pink line, quiet relief",
               "candle-lit crypt gloom, a yellow-green sickly light, deep shadows, faces half dark")
a.add("w", "Wide, burning cathedral in snow",
      "A burning stone cathedral at night in deep snow, orange flames pouring from the windows, the snow around it not melting, black figures small in the foreground.",
      [N("Собор горит, а снег вокруг не тает.")], S("fire", "tense", fx=[("fire_crackle", 0.6, -8)]), tier="A", cam="pan_r")
a.add("t", "Down the stairs, POV",
      "A narrow stone staircase leading down into the crypt, a candle held out in the foreground picking out damp walls and dark niches.",
      [N("Под храмом холодно. Свеча выхватывает ниши.")], S("church", fx=[("water_drip", 0.7, -10)]), tier="A", cam="zoom_in")
a.add("t", "Wide-medium, niches",
      "Rows of empty stone coffins in niches of a crypt wall, each lid with a carved plate whose letters are unreadable, candlelight, cobwebs.",
      [N("Пустые гробы. На каждом имя.")], S(fx=[("scare", 1.4, -20)]), tier="A", cam="pan_r")
a.add("t", "Macro, wall",
      "A hand tracing deep carved letters on a crypt wall with a fingertip, dust, candlelight, the letters illegible as a stylised script.",
      [N("На стене выбито: они приходят к тем, кто их помнит и оплакивает.")], S(), tier="B", cast=("hero",), cam="zoom_in")
a.add("w", "Wide, hero in niche",
      "A lone hooded figure from behind in a crypt aisle between rows of empty coffins, lantern light on the arches, a faint far-away call from the stairs.",
      [N("Меня звали с того берега, потому что по мне тоже кто-то плакал.")], S(fx=[("call_far", 1.0, -10)], music="sad"), tier="A", cast=("hero",), cam="zoom_in")

b.add("w", "Wide, crypt crowd",
      "Dozens of people in the crypt with raised hands in the lantern light, the old monk at the center, a vote, tense faces turning to relief.",
      [N("Суд в крипте окончен. Тех, кто помнит добро, больше.")], S("church", "dawn"), tier="A", cam="pan_r")
b.add("t", "Close, old monk",
      "The old monk with a long white beard looking straight ahead and slightly softening, candlelight, his hand resting on a stone coffin lid.",
      [D("ignat", "Живи. Но я буду смотреть.")], S("church"), tier="A", cast=("ignat",), cam="zoom_in")
b.add("t", "Exterior, steps, dawn",
      "The crypt door opening onto pale dawn, ash on snow outside, the burned cathedral ruin in the distance, steam of breath from the people coming up the stairs.",
      [N("Выхожу из крипты на рассвете. Пепел на снегу.")], S("wind", "hope"), tier="B", cast=("hero",), cam="zoom_out")
b.add("w", "Wide, group leaving",
      "A group of people walking away from the monastery on a snowy road at dawn toward a forest, a thin pink sunrise, their long shadows.",
      [N("На станцию идём вместе.")], S("wind", "hope"), tier="A", cam="pan_r")

c.add("t", "Close, judge",
      "The old monk in a crypt pointing a firm finger to the exit, stern, candlelight casting his shadow huge on the wall.",
      [D("ignat", "Тех, кто помнит зло, больше. Уходи за ворота до заката.")], S("church", "sad"), tier="A", cast=("ignat",), cam="zoom_in")
c.add("w", "Wide, ledger",
      "A big old book open on a lectern in the crypt, many lines of names crossed out with ink strokes, the final line written in a different, fresher ink, candlelight.",
      [N("Строки зачёркнуты, но имена видно. В самом низу моё.")], S(fx=[("page", 0.6, -10)]), tier="A", cam="pan_r")
c.add("t", "Macro, ribbon",
      "A faded red hair ribbon and a burnt-out candle lying on the open ledger beside a crossed-out line.",
      [N("Дочь мельника. Незнакомые фамилии. Их всех кто-то впустил.")], S(), tier="B", cam="zoom_in")
c.add("t", "Close, board of names",
      "A weathered wooden board by a chapel with rows of old carved names, one row's moss freshly scraped away, a lantern's glow on the cut letters.",
      [N("Эта река меня уже видела. Память обо мне осталась у неё.")], S("river", fx=[("call_far", 1.5, -10)]), tier="A", cast=("hero",), cam="zoom_in")

# ---------------------------------------------------------------- a4c1 Полустанок
a, b, c = trio("a4c1", "Полустанок", "Разъезд 14-я Верста, весна, дождь и туман",
               "early spring rain: grey-green wet mud, glistening rails, thin yellow kerosene light, low fog",
               "rain breaking, pale silver morning on wet rails, quiet",
               "dark night, one sick yellow lamp, black rails, cold green fog")
a.add("w", "Wide, rainy junction",
      "A lonely railway halt in rain: a workers' barracks, a signal hut, a telegraph shed, a rail handcar shed, wet mud paths, spruce wall behind.",
      [N("Разъезд 14-я Верста. Лес кончился у рельсов.")], S("rain", "tense"), tier="A", cam="pan_r")
a.add("t", "Medium, platform",
      "A stationmaster in a black greatcoat and peaked cap standing on a wet platform with a lantern, looking not at the camera but at the rails.",
      [D("smotritel", "Поезд придёт через четыре ночи. Так записано.")], S("whistle"), tier="A", cast=("smotritel",), cam="zoom_in")
a.add("t", "Medium, depot worker",
      "A depot worker in a padded jacket and fur hat with a small lantern beside a handcar in a shed, patting the machine like an animal, oil on his hands.",
      [N("Степан двадцать лет в депо. Говорит, машина пойдёт, если её не бросать.")], S(fx=[("hammer", 1.0, -10)]), tier="B", cast=("stepan",), cam="zoom_in")
a.add("t", "Macro, telegraph",
      "A brass telegraph key tapping on its own in a dim office, a paper tape feeding out, kerosene lamp reflected in the brass.",
      [N("Телеграф стучит сам. Никто не знает, что он передаёт.")], S(fx=[("tick", 0.5, -8), ("tick", 0.8, -8), ("tick", 1.4, -8), ("tick", 1.6, -8)]), tier="A", cam="zoom_in")
a.add("w", "Wide interior, waiting hall",
      "An empty third-class waiting hall: wooden benches, a cast-iron stove with a kettle on it, steam, a window with rain, no one in sight.",
      [N("В зале ожидания пустые скамьи. Чайник на печке горячий.")], S("murmur"), tier="B", cam="pan_l")

b.add("w", "Wide, platform, fog lifting",
      "A wet platform with fog rising off the rails as morning breaks, people standing along it, a distant signal arm.",
      [N("Туман поднимается над платформой.")], S("day", "dawn"), tier="A", cam="pan_r")
b.add("t", "Close, ledger",
      "A stationmaster's gloved hand drawing a line through one night in a grey ledger, pencil, a lantern at the edge.",
      [N("Смотритель вычёркивает ночь из тетради.")], S(fx=[("page", 0.4, -10)]), tier="A", cast=("smotritel",), cam="zoom_in")
b.add("t", "Medium, tea",
      "People holding tin mugs of tea around a stove in the waiting hall, steam, hands warming, quiet faces.",
      [N("Пьём чай из жестяных кружек. Руки перестают дрожать.")], S("murmur"), tier="B", cam="zoom_in")
b.add("w", "Wide, rails and whistle",
      "Wet rails shining silver into a pale horizon with a small cloud of steam far away, morning light.",
      [N("Далеко свистит. Это ещё не наш поезд.")], S("whistle", "hope"), tier="A", cam="pan_r")

c.add("t", "Medium, floor",
      "A paper telegraph tape spilling across the floor of a dim station office in loops, rows of dots and dashes, a boot print on it.",
      [N("Утром на полу лента. Ряды точек и тире. Читать её никто не умеет.")], S("night", "sad"), tier="A", cam="zoom_in")
c.add("w", "Wide, cellar door",
      "An open cellar door in the ground of a kerosene store, black stairs going down, cold breath of fog coming out, a lantern left on the lid.",
      [N("Дверь погреба открыта. Оттуда тянет холодом, а не керосином.")], S(fx=[("breath_3", 0.8, -10)]), tier="A", cam="zoom_in")
c.add("t", "Close, window",
      "A long pale handprint with too-long fingers on the outside of a foggy station window, a lamp inside, the glass beaded with water.",
      [N("На стекле снаружи отпечаток ладони. Слишком длинной.")], S(fx=[("scratch", 0.7, -10)]), tier="B", cam="zoom_in")
c.add("t", "Medium, stationmaster",
      "A stationmaster at his desk with a ledger and a trembling pencil, counting under his breath, lamp on his face, a cold sweat.",
      [N("Смотритель считает людей и каждый раз сбивается.")], S(fx=[("tick", 0.6, -10), ("tick", 1.0, -10)]), tier="A", cast=("smotritel",), cam="zoom_in")

# ---------------------------------------------------------------- a4c2 Список
a, b, c = trio("a4c2", "Список", "Грузовой Тупик, весна, угольный туман",
               "coal-dust mist: black and sulphur-yellow, cold steel, orange forge glow, grimy faces",
               "pale dawn through coal haze, silver on freight wagons, quiet",
               "dark underlit faces, yellow lamp, coal-black shadows, betrayal tension")
a.add("w", "Wide, coal yard",
      "A freight yard at night in coal-dust mist: a water tower, a freight warehouse, black coal heaps, abandoned freight wagons on rusted rails, one lantern.",
      [N("Грузовой тупик. Уголь, туман и вагоны, которые давно никуда не ходят.")], S("wind", "tense"), tier="A", cam="pan_r")
a.add("t", "Medium, clerk",
      "A thin clerk in a bowler hat and round spectacles with a small notebook and a pencil stub, half lit by a lantern from below, wearing a black greatcoat.",
      [D("pisar", "Я пишу то, за что платят.")], S("type"), tier="A", cast=("pisar",), cam="zoom_in")
a.add("t", "Straight-on, list board",
      "A wooden board on a station wall with a long list of lines of hand-written marks, some lines crossed out, a pencil hanging on a string, lantern light.",
      [N("Смотритель пишет список на поезд. Мест меньше, чем людей.")], S("type", fx=[("page", 0.5, -10)]), tier="A", cast=("smotritel",), cam="zoom_in")
a.add("t", "Interior, freight wagon",
      "The dark interior of an abandoned freight wagon with straw on the floor, a recently used blanket, an empty tin cup, fog drifting in through the open door.",
      [N("В брошенном вагоне кто-то живёт. Следов нет.")], S(fx=[("creak", 0.8, -10)]), tier="B", cam="zoom_in")
a.add("w", "Wide, forge glow",
      "A repair workshop at night with the forge glowing orange inside through open doors, nobody in sight, tools hanging, sparks drifting.",
      [N("В мастерской ночью горит горн. Никто не признаётся.")], S("fire", fx=[("fire_crackle", 0.5, -10)]), tier="B", cam="pan_r")

b.add("w", "Wide, platform, stamp",
      "A station office window with a hand pressing a rubber stamp on a long paper list, ink, a lamp, people outside the window waiting.",
      [N("Список закрыт. Печать поставлена до рассвета.")], S("type", "dawn"), tier="A", cam="zoom_in")
b.add("t", "Macro, stamp",
      "A rubber stamp pressed on a paper list leaving a red round impression, drops of ink, a wooden table.",
      [N("Печать ложится на бумагу. Очередь на поезд определена.")], S(fx=[("tap", 0.6, -4)]), tier="A", cam="zoom_in")
b.add("t", "Medium, washing",
      "People washing coal dust from their faces in a barrel of water, dark water, faces looking at each other to see who is cleaner.",
      [N("Моем лица от угля. Каждый смотрит, кто чище.")], S(), tier="B", cam="zoom_in")
b.add("w", "Wide, first light",
      "First light on freight wagons and a water tower, mist retreating from the rails, silver edges.",
      [N("Туман отступает от вагонов.")], S("day", "hope"), tier="A", cam="pan_r")

c.add("t", "Medium, stationmaster reading",
      "A stationmaster staring at one line in a ledger at night, the lamp light on his stern face, a clerk's hand blurred beside the book.",
      [N("Эту строку вписали ночью. Почерк я знаю.")], S("type", "sad"), tier="A", cast=("smotritel",), cam="zoom_in")
c.add("t", "Close, clerk",
      "The clerk in a bowler hat and spectacles in dark half-light speaking with a thin cold smile, a pencil behind his ear.",
      [D("pisar", "Мне заплатили. Кто платил, мне всё равно.")], S(), tier="A", cast=("pisar",), cam="zoom_in")
c.add("t", "Macro, ink",
      "A handwritten line in a ledger with an ink smear running into the neighbouring line, the paper wet, an eraser mark.",
      [N("Одна строка, и человека нет в списке.")], S(fx=[("page", 0.5, -10)]), tier="B", cam="zoom_in")
c.add("w", "Wide, confrontation",
      "A group of tense people under a lantern in a station yard, the camera behind a hooded figure with a lantern facing them, one face lit angrily, one looking away.",
      [N("Все смотрят на меня. Что скажу?")], S("murmur", fx=[("whisper", 0.8, -12)]), tier="A", cast=("hero",), cam="pan_l")

# ---------------------------------------------------------------- a4c3 Последний поезд
a, b, c = trio("a4c3", "Последний поезд", "Перрон Полночь, весна, последний мороз",
               "last frost: silver-blue platform, white breath, kerosene yellow lamps, deep black sky",
               "dawn light on steam, gold and blue, hope",
               "midnight blue, one open door of cold light, frost on glass, loneliness")
a.add("w", "Wide, night platform",
      "A wooden railway station platform at night with all the survivors waiting in small groups under hanging lanterns, frost on the planks, steam of breath.",
      [N("Последние ночи перед поездом. Все, кто дожил, на одной станции.")], S("wind", "tense"), tier="A", cam="pan_r")
a.add("t", "Straight-on, timetable",
      "A station timetable board with one hand-painted line, the date scraped off, a smear of frost across it.",
      [N("Поезд придёт на рассвете. Дальше расписания нет.")], S(), tier="B", cam="zoom_in")
a.add("t", "Medium, open door",
      "An old railway carriage door open on the platform, its interior dark and cold, a number plate by the door too frosted to read, mist inside.",
      [N("Вагон номер четыре стоит с открытыми дверями. Внутри холодно.")], S(fx=[("creak", 0.6, -10)]), tier="A", cam="zoom_in")
a.add("t", "Close, waiting-hall door",
      "A closed wooden waiting-hall door at night seen from inside, three heavy knocks making the lamp flame bend.",
      [N("В дверь стучат три раза, как в первую ночь.")], S("night", fx=[("knock", 0.4, -3), ("knock", 1.0, -3), ("knock", 1.6, -2)]), tier="A", cam="zoom_in")
a.add("w", "Wide, distant train light",
      "A distant yellow train headlamp glowing through thick fog down the straight rails, a faint plume of steam, an empty platform in the foreground.",
      [N("Вдалеке гудит. Двое упырей хотят уехать вместе с нами.")], S("whistle", "tense", fx=[("call_far", 0.5, -14)]), tier="A", cam="pan_r")

b.add("w", "Wide, train arrival at dawn",
      "A steam train arriving at a platform at dawn through fog, its headlamp glowing, the survivors standing back from the edge with bundles.",
      [N("На рассвете подходит поезд.")], S("train", "dawn"), tier="A", cam="pan_r")
b.add("t", "Medium, steam",
      "Steam swallowing the platform as carriage doors open by themselves, golden light inside, faces half hidden by the cloud.",
      [N("Пар окутывает перрон. Двери открываются сами.")], S(), tier="A", cam="zoom_in")
b.add("t", "Close, hands",
      "Hands helping each other up the carriage steps with bags, calm, a lantern passed from hand to hand.",
      [N("Садимся по очереди. Никто не толкается.")], S(), tier="B", cam="zoom_in")
b.add("w", "Wide, train departing",
      "A train leaving a small station at sunrise, steam and golden light on the platform, a stationmaster raising a lantern, forest behind.",
      [N("Поезд трогается. Станция остаётся позади.")], S("train", "dawn"), tier="A", cam="pan_r")

c.add("t", "POV, door",
      "A waiting-hall door seen from inside at night, a man's voice from outside and a thin line of lamplight under the door, a hand with a lantern lowered in the foreground.",
      [N("За дверью мой собственный голос зовёт меня по имени.")], S("night", "sad", fx=[("call_far", 0.6, -8), ("knock", 1.8, -4)]), tier="A", cast=("hero",), cam="zoom_in")
c.add("w", "Wide, blue dawn, empty platform",
      "A lone hooded figure from behind on an empty platform watching the red tail lamp of a departing train vanish into blue dawn fog.",
      [N("Поезд уходит без меня.")], S("train", "grief"), tier="A", cast=("hero",), cam="pan_r")
c.add("t", "Close, window",
      "A pale hand pressed on the glass of the last carriage window from inside, the compartment door behind it closed, frost.",
      [N("В окне последнего купе рука. Дверь закрыта изнутри.")], S(), tier="B", cam="zoom_in")
c.add("t", "High angle, footprints",
      "Bare footprints in frost on the platform leading away from the camera toward a gap in the fence and the dark line of a river at dawn.",
      [N("Мои следы ведут к реке.")], S("river"), tier="A", cam="zoom_in")
