"""Предыстории: 12 именных жителей, 5 гостей (с двумя разоблачениями), 4 NPC. И четыре финала."""
from dsl import deck, S, N, D
from cast import CAST

BIO_GRADE = ("warm lamp light against a cold blue window, crushed blacks; the first two frames are memories "
             "(faded sepia-grey film, soft focus), the third frame is the present, sharp and cold")


def bio(cid, kind, deckid, title, frames, music="sad"):
    """frames: три кортежа (план, что в кадре EN, подпись RU, звук)."""
    d = deck(deckid, title, kind, "Карточка жителя в Книге посёлка и при первой встрече",
             BIO_GRADE, "Тихое воспоминание, потом лицо. Музыка: грустная.", music=music)
    for i, (shot, en, cap, snd) in enumerate(frames):
        face = "The face must match the reference exactly and must be clearly visible and recognizable. " if i == 2 else ""
        d.add("t", shot, ("MEMORY frame, faded old film. " if i < 2 else "PRESENT, sharp. ") + en,
              [N(cap)], snd, cast=(cid,), tier="A", cam="zoom_in" if i != 1 else "pan_u")
        d.panels[-1].en = face + d.panels[-1].en
    return d


# ---------------------------------------------------------------- 12 жителей
bio("marina", "bio", "bio_marina", "Марина, перевозчица", [
    ("Medium, profile, golden dusk", "Marina poling a flat ferry raft crowded with silent villagers at sunset, her profile against the water, rope in her scarred hands.",
     "Марина переправляла людей через реку и знала каждого по походке.", S("river", "sad")),
    ("Wide, dusk", "The ferry raft returning to the shore with nobody aboard, the lantern still burning on the bow, the rope slack; Marina on the bank with her hand over her mouth.",
     "Однажды паром вернулся без пассажиров. Фонарь на носу ещё горел.", S(fx=[("call_far", 1.0, -12)])),
    ("Close-up portrait, lantern below", "Marina on the river bank at night, a lantern in her hand with the shutter half closed, staring straight at the viewer, oilskin cape beaded with spray.",
     "Теперь Марина гасит фонарь, когда с того берега зовут. И никому не отвечает.", S("river")),
])
bio("zhenya", "bio", "bio_zhenya", "Женя, знахарка", [
    ("Medium, sickbed, lamp", "Zhenya, an old healer, bending over a sickbed in a miller's house with bowls of herbs and a lamp, a family huddled in the shadows behind her.",
     "Женя лечила семью мельника.", S("night", "sad")),
    ("Wide, dusk, locked house", "A locked miller's house at dusk with a small paper bill nailed to the door (no readable writing), weeds in the yard, shutters closed.",
     "Дом теперь заперт, а счёт за лечение так и висит на двери.", S("wind")),
    ("Close-up portrait, herbs", "Zhenya in her herb room with dried bunches hanging above, wooden prayer beads wound around her hands, stern pale eyes looking straight at the viewer.",
     "Женя знает, чем болела семья мельника. Никому не говорит.", S()),
])
bio("timur", "bio", "bio_timur", "Тимур, могильщик", [
    ("Wide-medium, steam", "Timur digging frozen ground at a village graveyard with a small fire burning on the earth to thaw it, steam rising, winter dawn.",
     "После первой зимы Тимур копал могилы. Земля у нас оттаивает быстрее, чем память.", S("wind", "sad")),
    ("Medium, over the shoulder", "Timur standing over a fresh grave mound that he did not dig, shovel in hand, the edges too neat, frost on the heap.",
     "В одну могилу он не копал. Она уже была.", S(fx=[("crow", 0.8, -12)])),
    ("Close-up portrait, dusk", "Timur with his shovel on his shoulder at the edge of a graveyard at dusk, looking straight at the viewer, mud on his boots, wooden crosses behind him.",
     "Тимур считает могилы вслух. Каждый раз выходит на одну больше.", S("dusk")),
])
bio("lida", "bio", "bio_lida", "Лида, учительница", [
    ("Wide, afternoon light", "Lida standing in an empty village schoolroom with rows of empty benches, a wiped-clean slate board, dust in a sunbeam.",
     "Лида держала деревенскую школу.", S("day", "sad")),
    ("Close on hands", "Lida's ink-stained hand writing names in a thin notebook by lamplight, a row of children's caps still hanging on hooks in the background.",
     "Теперь она записывает имена тех, кто перестал приходить.", S(fx=[("page", 0.5, -10)])),
    ("Close-up portrait, window", "Lida at a night window with her notebook pressed to her chest, head slightly turned as if listening to something behind her, looking at the viewer.",
     "Лида слышит по вечерам, как в пустом классе кто-то отвечает урок.", S("night", fx=[("whisper", 1.0, -14)])),
])
bio("kostya", "bio", "bio_kostya", "Костя, потерявший сестру", [
    ("Wide, dawn, from behind", "A young woman with a bundle of firewood walking into a dark forest at dawn, seen from behind, Kostya small in the foreground at the fence watching.",
     "Сестра Кости ушла в лес за дровами.", S("wind", "sad")),
    ("Medium, interior", "Kostya setting a second bowl at a plain table by a cold stove, the empty bench opposite, a candle.",
     "С тех пор он каждый вечер оставляет ей место у печи.", S("night")),
    ("Close-up portrait, window", "Kostya at a window looking at the black forest line with a lantern at his chest, light on his young face, shutters half open.",
     "Костя до сих пор не закрывает ставни до конца.", S(fx=[("call_far", 1.2, -14)])),
])
bio("tikhon", "bio", "bio_tikhon", "Тихон, сторож моста", [
    ("Wide, night, bridge", "A wooden bridge at night with Tikhon at one end holding a lantern and a thin figure walking out into the mist at the other end.",
     "Тихон дежурил у моста в ту ночь, когда исчез человек.", S("river", "sad")),
    ("Medium, riverside", "Tikhon alone at the river bank talking to his own reflection in the water, one hand gesturing, rehearsing, lantern at his feet.",
     "Объяснение он репетирует до сих пор.", S("river")),
    ("Close-up portrait, lantern", "Tikhon's weary face lit by his lantern, looking straight at the viewer with the expression of someone about to say something and not saying it.",
     "Каждый раз оно получается другим.", S()),
])
bio("zakhar", "bio", "bio_zakhar", "Захар, трактирщик с метлой", [
    ("Wide, tavern at night", "Zakhar sweeping the floor of an empty tavern at night, benches upturned on tables, mugs in rows on a shelf.",
     "Захар подметал трактир.", S("night", "sad")),
    ("Macro, shelf and book", "A tavern ledger with nine mug rings drawn and only six mugs left on the shelf above it, lamp light.",
     "В ночь исчезновения троих в книге осталось шесть кружек.", S(fx=[("cup_break", 1.0, -10)])),
    ("Close-up portrait", "Zakhar leaning on his broom, giving the viewer a stare that ends conversations, leather apron, lamp at his side.",
     "Девять кружек в книге, шесть на полке. Захар не любит, когда их считают.", S()),
])
bio("rita", "bio", "bio_rita", "Рита, часовщица", [
    ("Low angle, tower", "Rita climbing the ladder inside a village clock tower with a tool bag, wooden gears and a weight on a chain around her.",
     "Рита чинила часы на башне.", S("day", "sad")),
    ("Wide, clock face", "The village tower clock face stopped before midnight, Rita's small silhouette looking up at it from the square at night.",
     "Однажды они остановились раньше полуночи.", S(fx=[("tick", 0.5, -8), ("tick", 1.5, -10)])),
    ("Close-up portrait", "Rita with a watchmaker's loupe over one eye, holding a small pocket watch up to the lamp, looking at the viewer with her other eye.",
     "С тех пор Рита проверяет время по своим часам и башне не верит.", S()),
])
bio("misha", "bio", "bio_misha", "Миша, следопыт", [
    ("Medium, doorstep, dawn", "A woman's boots standing neatly on a winter doorstep at dawn, Misha in the doorway looking down at them, fresh snow.",
     "Жена Миши умела читать следы.", S("wind", "sad")),
    ("Wide, tracks", "A line of footprints in deep snow leading from a doorstep into the forest, ending at the treeline, Misha kneeling at the start with a hand on the first print.",
     "Однажды она ушла в лес одна. Обувь осталась у порога.", S("blizzard")),
    ("Close-up portrait", "Misha in his fur ushanka with a coil of rope on his shoulder, watching the treeline with narrow eyes, breath fog.",
     "Миша читает чужие следы и ищет среди них её.", S()),
])
bio("nina", "bio", "bio_nina", "Нина, охотница на волков", [
    ("Wide, snow forest", "Nina with a long rifle at the edge of a snowy pine forest at dusk, shapes of wolves between the trunks, steam of breath.",
     "Нина охотилась на волков.", S("blizzard", "sad", fx=[("wolf", 1.2, -10)])),
    ("Medium, yard", "Neighbours pressing coins into Nina's hand in a yard, looking away from her, wolf tracks in the snow around the yard.",
     "Теперь соседи платят, чтобы она не называла их волками.", S("murmur")),
    ("Close-up portrait", "Nina in a fur hat with a rifle strap on her shoulder, a hard stare straight at the viewer, deep lines, snow on her brow.",
     "Нина знает, как выглядит зверь, который ходит на двух ногах.", S("wind")),
])
bio("vadim", "bio", "bio_vadim", "Вадим, садовник", [
    ("Wide, orchard, autumn", "An old apple orchard behind a small chapel in autumn, baskets of apples under the trees, Vadim picking with a long pole, soft low sun.",
     "Вадим выращивал яблоки за часовней.", S("day", "sad")),
    ("Medium, cellar door", "A locked cellar door in the orchard, apples scattered, frost on the planks, Vadim with an ear to the door listening.",
     "Каждую осень кто-то стучит в запертую кладовую.", S(fx=[("knock", 0.6, -10), ("knock", 1.4, -10)])),
    ("Close-up portrait", "Vadim holding a single apple in his palm, kind tired pale eyes looking straight at the viewer, white beard, a floppy hat.",
     "Вадим не открывает. Он разговаривает с дверью через щёлку.", S()),
])
bio("polina", "bio", "bio_polina", "Полина, мастер ножей", [
    ("Medium, forge", "Polina hammering a blade in a dim forge, sparks flying, rows of finished knives on the wall.",
     "Ножи Полины считались лучшими в деревне.", S("fire", "sad", fx=[("hammer", 0.6, -8)])),
    ("Wide, forge door", "A stranger in a dark coat leaving the forge door with a knife wrapped in cloth and walking into river fog, Polina at the door watching.",
     "Последний заказчик пропал сразу после покупки.", S("wind")),
    ("Close-up portrait", "Polina with scarred forearms holding a knife blade up to the light, looking at the viewer, a girl's face with an adult's tiredness.",
     "Полина больше не берёт заказов. Нож для неё теперь только нож.", S()),
])

