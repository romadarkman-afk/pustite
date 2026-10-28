class_name ClueBook
extends Control
## Тетрадь улик (TASK-017): записи партии, выбор двух для сравнения, «Спросить при всех».
## Открывается из дневника. Спорят ли записи, видно только после выбора: искать противоречие — дело игрока.

var screen: Screen
var m: Match
var picked: Array[String] = []
var rows: Dictionary[String, Button] = {}
var status: Label
var ask_btn: Button
var _closed := false


static func open(parent: Control, mm: Match, sc: Screen) -> ClueBook:
	var b := ClueBook.new()
	b.m = mm
	b.screen = sc
	parent.add_child(b)
	b._build()
	return b


func _build() -> void:
	name = "ClueBook"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = -3000
	dim.offset_top = -3000
	dim.offset_right = 3000
	dim.offset_bottom = 3000
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			close())
	add_child(dim)
	var sheet := W.panel(&"Page")
	sheet.name = "ClueSheet"
	sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(sheet)
	var box := W.vbox(10)
	sheet.add_child(box)
	box.add_child(W.label(L.t("clue.title"), &"Speaker"))
	var hint := W.label(L.t("clue.hint"), &"Hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var sc := TouchScroll.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, maxf(180.0, (get_parent() as Control).size.y * 0.5))
	var list := W.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	box.add_child(sc)
	var shown := m.clues.shown()
	if shown.is_empty():
		list.add_child(W.label(L.t("clue.none"), &"Small"))
	for e: Dictionary in shown:
		var b := W.button("%s · %s" % [L.t("clue.day", {"n": int(e.day)}), String(e.text)], &"Row")
		b.name = "Clue_" + String(e.id)
		b.toggle_mode = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id := String(e.id)
		b.pressed.connect(func() -> void: toggle(id))
		rows[id] = b
		list.add_child(b)
	status = W.label("", &"Small")
	status.name = "Status"
	box.add_child(status)
	ask_btn = W.button(L.t("clue.ask"))
	ask_btn.name = "Ask"
	ask_btn.disabled = true
	ask_btn.pressed.connect(ask)
	box.add_child(ask_btn)
	var close_b := W.button(L.t("ui.close"), &"Ghost")
	close_b.pressed.connect(close)
	box.add_child(close_b)


## Выбрать или снять запись. Выбраны две — видно, спорят ли они.
func toggle(id: String) -> void:
	if picked.has(id):
		picked.erase(id)
	else:
		if picked.size() >= 2:
			var old: String = picked.pop_front()
			if rows.has(old):
				rows[old].button_pressed = false
		picked.append(id)
	if rows.has(id):
		rows[id].button_pressed = picked.has(id)
	_update()


func _update() -> void:
	ask_btn.disabled = true
	if picked.size() < 2:
		status.text = ""
		return
	var a := m.clues.get_entry(picked[0])
	var b := m.clues.get_entry(picked[1])
	if not m.clues.contradiction(a, b):
		status.text = L.t("clue.no_conflict")
		return
	if m.clues.asked.has(Clues.pair_key(a, b)):
		status.text = L.t("clue.asked")
		return
	status.text = L.t("clue.conflict")
	var t := m.get_villager(int(a.who))
	ask_btn.disabled = t == null or not t.alive or m.phase != Match.Phase.DAY or not m.player().alive


func ask() -> void:
	if ask_btn.disabled or picked.size() < 2:
		return
	var a := picked[0]
	var b := picked[1]
	close()
	if is_instance_valid(screen):
		screen.emit_intent(Intent.CONFRONT, {"a": a, "b": b})


func close() -> void:
	if _closed:
		return
	_closed = true
	queue_free()
