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
## Колонка шапка · поле · содержимое · подвал; нужна, чтобы считать высоту поля по реальным размерам.
var chrome: VBoxContainer
var _title_label: Label
var hint: Hint
var _clock: Label
var _clock_capsule: Control
var _locked := false


func _ready() -> void:
	call_deferred("_focus_first_control")


func _focus_first_control() -> void:
	if not is_instance_valid(self):
		return
	for preferred_name: String in ["Continue", "Start"]:
		var preferred := find_child(preferred_name, true, false) as Control
		if preferred != null and preferred.is_visible_in_tree() and preferred.focus_mode == Control.FOCUS_ALL:
			preferred.grab_focus()
			return
	var controls: Array[Node] = find_children("*", "Control", true, false)
	for node: Node in controls:
		var control := node as Control
		var interactive := control is BaseButton or control is LineEdit or control is TextEdit
		if interactive and control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree() and not control.is_queued_for_deletion():
			control.grab_focus()
			return


func setup(match_ref: Match, director_ref: Director) -> void:
	m = match_ref
	director = director_ref
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chrome()
	build()


func _navigation_label() -> String:
	return L.t("ui.menu") if m != null else "← " + L.t("ui.back")


func refresh_locale() -> void:
	if _title_label != null:
		_title_label.text = title()
	var menu := find_child("BackToMenu", true, false) as Button
	if menu != null:
		menu.text = _navigation_label()
		menu.custom_minimum_size.x = maxf(float(ThemeFactory.COMPACT_TOUCH), W.button_need(menu))
		menu.tooltip_text = L.t("ui.menu") if m != null else L.t("ui.back")
		menu.accessibility_name = menu.tooltip_text


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
	var wanted := h * field_ratio()
	if chrome == null:
		return wanted
	# на низком экране поле уступает: под содержимое остаётся min_content_ratio() высоты дисплея (но поле не меньше 20%)
	var sep := float(chrome.get_theme_constant("separation"))
	var bar := 0.0
	if title() != "" and chrome.get_child_count() > 0:
		bar = (chrome.get_child(0) as Control).get_combined_minimum_size().y
	var content := min_content_ratio() * get_viewport_rect().size.y
	var left := h - bar - footer.get_combined_minimum_size().y - 3.0 * sep - content
	return clampf(left, h * 0.2, wanted)


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
## По умолчанию музыка молчит; её включают только экраны с отдельной драматической сценой.
func ambience() -> StringName:
	return &""


## Уровень фонового шума для этого экрана; меню приглушает его ради заглавной песни.
func ambience_volume_db() -> float:
	return -4.0


func music() -> StringName:
	return Sfx.menu_music() if Game.m == null else &""


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
var _pan_last: Vector2 = Vector2.INF       ## где был палец в прошлый раз, пока тянет поле; INF — палец не на поле


## Касание по полю: короткий тап без сдвига уходит наверх намерением FIELD_TAP.
func enable_field_taps() -> void:
	if field_spacer == null:
		return
	field_spacer.mouse_filter = Control.MOUSE_FILTER_STOP
	field_spacer.set_meta("pan_field", true)
	field_spacer.gui_input.connect(_on_field_tap_input)


## Долгое нажатие на месте — FIELD_HOLD (жест жителю), короткое — FIELD_TAP.
const HOLD_SEC := 0.5
var _hold_gen := 0


func _on_field_tap_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		_hold_gen += 1
		if mb.pressed:
			_field_press = mb.position
			_pan_last = mb.position
			_wait_hold(_hold_gen, mb.position)
		else:
			_pan_last = Vector2.INF
			if _field_press != Vector2.INF and mb.position.distance_to(_field_press) < 24.0:
				emit_intent(Intent.FIELD_TAP, {"pos": field_spacer.get_global_rect().position + mb.position})
				_field_press = Vector2.INF
	elif e is InputEventMouseMotion and _pan_last != Vector2.INF:
		var at := (e as InputEventMouseMotion).position
		if _field_press != Vector2.INF:
			if at.distance_to(_field_press) < 24.0:
				return
			_hold_gen += 1        # повёл пальцем — это не долгое нажатие
			_field_press = Vector2.INF  # отпускание после перетаскивания не открывает меню
			_pan_last = at        # первые 24 пикселя мёртвая зона, карта едет со следующего движения
			return
		var dx := at.x - _pan_last.x
		_pan_last = at
		if dx != 0.0:
			emit_intent(Intent.FIELD_PAN, {"dx": dx})