# ---------------------------------------------------------------- гости
bio("gordey", "guest", "guest_gordey", "Гордей, солдат без полка", [
    ("Wide, fog road", "A young soldier in an oversized greatcoat walking out of fog along a dirt road, a bundle on his back, rifle-less.",
     "Гордей пришёл с тракта в шинели не по росту.", S("wind", "sad")),
    ("Medium, well at dawn", "The soldier scrubbing a dark stain from the hem of his greatcoat at a village well at dawn, glancing around.",
     "Утром у колодца он отмывал шинель от чего-то тёмного. Сказал, что от глины.", S("day")),
    ("Close, coat lining", "A thumb pulling back the inside of the soldier's greatcoat collar to show an embroidered foreign surname (illegible stitching), his wary eyes in the background.",
     "Внутри шинели вышита чужая фамилия. «С убитого снял», говорит он.", S()),
])
bio("agafya", "guest", "guest_agafya", "Агафья, вдова с телегой", [
    ("Wide, road", "A widow in a black shawl pulling a cart covered with sackcloth along a muddy road in grey light.",
     "Агафья приехала на телеге, укрытой рогожей.", S("wind", "sad")),
    ("Medium, night, cart", "Agafya singing softly beside the cart at night, a lantern at her feet, a dog howling in the background.",
     "Под рогожей спит её сын. Будить нельзя. По вечерам она поёт ему.", S(fx=[("life_dog", 1.0, -10), ("whisper", 0.5, -14)])),
    ("Close-up portrait", "Agafya clutching a child's handkerchief to her chest, looking straight at the viewer with dark circles and a soft smile that does not reach her eyes.",
     "Агафья никого не подпускает к телеге. Говорит, свет ему вреден.", S()),
])
bio("efim", "guest", "guest_efim", "Ефим, торговец оберегами", [
    ("Wide, village road", "A travelling merchant opening a wooden box of thistle-and-salt amulets in front of a small crowd on a muddy village road.",
     "Ефим возит в коробе обереги из чертополоха и соли.", S("day", "sad")),
    ("Medium, gift", "Efim pressing an amulet into the hand of a poor old woman, waving away payment, a warm crooked smile.",
     "Бедным он отдаёт даром. Говорит, деревни по тракту живы благодаря ему.", S("murmur")),
    ("Close, palm", "Efim's palm with a cracked amulet and spilled salt, his shrug and half-smile in the background, lantern light.",
     "Оберег, купленный у Ефима, треснул в первую же ночь. «Значит, плохо держали».", S(fx=[("glass", 0.5, -10)])),
])
bio("stepan", "guest", "guest_stepan", "Степан, рабочий депо", [
    ("Medium, engine shed", "A depot worker patting the side of a big black steam locomotive in a shed like a horse, oil and soot, lantern.",
     "Двадцать лет при депо. Степан знает каждый болт в паровозе.", S("rails", "sad")),
    ("Low angle, under locomotive", "Stepan lying under a locomotive with a small lantern and a wrench, only his boots and hands in view, drips of oil.",
     "Говорит, машина пойдёт, если её не бросать.", S(fx=[("hammer", 0.8, -8)])),
    ("Close-up portrait", "Stepan's black oily hands on a wrench and his stern sooty face turning to the viewer, fur hat, padded jacket.",
     "Степан не боится ночи. Он боится, что поезд придёт без машиниста.", S()),
])
bio("pisar", "guest", "guest_pisar", "Аркадий, писарь", [
    ("Medium, office", "A neat clerk at a small desk writing a long list in beautiful handwriting under a lamp, bowler hat on the desk, spectacles.",
     "Аркадий служил в уездной управе. Почерк ровный, улыбка вежливая.", S("type", "sad")),
    ("Macro, pocket", "Silver coins clinking in a coat pocket, a clerk's hand pushing them deeper, a lantern in the background.",
     "У него в кармане звенит. Утром он купил у смотрителя керосин и расплатился серебром.", S(fx=[("tick", 0.4, -10)])),
    ("Close-up portrait", "The clerk in his round spectacles and bowler hat with a polite thin smile, looking at the viewer, a notebook held up.",
     "Список на поезд пишет он, потому что больше никто не умеет писать так быстро.", S("type")),
])


