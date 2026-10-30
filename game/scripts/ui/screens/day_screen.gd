class_name DayScreen
extends Screen
## День. Поле занимает около половины экрана, разговор идёт пузырями
## над головами, жители выбираются тапом по полю. Журнал свёрнут в одну строку
## и раскрывается по касанию — чтобы перечитать, кто что говорил.

var journal_button: Button
var supplies: SuppliesBadge
var journal_preview: Label
var _question_prompt_open := false
var _contact_hint: Label

const ACTION_HEIGHT := 54


func screen_id() -> String:
	return "day"


func field_ratio() -> float:
	return 0.82


## Под полем остаётся только строка журнала.
func min_content_ratio() -> float:
	return 0.04


## Поле занимает до 72% экрана. Подвал и строка журнала остаются на экране, а свободная высота уходит карте.
func field_height(h: float) -> float:
	var sep := float(chrome.get_theme_constant("separation")) if chrome != null else 18.0
	var bar := 0.0
	if chrome != null and chrome.get_child_count() > 0 and title() != "":
		bar = (chrome.get_child(0) as Control).get_combined_minimum_size().y
	# шапка, строка журнала (одна кнопка), подвал и три промежутка колонки
	var reserved := bar + footer.get_combined_minimum_size().y + float(ThemeFactory.COMPACT_TOUCH) + 3.0 * sep + 8.0
	return maxf(h * 0.34, minf(h * 0.82, h - reserved))


func title() -> String:
	return L.t("when.day", {"n": m.day})


func mood() -> Vector2:
	return Vector2(0.12, 0.25)


func build() -> void:
	Diag.step("день-экран: сборка")
	footer.add_theme_constant_override("separation", 6)
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", ThemeFactory.fs(17))
	if _clock != null:
		_clock.add_theme_font_size_override("font_size", ThemeFactory.fs(17))
	var back := find_child("BackToMenu", true, false) as Button
	if back != null:
		back.custom_minimum_size.y = ACTION_HEIGHT
		back.add_theme_font_size_override("font_size", ThemeFactory.fs(14))
	enable_field_taps()
	if field_spacer != null:
		supplies = SuppliesBadge.new()
		field_spacer.add_child(supplies)
		supplies.position = Vector2(20, 54)
		update_supplies()
	var jr := W.hbox(10)
	journal_button = W.button(L.t("day.journal"), &"Compact", ACTION_HEIGHT)
	journal_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	journal_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	journal_button.pressed.connect(open_journal)
	jr.add_child(journal_button)
	var diary := W.button(L.t("day.diary"), &"Compact", ACTION_HEIGHT)
	diary.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	diary.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	diary.pressed.connect(open_diary)
	jr.add_child(diary)
	var legend := W.button("?", &"Compact", ACTION_HEIGHT)
	legend.name = "MarksLegend"
	legend.tooltip_text = L.t("legend.btn")
	legend.accessibility_name = L.t("legend.btn")
	legend.custom_minimum_size = Vector2(ACTION_HEIGHT, ACTION_HEIGHT)
	legend.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	legend.pressed.connect(marks_legend)
	jr.add_child(legend)
	journal_preview = W.label("", &"Small")
	journal_preview.autowrap_mode = TextServer.AUTOWRAP_OFF
	journal_preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	journal_preview.clip_text = true
	journal_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	journal_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journal_preview.add_theme_font_size_override("font_size", ThemeFactory.fs(14))
	jr.add_child(journal_preview)
	body.add_child(jr)
	_update_journal()
	if Save.stats.get("games", 0) == 0 and m.day == 1 and not Game.first_contact:
		_contact_hint = W.label(SocialContent.narrative_ui("first_goal"), &"Hint")
		body.add_child(_contact_hint)

	if not m.player().alive:
		body.add_child(W.label(L.t("day.dead"), &"Small"))
		var skip := W.button(L.t("day.skip"), &"Ghost")
		skip.pressed.connect(func() -> void: commit(Intent.END_DAY))
		footer.add_child(skip)
		return

	Diag.step("день-экран: чат готов, кнопки")
	var qb: Array[Button] = []
	for spec: Array in [[L.t("day.defend"), _defend], [L.t("day.invite"), _invite_flow], [L.t("day.accuse"), _accuse_flow]]:
		var q := W.button(spec[0], &"Compact", ACTION_HEIGHT)
		q.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
		var cb: Callable = spec[1]
		q.pressed.connect(func() -> void: cb.call())
		qb.append(q)
	footer.add_child(_action_grid(qb, 3, "PrimaryActions"))

	var rb: Array[Button] = []
	var write := W.button(L.t("day.say"), &"Compact", ACTION_HEIGHT)
	write.name = "Say"
	write.pressed.connect(_write_flow)
	rb.append(write)
	if m.can_meeting(m.player()):
		var bell := W.button(L.t("day.bell"), &"Compact", ACTION_HEIGHT)
		bell.name = "Meeting"
		bell.pressed.connect(_meeting_flow)
		rb.append(bell)
	var ready_btn := W.button(L.t("day.ready"), &"Compact", ACTION_HEIGHT)
	ready_btn.name = "Ready"
	ready_btn.pressed.connect(_ready_flow)
	rb.append(ready_btn)
	footer.add_child(_action_grid(rb, mini(rb.size(), 3), "PhaseActions"))


