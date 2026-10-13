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
var _seats: HBoxContainer     ## свободные места значками: занятые светятся


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
	# до первого решения — одна строка и значки; пояснения под «Подробнее»
	var head := W.icon_line("knock", L.t("door.host_short"), &"Tale", 52)
	head.add_child(W.more(self, _host_info))
	_box.add_child(head)
	var cap := m.config.capacity - 1
	_seats = W.hbox(6)
	_seats.name = "Seats"
	for i in range(cap):
		_seats.add_child(Glyph.make("seat", 40, ThemeFactory.LAMP))
	if m.player().is_upyr:
		_seats.add_child(W.gap(10))
		_seats.add_child(Glyph.make("fang", 40, ThemeFactory.BLOOD))
	_box.add_child(_seats)

	for g: Villager in seat.knockers():
		var card := W.panel(&"Card")
		card.set_meta("action", true)       # карточка стучащего — сама кнопка выбора
		var row := W.hbox(14)
		var texts := W.vbox(4)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(W.label(g.name, &"Body"))
		texts.add_child(W.label(L.t("door.quote", {"text": pleas.get(g.id, "…")}), &"Small"))
		row.add_child(texts)
		var b := W.button(L.t("door.admit"), &"Row")
		b.custom_minimum_size = Vector2(200, ThemeFactory.TOUCH)
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING   # крупный текст: кнопка шире, имя переносится
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var gid := g.id
		b.pressed.connect(func() -> void: _toggle(gid, cap))
		_rows[gid] = b
		row.add_child(b)
		card.add_child(row)
		_box.add_child(card)

	_go = W.button(L.t("door.open"))
	_go.disabled = true
	_go.pressed.connect(func() -> void: _finish_host(_selected))
	footer.add_child(_go)
	var refuse := W.button(L.t("door.refuse"), &"Danger")
	refuse.pressed.connect(func() -> void: _finish_host([]))
	footer.add_child(refuse)
	_knock_sequence(seat.knockers().size())


## «Подробнее» у хозяина: чей дом, сколько мест, кто у других дверей, чем грозит отказ.
func _host_info() -> Array:
	var elsewhere := PackedStringArray()
	for other: Match.Seat in m.seats:
		if other == seat:
			continue
		for v: Villager in [other.host] + other.queue:
			if not v.is_player:
				elsewhere.append(v.name)
	var upyr := m.player().is_upyr
	return [["knock", L.t("door.host", {"house": m.house_name(seat.house)})],
		["seat", L.t("door.cap", {"n": m.config.capacity - 1})],
		["people", "" if elsewhere.is_empty() else L.t("door.elsewhere", {"list": L.t("list.sep").join(elsewhere)})],
		["fang" if upyr else "alone", L.t("door.upyr_note") if upyr else L.t("door.alone_note")],
		["info", L.t("door.hint_host")]]


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
	var i := 0
	for c: Node in _seats.get_children():
		if c is Glyph and (c as Glyph).kind.begins_with("seat"):
			(c as Glyph).set_kind("seat_on" if i < _selected.size() else "seat")
			i += 1


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
	var head := W.icon_line("lock", L.t("door.locked_short", {"who": seat.host}), &"Tale", 52)
	head.add_child(W.more(self, _guest_info))
	_box.add_child(head)
	if seat.mimic != null:
		_box.add_child(W.icon_line("mimic", L.t("door.mimic_short", {"voice": seat.mimic}), &"Hint"))
	for p: Dictionary in Phrases.player_pleas():
		var b := W.wrap(W.button(p.label, &"Row"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pid: String = p.id
		b.pressed.connect(func() -> void: _send_plea(pid))
		_box.add_child(b)
	_knock_sequence(1)


func _guest_info() -> Array:
	var rivals := PackedStringArray()
	for g: Villager in seat.queue:
		if not g.is_player:
			rivals.append(g.name)
	return [["lock", L.t("door.locked", {"house": m.house_name(seat.house), "who": seat.host})],
		["people", "" if rivals.is_empty() else L.t("door.rivals", {"list": L.t("list.sep").join(rivals)})],
		["mimic", "" if seat.mimic == null else L.t("door.mimic", {"voice": seat.mimic})],
		["info", L.t("door.say") + " " + L.t("door.hint_guest")]]


func _send_plea(plea_id: String) -> void:
	commit(Intent.PLEA, {"plea": plea_id})


## Удары в записи стука (assets/sfx/knock.ogg): пауза перед каждым, с.
const KNOCK_BEATS: Array[float] = [0.08, 0.14, 0.15]


## Nav вызывает, когда хозяин решил. Пауза, стук, засов — или шаги прочь.
func show_guest_result(admitted: bool) -> void:
	W.clear(_box)
	var line := W.icon_line("knock", L.t("door.knock", {"house": m.house_name(seat.house)}), &"Tale", 52)
	var g: Glyph = line.get_child(0)
	var t: Label = line.get_child(1)
	_box.add_child(line)
	# в записи три удара подряд: дверь вздрагивает в такт каждому
	Sfx.play(&"knock", randf_range(0.96, 1.04))
	for gap: float in KNOCK_BEATS:
		await Juice.wait(gap)
		knock_fx.emit()
		Juice.haptic(Juice.Haptic.KNOCK)
		Juice.shake(self, 6.0, 0.12)
	await Juice.wait(1.1)
	if admitted:
		open_fx.emit(0.4)
		Juice.haptic(Juice.Haptic.SUCCESS)
		Sfx.play(&"door_open")
		t.text = L.t("door.let_in", {"who": seat.host})
		g.col = ThemeFactory.LAMP
		g.set_kind("safe")
	else:
		open_fx.emit(0.0)
		Juice.haptic(Juice.Haptic.REFUSE)
		Sfx.play(&"door_shut")
		Juice.shake(self, 14.0, 0.4)
		t.text = L.t("door.shut")
		g.col = ThemeFactory.BLOOD
		g.set_kind("street")
	g.queue_redraw()
	Juice.pop_in(line)
	if not admitted and m.tunnel_to(seat.house) >= 0 and m.tunnel_room(seat.house):
		var to := m.house_name(m.tunnel_to(seat.house))
		_box.add_child(W.icon_line("tunnel", L.t("door.hatch", {"house": to}), &"Hint"))
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
	var head := W.icon_line("alone", L.t("door.alone_short"), &"Tale", 52)
	head.add_child(W.more(self, func() -> Array: return [
		["door", L.t("door.alone", {"house": m.house_name(seat.house)})],
		["fang" if m.player().is_upyr else "talisman_cracked", L.t("door.alone_upyr") if m.player().is_upyr else L.t("door.alone_human")],
		["info", L.t("door.hint_alone")]]))
	_box.add_child(head)
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
	return &"night"


func heart() -> bool:
	return true
