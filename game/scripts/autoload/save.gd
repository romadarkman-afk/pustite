extends Node
## Хранилище: баланс (ресурс GameConfig), настройки и статистика (ConfigFile).
## SCHEMA растёт, когда меняется формат сохранений, — для будущих миграций.

const SETTINGS_PATH := "user://settings.cfg"
const BALANCE_PATH := "user://balance.tres"
const DEFAULT_BALANCE := "res://config/balance_7.tres"
const SCHEMA := 1

var config: GameConfig
var haptics: bool = true
var stats: Dictionary[String, int] = {
	"games": 0, "wins": 0, "as_upyr": 0, "upyr_wins": 0,
}


func _ready() -> void:
	load_all()


func load_all() -> void:
	var loaded: GameConfig = null
	if ResourceLoader.exists(BALANCE_PATH):
		loaded = load(BALANCE_PATH) as GameConfig
	if loaded == null:
		loaded = load(DEFAULT_BALANCE) as GameConfig
	config = (loaded.duplicate() as GameConfig).sanitized()

	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		haptics = bool(cf.get_value("ui", "haptics", true))
		for k: String in stats.keys():
			stats[k] = int(cf.get_value("stats", k, 0))
	Juice.haptics_enabled = haptics


func set_settings(cfg: GameConfig, haptics_on: bool) -> void:
	config = cfg.sanitized()
	haptics = haptics_on
	Juice.haptics_enabled = haptics_on
	flush()


func record_result(won: bool, was_upyr: bool) -> void:
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
	cf.set_value("ui", "haptics", haptics)
	for k: String in stats.keys():
		cf.set_value("stats", k, stats[k])
	cf.save(SETTINGS_PATH)
