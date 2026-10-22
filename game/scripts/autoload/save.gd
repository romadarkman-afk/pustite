extends Node
## Хранилище: баланс (ресурс GameConfig), настройки и статистика (ConfigFile).
## SCHEMA растёт, когда меняется формат сохранений, — для будущих миграций.

var SETTINGS_PATH := "user://settings.cfg"
var BALANCE_PATH := "user://balance.tres"
const DEFAULT_BALANCE := "res://config/balance_easy.tres"

const SCHEMA := 3           ## 3: нейтральные записи для пройденных глав без журнала
var BACKUP_PATH := "user://settings.v%d.bak"   ## копия файла перед переходом на новую версию формата
const MEMORY_PER_CHAPTER := 40
var save_writable := true

var config: GameConfig
var haptics: bool = true
var simplified_graphics: bool = false
var difficulty: String = "easy"
var text_size: int = 0                ## 0 — обычный текст, 1 — крупный, 2 — самый крупный
var lang: String = ""                  ## язык игры: код из L.LANGS. Пусто в файле — берём язык телефона
const DEFAULT_VOLUMES := {&"Master": 1.0, &"Music": 0.7, &"Sfx": 0.9, &"Ambience": 0.8}
var volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
var window_fullscreen: bool = false
var window_resolution := Vector2i(720, 1280)
var win_streak: int = 0
var recent: PackedInt32Array = []      ## последние 10 партий лестницы: 1 — победа, 0 — поражение (для подстройки ботов)
var howto_seen: bool = false
var offer: String = ""                 ## что предложить после партии: ступень сложности или ""
var daily_last: String = ""           ## дата последнего сыгранного испытания дня
var daily_won: bool = false            ## чем оно кончилось
var daily_streak: int = 0              ## сколько дней подряд игрок проходил испытание (играл, не обязательно победил)
var daily_wins: int = 0
var daily_best: int = 0                ## лучшая серия дней подряд
var lantern: String = "classic"        ## фонарь твоего жителя (Cosmetics.LANTERNS)
var hat: String = "own"                ## шапка (Cosmetics.HATS)
var brooch: String = "none"           ## значок на одежде игрока
var avatar_id: String = "hero"          ## выбранный полный образ игрока
var solo_last_map: String = ""           ## карта предыдущей одиночной партии
var player_name: String = ""            ## имя игрока, пусто — локализованное обращение по умолчанию
var anchor_bonds: Dictionary[String, int] = {} ## отношения с тремя постоянными жителями
var campaign_stars: Dictionary[String, int] = {}  ## кампания: пройденные главы -> звёзды (1–3)
var campaign_dead: Array[int] = []              ## кампания: номера имён погибших насовсем
var campaign_seed: int = 0
## Память кампании (TASK-002): что игрок сделал в пройденных главах и кто об этом знает.
## Жители — номерами имён (как campaign_dead), поэтому смена языка ничего не ломает.
## {"ch": id главы, "kind": WorldLog.RANK, "who": номер, "day": n, "knew": [номера]}
var campaign_memory: Array[Dictionary] = []
## Отношения жителей кампании (TASK-007): «a>b» -> −3..3, номера историй; «a>p» — к игроку. Пишется в конце главы.
var campaign_bonds: Dictionary = {}
var loaded_schema: int = 0                        ## версия формата прочитанного файла; 0 — файла не было
var campaign_dead_guests: PackedStringArray = []  ## кампания: гости, погибшие насовсем                      ## кампания: порядок новых лиц, задаётся один раз
var xp: int = 0                                   ## опыт за все партии (Progress)
var achievements: PackedStringArray = []          ## полученные достижения
var book: Dictionary[String, String] = {}         ## Книга посёлка: житель -> "встречали,погиб,упырь"
var storybook: Dictionary[String, int] = {}        ## услышанные главы историй жителей и гостей: ключ -> 0..2
var endings: PackedStringArray = []               ## найденные концовки (Progress.ENDINGS)
var hints_seen: Dictionary = {}       ## id подсказки -> true: больше не показывать
var stats: Dictionary[String, int] = {
	"games": 0, "wins": 0, "as_upyr": 0, "upyr_wins": 0,
}