def reveal(cid, human, ru_title, frames):
    d = deck(f"guest_{cid}_{'human' if human else 'upyr'}", f"{ru_title}: " + ("человек" if human else "упырь"), "guest",
             "На утро разгадки, на третьем утре гостя" , BIO_GRADE if human else
             "bruised blue night, a single lantern, cold greens, long shadows",
             "Музыка: грустная." if human else "Музыка: тревожная.", music="sad" if human else "tense")
    for i, (shot, en, cap, snd) in enumerate(frames):
        d.add("t", shot, en, [N(cap)], snd, cast=(cid,), tier="B", cam="zoom_in")
    return d


reveal("gordey", True, "Гордей", [
    ("Wide, forest run", "A young soldier running through a dark forest away from distant gunfire and smoke, looking back over his shoulder, the greatcoat flaring.",
     "Гордей сбежал из полка, когда его окружили в лесу.", S("wind", fx=[("gasp", 0.6, -8)])),
    ("Medium, table", "The soldier alone at the end of a long table eating, everyone's shoulders turned away from him, his eyes down.",
     "Он не упырь. Он боится, что мы теперь бросим его.", S("murmur")),
])
reveal("gordey", False, "Гордей", [
    ("Wide, riverbank dawn", "A riverbank at dawn with empty army greatcoats lying scattered on the grass, boots, helmets, no bodies, mist.",
     "У реки, где стоял его полк, пустые шинели и ни одного тела.", S("river")),
    ("High angle, footprints", "Wet bare footprints leading from the riverbank across a field to a doorstep where a shadow of a soldier sleeps sitting up.",
     "От шинелей к деревне ведут босые следы. Такие же у порога, где он спит.", S(fx=[("breath_3", 0.8, -10)])),
])
reveal("agafya", True, "Агафья", [
    ("Close, cart", "Sackcloth lifted from a cart to reveal a small child's linen shirt and tiny boots laid out neatly on straw.",
     "Под рогожей детская рубашка и маленькие сапоги.", S(fx=[("weep", 0.6, -10)])),
    ("Medium, sitting", "Agafya sitting on the ground with the small shirt pressed to her face, shoulders shaking, the empty cart behind, soft grey light.",
     "Сына у неё нет уже год. Она так и не смогла его похоронить.", S("wind")),
])
reveal("agafya", False, "Агафья", [
    ("Close, cart", "Sackcloth lifted from a cart to reveal only straw with dark brown stains and a small dent where something lay.",
     "Под рогожей пусто. Только солома в бурых пятнах.", S(fx=[("scare", 0.8, -18)])),
    ("Wide, night", "Agafya smiling softly at the cart at night, her face lit by a lantern, and just beyond the light a crouched dark silhouette bent low.",
     "«Он вышел погулять», улыбается Агафья. Ночью у телеги кто-то тихо ест.", S("night", fx=[("breath_3", 1.0, -10)])),
])
reveal("efim", True, "Ефим", [
    ("Medium, river night", "The merchant kneeling at the riverbank at night bandaging a wounded man's arm with torn cloth by lantern light, blood on his hands.",
     "Полночи Ефим перевязывал раненого у реки.", S("river")),
    ("Close, mixing", "A bowl of chalk and salt being ground with a spoon to make fake amulets, the merchant's ashamed face lit from the side.",
     "Обереги у него поддельные: соль пополам с мелом. Он нажился на вашем страхе.", S()),
])
reveal("efim", False, "Ефим", [
    ("Macro, box", "The false bottom of a wooden merchant's box lifted to reveal thin gnawed bones, dust, thistle heads.",
     "На дне короба тонкие обглоданные кости.", S(fx=[("scare", 0.8, -18)])),
    ("Close, grin", "The merchant's crooked smile in the dark with a lantern held under his chin, eyes catching the light like an animal's.",
     "Обереги он делал из того, что оставалось от покупателей.", S(fx=[("growl", 1.0, -12)])),
])
reveal("stepan", True, "Степан", [
    ("Medium, shed night", "Stepan repairing a locomotive by lantern at night, a worn leather belt in his hands, soot.",
     "Степан чинил паровоз по ночам, чтобы успеть до прихода поезда.", S("rails", fx=[("hammer", 0.8, -8)])),
    ("Close, belt", "A worn leather belt taken from a dead fireman held in Stepan's black hands, his sad face above it.",
     "Ремень он снял с погибшего кочегара, чтобы заменить порванный.", S()),
])
reveal("stepan", False, "Степан", [
    ("Low angle, firebox", "An open locomotive firebox glowing orange, scraps of cloth and a boot heel among the ashes, heat shimmer.",
     "Паровоз Степан не чинил. В топке нашли обрывки одежды тех, кто ушёл к депо и не вернулся.", S("fire", fx=[("fire_crackle", 0.5, -8)])),
    ("Wide, shed", "A silhouette of a man standing perfectly still in the dark engine shed, eyes catching the light, a cold lantern at his feet.",
     "Он стоит у паровоза всю ночь и не двигается.", S(fx=[("breath_3", 1.0, -10)])),
])
reveal("pisar", True, "Аркадий", [
    ("Medium, bribe", "The clerk accepting a pouch of coins through a window slot from a frightened woman, his hand pale, lamp light.",
     "Аркадий брал деньги за место в списке. Кто платил, оказывался выше.", S("type", fx=[("tick", 0.4, -10)])),
    ("Close, list", "A long list of names with tiny numbers and ink marks beside them, spectacles lying on the page.",
     "Он не упырь. Он просто продавал спасение.", S(fx=[("page", 0.6, -10)])),
])
reveal("pisar", False, "Аркадий", [
    ("Wide, night platform", "A night platform with a line of people's belongings left neatly in a row, no people, a long shadow of a thin man standing at the end with a notebook.",
     "Аркадий брал за место в списке не деньги.", S("wind", fx=[("breath_3", 1.0, -10)])),
    ("Close, spectacles", "Round spectacles reflecting a lantern with two pale points of light behind them, the face dark, a pencil in a thin hand.",
     "Те, кто ему заплатил, ночью не вернулись с перрона.", S(fx=[("scare", 0.8, -18)])),
])

