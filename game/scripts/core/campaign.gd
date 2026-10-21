class_name Campaign
extends RefCounted
## Кампания «Посёлок за лесом» (Task 58–59, 63). Глава — одна партия с заданными условиями:
## состав, событие, цель и две дополнительные цели (звёзды). Погибшие и изгнанные в пройденной
## главе в следующие главы не приходят: их место занимают новые лица.
## Жители кампании хранятся номерами в списке имён языка (L.names), поэтому смена языка их не путает.
## Тексты глав: ключи camp.<id>.* во всех языках.

const ACTS := [
	{"id": 1, "chapters": ["a1c1", "a1c2", "a1c3"]},
	{"id": 2, "chapters": ["a2c1", "a2c2", "a2c3"]},   ## «Мельница у реки»: своя карта (config/village_mill.tres)
	{"id": 3, "chapters": ["a3c1", "a3c2", "a3c3"]},   ## «Монастырь»: config/village_monastery.tres
	{"id": 4, "chapters": ["a4c1", "a4c2", "a4c3"]},   ## «Станция», финал сезона: config/village_station.tres
]

## Условия глав. cold_open — глава начинается сразу со стука в дверь (первые 3 минуты новичка).
const CHAPTERS := {
	"a1c1": {"act": 1, "players": 5, "monsters": 1, "shelters": 2, "capacity": 2, "nights": 3,
		"cold_open": true, "goal": "people_win", "extra": ["admit_night1", "inspect"]},
	"a1c2": {"act": 1, "players": 7, "monsters": 1, "shelters": 3, "capacity": 2, "nights": 3,
		"event": "fog", "goal": "exile_upyr_by_3", "extra": ["no_wrong_exile", "survive"], "guests": ["soldier", "widow"]},
	"a1c3": {"act": 1, "players": 8, "monsters": 2, "shelters": 3, "capacity": 3, "nights": 4,
		"goal": "people_win", "extra": ["keep_couple", "no_wrong_exile"], "guests": ["soldier", "widow", "merchant"]},
	"a2c1": {"act": 2, "map": "mill", "players": 7, "monsters": 1, "shelters": 3, "capacity": 2, "nights": 3,
		"event": "rain", "goal": "people_win", "extra": ["survive", "inspect"], "npc": "miller"},
	"a2c2": {"act": 2, "map": "mill", "players": 8, "monsters": 2, "shelters": 3, "capacity": 2, "nights": 4,
		"goal": "exile_upyr_by_3", "extra": ["no_wrong_exile", "guest_secret"], "guests": ["soldier", "widow", "merchant"],
		"guest_roles": "random", "npc": "miller", "force_upyr": 9},
	"a2c3": {"act": 2, "map": "mill", "players": 9, "monsters": 2, "shelters": 3, "capacity": 3, "nights": 4,
		"event": "moon", "goal": "people_win", "extra": ["keep_couple", "no_wrong_exile"], "npc": "miller", "flood": 2},
	"a3c1": {"act": 3, "map": "monastery", "players": 8, "monsters": 2, "shelters": 3, "capacity": 2, "nights": 4,
		"event": "fog", "goal": "people_win", "extra": ["inspect", "no_wrong_exile"], "guests": ["widow"],
		"npc": "ignat", "npcs": ["anfisa"], "vouch": true},
	"a3c2": {"act": 3, "map": "monastery", "players": 9, "monsters": 2, "shelters": 3, "capacity": 3, "nights": 4,
		"event": "quiet", "goal": "exile_upyr_by_3", "extra": ["survive", "keep_couple"], "npc": "ignat", "npcs": ["anfisa"], "bell": true},
	"a3c3": {"act": 3, "map": "monastery", "players": 10, "monsters": 3, "shelters": 4, "capacity": 3, "nights": 5,
		"event": "moon", "goal": "people_win", "extra": ["no_wrong_exile", "guest_secret"], "guests": ["soldier", "merchant"],
		"guest_roles": "random", "npc": "ignat", "npcs": ["anfisa"], "trial": true},
	"a4c1": {"act": 4, "map": "station", "players": 9, "monsters": 2, "shelters": 3, "capacity": 3, "nights": 4,
		"event": "rain", "goal": "people_win", "extra": ["survive", "inspect"], "guests": ["merchant", "worker"], "npc": "keeper"},
	"a4c2": {"act": 4, "map": "station", "players": 10, "monsters": 3, "shelters": 4, "capacity": 2, "nights": 4,
		"event": "fog", "goal": "exile_upyr_by_3", "extra": ["no_wrong_exile", "keep_couple"], "guests": ["clerk"], "npc": "keeper"},
	"a4c3": {"act": 4, "map": "station", "players": 11, "monsters": 3, "shelters": 4, "capacity": 3, "nights": 5,
		"event": "moon", "goal": "people_win", "extra": ["survive", "no_wrong_exile"], "guests": ["soldier", "widow", "clerk"],
		"guest_roles": "random", "npc": "keeper", "train": true},
}
const ORDER: PackedStringArray = ["a1c1", "a1c2", "a1c3", "a2c1", "a2c2", "a2c3", "a3c1", "a3c2", "a3c3", "a4c1", "a4c2", "a4c3"]
const MAPS := {"mill": "res://config/village_mill.tres", "monastery": "res://config/village_monastery.tres",
	"station": "res://config/village_station.tres"}
