extends Node
## Экраны, переходы, фон и кнопка «Назад».
## Слушает сигналы Game и строит нужный экран. Намерения игрока с экранов
## передаёт в Game вызовами. Сам правила не трогает.

var layer: CanvasLayer
var ui: Control
var atmos: Atmosphere
var village: VillageView
var scrim: Scrim
var bubbles: Bubbles
var field_screen: Screen          ## экран, под который поле уже откадрировано (для самотестов)
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

	var field_layer := Control.new()
	field_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(field_layer)
	field_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	village = VillageView.new()
	village.setup(load("res://config/village_default.tres") as VillageDef, Save.config.shelters, Match.HOUSES)
	village.modulate.a = 0.0
	field_layer.add_child(village)
	scrim = Scrim.new()
	ui.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubbles = Bubbles.new()
	ui.add_child(bubbles)
	bubbles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	Game.marks_changed.connect(func() -> void: village.crowd.update_marks(Game.director, Game.m))
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
	if Diag.crashed_last_time:
		Diag.crashed_last_time = false
		show(CrashScreen.new())
	else:
		show_menu()


# =============================================================
# Навигация
# =============================================================
func show_menu() -> void:
	Game.abandon()
	village.crowd.clear()
	var s := MenuScreen.new()
	s.difficulty = Save.difficulty
	s.cfg = Save.config
	show(s)


func show_settings() -> void:
	Game.abandon()
	village.crowd.clear()
	var s := SettingsScreen.new()
	s.cfg = Save.config.duplicate() as GameConfig
	s.haptics = Save.haptics
	s.difficulty = Save.difficulty
	show(s)


func start_match() -> void:
	Game.start(Save.config)


func show(s: Screen) -> void:
	Diag.step("экран: %s" % s.screen_id())
	bubbles.clear()
	bubbles.field = Rect2()
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
	_frame_field(s)
	if Game.m != null and s.hint_id() != "" and not Save.hint_seen(s.hint_id()):
		s.show_hint()


## Подсказка выполнила своё: игрок сделал то, о чём она говорила.
const HINT_DONE := {
	"day": [&"field_tap", &"accuse", &"invite", &"ask", &"defend", &"say"],
	"night": [&"choose_house"],
	"door": [&"admit", &"plea"],
}


func _hint_done(sender: Screen, action: StringName) -> void:
	var id := sender.hint_id()
	if id != "" and HINT_DONE.has(id) and (HINT_DONE[id] as Array).has(action):
		Save.mark_hint(id)
		sender.hide_hint()


## Кадрирование поля под экран. Ждём раскладку, затем плавно ведём камеру.
func _frame_field(s: Screen) -> void:
	for i in range(3):
		await get_tree().process_frame
	if not is_instance_valid(s) or s != host.current:
		return
	var dur := 0.0 if Juice.instant else 0.6
	village.set_open_count(Game.m.config.shelters if Game.m != null else Save.config.shelters)
	var visible_field := s.field_ratio() > 0.0 and s.door_open() < 0.0
	Diag.step("поле: %s" % ("кадр" if visible_field else "скрыто"))
	if visible_field:
		var r := s.field_rect_local()
		r.position += host.global_position
		village.frame_to(r, ui.size.x, dur)
		bubbles.field = r
		village.set_mood(s.mood().x, dur)
		_tween_to(village, "modulate:a", 1.0, dur)
		_tween_to(scrim, "top", r.end.y, dur)
		_tween_to(scrim, "strength", 1.0, dur)
	else:
		_tween_to(village, "modulate:a", 0.0, dur * 0.6)
		_tween_to(scrim, "strength", 0.0, dur * 0.6)
	field_screen = s


func _tween_to(obj: Object, prop: String, value: float, dur: float) -> void:
	if dur <= 0.0:
		obj.set_indexed(prop, value)
		return
	Juice.tween().tween_property(obj, prop, value, dur)


