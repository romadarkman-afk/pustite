class_name Match
extends RefCounted
## Правила игры и машина состояний партии.
## Чистая логика: не знает про экраны, не трогает SceneTree.
## Наружу общается только сигналами. Переходы фаз решает только Match.

enum Phase { IDLE, PROLOGUE, DAY, VOTE, NIGHT, DOOR, MORNING, OVER }
enum Team { NONE, PEOPLE, UPYRI }
enum DoorRole { DEAD, HOST, GUEST, ALONE }
## Роли людей (задача 31). Каждый человек получает одну, пока хватает ролей. Упыри ролей не имеют,
## но могут назваться Старожилом. Старожил и Знахарка срабатывают один раз за партию,
## голос Старосты на изгнании всегда считается за два.
enum Role { NONE, ELDER, HEALER, HEADMAN }

signal phase_changed(phase: Phase)
signal chat_posted(line: ChatLine)

const NAMES: PackedStringArray = [
	"Марина", "Тимур", "Лида", "Костя", "Женя", "Артур",
	"Захар", "Рита", "Гриша", "Нина", "Вадим", "Полина",
]
const FEMALE: PackedStringArray = ["Марина", "Лида", "Женя", "Рита", "Нина", "Полина"]
const HOUSES: PackedStringArray = ["Дом у реки", "Сарай", "Церковь", "Погреб", "Гараж"]


## Кто к какому убежищу пришёл ночью. Первый добежавший — хозяин двери.
class Seat:
	var house: int
	var host: Villager
	var queue: Array[Villager] = []
	var admitted: Array[Villager] = []
	var decided: bool = false
	## Подражатель: тварь стучит голосом этого жителя (он в другом доме или уже погиб).
	var mimic: Villager = null
	var mimic_at: int = 0          ## каким по счёту он стоит среди стучащих
	var mimic_in: bool = false     ## его впустили

	## Все, кто стучит в дверь: очередь и, если пришёл, Подражатель на своём месте.
	func knockers() -> Array[Villager]:
		var out: Array[Villager] = queue.duplicate()
		if mimic != null:
			out.insert(clampi(mimic_at, 0, out.size()), mimic)
		return out

	func inside() -> Array[Villager]:
		var out: Array[Villager] = [host]
		out.append_array(admitted)
		return out

	func turned_away() -> Array[Villager]:
		var out: Array[Villager] = []
		for v: Villager in queue:
			if not admitted.has(v):
				out.append(v)
		return out


var config: GameConfig
var villagers: Array[Villager] = []
var houses: PackedStringArray = []
var day: int = 0
var phase: Phase = Phase.IDLE
var winner: Team = Team.NONE
var chat: Array[ChatLine] = []
var chronicle: PackedStringArray = []
var seats: Array[Seat] = []
var report: NightReport
var last_exiled: Villager
var last_tally: Dictionary[int, int] = {}
var rng := RandomNumberGenerator.new()

## Дела по посёлку и запасы дня. Запасы снижают шанс погибнуть ночью на улице
## и одному в доме: фонари горят, обереги держатся.
const SUPPLY_BONUS := 0.2           ## полные запасы срезают столько от шанса гибели
const DEFAULT_VILLAGE := "res://config/village_default.tres"
var jobs: Array[JobDef] = []                 ## дела сегодняшнего дня: обычные и починка оберегов
var base_jobs: Array[JobDef] = []            ## обычные дела из карты посёлка
var village: VillageDef

## Обереги убежищ: 2 — целый, 1 — треснул, 0 — расколот.
## Целый бережёт того, кто остался в доме один. Расколотый пускает в дом тварь из леса.
## За ночь оберег слабеет с шансом TALISMAN_DECAY; днём его чинят как дело.
const TALISMAN_MAX := 2
const TALISMAN_DECAY := 0.5
const CREATURE_KILL := 0.7
const ALONE_SAFE := 0.8                      ## целый оберег: одному в доме безопаснее (шанс гибели × 0.8)
var talisman: PackedInt32Array = PackedInt32Array()
var job_left: PackedInt32Array = PackedInt32Array()
var supply_done: int = 0
var supply_total: int = 0

## Подражатель (со второй ночи): тварь стучит в одну из дверей голосом жителя,
## который сейчас в другом доме или уже погиб. Впустили — забирает одного из тех, кто внутри.
const MIMIC_P := 0.4
const MIMIC_KILL := 0.85