const ENDING_ACTS := 4        ## у скольких актов есть концовка; концовка акта IV — финал сезона
const MIN_PLAYERS := 5
const ART := "res://assets/scenes/%s.jpg"     ## картинка главы, если есть: a1c1.jpg …


## Особые условия главы для партии, до Match.start (TASK-021–024).
static func setup_match(m: Match, ch: Dictionary) -> void:
	m.chapter_id = String(ch.get("id", ""))
	m.npc_id = String(ch.get("npc", ""))
	m.force_upyr_story = int(ch.get("force_upyr", -1))
	m.flood_day = int(ch.get("flood", -1))
	# тайна мельника (TASK-022): промолчал — мельник помог с оберегами в монастыре
	m.talisman_whole = int(ch.get("act", 0)) == 3 and miller_choice() == "keep"
	# акт III (TASK-026–030)
	m.extra_npcs = PackedStringArray(ch.get("npcs", []))
	m.vouch_on = bool(ch.get("vouch", false))
	m.bell_on = bool(ch.get("bell", false))
	m.trust_on = int(ch.get("act", 0)) == 3
	m.train_on = bool(ch.get("train", false))
	m.trust = trust_start(String(ch.get("id", "")))


## Финал кампании (TASK-035). Кого игрок потерял раньше всех: первый номер в списке погибших насовсем, -1 — никого.
static func first_lost() -> int:
	return Save.campaign_dead[0] if not Save.campaign_dead.is_empty() else -1


const FINAL_ENDINGS: PackedStringArray = ["final_shore", "final_upyr", "final_many", "final_few"]


## Концовка из четырёх актов: открыл дверь — ушёл на тот берег; сел в поезд — с упырём в вагоне,
## если тот остался в списке, иначе по тому, сколько людей дожило за всю кампанию.
static func final_ending(choice: String, m: Match) -> String:
	if choice == "open":
		return "final_shore"
	if m != null and not m.train_upyrs().is_empty():
		return "final_upyr"
	return "final_many" if Save.campaign_dead.size() <= 4 else "final_few"


## Эпилог: по строке на каждого жителя кампании — кто сел в поезд, кто остался на станции, кого не стало.
static func epilogue_lines(m: Match, ending: String) -> PackedStringArray:
	var out := PackedStringArray()
	var names := L.names()
	for i in range(names.size()):
		var p := Revelations._person(i, m)
		if Save.campaign_dead.has(i):
			out.append(L.t("fin.epi.dead", {"who": p}))
			continue
		var v: Villager = null
		if m != null:
			for x: Villager in m.villagers:
				if x.story_id == i and x.guest_id.is_empty() and not x.is_player:
					v = x
		if v != null and not v.alive:
			out.append(L.t("fin.epi.dead", {"who": p}))
		elif ending == "final_shore":
			out.append(L.t("fin.epi.left_behind", {"who": p}))
		elif v != null and m.on_train(v.id):
			out.append(L.t("fin.epi.upyr_car" if v.is_upyr else "fin.epi.train", {"who": p}))
		else:
			out.append(L.t("fin.epi.station", {"who": p}))
	return out


