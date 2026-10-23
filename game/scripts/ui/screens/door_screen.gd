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
var _bolt: BoltSwipe
var _peep_origin: Dictionary = {}     ## id стучащего -> где началось касание портрета
var _box: VBoxContainer       ## содержимое двери на тёмной подложке
var _seats: HBoxContainer     ## свободные места значками: занятые светятся
var _asked := false            ## вопрос «Кто там?» — один за ночь (TASK-013)
var _ask_rows: Dictionary[int, Button] = {}
var _name_labels: Dictionary[int, Label] = {}
var _portraits: Dictionary[int, Control] = {}
var _touched := false          ## игрок что-то сделал у двери: повторный стук больше не нужен
const IDLE_KNOCK := 5.5        ## молчишь у двери — через столько секунд стучат снова
const IDLE_KNOCKS := 3


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
		portrait.mouse_filter = Control.MOUSE_FILTER_STOP     # глазок: тап по портрету осматривает (TASK-072)
		var peep_id := g.id
		portrait.gui_input.connect(func(event: InputEvent) -> void: _on_peep_input(event, peep_id))
		portrait.draw.connect(func() -> void:
			portrait.draw_rect(Rect2(Vector2.ZERO, portrait.size), Color("171f27"))
			portrait.draw_rect(Rect2(101, 0, 31, portrait.size.y), Color("433c32"))
			portrait.draw_line(Vector2(100, 0), Vector2(100, portrait.size.y), Color("93704c"), 1.4)
			# глазок в двери: латунное кольцо с тёмной серединой
			portrait.draw_circle(Vector2(116, 60), 9.0, Color("120f0b"))
			portrait.draw_arc(Vector2(116, 60), 9.0, 0.0, TAU, 20, Color("c9a15a"), 2.4))
		# за дверью идёт погода главы: снег зимой, дождь осенью (TASK-068)
		var outside := WeatherOverlay.new()
		outside.position = Vector2.ZERO
		outside.size = Vector2(100, 178)
		outside.apply(Weather.for_match(m, Match.Phase.DOOR), 1.0)
		portrait.add_child(outside)
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
		portrait.add_child(_peep_vignette())
		row.add_child(portrait)
		var texts := W.vbox(4)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fog := m.night_event == Match.Event.FOG
		var name_l := W.label(L.t("door.fog_voice") if fog else g.name, &"Body")
		_name_labels[g.id] = name_l
		texts.add_child(name_l)
		if m.vouch_on and m.voucher_of(g.id, 0) >= 0 and g != seat.mimic:
			var vl := W.label(L.t("vouch.door"), &"Hint")          # «Ворота»: вписан в книгу — входит (TASK-026)
			vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			texts.add_child(vl)
		_portraits[g.id] = portrait
		if fog:
			portrait.modulate = Color(0.8, 0.85, 0.9, 0.3)     # в тумане лица не видно (TASK-016)
		texts.add_child(W.label(L.t("door.quote", {"text": pleas.get(g.id, "…")}), &"Small"))
		var mem := fog and director != null and not director.shared_memory(g).is_empty()
		var ask := W.button(L.t("door.mem_ask") if mem else L.t("door.ask"), &"Ghost")
		ask.name = "Ask_%d" % g.id
		ask.custom_minimum_size = Vector2(0, ThemeFactory.TOUCH)
		var aid := g.id
		ask.pressed.connect(func() -> void: choose_question(aid))
		_ask_rows[g.id] = ask
		texts.add_child(ask)
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
	# засов (TASK-071): тот же результат жестом; тап по кнопке работает как раньше
	_bolt = BoltSwipe.new()
	_bolt.name = "Bolt"
	_bolt.target = _go
	_go.add_child(_bolt)
	var refuse := W.button(L.t("door.refuse"), &"Danger")
	refuse.pressed.connect(func() -> void: _finish_host([]))
	footer.add_child(refuse)
	_start_knocks()


## Первая ночь главы «Стук» (TASK-011, TASK-013): сначала река и зов с того берега, потом темнота и стук.
## В остальные ночи — сразу стук. Молчишь у двери — стучат снова.
func _start_knocks() -> void:
	if String(Game.chapter.get("id", "")) == "a1c1" and m.day == 1 and not Game.opening_done:
		Game.opening_done = true
		var choice: String = await ScenePlayer.play(self, Scenes.river(m), m)
		if not is_instance_valid(self):
			return
		if choice == "answer" and director != null:
			director.river_answered()
		await ScenePlayer.play(self, Scenes.first_knock(choice == "answer"), m)
		if not is_instance_valid(self):
			return
	_knock_sequence(seat.knockers().size())
	_idle_knock()


