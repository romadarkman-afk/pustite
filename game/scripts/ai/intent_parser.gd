class_name IntentParser
extends RefCounted
## Понимает свободный текст игрока. Ловит имя в любом падеже по основе
## («Марину», «Марине» → Марина) и намерение по ключевым словам языка (intent.* в scripts/loc).

enum Kind { NONE, ACCUSE, INVITE, DEFEND, ASK }

class Result:
	var kind: Kind = Kind.NONE
	var target: Villager = null
	var house: int = -1


static func _norm(s: String) -> String:
	return s.to_lower().replace("ё", "е")


static func stem(word: String) -> String:
	var w := _norm(word)
	return w.substr(0, maxi(3, w.length() - 1)) if w.length() > 3 else w


static func parse(text: String, m: Match) -> Result:
	var r := Result.new()
	var low := " " + _norm(text) + " "
	var words := low.split(" ", false)
	var spaced := L.has("intent.no_spaces") == false

	for v: Villager in m.alive_bots():
		var st := stem(v.name)
		if spaced:
			for w: String in words:
				if w.begins_with(st):
					r.target = v
					break
		elif low.contains(_norm(v.name)):
			r.target = v
		if r.target != null:
			break

	var stems := L.arr("intent.houses")
	for i in range(m.houses.size()):
		if (i < stems.size() and low.contains(stems[i])) or low.contains(_norm(m.houses[i])):
			r.house = i
			break

	if _has_any(low, L.arr("intent.invite")) and r.target != null:
		r.kind = Kind.INVITE
	elif _has_any(low, L.arr("intent.accuse")) and r.target != null:
		r.kind = Kind.ACCUSE
	elif _has_any(low, L.arr("intent.ask")) and r.target != null:
		r.kind = Kind.ASK
	elif _has_any(low, L.arr("intent.defend")):
		r.kind = Kind.DEFEND
	elif r.target != null and (low.contains("?") or low.contains("？")):
		r.kind = Kind.ASK
	return r


static func _has_any(s: String, keys: PackedStringArray) -> bool:
	for k: String in keys:
		if s.contains(_norm(k)):
			return true
	return false