## Доверие группы переходит из главы в главу акта III (TASK-030): последняя запись "trust" в памяти.
static func trust_start(id: String) -> int:
	if id == "a3c1":
		return Match.TRUST_START
	var out := Match.TRUST_START
	for rec: Dictionary in Save.campaign_memory:
		if String(rec.kind) == "trust" and String(rec.ch).begins_with("a3") and String(rec.ch) != id:
			out = clampi(int(rec.day), 0, Match.TRUST_MAX)
	return out


## Суд в «Крипте» (TASK-029): исход только по журналу. Кто помнит добро — защищает, кто помнит зло — обвиняет.
## {"acquit": bool, "def": [{"who": номер, "kind"}], "acc": [...]}
const TRIAL_DEF: PackedStringArray = ["admitted", "kept", "listened", "react_defend", "refused_you", "broke_you"]
const TRIAL_ACC: PackedStringArray = ["refused_died", "refused", "broken", "exiled_by_you", "react_accuse", "react_revenge"]


static func trial(m: Match) -> Dictionary:
	var recs: Array[Dictionary] = []
	recs.append_array(Save.campaign_memory)
	if m != null:
		for r: Dictionary in m.world.campaign_records(m, 60):
			recs.append(r)
	var dfn: Array[Dictionary] = []
	var acc: Array[Dictionary] = []
	for r: Dictionary in recs:
		var k := String(r.kind)
		if int(r.who) < 0:
			continue
		if TRIAL_DEF.has(k):
			dfn.append({"who": int(r.who), "kind": k})
		elif TRIAL_ACC.has(k):
			acc.append({"who": int(r.who), "kind": k})
	return {"acquit": dfn.size() >= acc.size(), "def": dfn, "acc": acc}


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
	# погибшие насовсем в главу не приходят: если живых местных меньше, чем мест в главе, жителей меньше
	c.players = mini(int(ch.players), maxi(MIN_PLAYERS, cast(id).size() + 1))
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