# =============================================================
# Game → экраны
# =============================================================
func _on_phase(phase: Match.Phase) -> void:
	if phase == Match.Phase.PROLOGUE:
		village.crowd.populate(Game.m)
		village.crowd.update_marks(Game.director, Game.m)
	village.crowd.sync(Game.m, phase)
	# метка «Вы»: в первых трёх партиях всегда, потом — только в прологе
	village.crowd.set_player_highlight(phase == Match.Phase.PROLOGUE or int(Save.stats["games"]) < 3)
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
			var e := EndScreen.new()
			e.offer = Save.offer
			e.difficulty = Save.difficulty
			show(e)


func _on_chat(line: ChatLine) -> void:
	if host.current is DayScreen:
		(host.current as DayScreen).append_line(line)
		if line.speaker != null and village.crowd.figures.has(line.speaker.id):
			var f: VillagerFigure = village.crowd.figures[line.speaker.id]
			bubbles.say(Ru.nom(line.speaker), line.text, f.head_global(), line.speaker.is_player)


# =============================================================
# Экраны → Game
# =============================================================
func handle_intent(action: StringName, data: Dictionary, sender: Screen) -> void:
	if sender != host.current:
		return
	Diag.step("действие: %s" % action)
	if action != Intent.FIELD_TAP:
		_hint_done(sender, action)
	match action:
		Intent.START:
			_apply_settings(data)
			start_match()
		Intent.OPEN_SETTINGS:
			show_settings()
		Intent.BACK:
			_apply_settings(data)
			show_menu()
		Intent.AGAIN:
			if data.has("difficulty"):
				Save.set_difficulty(data.difficulty)
			start_match()
		Intent.SET_DIFFICULTY:
			Save.set_difficulty(data.d)
			if sender is MenuScreen:
				(sender as MenuScreen).refresh(Save.difficulty, Save.config)
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
		Intent.FIELD_TAP:
			var vid := village.crowd.figure_at(data.pos)
			if vid < 0 or Game.m == null:
				return
			var v := Game.m.get_villager(vid)
			_hint_done(sender, action)
			village.crowd.figures[vid].poke()
			Juice.haptic(Juice.Haptic.TAP)
			if v.alive and not v.is_player and sender is DayScreen:
				(sender as DayScreen).person_actions(v)


# =============================================================
# Кнопка «Назад» на Android
# =============================================================
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if _started:
				_on_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			Game.hold(&"background")
			Save.flush()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			Game.release(&"background")


## Настройки: ступень лестницы или своя сложность, вибрация, сброс подсказок.
func _apply_settings(data: Dictionary) -> void:
	if data.get("reset_hints", false):
		Save.reset_hints()
	if not data.has("cfg"):
		return
	var d: String = data.get("difficulty", "custom")
	if Difficulty.PRESETS.has(d):
		Save.set_difficulty(d)
		Save.set_haptics(data.haptics)
	else:
		Save.set_settings(data.cfg, data.haptics)


func _on_back() -> void:
	var s := host.current
	if s != null and s.handle_back():
		return
	if s is MenuScreen:
		if _exit_armed:
			Diag.clean_exit()
			get_tree().quit()
			return
		_exit_armed = true
		toast("Нажми ещё раз, чтобы выйти")
		await get_tree().create_timer(2.0).timeout
		_exit_armed = false
	elif s is SettingsScreen:
		var ss := s as SettingsScreen
		_apply_settings({"cfg": ss.cfg, "haptics": ss.haptics, "reset_hints": ss.reset_hints, "difficulty": ss.difficulty})
		show_menu()
	elif s is EndScreen:
		show_menu()
	elif Game.active():
		Game.hold(&"dialog")
		var i: int = await ActionSheet.ask(s, "Бросить партию?", PackedStringArray(["Остаться", "Выйти в меню"]))
		Game.release(&"dialog")
		if i == 1:
			show_menu()


func toast(text: String) -> void:
	_toast.text = text
	var t := Juice.tween()
	t.tween_property(_toast, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.4)
	t.tween_property(_toast, "modulate:a", 0.0, 0.4)