# ---------------------------------------------------------------- NPC
bio("melnik", "npc", "npc_melnik", "Мельник Савелий", [
    ("Wide, dusk, mill wheel", "A young girl's silhouette waving from the far bank of a river at dusk, the mill wheel turning behind, the miller small on the near side.",
     "У Савелия была дочь. Она ушла за реку.", S("mill", "sad")),
    ("Medium, door in rain", "The miller opening his door at night to a small silhouette standing in the rain with a hand extended, his face broken with hope.",
     "В ту ночь он узнал её голос и открыл. Это была не она.", S("rain", fx=[("door_open", 0.6, -6)])),
    ("Close-up portrait", "The miller at a table covered with burnt candle stubs, his ledger beside them, looking straight at the viewer with heavy tired eyes.",
     "С тех пор он пускает за плату. Деньги идут на свечи для неё.", S("mill")),
])
bio("ignat", "npc", "npc_ignat", "Брат Игнат", [
    ("Medium, scriptorium", "An old monk writing names in a thick book at a high desk by candlelight, many shelves of identical books behind him.",
     "Брат Игнат ведёт книгу у ворот. Он вписывает всех, кто пришёл.", S("church", "sad")),
    ("Macro, book", "A page of a monastery book with rows of names, small crosses drawn beside many of them, an old hand holding a quill.",
     "Возле имён пришедших раньше теперь кресты. Не все кресты его.", S(fx=[("page", 0.5, -10)])),
    ("Close-up portrait", "Brother Ignat with his tall kamilavka and long white beard standing by a silent bell rope, his pale stern eyes looking at the viewer.",
     "Он не звонит в колокол. Говорит, так лучше.", S("church")),
])
bio("anfisa", "npc", "npc_anfisa", "Сестра Анфиса", [
    ("Medium, candle", "A young novice copying lines from a hidden second book by a candle at night, a ring of keys at her belt, a shadow on the wall.",
     "Сестра Анфиса переписывает вторую книгу. Ту, о которой нельзя спрашивать при Игнате.", S("church", "sad")),
    ("Close, hands through gate", "A novice's hand passing a small notebook through the bars of a gate into the hero's hand, snow falling.",
     "Главное она переписала в мою тетрадь.", S(fx=[("page", 0.5, -10)])),
    ("Close-up portrait", "Anfisa with her huge dark eyes in the black veil looking straight at the viewer, a candle flame trembling before her face.",
     "Она боится не ночи. Она боится, что ей не поверят.", S()),
])
bio("smotritel", "npc", "npc_smotritel", "Смотритель станции", [
    ("Wide, platform seasons", "A stationmaster standing on the same wooden platform with a lantern, the scene faded and layered as if the years passed over him, winter and spring in one frame.",
     "Смотритель тридцать лет встречает на этом перроне один и тот же поезд.", S("whistle", "sad")),
    ("Medium, desk", "The stationmaster writing a list in a ledger with a shaking hand, lamp, a telegraph key beside him.",
     "Он пишет список. Мест меньше, чем людей.", S("type")),
    ("Close-up portrait", "The stationmaster holding up a pocket watch on a chain beside his lantern, stern pale eyes looking at the viewer, peaked cap with a small eagle badge.",
     "Часы у него идут точно. Это единственное, в чём он уверен.", S("train")),
])

