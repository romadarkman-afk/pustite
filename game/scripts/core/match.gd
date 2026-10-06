class_name Match
extends RefCounted
## Правила игры и машина состояний партии.
## Чистая логика: не знает про экраны, не трогает SceneTree.
## Наружу общается только сигналами. Переходы фаз решает только Match.

enum Phase { IDLE, PROLOGUE, DAY, VOTE, NIGHT, DOOR, MORNING, OVER }
enum Team { NONE, PEOPLE, UPYRI }
enum DoorRole { DEAD, HOST, GUEST, ALONE }

signal phase_changed(phase: Phase)
signal chat_posted(line: ChatLine)

const NAMES: PackedStringArray = [
	"Марина", "Тимур", "Лида", "Костя", "Женя", "Артур",
	"Захар", "Рита", "Гриша", "Нина", "Вадим", "Полина",
]
const HOUSES: PackedStringArray = ["Дом у реки", "Сарай", "Церковь", "Погреб", "Гараж"]


## Кто к какому убежищу пришёл ночью. Первый добежавший — хозяин двери.
class Seat:
	var house: int
	var host: Villager
	var queue: Array[Villager] = []
	var admitted: Array[Villager] = []
	var decided: bool = false

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
	return DoorRole.HOST if not s.queue.is_empty() else DoorRole.ALONE


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
		villagers.append(Villager.new(i + 1, String(pool[i]), false))

	var order: Array = range(villagers.size())
	_shuffle(order)
	for k in range(config.monsters):
		villagers[int(order[k])].is_upyr = true

	houses = HOUSES.slice(0, config.shelters)
	day = 1
	winner = Team.NONE
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
	_set_phase(Phase.DAY)
	post(ChatLine.system("Светает. Все выходят на площадь." if day == 1
		else "День %d. Живых осталось %d." % [day, alive().size()]))


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
		_log("День %d: посёлок изгнал %s." % [day, last_exiled.name])
	return last_exiled


func after_vote() -> void:
	assert(phase == Phase.VOTE)
	if _settle_winner():
		_set_phase(Phase.OVER)
	else:
		_set_phase(Phase.NIGHT)


## choices: id -> индекс убежища. Порядок прихода случаен — хозяином двери
## может оказаться кто угодно, включая игрока.
func seat_night(choices: Dictionary[int, int]) -> void:
	assert(phase == Phase.NIGHT)
	seats.clear()
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
		var s := Seat.new()
		s.house = i
		s.host = arrivals[0]
		for k in range(1, arrivals.size()):
			s.queue.append(arrivals[k])
		seats.append(s)
	_set_phase(Phase.DOOR)


func admit(seat: Seat, ids: Array[int]) -> void:
	assert(phase == Phase.DOOR)
	seat.admitted.clear()
	for v: Villager in seat.queue:
		if ids.has(v.id) and seat.admitted.size() < config.capacity - 1:
			seat.admitted.append(v)
	seat.decided = true


func resolve_night() -> NightReport:
	assert(phase == Phase.DOOR)
	var r := NightReport.new()
	var p_out := config.outside_death_chance(day)

	var was_fed: Dictionary[int, bool] = {}
	for v: Villager in villagers:
		if v.fed:
			was_fed[v.id] = true
		v.fed = false

	# 1. Кого не пустили — улица
	for s: Seat in seats:
		for v: Villager in s.turned_away():
			v.night_house = -1
			if v.is_upyr:
				r.add(NightReport.Kind.SURVIVED_STREET, v, s.house)
				_log("Ночь %d: %s не пустили в «%s», но он(а) дожил(а) до утра." % [day, v.name, house_name(s.house)])
			elif rng.randf() < p_out:
				v.alive = false
				r.add(NightReport.Kind.KILLED_STREET, v, s.house)
				_log("Ночь %d: %s не пустили в «%s». Утром нашли на улице." % [day, v.name, house_name(s.house)])
			else:
				r.add(NightReport.Kind.SURVIVED_STREET, v, s.house)
				_log("Ночь %d: %s ночевал(а) на улице и выжил(а)." % [day, v.name])

	# 2. Что было за дверьми
	for s: Seat in seats:
		var inside := s.inside()
		if inside.size() == 1:
			var lone: Villager = inside[0]
			if lone.is_upyr:
				r.add(NightReport.Kind.SURVIVED_ALONE, lone, s.house)
			elif rng.randf() < p_out:
				lone.alive = false
				r.add(NightReport.Kind.KILLED_ALONE, lone, s.house)
				_log("Ночь %d: %s остался(ась) один(на) в «%s». Оберег погас." % [day, lone.name, house_name(s.house)])
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
			victim.alive = false
			killer.fed = true
			var others: Array[Villager] = []
			for v: Villager in inside:
				if v != victim:
					others.append(v)
			r.add(NightReport.Kind.KILLED_INSIDE, victim, s.house, others)
			_log("Ночь %d: %s погиб(ла) в «%s». Рядом был(и): %s." % [
				day, victim.name, house_name(s.house), ", ".join(_names(others))])
		else:
			# все люди — или упырь сытый. Снаружи не отличить, и в этом весь смысл.
			r.add(NightReport.Kind.CLEAN_ROOM, s.host, s.house, inside.duplicate())
			_log("Ночь %d: в «%s» ночевали %s — все целы." % [day, house_name(s.house), " и ".join(_names(inside))])

	# 3. Сказал одно — ночевал в другом месте
	for v: Villager in villagers:
		if v.announced_house >= 0 and v.night_house >= 0 and v.night_house != v.announced_house:
			var e := r.add(NightReport.Kind.LIAR, v, v.night_house)
			e.said_house = v.announced_house
			_log("Ночь %d: %s говорил(а) про «%s», а ночевал(а) в «%s»." % [
				day, v.name, house_name(v.announced_house), house_name(v.night_house)])

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
func _settle_winner() -> bool:
	if humans_alive() == 0:
		winner = Team.UPYRI
	elif upyri_alive() == 0:
		winner = Team.PEOPLE
	return winner != Team.NONE


func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)


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
