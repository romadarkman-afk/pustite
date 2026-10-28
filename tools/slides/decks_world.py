"""Колоды мира: предыстория, входы в акты, выходы из актов."""
from dsl import deck, S, N, D

# ============================================================ ПРЕДЫСТОРИЯ
d = deck("prologue", "Предыстория: тот берег", "prologue",
         "Перед первой главой и из Книги посёлка («Как всё началось»)",
         "cold steel-blue dusk, heavy fog, desaturated; the thirty-years-ago frames (02 to 06) look like faded old film: grey-sepia, scratches, softer focus, vignette",
         "Тихая тоска, потом тревога. Музыка: грустная тема, под конец ночная.", music="sad")
d.add("w", "Extreme wide, locked-off camera, slightly high angle",
      "A black river at dusk between two walls of spruce and birch, a thick rope crossing the frame to a flat wooden ferry raft, ground fog lying on the water, on the far bank one weak lantern light.",
      [N("Эта река старше деревни. Старики говорят, что она ничего не забывает.")],
      S("river", "sad", fx=[("call_far", 2.5, -14)]), tier="A", cam="pan_r")
d.add("t", "Low angle, handheld, flash-frame look",
      "FLASHBACK, faded old film. A crowd of peasants in 1860s clothes on the river shore at night, seen from behind, torches and lanterns, every face turned to the dark far bank, one woman pressing a hand to her mouth.",
      [N("Тридцать лет назад деревня впервые услышала голоса с того берега.")],
      S(fx=[("call_far", 0.8, -9)]), tier="A", cam="zoom_in")
d.add("t", "Medium close-up, side-lit by a torch",
      "FLASHBACK. A middle-aged peasant woman listening, eyes wet, lips parted, torch fire reflected in her eyes; blurred figures behind her; the expression is longing, not fear.",
      [N("Звали по имени. Голосами тех, кого уже похоронили.")],
      S(fx=[("weep", 0.4, -8), ("call_far", 1.8, -12)]), tier="A", cam="zoom_in")
d.add("t", "POV from inside a dark izba, looking at the door",
      "FLASHBACK. A heavy wooden door open one hand's width onto the night, a pale long-fingered hand resting on the edge of the doorframe, thin cold light on the floor, a bare room, one burned-down candle on a table.",
      [N("Первым открыл тот, кто горевал сильнее всех. К утру в доме не осталось никого.")],
      S(fx=[("creak", 0.3, -8), ("breath_3", 1.5, -10)], music="tense"), tier="A", cam="zoom_in")
d.add("w", "Wide static shot, deadpan, dawn light",
      "FLASHBACK. A dawn interior of an izba: a bare table set with two cups, one overturned, uneaten bread, shutters open, sunrise through dust, nobody in the room.",
      [N("Две кружки. Хлеб. Ни одного следа.")],
      S(silence=True), tier="B", cam="hold")
d.add("t", "Overhead tabletop shot",
      "FLASHBACK. Village elders around a rough table lit by one candle, an old man cutting marks into a birch-bark scroll with a knife, only hands and half-lit tired faces visible.",
      [N("Тогда и решили: ночью никто не остаётся один. Один человек оберег не удержит.")],
      S("night", "sad"), tier="A", cam="zoom_out")
d.add("t", "Extreme close-up, shallow depth of field",
      "A talisman of dried thistle, a small salt bag and red thread hanging on a door lintel, a candle flame beneath it, a drop of wax on the wood.",
      [N("Оберег горит, пока в доме двое. Уйдёт второй, оберег погаснет.")],
      S(fx=[("tick", 1.2, -12)]), tier="B", cam="zoom_in")
d.add("w", "Medium wide, flat grey daylight",
      "Daytime in the village yard: neighbours standing in a loose circle, faces tense, a woman with a bucket, a man leaning on a fence, everyone looking at one person off-frame.",
      [N("Днём они такие же, как мы. Здороваются, чинят крыши. Днём решают, кого выгнать за околицу.")],
      S("murmur", "day"), tier="B", cam="pan_l")
