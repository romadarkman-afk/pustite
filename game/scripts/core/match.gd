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
const FEMALE: PackedStringArray = ["Марина", "Лида", "Женя", "Рита", "Нина", "Полина"]
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
	jobs = base_jobs.duplicate()
	for h in range(houses.size()):
		if talisman[h] < TALISMAN_MAX:
			jobs.append(_talisman_job(h))
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
	if not real or job_left[ji] <= 0:
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
	return maxf(0.05, config.outside_death_chance(day) - SUPPLY_BONUS * supplies())


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
		_log("День %d: посёлок изгнал %s." % [day, "вас" if last_exiled.is_player else Ru.accusative(last_exiled.name)])
	return last_exiled


func after_vote() -> void:
	assert(phase == Phase.VOTE)
	if _settle_winner():
		_set_phase(Phase.OVER)
	else:
		_set_phase(Phase.NIGHT)


## choices: id -> индекс убежища. Порядок прихода случаен — хозяином двери
## может оказаться кто угодно, включая игрока.
## Рассадка на ночь. arrival — когда кто добежал до двери (секунды от колокола):
## первый добежавший внутри и решает, остальные в очереди в порядке прибытия.
## Кого нет в arrival, тот добегает после всех известных, между собой — в случайном порядке.
func seat_night(choices: Dictionary[int, int], arrival: Dictionary[int, float] = {}) -> void:
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
	var p_out := outside_death_chance()
	if supply_total > 0:
		_log("Ночь %d: запасов набрали на %d%%." % [day, roundi(100.0 * supplies())])

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
				_log("Ночь %d: %s не пустили в «%s», но %s до утра." % [day, Ru.acc(v), house_name(s.house), Ru.g(v, "он дожил", "она дожила", "вы дожили")])
			elif rng.randf() < p_out:
				v.alive = false
				r.add(NightReport.Kind.KILLED_STREET, v, s.house)
				_log("Ночь %d: %s не пустили в «%s». %s" % [day, Ru.acc(v), house_name(s.house), Ru.g(v, "Утром его нашли на улице.", "Утром её нашли на улице.", "Вы погибли на улице.")])
			else:
				r.add(NightReport.Kind.SURVIVED_STREET, v, s.house)
				_log("Ночь %d: %s %s на улице и %s." % [day, Ru.nom(v), Ru.g(v, "ночевал", "ночевала", "ночевали"), Ru.g(v, "выжил", "выжила", "выжили")])

	# 2. Что было за дверьми
	for s: Seat in seats:
		var inside := s.inside()
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
			victim.alive = false
			killer.fed = true
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
		if talisman[h] > 0 and rng.randf() < TALISMAN_DECAY:
			talisman[h] -= 1
			r.add(NightReport.Kind.TALISMAN_WORN, null, h)
			_log("Утром: оберег у «%s» %s." % [Ru.house_of(house_name(h)), "треснул" if talisman[h] == 1 else "раскололся"])

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
