extends Node
## Хранилище: баланс (ресурс GameConfig), настройки и статистика (ConfigFile).
## SCHEMA растёт, когда меняется формат сохранений, — для будущих миграций.

const SETTINGS_PATH := "user://settings.cfg"
const BALANCE_PATH := "user://balance.tres"
const DEFAULT_BALANCE := "res://config/balance_easy.tres"

const SCHEMA := 1

var config: GameConfig
var haptics: bool = true
var difficulty: String = "easy"
var text_size: int = 0                ## 0 — обычный текст, 1 — крупный, 2 — самый крупный
var lang: String = ""                  ## язык игры: код из L.LANGS. Пусто в файле — берём язык телефона
const DEFAULT_VOLUMES := {&"Music": 0.7, &"Sfx": 0.9, &"Ambience": 0.8}
var volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
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
var player_name: String = ""            ## имя игрока, пусто — локализованное обращение по умолчанию
var hints_seen: Dictionary = {}       ## id подсказки -> true: больше не показывать
var stats: Dictionary[String, int] = {
	"games": 0, "wins": 0, "as_upyr": 0, "upyr_wins": 0,
}


func _ready() -> void:
	load_all()


func load_all() -> void:
	var cf := ConfigFile.new()
	var has := cf.load(SETTINGS_PATH) == OK
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
	player_name = String(cf.get_value("profile", "name", "")).strip_edges().left(20) if has else ""
	if DisplayServer.get_name() == "headless":
		lantern = "classic"   # самотесты видят жителя без косметики; --cosmetics надевает сам
		hat = "own"
	if has:
		haptics = bool(cf.get_value("ui", "haptics", true))
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
	else:
		hat = id
	flush()
	return true


func set_haptics(on: bool) -> void:
	haptics = on
	Juice.haptics_enabled = on
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
	ResourceSaver.save(config, BALANCE_PATH)
	var cf := ConfigFile.new()
	cf.set_value("meta", "schema", SCHEMA)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("game", "win_streak", win_streak)
	cf.set_value("game", "recent", ",".join(PackedStringArray(Array(recent).map(func(x: int) -> String: return str(x)))))
	cf.set_value("game", "howto_seen", howto_seen)
	cf.set_value("ui", "haptics", haptics)
	cf.set_value("ui", "lang", lang)
	cf.set_value("ui", "text_size", text_size)
	for b: StringName in volumes.keys():
		cf.set_value("sound", String(b), volumes[b])
	for k: String in stats.keys():
		cf.set_value("stats", k, stats[k])
	cf.set_value("daily", "last", daily_last)
	cf.set_value("daily", "won", daily_won)
	cf.set_value("daily", "streak", daily_streak)
	cf.set_value("daily", "wins", daily_wins)
	cf.set_value("daily", "best", daily_best)
	cf.set_value("look", "lantern", lantern)
	cf.set_value("look", "hat", hat)
	cf.set_value("profile", "name", player_name)
	cf.set_value("hints", "seen", ",".join(PackedStringArray(hints_seen.keys())))
	cf.save(SETTINGS_PATH)


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