# ---------------------------------------------------------------- финалы
FIN_GRADE = "dawn at the station after the last night: blue and gold, steam, hope or loss according to the frame"


def final(fid, title, music, frames):
    d = deck(fid, title, "finale", "Конец кампании, после финальной главы", FIN_GRADE, "Музыка: " + music, music=music)
    for i, (sz, shot, en, cap, snd) in enumerate(frames):
        d.add(sz, shot, en, [N(cap)], snd, tier="A" if i in (0, 4) else "B", cam="pan_r" if sz == "w" else "zoom_in")
    return d


final("final_shore", "Финал: тот берег", "dark", [
    ("t", "POV from inside, door opening", "The heavy waiting-hall door opening from inside onto the dark, a pale figure in the doorway lit warmly from behind, features unreadable, a hand extended.",
     "Я открываю. На пороге тот, кого не стало раньше всех.", S("night", "tense", fx=[("door_open", 0.5, -4)])),
    ("t", "Extreme close-up, hands", "A pale hand taking the hand of the hero (only hands in frame), the lantern placed on the floor between them, frost on the boards.",
     "Дверь закрывается за нами.", S(fx=[("door_shut", 0.8, -4)])),
    ("w", "Wide, blue dawn", "Two silhouettes walking side by side along the empty platform toward a river in blue dawn mist, seen from behind.",
     "Мы идём к реке. Никто не оглядывается.", S("river", "grief")),
    ("t", "High angle, platform", "A train pulling out of the station at sunrise with its carriages empty and lit, the platform behind it deserted.",
     "Утром поезд уходит без меня.", S("train", "grief")),
    ("t", "High angle, footprints", "Two sets of footprints in frost leading from a station platform down to the black river edge and disappearing into water, mist.",
     "На перроне остаются мои следы. Они ведут к реке.", S("river", fx=[("call_far", 1.0, -10)])),
])
final("final_upyr", "Финал: купе", "tense", [
    ("w", "Wide, train interior", "A packed quiet train carriage at dawn, passengers shoulder to shoulder, grey light on their faces, nobody speaking, the aisle narrow.",
     "Поезд уходит на рассвете. В вагоне тесно и тихо.", S("train", "tense")),
    ("t", "Reflection in window", "A night train window with passing black forest, the reflected faces of passengers and one empty place in the reflection where a person sits.",
     "В окне я считаю лица. В отражении одного не хватает.", S("train")),
    ("t", "Platform at night", "A small night platform seen from a train step as passengers get off and on, steam, a lantern, the last compartment's door shut.",
     "На третьей станции из последнего купе перестают выходить люди.", S("whistle", fx=[("door_shut", 1.0, -6)])),
    ("t", "Low angle, compartment door", "The closed sliding door of the last train compartment with a thin line of lantern light under it and a long shadow of a hand.",
     "Дверь закрыта изнутри.", S(fx=[("scratch", 0.8, -10), ("breath_3", 1.8, -10)])),
    ("t", "Close, list", "Hands holding a crumpled passenger list with one name crossed out in ink, lantern light, the train swaying.",
     "Упырь из списка едет с нами.", S("train", fx=[("growl", 1.5, -14)])),
])
final("final_many", "Финал: почти все", "dawn", [
    ("w", "Wide, train at sunrise", "A steam train in morning light on an embankment through a spruce forest, every carriage window lit, faces behind the glass.",
     "Поезд уходит на рассвете. В вагоне почти все, кто вышел из деревни.", S("train", "dawn")),
    ("t", "Medium, interior", "A crowded carriage with people sharing bread and a kettle, tired faces softening, steam, warm light.",
     "Передаём хлеб по рукам. Руки больше не дрожат.", S("murmur")),
    ("t", "Window view", "A carriage window with the dark spruce forest thinning into open fields and a pale sunrise, dew on the glass.",
     "За окном лес редеет.", S("train")),
    ("t", "Close, lantern", "A kerosene lantern in the hero's hand on a carriage seat, its flame small and steady, a sleeping passenger's shoulder.",
     "Фонарь горит ровно.", S()),
    ("w", "Wide, golden field", "A train crossing a golden open field at sunrise, a long plume of steam trailing, the forest a dark line behind.",
     "Лес за окном кончается, и никто больше не стучит.", S("train", "hope")),
])
final("final_few", "Финал: пустые места", "sad", [
    ("w", "Wide interior, empty seats", "A long train carriage with many empty wooden seats in grey dawn light, dust floating, three passengers far apart.",
     "Поезд уходит на рассвете. В вагоне много пустых мест.", S("train", "sad")),
    ("t", "Close, seats", "A cap, a shawl and a small bundle left on empty seats as if just vacated, grey light.",
     "Кто-то оставил шаль. Кто-то шапку.", S()),
    ("t", "Over-the-shoulder, aisle", "From behind a hooded figure with a lantern walking down the empty aisle counting the seats with a hand on each backrest.",
     "Я иду по вагону и считаю места.", S("train"), ),
    ("t", "Window", "A train window with the dense dark forest still close and one pale faint reflection of the hero's hands holding a lantern.",
     "Лес за окном не кончается.", S("train")),
    ("t", "Medium, hero seated", "The hero seen from behind sitting alone by a window at sunrise, the lantern on the seat beside, the empty seats beyond.",
     "Я помню, кто должен был на них сидеть.", S("train", "grief")),
])