func _ready() -> void:
	SETTINGS_PATH = Diag.test_path("settings.cfg")
	BALANCE_PATH = Diag.test_path("balance.tres")
	BACKUP_PATH = Diag.test_path("settings.v%d.bak")
	load_all()


func load_all() -> void:
	var cf := ConfigFile.new()
	var has := cf.load(SETTINGS_PATH) == OK
	loaded_schema = int(cf.get_value("meta", "schema", 1)) if has else 0
	save_writable = true
	if has and loaded_schema > SCHEMA:
		save_writable = false
		push_warning("Сохранение версии %d новее поддерживаемой версии %d. Запись отключена." % [loaded_schema, SCHEMA])
	elif has and loaded_schema < SCHEMA:
		var source_schema := loaded_schema
		if not _backup(source_schema):
			save_writable = false
			push_error("Не удалось создать резервную копию сохранения перед миграцией.")
		elif not _migrate_config(cf, source_schema):
			save_writable = false
			push_error("Не найдена цепочка миграции сохранения версии %d." % source_schema)
		else:
			var migration_error := cf.save(SETTINGS_PATH)
			if migration_error != OK:
				save_writable = false
				push_error("Не удалось записать мигрированное сохранение: %s" % error_string(migration_error))
			else:
				loaded_schema = SCHEMA
	lang = String(cf.get_value("ui", "lang", "")) if has else ""
	if DisplayServer.get_name() == "headless":
		lang = "ru"        # самотесты без экрана проверяют русские тексты; другой язык — флагом --lang=
	elif not L.LANGS.has(lang):
		lang = L.detect()  # первый запуск на телефоне — язык системы
	L.use(lang)
	text_size = clampi(int(cf.get_value("ui", "text_size", 0)), 0, 2) if has else 0
	if DisplayServer.get_name() == "headless":
		text_size = 0      # размер для самотеста — флагом --text=
	ThemeFactory.text_scale = ThemeFactory.TEXT_SCALES[text_size]
	difficulty = String(cf.get_value("game", "difficulty", "easy")) if has else "easy"
	if not Difficulty.NAMES.has(difficulty):
		difficulty = "easy"
	win_streak = int(cf.get_value("game", "win_streak", 0)) if has else 0
	recent.clear()
	for r: String in String(cf.get_value("game", "recent", "")).split(",", false):
		recent.append(1 if r == "1" else 0)
	howto_seen = bool(cf.get_value("game", "howto_seen", false)) if has else false
	var loaded: GameConfig = null
	if difficulty == "custom" and ResourceLoader.exists(BALANCE_PATH):
		loaded = load(BALANCE_PATH) as GameConfig
	if loaded == null:
		if difficulty == "custom":
			difficulty = "easy"
		loaded = load(Difficulty.PRESETS[difficulty]) as GameConfig
	config = (loaded.duplicate() as GameConfig).sanitized()
	daily_last = String(cf.get_value("daily", "last", "")) if has else ""
	daily_won = bool(cf.get_value("daily", "won", false)) if has else false
	daily_streak = int(cf.get_value("daily", "streak", 0)) if has else 0
	daily_wins = int(cf.get_value("daily", "wins", 0)) if has else 0
	daily_best = int(cf.get_value("daily", "best", 0)) if has else 0
	lantern = String(cf.get_value("look", "lantern", "classic")) if has else "classic"
	hat = String(cf.get_value("look", "hat", "own")) if has else "own"
	brooch = String(cf.get_value("look", "brooch", "none")) if has else "none"
	avatar_id = String(cf.get_value("look", "avatar", "hero")) if has else "hero"
	if not Cosmetics.avatar_exists(avatar_id):
		avatar_id = "hero"
	solo_last_map = String(cf.get_value("game", "solo_last_map", "")) if has else ""
	player_name = String(cf.get_value("profile", "name", "")).strip_edges().left(20) if has else ""
	campaign_stars.clear()
	campaign_dead.clear()
	campaign_dead_guests = String(cf.get_value("campaign", "dead_guests", "")).split(",", false) if has else PackedStringArray()
	campaign_seed = int(cf.get_value("campaign", "seed", 0)) if has else 0
	if has:
		for part: String in String(cf.get_value("campaign", "stars", "")).split(",", false):
			var kv := part.split(":")
			if kv.size() == 2:
				campaign_stars[kv[0]] = clampi(int(kv[1]), 1, 3)
		for part: String in String(cf.get_value("campaign", "dead", "")).split(",", false):
			campaign_dead.append(int(part))
	campaign_memory.clear()
	campaign_bonds.clear()
	if has:
		var raw_bonds: Variant = cf.get_value("campaign", "bonds", {})
		if raw_bonds is Dictionary:
			for k: Variant in raw_bonds:
				if String(k).contains(">"):
					campaign_bonds[String(k)] = clampi(int(raw_bonds[k]), -3, 3)
		var raw_mem: Variant = cf.get_value("campaign", "memory", [])
		if raw_mem is Array:
			for rec: Variant in raw_mem:
				var clean := _memory_record(rec)
				if not clean.is_empty():
					campaign_memory.append(clean)
	xp = int(cf.get_value("progress", "xp", 0)) if has else 0
	achievements = String(cf.get_value("progress", "achievements", "")).split(",", false) if has else PackedStringArray()
	endings = String(cf.get_value("progress", "endings", "")).split(",", false) if has else PackedStringArray()
	book.clear()
	if has:
		for part: String in String(cf.get_value("progress", "book", "")).split(";", false):
			var kv := part.split("=")
			if kv.size() == 2:
				book[kv[0]] = kv[1]
	storybook.clear()
	if has:
		var saved_stories: Variant = cf.get_value("progress", "storybook", {})
		if saved_stories is Dictionary:
			for key: Variant in saved_stories:
				if String(key).begins_with("n") or String(key).begins_with("g"):
					storybook[String(key)] = clampi(int(saved_stories[key]), 0, 2)
	anchor_bonds.clear()
	for i in range(3):
		anchor_bonds[str(i)] = clampi(int(cf.get_value("relationships", str(i), 0)), -3, 3) if has else 0
	if DisplayServer.get_name() == "headless":
		lantern = "classic"   # самотесты видят жителя без косметики; --cosmetics надевает сам
		hat = "own"
		brooch = "none"
		avatar_id = "hero"
	if has:
		haptics = bool(cf.get_value("ui", "haptics", true))
		simplified_graphics = bool(cf.get_value("ui", "simplified_graphics", false))
		window_fullscreen = bool(cf.get_value("display", "fullscreen", false))
		var res: Variant = cf.get_value("display", "resolution", Vector2i(720, 1280))
		if res is Vector2i:
			window_resolution = res
		for k: String in stats.keys():
			stats[k] = int(cf.get_value("stats", k, 0))
		hints_seen.clear()
		for h: String in String(cf.get_value("hints", "seen", "")).split(",", false):
			hints_seen[h] = true
	Juice.haptics_enabled = haptics
	for b: StringName in volumes.keys():
		var def_v: float = DEFAULT_VOLUMES[b]
		volumes[b] = clampf(float(cf.get_value("sound", String(b), def_v)) if has else def_v, 0.0, 1.0)
	apply_volumes()
	apply_display()