## События ночи (со второй ночи): меняют правила на одну ночь. Объявляются с колоколом.
enum Event { NONE, FOG, MOON, QUIET, RAIN }
const EVENT_P := 0.5
const EVENT_TITLE := {Event.FOG: "Туман", Event.MOON: "Полная луна", Event.QUIET: "Тихая ночь", Event.RAIN: "Ливень"}
const EVENT_TEXT := {
	Event.FOG: "Туман глушит колокол: на бег меньше времени, на улице опаснее.",
	Event.MOON: "Полная луна: к утру ослабнут все обереги.",
	Event.QUIET: "Тихая ночь: на улице спокойнее, Подражатель не придёт.",
	Event.RAIN: "Ливень заливает фонари: масло из запасов этой ночью не поможет.",
}
const FOG_RUN := 3              ## туман: на столько секунд короче звон
const FOG_DEATH := 0.1          ## туман: настолько опаснее улица
const QUIET_SAFE := 0.25        ## тихая ночь: настолько безопаснее улица
var night_event: Event = Event.NONE
var force_event: int = -1       ## самотесты: следующее событие ночи будет этим (со второй ночи)

## Знахарка: кто из знахарок взял травы этой ночью.
var healer_on: Dictionary[int, bool] = {}
## Что посёлок знает о ролях: кто кем назвался вслух. id -> строка для дневника.
var claims: Dictionary[int, String] = {}

## Экстренный сбор (задача 32): раз за партию любой может днём ударить в колокол — сразу голосование.
var meeting_used: Dictionary[int, bool] = {}
var meeting_by: int = -1           ## кто созвал сбор сегодня; -1 — сегодня сбора не было

## Туннель (задача 33): ход под посёлком между двумя убежищами. Кого не пустили в одно,
## может пролезть в другое, если там есть место. Упыри лезут охотнее.
const TUNNEL_UPYR := 0.8
const TUNNEL_HUMAN := 0.4
var tunnel: Vector2i = Vector2i(-1, -1)
var tunnel_log: Array[Array] = []   ## этой ночью: [житель, откуда, куда]

## Дневник (задача 34): что было каждой ночью. {"day", "where": {id: дом, -1 — улица}, "said": {id: дом}, "dead": [id]}
var history: Array[Dictionary] = []
var _night_ids: Array[int] = []     ## кто был жив, когда началась ночь
var player_seen: Dictionary[int, int] = {}   ## что игрок-старожил увидел на рисунках: id -> 1 упырь, 0 человек

## Ящик (со второго дня): днём на краю площади появляется ящик. Кто первым откроет,
## тому достаётся находка: записка (один из двоих — упырь), масло (+2 к запасам) или мел (чинит оберег).
enum Loot { NONE, NOTE, OIL, CHALK }
const BOX_P := 0.6
const BOX_OIL := 2
var box_today: bool = false
var box_pos: Vector2 = Vector2.ZERO
var box_loot: Loot = Loot.NONE
var box_opened_by: int = -1


# =============================================================
# Запросы (только чтение)
# =============================================================
func alive() -> Array[Villager]:
	var out: Array[Villager] = []
	for v: Villager in villagers:
		if v.alive:
			out.append(v)
	return out


func alive_bots() -> Array[Villager]:
	var out: Array[Villager] = []
	for v: Villager in villagers:
		if v.alive and not v.is_player:
			out.append(v)
	return out


func player() -> Villager:
	return villagers[0]


func get_villager(vid: int) -> Villager:
	for v: Villager in villagers:
		if v.id == vid:
			return v
	return null


func house_name(i: int) -> String:
	return houses[clampi(i, 0, houses.size() - 1)]


func humans_alive() -> int:
	var n := 0
	for v: Villager in villagers:
		if v.alive and not v.is_upyr:
			n += 1
	return n


func upyri_alive() -> int:
	var n := 0
	for v: Villager in villagers:
		if v.alive and v.is_upyr:
			n += 1
	return n


func vote_open() -> bool:
	return day >= config.vote_from_day and alive().size() > 2


func player_seat() -> Seat:
	for s: Seat in seats:
		if s.host == player() or s.queue.has(player()):
			return s
	return null


func player_door_role() -> DoorRole:
	if not player().alive:
		return DoorRole.DEAD
	var s := player_seat()
	if s == null:
		return DoorRole.DEAD
	if s.host != player():
		return DoorRole.GUEST
	return DoorRole.HOST if not s.knockers().is_empty() else DoorRole.ALONE


# =============================================================
# Чат
# =============================================================
func post(line: ChatLine) -> void:
	chat.append(line)
	chat_posted.emit(line)


