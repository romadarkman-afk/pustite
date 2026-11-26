class_name DayScreen
extends Screen
## День. Посёлок занимает большую часть экрана, разговор идёт пузырями
## над головами, жители выбираются тапом по полю. Журнал свёрнут в одну строку
## и раскрывается по касанию — чтобы перечитать, кто что говорил.

var journal_button: Button
var diary_button: Button
var supplies: SuppliesBadge
var supply_info_button: Button
var _supply_row: HBoxContainer
var _question_prompt_open := false
var _contact_hint: Label
var _guide_contact: Control
var _guide_target: VillagerFigure
var _guide_pause: StringName

const ACTION_HEIGHT := 50


func screen_id() -> String:
	return "day"


func field_ratio() -> float:
	return 0.82


## Под полем остаётся только строка журнала.
func min_content_ratio() -> float:
	return 0.04


## Высота поля считается по фактическому размеру строки журнала и всех кнопок под ней.
## На коротком экране карта сжимается первой, освобождая место для управления.
func field_height(h: float) -> float:
	var sep := float(chrome.get_theme_constant("separation")) if chrome != null else 18.0
	var bar := 0.0
	if chrome != null and chrome.get_child_count() > 0 and title() != "":
		bar = (chrome.get_child(0) as Control).get_combined_minimum_size().y
	var body_min := body.get_combined_minimum_size().y if body != null else float(ThemeFactory.COMPACT_TOUCH)
	var reserved := bar + body_min + footer.get_combined_minimum_size().y + 3.0 * sep + 8.0
	if is_instance_valid(_supply_row):
		reserved += _supply_row.get_combined_minimum_size().y + sep
	return maxf(1.0, h - reserved)


func title() -> String:
	return L.t("when.day", {"n": m.day})


func mood() -> Vector2:
	return Vector2(0.12, 0.25)


func build() -> void:
	Diag.step("день-экран: сборка")
	footer.add_theme_constant_override("separation", 4)
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", ThemeFactory.fs(15))
	if _clock != null:
		_clock.add_theme_font_size_override("font_size", ThemeFactory.fs(17))
	var back := find_child("BackToMenu", true, false) as Button
	if back != null:
		back.custom_minimum_size.y = ACTION_HEIGHT
		back.add_theme_font_size_override("font_size", ThemeFactory.fs(12))
	enable_field_taps()
	if field_spacer != null:
		_supply_row = W.hbox(7)
		_supply_row.name = "SupplyRow"
		chrome.add_child(_supply_row)
		chrome.move_child(_supply_row, field_spacer.get_index())
		_supply_row.minimum_size_changed.connect(_fit_field_spacer)
		supplies = SuppliesBadge.new()
		_supply_row.add_child(supplies)
		supply_info_button = W.button("?", &"Compact", 48)
		supply_info_button.name = "SupplyInfo"
		supply_info_button.tooltip_text = L.t("supply.info.title")
		supply_info_button.accessibility_name = L.t("supply.info.title")
		supply_info_button.custom_minimum_size = Vector2(48, 48)
		supply_info_button.pressed.connect(func() -> void: InfoSheet.open(self, _supply_info()))
		_supply_row.add_child(supply_info_button)
		update_supplies()
	var jr := W.hbox(10)
	journal_button = W.button(L.t("day.journal"), &"Compact", ACTION_HEIGHT)
	journal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	journal_button.pressed.connect(open_journal)
	jr.add_child(journal_button)
	diary_button = W.button(L.t("day.diary"), &"Compact", ACTION_HEIGHT)
	diary_button.name = "DiaryButton"
	diary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diary_button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	diary_button.pressed.connect(open_diary)
	jr.add_child(diary_button)
	var diary_timer := Timer.new()
	diary_timer.wait_time = 1.0
	diary_timer.autostart = true
	diary_timer.timeout.connect(_refresh_diary_badge)
	add_child(diary_timer)
	_refresh_diary_badge()
	var legend := W.button("?", &"Compact", ACTION_HEIGHT)
	legend.name = "MarksLegend"
	legend.tooltip_text = L.t("legend.btn")
	legend.accessibility_name = L.t("legend.btn")
	legend.custom_minimum_size = Vector2(ACTION_HEIGHT, ACTION_HEIGHT)
	legend.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	legend.pressed.connect(marks_legend)
	jr.add_child(legend)
	body.add_child(jr)
	_update_journal()
	if not Nav.chapter_guides() and Save.stats.get("games", 0) == 0 and m.day == 1 and not Game.first_contact:
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
	for spec: Array in [[L.t("day.say"), _write_flow], [L.t("day.invite"), _invite_flow], [L.t("day.accuse"), _accuse_flow]]:
		var q := W.button(spec[0], &"Compact", ACTION_HEIGHT)
		q.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
		var cb: Callable = spec[1]
		q.pressed.connect(func() -> void: cb.call())
		qb.append(q)
	footer.add_child(_action_grid(qb, 3, "PrimaryActions"))

	var rb: Array[Button] = []
	var more := W.button(L.t("day.actions"), &"Compact", ACTION_HEIGHT)
	more.name = "DayMoreActions"
	more.pressed.connect(_other_actions)
	rb.append(more)
	var ready_btn := W.button(L.t("day.ready"), &"RowOn", ACTION_HEIGHT)
	ready_btn.name = "Ready"
	ready_btn.pressed.connect(_ready_flow)
	rb.append(ready_btn)
	footer.add_child(_action_grid(rb, mini(rb.size(), 3), "PhaseActions"))