d.add("t", "Low angle from the mud, boots in the foreground",
      "Worn boots stepping off a ferry raft onto wet river mud, the hem of a sheepskin coat, a kerosene lantern in the left hand throwing a small warm circle, the village windows glowing far behind in the fog.",
      [N("Я иду туда, где меня не ждут. Река зовёт меня по имени.")],
      S("dusk", "night"), tier="A", cast=("hero",), cam="zoom_out")
d.add("t", "Locked-off, symmetrical, title-card framing",
      "A closed old wooden door at night seen straight on, one weak lantern light, a knuckle about to knock, rain-dark planks, an iron latch; nothing else in frame.",
      [N("«Пустите».")],
      S(fx=[("knock", 0.6, -4), ("knock", 1.2, -4), ("knock", 1.8, -3)], music="tense"), tier="A", cam="zoom_in")

# ============================================================ ВХОДЫ В АКТЫ
d = deck("act1_intro", "Акт I «Деревня»: вход", "act_intro", "Перед главой 1, после предыстории",
         "late summer: amber-gold dusk turning to steel blue, warm window light, haze over the river",
         "Тёплая обманчивая тишина. Музыка: день, к концу ночь.", music="day")
d.add("w", "Wide establishing shot at golden hour",
      "A riverside village of log houses at golden hour: hay stacks, nets drying on poles, smoke from chimneys, a path to the river, the sun low behind the spruce.",
      [N("Лето. Нижний Посад живёт так, будто ничего не слышал.")],
      S("day", "day"), tier="A", cam="pan_r")
d.add("t", "Close on tired hands, shallow depth of field",
      "A woman's tired hands carrying a water yoke with two buckets, water slopping, sun flare behind, the village blurred.",
      [N("Днём здесь работают. Носят воду, косят, латают сети.")],
      S("murmur"), tier="B", cam="pan_u")
d.add("t", "Straight-on, low camera, symmetrical",
      "A row of closed wooden doors in a village lane at sunset, each with a small thistle talisman nailed above it, long shadows across the dust.",
      [N("Двери закрывают до заката. Привычка, о которой никто не говорит.")],
      S(fx=[("latch", 0.5, -8)]), tier="A", cam="zoom_in")
d.add("w", "Long lens, compressed, backlit",
      "Villagers walking home along the lane in pairs at dusk, backlit silhouettes with long shadows, a dog trotting beside them, a bell somewhere.",
      [N("К вечеру все ищут себе пару. Одному в доме ночью нельзя.")],
      S("dusk", "night", fx=[("bell", 0.6, -14), ("life_dog", 2.0, -14)]), tier="B", cam="pan_l")
d.add("t", "Over-the-shoulder, window glow",
      "From behind a hooded figure with a lantern looking at a lit window where a curtain is pulled aside and a pale face looks out into the dark.",
      [N("Я знаю правила. Не знаю только, кто из них не человек.")],
      S("night", "night"), tier="A", cast=("hero",), cam="zoom_in")

d = deck("act2_intro", "Акт II «Мельница»: вход", "act_intro", "Перед главой 4",
         "autumn: rust and slate grey, wet light, cold rain, the lantern is the only warm colour",
         "Усталость и дождь. Музыка: грустная, под конец тревожная.", music="sad")
d.add("w", "Wide shot from the bank, rain",
      "A line of refugees wading a river ford with bundles held over their heads, seen from behind, a water mill with a wooden wheel in the grey background, heavy autumn rain.",
      [N("Осень. До мельницы добираемся вброд, вещи несём над головой.")],
      S("rain_drops", "sad", fx=[("water_drip", 1.0, -12)]), tier="A", cam="pan_r")
d.add("t", "Static, low angle on the wheel",
      "A big wooden mill wheel turning empty, water pouring off its paddles, moss and rot, nothing on the grindstone behind it.",
      [N("Колесо крутится вхолостую. Зерно сюда давно никто не возит.")],
      S("mill"), tier="B", cam="zoom_in")
