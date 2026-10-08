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
var win_streak: int = 0
var offer: String = ""                 ## что предложить после партии: ступень сложности или ""
var hints_seen: Dictionary = {}       ## id подсказки -> true: больше не показывать
var stats: Dictionary[String, int] = {
	"games": 0, "wins": 0, "as_upyr": 0, "upyr_wins": 0,
}


func _ready() -> void:
	load_all()


func load_all() -> void:
	var cf := ConfigFile.new()
	var has := cf.load(SETTINGS_PATH) == OK
	difficulty = String(cf.get_value("game", "difficulty", "easy")) if has else "easy"
	if not Difficulty.NAMES.has(difficulty):
		difficulty = "easy"
	win_streak = int(cf.get_value("game", "win_streak", 0)) if has else 0
	var loaded: GameConfig = null
	if difficulty == "custom" and ResourceLoader.exists(BALANCE_PATH):
		loaded = load(BALANCE_PATH) as GameConfig
	if loaded == null:
		if difficulty == "custom":
			difficulty = "easy"
		loaded = load(Difficulty.PRESETS[difficulty]) as GameConfig
	config = (loaded.duplicate() as GameConfig).sanitized()
	if has:
		haptics = bool(cf.get_value("ui", "haptics", true))
		for k: String in stats.keys():
			stats[k] = int(cf.get_value("stats", k, 0))
		hints_seen.clear()
		for h: String in String(cf.get_value("hints", "seen", "")).split(",", false):
			hints_seen[h] = true
	Juice.haptics_enabled = haptics


## Выбрать ступень лестницы: easy, normal или hard.
func set_difficulty(d: String) -> void:
	if not Difficulty.PRESETS.has(d):
		return
	difficulty = d
	config = Difficulty.preset(d)
	flush()


func set_haptics(on: bool) -> void:
	haptics = on
	Juice.haptics_enabled = on
	flush()


## Своя сложность: ползунки в настройках.
func set_settings(cfg: GameConfig, haptics_on: bool) -> void:
	difficulty = "custom"
	config = cfg.sanitized()
	haptics = haptics_on
	Juice.haptics_enabled = haptics_on
	flush()


func record_result(won: bool, was_upyr: bool) -> void:
	win_streak = win_streak + 1 if won else 0
	offer = ""
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


func flush() -> void:
	ResourceSaver.save(config, BALANCE_PATH)
	var cf := ConfigFile.new()
	cf.set_value("meta", "schema", SCHEMA)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("game", "win_streak", win_streak)
	cf.set_value("ui", "haptics", haptics)
	for k: String in stats.keys():
		cf.set_value("stats", k, stats[k])
	cf.set_value("hints", "seen", ",".join(PackedStringArray(hints_seen.keys())))
	cf.save(SETTINGS_PATH)


func hint_seen(id: String) -> bool:
	return hints_seen.has(id)


func mark_hint(id: String) -> void:
	if not hints_seen.has(id):
		hints_seen[id] = true
		flush()


func reset_hints() -> void:
	hints_seen.clear()
	flush()
