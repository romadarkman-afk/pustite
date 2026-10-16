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
var dilemma: Dictionary = {}      ## Match.door_dilemma: выбор с ценой этой ночью
var result_shown := false
var _selected: Array[int] = []
var _rows: Dictionary[int, Button] = {}
var _inspect_rows: Dictionary[int, Button] = {}
var _visitor_figures: Dictionary[int, VillagerFigure] = {}
var _observations: Dictionary[int, Label] = {}
var _inspected: Dictionary[int, bool] = {}
var _inspection_left := 2
var _portrait_used: Dictionary = {}
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
	Dread.door(self)


# ---------------------------------------------------------------
func _build_host() -> void:
	_inspection_left = 2 + Game.inspection_bonus
	Sfx.set_heartbeat_pace(1.0 + 0.04 * float(mini(seat.knockers().size() - 1, 3)))
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
	if not dilemma.is_empty():
		_box.add_child(dilemma_card(m, dilemma))

	for g: Villager in seat.knockers():
		var card := W.panel(&"Card")
		card.name = "Knocker_%d" % g.id
		card.set_meta("action", true)       # карточка стучащего — сама кнопка выбора
		var col := W.vbox(10)
		var row := W.hbox(14)
		var portrait := Control.new()
		portrait.name = "Portrait_%d" % g.id
		portrait.custom_minimum_size = Vector2(132, 178)
		portrait.clip_contents = true
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.draw.connect(func() -> void:
			portrait.draw_rect(Rect2(Vector2.ZERO, portrait.size), Color("171f27"))
			portrait.draw_rect(Rect2(101, 0, 31, portrait.size.y), Color("433c32"))
			portrait.draw_line(Vector2(100, 0), Vector2(100, portrait.size.y), Color("93704c"), 1.4))
		var figure := VillagerFigure.new()
		var looks := L.looks()
		var look := looks.for_name(g.name, false).duplicate() as LookDef
		look.female = g.female
		look.age = 0 if g.age < 28 else (2 if g.age >= 55 else 1)
		figure.setup(g.name, look, false)
		figure.sprite_id = VillagerFigure.pick_cast_sprite(g, _portrait_used)
		if Nav.village != null and Nav.village.crowd != null:
			var on_field: VillagerFigure = Nav.village.crowd.figures.get(g.id)
			if on_field == null:
				for known_figure: VillagerFigure in Nav.village.crowd.figures.values():
					if known_figure.who == g.name:
						on_field = known_figure
						break
			if is_instance_valid(on_field):
				figure.sprite_id = on_field.sprite_id
				figure.set_identity_color(on_field.identity_id)
		figure.scale = Vector2.ONE * (2.25 / look.height)
		figure.position = Vector2(46, 205)
		figure.modulate = Color(0.72, 0.78, 0.88)
		figure.door_portrait = true
		figure.door_tell = m.door_sign_for(g, seat)
		figure.tag.visible = false
		figure.set_cold(true)
		portrait.add_child(figure)
		_visitor_figures[g.id] = figure
		row.add_child(portrait)
		var texts := W.vbox(4)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(W.label(g.name, &"Body"))
		texts.add_child(W.label(L.t("door.quote", {"text": pleas.get(g.id, "…")}), &"Small"))
		var observation := W.label("", &"Hint")
		observation.name = "Observation_%d" % g.id
		observation.visible = false
		texts.add_child(observation)
		_observations[g.id] = observation
		row.add_child(texts)
		var inspect := W.button("%s · %d" % [SocialContent.door_ui("inspect"), _inspection_left], &"Ghost")
		inspect.name = "Inspect_%d" % g.id
		inspect.custom_minimum_size = Vector2(132, ThemeFactory.TOUCH)
		var gid := g.id
		inspect.pressed.connect(func() -> void: _inspect(gid))
		_inspect_rows[gid] = inspect
		var b := W.button(L.t("door.admit"), &"Row")
		b.name = "Admit_%d" % g.id
		b.custom_minimum_size = Vector2(132, ThemeFactory.TOUCH)
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING   # крупный текст: кнопка шире, имя переносится
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: _toggle(gid, cap))
		_rows[gid] = b
		col.add_child(row)
		col.add_child(W.fit_row([inspect, b], 8))
		card.add_child(col)
		_box.add_child(card)
	for record: Dictionary in m.door_inspections:
		if int(record.day) == m.day and _visitor_figures.has(int(record.villager)):
			show_inspection(int(record.villager), StringName(record.tell))

	_go = W.button(L.t("door.open"))
	_go.disabled = true
	_go.pressed.connect(func() -> void: _finish_host(_selected))
	footer.add_child(_go)
	var refuse := W.button(L.t("door.refuse"), &"Danger")
	refuse.pressed.connect(func() -> void: _finish_host([]))
	footer.add_child(refuse)
	_knock_sequence(seat.knockers().size())