func _idle_knock() -> void:
	for i in range(IDLE_KNOCKS):
		await Juice.wait(IDLE_KNOCK)
		if not is_instance_valid(self) or is_locked() or _touched or not _selected.is_empty() or Juice.instant:
			return
		knock_fx.emit()
		Sfx.play(&"knock", randf_range(0.94, 1.02), -2.0)
		Juice.haptic(Juice.Haptic.KNOCK)
		for f: VillagerFigure in _visitor_figures.values():
			if is_instance_valid(f):
				f.knock()


## «Кто там?» (TASK-013): один вопрос за ночь. Ответ зависит от того, кто стучит, но не выдаёт его наверняка.
func choose_question(gid: int) -> void:
	if _asked or is_locked():
		return
	var g := m.get_villager(gid)
	var can_ask_past := m.question_tokens > 0 and m.question_used_day != m.day \
		and m.night_event != Match.Event.FOG and director != null and not director.shared_memory(g).is_empty()
	if not can_ask_past:
		ask_who(gid)
		return
	var options := PackedStringArray([L.t("door.ask_choice_who"), L.t("door.ask_choice_past", {"n": m.question_tokens})])
	var choice: int = await ActionSheet.ask(self, L.t("door.ask_choice"), options)
	if not is_instance_valid(self) or is_locked():
		return
	if choice == 0:
		ask_who(gid)
	elif choice == 1:
		ask_past(gid)


## Жетон позволяет проверить общую память с посетителем. Ответ ненадёжен и звучит как обычная реплика.
func ask_past(gid: int) -> void:
	if _asked or is_locked() or director == null:
		return
	var g := m.get_villager(gid)
	if g == null or director.shared_memory(g).is_empty() or not m.spend_question_token():
		return
	_asked = true
	_touched = true
	var note: Label = _observations.get(gid)
	if is_instance_valid(note):
		var answer := director.token_memory_answer(g, seat)
		note.text = answer if note.text.is_empty() else note.text + "\n" + answer
		note.visible = true
	for b: Button in _ask_rows.values():
		b.disabled = true
	var figure: VillagerFigure = _visitor_figures.get(gid)
	if is_instance_valid(figure):
		figure.knock()


func ask_who(gid: int) -> void:
	if _asked or is_locked():
		return
	var g := m.get_villager(gid)
	if g == null and seat.mimic != null and seat.mimic.id == gid:
		g = seat.mimic
	if g == null:
		return
	_asked = true
	_touched = true
	var answer := director.door_answer(g, seat) if director != null else ""
	# туман: если днём был разговор, вопрос о нём, и голос либо помнит, либо сбивается (TASK-016)
	if m.night_event == Match.Event.FOG and director != null:
		var mem := director.memory_answer(g, seat)
		if not mem.is_empty():
			answer = String(mem.text) + "\n" + L.t("door.mem_ok" if bool(mem.ok) else "door.mem_bad")
		var name_l: Label = _name_labels.get(gid)
		if is_instance_valid(name_l):
			name_l.text = L.t("door.fog_claim", {"me": g})
		var pic: Control = _portraits.get(gid)
		if is_instance_valid(pic):
			pic.modulate = Color(1, 1, 1, 0.7)
	var note: Label = _observations.get(gid)
	if is_instance_valid(note):
		note.text = answer if note.text.is_empty() else note.text + "\n" + answer
		note.visible = true
	for b: Button in _ask_rows.values():
		b.disabled = true
	var figure: VillagerFigure = _visitor_figures.get(gid)
	if is_instance_valid(figure):
		figure.knock()


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
	_touched = true
	if _inspection_left <= 0 or _inspected.has(gid):
		return
	emit_intent(Intent.DOOR_INSPECT, {"id": gid})


## Глазок (TASK-072): тап по портрету стучащего — это осмотр. Тратит ту же попытку и показывает ту же
## примету, что кнопка «осмотреть»; обе дороги идут через _inspect и пишут одну запись.
func _on_peep_input(event: InputEvent, gid: int) -> void:
	if not (event is InputEventMouseButton) or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var b := event as InputEventMouseButton
	if b.pressed:
		_peep_origin[gid] = b.position
		return
	if not _peep_origin.has(gid):
		return
	var moved := b.position.distance_to(_peep_origin[gid]) > 14.0
	_peep_origin.erase(gid)
	if moved or _inspected.has(gid):
		return
	if _inspection_left <= 0:
		Juice.haptic(Juice.Haptic.REFUSE)
		return
	_inspect(gid)