d.add("t", "Low angle from the water, lantern from below",
      "A heavy miller on wooden planks holding a lantern and counting people with a finger, face lit from below, flour in his eyebrows, rain in the beam.",
      [N("Мельник ждёт на мостках с фонарём. Считает нас по головам. Пересчитывает дважды.")],
      S(fx=[("tick", 0.8, -10), ("tick", 1.6, -10)]), tier="A", cast=("melnik",), cam="zoom_in")
d.add("w", "High angle on the riverbank, wet mud",
      "Strange bare footprints in wet mud leading from the treeline straight to the water's edge and not coming back, rain pooling in them.",
      [N("На берегу чужие следы. Они идут к воде и обратно не возвращаются.")],
      S("river", "tense"), tier="A", cam="pan_l")
d.add("t", "Over-the-shoulder, doorway",
      "From behind a hooded figure with a lantern at the dark mill door, inside rows of sacks and a ring of keys swinging on a hook, nobody visible.",
      [N("За крышу придётся заплатить. Мельник цену пока не называет.")],
      S("mill"), tier="B", cast=("hero",), cam="zoom_in")

d = deck("act3_intro", "Акт III «Монастырь»: вход", "act_intro", "Перед главой 7",
         "winter: blue-white blizzard, black stone walls, a single orange lantern, breath fog",
         "Холод и тишина. Музыка: тревожная, потом хор-дрон.", music="tense")
d.add("w", "Wide, blizzard, low sun",
      "A column of exhausted people trudging knee-deep through snow towards a high black monastery wall, seen from behind, a blizzard blowing across, the wall dark and enormous.",
      [N("Зима пришла раньше дороги. К монастырю идём по колено в снегу и почти молчим.")],
      S("blizzard", "tense"), tier="A", cam="pan_r")
d.add("t", "Low angle, backlit by a lantern",
      "A monk in a hooded black habit standing motionless under a single lantern on a monastery wall, snow falling through the light, face in total shadow.",
      [N("На стене горит один фонарь. Под ним стоит монах и не двигается, пока мы не подходим вплотную.")],
      S(fx=[("creak", 1.0, -10)]), tier="A", cam="zoom_in")
d.add("t", "Extreme low angle, up the tower",
      "A huge iron bell in a snowy bell tower, the rope hanging frozen and still, ice on the rim, a crow on a beam.",
      [N("Над головой молчит колокол.")],
      S(fx=[("crow", 1.0, -12)]), tier="B", cam="pan_u")
d.add("t", "Close-up, soft key light",
      "An old monk with a long white beard and a tall black kamilavka looking straight at the viewer with calm pale eyes, candlelit from the side, snow on his shoulders.",
      [D("ignat", "Колокол пусть молчит. Так лучше для всех.")],
      S("wind"), tier="A", cast=("ignat",), cam="zoom_in")
d.add("w", "Wide static, from inside the gate",
      "Two monks dropping a massive wooden bar across a gate from inside, snow-covered courtyard behind the camera, the people in the gate opening shown as small dark figures.",
      [N("Ворота закрывают до рассвета. Выйти до утра нельзя.")],
      S(fx=[("door_shut", 0.7, -3), ("latch", 1.3, -4)]), tier="B", cam="hold")

d = deck("act4_intro", "Акт IV «Станция»: вход", "act_intro", "Перед главой 10",
         "early spring thaw: grey-green mud, wet rails, thin yellow kerosene light in heavy fog",
         "Надежда, которой не верят. Музыка: светлая, но тихая, потом тревога.", music="hope")
d.add("w", "Wide, low camera on the rails",
      "Two railway tracks shining in thaw mud leading into a pale fog, the snowbank melting along the embankment, a dark treeline.",
      [N("Весна. Снег сошёл, и на насыпи стали видны рельсы. Блестят, будто по ним ходили вчера.")],
      S("wind", "hope", fx=[("water_drip", 1.0, -12)]), tier="A", cam="pan_r")
