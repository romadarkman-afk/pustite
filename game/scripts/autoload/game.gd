extends Node
## Сессия партии: правила (Match), боты (Director), таймер фазы, очередь реплик.
## Про экраны не знает ничего. Наружу — только сигналы. Внутрь — только вызовы методов.

signal phase_entered(phase: Match.Phase)
signal chat_line(line: ChatLine)
signal clock_ticked(seconds_left: int)
signal clock_expired(phase: Match.Phase)
signal vote_resolved(tally: Dictionary, exiled: Villager)
signal guest_answered(admitted: bool)
signal marks_changed      ## подозрения, улики или уговоры поменялись — пора обновить поле
signal job_started(vid: int, ji: int)                              ## житель пошёл делать дело
signal job_finished(vid: int, ji: int, counted: bool, real: bool)  ## дело закончено; counted — запасы выросли
signal supplies_changed                                            ## запасы дня изменились
signal player_job_changed                                          ## игрок начал или бросил дело
signal run_changed                                                 ## колокол: начался бег или игрок сменил дом
signal sabotaged(vid: int, ji: int)                                ## у дела испортили сделанное
signal box_appeared(ji: int)                                       ## на площади появился ящик
signal box_opened(vid: int, res: Dictionary)                       ## ящик открыт, res — находка (Match.open_box)

var m: Match
var director: Director
var host_pleas: Dictionary[int, String] = {}
var clock: PhaseClock
var screen_kept_on: bool = false
var _feed_gen: int = 0

## Дела дня. Время дня идёт вместе с часами фазы: пауза — стоят и дела.
var tasks: Array[Director.JobTask] = []
var day_t: float = 0.0
var player_job: int = -1
var player_job_left: float = 0.0
var player_sab: bool = false       ## игрок-упырь не работает, а портит
var box_at: float = -1.0           ## на какой секунде дня появится ящик; -1 — сегодня его нет
var meeting_check_at: float = -1.0 ## на этой секунде дня боты решают, бить ли в колокол
var player_tunnel: bool = false    ## игрок решил лезть в туннель после отказа у двери

## Бег до дома по колоколу. Время бега идёт вместе с часами: пауза — стоят и бегущие.
var run_on: bool = false
var run_t: float = 0.0
var run_house: int = -1                         ## куда бежит игрок; -1 — ещё не выбрал
var run_choices: Dictionary[int, int] = {}      ## куда бегут боты
var run_react: Dictionary[int, float] = {}      ## когда бот сорвался с места
var run_arrive: Dictionary[int, float] = {}     ## когда житель у двери (игрок — id 0)
## Игрок бежит чуть быстрее ботов: он с фонарём и знает, куда бежит.
const PLAYER_RUN := 1.15
## Путь жителя до двери дома в единицах посёлка. Nav подставляет настоящий путь по полю.
var run_distance: Callable = func(_vid: int, _house: int) -> float: return 200.0


func _ready() -> void:
	clock = PhaseClock.new()
	add_child(clock)
	clock.ticked.connect(func(s: int) -> void: clock_ticked.emit(s))
	clock.finished.connect(func() -> void:
		if m != null:
			if m.phase == Match.Phase.NIGHT and run_on:
				_run_deadline()
				return
			clock_expired.emit(m.phase))


func active() -> bool:
	return m != null and m.phase != Match.Phase.OVER and m.phase != Match.Phase.IDLE


func start(cfg: GameConfig) -> void:
	abandon()
	m = Match.new()
	director = Director.new()
	m.start(cfg)
	director.attach(m)
	_keep_screen(true)
	m.phase_changed.connect(_on_phase)
	m.chat_posted.connect(func(l: ChatLine) -> void: chat_line.emit(l))
	_on_phase(m.phase)
	marks_changed.emit()


## Бросить партию: остановить таймер и отменить очередь реплик.
func abandon() -> void:
	_feed_gen += 1
	tasks.clear()
	player_job = -1
	run_on = false
	clock.stop()
	if m != null and m.phase_changed.is_connected(_on_phase):
		m.phase_changed.disconnect(_on_phase)
	m = null
	director = null
	_keep_screen(false)


## Пауза партии по причине: &"background" — игра свёрнута, &"dialog" — открыт вопрос.
## Таймер и реплики ботов стоят, пока есть хоть одна причина.
func hold(reason: StringName) -> void:
	clock.hold(reason)