# =============================================================
# Машина состояний. Каждый метод — единственный легальный вход в фазу.
# =============================================================
func start(cfg: GameConfig, seed_value: int = 0) -> void:
	config = cfg.sanitized()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var pool := Array(NAMES)
	_shuffle(pool)
	villagers.clear()
	villagers.append(Villager.new(0, "Вы", true))
	for i in range(config.players - 1):
		var v := Villager.new(i + 1, String(pool[i]), false)
		v.female = FEMALE.has(v.name)
		villagers.append(v)

	var order: Array = range(villagers.size())
	if config.player_always_human:
		order.erase(0)
	_shuffle(order)
	for k in range(mini(config.monsters, order.size())):
		villagers[int(order[k])].is_upyr = true

	houses = HOUSES.slice(0, config.shelters)
	_deal_roles()
	tunnel = Vector2i(-1, -1)
	if houses.size() >= 2:
		var a := rng.randi_range(0, houses.size() - 1)
		var b := (a + rng.randi_range(1, houses.size() - 1)) % houses.size()
		tunnel = Vector2i(mini(a, b), maxi(a, b))
	if village == null:
		village = load(DEFAULT_VILLAGE) as VillageDef
	base_jobs.clear()
	if village != null:
		for j: JobDef in village.jobs:
			if j.kind != JobDef.Kind.TALISMAN:
				base_jobs.append(j)
	# обереги: все целы, кроме одного — он треснул ещё до вас
	talisman = PackedInt32Array()
	for i in range(houses.size()):
		talisman.append(TALISMAN_MAX)
	if not houses.is_empty():
		talisman[rng.randi_range(0, houses.size() - 1)] = TALISMAN_MAX - 1
	day = 1
	winner = Team.NONE
	claims.clear()
	meeting_used.clear()
	history.clear()
	player_seen.clear()
	chat.clear()
	chronicle.clear()
	seats.clear()
	report = null
	last_exiled = null
	_set_phase(Phase.PROLOGUE)


func begin_day() -> void:
	assert(phase == Phase.PROLOGUE or phase == Phase.MORNING)
	for v: Villager in villagers:
		v.announced_house = -1
	night_event = Event.NONE
	meeting_by = -1
	jobs = base_jobs.duplicate()
	for h in range(houses.size()):
		if talisman[h] < TALISMAN_MAX:
			jobs.append(_talisman_job(h))
	_roll_box()
	job_left = PackedInt32Array()
	supply_total = 0
	for j: JobDef in jobs:
		job_left.append(j.portions)
		supply_total += j.portions
	supply_done = 0
	_set_phase(Phase.DAY)
	post(ChatLine.system("Светает. Все выходят на площадь." if day == 1
		else "День %d. Живых осталось %d." % [day, alive().size()]))


## Сделал дело. Засчитывается, если работа настоящая и у дела ещё есть порции.
## Возвращает true, если запасы выросли.
func do_job(_v: Villager, ji: int, real: bool) -> bool:
	if phase != Phase.DAY or ji < 0 or ji >= job_left.size():
		return false
	if not real or job_left[ji] <= 0 or jobs[ji].kind == JobDef.Kind.BOX:
		return false
	job_left[ji] -= 1
	supply_done += 1
	if jobs[ji].house >= 0 and jobs[ji].house < talisman.size():
		talisman[jobs[ji].house] = mini(TALISMAN_MAX, talisman[jobs[ji].house] + 1)
	return true


## Починка оберега убежища h — дело дня. Место работника — у двери дома.
func _talisman_job(h: int) -> JobDef:
	var j := JobDef.new()
	j.id = StringName("talisman_%d" % h)
	j.title = "Подправить оберег"
	j.place = "у оберега"
	j.done_line = "Оберег как новый."
	j.kind = JobDef.Kind.TALISMAN
	j.house = h
	j.portions = TALISMAN_MAX - talisman[h]
	j.work_sec = 4.0
	var hd: HouseDef = village.shelters[h] if village != null and h < village.shelters.size() else null
	j.pos = (hd.pos + Vector2(-hd.size.x * 0.5 + 14.0, 26.0)) if hd != null else Vector2(360, 392)
	return j


## Шанс погибнуть одному в доме: целый оберег снижает, расколотый — тварь из леса.
func alone_death_chance(h: int, p_out: float) -> float:
	match talisman[h] if h >= 0 and h < talisman.size() else TALISMAN_MAX:
		TALISMAN_MAX:
			return p_out * ALONE_SAFE
		0:
			return maxf(p_out, CREATURE_KILL)
	return p_out


func job_index(id: StringName) -> int:
	for i in range(jobs.size()):
		if jobs[i].id == id:
			return i
	return -1


func job_available(ji: int) -> bool:
	return ji >= 0 and ji < job_left.size() and job_left[ji] > 0


## Запасы дня 0..1.
func supplies() -> float:
	return float(supply_done) / float(supply_total) if supply_total > 0 else 0.0


