class_name App
extends Control
## Точка сборки. Владеет Match, Director, экранами и фоном.
## Match → App: сигналы phase_changed / chat_posted.
## Screen → App: сигнал intent. App → Screen: вызовы методов.
## Никаких get_parent().get_node(): зависимости передаются явно.

const SETTINGS_PATH := "user://settings.cfg"
const BALANCE_PATH := "user://balance.tres"
const DEFAULT_BALANCE := "res://config/balance_7.tres"

var game: Match
var director: Director
var host: ScreenHost
var atmos: Atmosphere
var frame: SafeFrame
var clock: PhaseClock
var cfg: GameConfig
var _feed_gen: int = 0
var _exit_armed := false
var _toast: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--sim"):
		_cli_sim()
		return
	theme = ThemeFactory.build()
	_load_settings()
	_build_layers()
	if args.has("--flow"):
		Juice.instant = true
		SelfTest.flow(self)
		return
	open_menu()


func _build_layers() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	atmos = Atmosphere.new()
	add_child(atmos)
	frame = SafeFrame.new()
	add_child(frame)
	host = ScreenHost.new()
	frame.add_child(host)
	clock = PhaseClock.new()
	add_child(clock)
	clock.ticked.connect(func(s: int) -> void:
		if host.current != null:
			host.current.set_clock(s))
	clock.finished.connect(_on_clock_finished)

	_toast = W.label("", &"Small")
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position.y -= 160
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


# =============================================================
# Навигация вне партии
# =============================================================
func open_menu() -> void:
	clock.stop()
	_show(MenuScreen.new())


func open_settings() -> void:
	clock.stop()
	var s := SettingsScreen.new()
	s.cfg = cfg.duplicate() as GameConfig
	s.haptics = Juice.haptics_enabled
	_show(s)


func start_match() -> void:
	_feed_gen += 1
	game = Match.new()
	director = Director.new()
	game.start(cfg)
	director.attach(game)
	game.phase_changed.connect(_on_phase)
	game.chat_posted.connect(_on_chat)
	_on_phase(game.phase)


func _show(s: Screen) -> void:
	s.setup(game, director)
	s.intent.connect(_on_intent.bind(s))
	host.show_screen(s)
	if s.door_open() >= 0.0:
		atmos.door(s.door_open())
	else:
		var md := s.mood()
		atmos.mood(md.x, md.y)
	if s is DoorScreen:
		var d := s as DoorScreen
		d.knock_fx.connect(atmos.knock)
		d.open_fx.connect(func(a: float) -> void: atmos.door(a, 0.5))
	if s is MorningScreen:
		(s as MorningScreen).death_fx.connect(atmos.blood_flash)


# =============================================================
# Match → App
# =============================================================
func _on_phase(phase: Match.Phase) -> void:
	clock.stop()
	_feed_gen += 1
	match phase:
		Match.Phase.PROLOGUE:
			_show(PrologueScreen.new())
		Match.Phase.DAY:
			director.plan_day()
			_show(DayScreen.new())
			clock.start(game.config.day_seconds)
			_feed(director.opening_lines())
		Match.Phase.VOTE:
			_show(VoteScreen.new())
		Match.Phase.NIGHT:
			_show(NightScreen.new())
		Match.Phase.DOOR:
			_enter_door()
		Match.Phase.MORNING:
			_show(MorningScreen.new())
		Match.Phase.OVER:
			_show(EndScreen.new())


func _on_chat(line: ChatLine) -> void:
	if host.current is DayScreen:
		(host.current as DayScreen).append_line(line)


func _on_clock_finished() -> void:
	var s := host.current
	if s == null:
		return
	if s is DayScreen and game.phase == Match.Phase.DAY:
		s.lock()
		game.end_day()
	elif s is DoorScreen:
		(s as DoorScreen).timeout()


## Реплики ботов приходят с человеческими паузами. Смена фазы отменяет очередь.
func _feed(lines: Array[ChatLine]) -> void:
	var gen := _feed_gen
	for line: ChatLine in lines:
		await Juice.wait(randf_range(0.7, 1.5))
		if gen != _feed_gen or game == null or game.phase != Match.Phase.DAY:
			return
		game.post(line)


# =============================================================
# Ночь у двери
# =============================================================
func _enter_door() -> void:
	var role := game.player_door_role()
	var mine := game.player_seat()
	for s: Match.Seat in game.seats:
		if s == mine and (role == Match.DoorRole.HOST or role == Match.DoorRole.GUEST):
			continue
		if not s.host.is_player:
			game.admit(s, director.host_decide(s))
		elif s.queue.is_empty():
			var none: Array[int] = []
			game.admit(s, none)

	if role == Match.DoorRole.DEAD:
		_finish_night()
		return
	var d := DoorScreen.new()
	d.role = role
	d.seat = mine
	if role == Match.DoorRole.HOST:
		for g: Villager in mine.queue:
			d.pleas[g.id] = director.plea_for(g)
	_show(d)
	if role != Match.DoorRole.ALONE:
		clock.start(game.config.door_seconds)


func _finish_night() -> void:
	clock.stop()
	director.after_door(game.seats)
	var r := game.resolve_night()
	director.read_report(r)