func _other_actions() -> void:
	var actions := PackedStringArray([L.t("day.defend")])
	if m.can_meeting(m.player()):
		actions.append(L.t("day.bell"))
	var selected: int = await ActionSheet.ask(self, L.t("day.actions"), actions)
	if not is_inside_tree():
		return
	if selected == 0:
		_defend()
	elif selected == 1:
		_meeting_flow()


func _action_grid(buttons: Array[Button], columns: int, node_name: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = node_name
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	for button: Button in buttons:
		button.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", ThemeFactory.fs(15))
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
	if not Nav.chapter_guides() or Save.hint_seen("guide_contact"):
		return
	Save.mark_hint("guide_contact")
	_clear_contact_guide()
	_show_work_lesson()


func setup_first_contact() -> void:
	if not is_inside_tree() or self != Nav.host.current or not Nav.chapter_guides() or not m.player().alive:
		return
	if Save.hint_seen("guide_contact") or Game.first_contact:
		_show_work_lesson()
		return
	_show_contact_task()


func _show_work_lesson() -> void:
	if Game.m.jobs.is_empty():
		return
	show_chapter_strip("supplies", "guide.work.short", [])


func work_lesson_done() -> void:
	if Nav.chapter_guides() and Save.hint_seen("guide_contact") and not Save.hint_seen("guide_supplies"):
		Save.mark_hint("guide_supplies")
		clear_chapter_strip()


func _show_contact_task() -> void:
	if self != Nav.host.current or is_instance_valid(_guide_contact) or not Nav.chapter_guides():
		return
	var residents := m.alive_bots()
	if residents.is_empty():
		return
	var resident := residents[0]
	_guide_target = Nav.village.crowd.figures.get(resident.id)
	if is_instance_valid(_guide_target):
		_guide_target.set_highlight(true)
	_guide_pause = StringName("contact_%d" % get_instance_id())
	Game.hold(_guide_pause)
	var speak := W.wrap(W.button(L.t("guide.talk", {"name": resident.name}), &"RowOn", ACTION_HEIGHT))
	speak.name = "GuideContact"
	speak.pressed.connect(func() -> void: _personal_talk(resident))
	var skip := W.wrap(W.button(L.t("guide.skip"), &"Ghost", ACTION_HEIGHT))
	skip.pressed.connect(func() -> void:
		Save.mark_hint("guide_skip")
		_clear_contact_guide())
	var brief := W.vbox(6)
	brief.add_child(W.label(L.t("guide.contact.short"), &"Small"))
	brief.add_child(W.fit_row([speak, skip], 6))
	_guide_contact = brief
	body.add_child(_guide_contact)
	_fit_field_spacer.call_deferred()


func _clear_contact_guide() -> void:
	if is_instance_valid(_guide_target):
		_guide_target.set_highlight(false)
	if _guide_pause != &"":
		Game.release(_guide_pause)
		_guide_pause = &""
	if is_instance_valid(_guide_contact):
		_guide_contact.hide()
		_guide_contact.queue_free()
		_fit_field_spacer.call_deferred()


func _exit_tree() -> void:
	if _guide_pause != &"":
		Game.release(_guide_pause)
	if is_instance_valid(_guide_target):
		_guide_target.set_highlight(false)



## Днём камера ближе: жители крупнее, камера идёт за тобой.
func field_zoom() -> float:
	return 1.4


func update_supplies() -> void:
	if is_instance_valid(supplies) and m != null:
		supplies.set_value(m.resource_completed(), m.resource_available())


func _supply_info() -> Array:
	var out: Array = [["", L.t("supply.info.title")]]
	if m != null:
		out.append_array(m.resource_info_lines())
	return out


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
	var quick := L.arr("react.answers") if line.question_kind == "grief" else SocialContent.question_answers(line.question_kind)
	var prompt := SocialContent.question_title(line.speaker.name) + "\n" + line.text
	var answer := await TextSheet.ask(self, prompt, quick)
	Game.release(&"dialog")
	_question_prompt_open = false
	if answer.is_empty() or not is_inside_tree() or m == null or m.phase != Match.Phase.DAY:
		return
	var answer_kind := quick.find(answer)
	emit_intent(Intent.QUESTION_REPLY, {"id": line.speaker.id, "kind": line.question_kind,
		"answer": answer, "answer_kind": answer_kind})


func _refresh_diary_badge() -> void:
	if not is_instance_valid(diary_button) or m == null:
		return
	var unread := DiarySheet.signature(m, director) != Game.diary_seen_signature
	diary_button.text = L.t("day.diary") + (" •" if unread else "")


func open_journal() -> void:
	JournalSheet.open(self, m.chat)


func open_diary() -> DiarySheet:
	var sheet := DiarySheet.open(self, m, director)
	_refresh_diary_badge()
	return sheet


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
	var crowd := Nav.village.crowd
	var job := int(crowd.at_job.get(v.id, -1))
	var figure := crowd.figures.get(v.id) as VillagerFigure
	if job >= 0 and job < m.jobs.size() and figure != null:
		var status := "job.npc_working" if figure.working else "job.npc_heading"
		head += "\n" + L.t(status, {"job": m.jobs[job].title})
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
	var personal_index := -1
	if v.story_step < 2:
		personal_index = opts.size()
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
	if personal_index >= 0 and i == personal_index:
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
