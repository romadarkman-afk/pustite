class_name IntentParser
extends RefCounted
## Понимает свободный текст игрока. Ловит имя в любом падеже по основе
## («Марину», «Марине» → Марина) и намерение по ключевым словам.

enum Kind { NONE, ACCUSE, INVITE, DEFEND, ASK }

class Result:
	var kind: Kind = Kind.NONE
	var target: Villager = null
	var house: int = -1

const ACCUSE_KEYS: PackedStringArray = ["упыр", "это он", "это она", "врёт", "врет", "подозр",
	"не верю", "выгон", "гнать", "гони", "убийц", "он ест", "она ест"]
const INVITE_KEYS: PackedStringArray = ["пойд", "пошли", "со мной", "вместе", "айда", "давай в",
	"идём", "идем", "ко мне"]
const DEFEND_KEYS: PackedStringArray = ["я не ", "я человек", "клянусь", "не я", "я чист", "я свой", "поверьте"]
const ASK_KEYS: PackedStringArray = ["где ", "куда", "ты где", "где ты", "где будешь"]
const HOUSE_STEMS: PackedStringArray = ["реки", "сара", "церк", "погр", "гара"]


static func stem(word: String) -> String:
	var w := word.to_lower().replace("ё", "е")
	return w.substr(0, maxi(3, w.length() - 1))


static func parse(text: String, m: Match) -> Result:
	var r := Result.new()
	var low := " " + text.to_lower().replace("ё", "е") + " "
	var words := low.split(" ", false)

	for v: Villager in m.alive_bots():
		var st := stem(v.name)
		for w: String in words:
			if w.begins_with(st):
				r.target = v
				break
		if r.target != null:
			break

	for i in range(m.houses.size()):
		if i < HOUSE_STEMS.size() and low.contains(HOUSE_STEMS[i]):
			r.house = i
			break

	if _has_any(low, INVITE_KEYS) and r.target != null:
		r.kind = Kind.INVITE
	elif _has_any(low, ACCUSE_KEYS) and r.target != null:
		r.kind = Kind.ACCUSE
	elif _has_any(low, ASK_KEYS) and r.target != null:
		r.kind = Kind.ASK
	elif _has_any(low, DEFEND_KEYS):
		r.kind = Kind.DEFEND
	elif r.target != null and low.contains("?"):
		r.kind = Kind.ASK
	return r


static func _has_any(s: String, keys: PackedStringArray) -> bool:
	for k: String in keys:
		if s.contains(k):
			return true
	return false