## Дилемма: что за выбор и чем он грозит. Текст на всех языках — ключи dil.<вид> и dil.<вид>_cost.
const DILEMMA_ICON := {"couple": "pact", "refuser": "lock", "voted": "people", "accuser": "liar",
	"grieving": "skull", "crowd": "seat", "oil": "talisman"}


static func dilemma_card(mm: Match, d: Dictionary) -> PanelContainer:
	var card := W.panel(&"Sheet")
	card.name = "Dilemma"
	card.set_meta("dilemma", String(d.kind))
	var box := W.vbox(6)
	card.add_child(box)
	var args := dilemma_args(mm, d)
	var icon: String = DILEMMA_ICON.get(String(d.kind), "info")
	box.add_child(W.icon_line(icon, L.t("dil." + String(d.kind), args), &"Body", 40, ThemeFactory.LAMP))
	box.add_child(W.label(L.t("dil." + String(d.kind) + "_cost", args), &"Hint"))
	return card


static func dilemma_args(mm: Match, d: Dictionary) -> Dictionary:
	var who := mm.get_villager(int(d.who))
	var other: Villager = mm.get_villager(int(d.other)) if int(d.get("other", -1)) >= 0 else null
	var args := {"who": who, "house": mm.house_name(int(d.get("house", 0))), "n": mm.config.capacity - 1}
	if other != null:
		args["other"] = other
		args["lost"] = other
	return args


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
		["info", SocialContent.door_ui("limit")],
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


func _inspect(gid: int) -> void:
	if _inspection_left <= 0 or _inspected.has(gid):
		return
	emit_intent(Intent.DOOR_INSPECT, {"id": gid})


func show_inspection(gid: int, tell: StringName) -> void:
	if _inspected.has(gid):
		return
	var visitor := m.get_villager(gid)
	if visitor == null and seat.mimic != null and seat.mimic.id == gid:
		visitor = seat.mimic
	if visitor == null:
		return
	_inspected[gid] = true
	_inspection_left -= 1
	var note: Label = _observations.get(gid)
	if is_instance_valid(note):
		var identity := visitor
		if visitor == seat.mimic:
			for known_person: Villager in m.villagers:
				if known_person.name == visitor.name:
					identity = known_person
					break
		var known := DiarySheet.facts(m, director, identity)
		var details := PackedStringArray([SocialContent.door_sign(tell)])
		for fact: String in known:
			if fact != L.t("diary.nothing") and fact != SocialContent.door_record(m.day, tell):
				details.append(fact)
			if details.size() >= 3:
				break
		note.text = "\n".join(details)
		note.visible = true
	var figure: VillagerFigure = _visitor_figures.get(gid)
	if is_instance_valid(figure):
		figure.knock()
	var button: Button = _inspect_rows.get(gid)
	if is_instance_valid(button):
		button.text = SocialContent.door_ui("done")
		button.disabled = true
	for other_id: int in _inspect_rows:
		var other: Button = _inspect_rows[other_id]
		if not _inspected.has(other_id):
			other.text = "%s · %d" % [SocialContent.door_ui("inspect"), _inspection_left]
			other.disabled = _inspection_left <= 0


func _finish_host(ids: Array[int]) -> void:
	if is_locked():
		return
	if ids.is_empty():
		open_fx.emit(0.0)
		Juice.haptic(Juice.Haptic.REFUSE)
		Sfx.play(&"door_shut")
		Juice.shake(self, 10.0)
		if not seat.knockers().is_empty():
			Dread.refused(self)
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
	if _visitor_figures.is_empty():
		for i in range(clampi(n, 1, 3)):
			if not is_instance_valid(self) or is_locked():
				return
			knock_fx.emit()
			Juice.haptic(Juice.Haptic.KNOCK)
			await Juice.wait(0.45)
		return
	for visitor: Villager in seat.knockers():
		var figure: VillagerFigure = _visitor_figures.get(visitor.id)
		var precise_rhythm := is_instance_valid(figure) and figure.door_tell == &"rhythm"
		for beat in range(3):
			if not is_instance_valid(self) or is_locked():
				return
			if beat == 0:
				knock_fx.emit()
			if is_instance_valid(figure):
				figure.knock()
			Juice.haptic(Juice.Haptic.KNOCK)
			await Juice.wait(0.15 if precise_rhythm else KNOCK_BEATS[beat])
		await Juice.wait(0.65)


func ambience() -> StringName:
	return &"amb_night"


func music() -> StringName:
	return &"night"


func heart() -> bool:
	return true