func release(reason: StringName) -> void:
	var was := held()
	clock.release(reason)
	# бег по колоколу стоял — пусть поле догонит: боты срываются с этой секунды
	if was and not held() and run_on:
		run_changed.emit()


func held() -> bool:
	return clock.held()


func held_by(reason: StringName) -> bool:
	return clock.held_by(reason)


## Во время партии экран не гаснет, в меню и на итоге — гаснет как обычно.
func _keep_screen(on: bool) -> void:
	screen_kept_on = on
	DisplayServer.screen_set_keep_on(on)


# =============================================================
# Дела по посёлку
# =============================================================
func _process(delta: float) -> void:
	if m == null or held():
		return
	if m.phase == Match.Phase.NIGHT and run_on:
		_run_step(minf(delta, PhaseClock.MAX_STEP))
		return
	if m.phase != Match.Phase.DAY:
		return
	var d := minf(delta, PhaseClock.MAX_STEP)
	day_t += d
	for t: Director.JobTask in tasks:
		if not t.started and day_t >= t.start:
			var v := m.get_villager(t.vid)
			if v == null or not v.alive:
				t.started = true
				t.done = true
				continue
			t.started = true
			job_started.emit(t.vid, t.job)
		elif t.started and not t.done and day_t >= t.start + Director.WORK_SEC:
			t.done = true
			_finish_job(t.vid, t.job, t.real, t.sabotage)
	if box_at >= 0.0 and day_t >= box_at:
		box_at = -1.0
		_show_box()
	if meeting_check_at >= 0.0 and day_t >= meeting_check_at:
		meeting_check_at = -1.0
		var caller := director.meeting_caller()
		if caller != null:
			m.post(director.meeting_line(caller))
			call_meeting(caller.id)
			return
	if player_job >= 0:
		if not (m.can_sabotage(player_job) if player_sab else m.job_available(player_job)):
			var lost := player_job
			player_job = -1
			player_sab = false
			player_job_changed.emit()
			job_finished.emit(0, lost, false, true)
			return
		player_job_left -= d
		if player_job_left <= 0.0:
			var ji := player_job
			var sab := player_sab
			player_job = -1
			player_sab = false
			player_job_changed.emit()
			_finish_job(0, ji, not sab, sab)


func _finish_job(vid: int, ji: int, real: bool, sab: bool = false) -> void:
	if m.jobs[ji].kind == JobDef.Kind.BOX:
		_finish_box(vid, ji)
		return
	if sab:
		_finish_sabotage(vid, ji)
		return
	var counted := m.do_job(m.get_villager(vid), ji, real)
	var lines := director.after_job(vid, ji, counted, real)
	Diag.step("дело: %s %s %s" % [m.get_villager(vid).name, m.jobs[ji].id, "засчитано" if counted else "впустую"])
	job_finished.emit(vid, ji, counted, real)
	if counted:
		supplies_changed.emit()
	for l: ChatLine in lines:
		m.post(l)
	if not lines.is_empty():
		marks_changed.emit()


func _finish_sabotage(vid: int, ji: int) -> void:
	var spoiled := m.sabotage(ji)
	var lines := director.after_sabotage(vid, ji, spoiled)
	Diag.step("саботаж: %s %s %s" % [m.get_villager(vid).name, m.jobs[ji].id, "испорчено" if spoiled else "нечего портить"])
	if spoiled:
		sabotaged.emit(vid, ji)
	job_finished.emit(vid, ji, false, false)
	if spoiled:
		supplies_changed.emit()
	_post_all(lines)


# =============================================================
# Ящик
# =============================================================
func _show_box() -> void:
	var ji := m.place_box()
	if ji < 0:
		return
	m.post(ChatLine.system("На краю площади стоит ящик. Вчера его не было."))
	box_appeared.emit(ji)
	# к ящику идёт свободный бот; игрок может успеть раньше
	var free: Array[Villager] = []
	for b: Villager in m.alive_bots():
		if busy_job(b.id) < 0:
			free.append(b)
	if free.is_empty():
		return
	var t := Director.JobTask.new()
	t.vid = free[director.rng.randi_range(0, free.size() - 1)].id
	t.job = ji
	t.start = day_t + director.rng.randf_range(3.0, 7.0)
	t.real = true
	tasks.append(t)