# =============================================================
# Screen → App
# =============================================================
func _on_intent(action: StringName, data: Dictionary, sender: Screen) -> void:
	if sender != host.current:
		return
	match action:
		Intent.START:
			if data.has("cfg"):
				_apply_settings(data.cfg, data.haptics)
			start_match()
		Intent.OPEN_SETTINGS:
			open_settings()
		Intent.BACK:
			if data.has("cfg"):
				_apply_settings(data.cfg, data.haptics)
			open_menu()
		Intent.AGAIN:
			start_match()

		Intent.CONTINUE:
			match game.phase:
				Match.Phase.PROLOGUE: game.begin_day()
				Match.Phase.VOTE: game.after_vote()
				Match.Phase.DOOR: _finish_night()
				Match.Phase.MORNING: game.end_morning()

		Intent.SAY:
			_player_says(data.text, IntentParser.parse(data.text, game))
		Intent.ACCUSE:
			var t := game.get_villager(data.id)
			_player_says("Я думаю, это %s." % t.name, _intent(IntentParser.Kind.ACCUSE, t))
		Intent.INVITE:
			var t := game.get_villager(data.id)
			var it := _intent(IntentParser.Kind.INVITE, t)
			it.house = data.house
			_player_says("%s, пойдём вместе в «%s»?" % [t.name, game.house_name(data.house)], it)
		Intent.ASK:
			var t := game.get_villager(data.id)
			_player_says("%s, ты где сегодня ночуешь?" % t.name, _intent(IntentParser.Kind.ASK, t))
		Intent.DEFEND:
			_player_says(["Я не упырь. Клянусь.", "Я свой. Проверьте меня ночью.", "Не я. Ищите дальше."].pick_random(),
				_intent(IntentParser.Kind.DEFEND, null))
		Intent.END_DAY:
			game.end_day()

		Intent.VOTE:
			var tally: Dictionary[int, int] = {}
			var bv := director.votes()
			for voter: int in bv:
				tally[bv[voter]] = tally.get(bv[voter], 0) + 1
			if int(data.id) >= 0 and game.player().alive:
				tally[int(data.id)] = tally.get(int(data.id), 0) + 1
			var out := game.apply_vote(tally)
			(sender as VoteScreen).show_result(tally, out)

		Intent.CHOOSE_HOUSE:
			var choices := director.night_choices()
			if game.player().alive:
				choices[0] = int(data.house)
			game.seat_night(choices)

		Intent.ADMIT:
			var ids: Array[int] = []
			ids.assign(data.ids)
			game.admit(game.player_seat(), ids)
			_finish_night()
		Intent.PLEA:
			clock.stop()
			var seat := game.player_seat()
			var ids := director.host_decide(seat, data.plea)
			game.admit(seat, ids)
			(sender as DoorScreen).show_guest_result(ids.has(game.player().id))


func _intent(kind: IntentParser.Kind, target: Villager) -> IntentParser.Result:
	var r := IntentParser.Result.new()
	r.kind = kind
	r.target = target
	return r


func _player_says(text: String, it: IntentParser.Result) -> void:
	game.post(ChatLine.say(game.player(), text))
	_feed(director.react(it))


# =============================================================
# Кнопка «Назад» на Android
# =============================================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _on_back() -> void:
	var s := host.current
	if s != null and s.handle_back():
		return
	if s is MenuScreen:
		if _exit_armed:
			get_tree().quit()
			return
		_exit_armed = true
		_show_toast("Нажмите ещё раз, чтобы выйти")
		await get_tree().create_timer(2.0).timeout
		_exit_armed = false
	elif s is SettingsScreen:
		var ss := s as SettingsScreen
		_apply_settings(ss.cfg, ss.haptics)
		open_menu()
	elif s is EndScreen:
		open_menu()
	elif game != null and game.phase != Match.Phase.OVER:
		var i: int = await ActionSheet.ask(s, "Бросить партию?", PackedStringArray(["Остаться", "Выйти в меню"]))
		if i == 1:
			_feed_gen += 1
			open_menu()


func _show_toast(text: String) -> void:
	_toast.text = text
	var t := Juice.tween()
	t.tween_property(_toast, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.4)
	t.tween_property(_toast, "modulate:a", 0.0, 0.4)


# =============================================================
# Настройки: баланс — ресурс GameConfig, вибрация — ConfigFile
# =============================================================
func _load_settings() -> void:
	if ResourceLoader.exists(BALANCE_PATH):
		var loaded := load(BALANCE_PATH) as GameConfig
		cfg = loaded if loaded != null else (load(DEFAULT_BALANCE) as GameConfig)
	else:
		cfg = load(DEFAULT_BALANCE) as GameConfig
	cfg = cfg.duplicate() as GameConfig
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		Juice.haptics_enabled = bool(cf.get_value("ui", "haptics", true))


func _apply_settings(new_cfg: GameConfig, haptics: bool) -> void:
	cfg = new_cfg.sanitized()
	Juice.haptics_enabled = haptics
	ResourceSaver.save(cfg, BALANCE_PATH)
	var cf := ConfigFile.new()
	cf.set_value("ui", "haptics", haptics)
	cf.save(SETTINGS_PATH)


# =============================================================
func _cli_sim() -> void:
	var c := load(DEFAULT_BALANCE) as GameConfig
	var r := SelfTest.balance(c, 3000)
	print("=== баланс: %d партий ===" % r.runs)
	print("состав: %d жителей, %d упырей, %d убежищ по %d, %d ночи" % [c.players, c.monsters, c.shelters, c.capacity, c.nights])
	print("побед людей: %.1f%%  | средняя партия: %.2f ночи" % [100.0 * r.people_win, r.avg_nights])
	print("игрок хозяином двери: %d раз, гостем у чужой: %d раз" % [r.player_host, r.player_guest])
	var ok: bool = r.people_win > 0.30 and r.people_win < 0.70 and r.player_guest > 0 and r.player_host > 0
	print("ИТОГ: %s" % ("OK" if ok else "БАЛАНС ВНЕ КОРИДОРА 30–70% ИЛИ ИГРОК НЕ ВИДИТ ОДНУ ИЗ РОЛЕЙ У ДВЕРИ"))
	get_tree().quit(0 if ok else 1)
