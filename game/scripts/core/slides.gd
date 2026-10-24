class_name Slides
extends RefCounted
## Комиксы «Пустите» (TASK-101): колоды кадров с подписями и звуковой картой.
## Данные лежат в config/slides.json (кадры, камера, звук) и config/slides_text.json (подписи по языкам).
## Их собирает tools/slides/build.py из раскадровок; картинки кладутся в assets/slides/<колода>/<NN>.webp|jpg|png.
## Нет картинки: кадр рисуется заглушкой из старого арта (SlideStand), игра не ломается.

const DATA_PATH := "res://config/slides.json"
const TEXT_PATH := "res://config/slides_text.json"
const ART_DIR := "res://assets/slides/"
const EXTS: PackedStringArray = ["webp", "jpg", "png"]

## Музыка и фон, которых ещё нет в игре, играют ближайшим из имеющихся (TASK-123, 124 запишут настоящие).
const MUSIC_FALLBACK := {
	&"theme_sad": &"night", &"theme_grief": &"night", &"theme_tense": &"night", &"theme_hope": &"day",
}
## Песня, которой заканчивается колода: [песня, с какого кадра (с 0)]. С этого кадра вместо музыки колоды играет песня.
## Нет файла песни: музыка колоды идёт как раньше.
const DECK_SONGS := {
	"act1_out_all": ["song_lullaby", 0], "act1_out_some": ["song_lullaby", 0], "act1_out_none": ["song_lullaby", 0],
	"act2_out_all": ["song_mill", 0], "act2_out_some": ["song_mill", 0], "act2_out_none": ["song_mill", 0],
	"act3_out_all": ["song_bell", 0], "act3_out_some": ["song_bell", 0], "act3_out_none": ["song_bell", 0], "act3_out_trial": ["song_bell", 0],
	"final_many": ["song_train", 2], "final_few": ["song_train", 2],
	"final_shore": ["song_shore", 2], "final_upyr": ["song_pustite", 3],
}
const AMB_FALLBACK := {
	&"amb_fire": &"amb_night", &"amb_bog": &"amb_night", &"amb_church": &"amb_night", &"amb_crowd": &"life_murmur",
}

## Именной житель кампании -> его место в списке имён языка (L.names()).
const VILLAGER_SLOT := {
	"marina": 0, "timur": 1, "lida": 2, "kostya": 3, "zhenya": 4, "tikhon": 5,
	"zakhar": 6, "rita": 7, "misha": 8, "nina": 9, "vadim": 10, "polina": 11,
}
## Лицо комикса -> гость в локализации (guest.<ключ>.name).
const GUEST_KEY := {"gordey": "soldier", "agafya": "widow", "efim": "merchant", "stepan": "worker", "pisar": "clerk"}

## Гость в игре (Guests.LIST) -> лицо комикса.
const GUEST_BY_GAME := {"soldier": "gordey", "widow": "agafya", "merchant": "efim", "worker": "stepan", "clerk": "pisar"}

static var _data: Dictionary = {}
static var _text: Dictionary = {}
static var _loaded := false


static func reload() -> void:
	_loaded = false
	_ensure()


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_data = _read(DATA_PATH)
	_text = _read(TEXT_PATH)


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func decks() -> Dictionary:
	_ensure()
	var d: Variant = _data.get("decks", {})
	return d if d is Dictionary else {}


static func deck_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in decks():
		out.append(String(k))
	return out


static func has_deck(id: String) -> bool:
	return decks().has(id)


static func deck(id: String) -> Dictionary:
	var d: Variant = decks().get(id, {})
	return d if d is Dictionary else {}


static func panels(id: String) -> Array:
	var p: Variant = deck(id).get("panels", [])
	return p if p is Array else []


## Подпись по ключу: язык игры, потом английский, потом русский. Нет ни одной — пусто (ключ игроку не показываем).
static func text(key: String) -> String:
	_ensure()
	for lang: String in [L.code, "en", "ru"]:
		var table: Variant = _text.get(lang, null)
		if table is Dictionary and (table as Dictionary).has(key):
			return String((table as Dictionary)[key])
	return ""


