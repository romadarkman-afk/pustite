class_name DiarySheet
extends Control
## Дневник улик (задача 34): всё, что посёлок знает о каждом жителе, в одном месте.
## Где ночевал каждую ночь и что говорил днём, улики, кто кем назвался, что показали рисунки
## старожила (если старожил — ты). Открывается кнопкой «Дневник» днём и на голосовании.

var list: VBoxContainer
var cards: Dictionary[int, Control] = {}     ## для самотестов: карточка жителя по id
var _closed := false


static func open(parent: Control, m: Match, d: Director) -> DiarySheet:
	var s := DiarySheet.new()
	parent.add_child(s)
	s._build(m, d)
	return s


## Строки о жителе — чистые данные, их проверяет самотест.
static func facts(m: Match, d: Director, v: Villager) -> PackedStringArray:
	var out := PackedStringArray()
	if not v.alive:
		if v.exiled:
			out.append(L.t("diary.exiled", {"who": v, "n": v.exiled_day}))
		else:
			for rec: Dictionary in m.history:
				if (rec.dead as Array).has(v.id):
					out.append(L.t("diary.died", {"who": v, "n": int(rec.day)}))
	var nights := PackedStringArray()
	for rec: Dictionary in m.history:
		var where: Dictionary = rec.where
		if not where.has(v.id):
			continue
		var h: int = where[v.id]
		var said: int = (rec.said as Dictionary).get(v.id, -1)
		var t := L.t("diary.night", {"n": int(rec.day), "where": L.t("diary.street") if h < 0 else m.house_name(h)})
		if said >= 0 and said != h:
			t += L.t("diary.said", {"who": v, "house": m.house_name(said)})
		nights.append(t)
	if not nights.is_empty():
		out.append(L.t("diary.nights", {"list": L.t("ev.sep").join(nights)}))
	if v.alive and v.announced_house >= 0:
		out.append(L.t("diary.today", {"house": m.house_name(v.announced_house)}))
	var ev := d.evidence_text(v) if d != null else ""
	if not ev.is_empty():
		out.append(L.t("diary.evidence", {"ev": ev}))
	if m.claims.has(v.id):
		out.append(L.t("diary.own_claim", {"text": L.gram().cap(m.claims[v.id])}))
	# что сказали про него другие: «Захар назвал себя старожилом: Тимур — упырь»
	for vid: int in m.claims:
		var who := m.get_villager(vid)
		if who != v and m.claim_elder.has(vid) and m.claim_about.get(vid, -1) == v.id:
			out.append(L.t("diary.claim", {"who": who, "text": m.claims[vid]}))
	if m.player_seen.has(v.id):
		out.append(L.t("diary.seen_upyr" if m.player_seen[v.id] == 1 else "diary.seen_human"))
	if out.is_empty():
		out.append(L.t("diary.nothing"))
	return out


func _build(m: Match, d: Director) -> void:
	Diag.step("дневник: открыт")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
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
	box.add_child(W.label(L.t("diary.head"), &"Hint"))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, maxf(200.0, (get_parent() as Control).size.y * 0.66))
	list = W.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	box.add_child(sc)
	# сначала живые (подозрительные выше), потом ушедшие
	var people: Array[Villager] = []
	for v: Villager in m.villagers:
		if not v.is_player:
			people.append(v)
	people.sort_custom(func(a: Villager, b: Villager) -> bool:
		if a.alive != b.alive:
			return a.alive
		return (d.susp(a.id) if d != null else 0.0) > (d.susp(b.id) if d != null else 0.0))
	for v: Villager in people:
		var card := W.panel(&"Card")
		var col := W.vbox(4)
		var head := W.label(v.name if v.alive else L.t("diary.gone", {"who": v}), &"Body")
		if not v.alive:
			head.modulate.a = 0.6
		col.add_child(head)
		for f: String in facts(m, d, v):
			col.add_child(W.label(f, &"Small"))
		card.add_child(col)
		list.add_child(card)
		cards[v.id] = card
	var close_b := W.button(L.t("ui.close"), &"Ghost")
	close_b.pressed.connect(close)
	box.add_child(close_b)


func close() -> void:
	if _closed:
		return
	_closed = true
	Diag.step("дневник: закрыт")
	queue_free()
