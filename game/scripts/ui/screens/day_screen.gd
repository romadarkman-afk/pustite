class_name DayScreen
extends Screen
## День. Картинка главнее текста: поле занимает 60% экрана, разговор идёт пузырями
## над головами, жители выбираются тапом по полю. Журнал свёрнут в одну строку
## и раскрывается по касанию — чтобы перечитать, кто что говорил.

var journal_button: Button
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
	var reserved := 46.0 + footer.get_combined_minimum_size().y + ThemeFactory.TOUCH + 4.0 * sep + 8.0
	return maxf(h * 0.55, h - reserved)


func title() -> String:
	return "День %d" % m.day


func mood() -> Vector2:
	return Vector2(0.12, 0.25)


func build() -> void:
	Diag.step("день-экран: сборка")
	enable_field_taps()
	var jr := W.hbox(10)
	journal_button = W.button("Журнал", &"Quick")
	journal_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	journal_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	journal_button.pressed.connect(open_journal)
	jr.add_child(journal_button)
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
		body.add_child(W.label("Тебя больше нет. Ты только смотришь.", &"Small"))
		var skip := W.button("Пропустить день", &"Ghost")
		skip.pressed.connect(func() -> void: commit(Intent.END_DAY))
		footer.add_child(skip)
		return

	Diag.step("день-экран: чат готов, кнопки")
	var quick := W.hbox(8)
	for spec: Array in [["Оправдаться", _defend], ["Позвать…", _invite_flow], ["Обвинить…", _accuse_flow]]:
		var q := W.button(spec[0], &"Quick")
		q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb: Callable = spec[1]
		q.pressed.connect(func() -> void: cb.call())
		quick.add_child(q)
	footer.add_child(quick)

	var row := W.hbox(8)
	var write := W.button("Сказать…", &"Row")
	write.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	write.pressed.connect(_write_flow)
	row.add_child(write)
	var ready_btn := W.button("Я готов к ночи", &"Ghost")
	ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ready_btn.pressed.connect(func() -> void: commit(Intent.END_DAY))
	row.add_child(ready_btn)
	footer.add_child(row)


func hint_id() -> String:
	return "day"


func hint_text() -> String:
	return "Нажми на жителя на площади: обвини, позови с собой или спроси, где ночует."


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


func _update_journal() -> void:
	if not is_instance_valid(journal_button):
		return
	journal_button.text = "Журнал (%d)" % m.chat.size()
	var last: ChatLine = m.chat[m.chat.size() - 1] if not m.chat.is_empty() else null
	if last == null:
		journal_preview.text = ""
	elif last.kind == ChatLine.Kind.SYSTEM:
		journal_preview.text = last.text
	else:
		journal_preview.text = "%s: %s" % ["Вы" if last.kind == ChatLine.Kind.MINE else last.speaker.name, last.text]


func _write_flow() -> void:
	var t: String = await TextSheet.ask(self, "Сказать вслух", Phrases.quick_for(m))
	if not t.is_empty():
		emit_intent(Intent.SAY, {"text": t})


func _defend() -> void:
	emit_intent(Intent.DEFEND)


func person_actions(v: Villager) -> void:
	var ev := director.evidence_text(v) if director != null else ""
	var head := v.name if ev.is_empty() else "%s · %s" % [v.name, ev]
	var i: int = await ActionSheet.ask(self, head, PackedStringArray([
		"Обвинить: «Это %s»" % v.name,
		"Позвать с собой на ночь",
		"Спросить, где ночует",
	]))
	match i:
		0: emit_intent(Intent.ACCUSE, {"id": v.id})
		1: _pick_house_for(v)
		2: emit_intent(Intent.ASK, {"id": v.id})


func _accuse_flow() -> void:
	var v := await _pick_person("Кого обвинить?")
	if v != null:
		emit_intent(Intent.ACCUSE, {"id": v.id})


func _invite_flow() -> void:
	var v := await _pick_person("Кого позвать с собой?")
	if v != null:
		_pick_house_for(v)


func _pick_house_for(v: Villager) -> void:
	var h: int = await ActionSheet.ask(self, "Куда идёте с %s?" % v.name, m.houses)
	if h >= 0:
		emit_intent(Intent.INVITE, {"id": v.id, "house": h})


func _pick_person(question: String) -> Villager:
	var list := m.alive_bots()
	var names := PackedStringArray()
	for v: Villager in list:
		names.append(v.name)
	var i: int = await ActionSheet.ask(self, question, names)
	return list[i] if i >= 0 else null