func outside_death_chance() -> float:
	var p := config.outside_death_chance(day)
	if night_event != Event.RAIN:
		p -= SUPPLY_BONUS * supplies()
	match night_event:
		Event.FOG: p += FOG_DEATH
		Event.QUIET: p -= QUIET_SAFE
	return clampf(p, 0.05, 0.95)


## Сколько звонит колокол этой ночью: в тумане меньше.
func run_seconds() -> int:
	return maxi(5, config.run_seconds - (FOG_RUN if night_event == Event.FOG else 0))


# =============================================================
# Саботаж: упырь портит уже сделанное
# =============================================================
## Испортить сделанное у дела: запасы −1, порция возвращается делу — её можно сделать заново.
## Портить можно только там, где сегодня уже что-то сделали. Обереги не портятся.
func can_sabotage(ji: int) -> bool:
	return phase == Phase.DAY and ji >= 0 and ji < jobs.size() and supply_done > 0 \
		and jobs[ji].house < 0 and jobs[ji].kind != JobDef.Kind.BOX and job_left[ji] < jobs[ji].portions


func sabotage(ji: int) -> bool:
	if not can_sabotage(ji):
		return false
	job_left[ji] += 1
	supply_done -= 1
	return true


# =============================================================
# Ящик
# =============================================================
func _roll_box() -> void:
	box_today = false
	box_loot = Loot.NONE
	box_opened_by = -1
	if day < 2 or village == null or village.box_spots.is_empty() or rng.randf() >= BOX_P:
		return
	box_today = true
	box_pos = village.box_spots[rng.randi_range(0, village.box_spots.size() - 1)]
	var r := rng.randf()
	box_loot = Loot.NOTE if r < 0.5 else (Loot.OIL if r < 0.75 else Loot.CHALK)


## Ящик появился на площади: становится делом дня «Открыть ящик». Запасов не прибавляет.
func place_box() -> int:
	if not box_today or phase != Phase.DAY or job_index(&"box") >= 0:
		return job_index(&"box")
	var j := JobDef.new()
	j.id = &"box"
	j.title = "Открыть ящик"
	j.place = "у ящика"
	j.done_line = ""
	j.kind = JobDef.Kind.BOX
	j.portions = 1
	j.work_sec = 3.0
	j.pos = box_pos
	jobs.append(j)
	job_left.append(1)
	return jobs.size() - 1


## Открыть ящик. Ответ: {"loot": Loot, "a": Villager, "b": Villager, "house": int} или пусто, если уже открыт.
## Записка честная: ровно один из двоих — упырь. Что с ней делать — решает открывший.
func open_box(v: Villager) -> Dictionary:
	var ji := job_index(&"box")
	if ji < 0 or job_left[ji] <= 0 or v == null or not v.alive:
		return {}
	job_left[ji] = 0
	box_opened_by = v.id
	var loot := box_loot
	var out := {"loot": loot}
	if loot == Loot.NOTE:
		var ups: Array[Villager] = []
		var hums: Array[Villager] = []
		for o: Villager in alive():
			if o == v:
				continue
			if o.is_upyr:
				ups.append(o)
			else:
				hums.append(o)
		if ups.is_empty() or hums.is_empty():
			loot = Loot.OIL
		else:
			var pair: Array[Villager] = [ups[rng.randi_range(0, ups.size() - 1)], hums[rng.randi_range(0, hums.size() - 1)]]
			_shuffle(pair)
			out["a"] = pair[0]
			out["b"] = pair[1]
	if loot == Loot.CHALK:
		var worst := -1
		for h in range(talisman.size()):
			if talisman[h] < TALISMAN_MAX and (worst < 0 or talisman[h] < talisman[worst]):
				worst = h
		if worst < 0:
			loot = Loot.OIL
		else:
			talisman[worst] += 1
			out["house"] = worst
			var tj := job_index(StringName("talisman_%d" % worst))
			if tj >= 0:
				job_left[tj] = maxi(0, job_left[tj] - 1)
	if loot == Loot.OIL:
		supply_done = mini(supply_total, supply_done + BOX_OIL)
	out["loot"] = loot
	return out


func end_day() -> void:
	assert(phase == Phase.DAY)
	_set_phase(Phase.VOTE if vote_open() else Phase.NIGHT)


## tally: id цели -> число голосов. Ничья решается жребием.
func apply_vote(tally: Dictionary[int, int]) -> Villager:
	assert(phase == Phase.VOTE)
	last_tally = tally
	var best := -1
	var leaders: Array[int] = []
	for vid: int in tally:
		if tally[vid] > best:
			best = tally[vid]
			leaders = [vid]
		elif tally[vid] == best:
			leaders.append(vid)
	last_exiled = null
	if not leaders.is_empty():
		last_exiled = get_villager(leaders[rng.randi_range(0, leaders.size() - 1)])
		last_exiled.alive = false
		last_exiled.exiled = true
		last_exiled.exiled_day = day
		_log("День %d: посёлок изгнал %s." % [day, "вас" if last_exiled.is_player else Ru.accusative(last_exiled.name)])
	return last_exiled