## Гости главы: кто приехал и ещё жив по ходу кампании.
static func guests(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for g: String in chapter(id).get("guests", []):
		if not Save.campaign_dead_guests.has(g):
			out.append(g)
	return out


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
		"guest_secret":
			if m.day < Guests.REVEAL_DAY:
				return false
			for v: Villager in m.villagers:
				if not v.guest_id.is_empty():
					return true
			return false
		"keep_couple":
			for v: Villager in m.villagers:
				var p := m.get_villager(v.partner_id)
				if p != null and v.alive and p.alive:
					return true
			return false
	return false


## Итог главы: пройдена ли (основная цель), сколько звёзд, кто погиб насовсем.
static func finish(m: Match, ch: Dictionary, d: Director = null) -> Dictionary:
	var g := goals(m, ch)
	var passed := bool(g[0].done)
	var stars := 0
	for x: Dictionary in g:
		if bool(x.done):
			stars += 1
	var lost: Array[int] = []
	var lost_guests := PackedStringArray()
	for v: Villager in m.villagers:
		if v.is_player or v.alive or v.departed:      # уплывший за реку жив и придёт в следующих главах
			continue
		if not v.guest_id.is_empty():
			lost_guests.append(v.guest_id)
		elif v.story_id >= 0:
			lost.append(v.story_id)
	if passed:
		var mem := m.world.campaign_records(m, Save.MEMORY_PER_CHAPTER - 2)
		mem.append_array(boat_records(m))
		mem.append_array(miller_records(m))
		if m.trust_on:
			mem.append({"kind": "trust", "who": -1, "day": m.trust, "knew": []})   # доверие группы — в следующую главу акта
		Save.record_chapter(String(ch.id), stars, lost, lost_guests, mem, d.campaign_bonds() if d != null else {})
	return {"passed": passed, "stars": stars, "goals": g, "lost": lost, "lost_guests": lost_guests, "id": String(ch.id)}


## Концовка акта: сколько из первых жителей деревни дожили до конца акта.
static func act_ending(act: int) -> String:
	var id := act_ending_id(act)
	var text := L.t("camp.act%d.end_%s" % [act, id.get_slice("_", 1)]) if not id.is_empty() else ""
	if act == 1 and not text.is_empty():
		# акт I помнит загадки (TASK-018, 019): разгадана ли лодка и что игрок ответил у доски
		text += " " + L.t("camp.act1.boat" if boat_clues() >= BOAT_SOLVED else "camp.act1.boat_open")
		var board := board_choice()
		if not board.is_empty():
			text += " " + L.t("camp.act1.board_" + board)
	if act == 2 and not text.is_empty():
		# акт II считается по двум актам (TASK-025): тайна мельника и сколько людей потеряно за оба
		var mc := miller_choice()
		if not mc.is_empty():
			text += " " + L.t("camp.act2.miller_" + mc)
		var lost := Save.campaign_dead.size()
		text += " " + L.t("camp.act2.sum_few" if lost <= 2 else ("camp.act2.sum_some" if lost <= 5 else "camp.act2.sum_many"), {"n": lost})
	if act == 3:
		# суд в крипте (TASK-029): проигранный суд — своя концовка акта
		for rec: Dictionary in Save.campaign_memory:
			if String(rec.kind) == "trial_lost":
				return L.t("camp.act3.end_trial")
		if not text.is_empty() and Save.campaign_memory.any(func(r: Dictionary) -> bool: return String(r.kind) == "trial_won"):
			text += " " + L.t("camp.act3.trial_won")
	return text


## Что глава добавила к «Пустой лодке» (TASK-018): находка у реки и спрошенное при всех противоречие.
## Находка есть в каждой из двух глав, вопрос — только если игрок сам сравнил записи. Разгадка — от трёх.
static func boat_records(m: Match) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in m.clues.entries:
		if String(e.mystery) == "boat" and int(e.who) < 0:
			out.append({"kind": "clue_boat", "who": -1, "day": int(e.day), "knew": []})
	for key: String in m.clues.asked:
		for id: String in key.split("|"):
			if String(m.clues.get_entry(id).get("mystery", "")) == "boat":
				out.append({"kind": "clue_boat", "who": -1, "day": m.day, "knew": []})
				break
	return out.slice(0, 2)


const BOAT_SOLVED := 3
const MILLER_KNOWN := 2       ## столько находок о мельнике — и игрок спрашивает его сам, а не слушает исповедь


## Находки тайны мельника в главе (TASK-022): одна на главу акта II.
static func miller_records(m: Match) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in m.clues.entries:
		if String(e.mystery) == "miller" and int(e.who) < 0:
			out.append({"kind": "clue_miller", "who": -1, "day": int(e.day), "knew": []})
	return out.slice(0, 1)


static func miller_clues() -> int:
	var n := 0
	for rec: Dictionary in Save.campaign_memory:
		if String(rec.kind) == "clue_miller":
			n += 1
	return n


## Что игрок решил о мельнике: tell (рассказал беженцам), keep (промолчал) или "".
static func miller_choice() -> String:
	var out := ""
	for rec: Dictionary in Save.campaign_memory:
		if String(rec.kind).begins_with("miller_"):
			out = String(rec.kind).substr(7)
	return out


## Кто из жителей акта I жив и что он помнит об игроке (TASK-025): [{"who": номер, "kind": запись}].
## Самая важная запись на каждого, не больше limit.
static func act_one_memory(limit: int = 3) -> Array[Dictionary]:
	var best: Dictionary = {}
	for rec: Dictionary in Save.campaign_memory:
		var who := int(rec.who)
		if who < 0 or Save.campaign_dead.has(who) or not String(rec.ch).begins_with("a1"):
			continue
		var rank := WorldLog.RANK.find(String(rec.kind))
		if rank < 0:
			continue
		if not best.has(who) or rank < WorldLog.RANK.find(String(best[who].kind)):
			best[who] = rec
	var out: Array[Dictionary] = []
	for who: int in best:
		out.append({"who": who, "kind": String(best[who].kind)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return WorldLog.RANK.find(String(a.kind)) < WorldLog.RANK.find(String(b.kind)))
	return out.slice(0, limit)


## Сколько находок «Пустой лодки» собрано за кампанию.
static func boat_clues() -> int:
	var n := 0
	for rec: Dictionary in Save.campaign_memory:
		if String(rec.kind) == "clue_boat":
			n += 1
	return n


## Что игрок ответил у доски с именем: confess, deny, silent или "" — ещё не был там.
static func board_choice() -> String:
	var out := ""
	for rec: Dictionary in Save.campaign_memory:
		if String(rec.kind).begins_with("board_"):
			out = String(rec.kind).substr(6)
	return out


## Какая концовка акта вышла: act1_all, act1_some или act1_none (и так же для следующих актов).
static func act_ending_id(act: int) -> String:
	if act < 1 or act > ENDING_ACTS:
		return ""
	var first := 0
	var alive := 0
	for i in range(mini(3, L.names().size())):
		first += 1
		if not Save.campaign_dead.has(i):
			alive += 1
	var pre := "act%d_" % act
	if alive >= first:
		return pre + "all"
	return pre + ("some" if alive > 0 else "none")


## Последняя ли это глава своего акта.
static func last_of_act(id: String) -> bool:
	var act := int(chapter(id).get("act", 0))
	var nxt := next_of(id)
	return nxt.is_empty() or int(chapter(nxt).get("act", 0)) != act


static func stars_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(maxi(0, 3 - n))


## Имена погибших в кампании — для строки памяти.
static func fallen() -> Array:
	var out: Array = []
	var names := L.names()
	for idx: int in Save.campaign_dead:
		if idx < names.size():
			out.append({"nom": String(names[idx][0]), "f": bool(names[idx][1])})
	for g: String in Save.campaign_dead_guests:
		if Guests.LIST.has(g):
			out.append({"nom": Guests.name_of(g), "f": bool(Guests.LIST[g].f)})
	return out


## Кто из жителей ещё не простил гибель близкого у двери игрока (TASK-010): обвинял или мстил,
## и с тех пор игрок не впустил его и не сдержал данного ему слова.
static func active_grudges() -> Array[int]:
	return _latest_state(["react_accuse", "react_revenge"], ["admitted", "kept", "react_defend", "react_withdraw"])


## Кто заступился за игрока в прошлых главах и с тех пор не обиделся.
static func defenders() -> Array[int]:
	return _latest_state(["react_defend"], ["react_accuse", "react_revenge", "broken", "refused_died"])


static func _latest_state(on: Array, off: Array) -> Array[int]:
	var out: Array[int] = []
	for idx in range(L.names().size()):
		var state := false
		for rec: Dictionary in Save.memory_of(idx):
			if on.has(String(rec.kind)):
				state = true
			elif off.has(String(rec.kind)):
				state = false
		if state:
			out.append(idx)
	return out


## Строки памяти о жителе с номером idx (TASK-002): «Глава 2: Костя стучал к тебе, дверь осталась закрытой».
## Новые сверху. Не больше limit строк.
static func memory_lines(idx: int, limit: int = 3) -> PackedStringArray:
	var out := PackedStringArray()
	var names := L.names()
	if idx < 0 or idx >= names.size():
		return out
	var who := Villager.new(100 + idx, String(names[idx][0]), false)
	who.female = bool(names[idx][1])
	var recs := Save.memory_of(idx)
	recs.reverse()
	for rec: Dictionary in recs:
		var key := "book.mem_" + String(rec.kind)
		if not L.has(key):
			continue
		out.append(L.t(key, {"who": who, "n": ORDER.find(String(rec.ch)) + 1}))
		if out.size() >= limit:
			break
	return out


static func art(id: String) -> Texture2D:
	var p := Scenes.art(id)
	return load(p) as Texture2D if ResourceLoader.exists(p) else null
