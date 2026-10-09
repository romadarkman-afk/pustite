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
	b.focus_mode = Control.FOCUS_NONE
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Juice.press_feedback(b)
	return b


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
		c.queue_free()