func after_vote() -> void:
	assert(phase == Phase.VOTE)
	if _settle_winner():
		_set_phase(Phase.OVER)
	else:
		_set_phase(Phase.NIGHT)


## Рассадка на ночь. arrival — когда кто добежал до двери (секунды от колокола):
## первый добежавший внутри и решает, остальные в очереди в порядке прибытия.
## Кого нет в arrival, тот добегает после всех известных, между собой — в случайном порядке.
func seat_night(choices: Dictionary[int, int], arrival: Dictionary[int, float] = {}) -> void:
	assert(phase == Phase.NIGHT)
	seats.clear()
	healer_on.clear()
	tunnel_log.clear()
	_night_ids.clear()
	for v: Villager in alive():
		_night_ids.append(v.id)
	var buckets: Array = []
	for i in range(houses.size()):
		buckets.append([])
	for v: Villager in alive():
		var h: int = clampi(choices.get(v.id, 0), 0, houses.size() - 1)
		v.night_house = h
		buckets[h].append(v)
	for i in range(houses.size()):
		var arrivals: Array = buckets[i]
		if arrivals.is_empty():
			continue
		_shuffle(arrivals)
		var key: Dictionary[int, float] = {}
		for k in range(arrivals.size()):
			var v: Villager = arrivals[k]
			key[v.id] = arrival.get(v.id, 1.0e6 + k)
		arrivals.sort_custom(func(a: Villager, b: Villager) -> bool: return key[a.id] < key[b.id])
		var s := Seat.new()
		s.house = i
		s.host = arrivals[0]
		for k in range(1, arrivals.size()):
			s.queue.append(arrivals[k])
		seats.append(s)
	_place_mimic()
	_set_phase(Phase.DOOR)


## Подражатель выбирает дверь и голос: житель не из этого дома — живой в другом месте или погибший.
func _place_mimic() -> void:
	if day < 2 or seats.is_empty() or night_event == Event.QUIET or rng.randf() >= MIMIC_P:
		return
	var s: Seat = seats[rng.randi_range(0, seats.size() - 1)]
	var voices: Array[Villager] = []
	for v: Villager in villagers:
		if v.is_player or v == s.host or s.queue.has(v):
			continue
		voices.append(v)
	if voices.is_empty():
		return
	s.mimic = voices[rng.randi_range(0, voices.size() - 1)]
	s.mimic_at = rng.randi_range(0, s.queue.size())


func admit(seat: Seat, ids: Array[int]) -> void:
	assert(phase == Phase.DOOR)
	seat.admitted.clear()
	seat.mimic_in = false
	var n := 0
	for v: Villager in seat.knockers():
		if ids.has(v.id) and n < config.capacity - 1:
			n += 1
			if v == seat.mimic:
				seat.mimic_in = true
			else:
				seat.admitted.append(v)
	seat.decided = true


