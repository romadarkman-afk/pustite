"""Состав комикса: лица, которые должны узнаваться во всех картинках.

Каждый персонаж: id, имя, роль, портрет из игры (assets/folk), приметы лица для ChatGPT на английском.
Приметы списаны с игровых портретов (game/assets/folk/realistic), чтобы лицо в комиксе совпадало с лицом на поле.
Именные жители привязаны к портретам по возрасту (SocialContent.AGES) и роду занятий (PEOPLE_RU); та же таблица в игре:
VillagerFigure.NAMED_SPRITES. Менять обе вместе, `--slides` сверяет.
"""

# (id, имя, роль, спрайт в game/assets/folk/realistic, приметы лица EN, одежда EN)
CAST = {
    # ---------- 12 именных жителей (предыстории) ----------
    "marina": dict(
        ru="Марина", role="перевозчица", sprite="f9", sex="f", age=34,
        face="woman about 34 who looks older than her years, auburn hair under a brown headscarf with red ties, light freckles over the nose, large sad grey-blue eyes, narrow tired face, pale lips, a look of someone who keeps listening for a call from the far bank",
        wear="patched linen blouse with a dark worn skirt, a brown shawl, an oilskin cape on the river, rope-scarred hands"),
    "lida": dict(
        ru="Лида", role="учительница", sprite="f12", sex="f", age=61,
        face="woman about 61, grey hair under a black fringed wool shawl, narrow severe face with deep lines, grey eyes, thin straight pale lips, a head slightly tilted as if she is always listening to a classroom that is empty",
        wear="black fringed shawl, long dark patched dress, ink-stained fingertips, a small thin notebook"),
    "zhenya": dict(
        ru="Женя", role="знахарка, фельдшер", sprite="f10", sex="f", age=47,
        face="woman about 47, light-brown hair pulled into a low bun, long stern face, thin tight mouth, green-grey eyes with tired lids, weathered skin with sun lines, two vertical frown lines between the brows",
        wear="brown wool shawl over a faded red-patterned sarafan, a wicker basket of dried herbs on her arm, little cloth pouches on her belt"),
    "rita": dict(
        ru="Рита", role="часовщица", sprite="f3", sex="f", age=29,
        face="woman about 29 who looks younger, very pale skin, long thick blonde braid over one shoulder, light blue-grey eyes, small serious mouth, high forehead, calm unblinking look",
        wear="plain linen blouse with a dark apron full of small tools, a magnifying lens on a cord, fine steady hands"),
    "nina": dict(
        ru="Нина", role="охотница на волков", sprite="f11", sex="f", age=58,
        face="stout woman about 58, heavy jowls and strong jaw, grey hair under a brown headscarf, severe grey eyes under a heavy brow, deep lines from nose to mouth, a face that does not smile",
        wear="dark floral dress under a sheepskin vest, fur hat when outdoors, old long rifle on a strap"),
    "polina": dict(
        ru="Полина", role="кузнец ножей", sprite="f1", sex="f", age=56,
        face="woman about 56, deeply lined severe face, grey eyebrows, pale blue-grey eyes, thin straight mouth, brown headscarf with a faded red pattern pulled low, a stocky solid build",
        wear="heavy patched brown coat over a scorched leather apron, wooden beads wound round one wrist, burn scars on both forearms"),
    "timur": dict(
        ru="Тимур", role="могильщик", sprite="f2", sex="m", age=41,
        face="man about 41, thick red-brown beard with a few grey hairs, blue eyes under heavy lids, broken nose bridge, deep creases at the eyes, flat worker's cap",
        wear="worn coat with a fur collar, mud to the knees, a shovel always in reach"),
    "kostya": dict(
        ru="Костя", role="потерял сестру", sprite="f4", sex="m", age=21,
        face="young man about 21, light-brown hair under a flat cap, light blue eyes, thin clean-shaven face, sharp cheekbones, restless alert look, a small old scar on the chin",
        wear="brown vest over a maroon shirt, red sash belt, patched trousers"),
    "tikhon": dict(
        ru="Тихон", role="сторож моста", sprite="f13", sex="m", age=54,
        face="man about 54, short greying brown hair, long deeply lined weary face, grey stubble, heavy-lidded sad eyes, drooping corners of the mouth",
        wear="dark long coat, a coil of rope or net over one shoulder, an old kerosene lantern in hand"),
    "zakhar": dict(
        ru="Захар", role="трактирный подметальщик", sprite="f7", sex="m", age=23,
        face="broad heavy young man of 23 who looks ten years older, short dark hair, thick brow, narrowed stern eyes, square jaw with dark stubble, a nose broken once, a stare that shuts conversations",
        wear="scorched leather apron over a grey shirt, huge forearms, a worn broom or a hammer"),
    "misha": dict(
        ru="Миша", role="следопыт, вдовец", sprite="f8", sex="m", age=45,
        face="lean man about 45, narrow grey eyes, weathered tanned face with a trimmed stubble, thin lips, a watchful look that checks every corner",
        wear="fur ushanka with the ear flaps down, sheepskin collar, brown scarf, hunting knife, coil of rope, leather satchel"),
    "vadim": dict(
        ru="Вадим", role="садовник", sprite="f14", sex="m", age=26,
        face="thin man about 26 with a prematurely aged face, grey-streaked dark hair falling over the forehead, hollow cheeks, deep tired eyes, stubble, a gentle patient look",
        wear="torn linen shirt with rolled sleeves, bast shoes with wrapped legs, a long fruit-picking pole, apple juice stains on the cuffs"),

    # ---------- гости кампании ----------
    "gordey": dict(
        ru="Гордей", role="солдат без полка", sprite="guest_soldier", sex="m", age=25,
        face="young soldier about 25, completely shaved head, narrow face with high cheekbones, grey-blue wary eyes, thin lips, sunken cheeks of a man who has not slept for days",
        wear="olive army greatcoat that is too big for him, shoulder straps, brass buttons, mud and a dark stain on the hem"),
    "agafya": dict(
        ru="Агафья", role="вдова с телегой", sprite="guest_widow", sex="f", age=40,
        face="woman about 40, dark hair under a heavy black wool shawl, dark circles under grey eyes, pale lips, a face that stopped hoping but keeps smiling softly",
        wear="black shawl with a patched corner, a small child's handkerchief clutched against the chest, long dark skirt"),
    "efim": dict(
        ru="Ефим", role="торговец оберегами", sprite="guest_merchant", sex="m", age=50,
        face="man about 50, round warm face, crooked friendly smile, laughing lines, small clever dark eyes, brown fur hat",
        wear="dark long coat with frog fasteners, leather satchel on a strap, a wooden box of thistle-and-salt amulets"),
    "stepan": dict(
        ru="Степан", role="рабочий депо", sprite="guest_worker", sex="m", age=45,
        face="man about 45, stern square face, grey stubble, deep-set tired eyes, fur ushanka with ear flaps, soot in the creases of the skin",
        wear="padded quilted jacket, wrapped felt boots, a small kerosene lantern, black hands"),
    "pisar": dict(
        ru="Аркадий", role="писарь", sprite="guest_clerk", sex="m", age=50,
        face="thin man about 50, narrow face, small round wire spectacles, thin pressed lips, cold attentive eyes, black bowler hat",
        wear="long black greatcoat, a small notebook and a pencil stub, ink on the right index finger"),

    # ---------- лица сюжета ----------
    "ignat": dict(
        ru="Брат Игнат", role="монах, рассказчик акта III", sprite="npc_abbot", sex="m", age=75,
        face="old monk about 75, tall black kamilavka, long white beard and white hair, pale stern eyes, a long straight nose, a gaunt calm face",
        wear="black wool robe, wooden pectoral cross on a chain, a ring of keys at the belt"),
    "anfisa": dict(
        ru="Сестра Анфиса", role="послушница", sprite="npc_nun", sex="f", age=22,
        face="young novice about 22, black hood and veil, huge sad dark eyes, pale narrow face, trembling lower lip",
        wear="black habit, a ring of iron keys at the belt, rough hands"),
    "smotritel": dict(
        ru="Смотритель", role="смотритель станции", sprite="npc_stationmaster", sex="m", age=60,
        face="man about 60, peaked railway cap with a small imperial eagle badge, grey moustache, deep nasolabial folds, stern pale eyes, a face of a man who has seen the same platform for thirty years",
        wear="black railway greatcoat with epaulettes, a watch chain, white gloves gone grey, a ledger under the arm and a lantern"),
    "melnik": dict(
        ru="Мельник Савелий", role="хозяин мельницы", sprite="npc_worker", sex="m", age=60,
        face="heavy man about 60, flour dust in his grey hair and eyebrows, small shrewd eyes, big fleshy hands, a face that counts everything, deep sorrow hidden behind the stare",
        wear="flour-covered apron over a thick grey sweater, a heavy ring of keys and a small ledger book at the belt"),

    # ---------- статисты (лица для толпы; именных жителей в сюжетных колодах нет, потому что они могли погибнуть) ----------
    "extra_thin": dict(
        ru="Худой старик", role="статист", sprite="f5", sex="m", age=72,
        face="thin old man about 72, long white beard and unkempt white hair, deep-set pale grey eyes, hooked nose, a gentle stooped face with heavy bags under the eyes",
        wear="floppy patched felt hat, long patched brown coat, bast shoes with wrapped legs, a walking stick"),
    "extra_boy": dict(
        ru="Мальчик", role="статист", sprite="f15", sex="m", age=14,
        face="boy about 14, ginger-brown hair under a flat cap, intense light eyes, freckles, a serious face",
        wear="patched shirt with a red sash, a cloth in his hand"),
    "extra_pilgrim": dict(
        ru="Странник", role="статист", sprite="f16", sex="m", age=55,
        face="man about 55, long grey-brown hair, long grey beard, calm stern eyes",
        wear="dark long coat with a wooden cross and prayer beads, a book under the arm"),
}

# Говорящие без лица в кадре (подпись «Гость»): id -> русское имя; в игре берётся перевод slides.who_<id>.
EXTRA_WHO = {"guest": "Гость"}

# Что нельзя показывать и как показывать героя и упыря.
HERO = ("The player character (called 'the hero') is NEVER shown from the front and the face is never visible: "
        "only from behind, a shoulder, hands, a silhouette or a reflection. Sheepskin coat, hood or headscarf, "
        "a kerosene lantern in the left hand.")
UPYR = ("The upyr (monster) is NEVER shown clearly: only a thin tall silhouette, pale long-fingered hands, wet bare footprints, "
        "eyes that catch the light like an animal's. No fangs, no gore.")


def face_lock(cid: str) -> str:
    c = CAST[cid]
    return f"{c['ru']} / {cid}: {c['face']}. Wears: {c['wear']}."