func set_display(fullscreen: bool, resolution: Vector2i) -> void:
	window_fullscreen = fullscreen
	window_resolution = resolution
	apply_display()
	flush()


func apply_display() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if window_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not window_fullscreen:
		DisplayServer.window_set_size(window_resolution)
		DisplayServer.window_set_position((DisplayServer.screen_get_size() - window_resolution) / 2)


func apply_volumes() -> void:
	for b: StringName in volumes.keys():
		Sfx.set_volume(b, volumes[b])


## Громкость канала: Music, Sfx или Ambience, 0..1. Слышно сразу, сохраняется в файл.
func set_volume(bus: StringName, v: float, write: bool = true) -> void:
	volumes[bus] = clampf(v, 0.0, 1.0)
	Sfx.set_volume(bus, volumes[bus])
	if write:
		flush()


## Выбрать ступень лестницы: easy, normal или hard.
func set_difficulty(d: String) -> void:
	if not Difficulty.PRESETS.has(d):
		return
	difficulty = d
	config = Difficulty.preset(d)
	flush()


## Сменить язык. Действует сразу: экраны строятся заново, посёлок берёт имена и внешности страны.
func set_lang(c: String) -> void:
	if not L.LANGS.has(c):
		return
	lang = c
	L.use(c)
	flush()