func resolve_night() -> NightReport:
	assert(phase == Phase.DOOR)
	var r := NightReport.new()
	var p_out := outside_death_chance()
	if supply_total > 0:
		_log("Ночь %d: запасов набрали на %d%%." % [day, roundi(100.0 * supplies())])

	var was_fed: Dictionary[int, bool] = {}
	for v: Villager in villagers:
		if v.fed:
			was_fed[v.id] = true
		v.fed = false

	# 0. Кто пролез туннелем — утром это знают все
	for t: Array in tunnel_log:
		var et := r.add(NightReport.Kind.TUNNEL, t[0], t[2])
		et.said_house = t[1]
		_log("Ночь %d: %s не пустили в «%s», и %s туннелем в «%s»." % [day, Ru.acc(t[0]), house_name(t[1]),
			Ru.g(t[0], "он пролез", "она пролезла", "вы пролезли"), Ru.house_in(house_name(t[2]))])

	# 1. Кого не пустили — улица
	for s: Seat in seats:
		for v: Villager in s.turned_away():
			v.night_house = -1
			if v.is_upyr:
				r.add(NightReport.Kind.SURVIVED_STREET, v, s.house)
				_log("Ночь %d: %s не пустили в «%s», но %s до утра." % [day, Ru.acc(v), house_name(s.house), Ru.g(v, "он дожил", "она дожила", "вы дожили")])
			elif rng.randf() < p_out:
				v.alive = false
				r.add(NightReport.Kind.KILLED_STREET, v, s.house)
				_log("Ночь %d: %s не пустили в «%s». %s" % [day, Ru.acc(v), house_name(s.house), Ru.g(v, "Утром его нашли на улице.", "Утром её нашли на улице.", "Вы погибли на улице.")])
			else:
				r.add(NightReport.Kind.SURVIVED_STREET, v, s.house)
				_log("Ночь %d: %s %s на улице и %s." % [day, Ru.nom(v), Ru.g(v, "ночевал", "ночевала", "ночевали"), Ru.g(v, "выжил", "выжила", "выжили")])

	# 1б. Подражатель: впустили — забирает одного из тех, кто внутри. Не впустили — стук слышали все.
	for s: Seat in seats:
		if s.mimic == null:
			continue
		if not s.mimic_in:
			var ek := r.add(NightReport.Kind.MIMIC_KNOCK, null, s.house)
			ek.voice = s.mimic
			_log("Ночь %d: в дверь «%s» стучали голосом %s. Не открыли." % [day, Ru.house_of(house_name(s.house)), Ru.gen(s.mimic)])
			continue
		var inside3: Array[Villager] = []
		for v: Villager in s.inside():
			if v.alive:
				inside3.append(v)
		if inside3.is_empty() or rng.randf() >= MIMIC_KILL:
			var es := r.add(NightReport.Kind.MIMIC_SPARED, null, s.house)
			es.voice = s.mimic
			_log("Ночь %d: в «%s» впустили голос %s. Это был не %s, но до утра все целы." % [day, Ru.house_in(house_name(s.house)), Ru.gen(s.mimic), s.mimic.name])
			continue
		var gone: Villager = inside3[rng.randi_range(0, inside3.size() - 1)]
		if _healed(s, gone, r, "mimic"):
			continue
		gone.alive = false
		var left: Array[Villager] = []
		for v: Villager in inside3:
			if v != gone:
				left.append(v)
		var em := r.add(NightReport.Kind.KILLED_MIMIC, gone, s.house, left)
		em.voice = s.mimic
		_log("Ночь %d: в «%s» впустили голос %s. Это был Подражатель: он забрал %s." % [day, Ru.house_in(house_name(s.house)), Ru.gen(s.mimic), Ru.acc(gone)])

	# 2. Что было за дверьми. Кто остался один после визита Подражателя, до утра в безопасности:
	# тварь насытилась или ушла, второй раз за ночь в этот дом никто не придёт.
	for s: Seat in seats:
		var inside: Array[Villager] = s.inside().filter(func(v: Villager) -> bool: return v.alive)
		if inside.is_empty():
			continue
		if s.mimic_in and inside.size() == 1:
			continue
		if inside.size() == 1:
			var lone: Villager = inside[0]
			if lone.is_upyr:
				r.add(NightReport.Kind.SURVIVED_ALONE, lone, s.house)
			elif rng.randf() < alone_death_chance(s.house, p_out):
				lone.alive = false
				r.add(NightReport.Kind.KILLED_ALONE, lone, s.house)
				_log("Ночь %d: %s в «%s». Оберег погас." % [day, Ru.g(lone, lone.name + " остался один", lone.name + " осталась одна", "Вы остались одни"), Ru.house_in(house_name(s.house))])
			else:
				r.add(NightReport.Kind.SURVIVED_ALONE, lone, s.house)
			continue

		var hungry: Array[Villager] = []
		var humans: Array[Villager] = []
		for v: Villager in inside:
			if v.is_upyr and not was_fed.has(v.id):
				hungry.append(v)
			elif not v.is_upyr:
				humans.append(v)

		if not hungry.is_empty() and not humans.is_empty():
			var killer: Villager = hungry[rng.randi_range(0, hungry.size() - 1)]
			var victim: Villager = humans[rng.randi_range(0, humans.size() - 1)]
			killer.fed = true
			if _healed(s, victim, r, "upyr"):
				continue
			victim.alive = false
			var others: Array[Villager] = []
			for v: Villager in inside:
				if v != victim:
					others.append(v)
			r.add(NightReport.Kind.KILLED_INSIDE, victim, s.house, others)
			_log("Ночь %d: %s %s в «%s». Рядом %s: %s." % [
				day, Ru.nom(victim), Ru.g(victim, "погиб", "погибла", "погибли"), Ru.house_in(house_name(s.house)), Ru.were(others, "был", "была", "были"), Ru.join(others)])
		else:
			# все люди — или упырь сытый. Снаружи не отличить, и в этом весь смысл.
			r.add(NightReport.Kind.CLEAN_ROOM, s.host, s.house, inside.duplicate())
			_log("Ночь %d: в «%s» ночевали %s — все целы." % [day, Ru.house_in(house_name(s.house)), Ru.join(inside)])

	# 2б. Расколотый оберег: в дом, где ночевали несколько, входит тварь из леса
	for s: Seat in seats:
		var inside2 := s.inside()
		if inside2.size() < 2 or s.house >= talisman.size() or talisman[s.house] > 0:
			continue
		var prey: Array[Villager] = []
		for v: Villager in inside2:
			if v.alive and not v.is_upyr:
				prey.append(v)
		if prey.is_empty() or rng.randf() >= CREATURE_KILL:
			continue
		var taken: Villager = prey[rng.randi_range(0, prey.size() - 1)]
		if _healed(s, taken, r, "creature"):
			continue
		taken.alive = false
		var rest: Array[Villager] = []
		for v: Villager in inside2:
			if v != taken:
				rest.append(v)
		r.add(NightReport.Kind.KILLED_CREATURE, taken, s.house, rest)
		_log("Ночь %d: оберег у «%s» был расколот. Тварь из леса забрала %s." % [day, Ru.house_of(house_name(s.house)), Ru.acc(taken)])

	# 3. Сказал одно — ночевал в другом месте
	for v: Villager in villagers:
		if v.announced_house >= 0 and v.night_house >= 0 and v.night_house != v.announced_house:
			var e := r.add(NightReport.Kind.LIAR, v, v.night_house)
			e.said_house = v.announced_house
			_log("Ночь %d: %s %s про «%s», а %s в «%s»." % [
				day, Ru.nom(v), Ru.g(v, "говорил", "говорила", "говорили"), house_name(v.announced_house), Ru.g(v, "ночевал", "ночевала", "ночевали"), Ru.house_in(house_name(v.night_house))])

	# 4. За ночь обереги слабеют
	for h in range(talisman.size()):
		if talisman[h] > 0 and (night_event == Event.MOON or rng.randf() < TALISMAN_DECAY):
			talisman[h] -= 1
			r.add(NightReport.Kind.TALISMAN_WORN, null, h)
			_log("Утром: оберег у «%s» %s." % [Ru.house_of(house_name(h)), "треснул" if talisman[h] == 1 else "раскололся"])

	# дневник: кто где был этой ночью и кого не стало
	var rec := {"day": day, "where": {}, "said": {}, "dead": []}
	for vid: int in _night_ids:
		var v := get_villager(vid)
		rec.where[vid] = v.night_house
		rec.said[vid] = v.announced_house
	for e: NightReport.Entry in r.deaths():
		rec.dead.append(e.who.id)
	history.append(rec)

	report = r
	_settle_winner()
	_set_phase(Phase.MORNING)
	return r


