class_name TextSheet
extends Control
## «Сказать…»: быстрые фразы в одно касание и своё поле ввода ниже.
## Клавиатура открывается, только когда игрок тапнул в поле; тогда фразы прячутся,
## освобождая место, — поле всегда остаётся над клавиатурой.
## Использование: var t: String = await TextSheet.ask(self, "Сказать вслух", фразы)  → "" = отмена

signal done(text: String)

var field: LineEdit
var quick_box: VBoxContainer
var send_button: Button
var _closed := false


func _exit_tree() -> void:
	# Экран может смениться, пока вызывающий код ждёт ответа.
	# Завершаем ожидание до удаления шторки, чтобы он снял свою паузу.
	if not _closed:
		_closed = true
		done.emit("")


static func ask(parent: Control, title: String, quick: PackedStringArray = PackedStringArray(), initial_text: String = "", max_length: int = 120) -> String:
	var s := TextSheet.new()
	parent.add_child(s)
	s._build(title, quick, initial_text, max_length)
	var t: String = await s.done
	return t


func _build(title: String, quick: PackedStringArray, initial_text: String = "", max_length: int = 120) -> void:
	Diag.step("ввод: открыт")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.34)
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
	quick_box = W.vbox(8)
	for q: String in quick:
		var chip := W.wrap(W.button(q, &"Quick"))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text := q
		chip.pressed.connect(func() -> void: close(text))
		quick_box.add_child(chip)
	quick_box.visible = not quick.is_empty()
	box.add_child(quick_box)
	field = LineEdit.new()
	field.placeholder_text = L.t("say.placeholder")
	field.max_length = maxi(1, max_length)
	field.text = initial_text
	field.custom_minimum_size = Vector2(0, ThemeFactory.TOUCH)
	field.text_submitted.connect(func(t: String) -> void: close(t.strip_edges()))
	field.focus_entered.connect(func() -> void:
		Diag.step("ввод: клавиатура")
		quick_box.visible = false)
	field.focus_exited.connect(func() -> void: quick_box.visible = quick_box.get_child_count() > 0)
	box.add_child(field)
	var row := W.hbox(10)
	var cancel := W.button(L.t("ui.cancel"), &"Ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: close(""))
	send_button = W.button(L.t("say.send"))
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
