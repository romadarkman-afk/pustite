Warning: truncated output (original token count: 9210)
Total output lines: 956

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
var daily: String = ""             ## дата испытания дня, если идёт оно; "" — обычная партия
var new_items: PackedStringArray = []   ## что открылось за эту партию: «lantern:copper»
var opening_done := false        ## глава «Стук»: сцена у реки уже показана (TASK-011)
var first_contact := false       ## первый личный разговор в партии
var board_done := false          ## сцена «Имя на доске» в этой партии уже была (TASK-019)
var scenes_done: Dictionary = {}  ## сюжетные сцены акта II, уже показанные в этой партии
var inspection_bonus := 0       ## награда за знакомство: один осмотр у двери
var host_pleas: Dictionary[int, String] = {}
var clock: PhaseClock
var screen_kept_on: bool = false
var _feed_gen: int = 0
var _restoring_checkpoint := false
var _preserve_checkpoint_on_abandon := false

## Дела дня. Время дня идёт вместе с часами фазы: пауза — стоят и дела.
var tasks: Array[Director.JobTask] = []
var chapter: Dictionary = {}        ## глава кампании (Campaign.chapter) или {} — обычная партия
var chapter_result: Dictionary = {}
var progress_result: Dictionary = {} ## опыт и достижения этой партии (Progress.record) ## итог главы: пройдена, звёзды, цели
var dilemma: Dictionary = {}       ## дилемма у двери этой ночи (Match.door_dilemma) — экран двери её показывает
var skipping := false              ## идёт skip_to_end: экраны фаз не показываются
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


## daily — дата испытания дня ("" — обычная партия): правило и зерно берутся по ней.
func start(cfg: GameConfig, daily_date: String = "", chapter_data: Dictionary = {}, varied_solo_map: bool = false) -> void:
	abandon()
	chapter = chapter_data
	chapter_result = {}
	progress_result = {}
	Dread.reset()
	dilemma = {}
	first_contact = fals…6210 tokens truncated…id: int in run_arrive:
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
		m.post(ChatLine.system(L.t("sys.elder_upyr" if res == 1 else "sys.elder_human", {"who": t})))
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
		m.post(ChatLine.system(L.t("sys.bell_you")))
	else:
		m.post(ChatLine.system(L.t("sys.bell", {"who": v})))
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
	if m == null or m.phase != Match.Phase.DOOR:
		return
	var seat := m.player_seat()
	if seat != null and seat.host.is_player:
		for v: Villager in seat.knockers():
			if v == seat.mimic or v.anchor_id < 0:
				continue
			v.relationship = Save.change_anchor_bond(v.anchor_id, 1 if ids.has(v.id) else -1)
	m.admit(seat, ids)
	_finish_night()


func inspect_visitor(vid: int) -> StringName:
	if m == null or m.phase != Match.Phase.DOOR:
		return &""
	return m.inspect_visitor(m.player_seat(), vid, 2 + inspection_bonus)


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
	var line := ChatLine.say(m.player(), text)
	if it.kind == IntentParser.Kind.ACCUSE:
		line.about = it.target
	m.post(line)
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
		Diag.step("реплика: %s" % (line.speaker.name if line.speaker != null else "хозяин места"))   # строки мельника и письма — без жителя
		m.post(line)