func end_morning() -> void:
	assert(phase == Phase.MORNING)
	if winner == Team.NONE and day >= config.nights:
		winner = Team.PEOPLE
	if winner != Team.NONE:
		_set_phase(Phase.OVER)
		return
	day += 1
	begin_day()


# =============================================================
# Роли
# =============================================================
func _deal_roles() -> void:
	var hums: Array = []
	for v: Villager in villagers:
		v.role = Role.NONE
		v.role_used = false
		if not v.is_upyr:
			hums.append(v)
	_shuffle(hums)
	var roles := [Role.ELDER, Role.HEALER, Role.HEADMAN]
	for k in range(mini(roles.size(), hums.size() - 1)):
		(hums[k] as Villager).role = roles[k]


static func role_name(v: Villager) -> String:
	match v.role:
		Role.ELDER: return "Старожил"
		Role.HEALER: return "Знахарь" if not v.female or v.is_player else "Знахарка"
		Role.HEADMAN: return "Староста"
	return ""


func role_holder(r: int) -> Villager:
	for v: Villager in villagers:
		if v.role == r:
			return v
	return null


## Старожил смотрит рисунки: упырь ли target. Один раз за партию, только днём.
## Ответ: 1 — упырь, 0 — человек, -1 — нельзя (не Старожил, уже смотрел, не день).
func elder_check(by: Villager, target: Villager) -> int:
	if phase != Phase.DAY or by == null or target == null or by.role != Role.ELDER or by.role_used or not by.alive or target == by:
		return -1
	by.role_used = true
	if by.is_player:
		player_seen[target.id] = 1 if target.is_upyr else 0
	return 1 if target.is_upyr else 0


## Знахарка берёт травы на эту ночь: если рядом с ней в доме кого-то убьют, она его выходит.
func heal_tonight(v: Villager) -> bool:
	if v == null or not v.alive or v.role != Role.HEALER or v.role_used or not (phase == Phase.NIGHT or phase == Phase.DOOR):
		return false
	healer_on[v.id] = true
	return true


