class_name Screen
extends Control
## Базовый экран. Правило: вызовы — вниз (App → Screen.setup/показ данных),
## сигналы — вверх (Screen → intent). Экран никогда не меняет Match сам.

signal intent(action: StringName, data: Dictionary)

var m: Match
var director: Director
var body: VBoxContainer
var footer: VBoxContainer
var scroll: ScrollContainer
var _clock: Label
var _locked := false


func setup(match_ref: Match, director_ref: Director) -> void:
	m = match_ref
	director = director_ref
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chrome()
	build()


## Переопределяется: наполнение экрана.
func build() -> void:
	pass


## Переопределяется: заголовок шапки. Пустая строка — без шапки.
func title() -> String:
	return ""


## Переопределяется: идентификатор для самотестов.
func screen_id() -> String:
	return "screen"


## Переопределяется: x — ночь (0..1), y — сила лампы. Дверной режим, если door_open() >= 0.
func mood() -> Vector2:
	return Vector2(1.0, 1.0)


func door_open() -> float:
	return -1.0


## Переопределяется: экран сам обработал «Назад» (например, закрыл шторку).
func handle_back() -> bool:
	for c: Node in get_children():
		if c is ActionSheet:
			(c as ActionSheet).close(-1)
			return true
	return false


func emit_intent(action: StringName, data: Dictionary = {}) -> void:
	if _locked:
		return
	intent.emit(action, data)


## Финальное решение экрана: отправить и сразу заблокировать.
func commit(action: StringName, data: Dictionary = {}) -> void:
	if _locked:
		return
	_locked = true
	intent.emit(action, data)


## Блокирует экран после финального решения: двойной тап и мультитач
## больше не могут отправить второе намерение.
func lock() -> void:
	_locked = true


func is_locked() -> bool:
	return _locked


func set_clock(seconds: int) -> void:
	if _clock == null:
		return
	_clock.text = "%d:%02d" % [seconds / 60, seconds % 60]
	_clock.add_theme_color_override("font_color",
		ThemeFactory.BLOOD if seconds <= 10 else ThemeFactory.FROST)
	if seconds <= 5 and seconds > 0:
		Juice.haptic(Juice.Haptic.TAP)


func scroll_to_end() -> void:
	if not is_inside_tree():
		await ready
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _chrome() -> void:
	var col := W.vbox(18)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(col)

	if title() != "":
		var bar := W.hbox(14)
		var t := W.label(title(), &"Body")
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		bar.add_child(t)
		if m != null and m.config != null:
			var marks := W.hbox(7)
			marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for i in range(m.config.nights):
				var dot := ColorRect.new()
				dot.custom_minimum_size = Vector2(10, 10)
				dot.color = ThemeFactory.LAMP_D if i + 1 < m.day else (ThemeFactory.LAMP if i + 1 == m.day else ThemeFactory.EDGE)
				marks.add_child(dot)
			bar.add_child(marks)
		_clock = W.label("", &"Clock")
		_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
		bar.add_child(_clock)
		col.add_child(bar)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	body = W.vbox(18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	footer = W.vbox(10)
	col.add_child(footer)


## Ряд плашек с жителями. on_tap: вызывается с Villager, если плашку можно нажать.
func people_strip(on_tap: Callable = Callable()) -> HFlowContainer:
	var flow := HFlowContainer.new()
	for v: Villager in m.villagers:
		var variation := &"Chip"
		var text := v.name
		if v.is_player:
			variation = &"ChipYou"
		elif not v.alive:
			variation = &"ChipDead"
			text += " · изгнан" if v.exiled else ""
		var c := W.chip(text, variation)
		if on_tap.is_valid() and v.alive and not v.is_player:
			var who := v
			c.pressed.connect(func() -> void: on_tap.call(who))
		else:
			c.disabled = not v.alive
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(c)
	return flow