func _action_grid(buttons: Array[Button], columns: int, node_name: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = node_name
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	for button: Button in buttons:
		button.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.tooltip_text = button.text
		grid.add_child(button)
	return grid


func _ready_flow() -> void:
	if Save.stats.get("games", 0) == 0 and m.day == 1 and not Game.first_contact:
		var residents := m.alive_bots()
		if not residents.is_empty():
			_personal_talk(residents[0])
			return
	commit(Intent.END_DAY)


func contact_done() -> void:
	if is_instance_valid(_contact_hint):
		_contact_hint.text = SocialContent.narrative_ui("bonus_earned")



## Днём камера ближе: жители крупнее, камера идёт за тобой.
func field_zoom() -> float:
	return 1.4


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


func hint_below() -> bool:
	return false


func on_clock_expired() -> void:
	commit(Intent.END_DAY)


## Nav вызывает при каждой новой реплике.
func append_line(_line: ChatLine) -> void:
	_update_journal()
	if _line.asks_player and not _question_prompt_open:
		_question_prompt_open = true
		_answer_npc_question.call_deferred(_line)


func _answer_npc_question(line: ChatLine) -> void:
	if not is_inside_tree() or m == null or line.speaker == null or m.phase != Match.Phase.DAY:
		return
	Game.hold(&"dialog")
	# после утраты — свои ответы: оправдаться, извиниться, промолчать (TASK-010)
	var quick := L.arr("react.answers") if line.question_kind == "grief" else SocialContent.question_answers()
	var prompt := SocialContent.question_title(line.speaker.name) + "\n" + line.text
	var answer := await TextSheet.ask(self, prompt, quick)
	Game.release(&"dialog")
	if answer.is_empty() or not is_inside_tree() or m == null or m.phase != Match.Phase.DAY:
		return
	var answer_kind := quick.find(answer)
	emit_intent(Intent.QUESTION_REPLY, {"id": line.speaker.id, "kind": line.question_kind,
		"answer": answer, "answer_kind": answer_kind})


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
		journal_preview.text = L.t("day.preview", {"who": Save.player_display_name() if last.kind == ChatLine.Kind.MINE else last.speaker.name, "text": last.text})


func _write_flow() -> void:
	var t: String = await TextSheet.ask(self, L.t("day.say_aloud"), Phrases.quick_for(m))
	if not t.is_empty():
		emit_intent(Intent.SAY, {"text": t})


func _defend() -> void:
	emit_intent(Intent.DEFEND)


## Хозяин места (TASK-021): один вопрос в день. Ответ — в чат, его видят все.
func npc_actions(id: String = "") -> void:
	if id.is_empty():
		id = m.npc_id
	if id.is_empty() or director == null:
		return
	var topics := Npc.topics(id)
	var opts := PackedStringArray()
	for t: String in topics:
		opts.append(L.t("npc.%s.q_%s" % [id, t]))
	var i: int = await ActionSheet.ask(self, Npc.display_name(id), opts)
	if i < 0 or i >= topics.size() or not is_instance_valid(self):
		return
	if topics[i] == "book":
		VouchSheet.open(self, m, director)      # книга у ворот: смотреть можно всегда, вопрос не тратится
		return
	if topics[i] == "list" and m.train_on:
		TrainSheet.open(self, m, director)      # список на поезд (TASK-033)
		return
	if int(m.npc_asked.get(id, 0)) == m.day:
		Nav.toast(L.t("npc.busy", {"name": Npc.display_name(id)}))
		return
	var answer := director.npc_answer(topics[i], id)
	if not answer.is_empty():
		m.post(ChatLine.say(m.player(), opts[i]))
		m.post(Director.npc_line(id, answer))


func person_actions(v: Villager) -> void:
	var ev := director.evidence_text(v) if director != null else ""
	var head := v.name
	head += "\n" + SocialContent.person_title(v)
	var state := m.feelings.status_text(v)     # что с человеком сейчас: словами, без цифр (TASK-009)
	if not state.is_empty():
		head += "\n" + state
	if not ev.is_empty():
		head += "\n" + ev
	var opts := PackedStringArray([
		L.t("day.p_accuse", {"who": v}),
		L.t("day.p_invite"),
		L.t("day.p_ask"),
	])
	var me := m.player()
	var elder := me.role == Match.Role.ELDER and not me.role_used
	if elder:
		opts.append(L.t("day.p_elder", {"who": v}))
	var promise_index := opts.size()
	opts.append(L.t("day.p_promise"))
	var comfort_index := -1
	if v.grief_days > 0 and not v.grief_comforted and m.get_villager(v.grief_for) != null:
		comfort_index = opts.size()
		opts.append(SocialContent.mourning_action())
	var send_index := -1
	if m.plant_chapter == "a1c3" and not m.send_used:       # «Прощание»: лодка за реку, одна за главу (TASK-020)
		send_index = opts.size()
		opts.append(L.t("day.p_send"))
	var train_index := -1
	if m.train_on:                                            # «Последний поезд»: список (TASK-033)
		train_index = opts.size()
		opts.append(L.t("day.p_list_strike" if m.on_train(v.id) else "day.p_list_write"))
	var vouch_index := -1
	if m.vouch_on and m.vouch_day != m.day:                  # «Ворота»: вписать имя в книгу (TASK-026)
		vouch_index = opts.size()
		opts.append(L.t("day.p_vouch"))
	var personal_index := opts.size()
	opts.append(SocialContent.narrative_ui("personal"))
	var legend_index := opts.size()
	opts.append(L.t("legend.btn"))
	opts.append(L.t("day.p_gesture"))        # то же, что долгое нажатие на жителя
	var i: int = await ActionSheet.ask(self, head, opts)
	if i == opts.size() - 1:
		gesture_actions(v)
		return
	if i == legend_index:
		marks_legend()
		return
	if i == personal_index:
		_personal_talk(v)
		return
	if i == comfort_index and comfort_index >= 0:
		_mourning_actions(v)
		return
	if i == promise_index:
		promise_actions(v)
		return
	if i == train_index and train_index >= 0:
		if not TrainSheet.apply(m, director, "strike" if m.on_train(v.id) else "write", v):
			Nav.toast(L.t("list.cant"))
		return
	if i == vouch_index and vouch_index >= 0:
		VouchSheet.confirm(self, m, director, v)
		return
	if i == send_index and send_index >= 0:
		var yes: int = await ActionSheet.ask(self, L.t("day.send_ask", {"who": v}), PackedStringArray([L.t("day.send_yes")]))
		if yes == 0:
			emit_intent(Intent.SEND_AWAY, {"id": v.id})
		return
	match i:
		0: emit_intent(Intent.ACCUSE, {"id": v.id})
		1: _pick_house_for(v)
		2: emit_intent(Intent.ASK, {"id": v.id})
		3: emit_intent(Intent.ELDER, {"id": v.id})


func _mourning_actions(v: Villager) -> void:
	var lost := m.get_villager(v.grief_for)
	if lost == null or v.grief_comforted:
		return
	var options := SocialContent.mourning_options(v, lost)
	var choice: int = await ActionSheet.ask(self, SocialContent.mourning_title(v), options)
	if choice >= 0 and is_inside_tree() and m != null and m.phase == Match.Phase.DAY:
		emit_intent(Intent.COMFORT_MOURNER, {"id": v.id, "choice": choice})


func _personal_talk(v: Villager) -> void:
	var text := v.name + "\n" + SocialContent.person_title(v) + "\n\n"
	if v.personal_day == m.day:
		text += SocialContent.narrative_ui("later")
		await ActionSheet.ask(self, text, PackedStringArray())
		return
	text += SocialContent.personal_chapter(v, mini(v.story_step + 1, 2))
	var bond := SocialContent.bond_text(v, m)
	if not bond.is_empty():
		text += "\n\n" + bond
	var choice: int = await ActionSheet.ask(self, text, PackedStringArray([SocialContent.narrative_ui("listen"), SocialContent.narrative_ui("doubt")]))
	if choice >= 0:
		emit_intent(Intent.PERSONAL_TALK, {"id": v.id, "choice": choice})


## Обещание жителю (TASK-004): из карточки, отдельной кнопки на экране нет.
func promise_actions(v: Villager) -> void:
	var kinds := ["open", "come"]
	var opts := PackedStringArray()
	for k: String in kinds:
		opts.append(L.t("day.promise_" + k, {"who": v}))
	var i: int = await ActionSheet.ask(self, L.t("day.promise_title", {"who": v}), opts)
	if i >= 0:
		emit_intent(Intent.PROMISE, {"id": v.id, "kind": kinds[i]})


## Долгое нажатие на жителя: жест без слов — показать пальцем, «верю», «не верю».
func gesture_actions(v: Villager) -> void:
	var kinds := ["point", "trust", "distrust"]
	var opts := PackedStringArray()
	for k: String in kinds:
		opts.append(L.t("gest." + k))
	var i: int = await ActionSheet.ask(self, L.t("gest.title", {"who": v}), opts)
	if i >= 0:
		emit_intent(Intent.GESTURE, {"kind": kinds[i], "id": v.id})


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


## Днём играет светлая тема; на голосовании тишина, ночью тревожная.
func music() -> StringName:
	return Sfx.stage_music(&"day")


## Что значат значки над жителями. Сверху — что посёлок знает про тебя самого.
func marks_legend() -> void:
	var me := m.player()
	var ev := director.evidence_text(me) if director != null else ""
	var lines: Array = []
	lines.append(["info", L.t("legend.mine", {"list": ev}) if not ev.is_empty() else L.t("legend.none")])
	lines.append(["mark_eye", L.t("legend.eye")])
	for b: String in ["street", "liar", "death", "fake", "sabotage", "tunnel"]:
		lines.append(["mark_" + b, L.t("legend." + b)])
	lines.append(["mark_pact", L.t("legend.pact")])
	InfoSheet.open(self, lines)
