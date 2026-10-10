class_name Difficulty
extends RefCounted
## Лестница сложности. Новичок начинает с лёгкой: обычный человек жмёт «Играть», не настраивая.

const LADDER := ["easy", "normal", "hard"]
const PRESETS := {
	"easy": "res://config/balance_easy.tres",
	"normal": "res://config/balance_7.tres",
	"hard": "res://config/balance_hard.tres",
}
const NAMES := {"easy": "diff.easy", "normal": "diff.normal", "hard": "diff.hard", "custom": "diff.custom"}


## Название ступени: «Лёгкая».
static func title(d: String) -> String:
	return L.t(String(NAMES.get(d, "diff.easy")))


static func preset(d: String) -> GameConfig:
	return ((load(PRESETS[d]) as GameConfig).duplicate() as GameConfig).sanitized()


## Одна строка о том, что ждёт в партии: «5 жителей, 1 упырь. Ты всегда человек.»
static func describe(d: String, c: GameConfig) -> String:
	var s := L.t("diff.cast", {"p": c.players, "u": c.monsters})
	if c.player_always_human:
		s += L.t("diff.human")
	match d:
		"easy":
			s += L.t("diff.easy_note")
		"hard":
			s += L.t("diff.hard_note")
	return s