d.add("t", "Medium, centered, fog",
      "A wooden railway platform sunk in fog, a station-master in a black greatcoat and peaked cap standing by the only lantern, not looking at the camera.",
      [N("Перрон тонет в тумане. Смотритель ждёт у единственного фонаря и не спрашивает, откуда мы.")],
      S("whistle"), tier="A", cast=("smotritel",), cam="zoom_in")
d.add("t", "Straight-on, close",
      "A wooden timetable board on a station wall with a single hand-painted line and a smudged, rubbed-out date, peeling paint, a rusty nail.",
      [N("В расписании на стене один поезд. Дата стёрта.")],
      S(), tier="B", cam="zoom_in")
d.add("t", "Extreme close-up, macro",
      "A brass telegraph key and a paper tape in a dim station office, the key slightly depressed as if just tapped, dust, a kerosene lamp reflected in the brass.",
      [N("Телеграф на столе. Ключ ещё тёплый.")],
      S(fx=[("tick", 0.5, -8), ("tick", 0.8, -8), ("tick", 1.4, -8)], music="tense"), tier="B", cam="zoom_in")
d.add("w", "Wide, dusk, forest edge",
      "The edge of a spruce forest right behind a small wooden railway station, rails running into the dark gap between the trees, a lit window in the station, nothing else.",
      [N("Лес кончился у рельсов. Дальше пути идут в никуда.")],
      S("dusk"), tier="A", cam="pan_l")

# ============================================================ ВЫХОДЫ ИЗ АКТОВ
def outro(act, tag, ru, text, p1, p2, music, amb, snd1=(), cast=()):
    d = deck(f"act{act}_out_{tag}", f"Акт {act}: выход, {ru}", "act_outro",
             f"После главы {act*3}, итог акта: " + ru,
             {1: "pale dawn, cold blue shadows, mist", 2: "grey-gold morning rain on the river", 3: "deep blue snow dawn, orange lantern",
              4: "grey spring dawn"}[act],
             "Музыка: " + ("светлая" if tag == "all" else "грустная"), music=music)
    d.add("w", p1[0], p1[1], [N(text)], S(amb, music, fx=list(snd1)), tier="A", cam="pan_r")
    d.add("t", p2[0], p2[1], [N(p2[2])] if len(p2) > 2 else [], S(), tier="B", cast=cast, cam="zoom_in")
    return d


outro(1, "all", "почти все дошли", "К мельнице деревня уходит почти вся. В пустых домах остаются только обереги.",
      ("Wide, dawn, column from behind", "A long column of villagers with carts and bundles walking along a riverside road at dawn, seen from behind, mist, a church bell far off, the village behind them small."),
      ("Interior, static, deadpan", "An abandoned izba at dawn, door open, wind stirring a cloth on the table, a burnt-out thistle talisman hanging on the lintel, empty benches.", "Обереги догорают сами."),
      "dawn", "day", [("bell", 1.0, -12)])
outro(1, "some", "дошли немногие", "К мельнице уходят немногие. Оглядываться никто не хочет.",
      ("Wide, gaps in the line", "A small group of six people walking far apart on a dusty road at morning, from behind, long shadows, nobody looking back, emptiness on both sides."),
      ("Close, hands", "One hand pulling another by the sleeve to keep walking, a lantern swinging, the village in blurred fog behind them.", "Не оглядывайся."),
      "sad", "wind")
outro(1, "none", "почти никто", "К мельнице я иду без тех, с кем пришёл. От деревни остались имена.",
      ("Wide, solitary figure", "A lone hooded figure with a lantern walking away on a road at dawn, seen from behind, a very long shadow, the village behind on the horizon, empty fields.", ""),
      ("Close on carved wood", "A weathered wooden board by a chapel with rows of carved names, letters illegible, the bottom row crossed out by many knife cuts, moss.", "Имена остаются на доске."),
      "grief", "wind", cast=("hero",))