func _finish_box(vid: int, ji: int) -> void:
	var who := m.get_villager(vid)
	var res := m.open_box(who)
	job_finished.emit(vid, ji, false, true)
	if res.is_empty():
		return
	Diag.step("ящик: открыл %s" % who.name)
	box_opened.emit(vid, res)
	if int(res.loot) == Match.Loot.OIL or int(res.loot) == Match.Loot.CHALK:
		supplies_changed.emit()
	if who.is_player:
		m.post(ChatLine.system(box_text(res)))
	_post_all(director.after_box(vid, res))


## Что нашёл игрок — словами. Записку видит только он.
func box_text(res: Dictionary) -> String:
	match int(res.get("loot", 0)):
		Match.Loot.NOTE:
			return "В ящике записка: «%s или %s». Один из них упырь. Записку видишь только ты." % [Ru.nom(res.a), Ru.nom(res.b)]
		Match.Loot.OIL:
			return "В ящике масло для фонарей: запасы +%d." % Match.BOX_OIL
		Match.Loot.CHALK:
			return "В ящике мел: оберег у «%s» подновлён." % Ru.house_of(m.house_name(int(res.get("house", 0))))
	return "Ящик пуст."


func _post_all(lines: Array[ChatLine]) -> void:
	for l: ChatLine in lines:
		m.post(l)
	if not lines.is_empty():
		marks_changed.emit()


## Игрок встал к делу. false — дело уже сделано или сейчас не день.
## sab — игрок-упырь портит сделанное (можно только там, где сегодня уже работали).
func start_player_job(ji: int, sab: bool = false) -> bool:
	if m == null or m.phase != Match.Phase.DAY or not m.player().alive:
		return false
	if sab and (not m.player().is_upyr or not m.can_sabotage(ji)):
		return false
	if not sab and not m.job_available(ji):
		return false
	player_job = ji
	player_sab = sab
	player_job_left = m.jobs[ji].work_sec
	player_job_changed.emit()
	return true


func cancel_player_job() -> void:
	if player_job >= 0:
		player_job = -1
		player_sab = false
		player_job_changed.emit()


## Сколько сделано, 0..1. -1 — игрок сейчас ничего не делает.
func player_job_progress() -> float:
	if player_job < 0:
		return -1.0
	return clampf(1.0 - player_job_left / m.jobs[player_job].work_sec, 0.0, 1.0)


## Работает ли сейчас житель над делом — и над каким. -1 — нет.
func busy_job(vid: int) -> int:
	if vid == 0:
		return player_job
	for t: Director.JobTask in tasks:
		if t.vid == vid and t.started and not t.done:
			return t.job
	return -1


# =============================================================
# Фазы
# =============================================================
func _on_phase(p: Match.Phase) -> void:
	clock.stop()
	if p != Match.Phase.DAY:
		tasks.clear()
		if player_job >= 0:
			player_job = -1
			player_job_changed.emit()
	_feed_gen += 1
	Diag.step("фаза: %s" % Match.Phase.keys()[p])
	match p:
		Match.Phase.DAY:
			director.plan_day()
			tasks = director.plan_jobs(m.config.day_seconds)
			day_t = 0.0
			player_job = -1
			player_sab = false
			box_at = m.config.day_seconds * director.rng.randf_range(0.2, 0.4) if m.box_today else -1.0
			meeting_check_at = m.config.day_seconds * 0.5
			Diag.step("день: боты спланировали")
			phase_entered.emit(p)
			Diag.step("день: экран показан")
			clock.start(m.config.day_seconds)
			var lines := director.opening_lines()
			Diag.step("день: реплик в очереди %d" % lines.size())
			_feed(lines)
		Match.Phase.NIGHT:
			run_on = false
			if m.player().alive:
				_start_run()
			phase_entered.emit(p)
			if run_on:
				clock.start(m.run_seconds())
				run_changed.emit()
		Match.Phase.DOOR:
			run_on = false
			_prepare_door()
		Match.Phase.OVER:
			_keep_screen(false)
			var you := m.player()
			Save.record_result((m.winner == Match.Team.PEOPLE) != you.is_upyr, you.is_upyr)
			phase_entered.emit(p)
		_:
			phase_entered.emit(p)


func door_role() -> Match.DoorRole:
	return m.player_door_role()


func door_seat() -> Match.Seat:
	return m.player_seat()