## Размер текста: тема строится заново, экраны подхватывают сразу.
func set_text_size(i: int) -> void:
	text_size = clampi(i, 0, 2)
	ThemeFactory.text_scale = ThemeFactory.TEXT_SCALES[text_size]
	flush()


## Надеть фонарь или шапку. Закрытую вещь надеть нельзя.
func wear(kind: String, id: String) -> bool:
	var it := Cosmetics.item(kind, id)
	if it.id != id or not Cosmetics.is_open(it):
		return false
	if kind == "lantern":
		lantern = id
	elif kind == "hat":
		if avatar_id != "hero":
			return false
		hat = id
	elif kind == "avatar":
		if not Cosmetics.avatar_exists(id):
			return false
		avatar_id = id
		if avatar_id != "hero":
			hat = "own"
	elif kind == "brooch":
		brooch = id
	else:
		return false
	flush()
	return true


func set_haptics(on: bool) -> void:
	haptics = on
	Juice.haptics_enabled = on
	flush()


func set_simplified_graphics(on: bool) -> void:
	simplified_graphics = on
	flush()


func set_player_name(value: String) -> bool:
	var clean := value.strip_edges().left(20)
	if clean.is_empty():
		return false
	for i in range(clean.length()):
		if clean.unicode_at(i) < 32:
			return false
	player_name = clean
	flush()
	return true


func player_display_name() -> String:
	return player_name if not player_name.is_empty() else L.t("you_name")


func anchor_bond(anchor_id: int) -> int:
	return int(anchor_bonds.get(str(anchor_id), 0)) if anchor_id >= 0 and anchor_id < 3 else 0


func change_anchor_bond(anchor_id: int, amount: int) -> int:
	if anchor_id < 0 or anchor_id >= 3 or amount == 0:
		return anchor_bond(anchor_id)
	var key := str(anchor_id)
	anchor_bonds[key] = clampi(int(anchor_bonds.get(key, 0)) + amount, -3, 3)
	return int(anchor_bonds[key])


func total_anchor_bond() -> int:
	var total := 0
	for i in range(3):
		total += maxi(anchor_bond(i), 0)
	return total


## Своя сложность: ползунки в настройках.
func set_settings(cfg: GameConfig, haptics_on: bool) -> void:
	difficulty = "custom"
	config = cfg.sanitized()
	haptics = haptics_on
	Juice.haptics_enabled = haptics_on
	flush()


