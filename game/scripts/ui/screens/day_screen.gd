class_name DayScreen
extends Screen
## День. Главное отличие от v0.1: слова игрока имеют последствия.
## Тап по жителю → обвинить / позвать с собой / спросить. Печатать не обязательно —
## на телефоне это неудобно, поэтому все ключевые действия доступны в два касания.

const MAX_BUBBLES := 40

var chat_box: VBoxContainer


func screen_id() -> String:
	return "day"


func field_ratio() -> float:
	return 0.40


func title() -> String:
	return "День %d" % m.day


func mood() -> Vector2:
	return Vector2(0.12, 0.25)


func build() -> void:
	Diag.step("день-экран: сборка")
	body.add_child(people_strip(_person_actions))
	chat_box = W.vbox(12)
	body.add_child(chat_box)
	for line: ChatLine in m.chat.slice(maxi(0, m.chat.size() - MAX_BUBBLES)):
		chat_box.add_child(_bubble(line))
	scroll_to_end()

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
	var write := W.button("Написать своё…", &"Row")
	write.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	write.pressed.connect(_write_flow)
	row.add_child(write)
	var ready_btn := W.button("Я готов к ночи", &"Ghost")
	ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ready_btn.pressed.connect(func() -> void: commit(Intent.END_DAY))
	row.add_child(ready_btn)
	footer.add_child(row)


func on_clock_expired() -> void:
	commit(Intent.END_DAY)


## Nav вызывает при каждой новой реплике.
func append_line(line: ChatLine) -> void:
	if not is_instance_valid(chat_box):
		return
	var near_bottom := scroll.scroll_vertical >= int(scroll.get_v_scroll_bar().max_value - scroll.size.y - 120)
	var b := _bubble(line)
	chat_box.add_child(b)
	Juice.pop_in(b)
	while chat_box.get_child_count() > MAX_BUBBLES:
		chat_box.get_child(0).free()
	if near_bottom or line.kind == ChatLine.Kind.MINE:
		scroll_to_end()


## Журнал: компактная строка «Имя: текст» — чтобы перечитать, кто что говорил.
## Живой разговор идёт пузырями над головами на поле.
func _bubble(line: ChatLine) -> Control:
	if line.kind == ChatLine.Kind.SYSTEM:
		return W.label(line.text, &"Small")
	var row := W.hbox(8)
	var nm := W.label(("Вы" if line.kind == ChatLine.Kind.MINE else line.speaker.name) + ":", &"Speaker")
	nm.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	if line.kind == ChatLine.Kind.MINE:
		nm.add_theme_color_override("font_color", ThemeFactory.LAMP)
	var tx := W.label(line.text, &"Small")
	tx.add_theme_color_override("font_color", ThemeFactory.BONE)
	row.add_child(nm)
	row.add_child(tx)
	return row


func _write_flow() -> void:
	var t: String = await TextSheet.ask(self, "Сказать вслух")
	if not t.is_empty():
		emit_intent(Intent.SAY, {"text": t})


func _defend() -> void:
	emit_intent(Intent.DEFEND)


func _person_actions(v: Villager) -> void:
	var i: int = await ActionSheet.ask(self, v.name, PackedStringArray([
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