## Выходит ли Знахарка того, на кого напали в доме seat. Тратит способность.
func _healed(s: Seat, victim: Villager, r: NightReport, cause: String) -> bool:
	for h: Villager in s.inside():
		if h != victim and h.alive and healer_on.get(h.id, false) and not h.role_used:
			h.role_used = true
			healer_on.erase(h.id)
			claims[h.id] = "%s: %s %s в ночь %d" % [role_name(h), Ru.g(h, "выходил", "выходила", "выходили"), Ru.acc(victim), day]
			var e := r.add(NightReport.Kind.SAVED, victim, s.house, [h] as Array[Villager])
			e.cause = cause
			var healer_txt := "вы" if h.is_player else "%s %s" % [role_name(h).to_lower(), h.name]
			var obj := "вас" if victim.is_player else ("её" if victim.female else "его")
			_log("Ночь %d: в «%s» на %s напали, но %s %s %s." % [day, Ru.house_in(house_name(s.house)), Ru.acc(victim),
				healer_txt, obj, Ru.g(h, "выходил", "выходила", "выходили")])
			return true
	return false


## Сколько весит голос на изгнании: у Старосты — два.
func vote_weight(vid: int) -> int:
	var v := get_villager(vid)
	return 2 if v != null and v.alive and v.role == Role.HEADMAN else 1


# =============================================================
# Экстренный сбор
# =============================================================
func can_meeting(v: Villager) -> bool:
	return phase == Phase.DAY and v != null and v.alive and not meeting_used.has(v.id)


func call_meeting(v: Villager) -> bool:
	if not can_meeting(v):
		return false
	meeting_used[v.id] = true
	meeting_by = v.id
	_log("День %d: %s %s в колокол: экстренный сбор." % [day, Ru.nom(v), Ru.g(v, "ударил", "ударила", "ударили")])
	_set_phase(Phase.VOTE)
	return true


# =============================================================
# Туннель
# =============================================================
## Куда ведёт туннель из дома h. -1 — из этого дома хода нет.
func tunnel_to(h: int) -> int:
	if tunnel.x < 0:
		return -1
	if h == tunnel.x:
		return tunnel.y
	if h == tunnel.y:
		return tunnel.x
	return -1


func _seat_of_house(h: int) -> Seat:
	for s: Seat in seats:
		if s.house == h:
			return s
	return null


## Есть ли место на том конце туннеля из дома h.
func tunnel_room(h: int) -> bool:
	var to := tunnel_to(h)
	if to < 0:
		return false
	var s := _seat_of_house(to)
	return s == null or s.inside().size() < config.capacity


## После дверей, до ночи: кого не пустили у дома с туннелем, тот может пролезть на другой конец.
## Игрок лезет, если выбрал это сам (player_goes). Хозяин того дома пролезшего не выбирает.
func tunnel_pass(player_goes: bool) -> void:
	assert(phase == Phase.DOOR)
	tunnel_log.clear()
	if tunnel.x < 0:
		return
	var order: Array[Villager] = []
	for s: Seat in seats:
		if tunnel_to(s.house) >= 0:
			for v: Villager in s.turned_away():
				if v.is_player:
					order.push_front(v)    # игрок решил первым
				else:
					order.append(v)
	for v: Villager in order:
		var from := v.night_house
		var wants := player_goes if v.is_player else rng.randf() < (TUNNEL_UPYR if v.is_upyr else TUNNEL_HUMAN)
		if not wants or not tunnel_room(from):
			continue
		var to := tunnel_to(from)
		var src := _seat_of_house(from)
		src.queue.erase(v)
		var dst := _seat_of_house(to)
		if dst == null:
			dst = Seat.new()
			dst.house = to
			dst.host = v
			dst.decided = true
			seats.append(dst)
		else:
			dst.admitted.append(v)
		v.night_house = to
		tunnel_log.append([v, from, to])


# =============================================================
func _settle_winner() -> bool:
	if humans_alive() == 0:
		winner = Team.UPYRI
	elif upyri_alive() == 0:
		winner = Team.PEOPLE
	return winner != Team.NONE


func _set_phase(p: Phase) -> void:
	phase = p
	if p == Phase.NIGHT:
		_roll_event()
	phase_changed.emit(p)


func _roll_event() -> void:
	night_event = Event.NONE
	if day < 2:
		return
	if force_event >= 0:
		night_event = force_event as Event
	elif rng.randf() < EVENT_P:
		night_event = (rng.randi_range(1, Event.size() - 1)) as Event
	if night_event != Event.NONE:
		_log("Ночь %d: %s." % [day, String(EVENT_TITLE[night_event]).to_lower()])


func _log(t: String) -> void:
	chronicle.append(t)


func _names(list: Array[Villager]) -> PackedStringArray:
	var out: PackedStringArray = []
	for v: Villager in list:
		out.append(v.name)
	return out


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
