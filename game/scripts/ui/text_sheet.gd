class_name TextSheet
extends Control
## «Сказать…»: быстрые фразы в одно касание и своё поле ввода ниже.
## Клавиатура открывается, только когда игрок тапнул в поле; тогда фразы прячутся,
## освобождая место, — поле всегда остаётся над клавиатурой.
## Использование: var t: String = await TextSheet.ask(self, "Сказать вслух", фразы)  → "" = отмена

signal done(text: String)

var field: LineEdit
var quick_box: HFlowContainer
var send_button: Button
var _closed := false


static func ask(parent: Control, title: String, quick: PackedStringArray = PackedStringArray()) -> String:
	var s := TextSheet.new()
	parent.add_child(s)
	s._build(title, quick)
	var t: String = await s.done
	return t


func _build(title: String, quick: PackedStringArray = PackedStringArray()) -> void:
	Diag.step("ввод: открыт")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover_screen(dim)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			close(""))
	var sheet := W.panel(&"Sheet")
	add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := W.vbox(10)
	sheet.add_child(box)
	box.add_child(W.label(title, &"Hint"))
	quick_box = HFlowContainer.new()
	for q: String in quick:
		var chip := W.chip(q, &"Quick")
		var text := q
		chip.pressed.connect(func() -> void: close(text))
		quick_box.add_child(chip)
	quick_box.visible = not quick.is_empty()
	box.add_child(quick_box)
	field = LineEdit.new()
	field.placeholder_text = "Или напишите своё"
	field.max_length = 120
	field.custom_minimum_size = Vector2(0, ThemeFactory.TOUCH)
	field.text_submitted.connect(func(t: String) -> void: close(t.strip_edges()))
	field.focus_entered.connect(func() -> void:
		Diag.step("ввод: клавиатура")
		quick_box.visible = false)
	field.focus_exited.connect(func() -> void: quick_box.visible = quick_box.get_child_count() > 0)
	box.add_child(field)
	var row := W.hbox(10)
	var cancel := W.button("Отмена", &"Ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: close(""))
	send_button = W.button("Сказать")
	send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_button.pressed.connect(func() -> void: close(field.text.strip_edges()))
	row.add_child(cancel)
	row.add_child(send_button)
	box.add_child(row)
	if quick.is_empty():
		field.call_deferred("grab_focus")


func close(text: String) -> void:
	if _closed:
		return
	_closed = true
	Diag.step("ввод: закрыт")
	if is_instance_valid(field) and field.has_focus():
		field.release_focus()
	done.emit(text)
	queue_free()



## Затемнение на весь экран, а не только в пределах полей безопасной зоны.
func _cover_screen(dim: Control) -> void:
	dim.offset_left = -3000
	dim.offset_top = -3000
	dim.offset_right = 3000
	dim.offset_bottom = 3000
