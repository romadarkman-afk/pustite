class_name ActionSheet
extends Control
## Нижняя шторка выбора — в зоне большого пальца.
## Использование: var i: int = await ActionSheet.ask(self, "Кого?", ["А", "Б"])  → -1 = отмена

signal chosen(index: int)

var _done := false
var _pause_key: StringName


static func ask(parent: Control, title: String, options: PackedStringArray) -> int:
	var s := ActionSheet.new()
	parent.add_child(s)
	s._build(title, options)
	var idx: int = await s.chosen
	return idx


func _build(title: String, options: PackedStringArray) -> void:
	_pause_key = StringName("action_sheet_%d" % get_instance_id())
	Game.hold(_pause_key)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover_screen(dim)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			close(-1))
	add_child(dim)

	var sheet := W.panel(&"Sheet")
	sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(sheet)

	var box := W.vbox(10)
	sheet.add_child(box)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = minf((get_parent() as Control).size.y * 0.56, 500.0 * ThemeFactory.text_scale)
	var content := W.vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	box.add_child(sc)
	content.add_child(W.label(title, &"Hint"))
	var first_button: Button
	for i in range(options.size()):
		var b := W.button(options[i], &"Row")
		if i == 0:
			first_button = b
		var idx := i
		b.pressed.connect(func() -> void: close(idx))
		content.add_child(b)
	var cancel := W.button(L.t("ui.cancel"), &"Ghost")
	cancel.pressed.connect(func() -> void: close(-1))
	box.add_child(cancel)
	if first_button != null:
		first_button.call_deferred("grab_focus")

	if not Juice.instant:
		dim.modulate.a = 0.0
		sheet.modulate.a = 0.0
		var t := Juice.tween().set_parallel(true)
		t.tween_property(dim, "modulate:a", 1.0, 0.18)
		t.tween_property(sheet, "modulate:a", 1.0, 0.22)


func close(idx: int) -> void:
	if _done:
		return
	_done = true
	Game.release(_pause_key)
	chosen.emit(idx)
	queue_free()


func _exit_tree() -> void:
	if not _done:
		_done = true
		Game.release(_pause_key)
		chosen.emit(-1)



## Затемнение на весь экран, а не только в пределах полей безопасной зоны.
func _cover_screen(dim: Control) -> void:
	dim.offset_left = -3000
	dim.offset_top = -3000
	dim.offset_right = 3000
	dim.offset_bottom = 3000