## Все двери, где решают боты, решаются сразу. Дверь игрока ждёт его.
func _prepare_door() -> void:
	var role := m.player_door_role()
	var mine := m.player_seat()
	for s: Match.Seat in m.seats:
		if s == mine and (role == Match.DoorRole.HOST or role == Match.DoorRole.GUEST):
			continue
		if not s.host.is_player:
			m.admit(s, director.host_decide(s))
		elif s.knockers().is_empty():
			var none: Array[int] = []
			m.admit(s, none)

	if role == Match.DoorRole.DEAD:
		_finish_night()
		return
	host_pleas.clear()
	if role == Match.DoorRole.HOST:
		for g: Villager in mine.knockers():
			host_pleas[g.id] = director.mimic_plea(g) if g == mine.mimic else director.plea_for(g)
	phase_entered.emit(Match.Phase.DOOR)
	if role != Match.DoorRole.ALONE:
		clock.start(m.config.door_seconds)


func _finish_night() -> void:
	clock.stop()
	m.tunnel_pass(player_tunnel and m.player().alive)
	player_tunnel = false
	director.after_door(m.seats)
	var r := m.resolve_night()
	director.read_report(r)
	marks_changed.emit()


# =============================================================
# Действия игрока
# =============================================================
func proceed() -> void:
	match m.phase:
		Match.Phase.PROLOGUE: m.begin_day()
		Match.Phase.VOTE: m.after_vote()
		Match.Phase.DOOR: _finish_night()
		Match.Phase.MORNING: m.end_morning()


func say(text: String) -> void:
	_player_says(text, IntentParser.parse(text, m))


func accuse(vid: int) -> void:
	var t := m.get_villager(vid)
	_player_says("Я думаю, это %s." % t.name, _intent(IntentParser.Kind.ACCUSE, t))


func invite(vid: int, house: int) -> void:
	var t := m.get_villager(vid)
	var it := _intent(IntentParser.Kind.INVITE, t)
	it.house = house
	_player_says("%s, пойдём вместе в «%s»?" % [t.name, m.house_name(house)], it)


func ask(vid: int) -> void:
	var t := m.get_villager(vid)
	_player_says("%s, ты где сегодня ночуешь?" % t.name, _intent(IntentParser.Kind.ASK, t))


func defend() -> void:
	var lines: PackedStringArray = ["Я не упырь. Клянусь.", "Я свой. Проверьте меня ночью.", "Не я. Ищите дальше."]
	_player_says(lines[randi() % lines.size()], _intent(IntentParser.Kind.DEFEND, null))


func end_day() -> void:
	if m.phase == Match.Phase.DAY:
		clock.stop()
		m.end_day()


## Голоса ботов считаются один раз, затем голос игрока.
func vote(target_id: int) -> void:
	var tally: Dictionary[int, int] = {}
	var bv := director.votes()
	for voter: int in bv:
		tally[bv[voter]] = tally.get(bv[voter], 0) + m.vote_weight(voter)
	if target_id >= 0 and m.player().alive:
		tally[target_id] = tally.get(target_id, 0) + m.vote_weight(0)
	var out := m.apply_vote(tally)
	vote_resolved.emit(tally, out)


# =============================================================
# Колокол: бег до дома
# =============================================================
func _start_run() -> void:
	run_on = true
	run_t = 0.0
	run_house = -1
	run_choices = director.night_choices()
	var plan := director.plan_run(run_choices, run_distance)
	run_react.assign(plan.react)
	run_arrive.assign(plan.arrive)
	Diag.step("колокол: боты бегут, последний у двери через %.1f с" % _bots_done_at())


func _bots_done_at() -> float:
	var t := 0.0
	for vid: int in run_arrive:
		if vid != 0:
			t = maxf(t, run_arrive[vid])
	return t


func _run_step(d: float) -> void:
	run_t += d
	# все у дверей — ночь начинается, не дожидаясь конца звона
	if run_house >= 0 and run_t >= run_arrive.get(0, INF) and run_t >= _bots_done_at():
		_finish_run()


## Игрок побежал к дому (или передумал на бегу). Время до двери — от того места, где он сейчас.
func run_to_house(house: int) -> void:
	if not run_on or m == null or m.phase != Match.Phase.NIGHT or house < 0 or house >= m.houses.size():
		return
	run_house = house
	run_arrive[0] = run_t + float(run_distance.call(0, house)) / (Director.RUN_SPEED * PLAYER_RUN)
	run_changed.emit()


