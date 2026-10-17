class_name Clues
extends RefCounted
## Тетрадь улик (TASK-017). Записи с источником и днём: кто где обещал ночевать, кого игрок видел ночью
## у своей двери, что нашли у реки. Две записи можно сравнить: если они противоречат друг другу,
## игрок спрашивает при всех, и по ответу видно больше, чем по самим уликам.
## Противоречия не выдумываются: они либо следуют из фактов партии (сказал одно, был в другом месте),
## либо заложены в главу данными (TASK-018: «Пустая лодка»). В главе показывается не больше MAX записей.

const MAX := 8

## {"id", "day", "kind": claim | seen | find | say, "who": id, "house": int, "night": int,
##  "text", "source": id или -1, "mystery": "" или boat, "pair": id записи, с которой противоречит}
var entries: Array[Dictionary] = []
var asked: Dictionary = {}          ## "id1|id2" -> true: это противоречие уже спрашивали
var m: Match
var _n := 0


func attach(match_ref: Match) -> void:
	m = match_ref
	entries.clear()
	asked.clear()
	_n = 0


func add(kind: String, who: int, text: String, extra: Dictionary = {}) -> Dictionary:
	_n += 1
	var e := {"id": "c%d" % _n, "day": m.day, "kind": kind, "who": who, "house": -1, "night": m.day,
		"text": text, "source": -1, "mystery": "", "pair": ""}
	e.merge(extra, true)
	entries.append(e)
	return e


func get_entry(id: String) -> Dictionary:
	for e: Dictionary in entries:
		if e.id == id:
			return e
	return {}


## Видимые записи: находки загадки всегда, остальные — последние, всего не больше MAX.
func shown() -> Array[Dictionary]:
	var pinned := 0
	for e: Dictionary in entries:
		if _pinned(e):
			pinned += 1
	var room := maxi(0, MAX - pinned)
	var out: Array[Dictionary] = []
	var rest := 0
	for i in range(entries.size() - 1, -1, -1):
		var e := entries[i]
		if _pinned(e):
			out.push_front(e)
		elif rest < room:
			rest += 1
			out.push_front(e)
	return out


## Записи загадки и заложенного противоречия не вытесняются новыми.
func _pinned(e: Dictionary) -> bool:
	if not String(e.mystery).is_empty() or not String(e.pair).is_empty():
		return true
	for o: Dictionary in entries:
		if String(o.pair) == String(e.id):
			return true
	return false


## Вечер: кто куда собрался ночевать (сказано вслух днём).
func record_claims() -> void:
	for v: Villager in m.alive_bots():
		if v.announced_house >= 0:
			add("claim", v.id, L.t("clue.claim", {"who": v, "house": m.house_name(v.announced_house)}),
				{"house": v.announced_house})


## Ночь: кто стучал в дверь, у которой был игрок. Видел сам.
func record_door(seat: Match.Seat) -> void:
	if seat == null:
		return
	for v: Villager in seat.queue:
		if v.is_player:
			continue
		add("seen", v.id, L.t("clue.seen", {"who": v, "house": m.house_name(seat.house)}),
			{"house": seat.house, "source": 0})


## Противоречат ли две записи. Пусто — нет; иначе ключ пары.
func contradiction(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or a.id == b.id or int(a.who) != int(b.who) or int(a.who) < 0:
		return false
	if String(a.pair) == String(b.id) or String(b.pair) == String(a.id):
		return true
	var kinds := [String(a.kind), String(b.kind)]
	if kinds.has("claim") and kinds.has("seen") and int(a.night) == int(b.night):
		return int(a.house) != int(b.house)
	return false


## Все противоречия в тетради: [[запись, запись], …].
func contradictions() -> Array:
	var out: Array = []
	for i in range(entries.size()):
		for j in range(i + 1, entries.size()):
			if contradiction(entries[i], entries[j]):
				out.append([entries[i], entries[j]])
	return out


static func pair_key(a: Dictionary, b: Dictionary) -> String:
	var ids := [String(a.id), String(b.id)]
	ids.sort()
	return "|".join(ids)


## Заложенное противоречие главы (TASK-018): житель утром говорит, что всю ночь был дома,
## а у реки находят его следы. Житель выбирается без случайности партии. Человек потом объяснит,
## зачем ходил к реке; упырь чаще отпирается.
func plant(chapter_id: String) -> void:
	var bots := m.alive_bots()
	if bots.is_empty():
		return
	var pr := RandomNumberGenerator.new()
	pr.seed = hash("plant:%s:%d" % [chapter_id, m.rng.seed])
	var who: Villager = bots[pr.randi_range(0, bots.size() - 1)]
	var say := add("say", who.id, L.t("clue.say_home", {"who": who}), {"night": m.day - 1})
	add("find", who.id, L.t("clue.find_tracks", {"who": who}), {"night": m.day - 1, "pair": say.id, "mystery": "boat"})
