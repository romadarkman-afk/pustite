extends Node
## Экраны, переходы, фон и кнопка «Назад».
## Слушает сигналы Game и строит нужный экран. Намерения игрока с экранов
## передаёт в Game вызовами. Сам правила не трогает.

var layer: CanvasLayer
var ui: Control
var atmos: Atmosphere
var frame: SafeFrame
var host: ScreenHost
var _toast: Label
var _exit_armed := false
var _started := false


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.visible = false
	add_child(layer)

	ui = Control.new()
	ui.theme = ThemeFactory.build()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	atmos = Atmosphere.new()
	ui.add_child(atmos)
	frame = SafeFrame.new()
	ui.add_child(frame)
	host = ScreenHost.new()
	frame.add_child(host)

	_toast = W.label("", &"Small")
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_top = -260
	_toast.offset_bottom = -200

	Game.phase_entered.connect(_on_phase)
	Game.chat_line.connect(_on_chat)
	Game.clock_ticked.connect(func(s: int) -> void:
		if host.current != null:
			host.current.set_clock(s))
	Game.clock_expired.connect(func(_p: Match.Phase) -> void:
		if host.current != null:
			host.current.on_clock_expired())
	Game.vote_resolved.connect(func(tally: Dictionary, exiled: Villager) -> void:
		if host.current is VoteScreen:
			var t: Dictionary[int, int] = {}
			t.assign(tally)
			(host.current as VoteScreen).show_result(t, exiled))
	Game.guest_answered.connect(func(admitted: bool) -> void:
		if host.current is DoorScreen:
			(host.current as DoorScreen).show_guest_result(admitted))


## Вызывается сценой загрузки, когда логотип отыграл.
func start() -> void:
	if _started:
		return
	_started = true
	layer.visible = true
	show_menu()


# =============================================================
# Навигация
# =============================================================
func show_menu() -> void:
	Game.abandon()
	show(MenuScreen.new())


func show_settings() -> void:
	Game.abandon()
	var s := SettingsScreen.new()
	s.cfg = Save.config.duplicate() as GameConfig
	s.haptics = Save.haptics
	show(s)


func start_match() -> void:
	Game.start(Save.config)


func show(s: Screen) -> void:
	s.setup(Game.m, Game.director)
	s.intent.connect(handle_intent.bind(s))
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
# Game → экраны
# =============================================================
func _on_phase(phase: Match.Phase) -> void:
	match phase:
		Match.Phase.PROLOGUE:
			show(PrologueScreen.new())
		Match.Phase.DAY:
			show(DayScreen.new())
		Match.Phase.VOTE:
			show(VoteScreen.new())
		Match.Phase.NIGHT:
			show(NightScreen.new())
		Match.Phase.DOOR:
			var d := DoorScreen.new()
			d.role = Game.door_role()
			d.seat = Game.door_seat()
			d.pleas = Game.host_pleas.duplicate()
			show(d)
		Match.Phase.MORNING:
			show(MorningScreen.new())
		Match.Phase.OVER:
			show(EndScreen.new())


func _on_chat(line: ChatLine) -> void:
	if host.current is DayScreen:
		(host.current as DayScreen).append_line(line)


# =============================================================
# Экраны → Game
# =============================================================
func handle_intent(action: StringName, data: Dictionary, sender: Screen) -> void:
	if sender != host.current:
		return
	match action:
		Intent.START:
			if data.has("cfg"):
				Save.set_settings(data.cfg, data.haptics)
			start_match()
		Intent.OPEN_SETTINGS:
			show_settings()
		Intent.BACK:
			if data.has("cfg"):
				Save.set_settings(data.cfg, data.haptics)
			show_menu()
		Intent.AGAIN:
			start_match()
		Intent.CONTINUE:
			Game.proceed()
		Intent.SAY:
			Game.say(data.text)
		Intent.ACCUSE:
			Game.accuse(data.id)
		Intent.INVITE:
			Game.invite(data.id, data.house)
		Intent.ASK:
			Game.ask(data.id)
		Intent.DEFEND:
			Game.defend()
		Intent.END_DAY:
			Game.end_day()
		Intent.VOTE:
			Game.vote(int(data.id))
		Intent.CHOOSE_HOUSE:
			Game.choose_house(int(data.house))
		Intent.ADMIT:
			var ids: Array[int] = []
			ids.assign(data.ids)
			Game.admit(ids)
		Intent.PLEA:
			Game.plea(data.plea)


# =============================================================
# Кнопка «Назад» на Android
# =============================================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _started:
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
		toast("Нажмите ещё раз, чтобы выйти")
		await get_tree().create_timer(2.0).timeout
		_exit_armed = false
	elif s is SettingsScreen:
		var ss := s as SettingsScreen
		Save.set_settings(ss.cfg, ss.haptics)
		show_menu()
	elif s is EndScreen:
		show_menu()
	elif Game.active():
		var i: int = await ActionSheet.ask(s, "Бросить партию?", PackedStringArray(["Остаться", "Выйти в меню"]))
		if i == 1:
			show_menu()


func toast(text: String) -> void:
	_toast.text = text
	var t := Juice.tween()
	t.tween_property(_toast, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.4)
	t.tween_property(_toast, "modulate:a", 0.0, 0.4)