## Имя говорящего: жителям и гостям даём их имена в выбранном языке, остальным имя из таблицы колод (по-русски).
static func who_name(id: String) -> String:
	_ensure()
	if id.is_empty():
		return ""
	if VILLAGER_SLOT.has(id):
		var names := L.names()
		var slot := int(VILLAGER_SLOT[id])
		if slot < names.size():
			return String((names[slot] as Array)[0])
	if id == "guest":
		return L.t("slides.who_guest")
	if GUEST_KEY.has(id):
		var key := "guest.%s.name" % GUEST_KEY[id]
		if L.has(key):
			return L.t(key)
	var w: Variant = _text.get("who", {})
	if w is Dictionary and (w as Dictionary).has(id):
		return String((w as Dictionary)[id])
	return ""


## Спрайт игрового портрета для лица комикса (cast.py): нужен заглушке, пока нет картинок.
static func cast_sprite(cast_id: String) -> String:
	_ensure()
	var c: Variant = _data.get("cast", {})
	if c is Dictionary and (c as Dictionary).has(cast_id):
		return String((c as Dictionary)[cast_id])
	return ""


static func card(id: String) -> String:
	return text(String(deck(id).get("card_key", "")))


static func title(id: String) -> String:
	return text(String(deck(id).get("title_key", "")))


## Путь к картинке кадра или "", если картинки ещё нет.
static func art_path(panel: Dictionary) -> String:
	var base := ART_DIR + String(panel.get("file", ""))
	for ext: String in EXTS:
		var p := base + "." + ext
		if ResourceLoader.exists(p):
			return p
	return ""


static func panel_art_ready(panel: Dictionary) -> bool:
	return not art_path(panel).is_empty()


## Сколько кадров колоды уже с настоящей картинкой.
static func art_count(id: String) -> int:
	var n := 0
	for p: Variant in panels(id):
		if p is Dictionary and panel_art_ready(p as Dictionary):
			n += 1
	return n


## Номер акта колоды (0 — колода без акта: предыстория, предыстории жителей, финалы).
static func act_of(id: String) -> int:
	var d := deck(id)
	if d.has("act"):
		return int(d.act)
	return 0