## ladder = false — партия вне лестницы сложности (испытание дня): серия побед и предложение ступени не трогаются.
func record_result(won: bool, was_upyr: bool, ladder: bool = true) -> void:
	offer = ""
	if not ladder:
		stats["games"] += 1
		if won:
			stats["wins"] += 1
		if was_upyr:
			stats["as_upyr"] += 1
			if won:
				stats["upyr_wins"] += 1
		flush()
		return
	win_streak = win_streak + 1 if won else 0
	recent.append(1 if won else 0)
	if recent.size() > 10:
		recent = recent.slice(recent.size() - 10)
	var i := Difficulty.LADDER.find(difficulty)
	if i >= 0:
		if not won and i > 0:
			offer = Difficulty.LADDER[i - 1]          # проиграл: сделать легче
		elif won and win_streak >= 2 and i < Difficulty.LADDER.size() - 1:
			offer = Difficulty.LADDER[i + 1]          # две победы подряд: попробовать сложнее
	stats["games"] += 1
	if won:
		stats["wins"] += 1
	if was_upyr:
		stats["as_upyr"] += 1
		if won:
			stats["upyr_wins"] += 1
	flush()


## Подстройка ботов под игрока: три поражения подряд — боты поддаются (до −1 к пятому),
## побед 70% и больше из последних пяти-десяти — собираются (до +1). Иначе 0.
func tune() -> float:
	var losses := 0
	for i in range(recent.size() - 1, -1, -1):
		if recent[i] != 0:
			break
		losses += 1
	if losses >= 3:
		return -minf(1.0, 0.25 * (losses - 1))
	if recent.size() >= 5:
		var w := 0
		for r: int in recent:
			w += r
		var rate := float(w) / recent.size()
		if rate >= 0.7:
			return minf(1.0, (rate - 0.6) * 2.5)
	return 0.0


## Испытание дня сыграно. Одна попытка в день: повтор той же даты не записывается.
## Серия растёт, если вчерашнее тоже сыграно, иначе начинается заново.
func record_daily(date: String, won: bool) -> bool:
	if daily_last == date:
		return false
	var next_day := daily_last != "" and Challenge.day_index(date) - Challenge.day_index(daily_last) == 1
	daily_streak = daily_streak + 1 if next_day else 1
	daily_last = date
	daily_won = won
	daily_best = maxi(daily_best, daily_streak)
	if won:
		daily_wins += 1
	flush()
	return true


## Серия на сегодня: пропустил вчера — серия прервалась, даже если ещё не сыграл сегодня.
func daily_streak_on(date: String) -> int:
	if daily_last == "":
		return 0
	var gap := Challenge.day_index(date) - Challenge.day_index(daily_last)
	return daily_streak if gap <= 1 else 0


func flush() -> void:
	if not save_writable:
		return
	ResourceSaver.save(config, BALANCE_PATH)
	var cf := ConfigFile.new()
	cf.set_value("meta", "schema", SCHEMA)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("game", "win_streak", win_streak)
	cf.set_value("game", "recent", ",".join(PackedStringArray(Array(recent).map(func(x: int) -> String: return str(x)))))
	cf.set_value("game", "howto_seen", howto_seen)
	cf.set_value("game", "solo_last_map", solo_last_map)
	cf.set_value("ui", "haptics", haptics)
	cf.set_value("ui", "simplified_graphics", simplified_graphics)
	cf.set_value("ui", "lang", lang)
	cf.set_value("ui", "text_size", text_size)
	for b: StringName in volumes.keys():
		cf.set_value("sound", String(b), volumes[b])
	cf.set_value("display", "fullscreen", window_fullscreen)
	cf.set_value("display", "resolution", window_resolution)
	for k: String in stats.keys():
		cf.set_value("stats", k, stats[k])
	cf.set_value("daily", "last", daily_last)
	cf.set_value("daily", "won", daily_won)
	cf.set_value("daily", "streak", daily_streak)
	cf.set_value("daily", "wins", daily_wins)
	cf.set_value("daily", "best", daily_best)
	cf.set_value("look", "lantern", lantern)
	cf.set_value("look", "hat", hat)
	cf.set_value("look", "brooch", brooch)
	cf.set_value("look", "avatar", avatar_id)
	cf.set_value("profile", "name", player_name)
	for i in range(3):
		cf.set_value("relationships", str(i), anchor_bond(i))
	cf.set_value("hints", "seen", ",".join(PackedStringArray(hints_seen.keys())))
	var st := PackedStringArray()
	for k: String in campaign_stars:
		st.append("%s:%d" % [k, campaign_stars[k]])
	cf.set_value("campaign", "stars", ",".join(st))
	cf.set_value("campaign", "dead", ",".join(PackedStringArray(campaign_dead.map(func(x: int) -> String: return str(x)))))
	cf.set_value("campaign", "seed", campaign_seed)
	cf.set_value("campaign", "dead_guests", ",".join(campaign_dead_guests))
	cf.set_value("campaign", "memory", campaign_memory)
	cf.set_value("campaign", "bonds", campaign_bonds)
	cf.set_value("progress", "xp", xp)
	cf.set_value("progress", "achievements", ",".join(achievements))
	cf.set_value("progress", "endings", ",".join(endings))
	var bk := PackedStringArray()
	for k: String in book:
		bk.append("%s=%s" % [k, book[k]])
	cf.set_value("progress", "book", ";".join(bk))
	cf.set_value("progress", "storybook", storybook)
	cf.save(SETTINGS_PATH)


