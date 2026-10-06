class_name TextSheet
extends Control
## Ввод своего текста по запросу. Поле ввода и экранная клавиатура появляются,
## только когда игрок сам решил написать, — а не висят на экране всё время.
## Использование: var t: String = await TextSheet.ask(self, "Сказать вслух")  → "" = отмена

signal done(text: String)

var field: LineEdit
var _closed := false


static func ask(parent: Control, title: String) -> String:
	var s := TextSheet.new()
	parent.add_child(s)
	s._build(title)
	var t: String = await s.done
	return t


func _build(title: String) -> void:
	Diag.step("ввод: открыт")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	field = LineEdit.new()
	field.placeholder_text = "Что скажете?"
	field.max_length = 120
	field.custom_minimum_size = Vector2(0, ThemeFactory.TOUCH)
	field.text_submitted.connect(func(t: String) -> void: close(t.strip_edges()))
	box.add_child(field)
	var row := W.hbox(10)
	var cancel := W.button("Отмена", &"Ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: close(""))
	var send := W.button("Сказать")
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send.pressed.connect(func() -> void: close(field.text.strip_edges()))
	row.add_child(cancel)
	row.add_child(send)
	box.add_child(row)
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
