extends Node
## Сессия партии: правила (Match), боты (Director), таймер фазы, очередь реплик.
## Про экраны не знает ничего. Наружу — только сигналы. Внутрь — только вызовы методов.

signal phase_entered(phase: Match.Phase)
signal chat_line(line: ChatLine)
signal clock_ticked(seconds_left: int)
signal clock_expired(phase: Match.Phase)
signal vote_resolved(tally: Dictionary, exiled: Villager)
signal guest_answered(admitted: bool)

var m: Match
var director: Director
var host_pleas: Dictionary[int, String] = {}
var clock: PhaseClock
var screen_kept_on: bool = false
var _feed_gen: int = 0


func _ready() -> void:
	clock = PhaseClock.new()
	add_child(clock)
	clock.ticked.connect(func(s: int) -> void: clock_ticked.emit(s))
	clock.finished.connect(func() -> void:
		if m != null:
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


## Бросить партию: остановить таймер и отменить очередь реплик.
func abandon() -> void:
	_feed_gen += 1
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
	clock.release(reason)


func held() -> bool:
	return clock.held()


## Во время партии экран не гаснет, в меню и на итоге — гаснет как обычно.
func _keep_screen(on: bool) -> void:
	screen_kept_on = on
	DisplayServer.screen_set_keep_on(on)


# =============================================================
# Фазы
# =============================================================
func _on_phase(p: Match.Phase) -> void:
	clock.stop()
	_feed_gen += 1
	Diag.step("фаза: %s" % Match.Phase.keys()[p])
	match p:
		Match.Phase.DAY:
			director.plan_day()
			Diag.step("день: боты спланировали")
			phase_entered.emit(p)
			Diag.step("день: экран показан")
			clock.start(m.config.day_seconds)
			var lines := director.opening_lines()
			Diag.step("день: реплик в очереди %d" % lines.size())
			_feed(lines)
		Match.Phase.DOOR:
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
		elif s.queue.is_empty():
			var none: Array[int] = []
			m.admit(s, none)

	if role == Match.DoorRole.DEAD:
		_finish_night()
		return
	host_pleas.clear()
	if role == Match.DoorRole.HOST:
		for g: Villager in mine.queue:
			host_pleas[g.id] = director.plea_for(g)
	phase_entered.emit(Match.Phase.DOOR)
	if role != Match.DoorRole.ALONE:
		clock.start(m.config.door_seconds)


func _finish_night() -> void:
	clock.stop()
	director.after_door(m.seats)
	var r := m.resolve_night()
	director.read_report(r)


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
		tally[bv[voter]] = tally.get(bv[voter], 0) + 1
	if target_id >= 0 and m.player().alive:
		tally[target_id] = tally.get(target_id, 0) + 1
	var out := m.apply_vote(tally)
	vote_resolved.emit(tally, out)


func choose_house(house: int) -> void:
	var choices := director.night_choices()
	if m.player().alive:
		choices[0] = house
	m.seat_night(choices)


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
	_feed(director.react(it))


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