outro(2, "all", "почти все дошли", "Вверх по реке уходят почти все. Мельничное колесо останавливается за нашими спинами.",
      ("Wide, rain stopping", "A line of people walking upstream along the river bank in the grey morning, mill and wheel far behind and now still, rain clouds opening on a pale strip of sky."),
      ("Static, low", "The mill wheel stopped, water running over its dead paddles, a single crow on the wheel's axle.", "Колесо остановилось."),
      "dawn", "river", [("crow", 1.5, -12)])
outro(2, "some", "дошли немногие", "К монастырю идут немногие. Мельник запирает ворота и остаётся у реки.",
      ("Wide, from the road", "A few travellers on a muddy road looking back at the mill where a heavy miller closes a big gate with a ring of keys, distance, drizzle."),
      ("Close", "A big iron key turning in a rusty padlock on a mill gate, the miller's hand, rain on the knuckles.", "Замок щёлкает."),
      "sad", "rain", [("latch", 1.5, -5)])
outro(2, "none", "почти никто", "К монастырю я иду без тех, с кем начинал. Река уносит то, что осталось от мельницы.",
      ("Wide, flood", "A lone figure on a hill road above a flooded valley, the mill roof barely above brown water, floating planks and a stuck wheel, grey sky, from behind.", ""),
      ("Close, water", "Brown river water carrying a wooden bucket and a scrap of red cloth past the camera, slow, rain rings.", "Река забирает всё."),
      "grief", "river", cast=("hero",))

outro(3, "all", "почти все дошли", "К станции уходят почти все. Брат Игнат закрывает за нами ворота и остаётся звонить.",
      ("Wide, snow dawn", "A column of people leaving the monastery gate at blue dawn on a snowy road, an old monk with white beard closing the gate behind them, orange lantern, bell tower above.", ""),
      ("Low angle", "A bell swinging in the tower against the dawn sky, the rope pulled by unseen hands, snow dust falling.", "Колокол звонит нам вслед."),
      "dawn", "wind", [("bell", 0.8, -4), ("bell", 3.0, -6)], cast=("ignat",))
outro(3, "some", "дошли немногие", "До станции доходят немногие. Колокол звонит нам вслед до самого леса.",
      ("Wide, treeline", "A few figures reaching the edge of a pine forest in deep snow, far behind them a monastery on a hill, tiny, a faint bell cloud of sound visualised only as winter haze.", ""),
      ("Close", "A snowy boot print line leading into the forest, the line broken by one place where a body-shaped dent lies in the snow.", "Не все дошли."),
      "sad", "wind", [("bell", 1.0, -10)])
outro(3, "none", "почти никто", "К станции я иду без тех, с кем начинал. Монастырь за спиной молчит.",
      ("Wide, solitary", "A lone figure in deep snow walking towards a distant forest, a silent monastery on a hill behind, no smoke, no lights, from behind.", ""),
      ("Close", "A frozen rope on a silent bell, ice crystals, no movement, very still.", "Колокол больше не звонит."),
      "grief", "blizzard", cast=("hero",))
d = deck("act3_out_trial", "Акт 3: выход, суд в крипте решил идти", "act_outro",
         "После главы 9, если суд выгнал игрока",
         "cold blue night, cathedral smoke, one lantern, snow", "Музыка: траурная.", music="grief")
d.add("w", "Wide, from the courtyard", "A massive monastery gate closing behind a lone figure standing in the snow outside, a line of monks on the wall with lanterns looking down, nobody speaks.",
      [N("Ворота монастыря закрываются за моей спиной. Остальные пойдут на станцию без меня.")],
      S("blizzard", "grief", fx=[("door_shut", 0.8, -3), ("latch", 1.5, -4)]), tier="A", cast=("hero",), cam="pan_l")
d.add("t", "Over-the-shoulder, far shore", "A hooded figure from behind on a snowy riverbank at night, across the black water a faint lantern and a silhouette calling, mist rising.",
      [N("Я слышу, как кто-то зовёт меня с того берега.")],
      S("river", fx=[("call_far", 1.0, -8)]), tier="A", cast=("hero",), cam="zoom_in")