## Глава пройдена: звёзды — лучший результат, погибшие больше не придут.
func record_chapter(id: String, stars: int, lost: Array[int], lost_guests: PackedStringArray = PackedStringArray(),
		memory: Array[Dictionary] = [], bonds: Dictionary = {}) -> void:
	if not bonds.is_empty():
		campaign_bonds = bonds.duplicate()
	campaign_stars[id] = maxi(int(campaign_stars.get(id, 0)), clampi(stars, 1, 3))
	# память главы: прошёл заново — помнится последний раз
	for i in range(campaign_memory.size() - 1, -1, -1):
		if String(campaign_memory[i].get("ch", "")) == id:
			campaign_memory.remove_at(i)
	for rec: Dictionary in memory.slice(0, MEMORY_PER_CHAPTER):
		var r2 := rec.duplicate()
		r2["ch"] = id
		var clean := _memory_record(r2)
		if not clean.is_empty():
			campaign_memory.append(clean)
	for idx: int in lost:
		if not campaign_dead.has(idx):
			campaign_dead.append(idx)
	for g: String in lost_guests:
		if not campaign_dead_guests.has(g):
			campaign_dead_guests.append(g)
	flush()


## Итог партии в Книгу посёлка: опыт, судьбы жителей [ключ, погиб, упырь], концовки, достижения.
func record_progress(gained: int, fates: Array, ends: PackedStringArray, new_ach: PackedStringArray) -> void:
	xp += maxi(0, gained)
	for f: Array in fates:
		var e := Progress.book_entry(String(f[0]))
		e[0] += 1
		e[1] += 1 if bool(f[1]) else 0
		e[2] += 1 if bool(f[2]) else 0
		var key := String(f[0])
		book[key] = "%d,%d,%d" % [e[0], e[1], e[2]]
		if f.size() > 3 and not String(f[3]).is_empty():
			book["name:%s:%s" % [key, L.code]] = String(f[3])
	for e2: String in ends:
		if not endings.has(e2):
			endings.append(e2)
	for a: String in new_ach:
		if not achievements.has(a):
			achievements.append(a)
	flush()


## История открывается в Книге, когда игрок впервые слышит её страницу.
## write=false нужен для пачки страниц вступления, чтобы сохранить их одним вызовом.
func remember_story(key: String, step: int, write: bool = true) -> bool:
	if key.is_empty() or step < 0:
		return false
	var value := clampi(step, 0, 2)
	if storybook.get(key, -1) >= value:
		return false
	storybook[key] = value
	if write:
		flush()
	return true


func campaign_begin() -> void:
	if campaign_seed == 0:
		campaign_seed = randi_range(1, 1 << 30)
		flush()


## Начать кампанию заново: звёзды, погибшие и порядок новых лиц стираются.
func campaign_reset() -> void:
	campaign_stars.clear()
	campaign_dead.clear()
	campaign_dead_guests.clear()
	campaign_memory.clear()
	campaign_bonds.clear()
	campaign_seed = 0
	flush()


