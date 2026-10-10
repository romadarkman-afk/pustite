class_name DayScreen
extends Screen
## День. Картинка главнее текста: поле занимает 60% экрана, разговор идёт пузырями
## над головами, жители выбираются тапом по полю. Журнал свёрнут в одну строку
## и раскрывается по касанию — чтобы перечитать, кто что говорил.

var journal_button: Button
var supplies: SuppliesBadge
var journal_preview: Label


func screen_id() -> String:
	return "day"


func field_ratio() -> float:
	return 0.60


## Под полем остаётся только строка журнала.
func min_content_ratio() -> float:
	return 0.04


## Поле резиновое: всё, что осталось после шапки, строки журнала и кнопок.
## На высоких телефонах картинка растёт, а не остаётся пустая полоса.
func field_height(h: float) -> float:
	var sep := float(get_theme_constant("separation", "VBoxContainer")) if has_theme_constant("separation", "VBoxContainer") else 18.0
	var reserved := 46.0 + footer.get_combined_minimum_size().y + ThemeFactory.TOUCH + 4.0 * sep + 24.0
	return maxf(h * 0.55, h - reserved)


func title() -> String:
	return L.t("when.day", {"n": m.day})


func mood() -> Vector2:
	return Vector2(0.12, 0.25)


func build() -> void:
	Diag.step("день-экран: сборка")
	enable_field_taps()
	if field_spacer != null:
		supplies = SuppliesBadge.new()
		field_spacer.add_child(supplies)
		supplies.position = Vector2(20, 64)
		update_supplies()
	var jr := W.hbox(10)
	journal_button = W.button(L.t("day.journal"), &"Quick")
	journal_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	journal_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	journal_button.pressed.connect(open_journal)
	jr.add_child(journal_button)
	var diary := W.button(L.t("day.diary"), &"Quick")
	diary.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	diary.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	diary.pressed.connect(open_diary)
	jr.add_child(diary)
	journal_preview = W.label("", &"Small")
	journal_preview.autowrap_mode = TextServer.AUTOWRAP_OFF
	journal_preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	journal_preview.clip_text = true
	journal_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	journal_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jr.add_child(journal_preview)
	body.add_child(jr)
	_update_journal()

	if not m.player().alive:
		body.add_child(W.label(L.t("day.dead"), &"Small"))
		var skip := W.button(L.t("day.skip"), &"Ghost")
		skip.pressed.connect(func() -> void: commit(Intent.END_DAY))
		footer.add_child(skip)
		return

	Diag.step("день-экран: чат готов, кнопки")
	var quick := W.hbox(8)
	for spec: Array in [[L.t("day.defend"), _defend], [L.t("day.invite"), _invite_flow], [L.t("day.accuse"), _accuse_flow]]:
		var q := W.button(spec[0], &"Quick")
		q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb: Callable = spec[1]
		q.pressed.connect(func() -> void: cb.call())
		quick.add_child(q)
	footer.add_child(quick)

	var row := W.hbox(8)
	var write := W.button(L.t("day.say"), &"Row")
	write.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	write.pressed.connect(_write_flow)
	row.add_child(write)
	if m.can_meeting(m.player()):
		var bell := W.button(L.t("day.bell"), &"Ghost")
		bell.name = "Meeting"
		bell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bell.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		bell.pressed.connect(_meeting_flow)
		row.add_child(bell)
	var ready_btn := W.button(L.t("day.ready"), &"Ghost")
	ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ready_btn.pressed.connect(func() -> void: commit(Intent.END_DAY))
	row.add_child(ready_btn)
	footer.add_child(row)


## Днём камера ближе: жители крупнее, камера идёт за тобой.
func field_zoom() -> float:
	return 1.3


func update_supplies() -> void:
	if is_instance_valid(supplies) and m != null:
		supplies.set_value(m.supply_done, m.supply_total)


func hint_id() -> String:
	return "day"


func hint_text() -> String:
	return L.t("day.hint")