## Тёмные края круглого окошка: радиальный градиент, который рисует движок.
func _peep_vignette() -> TextureRect:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.34, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.9), Color(0, 0, 0, 0.9)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var vg := TextureRect.new()
	vg.name = "Vignette"
	vg.texture = tex
	vg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# квадрат, чтобы окошко было круглым; центр на лице, всё за кругом темнеет (портрет обрезает лишнее)
	vg.size = Vector2(420, 420)
	vg.position = Vector2(50.0 - 210.0, 62.0 - 210.0)
	vg.modulate.a = 0.0
	return vg


## Приближение лица и виньетка после осмотра: смотришь через глазок.
func _peep_fx(gid: int) -> void:
	var figure: VillagerFigure = _visitor_figures.get(gid)
	var portrait: Control = _portraits.get(gid)
	if not is_instance_valid(figure) or not is_instance_valid(portrait):
		return
	var zoom := figure.scale * 1.22
	var lowered := figure.position + Vector2(0, 30)
	var vg := portrait.get_node_or_null("Vignette") as TextureRect
	if Juice.instant:
		figure.scale = zoom
		figure.position = lowered
		if vg != null:
			vg.modulate.a = 1.0
		return
	var tw := Juice.tween().set_parallel(true)
	tw.tween_property(figure, "scale", zoom, 0.35)
	tw.tween_property(figure, "position", lowered, 0.35)
	if vg != null:
		tw.tween_property(vg, "modulate:a", 1.0, 0.35)


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
		var details := PackedStringArray([L.fill(SocialContent.door_sign(tell, m.day * 31 + identity.id * 7), {"who": identity})])
		var note_record := m.door_note_for(visitor)
		if not note_record.is_empty():
			var note_a := m.get_villager(int(note_record.get("a", -1)))
			var note_b := m.get_villager(int(note_record.get("b", -1)))
			if note_a != null and note_b != null:
				details.append(SocialContent.door_box_note(int(note_record.get("day", 0)), note_a.name, note_b.name))
		var remembered := remembered_story(identity)
		if not remembered.is_empty():
			details.append(remembered)
		# биография одна и та же каждую ночь: у двери полезнее то, что было в эту партию
		var fixed := PackedStringArray()
		var known_story_step := maxi(identity.story_step, int(Save.storybook.get(Progress.story_key(identity), -1)))
		if not identity.is_player and identity.story_id >= 0:
			fixed.append(SocialContent.person_title(identity))
			fixed.append(SocialContent.story(identity.story_id, identity))
			for step in range(1, known_story_step + 1):
				fixed.append(SocialContent.personal_chapter(identity, step))
		var fresh := PackedStringArray()
		for fact: String in known:
			if fact != L.t("diary.nothing") and fact != SocialContent.door_record(m.day, tell) and not fixed.has(fact):
				fresh.append(fact)
		if fresh.is_empty() and not fixed.is_empty():
			fresh.append(fixed[0])          # о человеке ничего не известно: хотя бы кто это
		for fact: String in fresh:
			if details.size() >= 3:
				break
			details.append(fact)
		note.text = "\n".join(details)
		note.visible = true
	var figure: VillagerFigure = _visitor_figures.get(gid)
	if is_instance_valid(figure):
		figure.knock()
	_peep_fx(gid)
	var button: Button = _inspect_rows.get(gid)
	if is_instance_valid(button):
		button.text = SocialContent.door_ui("done")
		button.disabled = true
	for other_id: int in _inspect_rows:
		var other: Button = _inspect_rows[other_id]
		if not _inspected.has(other_id):
			other.text = "%s · %d" % [SocialContent.door_ui("inspect"), _inspection_left]
			other.disabled = _inspection_left <= 0


static func remembered_story(identity: Villager) -> String:
	if identity == null or identity.is_player:
		return ""
	var step := maxi(identity.story_step, int(Save.storybook.get(Progress.story_key(identity), -1)))
	if step < 2:
		return ""
	var text := SocialContent.personal_chapter(identity, step - 1)
	return L.fill(SocialContent.door_ui("remembered"), {"text": text}) if not text.is_empty() else ""


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
	# за дверью дышат: в первую ночь всегда, потом изредка (TASK-013)
	if is_instance_valid(self) and not is_locked() and (String(Game.chapter.get("id", "")) == "a1c1" or randf() < 0.3):
		Sfx.play(&"breath", 1.0, -9.0)


func ambience() -> StringName:
	return &"amb_night"


func music() -> StringName:
	return &"night"


func heart() -> bool:
	return true
