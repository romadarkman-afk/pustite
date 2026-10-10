class_name JournalSheet
extends Control
## Журнал дня целиком: кто что говорил. Открывается по строке «Журнал (N)» под полем —
## живой разговор идёт пузырями на картинке, текст нужен, только чтобы перечитать.

var list: VBoxContainer
var _closed := false


static func open(parent: Control, lines: Array[ChatLine]) -> JournalSheet:
	var s := JournalSheet.new()
	parent.add_child(s)
	s._build(lines)
	return s


## Строка журнала: «Имя: текст». Системные сообщения — мелким серым.
static func line_row(line: ChatLine) -> Control:
	if line.kind == ChatLine.Kind.SYSTEM:
		return W.label(line.text, &"Small")
	var row := W.hbox(8)
	var nm := W.label(L.t("journal.who", {"who": L.t("you_name") if line.kind == ChatLine.Kind.MINE else line.speaker.name}), &"Speaker")
	nm.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	if line.kind == ChatLine.Kind.MINE:
		nm.add_theme_color_override("font_color", ThemeFactory.LAMP)
	var tx := W.label(line.text, &"Small")
	tx.add_theme_color_override("font_color", ThemeFactory.BONE)
	row.add_child(nm)
	row.add_child(tx)
	return row


func _build(lines: Array[ChatLine]) -> void:
	Diag.step("журнал: открыт")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = -3000
	dim.offset_top = -3000
	dim.offset_right = 3000
	dim.offset_bottom = 3000
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			close())
	var sheet := W.panel(&"Sheet")
	add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := W.vbox(10)
	sheet.add_child(box)
	box.add_child(W.label(L.t("journal.head"), &"Hint"))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, maxf(160.0, (get_parent() as Control).size.y * 0.6))
	list = W.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	box.add_child(sc)
	for l: ChatLine in lines:
		list.add_child(line_row(l))
	var close_b := W.button(L.t("ui.close"), &"Ghost")
	close_b.pressed.connect(close)
	box.add_child(close_b)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(sc):
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)


func close() -> void:
	if _closed:
		return
	_closed = true
	Diag.step("журнал: закрыт")
	queue_free()