func _wait_hold(gen: int, at: Vector2) -> void:
	await get_tree().create_timer(HOLD_SEC).timeout
	if gen != _hold_gen or _field_press == Vector2.INF or not is_instance_valid(field_spacer):
		return
	_field_press = Vector2.INF      # отпускание после жеста — уже не тап
	emit_intent(Intent.FIELD_HOLD, {"pos": field_spacer.get_global_rect().position + at})


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
		if c is SlidePlayer:
			(c as SlidePlayer).skip()
			return true
		if c is ScenePlayer:
			(c as ScenePlayer).skip()
			return true
		if c is ClueBook:
			(c as ClueBook).close()
			return true
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
	if _clock_capsule != null:
		_clock_capsule.visible = true
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
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(inner)
	return p




func _chrome() -> void:
	var col := W.vbox(10 if field_ratio() > 0.0 else 14)
	chrome = col
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(col)

	if title() != "":
		# над полем шапка лежит на небе — днём оно светлое, поэтому заголовок и часы в тёмных капсулах
		var over_sky := field_ratio() > 0.0
		var bar := W.hbox(8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var left := W.hbox(8)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := W.label(title(), &"Body")
		_title_label = t
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(t)
		if m != null and m.config != null:
			var marks := W.hbox(5)
			marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for i in range(m.config.nights):
				var dot := ColorRect.new()
				dot.custom_minimum_size = Vector2(8, 8)
				dot.color = ThemeFactory.LAMP_D if i + 1 < m.day else (ThemeFactory.LAMP if i + 1 == m.day else Color(1, 1, 1, 0.3))
				marks.add_child(dot)
			left.add_child(marks)
		var left_capsule: Control = _capsule(left) if over_sky else left
		left_capsule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(left_capsule)
		_clock = W.label("", &"Clock")
		_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
		_clock.custom_minimum_size = Vector2(56, 0)
		_clock_capsule = _capsule(_clock) if over_sky else _clock
		_clock_capsule.visible = false
		bar.add_child(_clock_capsule)
		if screen_id() != "menu":
			var menu := W.button(_navigation_label(), &"Compact", ThemeFactory.COMPACT_TOUCH)
			menu.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
			menu.accessibility_name = L.t("ui.menu") if m != null else L.t("ui.back")
			menu.name = "BackToMenu"
			menu.size_flags_horizontal = Control.SIZE_SHRINK_END
			menu.custom_minimum_size.x = maxf(float(ThemeFactory.COMPACT_TOUCH), W.button_need(menu))
			menu.tooltip_text = menu.text
			menu.pressed.connect(Nav._on_back)
			bar.add_child(menu)
		col.add_child(bar)

	if field_ratio() > 0.0:
		field_spacer = Control.new()
		field_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(field_spacer)
		resized.connect(_fit_field_spacer)
		field_spacer.resized.connect(Nav._queue_field_layout)

	scroll = TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	body = W.vbox(14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	footer = W.vbox(8)
	col.add_child(footer)
	# ряд кнопок внизу может перестроиться (строка → сетка) после первой раскладки: поле подстраиваем под него
	if field_spacer != null:
		footer.minimum_size_changed.connect(_fit_field_spacer)


func _fit_field_spacer() -> void:
	if field_spacer != null and size.y > 0.0:
		field_spacer.custom_minimum_size.y = floorf(field_height(size.y))


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
			text += L.t("chip.exiled") if v.exiled else ""
		var c := W.chip(text, variation)
		if on_tap.is_valid() and v.alive and not v.is_player:
			var who := v
			c.pressed.connect(func() -> void: on_tap.call(who))
		else:
			c.disabled = not v.alive
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(c)
	return flow