## Проверка звуковой карты кадра. Возвращает проблемы (пусто — всё в порядке).
## Звук, которого ещё нет в игре, не считается ошибкой, если он есть в списке «ещё не записан» (needs_audio) или имеет замену.
static func sound_problems(panel: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var last_at := -1.0
	for ev: Variant in panel.get("sound", []):
		if not (ev is Dictionary):
			out.append("событие не словарь")
			continue
		var e := ev as Dictionary
		var at := float(e.get("at", 0.0))
		if at < last_at:
			out.append("события не по порядку времени: %s" % str(e))
		last_at = at
		var op := String(e.get("do", ""))
		if not ["start", "stop", "play", "silence", "keep"].has(op):
			out.append("неизвестное действие %s" % op)
		if op == "start" or op == "play":
			if String(e.get("id", "")).is_empty():
				out.append("%s без id" % op)
		if op == "start" and not ["amb", "music"].has(String(e.get("layer", ""))):
			out.append("start без слоя amb или music")
	return out


## Что должна играть музыка в событии: само имя или замена, если файла ещё нет. Пусто — оставить как есть.
static func music_for(id: StringName) -> StringName:
	if Sfx.has_sound(id):
		return id
	return MUSIC_FALLBACK.get(id, &"")


## Песня на кадре i колоды или пусто: колода без песни, кадр раньше песни, файла песни нет.
static func song_for(id: String, i: int) -> StringName:
	var e: Variant = DECK_SONGS.get(id)
	if not (e is Array):
		return &""
	var song := StringName(String((e as Array)[0]))
	if i < int((e as Array)[1]) or not Sfx.has_sound(song):
		return &""
	return song


## Озвучка есть только на русском: подписи на других языках переведены, чужой голос под ними не нужен.
static func voice_on() -> bool:
	return L.code == "ru"


## Файл озвучки подписи по ключу «sl.<колода>.<кадр>.<строка>» или "" (нет файла, язык не русский).
static func voice_path(key: String) -> String:
	if not voice_on():
		return ""
	return voice_file(key)


## Подмена для самотестов: ключ подписи -> путь к ресурсу озвучки.
static var voice_test: Dictionary = {}


## То же без проверки языка: для самотестов и ingest.
static func voice_file(key: String) -> String:
	if voice_test.has(key):
		return String(voice_test[key])
	var parts := key.split(".")
	if parts.size() < 4 or parts[0] != "sl":
		return ""
	var p := "%s%s/%s.ogg" % [Sfx.VOICE_DIR, parts[1], "_".join(parts.slice(2))]
	return p if ResourceLoader.exists(p) else ""


## Озвучка кадра: файл первой подписи с текстом или "".
static func panel_voice(panel: Dictionary) -> String:
	for l: Variant in panel.get("lines", []):
		if l is Dictionary and not text(String((l as Dictionary).get("key", ""))).is_empty():
			return voice_path(String((l as Dictionary).get("key", "")))
	return ""


static func amb_for(id: StringName) -> StringName:
	if Sfx.has_sound(id):
		return id
	return AMB_FALLBACK.get(id, &"")


# ----------------------------------------------------------------- просмотренное

static func seen(id: String) -> bool:
	return Save.slides_seen.has(id)


static func mark_seen(id: String) -> void:
	if id.is_empty() or Save.slides_seen.has(id):
		return
	Save.slides_seen[id] = 1
	Save.flush()


## Имена колод, которые игрок видел, в порядке данных.
static func seen_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in deck_ids():
		if Save.slides_seen.has(id):
			out.append(id)
	return out


# ----------------------------------------------------------------- какая колода к какому месту

static func chapter_deck(chapter_id: String, part: String) -> String:
	var id := "%s_%s" % [chapter_id, part]
	return id if has_deck(id) else ""


static func act_intro_deck(act: int) -> String:
	var id := "act%d_intro" % act
	return id if has_deck(id) else ""


## Итог акта: "all" все дошли, "some" часть, "none" никто, "trial" суд изгнал (только акт III).
static func act_outro_deck(act: int, outcome: String) -> String:
	var id := "act%d_out_%s" % [act, outcome]
	return id if has_deck(id) else ""


static func bio_deck(kind: String, who_id: String) -> String:
	var id := "%s_%s" % [kind, who_id]
	return id if has_deck(id) else ""


static func final_deck(ending: String) -> String:
	var id := ending if ending.begins_with("final_") else "final_" + ending
	return id if has_deck(id) else ""


# ----------------------------------------------------------------- Книга посёлка

## Группы галереи в Книге: ключ, виды колод.
const GALLERY: Array = [
	["story", ["prologue", "act_intro", "act_outro"]],
	["chapters", ["ch_intro", "ch_win", "ch_twist"]],
	["people", ["bio", "guest", "npc"]],
	["endings", ["finale"]],
]


## Колоды по группам галереи в порядке данных: [[ключ группы, [id, …]], …].
static func gallery() -> Array:
	var out: Array = []
	for g: Array in GALLERY:
		var ids: Array = []
		for id: String in deck_ids():
			if (g[1] as Array).has(String(deck(id).get("kind", ""))):
				ids.append(id)
		out.append([g[0], ids])
	return out


## Колода предыстории по ключу истории из Книги: "n3" (житель кампании, место в списке имён) или "g<гость в игре>".
static func bio_for_story_key(key: String) -> String:
	if key.begins_with("n"):
		var slot := int(key.substr(1))
		for who: String in VILLAGER_SLOT:
			if int(VILLAGER_SLOT[who]) == slot:
				return bio_deck("bio", who)
	elif key.begins_with("g"):
		var gid := String(GUEST_BY_GAME.get(key.substr(1), ""))
		if not gid.is_empty():
			return bio_deck("guest", gid)
	return ""
