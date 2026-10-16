class_name Campaign
extends RefCounted
## Кампания «Посёлок за лесом» (Task 58–59, 63). Глава — одна партия с заданными условиями:
## состав, событие, цель и две дополнительные цели (звёзды). Погибшие и изгнанные в пройденной
## главе в следующие главы не приходят: их место занимают новые лица.
## Жители кампании хранятся номерами в списке имён языка (L.names), поэтому смена языка их не путает.
## Тексты глав: ключи camp.<id>.* во всех языках.

const ACTS := [
	{"id": 1, "chapters": ["a1c1", "a1c2", "a1c3"]},
	{"id": 2, "chapters": []},       ## «Мельница у реки» — скоро
	{"id": 3, "chapters": []},       ## «Монастырь» — скоро
	{"id": 4, "chapters": []},       ## «Станция» — скоро
]

## Условия глав. cold_open — глава начинается сразу со стука в дверь (первые 3 минуты новичка).
const CHAPTERS := {
	"a1c1": {"act": 1, "players": 5, "monsters": 1, "shelters": 2, "capacity": 2, "nights": 3,
		"cold_open": true, "goal": "people_win", "extra": ["admit_night1", "inspect"]},
	"a1c2": {"act": 1, "players": 7, "monsters": 1, "shelters": 3, "capacity": 2, "nights": 3,
		"event": "fog", "goal": "exile_upyr_by_3", "extra": ["no_wrong_exile", "survive"]},
	"a1c3": {"act": 1, "players": 8, "monsters": 2, "shelters": 3, "capacity": 3, "nights": 4,
		"goal": "people_win", "extra": ["keep_couple", "no_wrong_exile"]},
}
const ORDER: PackedStringArray = ["a1c1", "a1c2", "a1c3"]
const ART := "res://assets/scenes/%s.jpg"     ## картинка главы, если есть: a1c1.jpg …


static func chapter(id: String) -> Dictionary:
	var d: Dictionary = CHAPTERS.get(id, {}).duplicate()
	if not d.is_empty():
		d["id"] = id
	return d


## Партия главы: сложность игрока как основа, состав и длина — из главы. Игрок в кампании всегда человек.
static func config(id: String) -> GameConfig:
	var ch := chapter(id)
	var c := (Save.config.duplicate() as GameConfig)
	if ch.is_empty():
		return c
	c.players = int(ch.players)
	c.monsters = int(ch.monsters)
	c.shelters = int(ch.shelters)
	c.capacity = int(ch.capacity)
	c.nights = int(ch.nights)
	c.player_always_human = true
	return c.sanitized()


## Кто живёт в посёлке в этой главе: номера имён. Первые трое — постоянные жители, остальные
## в порядке, который задаётся один раз на всю кампанию. Погибшие пропускаются.
static func cast(id: String) -> Array[int]:
	var n := int(chapter(id).get("players", 5)) - 1
	var names := L.names().size()
	var order: Array[int] = []
	for i in range(mini(3, names)):
		order.append(i)
	var rest: Array[int] = []
	for i in range(3, names):
		rest.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, Save.campaign_seed)
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := rest[i]
		rest[i] = rest[j]
		rest[j] = t
	order.append_array(rest)
	var out: Array[int] = []
	for idx: int in order:
		if Save.campaign_dead.has(idx) or _same_as_player(idx):
			continue
		out.append(idx)
		if out.size() >= n:
			break
	return out


static func _same_as_player(idx: int) -> bool:
	var names := L.names()
	return not Save.player_name.is_empty() and idx < names.size() and String(names[idx][0]).to_lower() == Save.player_name.to_lower()


## Открыта ли глава: первая — всегда, остальные — после прохождения предыдущей.
static func unlocked(id: String) -> bool:
	var i := ORDER.find(id)
	return i == 0 or (i > 0 and Save.campaign_stars.has(ORDER[i - 1]))


## Глава, с которой продолжать: первая непройденная, иначе последняя.
static func current() -> String:
	for id: String in ORDER:
		if not Save.campaign_stars.has(id):
			return id
	return ORDER[ORDER.size() - 1]


static func next_of(id: String) -> String:
	var i := ORDER.find(id)
	return ORDER[i + 1] if i >= 0 and i + 1 < ORDER.size() else ""


static func is_new() -> bool:
	return Save.campaign_stars.is_empty()


## Цели главы: [основная, доп. 1, доп. 2] — ключ и выполнена ли.
static func goals(m: Match, ch: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var keys: Array = [String(ch.get("goal", "people_win"))]
	keys.append_array(ch.get("extra", []))
	for k: String in keys:
		out.append({"key": k, "done": goal_done(m, k)})
	return out


static func goal_done(m: Match, key: String) -> bool:
	match key:
		"people_win":
			return m.winner == Match.Team.PEOPLE
		"survive":
			return m.player().alive
		"exile_upyr_by_3":
			for rec: Dictionary in m.vote_log:
				var ex: Villager = rec.get("exiled")
				if ex != null and ex.is_upyr and int(rec.day) <= 3:
					return true
			return false
		"no_wrong_exile":
			for rec: Dictionary in m.vote_log:
				var ex: Villager = rec.get("exiled")
				if ex != null and not ex.is_upyr:
					return false
			return m.winner != Match.Team.NONE
		"admit_night1":
			for rec: Dictionary in m.player_admits:
				if int(rec.day) == 1:
					return true
			return false
		"inspect":
			return not m.door_inspections.is_empty()
		"keep_couple":
			for v: Villager in m.villagers:
				var p := m.get_villager(v.partner_id)
				if p != null and v.alive and p.alive:
					return true
			return false
	return false


## Итог главы: пройдена ли (основная цель), сколько звёзд, кто погиб насовсем.
static func finish(m: Match, ch: Dictionary) -> Dictionary:
	var g := goals(m, ch)
	var passed := bool(g[0].done)
	var stars := 0
	for x: Dictionary in g:
		if bool(x.done):
			stars += 1
	var lost: Array[int] = []
	for v: Villager in m.villagers:
		if not v.is_player and not v.alive and v.story_id >= 0:
			lost.append(v.story_id)
	if passed:
		Save.record_chapter(String(ch.id), stars, lost)
	return {"passed": passed, "stars": stars, "goals": g, "lost": lost, "id": String(ch.id)}


## Концовка акта I: сколько из первых жителей деревни дожили до ухода к мельнице.
static func act_ending(act: int) -> String:
	if act != 1:
		return ""
	var first := 0
	var alive := 0
	for i in range(mini(3, L.names().size())):
		first += 1
		if not Save.campaign_dead.has(i):
			alive += 1
	if alive >= first:
		return L.t("camp.act1.end_all")
	return L.t("camp.act1.end_some") if alive > 0 else L.t("camp.act1.end_none")


static func stars_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(maxi(0, 3 - n))


## Имена погибших в кампании — для строки памяти.
static func fallen() -> Array:
	var out: Array = []
	var names := L.names()
	for idx: int in Save.campaign_dead:
		if idx < names.size():
			out.append({"nom": String(names[idx][0]), "f": bool(names[idx][1])})
	return out


static func art(id: String) -> Texture2D:
	var p := ART % id
	return load(p) as Texture2D if ResourceLoader.exists(p) else null
