class_name Challenge
extends RefCounted
## Испытание дня: раз в сутки партия по особому правилу. Правило и посёлок (зерно случайности)
## зависят только от даты, поэтому в этот день у всех игроков одно и то же испытание.
## Основа — обычная сложность, правило меняет её в одну сторону.

const RULES: PackedStringArray = ["fog", "no_elder", "three_upyr", "moon", "rain"]
const EPOCH := "2026-01-01"       ## отсчёт номеров дней: правила идут по кругу


## Сегодняшняя дата по часам телефона: «2026-10-11».
static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## Номер дня от EPOCH — для круга правил и серии дней подряд.
static func day_index(date: String) -> int:
	var t := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	var e := Time.get_unix_time_from_datetime_string(EPOCH + "T12:00:00")
	return int(floor((t - e) / 86400.0))


static func rule_for(date: String) -> String:
	return RULES[posmod(day_index(date), RULES.size())]


## Зерно партии: одно на дату, не ноль.
static func seed_for(date: String) -> int:
	# дата в начале строки и перемешивание битов: у хэша соседних дат различались только младшие биты,
	# и «| 1» склеивал два дня в один посёлок
	var h := hash(date + "|pustite-daily")
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0xffffffff
	h = h ^ (h >> 16)
	return (h & 0x7fffffff) | 1


## Баланс испытания: обычная сложность и правка под правило.
static func config(rule: String) -> GameConfig:
	var c := Difficulty.preset("normal")
	c.player_always_human = false
	match rule:
		"three_upyr":
			c.players = 10
			c.monsters = 3
			c.shelters = 3
		"no_elder":
			c.players = 8
	return c.sanitized()


## Событие, которое идёт каждую ночь, начиная с первой; NONE — обычные ночи.
static func night_event(rule: String) -> Match.Event:
	match rule:
		"fog": return Match.Event.FOG
		"moon": return Match.Event.MOON
		"rain": return Match.Event.RAIN
	return Match.Event.NONE


static func title(rule: String) -> String:
	return L.t("daily.%s" % rule)


static func text(rule: String) -> String:
	return L.t("daily.%s_text" % rule)