## Запись памяти из файла или из главы: только известные поля и типы. Битая запись — пусто.
static func _memory_record(rec: Variant) -> Dictionary:
	if not rec is Dictionary:
		return {}
	var d := rec as Dictionary
	var kind := String(d.get("kind", ""))
	var ch := String(d.get("ch", ""))
	if kind.is_empty() or ch.is_empty() or not d.has("who"):   # who = -1 — запись без жителя (находка, выбор)
		return {}
	var knew: Array = []
	var raw_knew: Variant = d.get("knew", [])
	if raw_knew is Array or raw_knew is PackedInt32Array:
		for k: Variant in raw_knew:
			knew.append(int(k))
	return {"ch": ch, "kind": kind, "who": int(d.who), "day": int(d.get("day", 0)), "knew": knew}


func _migrate_config(cf: ConfigFile, from_schema: int) -> bool:
	var version := from_schema
	while version < SCHEMA:
		match version:
			1:
				_migrate_1_to_2(cf)
			2:
				_migrate_2_to_3(cf)
			_:
				return false
		version += 1
		cf.set_value("meta", "schema", version)
	return true


## Память и отношения появились вместе с форматом кампании версии 2.
static func _migrate_1_to_2(cf: ConfigFile) -> void:
	var memory: Variant = cf.get_value("campaign", "memory", [])
	if not memory is Array:
		cf.set_value("campaign", "memory", [])
	var bonds: Variant = cf.get_value("campaign", "bonds", {})
	if not bonds is Dictionary:
		cf.set_value("campaign", "bonds", {})


## Старый сейв мог отметить главы пройденными, не записав журнал событий.
static func _migrate_2_to_3(cf: ConfigFile) -> void:
	var memory: Array = []
	var seen: Dictionary = {}
	var raw_memory: Variant = cf.get_value("campaign", "memory", [])
	if raw_memory is Array:
		for rec: Variant in raw_memory:
			var clean := _memory_record(rec)
			if not clean.is_empty():
				memory.append(clean)
				seen[String(clean.ch)] = true
	var raw_stars := String(cf.get_value("campaign", "stars", ""))
	for item: String in raw_stars.split(",", false):
		var pair := item.split(":", false)
		if pair.size() != 2:
			continue
		var chapter_id := pair[0].strip_edges()
		if chapter_id.is_empty() or seen.has(chapter_id) or not Campaign.ORDER.has(chapter_id):
			continue
		memory.append({"ch": chapter_id, "kind": "neutral", "who": -1, "day": 0, "knew": []})
		seen[chapter_id] = true
	cf.set_value("campaign", "memory", memory)


## Что помнит кампания о жителе с номером idx: записи в порядке глав.
func memory_of(idx: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rec: Dictionary in campaign_memory:
		if int(rec.who) == idx:
			out.append(rec)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Campaign.ORDER.find(String(a.ch)) < Campaign.ORDER.find(String(b.ch)))
	return out


## Перед миграцией сохраняется точный снимок исходного файла.
func _backup(from_schema: int) -> bool:
	var path := BACKUP_PATH % from_schema
	if not FileAccess.file_exists(SETTINGS_PATH):
		return false
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var source := FileAccess.get_file_as_bytes(SETTINGS_PATH)
	if source.is_empty():
		return false
	var backup := FileAccess.open(path, FileAccess.WRITE)
	if backup == null:
		return false
	backup.store_buffer(source)
	backup.close()
	return FileAccess.get_file_as_bytes(path) == source


func mark_howto() -> void:
	if not howto_seen:
		howto_seen = true
		flush()


func hint_seen(id: String) -> bool:
	return hints_seen.has(id)


func mark_hint(id: String) -> void:
	if not hints_seen.has(id):
		hints_seen[id] = true
		flush()


func reset_hints() -> void:
	hints_seen.clear()
	flush()