## Колокол отзвонил. Кто не выбрал дом — бежит туда, куда собирался днём,
## а если не собирался — к ближайшему, и добегает последним.
func _run_deadline() -> void:
	if run_house < 0:
		var h := m.player().announced_house
		if h < 0 or h >= m.houses.size():
			var best := INF
			for i in range(m.houses.size()):
				var dd := float(run_distance.call(0, i))
				if dd < best:
					best = dd
					h = i
		run_house = h
		run_arrive[0] = 1.0e5
		run_changed.emit()
	_finish_run()


func _finish_run() -> void:
	if run_on:
		choose_house(run_house)


## Сесть по домам сейчас же. Во время бега — по тем же выборам и временам, что видны на поле.
## Без бега (мёртвый игрок, самотесты правил) — как раньше: выбор ботов и случайный порядок.
# =============================================================
# Роли, сбор, туннель — действия игрока
# =============================================================
## Игрок-старожил смотрит рисунки. Ответ видит только он. -1 — нельзя.
func elder_check(vid: int) -> int:
	var t := m.get_villager(vid)
	var res := m.elder_check(m.player(), t)
	if res >= 0:
		m.post(ChatLine.system("Рисунки старожила: %s — %s. Это знаешь только ты." % [t.name, "упырь" if res == 1 else "человек"]))
		marks_changed.emit()
	return res


## Игрок-знахарь берёт травы на эту ночь.
func heal() -> bool:
	return m.heal_tonight(m.player())


## Ударить в колокол днём: экстренный сбор, сразу голосование.
func call_meeting(vid: int) -> bool:
	var v := m.get_villager(vid)
	if not m.can_meeting(v):
		return false
	clock.stop()
	if v.is_player:
		m.post(ChatLine.system("Ты бьёшь в колокол. Экстренный сбор!"))
	else:
		m.post(ChatLine.system("%s бьёт в колокол. Экстренный сбор!" % v.name))
	return m.call_meeting(v)


## Игрока не пустили — он лезет туннелем на другой конец (если там есть место).
func go_tunnel() -> void:
	if m.phase != Match.Phase.DOOR:
		return
	player_tunnel = true
	_finish_night()


func choose_house(house: int) -> void:
	var choices: Dictionary[int, int] = {}
	var arrival: Dictionary[int, float] = {}
	if run_on:
		choices = run_choices.duplicate()
		arrival = run_arrive.duplicate()
		if house >= 0 and house != run_house:
			arrival[0] = run_t + float(run_distance.call(0, house)) / (Director.RUN_SPEED * PLAYER_RUN)
	else:
		choices = director.night_choices()
	run_on = false
	clock.stop()
	if m.player().alive:
		choices[0] = house
	else:
		arrival.erase(0)
	m.seat_night(choices, arrival)


func admit(ids: Array[int]) -> void:
	m.admit(m.player_seat(), ids)
	_finish_night()


func plea(plea_id: String) -> void:
	clock.stop()
	var seat := m.player_seat()
	var ids := director.host_decide(seat, plea_id)
	m.admit(seat, ids)
	guest_answered.emit(ids.has(m.player().id))


# =============================================================
func _intent(kind: IntentParser.Kind, target: Villager) -> IntentParser.Result:
	var r := IntentParser.Result.new()
	r.kind = kind
	r.target = target
	return r


func _player_says(text: String, it: IntentParser.Result) -> void:
	m.post(ChatLine.say(m.player(), text))
	var replies := director.react(it)
	marks_changed.emit()
	_feed(replies)


## Реплики ботов приходят с человеческими паузами. Смена фазы отменяет очередь.
func _feed(lines: Array[ChatLine]) -> void:
	var gen := _feed_gen
	var prev_len := -1
	for line: ChatLine in lines:
		# первая реплика — когда жители добежали на места; дальше пауза по длине прошлой: успеть прочитать
		var pause := randf_range(1.3, 1.8) if prev_len < 0 else (0.9 + 0.032 * prev_len) * randf_range(0.85, 1.15)
		await Juice.wait(pause)
		prev_len = line.text.length()
		while held() and gen == _feed_gen:
			await get_tree().process_frame
		if gen != _feed_gen or m == null or m.phase != Match.Phase.DAY:
			return
		Diag.step("реплика: %s" % line.speaker.name)
		m.post(line)
