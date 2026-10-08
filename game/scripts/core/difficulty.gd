class_name Difficulty
extends RefCounted
## Лестница сложности. Новичок начинает с лёгкой: обычный человек жмёт «Играть», не настраивая.

const LADDER := ["easy", "normal", "hard"]
const PRESETS := {
	"easy": "res://config/balance_easy.tres",
	"normal": "res://config/balance_7.tres",
	"hard": "res://config/balance_hard.tres",
}
const NAMES := {"easy": "Лёгкая", "normal": "Обычная", "hard": "Сложная", "custom": "Своя"}


static func preset(d: String) -> GameConfig:
	return ((load(PRESETS[d]) as GameConfig).duplicate() as GameConfig).sanitized()


## Одна строка о том, что ждёт в партии: «5 жителей, 1 упырь. Ты всегда человек.»
static func describe(d: String, c: GameConfig) -> String:
	var s := "%d %s, %d %s." % [c.players, Ru.plural(c.players, "житель", "жителя", "жителей"),
		c.monsters, Ru.plural(c.monsters, "упырь", "упыря", "упырей")]
	if c.player_always_human:
		s += " Ты всегда человек."
	match d:
		"easy":
			s += " Дольше день."
		"hard":
			s += " Короче день, опаснее улица."
	return s