func hint_target() -> Rect2:
	var f := field_rect_local()
	return Rect2(Vector2(f.get_center().x, f.end.y - 30.0), Vector2.ZERO)


func on_clock_expired() -> void:
	commit(Intent.END_DAY)


## Nav вызывает при каждой новой реплике.
func append_line(_line: ChatLine) -> void:
	_update_journal()


func open_journal() -> void:
	JournalSheet.open(self, m.chat)


func open_diary() -> DiarySheet:
	return DiarySheet.open(self, m, director)


## Экстренный сбор: удар в колокол днём. Спросить, точно ли — он один на партию.
func _meeting_flow() -> void:
	var i: int = await ActionSheet.ask(self, L.t("day.bell_ask"),
		PackedStringArray([L.t("day.bell_do")]))
	if i == 0:
		emit_intent(Intent.MEETING)


func _update_journal() -> void:
	if not is_instance_valid(journal_button):
		return
	journal_button.text = L.t("day.journal_n", {"n": m.chat.size()})
	var last: ChatLine = m.chat[m.chat.size() - 1] if not m.chat.is_empty() else null
	if last == null:
		journal_preview.text = ""
	elif last.kind == ChatLine.Kind.SYSTEM:
		journal_preview.text = last.text
	else:
		journal_preview.text = L.t("day.preview", {"who": L.t("you_name") if last.kind == ChatLine.Kind.MINE else last.speaker.name, "text": last.text})


func _write_flow() -> void:
	var t: String = await TextSheet.ask(self, L.t("day.say_aloud"), Phrases.quick_for(m))
	if not t.is_empty():
		emit_intent(Intent.SAY, {"text": t})


func _defend() -> void:
	emit_intent(Intent.DEFEND)


func person_actions(v: Villager) -> void:
	var ev := director.evidence_text(v) if director != null else ""
	var head := v.name if ev.is_empty() else L.t("day.person_ev", {"who": v.name, "ev": ev})
	var opts := PackedStringArray([
		L.t("day.p_accuse", {"who": v}),
		L.t("day.p_invite"),
		L.t("day.p_ask"),
	])
	var me := m.player()
	if me.role == Match.Role.ELDER and not me.role_used:
		opts.append(L.t("day.p_elder", {"who": v}))
	var i: int = await ActionSheet.ask(self, head, opts)
	match i:
		0: emit_intent(Intent.ACCUSE, {"id": v.id})
		1: _pick_house_for(v)
		2: emit_intent(Intent.ASK, {"id": v.id})
		3: emit_intent(Intent.ELDER, {"id": v.id})


## Игрок-упырь у дела, где сегодня уже работали: поработать по-настоящему или испортить сделанное.
func job_actions(ji: int) -> void:
	var j: JobDef = m.jobs[ji]
	var opts := PackedStringArray([L.t("day.work", {"job": j.title})])
	opts.append(L.t("day.spoil", {"place": j.place}))
	var i: int = await ActionSheet.ask(self, j.title, opts)
	if i >= 0:
		emit_intent(Intent.WORK, {"ji": ji, "sab": i == 1})


func _accuse_flow() -> void:
	var v := await _pick_person(L.t("day.who_accuse"))
	if v != null:
		emit_intent(Intent.ACCUSE, {"id": v.id})


func _invite_flow() -> void:
	var v := await _pick_person(L.t("day.who_invite"))
	if v != null:
		_pick_house_for(v)


func _pick_house_for(v: Villager) -> void:
	var h: int = await ActionSheet.ask(self, L.t("day.where_with", {"who": v}), m.houses)
	if h >= 0:
		emit_intent(Intent.INVITE, {"id": v.id, "house": h})


func _pick_person(question: String) -> Villager:
	var list := m.alive_bots()
	var names := PackedStringArray()
	for v: Villager in list:
		names.append(v.name)
	var i: int = await ActionSheet.ask(self, question, names)
	return list[i] if i >= 0 else null


func ambience() -> StringName:
	return &"amb_day"


func music() -> StringName:
	return &"day"
