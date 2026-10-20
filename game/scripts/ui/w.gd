class_name W
extends RefCounted
## Короткие конструкторы виджетов. Весь стиль — в теме, здесь только структура.


static func label(text: String, variation: StringName = &"Body") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, variation: StringName = &"Primary", min_h: int = ThemeFactory.TOUCH) -> Button:
	var b := _button(text, variation, min_h)
	b.pressed.connect(func() -> void: Sfx.play(&"tap", randf_range(0.95, 1.08), -4.0))
	return b


static func _button(text: String, variation: StringName = &"Primary", min_h: int = ThemeFactory.TOUCH) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_ALL
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Juice.press_feedback(b)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void: _button_state(b, true))
	b.mouse_exited.connect(func() -> void: _button_state(b, false))
	b.focus_entered.connect(func() -> void: _button_state(b, true))
	b.focus_exited.connect(func() -> void: _button_state(b, false))
	return b


static func _button_state(b: Button, active: bool) -> void:
	if not is_instance_valid(b) or b.disabled:
		return
	if b.has_meta("ui_state_tween"):
		var old: Variant = b.get_meta("ui_state_tween")
		if old is Tween and (old as Tween).is_running():
			(old as Tween).kill()
	if active:
		Sfx.play(&"blip", 1.15, -14.0)
	var tween := b.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	b.set_meta("ui_state_tween", tween)
	tween.tween_property(b, "scale", Vector2.ONE * (1.018 if active else 1.0), 0.12)
	tween.parallel().tween_property(b, "self_modulate", Color(1.08, 1.04, 0.94) if active else Color.WHITE, 0.12)


## Плашка с именем: ширина по тексту, имя никогда не обрезается.
## (С обрезкой многоточием Godot считает минимальную ширину нулевой — плашка схлопывается.)
static func chip(text: String, variation: StringName) -> Button:
	var b := button(text, variation, ThemeFactory.TOUCH - 4)
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


static func panel(variation: StringName = &"Card") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


static func vbox(sep: int = 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func clear(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)       # сразу из дерева: новые узлы получат свои имена, а не «@HBox@12»
		c.queue_free()


## Значок и короткая подпись в одну строку.
static func icon_line(kind: String, text: String, variation: StringName = &"Body", px: float = 44.0, c: Color = Color(0, 0, 0, 0)) -> HBoxContainer:
	var h := hbox(14)
	h.add_child(Glyph.make(kind, px, Glyph.tint(kind) if c.a == 0.0 else c))
	var l := label(text, variation)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


## Кнопка «Подробнее»: открывает шторку с пояснениями. lines — функция, чтобы тексты собирались в момент нажатия.
static func more(parent: Control, lines: Callable) -> Button:
	var b := chip(L.t("ui.more"), &"Ghost")
	b.name = "More"
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: InfoSheet.open(parent, lines.call()))
	return b


## Ряд кнопок: влезают в строку — встают в строку; при крупном тексте или длинных словах —
## сеткой в два столбца, а если и так тесно — столбиком. Надписи не обрезаются.
static func fit_row(buttons: Array, sep: int = 8) -> Container:
	var avail: float = Nav.host.size.x if Nav.host != null and Nav.host.size.x > 100.0 else 672.0
	var widest := 0.0
	var total := sep * (buttons.size() - 1.0)
	for b: Button in buttons:
		var need := button_need(b)
		widest = maxf(widest, need)
		total += need
	var box: Container
	if total <= avail:
		box = hbox(sep)
	else:
		var g := GridContainer.new()
		g.columns = 2 if widest * 2.0 + sep <= avail else 1
		g.add_theme_constant_override("h_separation", sep)
		g.add_theme_constant_override("v_separation", sep)
		box = g
	box.name = "FitRow"
	for b: Button in buttons:
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		# узкая кнопка (SHRINK_BEGIN) в строке остаётся узкой; в сетке все одной ширины
		if box is GridContainer or b.size_flags_horizontal != Control.SIZE_SHRINK_BEGIN:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(b)
	return box


const _BTN_SIZE := {&"Primary": 25, &"Quick": 20, &"Chip": 19, &"ChipYou": 19, &"ChipDead": 19, &"ChipUpyr": 19}
const _BTN_PAD := {&"Quick": 14, &"Chip": 12, &"ChipYou": 12, &"ChipDead": 12, &"ChipUpyr": 12}


## Ширина кнопки по надписи — ещё до того, как она попала в дерево и получила тему.
static func button_need(b: Button) -> float:
	var v := b.theme_type_variation
	var fsz := ThemeFactory.fs(_BTN_SIZE.get(v, 23))
	if b.has_theme_font_size_override("font_size"):
		fsz = b.get_theme_font_size("font_size")
	var pad: int = _BTN_PAD.get(v, 20)
	return ThemeFactory.font_bold().get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x + 2.0 * (pad + 2) + 4.0


## Длинная надпись на кнопке переносится по словам, а не обрезается.
static func wrap(b: Button) -> Button:
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return b


## Портрет жителя с поля: та же картинка, что на площади (у героя — с шапкой). name = "Portrait".
static func portrait(v: Villager, sz: Vector2 = Vector2(70, 128), tint: Color = Color(1, 1, 1)) -> TextureRect:
	var p := LivingPortrait.new()
	p.name = "Portrait"
	p.active = v != null and v.alive
	if v != null and Game.m != null and Game.m.feelings != null:
		p.state = Game.m.feelings.main(v.id)
	var figure: VillagerFigure = null
	if v != null and Nav.village != null and Nav.village.crowd != null:
		figure = Nav.village.crowd.figures.get(v.id)
	if figure != null:
		p.texture = figure._hero_texture() if v.is_player else VillagerFigure.folk_tex(figure.sprite_id)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.custom_minimum_size = sz
	p.modulate = tint
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
