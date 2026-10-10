class_name DoorScreen
extends Screen
## Дверь. Три режима:
##  HOST  — ты добежал первым, в дверь стучат, решаешь ты;
##  GUEST — ты у чужой двери и умоляешь впустить (в v0.1 этого не было вообще);
##  ALONE — ты внутри, а больше никто не пришёл.
## Атмосферой управляет Nav по сигналам этого экрана — экран лишь просит.

signal knock_fx
signal open_fx(amount: float)

var role: Match.DoorRole
var seat: Match.Seat
var pleas: Dictionary[int, String] = {}
var result_shown := false
var _selected: Array[int] = []
var _rows: Dictionary[int, Button] = {}
var _go: Button
var _box: VBoxContainer       ## содержимое двери на тёмной подложке


func screen_id() -> String:
	match role:
		Match.DoorRole.HOST: return "door_host"
		Match.DoorRole.GUEST: return "door_guest"
	return "door_alone"


func title() -> String:
	return L.t("door.title")


func hint_id() -> String:
	return "door"


func hint_text() -> String:
	match role:
		Match.DoorRole.HOST:
			return L.t("door.hint_host")
		Match.DoorRole.GUEST:
			return L.t("door.hint_guest")
	return L.t("door.hint_alone")


func hint_target() -> Rect2:
	return Rect2(Vector2(size.x * 0.5, footer.get_global_rect().position.y - get_global_rect().position.y - 10.0), Vector2.ZERO)


func _plate(side: int, top: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.88)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = side
	sb.content_margin_right = side
	sb.content_margin_top = top
	sb.content_margin_bottom = top + 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func hint_below() -> bool:
	return false


func door_open() -> float:
	return 0.05 if role != Match.DoorRole.GUEST else 0.012


func build() -> void:
	# весь текст двери и кнопки — на тёмных подложках: свет из щели и распахнутой двери их не засвечивает
	var plate := _plate(22, 16)
	_box = W.vbox(14)
	plate.add_child(_box)
	body.add_child(plate)
	var col := footer.get_parent()
	var at := footer.get_index()
	var fplate := _plate(10, 10)
	col.remove_child(footer)
	fplate.add_child(footer)
	col.add_child(fplate)
	col.move_child(fplate, at)
	match role:
		Match.DoorRole.HOST: _build_host()
		Match.DoorRole.GUEST: _build_guest()
		_: _build_alone()


# ---------------------------------------------------------------
func _build_host() -> void:
	_box.add_child(W.label(L.t("door.host", {"house": m.house_name(seat.house)}), &"Tale"))
	var cap := m.config.capacity - 1
	_box.add_child(W.label(L.t("door.cap", {"n": cap}), &"Hint"))

	for g: Villager in seat.knockers():
		var card := W.panel(&"Card")
		var row := W.hbox(14)
		var texts := W.vbox(4)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(W.label(g.name, &"Body"))
		texts.add_child(W.label(L.t("door.quote", {"text": pleas.get(g.id, "…")}), &"Small"))
		row.add_child(texts)
		var b := W.button(L.t("door.admit"), &"Row")
		b.custom_minimum_size = Vector2(200, ThemeFactory.TOUCH)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var gid := g.id
		b.pressed.connect(func() -> void: _toggle(gid, cap))
		_rows[gid] = b
		row.add_child(b)
		card.add_child(row)
		_box.add_child(card)

	# кто сейчас у других дверей: если голос за дверью — один из них, это не он
	var elsewhere := PackedStringArray()
	for other: Match.Seat in m.seats:
		if other == seat:
			continue
		for v: Villager in [other.host] + other.queue:
			if not v.is_player:
				elsewhere.append(v.name)
	if not elsewhere.is_empty():
		_box.add_child(W.label(L.t("door.elsewhere", {"list": L.t("list.sep").join(elsewhere)}), &"Small"))

	_box.add_child(W.label(
		L.t("door.upyr_note") if m.player().is_upyr else L.t("door.alone_note"), &"Hint"))

	_go = W.button(L.t("door.open"))
	_go.disabled = true
	_go.pressed.connect(func() -> void: _finish_host(_selected))
	footer.add_child(_go)
	var refuse := W.button(L.t("door.refuse"), &"Danger")
	refuse.pressed.connect(func() -> void: _finish_host([]))
	footer.add_child(refuse)
	_knock_sequence(seat.knockers().size())


func _toggle(gid: int, cap: int) -> void:
	if _selected.has(gid):
		_selected.erase(gid)
	else:
		if _selected.size() >= cap:
			_selected.pop_front()
		_selected.append(gid)
	for k: int in _rows:
		_rows[k].theme_type_variation = &"RowOn" if _selected.has(k) else &"Row"
		_rows[k].text = L.t("door.admitting") if _selected.has(k) else L.t("door.admit")
	_go.disabled = _selected.is_empty()


