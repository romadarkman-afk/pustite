class_name Screen
extends Control
## Базовый экран. Правило: вызовы — вниз (Nav → Screen.setup/показ данных),
## сигналы — вверх (Screen → intent). Экран никогда не меняет Match сам.

signal intent(action: StringName, data: Dictionary)

var m: Match
var director: Director
var body: VBoxContainer
var footer: VBoxContainer
var scroll: ScrollContainer
var field_spacer: Control
var _title_label: Label
var hint: Hint
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


## Переопределяется: какая доля высоты экрана сверху отдана игровому полю. 0 — поле скрыто.
func field_ratio() -> float:
	return 0.0


## Переопределяется: высота поля при высоте экрана h. По умолчанию — доля field_ratio().
func field_height(h: float) -> float:
	return h * field_ratio()


## Прямоугольник поля в координатах экрана (без учёта анимации появления).
func field_rect_local() -> Rect2:
	if field_spacer == null:
		return Rect2()
	return Rect2(field_spacer.position + (field_spacer.get_parent() as Control).position, field_spacer.size)


## Переопределяется: идентификатор для самотестов.
func screen_id() -> String:
	return "screen"


## Переопределяется: x — ночь (0..1), y — сила лампы. Дверной режим, если door_open() >= 0.
func mood() -> Vector2:
	return Vector2(1.0, 1.0)


func door_open() -> float:
	return -1.0


## Звуковая картина экрана: фон, музыка, сердцебиение. Nav включает её при показе экрана.
## По умолчанию — экраны вне партии: музыка меню, без фона.
func ambience() -> StringName:
	return &""


func music() -> StringName:
	return &"menu"


func heart() -> bool:
	return false


## Переопределяется: во сколько раз приблизить посёлок на этом экране.
## Днём камера ближе и идёт за игроком; в остальных фазах посёлок виден целиком.
func field_zoom() -> float:
	return 1.0


## Переопределяется: за сколько секунд посёлок переходит к настроению этого экрана.
func mood_duration() -> float:
	return 0.6


var _field_press: Vector2 = Vector2.INF


## Касание по полю: короткий тап без сдвига уходит наверх намерением FIELD_TAP.
func enable_field_taps() -> void:
	if field_spacer == null:
		return
	field_spacer.mouse_filter = Control.MOUSE_FILTER_STOP
	field_spacer.gui_input.connect(_on_field_tap_input)


func _on_field_tap_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_field_press = mb.position
		elif _field_press != Vector2.INF and mb.position.distance_to(_field_press) < 24.0:
			emit_intent(Intent.FIELD_TAP, {"pos": field_spacer.get_global_rect().position + mb.position})
			_field_press = Vector2.INF


## Переопределяется: какая доля экрана обязана остаться под текст и кнопки в теле экрана.
## Самотест раскладки проверяет это правило.
func min_content_ratio() -> float:
	return 0.3


## Переопределяется: id подсказки новичку на этом экране ("" — без подсказки) и её текст.
func hint_id() -> String:
	return ""


func hint_text() -> String:
	return ""


## Переопределяется: к чему указывает подсказка (координаты экрана) и встаёт ли она под этим местом.
func hint_target() -> Rect2:
	return Rect2(Vector2(size.x * 0.5, scroll.position.y + 40.0), Vector2.ZERO)


func hint_below() -> bool:
	return true


func show_hint() -> void:
	if hint != null or hint_text().is_empty():
		return
	if not is_inside_tree():
		await ready
	for i in range(3):
		await get_tree().process_frame
	if not is_instance_valid(self) or hint != null:
		return
	hint = Hint.new()
	add_child(hint)
	hint.setup(hint_text())
	hint.place(hint_target(), minf(size.x, 520.0), hint_below())


func hide_hint() -> void:
	if hint != null:
		var h := hint
		hint = null
		if Juice.instant:
			h.queue_free()
		else:
			var t := Juice.tween()
			t.tween_property(h, "modulate:a", 0.0, 0.2)
			t.tween_callback(h.queue_free)


## Переопределяется: экран ещё раскрывается (построчный отчёт, появление роли).
## Самотесты ждут, пока он закончит, и только потом меряют раскладку.
func is_busy() -> bool:
	return false


## Переопределяется: время фазы вышло. По умолчанию ничего.
func on_clock_expired() -> void:
	pass


## Переопределяется: экран сам обработал «Назад» (например, закрыл шторку).
func handle_back() -> bool:
	for c: Node in get_children():
		if c is ActionSheet:
			(c as ActionSheet).close(-1)
			return true
		if c is TextSheet:
			(c as TextSheet).close("")
			return true
		if c is JournalSheet:
			(c as JournalSheet).close()
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
		Sfx.play(&"tick")


## Тёмная полупрозрачная капсула под текстом шапки — читается на любом небе.
func _capsule(inner: Control) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.1, 0.6)
	sb.border_color = Color(1, 1, 1, 0.16)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(inner)
	return p


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
		# над полем шапка лежит на небе — днём оно светлое, поэтому заголовок и часы в тёмных капсулах
		var over_sky := field_ratio() > 0.0
		var bar := W.hbox(14)
		var left := W.hbox(12)
		var t := W.label(title(), &"Body")
		_title_label = t
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		left.add_child(t)
		if m != null and m.config != null:
			var marks := W.hbox(7)
			marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for i in range(m.config.nights):
				var dot := ColorRect.new()
				dot.custom_minimum_size = Vector2(10, 10)
				dot.color = ThemeFactory.LAMP_D if i + 1 < m.day else (ThemeFactory.LAMP if i + 1 == m.day else Color(1, 1, 1, 0.3))
				marks.add_child(dot)
			left.add_child(marks)
		bar.add_child(_capsule(left) if over_sky else left)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(gap)
		_clock = W.label("", &"Clock")
		_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
		_clock.custom_minimum_size = Vector2(62, 0)
		bar.add_child(_capsule(_clock) if over_sky else _clock)
		col.add_child(bar)

	if field_ratio() > 0.0:
		field_spacer = Control.new()
		field_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(field_spacer)
		resized.connect(func() -> void: field_spacer.custom_minimum_size.y = floorf(field_height(size.y)))

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