func _finish_host(ids: Array[int]) -> void:
	if is_locked():
		return
	if ids.is_empty():
		open_fx.emit(0.0)
		Juice.haptic(Juice.Haptic.REFUSE)
		Sfx.play(&"door_shut")
		Juice.shake(self, 10.0)
	else:
		open_fx.emit(0.38)
		Juice.haptic(Juice.Haptic.SUCCESS)
		Sfx.play(&"door_open")
	commit(Intent.ADMIT, {"ids": ids.duplicate()})


## Время вышло: не решил — дверь осталась закрытой.
func on_clock_expired() -> void:
	match role:
		Match.DoorRole.HOST: _finish_host([])
		Match.DoorRole.GUEST: _send_plea("")
		_: commit(Intent.ADMIT, {"ids": [] as Array[int]})


# ---------------------------------------------------------------
func _build_guest() -> void:
	_box.add_child(W.label(L.t("door.locked", {"house": m.house_name(seat.house), "who": seat.host}), &"Tale"))
	var rivals := PackedStringArray()
	for g: Villager in seat.queue:
		if not g.is_player:
			rivals.append(g.name)
	if not rivals.is_empty():
		_box.add_child(W.label(L.t("door.rivals", {"list": L.t("list.sep").join(rivals)}), &"Hint"))
	if seat.mimic != null:
		_box.add_child(W.label(L.t("door.mimic", {"voice": seat.mimic}), &"Hint"))
	_box.add_child(W.label(L.t("door.say"), &"Small"))

	for p: Dictionary in Phrases.player_pleas():
		var b := W.button(p.label, &"Row")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pid: String = p.id
		b.pressed.connect(func() -> void: _send_plea(pid))
		_box.add_child(b)
	_knock_sequence(1)


func _send_plea(plea_id: String) -> void:
	commit(Intent.PLEA, {"plea": plea_id})


## Nav вызывает, когда хозяин решил. Пауза, стук, засов — или шаги прочь.
func show_guest_result(admitted: bool) -> void:
	W.clear(_box)
	var t := W.label(L.t("door.knock", {"house": m.house_name(seat.house)}), &"Tale")
	_box.add_child(t)
	for i in range(3):
		knock_fx.emit()
		Juice.haptic(Juice.Haptic.KNOCK)
		Sfx.play(&"knock", randf_range(0.92, 1.06))
		Sfx.play(&"knock", 1.0 + 0.04 * i)
		Juice.shake(self, 6.0, 0.2)
		await Juice.wait(0.55)
	await Juice.wait(0.6)
	if admitted:
		open_fx.emit(0.4)
		Juice.haptic(Juice.Haptic.SUCCESS)
		Sfx.play(&"door_open")
		t.text = L.t("door.let_in", {"who": seat.host})
	else:
		open_fx.emit(0.0)
		Juice.haptic(Juice.Haptic.REFUSE)
		Sfx.play(&"door_shut")
		Juice.shake(self, 14.0, 0.4)
		t.text = L.t("door.shut")
	Juice.pop_in(t)
	if not admitted and m.tunnel_to(seat.house) >= 0 and m.tunnel_room(seat.house):
		var to := m.house_name(m.tunnel_to(seat.house))
		_box.add_child(W.label(L.t("door.hatch", {"house": to}), &"Hint"))
		var hole := W.button(L.t("door.tunnel", {"house": to}))
		hole.name = "Tunnel"
		hole.pressed.connect(func() -> void: commit(Intent.TUNNEL))
		footer.add_child(hole)
	var next := W.button(L.t("door.wait"), &"Ghost" if not admitted and m.tunnel_room(seat.house) else &"Primary")
	next.pressed.connect(func() -> void: commit(Intent.CONTINUE))
	footer.add_child(next)
	_locked = false
	result_shown = true


# ---------------------------------------------------------------
func _build_alone() -> void:
	_box.add_child(W.label(L.t("door.alone", {"house": m.house_name(seat.house)}), &"Tale"))
	_box.add_child(W.label(
		L.t("door.alone_upyr") if m.player().is_upyr else L.t("door.alone_human"), &"Hint"))
	var next := W.button(L.t("door.wait"))
	next.pressed.connect(func() -> void: commit(Intent.ADMIT, {"ids": [] as Array[int]}))
	footer.add_child(next)


func _knock_sequence(n: int) -> void:
	await Juice.wait(0.5)
	for i in range(clampi(n, 1, 3)):
		if not is_instance_valid(self) or is_locked():
			return
		knock_fx.emit()
		Juice.haptic(Juice.Haptic.KNOCK)
		Juice.shake(self, 7.0, 0.22)
		await Juice.wait(0.45)


func ambience() -> StringName:
	return &"amb_night"


func music() -> StringName:
	return &""


func heart() -> bool:
	return true
