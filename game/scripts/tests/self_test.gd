class_name SelfTest
extends RefCounted
## Проверки, которые CI гоняет перед сборкой APK.
## Падение любой из них = красная сборка, битый APK не выходит.


## Запуск из сборки: --sim. Коридор 30–70% и обе роли у двери обязательны.
static func cli_balance() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var c := load("res://config/balance_7.tres") as GameConfig
	var r := balance(c, 3000)
	print("=== баланс: %d партий ===" % r.runs)
	print("состав: %d жителей, %d упырей, %d убежищ по %d, %d ночи" % [c.players, c.monsters, c.shelters, c.capacity, c.nights])
	print("побед людей: %.1f%%  | средняя партия: %.2f ночи" % [100.0 * r.people_win, r.avg_nights])
	print("игрок хозяином двери: %d раз, гостем у чужой: %d раз" % [r.player_host, r.player_guest])
	var ok: bool = r.people_win > 0.30 and r.people_win < 0.70 and r.player_guest > 0 and r.player_host > 0
	var gram := grammar(c)
	print("грамматика: проверено %d фраз, ошибок %d" % [gram.checked, gram.errors.size()])
	for e: String in gram.errors.slice(0, 12):
		print("  ✗ " + e)
	ok = ok and gram.errors.is_empty()
	# журнал событий (TASK-001): все виды событий встречаются и сходятся со старыми списками
	var wl := PlanTests.world_log_sim(500)
	print("журнал событий: %d партий, нет видов: %s, расхождений: %d" % [wl.games, ", ".join(wl.missing), (wl.mismatch as PackedStringArray).size()])
	for e2: String in wl.mismatch:
		print("  ✗ " + e2)
	ok = ok and (wl.missing as PackedStringArray).is_empty() and (wl.mismatch as PackedStringArray).is_empty()
	print("ИТОГ: %s" % ("OK" if ok else "БАЛАНС ВНЕ КОРИДОРА 30–70%, ИГРОК НЕ ВИДИТ ОДНУ ИЗ РОЛЕЙ У ДВЕРИ ИЛИ ОШИБКИ В ТЕКСТАХ"))
	tree.quit(0 if ok else 1)


## Грамматика реплик и хроники: «Рита был», «на Женя», недоставленные метки, «Вы» в третьем лице.
static func grammar(cfg: GameConfig, games: int = 250) -> Dictionary:
	var texts := collect_texts(cfg, games)
	return check_ru(texts)


## Все тексты, которые игра собирает в партиях: реплики, хроника, утро, разбор. На текущем языке.
static func collect_texts(cfg: GameConfig, games: int) -> PackedStringArray:
	var texts: PackedStringArray = []
	for g in range(games):
		var m := Match.new()
		var d := Director.new()
		m.start(cfg, 5000 + g)
		d.attach(m)
		m.begin_day()
		texts.append_array(Phrases.quick_for(m))
		while m.phase != Match.Phase.OVER:
			match m.phase:
				Match.Phase.DAY:
					d.plan_day()
					for l: ChatLine in d.opening_lines():
						texts.append(l.text)
					for t: Villager in m.alive_bots():
						for k: IntentParser.Kind in [IntentParser.Kind.ACCUSE, IntentParser.Kind.ASK, IntentParser.Kind.DEFEND, IntentParser.Kind.NONE]:
							var it := IntentParser.Result.new()
							it.kind = k
							it.target = t
							for l: ChatLine in d.react(it):
								texts.append(l.text)
						texts.append(d.plea_for(t))
					for l: ChatLine in d.run_jobs_instant(d.plan_jobs(m.config.day_seconds)):
						texts.append(l.text)
					# все реплики о пустой работе — для каждого жителя и каждого дела
					for t: Villager in m.alive_bots():
						for j: JobDef in m.jobs:
							for line: String in Phrases.b("JOB_FAKE"):
								texts.append(Phrases.fill(line, {"who": t, "me_f": false, "place": j.place}))
								texts.append(Phrases.fill(line, {"who": t, "me_f": true, "place": j.place}))
							for line: String in Phrases.b("JOB_FAKE_AT_PLAYER"):
								texts.append(Phrases.fill(line, {"me_f": t.female, "place": j.place}))
					# Подражатель, саботаж, ящик: все реплики для каждого жителя
					for t: Villager in m.villagers:
						if t.is_player:
							continue
						for line: String in Phrases.b("MIMIC_PLEAS"):
							texts.append(Phrases.fill(line, {"who": t, "me_f": t.female}))
						for line: String in Phrases.b("SABOTAGE_SEEN"):
							texts.append(Phrases.fill(line, {"who": t, "me_f": not t.female, "place": L.t("job.water.place")}))
						for line: String in Phrases.b("SABOTAGE_SEEN_AT_PLAYER"):
							texts.append(Phrases.fill(line, {"me_f": t.female, "place": L.t("job.water.place")}))
						for bank: PackedStringArray in [Phrases.b("BOX_NOTE"), Phrases.b("BOX_OIL"), Phrases.b("BOX_CHALK")]:
							for line: String in bank:
								texts.append(Phrases.fill(line, {"me_f": t.female, "a": t, "b": m.player(), "house": m.houses[0]}))
					var mc := d.meeting_caller()
					if mc != null:
						texts.append(d.meeting_line(mc).text)
					m.end_day()
				Match.Phase.VOTE:
					var tally: Dictionary[int, int] = {}
					var bv := d.votes()
					for voter: int in bv:
						tally[bv[voter]] = tally.get(bv[voter], 0) + m.vote_weight(voter)
					m.apply_vote(tally)
					m.after_vote()
				Match.Phase.NIGHT:
					var ch := d.night_choices()
					ch[0] = m.rng.randi_range(0, m.houses.size() - 1)
					m.seat_night(ch)
				Match.Phase.DOOR:
					for s: Match.Seat in m.seats:
						var ids: Array[int] = []
						if s.host.is_player:
							if not s.queue.is_empty():
								ids.append(s.queue[0].id)
						else:
							ids = d.host_decide(s, "beg")
						m.admit(s, ids)
					m.tunnel_pass(false)
					d.after_door(m.seats)
					var rep := m.resolve_night()
					d.read_report(rep)
					var ms := MorningScreen.new()
					ms.m = m
					for e: NightReport.Entry in rep.entries:
						texts.append(ms._text(e))
					ms.free()
				Match.Phase.MORNING:
					m.end_morning()
		texts.append_array(m.chronicle)
		texts.append(Recap.verdict(m, d))
		texts.append_array(Recap.exile_lines(m, d))
		if m.player_death != null:
			texts.append_array(Recap.death_lines(m, m.player_death))
		for sec: Dictionary in Recap.timeline(m):
			texts.append_array(sec.lines)
	return texts


## Русские правила: род, падежи имён и домов, «Вы» во множественном.
static func check_ru(texts: PackedStringArray) -> Dictionary:
	var fem := "(?:" + "|".join(L.female_names()) + ")"
	var males: PackedStringArray = []
	var names_all: PackedStringArray = []
	for n: Array in L.names():
		names_all.append(String(n[0]))
		if not bool(n[1]):
			males.append(String(n[0]))
	var mal := "(?:" + "|".join(males) + ")"
	var all_names := "(?:" + "|".join(names_all) + ")"
	var rules: Array[Array] = [
		[RegEx.create_from_string("[{}\\[\\]|]"), "недоставленная метка"],
		[RegEx.create_from_string("(*UCP)" + fem + "\\s+(?:был|ночевал|говорил|вернулся|дожил|спал|собирался|остался|погиб|провёл)\\b"), "женское имя с мужским глаголом"],
		[RegEx.create_from_string("(*UCP)" + mal + "\\s+(?:была|ночевала|говорила|вернулась|дожила|спала|собиралась|осталась|погибла|провела)\\b"), "мужское имя с женским глаголом"],
		[RegEx.create_from_string("(*UCP)(?:\\bна|\\bза)\\s+" + all_names + "\\b"), "имя после «на/за» не в винительном"],
		[RegEx.create_from_string("(*UCP)^(?!Ночь|День).*\\bВы\\s+(?:был|была|не пустили)\\b"), "«Вы» с единственным числом"],
		[RegEx.create_from_string("(*UCP)(?:погиб\\w*|ночевал\\w*|один|одна|одни|сегодня|Ночую|Я) в «(?:Дом у реки|Сарай|Погреб|Гараж|Церковь)»"), "убежище не в предложном падеже («в Сарае»)"],
		[RegEx.create_from_string("(*UCP)(?:^|\\s)[Вв] «(?:Дом у реки|Сарай|Погреб|Гараж|Церковь)» ночевали"), "убежище не в предложном падеже («В Доме у реки ночевали»)"],
		[RegEx.create_from_string("(*UCP)\\b(?:до|у|дверь) «(?:Дом у реки|Сарай|Погреб|Гараж|Церковь)»"), "убежище не в родительном падеже («до Сарая»)"],
		[RegEx.create_from_string("«\\s*»"), "пустые кавычки — название не подставилось"],
	]
	# самопроверка: правила обязаны ловить заведомо плохие фразы, иначе проверка слепая
	var probes: PackedStringArray = ["Рита был рядом.", "Тимур ночевала на улице.", "Посмотри лучше на Женя.", "Вы был там.", "Метка {who} осталась.",
		"Гриша погиб в «Сарай».", "Я сегодня в «Погреб».", "В «Дом у реки» ночевали Костя и Лида — все целы.", "Встречаемся у «Гараж».",
		"Ночую в «», если что."]
	var errors: PackedStringArray = []
	for pr: String in probes:
		var hit := false
		for r: Array in rules:
			if (r[0] as RegEx).search(pr) != null:
				hit = true
		if not hit:
			errors.append("проверка грамматики слепая: не поймала «%s»" % pr)
	for i in range(L.houses().size()):
		var hh := L.house(i)
		var h := String(hh.get("nom", ""))
		if String(hh.get("in", "")).is_empty() or String(hh.get("of", "")).is_empty() or hh.get("in") == h:
			errors.append("нет падежей для убежища «%s»: где «%s», чего «%s»" % [h, hh.get("in", ""), hh.get("of", "")])
	var seen: Dictionary[String, bool] = {}
	for t: String in texts:
		for r: Array in rules:
			if (r[0] as RegEx).search(t) != null and not seen.has(t):
				seen[t] = true
				errors.append("%s: «%s»" % [r[1], t])
	return {"checked": texts.size(), "errors": errors}


## Прогон партий без экрана. Игрок ходит случайно — это нижняя граница его силы.
static func balance(cfg: GameConfig, runs: int = 3000, rule: String = "", tune: float = 0.0) -> Dictionary:
	var wins := 0
	var nights := 0
	var guest_turns := 0
	var host_turns := 0
	var as_human := 0
	var human_wins := 0
	var as_upyr := 0
	var upyr_wins := 0
	for g in range(runs):
		var m := Match.new()
		var d := Director.new()
		m.rule = rule
		d.tune = tune
		m.start(cfg, 1000 + g)
		d.attach(m)
		m.begin_day()
		while m.phase != Match.Phase.OVER:
			match m.phase:
				Match.Phase.DAY:
					d.plan_day()
					d.run_jobs_instant(d.plan_jobs(m.config.day_seconds))
					var caller := d.meeting_caller()
					if caller != null:
						m.call_meeting(caller)
					else:
						m.end_day()
				Match.Phase.VOTE:
					var tally: Dictionary[int, int] = {}
					var bv := d.votes()
					for voter: int in bv:
						tally[bv[voter]] = tally.get(bv[voter], 0) + m.vote_weight(voter)
					m.apply_vote(tally)
					m.after_vote()
				Match.Phase.NIGHT:
					var ch := d.night_choices()
					if m.player().alive:
						ch[0] = m.rng.randi_range(0, m.houses.size() - 1)
					m.seat_night(ch)
				Match.Phase.DOOR:
					for s: Match.Seat in m.seats:
						if s.host.is_player:
							host_turns += 1
							var ids: Array[int] = []
							if not s.queue.is_empty():
								ids.append(s.queue[m.rng.randi_range(0, s.queue.size() - 1)].id)
							m.admit(s, ids)
						else:
							if s.queue.has(m.player()):
								guest_turns += 1
							m.admit(s, d.host_decide(s, "beg"))
					m.tunnel_pass(false)
					d.after_door(m.seats)
					d.read_report(m.resolve_night())
				Match.Phase.MORNING:
					m.end_morning()
		nights += m.day
		if m.winner == Match.Team.PEOPLE:
			wins += 1
		if m.player().is_upyr:
			as_upyr += 1
			upyr_wins += 1 if m.winner != Match.Team.PEOPLE else 0
		else:
			as_human += 1
			human_wins += 1 if m.winner == Match.Team.PEOPLE else 0
	return {
		"runs": runs,
		"people_win": float(wins) / runs,
		"human_win": float(human_wins) / maxi(1, as_human),     ## игрок-человек выиграл
		"upyr_win": float(upyr_wins) / maxi(1, as_upyr),        ## игрок-упырь выиграл
		"avg_nights": float(nights) / runs,
		"player_host": host_turns,
		"player_guest": guest_turns,
	}


## Прогон через настоящие экраны и настоящие обработчики Nav и Game.
## Требует, чтобы игрок побывал во ВСЕХ ролях у двери. Иначе — код выхода 1.
static func flow() -> void:
	var tree := Nav.get_tree()
	var seen: Dictionary[String, int] = {}
	var bonds_before: Dictionary[String, int] = Save.anchor_bonds.duplicate()
	var name_before := Save.player_name
	var cast_a := Match.new()
	var cast_b := Match.new()
	# Биография не зависит от жеребьёвки, пол и возраст согласованы с портретом.
	var cast_cfg := GameConfig.new()
	cast_cfg.players = 12
	var full_a := Match.new()
	var full_b := Match.new()
	full_a.start(cast_cfg, 3301)
	full_b.start(cast_cfg, 3302)
	var identity_ok := true
	for v: Villager in full_a.alive_bots():
		identity_ok = identity_ok and v.age >= 18 and v.age == SocialContent.story_age(v.story_id)
		for other: Villager in full_b.alive_bots():
			if v.name == other.name:
				identity_ok = identity_ok and v.story_id == other.story_id and v.age == other.age and v.female == other.female
		var portrait_id := VillagerFigure.pick_cast_sprite(v, {})
		identity_ok = identity_ok and portrait_id != 6 and portrait_id != 15
		identity_ok = identity_ok and (VillagerFigure.FOLK_FEMALE.has(portrait_id) == v.female)
		if v.partner_id >= 0:
			var partner := full_a.get_villager(v.partner_id)
			identity_ok = identity_ok and partner != null and partner.partner_id == v.id and partner.female != v.female
		if v.family_id >= 0:
			var relative := full_a.get_villager(v.family_id)
			identity_ok = identity_ok and relative != null and relative.family_id == v.id
			identity_ok = identity_ok and not SocialContent.bond_text(v, full_a).is_empty()
	var spouse := Villager.new(90, "Нина", false)
	spouse.female = true
	identity_ok = identity_ok and SocialContent.story(8, spouse).contains("муж") and not SocialContent.story(8, spouse).contains("Моя жена")
	spouse.female = false
	identity_ok = identity_ok and SocialContent.story(8, spouse).contains("жена")
	print("личности: ", "OK" if identity_ok else "FAIL")
	if not identity_ok:
		push_error("Narrative identity regression")
		Nav.get_tree().quit(1)
		return
	var narrative_dir := Director.new()
	narrative_dir.attach(full_a)
	var person: Villager = full_a.villagers[4]
	var first_talk := narrative_dir.personal_talk(person.id, 0)
	var talk_ok := first_talk.size() == 4 and person.story_step == 1 and not first_talk[1].emotion.is_empty()
	talk_ok = talk_ok and narrative_dir.personal_talk(person.id, 0).is_empty()
	full_a.day = 2
	var second_talk := narrative_dir.personal_talk(person.id, 1)
	talk_ok = talk_ok and second_talk.size() == 4 and person.story_step == 2 and second_talk[1].text != first_talk[1].text
	for v: Villager in full_a.alive_bots():
		if v.partner_id >= 0:
			full_a.get_villager(v.partner_id).alive = false
			full_a.get_villager(v.partner_id).exiled = true   # гибель ночью — траур (--recap), изгнание — здесь
			var grief := narrative_dir.emotional_lines()
			talk_ok = talk_ok and not grief.is_empty() and grief[0].emotion == "sad"
			break
	print("личные сцены: ", "OK" if talk_ok else "FAIL")
	if not talk_ok:
		push_error("Narrative conversation regression")
		Nav.get_tree().quit(1)
		return
	cast_a.start((load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig, 701)
	cast_b.start((load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig, 702)
	var cast_ok := cast_a.case_id >= 0 and cast_a.case_id < 3 and not SocialContent.case_hook(cast_a.case_id).is_empty()
	for i in range(3):
		var a: Villager = cast_a.villagers[i + 1]
		var b: Villager = cast_b.villagers[i + 1]
		cast_ok = cast_ok and a.anchor_id == i and b.anchor_id == i and a.story_id == i and b.story_id == i and a.name == b.name
	var saved_bond := Save.anchor_bond(0)
	Save.anchor_bonds["0"] = 1
	Save.flush()
	Save.anchor_bonds.clear()
	Save.load_all()
	var cast_memory := Match.new()
	cast_memory.start((load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig, 703)
	cast_ok = cast_ok and cast_memory.villagers[1].relationship == 1 and not SocialContent.anchor_chapter(0, 0).is_empty()
	Save.anchor_bonds["0"] = saved_bond
	Save.player_name = cast_a.villagers[1].name
	var named_config := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	named_config.players = 12
	var named_cast := Match.new()
	named_cast.start(named_config, 704)
	var unique_names: Dictionary[String, bool] = {}
	for v: Villager in named_cast.villagers:
		cast_ok = cast_ok and not unique_names.has(v.name.to_lower())
		unique_names[v.name.to_lower()] = true
	Save.player_name = name_before
	var test_seat := Match.Seat.new()
	test_seat.host = cast_a.player()
	test_seat.house = 0
	test_seat.queue.assign(cast_a.villagers.slice(1, 4))
	cast_a.phase = Match.Phase.DOOR
	var inspection_rules_ok := cast_a.inspect_visitor(test_seat, test_seat.queue[0].id) != &""
	inspection_rules_ok = inspection_rules_ok and cast_a.inspect_visitor(test_seat, test_seat.queue[0].id) == &"" and cast_a.door_inspections.size() == 1
	inspection_rules_ok = inspection_rules_ok and cast_a.inspect_visitor(test_seat, test_seat.queue[1].id) != &"" and cast_a.inspect_visitor(test_seat, test_seat.queue[2].id) == &"" and cast_a.door_inspections.size() == 2
	inspection_rules_ok = inspection_rules_ok and cast_a.inspect_visitor(test_seat, test_seat.queue[2].id, 3) != &"" and cast_a.door_inspections.size() == 3
	var human_anomalies := 0
	var upyr_anomalies := 0
	test_seat.queue[0].is_upyr = false
	test_seat.queue[1].is_upyr = true
	for night in range(1, 201):
		cast_a.day = night
		human_anomalies += 1 if cast_a.door_sign_for(test_seat.queue[0], test_seat) != &"ordinary" else 0
		upyr_anomalies += 1 if cast_a.door_sign_for(test_seat.queue[1], test_seat) != &"ordinary" else 0
	inspection_rules_ok = inspection_rules_ok and human_anomalies > 0 and human_anomalies < upyr_anomalies and upyr_anomalies < 200
	test_seat = null
	cast_a = null
	cast_b = null
	cast_memory = null
	named_cast = null
	named_config = null
	var door_check_ok := false
	var required: PackedStringArray = ["menu", "settings", "prologue", "day", "vote",
		"night", "door_host", "door_guest", "morning", "end"]

	Nav.show_menu()
	await tree.process_frame
	_mark(seen)
	Nav.show_settings()
	await tree.process_frame
	_mark(seen)

	var games_before: int = Save.stats["games"]
	var matches := 0
	for attempt in range(60):
		matches += 1
		Nav.start_match()
		var guard := 0
		while Game.m.phase != Match.Phase.OVER and guard < 400:
			guard += 1
			await tree.process_frame
			var s: Screen = Nav.host.current
			_mark(seen)
			match Game.m.phase:
				Match.Phase.PROLOGUE:
					Nav.handle_intent(Intent.CONTINUE, {}, s)
				Match.Phase.DAY:
					var bots := Game.m.alive_bots()
					if Game.m.player().alive and not bots.is_empty():
						Nav.handle_intent(Intent.SAY, {"text": "%s, пойдём в сарай?" % bots[0].name}, s)
						Nav.handle_intent(Intent.ACCUSE, {"id": bots[bots.size() - 1].id}, s)
						Nav.handle_intent(Intent.DEFEND, {}, s)
					Nav.handle_intent(Intent.END_DAY, {}, s)
				Match.Phase.VOTE:
					var vs := s as VoteScreen
					if not vs.result_shown:
						var bots2 := Game.m.alive_bots()
						Nav.handle_intent(Intent.VOTE, {"id": bots2[0].id if not bots2.is_empty() else -1}, s)
						for f in range(40):
							if vs.result_shown:
								break
							await tree.process_frame
					Nav.handle_intent(Intent.CONTINUE, {}, s)
				Match.Phase.NIGHT:
					Game.run_t = 2.5     # живой игрок жмёт не мгновенно: иногда кто-то успевает раньше
					Nav.handle_intent(Intent.CHOOSE_HOUSE, {"house": Game.m.rng.randi_range(0, Game.m.houses.size() - 1)}, s)
				Match.Phase.DOOR:
					var ds := s as DoorScreen
					if ds == null:
						continue
					match ds.role:
						Match.DoorRole.HOST:
							var ids: Array[int] = []
							if not ds.seat.knockers().is_empty():
								var visitor: Villager = ds.seat.knockers()[0]
								ids.append(visitor.id)
								var inspect := ds.find_child("Inspect_%d" % visitor.id, true, false) as Button
								var note := ds.find_child("Observation_%d" % visitor.id, true, false) as Label
								if inspect != null and note != null:
									inspect.pressed.emit()
									await tree.process_frame
									var figure: VillagerFigure = ds._visitor_figures.get(visitor.id)
									var on_field: VillagerFigure = Nav.village.crowd.figures.get(visitor.id)
									var visual_ok := is_instance_valid(figure) and figure.door_portrait
									if visual_ok and on_field != null:
										visual_ok = figure.sprite_id == on_field.sprite_id and figure.identity_color == on_field.identity_color
									if visual_ok:
										figure.knock()
										figure._process(VillagerFigure.KNOCK_LEN * 0.5)
										visual_ok = float((figure.pose_now()[1] as Dictionary).get("knock", 0.0)) > 0.5
										figure._process(VillagerFigure.KNOCK_LEN)
										visual_ok = visual_ok and not (figure.pose_now()[1] as Dictionary).has("knock")
									door_check_ok = door_check_ok or (visual_ok and note.visible and not note.text.is_empty() and not Game.m.door_inspections.is_empty())
							Nav.handle_intent(Intent.ADMIT, {"ids": ids}, s)
						Match.DoorRole.GUEST:
							Nav.handle_intent(Intent.PLEA, {"plea": "shared"}, s)
							for f in range(60):
								if ds.result_shown:
									break
								await tree.process_frame
							Nav.handle_intent(Intent.CONTINUE, {}, s)
						_:
							var none: Array[int] = []
							Nav.handle_intent(Intent.ADMIT, {"ids": none}, s)
				Match.Phase.MORNING:
					var ms := s as MorningScreen
					for f in range(80):
						if ms.revealed:
							break
						await tree.process_frame
					Nav.handle_intent(Intent.CONTINUE, {}, s)
		await tree.process_frame
		_mark(seen)
		var done := true
		for r: String in required:
			if not seen.has(r):
				done = false
		if done:
			break

	var missing: PackedStringArray = []
	for r: String in required:
		if not seen.has(r):
			missing.append(r)
	var keys: PackedStringArray = []
	for k: String in seen:
		keys.append("%s×%d" % [k, seen[k]])
	var recorded: int = Save.stats["games"] - games_before
	if recorded != matches:
		missing.append("статистика: сыграно %d, записано в Save %d" % [matches, recorded])
	if not cast_ok:
		missing.append("три постоянных жителя или память отношений не сохранились между партиями")
	if not door_check_ok:
		missing.append("у двери нельзя осмотреть стучащего и записать примету")
	if not inspection_rules_ok:
		missing.append("лимит осмотров или неоднозначность примет нарушены")
	Save.anchor_bonds = bonds_before
	Save.player_name = name_before
	Save.flush()
	print("=== экраны: %d партий, записано в статистику: %d ===" % [matches, recorded])
	print("посещено: " + ", ".join(keys))
	print("осмотр: повтор и третий посетитель отклонены; приметы у людей %d/200, у упырей %d/200" % [human_anomalies, upyr_anomalies])
	if missing.is_empty():
		print("ИТОГ: OK — все экраны и обе роли у двери пройдены")
		tree.quit(0)
	else:
		print("ИТОГ: НЕ ПРОЙДЕНЫ: " + ", ".join(missing))
		tree.quit(1)


static func _mark(seen: Dictionary[String, int]) -> void:
	if Nav.host.current != null:
		var id := Nav.host.current.screen_id()
		seen[id] = seen.get(id, 0) + 1


# =============================================================
# Раскладка. Каждый экран на каждом типе дисплея обязан:
#  · занимать весь экран (ошибка v0.2: экраны схлопывались в 0×0);
#  · оставлять под содержимое не меньше 30% высоты;
#  · держать все кнопки не ниже 84 px вьюпорта (≈ 48 dp);
#  · ничего не выводить за левый и правый край;
#  · держать нижнюю панель кнопок в пределах экрана.
# Любое нарушение — код выхода 1, APK не собирается.
# =============================================================
const LAYOUT_SIZES: Array[Vector2i] = [
	Vector2i(720, 1280),    # 16:9, старый телефон
	Vector2i(1080, 2340),   # 19.5:9
	Vector2i(1080, 2400),   # 20:9
	Vector2i(1080, 2520),   # 21:9
	Vector2i(1536, 2048),   # планшет 4:3
]
## Телефоны с вырезом камеры и жестовой панелью: размер окна + поля (лево, верх, право, низ) в px вьюпорта.
const LAYOUT_CUTOUTS: Array[Array] = [
	[Vector2i(1080, 2400), Vector4(0, 110, 0, 70)],   # дырка в экране + жесты
	[Vector2i(1080, 2340), Vector4(0, 140, 0, 48)],   # каплевидный вырез
]
const MIN_TOUCH := 84.0
## Дома должны читаться: не мельче 80% задуманного размера. Пустых краёв не бывает —
## лес, земля и небо нарисованы шире экрана.
const MIN_FIELD_SCALE := 0.8
static var field_scales: PackedFloat32Array = PackedFloat32Array()


static func layout() -> void:
	var tree := Nav.get_tree()
	var problems: PackedStringArray = []
	var checks := 0
	var phone_cutouts: Array[Rect2] = [Rect2(500, 0, 80, 105)]
	var phone_inset := SafeFrame.cutout_insets(Vector2(720, 1560), Vector2(1080, 2340), phone_cutouts)
	checks += _expect(problems, absf(phone_inset.y - 70.0) < 0.1 and phone_inset.w == 0.0,
		"Android: вырез камеры создаёт пустой нижний отступ")
	var side_cutouts: Array[Rect2] = [Rect2(0, 400, 96, 80)]
	var side_inset := SafeFrame.cutout_insets(Vector2(1560, 720), Vector2(2340, 1080), side_cutouts)
	checks += _expect(problems, absf(side_inset.x - 64.0) < 0.1 and side_inset.y == 0.0 and side_inset.w == 0.0,
		"Android: боковой вырез сжимает интерфейс по высоте")
	var profiles: Array[Array] = []
	for sz: Vector2i in LAYOUT_SIZES:
		profiles.append([sz, Vector4(-1, -1, -1, -1)])
	profiles.append_array(LAYOUT_CUTOUTS)
	for prof: Array in profiles:
		var sz: Vector2i = prof[0]
		var cut: Vector4 = prof[1]
		Nav.frame.debug_insets = cut
		tree.root.size = sz
		await _settle(tree)
		Nav.frame.refresh()
		await _frames(tree, 2)
		var tag := "%d×%d" % [sz.x, sz.y] + (" вырез %d/%d" % [int(cut.y), int(cut.w)] if cut.x >= 0.0 else "")

		Nav.show_menu()
		await _settle(tree)
		checks += _check(tag, problems)
		Nav.show_settings()
		await _settle(tree)
		checks += _check(tag, problems)
		Nav.show_wardrobe()
		await _settle(tree)
		checks += _check(tag, problems)
		# экран глав: и пустой, и с пройденным актом, погибшими и концовкой — самый длинный вариант
		var keep_stars := Save.campaign_stars.duplicate()
		var keep_dead := Save.campaign_dead.duplicate()
		Nav.show_campaign()
		await _settle(tree)
		checks += _check(tag + " · главы", problems)
		Save.campaign_stars.assign({"a1c1": 3, "a1c2": 2, "a1c3": 1})
		Save.campaign_dead.assign([1, 4])
		Nav.show_campaign()
		await _settle(tree)
		checks += _check(tag + " · главы, акт пройден", problems)
		Save.campaign_stars.assign(keep_stars)
		Save.campaign_dead.assign(keep_dead)
		var keep_ach := Save.achievements.duplicate()
		Nav.show_book()
		await _settle(tree)
		checks += _check(tag + " · книга", problems)
		Save.achievements = Progress.ACHIEVEMENTS.duplicate()
		Nav.show_book()
		await _settle(tree)
		checks += _check(tag + " · книга полная", problems)
		Save.achievements = keep_ach
		# карта мельницы (акт II): пролог главы на другой земле
		var keep_st := Save.campaign_stars.duplicate()
		Save.campaign_stars.assign({"a1c1": 1, "a1c2": 1, "a1c3": 1})
		Nav.start_chapter("a2c1")
		await _settle(tree)
		checks += _check(tag + " · мельница", problems)
		Save.campaign_stars.assign(keep_st)
		Nav.show_howto(false)
		await _settle(tree)
		for pg in range(HowToScreen.PAGES.size()):
			checks += _check(tag + " · карточка %d" % (pg + 1), problems)
			(Nav.host.current as HowToScreen).next_page()
			await _settle(tree)

		Nav.start_match()
		await _settle(tree)
		checks += await _check_doors(tag, problems)

		var guard := 0
		while Game.m.phase != Match.Phase.OVER and guard < 60:
			guard += 1
			await _settle(tree)
			checks += _check(tag, problems)
			checks += await _layout_step(tag, problems)
		await _settle(tree)
		checks += _check(tag, problems)

	Nav.frame.debug_insets = Vector4(-1, -1, -1, -1)
	if not field_scales.is_empty():
		var lo := 9.0
		var hi := 0.0
		for sc: float in field_scales:
			lo = minf(lo, sc)
			hi = maxf(hi, sc)
		print("масштаб посёлка на всех экранах: от %.2f до %.2f" % [lo, hi])
	print("=== раскладка: %d проверок на %d типах экранов (из них %d с вырезом) ===" % [checks, profiles.size(), LAYOUT_CUTOUTS.size()])
	if problems.is_empty():
		print("ИТОГ: OK — все экраны на весь дисплей, кнопки ≥ 48 dp, ничего не вылезает")
		tree.quit(0)
	else:
		for p: String in problems.slice(0, 40):
			print("  ✗ " + p)
		print("ИТОГ: НАРУШЕНИЙ РАСКЛАДКИ: %d" % problems.size())
		tree.quit(1)


## Один шаг партии + проверка промежуточных состояний (итог голосования, утро, ответ у двери).
static func _layout_step(tag: String, out: PackedStringArray) -> int:
	var tree := Nav.get_tree()
	var s: Screen = Nav.host.current
	var n := 0
	match Game.m.phase:
		Match.Phase.PROLOGUE:
			Nav.handle_intent(Intent.CONTINUE, {}, s)
		Match.Phase.DAY:
			var sheet := ActionSheet.new()
			s.add_child(sheet)
			sheet._build("Проверка шторки", PackedStringArray(["Первый", "Второй", "Третий"]))
			await _settle(tree)
			n += _check_sheet(sheet, tag, out)
			sheet.close(-1)
			var bots := Game.m.alive_bots()
			if Game.m.player().alive and not bots.is_empty():
				Nav.handle_intent(Intent.SAY, {"text": "%s, пойдём в сарай?" % bots[0].name}, s)
				await _settle(tree)
				n += _check(tag, out)
			Nav.handle_intent(Intent.END_DAY, {}, s)
		Match.Phase.VOTE:
			var vs := s as VoteScreen
			if not vs.result_shown:
				var bots2 := Game.m.alive_bots()
				Nav.handle_intent(Intent.VOTE, {"id": bots2[0].id if not bots2.is_empty() else -1}, s)
				for f in range(40):
					if vs.result_shown:
						break
					await tree.process_frame
				await _settle(tree)
				n += _check(tag, out)
			Nav.handle_intent(Intent.CONTINUE, {}, s)
		Match.Phase.NIGHT:
			Nav.handle_intent(Intent.CHOOSE_HOUSE, {"house": 0}, s)
		Match.Phase.DOOR:
			var ds := s as DoorScreen
			if ds == null:
				return n
			match ds.role:
				Match.DoorRole.HOST:
					# на медленной машине очередь у двери может быть ещё пустой — тогда никого не впускаем
					var ids: Array[int] = []
					if not ds.seat.queue.is_empty():
						ids.append(ds.seat.queue[0].id)
					Nav.handle_intent(Intent.ADMIT, {"ids": ids}, s)
				Match.DoorRole.GUEST:
					Nav.handle_intent(Intent.PLEA, {"plea": "beg"}, s)
					for f in range(60):
						if ds.result_shown:
							break
						await tree.process_frame
					await _settle(tree)
					n += _check(tag, out)
					Nav.handle_intent(Intent.CONTINUE, {}, s)
				_:
					var none: Array[int] = []
					Nav.handle_intent(Intent.ADMIT, {"ids": none}, s)
		Match.Phase.MORNING:
			var ms := s as MorningScreen
			for f in range(80):
				if ms.revealed:
					break
				await tree.process_frame
			await _settle(tree)
			n += _check(tag, out)
			var entries := 0
			for c: Node in ms.body.get_children():
				if c.has_meta("entry"):
					entries += 1
					if not c.has_meta("loss") and not (c.get_child(0).get_child(0) is Glyph):
						out.append("%s · утро: строка сводки без значка" % tag)
			if entries == 0:
				out.append("%s · утро: сводка без карточек" % tag)
			n += 1
			Nav.handle_intent(Intent.CONTINUE, {}, s)
	return n


## Все три режима двери строятся явно — не ждём, пока случайность приведёт к каждому.
static func _check_doors(tag: String, out: PackedStringArray) -> int:
	var m: Match = Game.m
	var bots := m.alive_bots()
	var n := 0
	for role: Match.DoorRole in [Match.DoorRole.HOST, Match.DoorRole.GUEST, Match.DoorRole.ALONE]:
		var seat := Match.Seat.new()
		seat.house = 0
		if role == Match.DoorRole.GUEST:
			seat.host = bots[0]
			seat.queue = [m.player(), bots[1]] as Array[Villager]
		else:
			seat.host = m.player()
			if role == Match.DoorRole.HOST:
				seat.queue = [bots[0], bots[1], bots[2]] as Array[Villager]
		var d := DoorScreen.new()
		d.role = role
		d.seat = seat
		for g: Villager in seat.queue:
			d.pleas[g.id] = "Открой, тут холодно и кто-то ходит за забором, слышишь?"
		Nav.show(d)
		await _settle(Nav.get_tree())
		n += _check(tag, out)
		# до первого действия — не больше двух строк текста; пояснения — под «Подробнее»
		var lines := _reading_lines(d)
		if lines > 2:
			out.append("%s · дверь %s: до первого действия %d строк текста" % [tag, d.screen_id(), lines])
		var more := _more_text(d)
		if more.length() < 20:
			out.append("%s · дверь %s: в «Подробнее» пусто" % [tag, d.screen_id()])
		n += 2
	return n


## Строки текста, которые надо прочитать до действия: подписи в теле экрана и подвале,
## кроме надписей на кнопках и карточек стучащих (карточка — сама кнопка выбора).
static func _reading_lines(s: Screen) -> int:
	var total := 0
	for root: Control in [s.body, s.footer]:
		for c: Control in _controls(root):
			if not (c is Label) or not c.is_visible_in_tree():
				continue
			var skip := false
			var p := c.get_parent()
			while p != null and p != root:
				if p is Button or p.has_meta("action"):
					skip = true
					break
				p = p.get_parent()
			if not skip:
				total += maxi(1, (c as Label).get_visible_line_count())
	return total


static func _check(tag: String, out: PackedStringArray) -> int:
	var vp := Nav.frame.get_viewport_rect().size
	var s: Screen = Nav.host.current
	if s == null:
		out.append("%s: нет текущего экрана" % tag)
		return 1
	var w := "%s · %s" % [tag, s.screen_id()]
	if not _near(Nav.frame.size, vp):
		out.append("%s: SafeFrame %s, а экран %s" % [w, Nav.frame.size, vp])
	if Nav.host.size.x < 300.0 or Nav.host.size.y < vp.y * 0.8:
		out.append("%s: область экранов слишком мала: %s" % [w, Nav.host.size])
	if not _near(s.size, Nav.host.size):
		out.append("%s: экран %s не растянут на область %s" % [w, s.size, Nav.host.size])
	if s.footer.get_child_count() > 0 and s.size.y > 0.0:
		var unused := s.get_global_rect().end.y - s.footer.get_global_rect().end.y
		if unused > maxf(48.0 * ThemeFactory.text_scale, s.size.y * 0.05):
			out.append("%s: под нижними кнопками пустует %d px" % [w, int(unused)])
	if s.scroll.size.y < maxf(56.0, vp.y * s.min_content_ratio()):
		out.append("%s: под содержимое всего %d px из %d" % [w, int(s.scroll.size.y), int(vp.y)])
	if s is DayScreen and s.field_rect_local().size.y < Nav.host.size.y * 0.55:
		out.append("%s: поле дня %d px — меньше 55%% экрана (%d)" % [w, int(s.field_rect_local().size.y), int(Nav.host.size.y)])
	var ins := Nav.frame.insets
	var safe := Rect2(ins.x, ins.y, vp.x - ins.x - ins.z, vp.y - ins.y - ins.w)
	var hr := Nav.host.get_global_rect()
	if hr.position.y < safe.position.y - 1.0 or hr.end.y > safe.end.y + 1.0:
		out.append("%s: интерфейс заходит под вырез или жестовую панель (%d…%d, безопасно %d…%d)" % [
			w, int(hr.position.y), int(hr.end.y), int(safe.position.y), int(safe.end.y)])
	if s.field_ratio() > 0.0 and s.door_open() < 0.0:
		var fld := s.field_rect_local()
		fld.position += Nav.host.global_position
		var band := Nav.village.band_global_rect()
		if fld.size.y < vp.y * 0.18:
			out.append("%s: поле схлопнуто (%d px)" % [w, int(fld.size.y)])
		if Nav.village.modulate.a < 0.9:
			out.append("%s: посёлок не виден" % w)
		# полоса с домами внутри поля; лишняя высота поля — 3/4 сверху (небо), 1/4 снизу
		var extra := fld.size.y - band.size.y
		var want_top := fld.position.y + maxf(0.0, extra) * VillageView.SKY_SHARE
		if extra >= 0.0 and absf(band.position.y - want_top) > 3.0:
			out.append("%s: посёлок не на своём месте в поле (верх %d, ждали %d)" % [w, int(band.position.y), int(want_top)])
		if extra >= -1.0 and (band.position.y < fld.position.y - 1.0 or band.end.y > fld.end.y + 1.0):
			out.append("%s: полоса с домами вылезает из поля" % w)
		if band.size.y > fld.size.y + 3.0:
			out.append("%s: дома не влезают в поле (%d > %d)" % [w, int(band.size.y), int(fld.size.y)])
		if Nav.village.scale.x < MIN_FIELD_SCALE:
			out.append("%s: дома мельче %d%% от задуманного (масштаб %.2f)" % [w, int(MIN_FIELD_SCALE * 100), Nav.village.scale.x])
		var zoomed := s.field_zoom() > 1.0
		var me_f: VillagerFigure = Nav.village.crowd.figures.get(0)
		if not zoomed and absf(band.get_center().x - vp.x * 0.5) > 2.0:
			out.append("%s: посёлок не по центру по горизонтали" % w)
		if zoomed:
			# день: камера приближена и смотрит на игрока; посёлок шире экрана, но без пустых краёв
			var left_edge: float = Nav.village.to_global(Vector2(0, 0)).x
			var right_edge: float = Nav.village.to_global(Vector2(VillageView.LOGICAL.x, 0)).x
			if left_edge > 20.0 * Nav.village.scale.x + 1.0 or right_edge < vp.x - 20.0 * Nav.village.scale.x - 1.0:
				out.append("%s: камера дня ушла за край посёлка (%d…%d)" % [w, int(left_edge), int(right_edge)])
			if me_f != null:
				var mx: float = me_f.get_global_transform_with_canvas().origin.x
				if mx < vp.x * 0.2 or mx > vp.x * 0.8:
					out.append("%s: днём игрок не в середине кадра (x=%d)" % [w, int(mx)])

		field_scales.append(Nav.village.scale.x)
		if absf(Nav.scrim.top - fld.end.y) > 3.0:
			out.append("%s: затемнение не у нижнего края поля (%d vs %d)" % [w, int(Nav.scrim.top), int(fld.end.y)])
		for f: VillagerFigure in Nav.village.crowd.figures.values():
			if not f.visible or f.state == VillagerFigure.State.GONE:
				continue
			var gp := f.get_global_transform_with_canvas().origin
			var half := 16.0 * Nav.village.scale.x
			if zoomed:
				# днём край кадра — не край посёлка: житель обязан стоять внутри посёлка,
				# а игрок — целиком на экране
				if f.position.x < VillageView.SAFE_X.x - 1.0 or f.position.x > VillageView.SAFE_X.y + 1.0:
					out.append("%s: житель %s вне посёлка (x=%d)" % [w, f.who, int(f.position.x)])
				if f.is_player and (gp.x - half < -1.0 or gp.x + half > vp.x + 1.0):
					out.append("%s: игрок за краем экрана (x=%d)" % [w, int(gp.x)])
			elif gp.x - half < -1.0 or gp.x + half > vp.x + 1.0:
				out.append("%s: житель %s за краем экрана (x=%d)" % [w, f.who, int(gp.x)])
	elif Nav.village.modulate.a > 0.05:
		out.append("%s: посёлок виден там, где должен быть скрыт" % w)
	if s.hint != null and is_instance_valid(s.hint):
		var hr2 := s.hint.card_rect_global()
		if hr2.position.y < -1.0 or hr2.end.y > vp.y + 1.0 or hr2.position.x < -1.0 or hr2.end.x > vp.x + 1.0:
			out.append("%s: подсказка за краем экрана (%s)" % [w, hr2])
		if hr2.size.y > vp.y * 0.4:
			out.append("%s: подсказка высотой %d px — больше 40%% экрана" % [w, int(hr2.size.y)])
	var fr := s.footer.get_global_rect()
	if fr.end.y > vp.y + 1.0:
		out.append("%s: нижние кнопки уходят за экран (%d > %d)" % [w, int(fr.end.y), int(vp.y)])
	for c: Control in _controls(s):
		if not c.is_visible_in_tree() or _is_fullscreen_scrim(c):
			continue
		var r := c.get_global_rect()
		if r.position.x < -1.0 or r.end.x > vp.x + 1.0:
			out.append("%s: %s вылезает за край по ширине (%d…%d из %d)" % [
				w, _label_of(c), int(r.position.x), int(r.end.x), int(vp.x)])
		if c is BaseButton and r.size.y < MIN_TOUCH - 0.5:
			out.append("%s: кнопка «%s» высотой %d px — меньше 48 dp" % [w, _label_of(c), int(r.size.y)])
		if c is Button and (c as Button).text != "":
			var b := c as Button
			var f := b.get_theme_font("font")
			var fs := b.get_theme_font_size("font_size")
			var sb := b.get_theme_stylebox("normal")
			var pad := sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
			var need := f.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad
			if b.autowrap_mode != TextServer.AUTOWRAP_OFF:
				# перенос по словам: влезть должно самое длинное слово, а по высоте — все строки
				need = 0.0
				for word: String in b.text.replace("\n", " ").split(" ", false):
					need = maxf(need, f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad)
				var tall := f.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad, fs).y
				if r.size.y + 1.0 < tall:
					out.append("%s: перенесённый текст не влезает в кнопку по высоте: «%s»" % [w, b.text.replace("\n", " ").left(30)])
			if r.size.x + 1.0 < need:
				out.append("%s: текст на кнопке обрезан: «%s» (%d px из нужных %d)" % [w, b.text.replace("\n", " ").left(30), int(r.size.x), int(need)])
	return 1


## Скримы намеренно выходят за область безопасной зоны, чтобы затемнить весь дисплей.
static func _is_fullscreen_scrim(c: Control) -> bool:
	return c is ColorRect and c.offset_left <= -1000.0 and c.offset_top <= -1000.0 \
		and c.offset_right >= 1000.0 and c.offset_bottom >= 1000.0


static func _check_sheet(sheet: ActionSheet, tag: String, out: PackedStringArray) -> int:
	var w := "%s · шторка выбора" % tag
	var screen_rect := (sheet.get_parent() as Control).get_global_rect()
	var panel: PanelContainer = null
	for c: Node in sheet.get_children():
		if c is PanelContainer:
			panel = c
	if panel == null:
		out.append("%s: панель шторки не найдена" % w)
		return 1
	var r := panel.get_global_rect()
	if absf(r.end.y - screen_rect.end.y) > 2.0:
		out.append("%s: шторка не у нижнего края (низ %d, экран до %d)" % [w, int(r.end.y), int(screen_rect.end.y)])
	if absf(r.size.x - screen_rect.size.x) > 2.0:
		out.append("%s: шторка не во всю ширину (%d из %d)" % [w, int(r.size.x), int(screen_rect.size.x)])
	if r.size.y < MIN_TOUCH * 3.0:
		out.append("%s: шторка схлопнута (%d px)" % [w, int(r.size.y)])
	return 1


## Кампания (Task 58, 59, 63): главы, состав и погибшие насовсем, цели и звёзды, старт новичка со стука.
static func _campaign_checks(tree: SceneTree, fails: PackedStringArray) -> int:
	var ok := 0
	var games_before := int(Save.stats["games"])
	Save.campaign_reset()
	# состав: первые трое — постоянные жители, погибшие в пройденной главе не приходят
	var c1 := Campaign.cast("a1c1")
	ok += _expect(fails, c1.size() == 4 and c1.has(0) and c1.has(1) and c1.has(2), "в первой главе не те жители: %s" % [c1])
	var cfg2 := Campaign.config("a1c2")
	ok += _expect(fails, cfg2.players == 7 and cfg2.monsters == 1 and cfg2.player_always_human, "условия второй главы не применились")
	ok += _expect(fails, Campaign.unlocked("a1c1") and not Campaign.unlocked("a1c2"), "вторая глава открыта раньше первой")

	# новичок: «Играть» — сразу первая глава, и через несколько секунд стучат в дверь
	Save.stats["games"] = 0
	Nav.show_menu()
	await _settle(tree)
	var t0 := Time.get_ticks_msec()
	Nav.handle_intent(Intent.START, {}, Nav.host.current)
	await _settle(tree)
	var ds := Nav.host.current as DoorScreen
	var knock_ok := ds != null and ds.role == Match.DoorRole.HOST and not ds.seat.knockers().is_empty()
	if knock_ok:
		var humans := 0                      # через раз один из двоих — упырь, но сытый (TASK-013)
		for v: Villager in ds.seat.knockers():
			humans += 0 if v.is_upyr else 1
			knock_ok = knock_ok and (not v.is_upyr or v.fed)
		knock_ok = knock_ok and humans >= 1
	ok += _expect(fails, knock_ok and String(Game.chapter.get("id", "")) == "a1c1", "новичок после «Играть» не у двери со стуком (%s)" % [Nav.host.current])
	ok += _expect(fails, Time.get_ticks_msec() - t0 < 10000, "до стука дольше 10 секунд")
	ok += _expect(fails, Nav.village.crowd.figures.size() == Game.m.villagers.size(), "глава со стука началась без жителей на поле")
	if ds != null:
		var first: Array[int] = [ds.seat.knockers()[0].id]
		ds._finish_host(first)
		await _settle(tree)
	var mo := Nav.host.current
	ok += _expect(fails, mo is MorningScreen and mo.find_child("Goals", true, false) != null, "после первой ночи не видно целей главы")
	ok += _expect(fails, Campaign.goal_done(Game.m, "admit_night1"), "впустил в первую ночь, а цель не засчитана")

	# итог главы: пройдена — звёзды, погибшие насовсем, следующая открыта
	var m := Game.m
	var lost_bot: Villager = m.alive_bots()[0]
	lost_bot.alive = false
	m.winner = Match.Team.PEOPLE
	var res := Campaign.finish(m, Game.chapter)
	ok += _expect(fails, bool(res.passed) and int(res.stars) >= 2 and Save.campaign_stars.has("a1c1") and Save.campaign_dead.has(lost_bot.story_id),
		"пройденная глава не записалась: %s" % [res])
	ok += _expect(fails, Campaign.unlocked("a1c2") and not Campaign.cast("a1c2").has(lost_bot.story_id), "погибший пришёл в следующую главу")
	Game.chapter_result = res
	m.phase = Match.Phase.OVER
	Nav.show(EndScreen.new())
	await _settle(tree)
	var nxt := Nav.host.current.find_child("ChapterNext", true, false) as Button
	ok += _expect(fails, Nav.host.current.find_child("ChapterResult", true, false) != null and nxt != null and nxt.text.contains(L.t("camp.a1c2.title")),
		"в конце главы нет итога или кнопки следующей главы")
	# не пройдена — «Ещё раз», погибшие не записываются
	var dead_before := Save.campaign_dead.size()
	m.winner = Match.Team.UPYRI
	var fail_res := Campaign.finish(m, Campaign.chapter("a1c3"))
	ok += _expect(fails, not bool(fail_res.passed) and Save.campaign_dead.size() == dead_before and not Save.campaign_stars.has("a1c3"),
		"проваленная глава записала погибших или звёзды")

	# вторая глава: сцена главы с текстом главы и целями
	if nxt != null:
		nxt.pressed.emit()
		await _settle(tree)
	var ps := Nav.host.current as PrologueScreen
	ok += _expect(fails, ps != null and ps._beat_text.text in [L.t("camp.a1c2.beat1"), L.t("camp.a1c2.beat2"), String(Revelations.beat("boat", Game.m)[1])] and ps._cast.find_child("Goals", true, false) != null,
		"вторая глава началась без своей сцены и целей")
	ok += _expect(fails, Game.m.force_event == Match.Event.FOG and Game.m.villagers.size() == 7, "во второй главе нет тумана или не тот состав")

	# экран глав: открытая и закрытая глава, акты «скоро», память о погибших, концовка акта
	Nav.show_campaign()
	await _settle(tree)
	var cs := Nav.host.current
	var b1 := cs.find_child("Chapter_a1c1", true, false) as Button
	var b3 := cs.find_child("Chapter_a1c3", true, false) as Button
	ok += _expect(fails, b1 != null and not b1.disabled and b3 != null and b3.disabled and cs.find_child("Soon_4", true, false) == null and cs.find_child("Chapter_a4c3", true, false) != null and cs.find_child("Chapter_a2c1", true, false) != null
		and cs.find_child("Fallen", true, false) != null, "экран глав: не видно открытых, закрытых, будущих актов или погибших")
	var none_lost: Array[int] = []
	Save.record_chapter("a1c2", 3, none_lost)
	Save.record_chapter("a1c3", 1, none_lost)
	Nav.show_campaign()
	await _settle(tree)
	var act_end := Nav.host.current.find_child("ActEnd_1", true, false)
	ok += _expect(fails, act_end != null and not _all_text(act_end).contains("{") and not _all_text(act_end).is_empty(), "после третьей главы нет концовки акта")
	ok += _expect(fails, not _all_text(Nav.host.current).contains("{"), "на экране глав метка подстановки")

	# акт II: своя карта мельницы, свои названия убежищ с падежами, дождь; после главы — снова деревня
	ok += _expect(fails, Campaign.unlocked("a2c1") and Campaign.act_ending(2) != "", "акт II не открылся после акта I")
	Nav.start_chapter("a2c1")
	await _settle(tree)
	var mm := Game.m
	var mill_names := L.houses("houses_mill")
	ok += _expect(fails, mm.village.ground == "ground_mill" and Nav.village.def == mm.village and mm.houses[0] == mill_names[0]
		and Nav.village.titles[0] == mill_names[0] and mm.force_event == Match.Event.RAIN,
		"глава акта II не на карте мельницы")
	ok += _expect(fails, L.fill("{h.in}", {"h": mill_names[1]}) == "Мельничном дворе" and L.fill("{h.of}", {"h": mill_names[2]}) == "Скита",
		"у убежищ мельницы нет падежей")
	Nav.show_menu()
	await _settle(tree)
	ok += _expect(fails, Nav.village.def == Nav.default_village and Nav.village.titles[0] == L.houses()[0], "после главы на мельнице меню осталось на чужой карте")
	ok += _expect(fails, not Campaign.chapter("a2c2").get("guest_roles", "story") == "story" and Campaign.last_of_act("a1c3") and Campaign.last_of_act("a2c3")
		and not Campaign.last_of_act("a2c1"), "акты разбиты неверно")

	# акт III: монастырь со своими убежищами и падежами, туман в первой главе, концовка акта
	var no_lost: Array[int] = []
	for cid: String in ["a2c1", "a2c2", "a2c3"]:
		Save.record_chapter(cid, 1, no_lost)
	ok += _expect(fails, Campaign.unlocked("a3c1") and not Campaign.unlocked("a3c2"), "акт III не открылся после акта II")
	Nav.start_chapter("a3c1")
	await _settle(tree)
	var mon := L.houses("houses_monastery")
	ok += _expect(fails, Game.m.village.houses_key == "houses_monastery" and Nav.village.titles[0] == mon[0] and Game.m.houses[0] == mon[0]
		and Game.m.force_event == Match.Event.FOG, "глава акта III не в монастыре")
	ok += _expect(fails, L.fill("{h.in}", {"h": mon[3]}) == "Крипте" and String(Campaign.chapter("a3c2").get("event", "")) == "quiet"
		and Campaign.last_of_act("a3c3") and not Campaign.last_of_act("a3c1") and Campaign.act_ending_id(3).begins_with("act3_")
		and Campaign.act_ending(3) != "", "акт III собран неверно")
	# рассказчик главы: на второй странице сцены портрет и имя брата Игната
	Nav.start_chapter("a3c1")
	await _frames(tree, 4)
	var pro := Nav.host.current
	var narr: Control = null
	if pro is PrologueScreen:
		(pro as PrologueScreen)._advance()
		await _frames(tree, 2)
		narr = pro.find_child("Narrator", true, false) as Control
	ok += _expect(fails, narr != null and narr.visible and _all_text(narr).contains(L.t("narr.ignat")), "в главе акта III нет рассказчика (%s)" % pro.screen_id())
	await _settle(tree)
	Nav.show_menu()
	await _settle(tree)

	# акт IV и финал сезона: станция, свои убежища, состав главы не больше живых жителей кампании
	for cid: String in ["a3c1", "a3c2", "a3c3"]:
		Save.record_chapter(cid, 1, no_lost)
	ok += _expect(fails, Campaign.unlocked("a4c1") and not Campaign.unlocked("a4c2"), "акт IV не открылся после акта III")
	Nav.start_chapter("a4c1")
	await _settle(tree)
	var st := L.houses("houses_station")
	ok += _expect(fails, Game.m.village.houses_key == "houses_station" and Nav.village.titles[0] == st[0] and Game.m.force_event == Match.Event.RAIN,
		"глава акта IV не на станции")
	Nav.show_menu()
	await _settle(tree)
	var fin_end := Campaign.act_ending(4)
	ok += _expect(fails, L.fill("{h.in}", {"h": st[1]}) == "Водокачке" and Campaign.last_of_act("a4c3") and Campaign.next_of("a4c3") == ""
		and Campaign.act_ending_id(4).begins_with("act4_") and fin_end != "" and not fin_end.contains("{"), "финал сезона собран неверно")
	var saved_dead := Save.campaign_dead.duplicate()
	for i in range(3, L.names().size()):
		if not Save.campaign_dead.has(i):
			Save.campaign_dead.append(i)
	ok += _expect(fails, Campaign.config("a4c3").players == Campaign.MIN_PLAYERS and Campaign.cast("a4c3").size() <= 3,
		"погибшие насовсем возвращаются в главу: жителей %d" % Campaign.config("a4c3").players)
	Save.campaign_dead = saved_dead

	Save.campaign_reset()
	Save.stats["games"] = games_before
	Save.flush()
	return ok


## Гости (Task 60), объём реплик (Task 52), опыт и Книга посёлка (Task 62).
static func _guests_progress_checks(tree: SceneTree, fails: PackedStringArray) -> int:
	var ok := 0
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	# 52: реплик по-русски не меньше 600 вместе с общим банком; у каждого характера свой голос в 16 ситуациях
	var common := 0
	for k: String in L.gram().d():
		if k.begins_with("ph."):
			common += L.arr(k).size()
	ok += _expect(fails, Voices.total() + common >= 600, "реплик меньше 600: %d" % (Voices.total() + common))
	# гость по сюжету кампании: торговец — упырь, упырей столько же, сколько задано; родни у гостя нет
	var mg := Match.new()
	mg.guests = PackedStringArray(["merchant", "soldier"])
	mg.guest_roles_fixed = true
	mg.start(c, 4242)
	var merchant: Villager = null
	var soldier: Villager = null
	var upyri := 0
	for v: Villager in mg.villagers:
		if v.guest_id == "merchant": merchant = v
		if v.guest_id == "soldier": soldier = v
		if v.is_upyr: upyri += 1
	ok += _expect(fails, merchant != null and merchant.is_upyr and soldier != null and not soldier.is_upyr and upyri == c.monsters
		and merchant.name == L.t("guest.merchant.name") and merchant.partner_id < 0 and merchant.family_id < 0,
		"гости кампании: роль, имя или число упырей не те")
	ok += _expect(fails, not SocialContent.person_title(merchant).contains("{") and SocialContent.story(merchant.story_id, merchant) == Guests.story(merchant),
		"у гостя чужая биография")
	var gs_ok := true
	for gid: String in Guests.IDS:
		var gsid := VillagerFigure.guest_sprite(gid)
		gs_ok = gs_ok and gsid > 0 and VillagerFigure.folk_tex(gsid) != null
	ok += _expect(fails, gs_ok, "у гостей нет своих картинок")
	var clues_ok := true
	for d in range(1, Guests.REVEAL_DAY + 1):
		mg.day = d
		var cl := Guests.morning_clues(mg)
		clues_ok = clues_ok and cl.size() == 2
		for x: Dictionary in cl:
			clues_ok = clues_ok and not String(x.text).contains("{") and bool(x.reveal) == (d == Guests.REVEAL_DAY)
	mg.day = Guests.REVEAL_DAY
	clues_ok = clues_ok and Guests.clue(merchant, 3) == L.t("guest.merchant.reveal_u", {"who": merchant}) \
		and Guests.clue(soldier, 3) == L.t("guest.soldier.reveal_h", {"who": soldier})
	ok += _expect(fails, clues_ok, "улики гостей по утрам или разгадка не те")
	var dg := Director.new()
	dg.attach(mg)
	var before := dg.susp(merchant.id)
	dg.read_report(NightReport.new())
	ok += _expect(fails, dg.susp(merchant.id) > before, "разгадка упыря-гостя не подняла подозрение")
	ok += _expect(fails, SocialContent.personal_chapter(merchant, 1) == Guests.clue(merchant, 1), "разговор наедине с гостем не даёт улику")
	# утро: карточка гостя
	Nav.start_match()
	await _settle(tree)
	var gm := Game.m
	var gv: Villager = gm.alive_bots()[gm.alive_bots().size() - 1]
	Guests.apply(gm, gv, "widow")
	gm.day = 1
	gm.phase = Match.Phase.MORNING
	gm.report = NightReport.new()
	Nav.show(MorningScreen.new())
	await _settle(tree)
	ok += _expect(fails, Nav.host.current.find_child("Guest_widow", true, false) != null, "утром нет карточки о госте")
	# кампания: гости главы и погибшие гости
	Save.campaign_reset()
	ok += _expect(fails, Array(Campaign.guests("a1c2")) == ["soldier", "widow"], "во второй главе не те гости")
	var none: Array[int] = []
	Save.record_chapter("a1c2", 1, none, PackedStringArray(["widow"]))
	ok += _expect(fails, not Campaign.guests("a1c3").has("widow") and Campaign.fallen().size() == 1, "погибший гость вернулся")
	Save.campaign_reset()

	# 62: опыт, уровень, книга, концовки, достижения
	var keep := [Save.xp, Save.achievements.duplicate(), Save.book.duplicate(), Save.endings.duplicate()]
	Save.xp = 0
	Save.achievements.clear()
	Save.book.clear()
	Save.endings.clear()
	ok += _expect(fails, Progress.level_of(0) == 1 and Progress.level_of(99) == 1 and Progress.level_of(100) == 2 and not Progress.title(5).is_empty(),
		"уровни посёлка считаются неверно")
	var mp := Match.new()
	mp.start(c, 777)
	mp.day = 3
	mp.winner = Match.Team.PEOPLE
	mp.player().is_upyr = false
	var dead_bot: Villager = mp.alive_bots()[0]
	dead_bot.alive = false
	var pr := Progress.record(mp, {})
	var keys := PackedStringArray()
	for l: Array in pr.lines:
		keys.append(String(l[0]))
	ok += _expect(fails, keys.has("xp.game") and keys.has("xp.nights") and keys.has("xp.win") and int(pr.gained) > 0 and Save.xp == int(pr.gained),
		"опыт за партию не начислен: %s" % [keys])
	ok += _expect(fails, Progress.book_entry("n%d" % dead_bot.story_id)[0] == 1 and Progress.book_entry("n%d" % dead_bot.story_id)[1] == 1
		and Save.endings.has("people") and Save.achievements.has("night1") and (pr.new_ach as PackedStringArray).has("night1"),
		"книга, концовки или достижения не записались")
	Game.progress_result = pr
	gm.phase = Match.Phase.OVER
	gm.winner = Match.Team.PEOPLE
	Nav.show(EndScreen.new())
	await _settle(tree)
	ok += _expect(fails, Nav.host.current.find_child("Progress", true, false) != null and Nav.host.current.find_child("Ach_night1", true, false) != null,
		"в итоге партии нет опыта или нового достижения")
	Nav.show_book()
	await _settle(tree)
	var bk := Nav.host.current
	var person := bk.find_child("Person_n%d" % dead_bot.story_id, true, false)
	ok += _expect(fails, bk is BookScreen and person != null and _all_text(person).contains(dead_bot.name)
		and bk.find_child("Ending_people", true, false) != null and bk.find_child("Ach_night1", true, false) != null
		and not _all_text(bk).contains("{"), "Книга посёлка: нет жителей, концовок или достижений")
	Save.xp = int(keep[0])
	Save.achievements = keep[1]
	Save.book.assign(keep[2])
	Save.endings = keep[3]
	Save.flush()
	Game.progress_result = {}
	return ok


## Весь текст подписей, даже вне дерева сцены (карточка ещё не показана).
static func _all_text_raw(root: Node) -> String:
	var out := PackedStringArray()
	for n: Node in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return "\n".join(out)


static func _controls(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for c: Node in root.get_children():
		if c is Control:
			out.append(c)
		out.append_array(_controls(c))
	return out


static func _label_of(c: Control) -> String:
	if c is Button:
		return (c as Button).text.left(24)
	if c is Label:
		return "текст «%s»" % (c as Label).text.left(24)
	return c.get_class()


static func _near(a: Vector2, b: Vector2) -> bool:
	return absf(a.x - b.x) <= 1.5 and absf(a.y - b.y) <= 1.5


static func _frames(tree: SceneTree, n: int) -> void:
	for i in range(n):
		await tree.process_frame



# =============================================================
# Жизненный цикл: сворачивание, возврат, «Назад», удержание экрана.
# =============================================================
static func lifecycle() -> void:
	var tree := Nav.get_tree()
	var root := tree.root
	var fails: PackedStringArray = []
	var passed := 0

	Nav.show_menu()
	await _frames(tree, 2)
	passed += _expect(fails, not Game.screen_kept_on, "в меню экран не должен держаться включённым")

	Nav.start_match()
	await _frames(tree, 2)
	passed += _expect(fails, Game.screen_kept_on, "в партии экран должен держаться включённым")
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1 # открывающие реплики с вопросом игроку тестируются отдельно
	await _frames(tree, 3)

	# 1. Свернули посреди дня — таймер стоит, вернулись — идёт
	var before := Game.clock.time_left()
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await tree.create_timer(1.2).timeout
	var during := Game.clock.time_left()
	passed += _expect(fails, absf(before - during) < 0.05,
		"день: таймер шёл, пока игра свёрнута (%.2f → %.2f)" % [before, during])
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await tree.create_timer(0.7).timeout
	passed += _expect(fails, Game.clock.time_left() < during - 0.3, "день: после возврата таймер не пошёл")

	# 2. Огромная дельта первого кадра после фона не сжигает таймер
	var t := Game.clock.time_left()
	Game.clock._process(120.0)
	passed += _expect(fails, t - Game.clock.time_left() <= PhaseClock.MAX_STEP + 0.01,
		"один кадр съел %.1f с таймера" % (t - Game.clock.time_left()))

	# 3. «Назад» посреди партии — вопрос, таймер стоит; второе «Назад» — закрыть вопрос
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(tree, 3)
	passed += _expect(fails, _sheet(Nav.host.current) != null, "«Назад» посреди партии не спросил «Бросить партию?»")
	var b := Game.clock.time_left()
	await tree.create_timer(0.8).timeout
	passed += _expect(fails, absf(b - Game.clock.time_left()) < 0.05, "таймер шёл, пока открыт вопрос")
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(tree, 3)
	passed += _expect(fails, _sheet(Nav.host.current) == null and Game.active(),
		"второе «Назад» должно закрыть вопрос и оставить партию")
	var b2 := Game.clock.time_left()
	await tree.create_timer(0.6).timeout
	passed += _expect(fails, Game.clock.time_left() < b2 - 0.3, "после закрытия вопроса таймер не пошёл")

	# 4. Свернули посреди двери — таймер двери стоит
	var door_ok := false
	for attempt in range(40):
		Nav.start_match()
		Game.proceed()
		Game.end_day()
		if Game.m.phase == Match.Phase.VOTE:
			Game.vote(-1)
			Game.proceed()
		if Game.m.phase != Match.Phase.NIGHT:
			continue
		Game.choose_house(0)
		await _frames(tree, 2)
		var role := Game.door_role() if Game.m.phase == Match.Phase.DOOR else Match.DoorRole.DEAD
		if role != Match.DoorRole.HOST and role != Match.DoorRole.GUEST:
			continue
		var d0 := Game.clock.time_left()
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		await tree.create_timer(1.0).timeout
		passed += _expect(fails, absf(d0 - Game.clock.time_left()) < 0.05 and Game.m.phase == Match.Phase.DOOR,
			"дверь: таймер шёл или дверь закрылась, пока игра свёрнута")
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		await tree.create_timer(0.6).timeout
		passed += _expect(fails, Game.clock.time_left() < d0 - 0.3, "дверь: после возврата таймер не пошёл")
		door_ok = true
		break
	passed += _expect(fails, door_ok, "не удалось дойти до двери в роли хозяина или гостя")

	# 5. «Выйти в меню» из вопроса — меню, партия брошена, экран снова гаснет
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(tree, 3)
	var sh := _sheet(Nav.host.current)
	if sh != null:
		sh.close(1)
	await _frames(tree, 3)
	passed += _expect(fails, Nav.host.current is MenuScreen and not Game.active() and not Game.screen_kept_on,
		"«Выйти в меню» должно вернуть в меню, бросить партию и отпустить экран")

	# 6. «Назад» в настройках — сохранить и в меню
	Nav.show_settings()
	await _frames(tree, 2)
	(Nav.host.current as SettingsScreen).haptics = false
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(tree, 3)
	passed += _expect(fails, Nav.host.current is MenuScreen and not Save.haptics,
		"«Назад» в настройках должно сохранить и вернуть в меню")
	Save.set_settings(Save.config, true)

	# 7. Итог партии — экран отпущен; «Назад» — в меню
	Nav.start_match()
	await _frames(tree, 2)
	Game.m.winner = Match.Team.PEOPLE
	Game.m.phase = Match.Phase.MORNING
	Game.m.end_morning()
	await _frames(tree, 3)
	passed += _expect(fails, Nav.host.current is EndScreen and not Game.screen_kept_on,
		"на итоге партии экран должен отпускаться")
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(tree, 3)
	passed += _expect(fails, Nav.host.current is MenuScreen, "«Назад» на итоге должно вернуть в меню")

	# 8. «Назад» в меню — только взводит выход, игра работает
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(tree, 2)
	passed += _expect(fails, Nav._exit_armed and Nav.host.current is MenuScreen,
		"первое «Назад» в меню должно только предупредить о выходе")

	# 9. Ввод своего текста по запросу: поле появляется, текст уходит в чат, «Назад» закрывает
	Nav.start_match()
	await _frames(tree, 2)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _frames(tree, 3)
	var ds := Nav.host.current as DayScreen
	ds._write_flow()
	await _frames(tree, 3)
	var ts: TextSheet = null
	for c: Node in ds.get_children():
		if c is TextSheet:
			ts = c
	passed += _expect(fails, ts != null and ts.field != null, "по кнопке «Написать своё…» не открылось поле ввода")
	if ts != null:
		ts.field.text = "Проверка ввода"
		ts.close(ts.field.text)
		await _frames(tree, 3)
		var last: ChatLine = Game.m.chat[Game.m.chat.size() - 1] if not Game.m.chat.is_empty() else null
		var mine_found := false
		for l: ChatLine in Game.m.chat:
			if l.kind == ChatLine.Kind.MINE and l.text == "Проверка ввода":
				mine_found = true
		passed += _expect(fails, mine_found, "текст из поля ввода не попал в чат")
	ds._write_flow()
	await _frames(tree, 3)
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(tree, 3)
	var still := false
	for c: Node in ds.get_children():
		if c is TextSheet and not c.is_queued_for_deletion():
			still = true
	passed += _expect(fails, not still and Game.active(), "«Назад» должно закрыть поле ввода и оставить партию")

	# 9б. Журнал дня: ряда плашек нет, строка журнала свежая, шторка со всеми репликами
	Nav.start_match()
	await _frames(tree, 2)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _frames(tree, 3)
	var dj := Nav.host.current as DayScreen
	var chips_row := false
	for c: Control in _controls(dj):
		if c is HFlowContainer and c.is_visible_in_tree():
			chips_row = true
	passed += _expect(fails, not chips_row, "на экране дня остался ряд плашек с именами")
	Game.say("Проверка журнала.")
	await _frames(tree, 3)
	var lastl: ChatLine = Game.m.chat[Game.m.chat.size() - 1]
	var want_prev := lastl.text if lastl.kind == ChatLine.Kind.SYSTEM else "%s: %s" % ["Вы" if lastl.kind == ChatLine.Kind.MINE else lastl.speaker.name, lastl.text]
	passed += _expect(fails, dj.journal_button.text == "Журнал (%d)" % Game.m.chat.size() and dj.journal_preview.text == want_prev,
		"строка журнала не обновилась: «%s» / «%s»" % [dj.journal_button.text, dj.journal_preview.text])
	dj.journal_button.pressed.emit()
	await _frames(tree, 3)
	var js: JournalSheet = null
	for c: Node in dj.get_children():
		if c is JournalSheet and not c.is_queued_for_deletion():
			js = c
	passed += _expect(fails, js != null and js.list.get_child_count() == Game.m.chat.size(),
		"шторка журнала не открылась или в ней не все реплики")
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(tree, 3)
	var still_js := false
	for c: Node in dj.get_children():
		if c is JournalSheet and not c.is_queued_for_deletion():
			still_js = true
	passed += _expect(fails, not still_js and Game.active(), "«Назад» должно закрыть журнал и оставить партию")

	# 10. Самописец: после аварийного выхода — экран отчёта с последними шагами
	Diag.enabled = true
	Diag.step("проверка самописца")
	Diag.set_running(true)
	Diag.check_previous()
	passed += _expect(fails, Diag.crashed_last_time and Diag.report_text().contains("проверка самописца"),
		"самописец не заметил аварийный выход или потерял шаги")
	Nav.show(CrashScreen.new())
	await _frames(tree, 3)
	passed += _expect(fails, Nav.host.current is CrashScreen, "экран отчёта о вылете не показался")
	Nav.handle_intent(Intent.BACK, {}, Nav.host.current)
	await _frames(tree, 3)
	passed += _expect(fails, Nav.host.current is MenuScreen, "из отчёта о вылете кнопка «Продолжить» должна вести в меню")
	Diag.set_running(false)
	Diag.check_previous()
	passed += _expect(fails, not Diag.crashed_last_time, "после нормального выхода самописец не должен видеть вылет")
	Diag.enabled = false

	# 11. Движок сцен (TASK-012): кадры, выбор в журнал, «Назад», сворачивание
	passed += await PlanTests.scene_engine(tree, fails)

	print("=== жизненный цикл: %d проверок ===" % (passed + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — сворачивание, возврат, «Назад» и удержание экрана работают")
		tree.quit(0)
	else:
		for f: String in fails:
			print("  ✗ " + f)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)


static func _expect(fails: PackedStringArray, ok: bool, what: String) -> int:
	if not ok:
		fails.append(what)
		return 0
	return 1


static func _sheet(s: Node) -> ActionSheet:
	if s == null:
		return null
	for c: Node in s.get_children():
		if c is ActionSheet and not (c as ActionSheet).is_queued_for_deletion():
			return c
	return null



# =============================================================
# Игровое поле (Task 4): посёлок на экране, туман движется, 30 fps в покое.
# =============================================================
static func field() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	var v := Nav.village
	Save.set_difficulty("normal")    # всегда обычная партия на 7 жителей, независимо от сохранённых настроек

	var vd := load("res://config/village_default.tres") as VillageDef
	ok += _expect(fails, vd != null and vd.shelters.size() == 5 and vd.decor.size() >= 3 and vd.lamps.size() == 3,
		"ресурс посёлка: ждём 5 убежищ, 3+ фоновых дома, 3 фонаря")
	for i in range(mini(vd.shelters.size(), L.houses().size())):
		ok += _expect(fails, vd.shelters[i].title == L.houses()[i],
			"убежище %d в ресурсе «%s», а в правилах «%s»" % [i, vd.shelters[i].title, L.houses()[i]])

	Nav.show_menu()
	await _settle(tree)
	ok += _expect(fails, v.modulate.a > 0.9, "в меню посёлок не виден")
	ok += _expect(fails, v.open_shelters() == Save.config.shelters and v.boarded_shelters() == 5 - Save.config.shelters,
		"открыто убежищ %d, заколочено %d — а по балансу открыто %d" % [v.open_shelters(), v.boarded_shelters(), Save.config.shelters])
	ok += _expect(fails, v.fog().emitting and v.fog().amount >= 10 and v.fog().initial_velocity_min > 0.0,
		"туман не идёт или стоит на месте")
	ok += _expect(fails, v.dust().emitting, "пыль не летит")

	# картинки посёлка: все загружены; дверь каждого дома на картинке стоит в точке, куда встаёт очередь;
	# табличка висит на самом доме; заставка запуска — та же ночная деревня
	var missing := PackedStringArray()
	for f: String in VillageView.ART_FILES + VillageView.GROUND_FILES:
		if not (v._tex.get(f) is Texture2D):
			missing.append(f)
	ok += _expect(fails, missing.is_empty(), "нет картинок посёлка: %s" % ", ".join(missing))
	var map_missing := PackedStringArray()
	for f: String in VillageView.MAP_FILES:
		if not (v._tex.get(f.get_basename()) is Texture2D):
			map_missing.append(f)
	ok += _expect(fails, map_missing.is_empty(), "нет неба, леса, тумана или дыма: %s" % ", ".join(map_missing))
	ok += _expect(fails, v.smoke_count() >= 2, "из труб не идёт дым: труб с дымом %d" % v.smoke_count())
	var no_prop := PackedStringArray()
	for pr: Dictionary in v.def.props:
		if not (v._tex.get(String(pr.id)) is Texture2D):
			no_prop.append(String(pr.id))
	ok += _expect(fails, v.def.props.size() >= 4 and no_prop.is_empty(), "реквизит посёлка: %d предметов, без картинки: %s" % [v.def.props.size(), ", ".join(no_prop)])
	var hz := v.hidden_zones().size()
	ok += _expect(fails, hz >= v.def.shelters.size() + v.def.decor.size() + 1 + v.def.props.size(), "жители могут встать за телегу или стог: зон %d" % hz)
	v.set_traces(PackedVector2Array([v.door_point(0)]), PackedVector2Array([v.door_point(0)]))
	v.set_rain(true)
	ok += _expect(fails, v.blood_spots.size() == 1 and v.trail_doors.size() == 1 and v.rain, "кровь, следы и лужи не ложатся на землю")
	v.set_traces(PackedVector2Array(), PackedVector2Array())
	v.set_rain(false)
	var door_closed := load("res://assets/ui/door_closed.png") as Texture2D
	var door_open := load("res://assets/ui/door_open.png") as Texture2D
	ok += _expect(fails, door_closed != null and door_open != null
		and door_closed.get_width() > 700 and door_closed.get_height() > 1000
		and door_open.get_width() > 700 and door_open.get_height() > 1000,
		"нет полноразмерных картинок закрытой и открытой двери")
	var art := Nav.atmos
	var night_before: float = art._param("night")
	var lamp_before: float = art._param("lamp_power")
	art.door(0.05, 0.0)
	ok += _expect(fails, art._door_art.visible and art._door_closed.modulate.a > 0.95
		and art._door_open.modulate.a < 0.05, "у двери не показана закрытая картинка")
	art.door(0.4, 0.0)
	ok += _expect(fails, art._door_open.modulate.a > 0.95 and art._door_closed.modulate.a < 0.05,
		"при открытии двери не переключается картинка")
	art.door(0.0, 0.0)
	ok += _expect(fails, art._door_closed.modulate.a > 0.95 and art._door_open.modulate.a < 0.05,
		"при закрытии двери не возвращается закрытая картинка")
	art.mood(night_before, lamp_before, 0.0)
	for i in range(v.open_shelters()):
		var sh: HouseDef = v.def.shelters[i]
		var dr := v.door_rect(sh)
		ok += _expect(fails, absf(dr.get_center().x - sh.pos.x) < 2.0 and absf(dr.end.y - sh.pos.y) < 2.0,
			"дверь убежища %d на картинке не там, где очередь (%s, а дверь %s)" % [i, sh.pos, dr])
		ok += _expect(fails, v.house_rect(sh).encloses(v.shelter_label_rect_local(i)), "табличка убежища %d висит мимо дома" % i)
	ok += _expect(fails, ProjectSettings.get_setting("application/boot_splash/show_image", false)
		and ResourceLoader.exists(String(ProjectSettings.get_setting("application/boot_splash/image", ""))), "нет заставки при запуске")
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") == OK:
		for key: String in ["main_192x192", "adaptive_foreground_432x432", "adaptive_background_432x432"]:
			var ip := String(presets.get_value("preset.0.options", "launcher_icons/" + key, ""))
			ok += _expect(fails, ip != "" and FileAccess.file_exists(ip), "у Android нет значка приложения %s" % key)

	var d0 := v.draws
	await _frames(tree, 60)
	ok += _expect(fails, v.draws - d0 <= 1, "посёлок перерисовывается в покое: %d раз за 60 кадров" % (v.draws - d0))
	await tree.create_timer(1.8).timeout
	ok += _expect(fails, Engine.max_fps == Juice.FPS_IDLE, "в покое %d fps вместо %d" % [Engine.max_fps, Juice.FPS_IDLE])

	Nav.start_match()
	await _settle(tree)
	# жители — картинки из листа: у каждого своя, пока хватает подходящих; подпись над домами
	var seen := {}
	var drawn_ok := true
	var women := 0
	var men := 0
	for f: VillagerFigure in v.crowd.figures.values():
		drawn_ok = drawn_ok and f.sprite_id > 0 and VillagerFigure.folk_tex(f.sprite_id) != null and f.tag.z_index > 0
		seen[f.sprite_id] = int(seen.get(f.sprite_id, 0)) + 1
		if f.look.female:
			women += 1
		else:
			men += 1
	ok += _expect(fails, drawn_ok, "жители не из картинок или подпись не над домами")
	var me0: VillagerFigure = v.crowd.figures[0]
	ok += _expect(fails, me0.sprite_id == VillagerFigure.hero_for(me0.look), "игрок не герой с фонарём (картинка %d)" % me0.sprite_id)
	ok += _expect(fails, seen.size() >= mini(women, VillagerFigure.FOLK_FEMALE.size()) + mini(men, VillagerFigure.FOLK_MALE.size()),
		"картинки жителей повторяются раньше времени (%d разных на %d женщин и %d мужчин)" % [seen.size(), women, men])
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	ok += _expect(fails, Nav.host.current is DayScreen and absf(v.night - 0.12) < 0.02,
		"днём посёлок должен быть дневным (ночь = %.2f)" % v.night)
	Game.end_day()
	await _settle(tree)
	if Game.m.phase == Match.Phase.VOTE:
		Game.vote(-1)
		await _settle(tree)
		Game.proceed()
		await _settle(tree)
	ok += _expect(fails, Nav.host.current is NightScreen and v.night > 0.95,
		"ночью посёлок должен быть ночным (ночь = %.2f)" % v.night)
	Game.choose_house(0)
	await _settle(tree)
	if Game.m != null and Game.m.phase == Match.Phase.DOOR:
		ok += _expect(fails, v.modulate.a < 0.05, "у двери посёлок должен скрываться — там крупный план двери")

	Nav.show_settings()
	await _settle(tree)
	ok += _expect(fails, v.modulate.a < 0.05, "в настройках посёлок должен быть скрыт")

	var keep := Save.config.duplicate() as GameConfig
	Save.set_settings(load("res://config/balance_10.tres") as GameConfig, Save.haptics)
	Nav.start_match()
	await _settle(tree)
	ok += _expect(fails, v.open_shelters() == 3 and v.boarded_shelters() == 2,
		"на 10 игроков ждём 3 открытых убежища, а открыто %d" % v.open_shelters())
	Save.set_settings(keep, Save.haptics)

	# --- Task 5: жители ---
	var cr := v.crowd
	Nav.start_match()
	await _settle(tree)
	ok += _expect(fails, cr.figures.size() == Game.m.villagers.size(),
		"на площади %d фигур, а жителей %d" % [cr.figures.size(), Game.m.villagers.size()])
	var me_fig: VillagerFigure = cr.figures[0]
	var front := true
	for f: VillagerFigure in cr.figures.values():
		if f.position.y > me_fig.position.y + 0.5:
			front = false
	ok += _expect(fails, me_fig.is_player and front, "ваша фигурка должна стоять ближе всех к зрителю")
	var sq := v.def.square_center
	var inside := true
	for f: VillagerFigure in cr.figures.values():
		if f.position.distance_to(cr.walk_clamp(f.position)) > 1.0:
			inside = false
	ok += _expect(fails, inside, "кто-то из жителей стоит за пределами площади")

	# дыхание: 16 замеров за 2 секунды — размах масштаба тела. Вдох длится ~3,7 с: за одну секунду
	# у вершины вдоха размах бывал ровно 0.010, и тест ложно падал.
	var probe: VillagerFigure = cr.figures[1]
	var lo_b := 9.0
	var hi_b := 0.0
	for k in range(16):
		await tree.create_timer(0.13).timeout
		lo_b = minf(lo_b, probe.body_scale().y)
		hi_b = maxf(hi_b, probe.body_scale().y)
	ok += _expect(fails, hi_b - lo_b > 0.001 and hi_b - lo_b < 0.012,
		"дыхание отсутствует или слишком сильно растягивает тело (размах %.3f)" % (hi_b - lo_b))

	Juice.instant = false
	var target := probe.position + Vector2(70, 0)
	probe.run_to(target, 0.5)
	var hi := 0.0
	var lo := 9.0
	for i in range(90):
		await tree.process_frame
		hi = maxf(hi, probe.body_scale().y)
		lo = minf(lo, probe.body_scale().y)
		if probe.state == VillagerFigure.State.IDLE and i > 10:
			break
	Juice.instant = true
	ok += _expect(fails, hi < 1.01 and lo > 0.99, "перемещение растягивает и сжимает корпус (%.2f / %.2f)" % [hi, lo])
	ok += _expect(fails, probe.position.distance_to(target) < 1.0, "житель не добежал до точки")

	Game.proceed()
	await _settle(tree)
	Save.mark_hint("night")     # подсказка первой ночи держит колокол — здесь проверяем сам бег
	Game.end_day()
	await _settle(tree)
	if Game.m.phase == Match.Phase.VOTE:
		Game.vote(-1)
		await _settle(tree)
		Game.proceed()
		await _settle(tree)
	# по колоколу боты бегут туда, куда решили на самом деле, и встают в порядке прибытия
	var runners := 0
	var wrong := PackedStringArray()
	var groups: Dictionary[int, Array] = {}
	for vv: Villager in Game.m.alive_bots():
		var hb: int = Game.run_choices.get(vv.id, -1)
		if hb >= 0 and hb < v.open_count:
			if not groups.has(hb):
				groups[hb] = []
			groups[hb].append(vv)
	var avoid := cr._avoid()
	for hh: int in groups:
		var members: Array = groups[hh]
		members.sort_custom(func(a: Villager, b: Villager) -> bool: return Game.run_arrive[a.id] < Game.run_arrive[b.id])
		var spots := cr.queue_spots(hh, members.size(), avoid)
		for k in range(mini(members.size(), spots.size())):
			var vv: Villager = members[k]
			runners += 1
			if cr.figures[vv.id].position.distance_to(spots[k]) > 2.0:
				wrong.append(vv.name)
			avoid.append(Crowd.slot_rect(spots[k], Crowd.QUEUE_COL - 2.0))
	ok += _expect(fails, runners > 0 and wrong.is_empty(), "ночью не добежали до своих домов: %s" % ", ".join(wrong))

	Game.choose_house(0)
	await _settle(tree)
	if Game.m.phase == Match.Phase.DOOR:
		var none: Array[int] = []
		if Game.door_role() == Match.DoorRole.GUEST:
			Game.plea("beg")
			await _settle(tree)
			Game.proceed()
		else:
			Game.admit(none)
		await _settle(tree)
	var bad_dead := PackedStringArray()
	for vv: Villager in Game.m.villagers:
		if not vv.alive and not vv.exiled and cr.figures[vv.id].state != VillagerFigure.State.DEAD:
			bad_dead.append(vv.name)
	ok += _expect(fails, bad_dead.is_empty(), "погибшие не стали надгробиями: %s" % ", ".join(bad_dead))

	Nav.show_menu()
	await _settle(tree)
	ok += _expect(fails, cr.figures.is_empty(), "в меню на площади остались жители")

	print("=== игровое поле: %d проверок ===" % (ok + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — посёлок на экране, туман и пыль идут, в покое без перерисовки и 30 fps")
		tree.quit(0)
	else:
		for f: String in fails:
			print("  ✗ " + f)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)


## Дождаться, пока экран разложится и поле под него откадрируется.
static func _settle(tree: SceneTree) -> void:
	await _frames(tree, 3)
	# Автотесты проходят интерактивное вступление, прежде чем ждать раскрытия роли.
	if Nav.host.current is PrologueScreen:
		var intro := Nav.host.current as PrologueScreen
		if intro._beat == 0:
			for k in range(intro._beats().size()):     # все страницы сцены, с откровениями главы
				intro._advance()
	for i in range(30):
		if Nav.field_screen == Nav.host.current:
			break
		await tree.process_frame
	for i in range(150):
		if Nav.host.current == null or not Nav.host.current.is_busy():
			break
		await tree.process_frame
	await _frames(tree, 2)



# =============================================================
# Толпа (Task 6): от 5 до 12 жителей на 7 типах экранов.
# Днём на площади и ночью у каждой двери — все в кадре, имена не налезают
# друг на друга и не прячутся за спинами тех, кто стоит ближе.
# =============================================================
static func crowd() -> void:
	var tree := Nav.get_tree()
	var problems: PackedStringArray = []
	var checks := 0
	var keep := Save.config.duplicate() as GameConfig
	var profiles: Array[Array] = []
	for sz: Vector2i in LAYOUT_SIZES:
		profiles.append([sz, Vector4(-1, -1, -1, -1)])
	profiles.append_array(LAYOUT_CUTOUTS)
	for prof: Array in profiles:
		var sz: Vector2i = prof[0]
		Nav.frame.debug_insets = prof[1]
		tree.root.size = sz
		await _frames(tree, 3)
		Nav.frame.refresh()
		for n in range(5, 13):
			var c := GameConfig.new()
			c.players = n
			c.monsters = maxi(1, int(round(n * 0.3)))
			c.shelters = clampi(int(ceil(n * 0.3)), 1, 5)
			Save.config = c.sanitized()
			Nav.start_match()
			await _settle(tree)
			var tag := "%d×%d · %d жителей" % [sz.x, sz.y, n]
			checks += _check_crowd(tag + " · день", problems)
			# ночью: дома распределяет сам ИИ — теми же правилами, что в партии (в доме не больше
			# двух по своей воле, остальные — в самый пустой). Сверху нагрузка: к одной двери ещё
			# один, как при уговоре сверх вместимости. Расставляет игровой код.
			var cr := Nav.village.crowd
			var bots := Game.m.alive_bots()
			for hi in range(Game.m.config.shelters):
				Game.director.plan_day()
				var moved := 0
				for b: Villager in bots:
					if moved < 1 and b.announced_house != hi:
						b.announced_house = hi
						moved += 1
				cr.arrange_night(Game.m, -1)
				await _frames(tree, 1)
				checks += _check_crowd("%s · ночь у «%s»" % [tag, Game.m.house_name(hi)], problems)
			# настоящий экран дня: камера ближе и смотрит на игрока
			Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
			await _settle(tree)
			checks += _check_crowd(tag + " · экран дня", problems)
	Nav.frame.debug_insets = Vector4(-1, -1, -1, -1)
	Save.config = keep
	print("=== толпа: %d раскладок проверено ===" % checks)
	if problems.is_empty():
		print("ИТОГ: OK — от 5 до 12 жителей, днём и ночью, все в кадре и все имена читаются")
		tree.quit(0)
	else:
		for p: String in problems.slice(0, 25):
			print("  ✗ " + p)
		print("ИТОГ: НАРУШЕНИЙ: %d" % problems.size())
		tree.quit(1)


static func _check_crowd(tag: String, out: PackedStringArray) -> int:
	var vp := Nav.frame.get_viewport_rect().size
	var fld := Nav.host.current.field_rect_local()
	fld.position += Nav.host.global_position
	var bottom := Nav.scrim.top
	var figs: Array[VillagerFigure] = []
	for f: VillagerFigure in Nav.village.crowd.figures.values():
		if f.visible and f.state != VillagerFigure.State.GONE:
			figs.append(f)
	var zoomed := Nav.host.current.field_zoom() > 1.0
	for f: VillagerFigure in figs:
		var lr := f.label_rect_global()
		var br := f.body_rect_global()
		var all := lr.merge(br)
		var off := all.position.x < -1.0 or all.end.x > vp.x + 1.0
		if zoomed:
			# днём камера ближе: край кадра — не край посёлка
			if f.position.x < VillageView.SAFE_X.x - 1.0 or f.position.x > VillageView.SAFE_X.y + 1.0:
				out.append("%s: %s вне посёлка" % [tag, f.who])
			if f.is_player and off:
				out.append("%s: игрок за краем экрана" % tag)
		elif off:
			out.append("%s: %s за краем экрана" % [tag, f.who])
		if all.end.y > bottom + 2.0:
			out.append("%s: %s уходит под нижнюю панель (низ %d, граница %d)" % [tag, f.who, int(all.end.y), int(bottom)])
		if all.position.y < fld.position.y - 40.0:
			out.append("%s: %s выше поля" % [tag, f.who])
	var vv := Nav.village
	# за домом или колодцем никто не стоит: слой толпы сортируется по глубине, и дом закрыл бы фигуру
	for f: VillagerFigure in figs:
		if f.state != VillagerFigure.State.RUN and vv.crowd._hidden(f.position):
			out.append("%s: %s стоит за домом или колодцем (%s)" % [tag, f.who, f.position])
	for hi in range(vv.open_count):
		var plaque := vv.shelter_label_rect_global(hi).grow(-1.0)
		for f: VillagerFigure in figs:
			if plaque.intersects(f.body_rect_global().grow(-2.0)) or plaque.intersects(f.label_rect_global().grow(-1.0)):
				out.append("%s: табличку «%s» закрывает %s (табличка %s, тело %s, имя %s)" % [tag, vv._title(hi), f.who, plaque, f.body_rect_global(), f.label_rect_global()])
	for i in range(figs.size()):
		for j in range(figs.size()):
			if i == j:
				continue
			var a := figs[i]
			var b := figs[j]
			var la := a.label_rect_global().grow(-1.0)
			if j > i and la.intersects(b.label_rect_global().grow(-1.0)):
				out.append("%s: имена «%s» и «%s» налезают друг на друга (%s %s / %s %s)" % [tag, a.who, b.who, a.position, a.label_rect_global(), b.position, b.label_rect_global()])
			if b.position.y > a.position.y + 0.5 and la.intersects(b.body_rect_global().grow(-2.0)):
				out.append("%s: имя «%s» закрыто фигурой %s" % [tag, a.who, b.who])
	return 1



# =============================================================
# Пузыри реплик (Task 7): шквал реплик на 7 типах экранов. Пузыри не налезают
# друг на друга, не выходят за поле и экран, свежая реплика видна над говорящим.
# =============================================================
static func bubbles() -> void:
	var tree := Nav.get_tree()
	var problems: PackedStringArray = []
	var checks := 0
	var texts: PackedStringArray = []
	for bank: PackedStringArray in [Phrases.b("ACCUSE_STRONG"), Phrases.b("UPYR_DEFLECT"), Phrases.b("DEFEND"), Phrases.b("FILLER"), Phrases.b("ANNOUNCE")]:
		texts.append_array(bank)
	texts.append("Я вчера сидел тихо и дожил. Значит, всё делал правильно, а вы тут спорите о пустом.")
	var profiles: Array[Array] = []
	for sz: Vector2i in LAYOUT_SIZES:
		profiles.append([sz, Vector4(-1, -1, -1, -1)])
	profiles.append_array(LAYOUT_CUTOUTS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for prof: Array in profiles:
		var sz: Vector2i = prof[0]
		Nav.frame.debug_insets = prof[1]
		tree.root.size = sz
		await _frames(tree, 3)
		Nav.frame.refresh()
		Nav.start_match()
		await _settle(tree)
		Game.hold(&"test")
		Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
		Game._feed_gen += 1
		Game.release(&"test")
		await _settle(tree)
		var tag := "%d×%d" % [sz.x, sz.y]
		var speakers := Game.m.alive()
		var vp := Nav.frame.get_viewport_rect().size
		var fld := Nav.bubbles.field
		if fld.size.y < 150.0:
			problems.append("%s: поле для пузырей не задано или мало (%s)" % [tag, fld])
			continue
		for k in range(14):
			var who: Villager = speakers[rng.randi_range(0, speakers.size() - 1)]
			var text: String = Phrases.fill(texts[rng.randi_range(0, texts.size() - 1)], {"who": "Тимур", "house": "Сарай", "me_f": who.female})
			Game.m.post(ChatLine.say(who, text))
			await tree.process_frame
			checks += 1
			var live := Nav.bubbles.alive()
			if live.size() > Bubbles.MAX_ON_SCREEN:
				problems.append("%s: на экране %d пузырей" % [tag, live.size()])
			var newest: Bubbles.Bubble = null
			for b: Bubbles.Bubble in live:
				if newest == null or b.order > newest.order:
					newest = b
			if newest == null or newest.who != who.name:
				problems.append("%s: свежая реплика %s не видна" % [tag, who.name])
			else:
				var head: Vector2 = Nav.village.crowd.figures[who.id].head_global()
				if absf(newest.tail_x - clampf(head.x, newest.rect.position.x + 14.0, newest.rect.end.x - 14.0)) > 1.0:
					problems.append("%s: хвостик пузыря %s не указывает на говорящего" % [tag, who.name])
				if newest.rect.end.y > head.y:
					problems.append("%s: пузырь %s ниже головы говорящего" % [tag, who.name])
			for i in range(live.size()):
				var a := live[i]
				if a.rect.position.x < -0.5 or a.rect.end.x > vp.x + 0.5:
					problems.append("%s: пузырь %s за краем экрана" % [tag, a.who])
				if a.rect.position.y < fld.position.y - 0.5 or a.rect.end.y > fld.end.y + 0.5:
					problems.append("%s: пузырь %s выходит за поле" % [tag, a.who])
				for j in range(i + 1, live.size()):
					if a.rect.grow(-1.0).intersects(live[j].rect.grow(-1.0)):
						problems.append("%s: пузыри %s и %s налезают друг на друга" % [tag, a.who, live[j].who])
		Nav.bubbles.tick(20.0)
		Nav.bubbles.tick(1.0)
		if not Nav.bubbles.bubbles.is_empty():
			problems.append("%s: пузыри не погасли за 20 секунд" % tag)
		# соседи говорят по очереди — оба пузыря должны ужиться: второй встаёт над первым
		var me: Villager = Game.m.player()
		var near: Villager = null
		var best := 9999.0
		for v2: Villager in Game.m.alive_bots():
			var d: float = Nav.village.crowd.figures[v2.id].position.distance_to(Nav.village.crowd.figures[me.id].position)
			if d < best:
				best = d
				near = v2
		Game.m.post(ChatLine.say(near, "Я с тобой."))
		Game.m.post(ChatLine.say(me, "Идём вместе."))
		await tree.process_frame
		checks += 1
		if Nav.bubbles.alive().size() != 2:
			problems.append("%s: соседи сказали по реплике, а видно пузырей: %d — пузыри не уступают место" % [tag, Nav.bubbles.alive().size()])
		Nav.bubbles.tick(20.0)
		Nav.bubbles.tick(1.0)
	Nav.frame.debug_insets = Vector4(-1, -1, -1, -1)
	print("=== пузыри реплик: %d реплик на %d типах экранов ===" % [checks, profiles.size()])
	if problems.is_empty():
		print("ИТОГ: OK — пузыри не налезают, свежая реплика видна над говорящим, всё в кадре")
		tree.quit(0)
	else:
		for pr: String in problems.slice(0, 25):
			print("  ✗ " + pr)
		print("ИТОГ: НАРУШЕНИЙ: %d" % problems.size())
		tree.quit(1)



# =============================================================
# Живое поле (Task 8): тап по жителю, глаз подозрения, значки улик, уговор.
# =============================================================
static func marks() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	Save.config = (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _settle(tree)
	var cr := Nav.village.crowd
	var day := Nav.host.current as DayScreen
	var clean := true
	for f: VillagerFigure in cr.figures.values():
		if f.eye_level != 0 or not f.badges.is_empty():
			clean = false
	ok += _expect(fails, clean, "в начале партии у кого-то уже есть глаз или значки")

	# тап по себе открывает пояснение: что значат глаз, значки улик и кольцо уговора
	var me_fig: VillagerFigure = cr.figures[0]
	# палец у ног — это шаг, пояснение не открывается и часы не стоят
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": me_fig.get_global_transform_with_canvas() * Vector2(0, -6)}, day)
	await _frames(tree, 2)
	ok += _expect(fails, day.find_children("InfoSheet", "InfoSheet", true, false).is_empty() and not Game.held(),
		"палец у ног своей фигуры открыл пояснение или остановил время")
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": me_fig.head_global() + Vector2(0, 6)}, day)
	await _frames(tree, 2)
	var legend := day.find_children("InfoSheet", "InfoSheet", true, false)
	var glyph_kinds := {}
	if not legend.is_empty():
		for g: Node in legend[0].find_children("*", "Glyph", true, false):
			glyph_kinds[(g as Glyph).kind] = true
	ok += _expect(fails, legend.size() == 1 and glyph_kinds.has("mark_eye") and glyph_kinds.has("mark_liar") and glyph_kinds.has("mark_pact") and glyph_kinds.size() >= 8,
		"тап по себе не объяснил значки (%d шторок, значков %d)" % [legend.size(), glyph_kinds.size()])
	for sh: Node in legend:
		sh.queue_free()
	Game.release(&"info")
	await _frames(tree, 2)

	# зона касания
	var small := false
	for f: VillagerFigure in cr.figures.values():
		var r := f.hit_rect_global()
		if r.size.x < 84.0 or r.size.y < 84.0:
			small = true
	ok += _expect(fails, not small, "зона касания жителя меньше 84 px (48 dp)")

	# тап по пустой земле и по себе — ничего
	var fld := Nav.bubbles.field
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": fld.position + Vector2(6, 6)}, day)
	await _frames(tree, 2)
	ok += _expect(fails, _sheet(day) == null, "тап по пустому месту открыл шторку")
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": cr.figures[0].hit_rect_global().get_center()}, day)
	await _frames(tree, 2)
	ok += _expect(fails, _sheet(day) == null, "тап по своей фигурке открыл шторку действий")
	for info: Node in day.find_children("InfoSheet", "InfoSheet", true, false):
		info.queue_free()        # тап по себе открывает пояснение значков; закрываем, чтобы часы шли
	await _frames(tree, 2)

	# тап по жителю → шторка про него → обвинить → глаз изменился, ответил
	var bots := Game.m.alive_bots()
	var target: Villager = bots[0]
	Game.director.public_susp[target.id] = 0.0   # старожил мог обелить его утром — начинаем с нуля
	Game.director.public_susp[0] = 0.0           # а если старожил назвал тебя, твоим словам не верят
	Game.marks_changed.emit()
	await _frames(tree, 1)
	var before: int = cr.figures[target.id].eye_level
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": cr.figures[target.id].hit_rect_global().get_center()}, day)
	await _frames(tree, 2)
	var sh := _sheet(day)
	var title_ok := false
	if sh != null:
		for control: Control in _controls(sh):
			if control is Label and (control as Label).text.begins_with(target.name):
				title_ok = true
	ok += _expect(fails, sh != null and title_ok, "тап по %s не открыл шторку с его именем" % target.name)
	var chat_before := Game.m.chat.size()
	if sh != null:
		sh.close(0)
	await _frames(tree, 4)
	ok += _expect(fails, cr.figures[target.id].eye_level > before,
		"обвинили %s — глаз не изменился (%d → %d)" % [_ru_case("acc", target.name), before, cr.figures[target.id].eye_level])
	var replied := false
	var reply_until := Time.get_ticks_msec() + 5000
	while not replied and Time.get_ticks_msec() < reply_until:
		for i in range(chat_before, Game.m.chat.size()):
			if Game.m.chat[i].speaker == target:
				replied = true
				break
		if not replied:
			await tree.process_frame
	ok += _expect(fails, replied, "обвинённый %s не ответил" % target.name)

	# позвать с собой — кто-нибудь согласится; кольцо уговора; ночью вместе к одной двери
	Game.director.public_susp[0] = 0.0      # старожил мог назвать тебя упырём — тогда не согласится никто
	var partner: Villager = null
	for b: Villager in bots:
		if b == target:
			continue
		Nav.handle_intent(Intent.FIELD_TAP, {"pos": cr.figures[b.id].hit_rect_global().get_center()}, day)
		await _frames(tree, 2)
		var s1 := _sheet(day)
		if s1 == null:
			continue
		s1.close(1)
		await _frames(tree, 2)
		var s2 := _sheet(day)
		if s2 == null:
			continue
		s2.close(0)
		await _frames(tree, 4)
		if Game.director.brains[b.id].pact_id == 0:
			partner = b
			break
	ok += _expect(fails, partner != null, "никто из жителей не согласился ночевать вместе")
	if partner != null:
		ok += _expect(fails, cr.figures[partner.id].pact, "над %s нет кольца уговора" % partner.name)
		Game.end_day()
		await _settle(tree)
		if Game.m.phase == Match.Phase.VOTE:
			Game.vote(-1)
			await _settle(tree)
			Game.proceed()
			await _settle(tree)
		# колокол: ты бежишь к дому из уговора, напарник бежит туда же сам
		(Nav.host.current as NightScreen).select_house(0)
		await _settle(tree)
		var nearest := func(pos: Vector2) -> int:
			var best := -1
			for k in range(cr.view.open_count):
				if best < 0 or pos.distance_to(cr.view.def.shelters[k].pos) < pos.distance_to(cr.view.def.shelters[best].pos):
					best = k
			return best
		var at_door: bool = Game.run_choices.get(partner.id, -1) == 0 and nearest.call(cr.figures[0].position) == 0 and nearest.call(cr.figures[partner.id].position) == 0
		ok += _expect(fails, at_door, "ночью вы и %s не пошли к одному дому" % partner.name)
		Game.choose_house(0)
		await _settle(tree)
		var same := false
		for seat: Match.Seat in Game.m.seats:
			var inn := seat.inside() + seat.queue
			if inn.has(Game.m.player()) and inn.has(partner):
				same = true
		ok += _expect(fails, same, "ночью %s не пришёл к той же двери, что и вы" % partner.name)
		if Game.m.phase == Match.Phase.DOOR:
			if Game.door_role() == Match.DoorRole.GUEST:
				Game.plea("beg")
				await _settle(tree)
				Game.proceed()
			else:
				var none: Array[int] = []
				Game.admit(none)
			await _settle(tree)

	# после ночи значки совпадают с отчётом
	if Game.m != null and Game.m.report != null:
		var wrong := PackedStringArray()
		for e: NightReport.Entry in Game.m.report.entries:
			var want := ""
			var who: Array[Villager] = []
			match e.kind:
				NightReport.Kind.SURVIVED_STREET:
					want = "street"
					who = [e.who]
				NightReport.Kind.LIAR:
					want = "liar"
					who = [e.who]
				NightReport.Kind.KILLED_INSIDE:
					want = "death"
					who = e.others
			for v: Villager in who:
				if v.alive and cr.figures.has(v.id) and not cr.figures[v.id].badges.has(want) and cr.figures[v.id].badges.size() < 2:
					wrong.append("%s без значка %s" % [v.name, want])
		ok += _expect(fails, wrong.is_empty(), "значки не совпали с отчётом ночи: %s" % ", ".join(wrong))

	print("=== живое поле: %d проверок ===" % (ok + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — тап по жителю, глаз подозрения, значки улик и уговор работают")
		tree.quit(0)
	else:
		for f: String in fails:
			print("  ✗ " + f)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)



# =============================================================
# Ввод (Task 9): быстрые фразы и своё поле. Клавиатура не закрывает ввод.
# =============================================================
static func input() -> void:
	var tree := Nav.get_tree()
	var problems: PackedStringArray = []
	var checks := 0
	var profiles: Array[Array] = []
	for sz: Vector2i in LAYOUT_SIZES:
		profiles.append([sz, Vector4(-1, -1, -1, -1)])
	profiles.append_array(LAYOUT_CUTOUTS)
	for prof: Array in profiles:
		var sz: Vector2i = prof[0]
		Nav.frame.debug_insets = prof[1]
		Nav.frame.debug_keyboard = -1.0
		tree.root.size = sz
		await _frames(tree, 3)
		Nav.frame.refresh()
		Nav.start_match()
		await _settle(tree)
		Game.hold(&"test")
		Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
		Game._feed_gen += 1
		Game.release(&"test")
		await _settle(tree)
		var tag := "%d×%d" % [sz.x, sz.y]
		var day := Nav.host.current as DayScreen
		var vp := Nav.frame.get_viewport_rect().size
		for child: Node in day.get_children():
			if child is TextSheet:
				(child as TextSheet).close("")
		await _frames(tree, 2)

		day._write_flow()
		await _frames(tree, 3)
		var ts := _text_sheet(day)
		checks += 1
		if ts == null:
			problems.append("%s: «Сказать…» не открыло окно" % tag)
			continue
		var chips: Array[Button] = []
		for c: Node in ts.quick_box.get_children():
			if c is Button:
				chips.append(c)
		if chips.size() < 5:
			problems.append("%s: быстрых фраз %d, ждём не меньше 5" % [tag, chips.size()])
		for b: Button in chips:
			var r := b.get_global_rect()
			var f := b.get_theme_font("font")
			var need := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			if r.size.x + 1.0 < need or r.end.x > vp.x + 1.0 or r.position.x < -1.0 or r.size.y < MIN_TOUCH - 0.5:
				problems.append("%s: быстрая фраза «%s» обрезана, мала или за краем" % [tag, b.text.left(24)])
		# фраза с домом: сказано и засчитано как объявление ночлега
		var house_text := chips[0].text if not chips.is_empty() else ""
		if not chips.is_empty():
			chips[0].pressed.emit()
			await _frames(tree, 3)
			var said := false
			for l: ChatLine in Game.m.chat:
				if l.kind == ChatLine.Kind.MINE and l.text == house_text:
					said = true
			if not said:
				problems.append("%s: быстрая фраза не попала в чат" % tag)
			if Game.m.player().announced_house != 0:
				problems.append("%s: «%s» не засчиталось как ночлег (дом %d)" % [tag, house_text, Game.m.player().announced_house])
		# клавиатура: поле и «Сказать» над ней, фразы спрятаны
		day._write_flow()
		await _frames(tree, 3)
		ts = _text_sheet(day)
		if ts != null:
			ts.field.grab_focus()
			var kb := roundf(vp.y * 0.42)
			Nav.frame.debug_keyboard = kb
			Nav.frame.refresh()
			await _frames(tree, 4)
			checks += 1
			var fr := ts.field.get_global_rect()
			var sr := ts.send_button.get_global_rect()
			if fr.end.y > vp.y - kb + 1.0 or sr.end.y > vp.y - kb + 1.0:
				problems.append("%s: клавиатура закрывает ввод (низ поля %d, кнопки %d, клавиатура с %d)" % [tag, int(fr.end.y), int(sr.end.y), int(vp.y - kb)])
			if fr.position.y < 0.0:
				problems.append("%s: поле ввода уехало за верх экрана" % tag)
			if ts.quick_box.visible:
				problems.append("%s: при открытой клавиатуре быстрые фразы не спрятались" % tag)
			ts.close("")
			Nav.frame.debug_keyboard = -1.0
			Nav.frame.refresh()
			await _frames(tree, 2)
	Nav.frame.debug_insets = Vector4(-1, -1, -1, -1)
	Nav.frame.debug_keyboard = -1.0
	print("=== ввод: %d проверок на %d типах экранов ===" % [checks, profiles.size()])
	if problems.is_empty():
		print("ИТОГ: OK — быстрые фразы работают, клавиатура не закрывает ввод")
		tree.quit(0)
	else:
		for pr: String in problems.slice(0, 25):
			print("  ✗ " + pr)
		print("ИТОГ: НАРУШЕНИЙ: %d" % problems.size())
		tree.quit(1)


static func _text_sheet(s: Node) -> TextSheet:
	for c: Node in s.get_children():
		if c is TextSheet and not c.is_queued_for_deletion():
			return c
	return null


# =============================================================
# Подсказки новичку (Task 10): три штуки, исчезают после действия, не возвращаются.
# =============================================================
static func hints() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	Save.hints_seen.clear()
	var shown: Dictionary = {}
	var vp := Nav.frame.get_viewport_rect().size

	var door_seen := false
	for attempt in range(25):
		Nav.start_match()
		await _settle(tree)
		ok += _expect(fails, Nav.host.current.hint == null, "в прологе не должно быть подсказки")
		Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
		await _settle(tree)
		await _frames(tree, 5)
		var day := Nav.host.current as DayScreen
		if not Save.hint_seen("day"):
			ok += _check_hint(day, "day", vp, fails)
			shown["day"] = true
			var bots := Game.m.alive_bots()
			Nav.handle_intent(Intent.FIELD_TAP, {"pos": Nav.village.crowd.figures[bots[0].id].hit_rect_global().get_center()}, day)
			await _frames(tree, 3)
			var sh := _sheet(day)
			if sh != null:
				sh.close(-1)
			await _frames(tree, 2)
			ok += _expect(fails, day.hint == null and Save.hint_seen("day"), "дневная подсказка не исчезла после тапа по жителю")
		else:
			ok += _expect(fails, day.hint == null, "дневная подсказка вернулась после того, как её выполнили")
		Game.end_day()
		await _settle(tree)
		if Game.m.phase == Match.Phase.VOTE:
			Game.vote(-1)
			await _settle(tree)
			Game.proceed()
			await _settle(tree)
		await _frames(tree, 5)
		var night := Nav.host.current as NightScreen
		if night != null and Game.m.player().alive:
			if not Save.hint_seen("night"):
				ok += _check_hint(night, "night", vp, fails)
				shown["night"] = true
				Nav.handle_intent(Intent.CHOOSE_HOUSE, {"house": 0}, night)
				await _settle(tree)
				ok += _expect(fails, Save.hint_seen("night"), "ночная подсказка не засчиталась после выбора дома")
			else:
				ok += _expect(fails, night.hint == null, "ночная подсказка вернулась")
				Nav.handle_intent(Intent.CHOOSE_HOUSE, {"house": 0}, night)
				await _settle(tree)
		await _frames(tree, 5)
		if Game.m != null and Game.m.phase == Match.Phase.DOOR and Nav.host.current is DoorScreen:
			var ds := Nav.host.current as DoorScreen
			if not Save.hint_seen("door"):
				ok += _check_hint(ds, "door", vp, fails)
				shown["door"] = true
				if ds.role == Match.DoorRole.GUEST:
					Nav.handle_intent(Intent.PLEA, {"plea": "beg"}, ds)
				else:
					var none: Array[int] = []
					Nav.handle_intent(Intent.ADMIT, {"ids": none}, ds)
				await _frames(tree, 3)
				ok += _expect(fails, Save.hint_seen("door"), "подсказка у двери не засчиталась после решения")
				door_seen = true
		if shown.size() == 3:
			break
	ok += _expect(fails, door_seen and shown.size() == 3, "показано подсказок: %s — ждём день, ночь и дверь" % ", ".join(PackedStringArray(shown.keys())))

	# перезапуск: увиденные подсказки не возвращаются
	Save.flush()
	Save.load_all()
	ok += _expect(fails, Save.hint_seen("day") and Save.hint_seen("night") and Save.hint_seen("door"),
		"после перезапуска подсказки забылись")
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	await _frames(tree, 5)
	ok += _expect(fails, Nav.host.current.hint == null, "подсказка вернулась в новой партии")

	# сброс через настройки
	Nav.show_settings()
	await _settle(tree)
	var st := Nav.host.current as SettingsScreen
	Nav.handle_intent(Intent.BACK, {"cfg": st.cfg, "haptics": st.haptics, "reset_hints": true}, st)
	await _settle(tree)
	ok += _expect(fails, not Save.hint_seen("day") and not Save.hint_seen("night") and not Save.hint_seen("door"),
		"кнопка «Показать подсказки заново» не сбросила подсказки")

	print("=== подсказки: %d проверок ===" % (ok + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — три подсказки, исчезают после действия и не возвращаются")
		tree.quit(0)
	else:
		for f: String in fails:
			print("  ✗ " + f)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)


static func _check_hint(s: Screen, id: String, vp: Vector2, fails: PackedStringArray) -> int:
	var n := 0
	n += _expect(fails, s.hint != null and is_instance_valid(s.hint), "подсказка «%s» не показалась" % id)
	if s.hint == null:
		return n
	var r := s.hint.card_rect_global()
	n += _expect(fails, r.position.x >= -1.0 and r.end.x <= vp.x + 1.0 and r.position.y >= -1.0 and r.end.y <= vp.y + 1.0,
		"подсказка «%s» за краем экрана: %s" % [id, r])
	n += _expect(fails, not s.hint.text.is_empty() and r.size.y > 30.0, "подсказка «%s» пустая" % id)
	n += _expect(fails, r.size.y < vp.y * 0.4, "подсказка «%s» высотой %d px — больше 40%% экрана" % [id, int(r.size.y)])
	var lr := s.hint.text_rect_global()
	n += _expect(fails, r.grow(1.0).encloses(lr), "текст подсказки «%s» вылезает из карточки (текст %s, карточка %s)" % [id, lr, r])
	var blocks := false
	for c: Control in _controls(s.hint) + ([s.hint] as Array[Control]):
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocks = true
	n += _expect(fails, not blocks, "подсказка «%s» перехватывает касания" % id)
	return n



# =============================================================
# Сложность, метка «Вы», предложение после партии (Task 11–13).
# =============================================================
static func difficulty() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	var keep_games: int = Save.stats["games"]

	# 1. Первый запуск — лёгкая
	var cf_path := ProjectSettings.globalize_path(Save.SETTINGS_PATH)
	var backup := FileAccess.get_file_as_string(Save.SETTINGS_PATH) if FileAccess.file_exists(Save.SETTINGS_PATH) else ""
	if FileAccess.file_exists(Save.SETTINGS_PATH):
		DirAccess.remove_absolute(cf_path)
	Save.load_all()
	ok += _expect(fails, not Save.howto_seen, "при первом запуске «Как играть» уже отмечено просмотренным")
	Save.howto_seen = true      # этот тест про сложность; показ «Как играть» проверяет --howto
	ok += _expect(fails, Save.difficulty == "easy" and Save.config.players == 5 and Save.config.player_always_human,
		"первый запуск не на лёгкой: %s, %d жителей" % [Save.difficulty, Save.config.players])

	# 2. Меню: ступени, подсветка, строка о партии
	Nav.show_menu()
	await _settle(tree)
	var menu := Nav.host.current as MenuScreen
	var play := _find_button(menu, "Играть")
	var normal_b := _find_button(menu, "Обычная")
	ok += _expect(fails, play != null and normal_b != null, "в меню нет «Играть» или выбора сложности")
	ok += _expect(fails, (_find_button(menu, "Лёгкая") as Button).theme_type_variation == &"RowOn", "в меню не подсвечена текущая ступень")
	if normal_b != null:
		normal_b.pressed.emit()
		await _frames(tree, 2)
		ok += _expect(fails, Save.difficulty == "normal" and Save.config.players == 7, "«Обычная» не включилась")
		ok += _expect(fails, normal_b.theme_type_variation == &"RowOn" and menu._diff_note.text.contains("7 жителей"),
			"подсветка или строка о партии не обновились: «%s»" % menu._diff_note.text)
	if play != null:
		play.pressed.emit()
		await _settle(tree)
		ok += _expect(fails, Game.m != null and Game.m.villagers.size() == 7, "«Играть» начало не ту партию")

	# 3. На лёгкой вы всегда человек
	Save.set_difficulty("easy")
	var upyr_times := 0
	for g in range(40):
		Game.start(Save.config)
		if Game.m.player().is_upyr:
			upyr_times += 1
	ok += _expect(fails, upyr_times == 0, "на лёгкой игрок оказался упырём %d раз из 40" % upyr_times)

	# 4. Предложения после партии
	ok += await _offer_case(tree, "normal", false, 0, "easy", fails)
	ok += await _offer_case(tree, "easy", false, 0, "", fails)
	ok += await _offer_case(tree, "easy", true, 1, "normal", fails)
	ok += await _offer_case(tree, "easy", true, 0, "", fails)
	ok += await _offer_case(tree, "hard", true, 1, "", fails)
	Save.set_settings(Difficulty.preset("normal"), Save.haptics)
	ok += await _offer_case(tree, "custom", false, 0, "", fails)

	# принять предложение — новая партия уже на другой ступени
	Save.set_difficulty("normal")
	Save.win_streak = 0
	await _finish_match(tree, false)
	var end := Nav.host.current as EndScreen
	var easier := _find_button(end, "Сделать легче") if end != null else null
	ok += _expect(fails, easier != null, "на итоге нет кнопки «Сделать легче»")
	if easier != null:
		easier.pressed.emit()
		await _settle(tree)
		ok += _expect(fails, Save.difficulty == "easy" and Game.m != null and Game.m.villagers.size() == 5,
			"«Сделать легче» не перевело на лёгкую")

	# 5. Настройки: ступень, затем ползунок — своя
	Save.set_difficulty("normal")
	Nav.show_settings()
	await _settle(tree)
	var st := Nav.host.current as SettingsScreen
	var hard_b := _find_button(st, "Сложная")
	if hard_b != null:
		hard_b.pressed.emit()
		await _frames(tree, 2)
	ok += _expect(fails, st.difficulty == "hard" and st.cfg.players == 10, "в настройках «Сложная» не выбралась")
	var slider: HSlider = null
	for c: Control in _controls(st):
		if c is HSlider and not c.name.begins_with("Volume_"):      # ползунок баланса, а не громкости
			slider = c
			break
	if slider != null:
		slider.value = slider.value - 1.0
		await _frames(tree, 1)
	ok += _expect(fails, st.difficulty == "custom", "после ползунка сложность не стала «Своей»")
	root_back(tree)
	await _settle(tree)
	ok += _expect(fails, Save.difficulty == "custom", "«Своя» сложность не сохранилась при выходе из настроек")
	Save.flush()
	Save.load_all()
	ok += _expect(fails, Save.difficulty == "custom", "после перезапуска сложность забылась")

	# 6. Метка «Вы»
	Save.set_difficulty("easy")
	Save.stats["games"] = 0
	Nav.start_match()
	await _settle(tree)
	var me: VillagerFigure = Nav.village.crowd.figures[0]
	var vp := Nav.frame.get_viewport_rect().size
	ok += _expect(fails, me.highlight, "в прологе нет метки «Вы»")
	var mr := me.marker_rect_global()
	ok += _expect(fails, mr.position.x >= 0.0 and mr.end.x <= vp.x and mr.position.y >= 0.0 and mr.end.y <= Nav.scrim.top,
		"метка «Вы» за краем поля: %s" % mr)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	ok += _expect(fails, me.highlight, "в первой партии днём нет метки «Вы»")
	Save.stats["games"] = 5
	Nav.start_match()
	await _settle(tree)
	me = Nav.village.crowd.figures[0]
	ok += _expect(fails, me.highlight, "в прологе опытного игрока нет напоминания «Вы»")
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	ok += _expect(fails, not me.highlight, "у опытного игрока метка «Вы» не прячется днём")
	Save.stats["games"] = keep_games

	# 7. Ступени идут от лёгкой к сложной
	var rates := {}
	for d: String in Difficulty.LADDER:
		rates[d] = balance(Difficulty.preset(d), 800).people_win
	print("доля побед людей: лёгкая %.1f%%, обычная %.1f%%, сложная %.1f%%" % [100.0 * rates["easy"], 100.0 * rates["normal"], 100.0 * rates["hard"]])
	ok += _expect(fails, rates["easy"] > rates["normal"] + 0.15 and rates["normal"] > rates["hard"] + 0.02 and rates["hard"] > 0.3,
		"ступени не идут от лёгкой к сложной")

	if backup != "":
		var f := FileAccess.open(Save.SETTINGS_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
		Save.load_all()

	print("=== сложность и метка «Вы»: %d проверок ===" % (ok + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — лёгкий старт, выбор сложности, предложение после партии и метка «Вы» работают")
		tree.quit(0)
	else:
		for f2: String in fails:
			print("  ✗ " + f2)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)


static func root_back(tree: SceneTree) -> void:
	tree.root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)


static func _find_button(root: Node, text_start: String) -> Button:
	if root == null:
		return null
	for c: Control in _controls(root):
		if c is Button and (c as Button).text.begins_with(text_start) and c.is_visible_in_tree():
			return c
	return null


## Довести партию до итога с нужным исходом для игрока.
static func _finish_match(tree: SceneTree, player_wins: bool) -> void:
	Nav.start_match()
	await _settle(tree)
	var human := not Game.m.player().is_upyr
	Game.m.winner = Match.Team.PEOPLE if (player_wins == human) else Match.Team.UPYRI
	Game.m.phase = Match.Phase.MORNING
	Game.m.end_morning()
	await _settle(tree)


static func _offer_case(tree: SceneTree, diff: String, win: bool, streak_before: int, want: String, fails: PackedStringArray) -> int:
	if diff != "custom":
		Save.set_difficulty(diff)
	Save.win_streak = streak_before
	await _finish_match(tree, win)
	var end := Nav.host.current as EndScreen
	var got := end.offer if end != null else "?"
	var has_card := end != null and (_find_button(end, "Сделать легче") != null or _find_button(end, "Попробовать сложнее") != null)
	var good := got == want and has_card == (want != "")
	return _expect(fails, good, "%s, %s (серия до этого %d): предложено «%s», ждали «%s»" % [
		Difficulty.NAMES[diff], "победа" if win else "поражение", streak_before, got, want])



# =============================================================
# «Как играть» (Task 15): один раз перед первой партией, повтор из меню.
# =============================================================
static func howto() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	Save.howto_seen = false
	# совсем новый игрок с «Играть» попадает в первую главу кампании (--recap); здесь — тот, кто уже играл
	Save.stats["games"] = maxi(1, int(Save.stats["games"]))

	Nav.show_menu()
	await _settle(tree)
	_find_button(Nav.host.current, "Играть").pressed.emit()
	await _settle(tree)
	var h := Nav.host.current as HowToScreen
	ok += _expect(fails, h != null and h.then_play, "первое «Играть» не открыло «Как играть»")
	if h != null:
		var host_h := Nav.host.size.y
		for pg in range(HowToScreen.PAGES.size()):
			var ar := h.art.get_global_rect()
			ok += _expect(fails, h.page == pg and ar.size.y >= host_h * 0.3, "карточка %d: картинка %d px — меньше 30%% экрана" % [pg + 1, int(ar.size.y)])
			var inside := true
			for f: VillagerFigure in h.art.figures:
				if not ar.grow(2.0).encloses(f.body_rect_global()):
					inside = false
			ok += _expect(fails, inside and not h.art.figures.is_empty(), "карточка %d: фигурки вне картинки или их нет" % (pg + 1))
			var last := pg == HowToScreen.PAGES.size() - 1
			var btn := _find_button(h, "Играть" if last else "Дальше")
			ok += _expect(fails, btn != null, "карточка %d: нет кнопки «%s»" % [pg + 1, "Играть" if last else "Дальше"])
			if btn != null:
				btn.pressed.emit()
				await _settle(tree)
		ok += _expect(fails, Nav.host.current is PrologueScreen and Save.howto_seen, "после «Как играть» не началась партия")

	Nav.show_menu()
	await _settle(tree)
	_find_button(Nav.host.current, "Играть").pressed.emit()
	await _settle(tree)
	ok += _expect(fails, Nav.host.current is PrologueScreen, "второе «Играть» снова показало «Как играть»")

	Nav.show_menu()
	await _settle(tree)
	_find_button(Nav.host.current, "Как играть").pressed.emit()
	await _settle(tree)
	h = Nav.host.current as HowToScreen
	ok += _expect(fails, h != null and not h.then_play, "кнопка «Как играть» в меню не открыла карточки")
	if h != null:
		h.next_page()
		await _settle(tree)
		h.next_page()
		await _settle(tree)
		var done := _find_button(Nav.host.current, "Понятно")
		ok += _expect(fails, done != null, "из меню на последней карточке нет «Понятно»")
		if done != null:
			done.pressed.emit()
			await _settle(tree)
		ok += _expect(fails, Nav.host.current is MenuScreen, "«Понятно» не вернуло в меню")

	Save.howto_seen = false
	_find_button(Nav.host.current, "Играть").pressed.emit()
	await _settle(tree)
	var skip := _find_button(Nav.host.current, "Пропустить")
	ok += _expect(fails, skip != null, "нет «Пропустить»")
	if skip != null:
		skip.pressed.emit()
		await _settle(tree)
	ok += _expect(fails, Nav.host.current is PrologueScreen and Save.howto_seen, "«Пропустить» не начало партию")

	Nav.show_howto(false)
	await _settle(tree)
	root_back(tree)
	await _settle(tree)
	ok += _expect(fails, Nav.host.current is MenuScreen, "«Назад» в «Как играть» не вернуло в меню")

	Save.flush()
	Save.load_all()
	ok += _expect(fails, Save.howto_seen, "после перезапуска «Как играть» забылось")

	print("=== «Как играть»: %d проверок ===" % (ok + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — показывается один раз перед первой партией и открывается из меню")
		tree.quit(0)
	else:
		for f2: String in fails:
			print("  ✗ " + f2)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)



# =============================================================
# Ночь на картинке (Task 16–17): сумерки, выбор дома тапом, кто куда идёт.
# =============================================================
static func night() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	Save.set_difficulty("easy")
	var v := Nav.village

	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	ok += _expect(fails, v.eyes.visible_pairs() == 0, "днём в темноте видны глаза")

	# Воспроизводим сбой CI: вопрос уже открыт, когда экран дня сменяется ночью.
	Game._feed_gen += 1
	var day_screen := Nav.host.current as DayScreen
	var question := ChatLine.say(Game.m.villagers[1], SocialContent.question("alibi", Game.m.player().name, Game.m.rng))
	question.asks_player = true
	question.question_kind = "alibi"
	if _text_sheet(day_screen) == null:
		day_screen._question_prompt_open = false
		day_screen.append_line(question)
	await _frames(tree, 3)
	ok += _expect(fails, _text_sheet(day_screen) != null and Game.held_by(&"dialog"), "вопрос перед ночью не открылся или не остановил время")

	# сумерки в живом темпе
	Juice.instant = false
	var d0 := v.draws
	var u0 := v.draw_usec_total
	Game.end_day()
	if Game.m.phase == Match.Phase.VOTE:
		Game.vote(-1)
		Game.proceed()
	var total := v.lights_total()
	var mid_lit := -1
	var t := 0.0
	while t < 2.6:
		await tree.process_frame
		t += tree.root.get_process_delta_time() if tree.root.get_process_delta_time() > 0.0 else 0.016
		if mid_lit < 0 and v.night > 0.5 and v.night < 0.8:
			mid_lit = v.lit_count()
	var redraws := v.draws - d0
	var avg_us := float(v.draw_usec_total - u0) / maxf(1.0, float(redraws))
	var eyes_max := 0
	for k in range(30):
		await tree.process_frame
		eyes_max = maxi(eyes_max, v.eyes.visible_pairs())
	Juice.instant = true
	ok += _expect(fails, not Game.held_by(&"dialog"), "после удаления дневного вопроса осталась пауза dialog")
	print("сумерки: перерисовок %d, в среднем %.1f мс на перерисовку, окон к середине %d из %d, глаз %d пар" % [redraws, avg_us / 1000.0, mid_lit, total, eyes_max])
	ok += _expect(fails, Nav.host.current is NightScreen and v.night > 0.99, "ночь не наступила полностью (%.2f)" % v.night)
	ok += _expect(fails, mid_lit >= 1 and mid_lit < total, "окна загорелись не по одному: к середине %d из %d" % [mid_lit, total])
	ok += _expect(fails, v.lit_count() == total, "к концу сумерек горят не все окна: %d из %d" % [v.lit_count(), total])
	ok += _expect(fails, eyes_max >= 4, "ночью в темноте не видно глаз (%d пар)" % eyes_max)
	ok += _expect(fails, redraws <= 70, "сумерки перерисовали посёлок %d раз — кадры будут проседать" % redraws)
	ok += _expect(fails, avg_us < 8000.0, "одна перерисовка посёлка %.1f мс — слишком долго" % (avg_us / 1000.0))

	# колокол: бег начался, отсчёт идёт, кнопки «Идти» нет
	var ns := Nav.host.current as NightScreen
	Game.hold(&"test")          # время бега стоит, пока проверяем выбор дома
	await _settle(tree)
	ok += _expect(fails, Game.run_on and Game.run_house == -1 and _find_button(ns, "Идти") == null, "колокол не начал бег или осталась кнопка «Идти»")
	ok += _expect(fails, Game.clock.running() and Game.clock.time_left() <= float(Game.m.config.run_seconds), "у колокола нет обратного отсчёта")

	# тап по дому
	var hr := v.house_hit_rect_global(0)
	ok += _expect(fails, hr.size.x >= 84.0 and hr.size.y >= 84.0, "зона касания дома меньше 84 px")
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": hr.get_center()}, ns)
	await _settle(tree)
	var me: VillagerFigure = v.crowd.figures[0]
	ok += _expect(fails, ns.picked == 0 and v.selected_house == 0 and Game.run_house == 0,
		"тап по дому не выбрал его (выбран %d, на поле %d, бег %d)" % [ns.picked, v.selected_house, Game.run_house])
	# стоишь в очереди у выбранного дома: к нему ближе, чем к любому другому открытому
	var near_house := func(h: int) -> bool:
		for k in range(v.open_count):
			if k != h and me.position.distance_to(v.def.shelters[k].pos) <= me.position.distance_to(v.def.shelters[h].pos):
				return false
		return true
	ok += _expect(fails, near_house.call(0), "твоя фигурка не побежала к выбранному дому")
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.house_hit_rect_global(1).get_center()}, ns)
	await _settle(tree)
	ok += _expect(fails, ns.picked == 1 and v.selected_house == 1 and Game.run_house == 1 and near_house.call(1),
		"выбор не перешёл на второй дом (выбран %d, на поле %d, бег %d, до двери %d)" % [ns.picked, v.selected_house, Game.run_house, int(me.position.distance_to(v.def.shelters[1].pos))])
	if v.open_count < v.def.shelters.size():
		var bh: HouseDef = v.def.shelters[v.open_count]
		Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.to_global(bh.pos - Vector2(0, bh.size.y * 0.5))}, ns)
		await _settle(tree)
		ok += _expect(fails, ns.picked == 1, "тап по заколоченному дому сменил выбор")
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": Nav.host.global_position + ns.field_rect_local().position + Vector2(10, 10)}, ns)
	await _settle(tree)
	ok += _expect(fails, ns.picked == 1, "тап по небу сменил выбор")

	# кто куда идёт — на табличках
	ok += _expect(fails, v.show_going and v.house_going == ns.going_counts(), "числа на табличках не совпадают с тем, кто куда собирался")

	# отпустили время: все добегают, ночь начинается раньше конца звона
	Game.release(&"test")
	var ran := 0.0
	while Game.m.phase == Match.Phase.NIGHT and ran < float(Game.m.config.run_seconds) + 2.0:
		await tree.process_frame
		ran += maxf(tree.root.get_process_delta_time(), 0.001)
	ok += _expect(fails, Game.m.phase != Match.Phase.NIGHT and Game.m.player().night_house == 1, "бег не привёл во второй дом (дом %d, фаза %s, бег %.2f, осталось %.2f, паузы %s)" % [Game.m.player().night_house, Match.Phase.keys()[Game.m.phase], Game.run_t, Game.clock.time_left(), str(Game.clock._holds)])
	ok += _expect(fails, Game.run_t < float(Game.m.config.run_seconds) - 0.5, "все добежали, а ночь ждала конца звона (%.1f с)" % Game.run_t)
	await _settle(tree)
	ok += _expect(fails, not v.show_going and v.selected_house == -1, "после ночи на поле осталась рамка или числа")

	print("=== ночь на картинке: %d проверок ===" % (ok + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — сумерки по шагам, колокол и бег до дома тапом, кто куда идёт видно на поле")
		tree.quit(0)
	else:
		for f2: String in fails:
			print("  ✗ " + f2)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)



# =============================================================
# Звук (Task 21): все звуки на месте, у каждого события свой звук, громкость
# каналов работает и сохраняется, свёрнутая игра молчит.
# =============================================================
static func sound() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	Save.set_difficulty("easy")

	# 1. Файлы, каналы, циклы
	var missing := PackedStringArray()
	for k: StringName in Sfx.SOUNDS.keys() + Sfx.LOOPS.keys():
		if not Sfx.has_sound(k):
			missing.append(String(k))
	ok += _expect(fails, missing.is_empty(), "не загрузились звуки: %s" % ", ".join(missing))
	var not_loop := PackedStringArray()
	for k: StringName in Sfx.LOOPS.keys():
		var st := Sfx._streams.get(k) as AudioStreamOggVorbis
		if st == null or not st.loop:
			not_loop.append(String(k))
	ok += _expect(fails, not_loop.is_empty(), "не зациклены: %s" % ", ".join(not_loop))
	for b: StringName in Sfx.BUSES:
		ok += _expect(fails, AudioServer.get_bus_index(b) >= 0, "нет канала громкости %s" % b)
	var total := 0
	for path: String in Sfx.SOUNDS.values() + Sfx.LOOPS.values():
		var f := FileAccess.open(path.replace(".ogg", ".ogg"), FileAccess.READ)
		if f == null:
			# в экспортированной сборке исходник лежит внутри .import — размер берём из него
			continue
		total += f.get_length()
	# с v0.24.0 часть звуков — записи, а не формулы; запас под музыку меню и ночи
	ok += _expect(fails, total < 3 * 1024 * 1024, "звуки весят %d КБ — больше 3 МБ" % (total / 1024))

	# 2. Громкость: ползунок → канал → файл настроек
	Save.set_volume(&"Music", 0.5)
	ok += _expect(fails, absf(Sfx.volume(&"Music") - 0.5) < 0.02, "громкость музыки не дошла до канала (%.2f)" % Sfx.volume(&"Music"))
	Save.set_volume(&"Ambience", 0.0)
	ok += _expect(fails, Sfx.is_bus_muted(&"Ambience"), "громкость 0 не заглушила канал атмосферы")
	Save.load_all()
	ok += _expect(fails, absf(float(Save.volumes[&"Music"]) - 0.5) < 0.01 and float(Save.volumes[&"Ambience"]) == 0.0,
		"громкость не сохранилась после перезапуска")
	ok += _expect(fails, Sfx.is_bus_muted(&"Ambience") and not Sfx.is_bus_muted(&"Music"), "после перезапуска каналы выставлены не так")
	Save.set_volume(&"Ambience", 0.8)
	Save.set_volume(&"Music", 0.7)

	# 3. Свернули — тишина, вернулись — звук, заглушённый канал так и остаётся заглушённым
	Save.set_volume(&"Sfx", 0.0)
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _frames(tree, 2)
	var all_muted := true
	for b: StringName in Sfx.BUSES:
		all_muted = all_muted and Sfx.is_bus_muted(b)
	ok += _expect(fails, all_muted, "свёрнутая игра не замолчала")
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _frames(tree, 2)
	ok += _expect(fails, not Sfx.is_bus_muted(&"Music") and not Sfx.is_bus_muted(&"Ambience") and Sfx.is_bus_muted(&"Sfx"),
		"после возврата каналы не вернулись к своей громкости")
	Save.set_volume(&"Sfx", 0.9)

	# 4. Меню и кнопки
	Nav.show_menu()
	await _settle(tree)
	ok += _expect(fails, Sfx.music_name == &"menu" and Sfx.ambience_name == &"", "в меню не музыка меню (%s / %s)" % [Sfx.music_name, Sfx.ambience_name])
	Sfx.played.clear()
	_find_button(Nav.host.current, "Обычная").pressed.emit()
	await _frames(tree, 2)
	ok += _expect(fails, Sfx.played.has(&"tap"), "кнопка нажалась без щелчка")
	Save.set_difficulty("easy")

	# 5. Партия: у каждой фазы свой звук
	var door_done := false
	for attempt in range(25):
		Sfx.played.clear()
		Nav.start_match()
		await _settle(tree)
		await _frames(tree, 4)
		if attempt == 0:
			ok += _expect(fails, Sfx.played.has(&"reveal") and Sfx.ambience_name == &"amb_dusk", "пролог без звука раскрытия роли")
		Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
		await _settle(tree)
		if attempt == 0:
			ok += _expect(fails, Sfx.ambience_name == &"amb_day" and Sfx.music_name == &"day", "днём не дневной фон и музыка (%s / %s)" % [Sfx.ambience_name, Sfx.music_name])
			Sfx.played.clear()
			Game.say("Проверка голоса.")
			await _frames(tree, 30)
			ok += _expect(fails, Sfx.played.has(&"blip"), "реплика прозвучала без голоса")
		Game.end_day()
		await _settle(tree)
		if Game.m.phase == Match.Phase.VOTE:
			Game.vote(-1)
			await _settle(tree)
			Game.proceed()
			await _settle(tree)
		if attempt == 0:
			ok += _expect(fails, Sfx.played.has(&"bell") and Sfx.ambience_name == &"amb_night" and Sfx.music_name == &"night",
				"ночь без колокола, ночного фона или музыки (%s / %s)" % [Sfx.ambience_name, Sfx.music_name])
		if not Game.m.player().alive:
			continue
		Sfx.played.clear()
		Game.choose_house(0)
		await _settle(tree)
		if Game.m.phase != Match.Phase.DOOR:
			continue
		ok += _expect(fails, Sfx.heart_on, "у двери не бьётся сердце")
		if Game.door_role() == Match.DoorRole.GUEST:
			Nav.handle_intent(Intent.PLEA, {"plea": "beg"}, Nav.host.current)
			await _frames(tree, 6)
			ok += _expect(fails, Sfx.played.has(&"knock"), "гость стучит без звука")
			await tree.create_timer(0.1).timeout
			Game.proceed()
		elif Game.door_role() == Match.DoorRole.HOST:
			# хозяин решает через экран двери — так же, как игрок пальцем
			var ids: Array[int] = []
			var ds := Nav.host.current as DoorScreen
			if ds != null and not ds.seat.queue.is_empty():
				ids.append(ds.seat.queue[0].id)
			ds._finish_host(ids)
			await _frames(tree, 4)
			ok += _expect(fails, Sfx.played.has(&"door_open" if not ids.is_empty() else &"door_shut"), "решение у двери без звука двери")
		else:
			# один у двери: решать некому, звука двери нет — просто идём дальше
			var none: Array[int] = []
			Nav.handle_intent(Intent.ADMIT, {"ids": none}, Nav.host.current)
			await _frames(tree, 2)
			continue
		await _settle(tree)
		ok += _expect(fails, not Sfx.heart_on or Game.m.phase == Match.Phase.DOOR, "сердце не утихло после двери")
		door_done = true
		break
	ok += _expect(fails, door_done, "за 25 партий не дошли до двери")

	# 6. Итог партии: победа или поражение звучат
	Sfx.played.clear()
	await _finish_match(tree, true)
	ok += _expect(fails, Sfx.played.has(&"win"), "победа без звука победы")
	Sfx.played.clear()
	await _finish_match(tree, false)
	ok += _expect(fails, Sfx.played.has(&"lose"), "поражение без звука поражения")

	# 6б. Звуки страха (57): все на месте, резкий удар не чаще раза за ночь и не в первую ночь
	var dread_missing := PackedStringArray()
	for k: StringName in Dread.SOUNDS:
		if not Sfx.SOUNDS.has(k) or not Sfx.has_sound(k):
			dread_missing.append(String(k))
	ok += _expect(fails, dread_missing.is_empty() and Dread.SOUNDS.size() >= 10, "нет звуков страха: %s" % ", ".join(dread_missing))
	Dread.reset()
	Sfx.played.clear()
	var first_night := Dread.scare(1)
	var a1 := Dread.scare(2)
	var a2 := Dread.scare(2)
	var a3 := Dread.scare(3)
	ok += _expect(fails, not first_night and a1 and not a2 and a3 and Dread.scares == 2 and Sfx.played.count(&"scare") == 2,
		"резкий удар звучит чаще раза за ночь или в первую ночь")
	var kinds_ok := true
	for kind: NightReport.Kind in [NightReport.Kind.KILLED_STREET, NightReport.Kind.KILLED_INSIDE, NightReport.Kind.KILLED_CREATURE,
			NightReport.Kind.KILLED_MIMIC, NightReport.Kind.KILLED_ALONE]:
		kinds_ok = kinds_ok and Dread.SOUNDS.has(Dread.death_sound(kind))
	ok += _expect(fails, kinds_ok and Dread.death_sound(NightReport.Kind.KILLED_INSIDE) != Dread.death_sound(NightReport.Kind.KILLED_STREET),
		"утром смерть звучит одинаково, как бы ни погиб человек")
	# один в доме: шаги по крыше и скрип половиц
	Nav.start_match()
	await _settle(tree)
	var gm := Game.m
	gm.phase = Match.Phase.DOOR
	var lone := Match.Seat.new()
	lone.host = gm.player()
	lone.house = 0
	var ds_alone := DoorScreen.new()
	ds_alone.role = Match.DoorRole.ALONE
	ds_alone.seat = lone
	Sfx.played.clear()
	Nav.show(ds_alone)
	await _frames(tree, 12)
	ok += _expect(fails, Sfx.played.has(&"roof_steps") and Sfx.played.has(&"creak"), "один в доме: не слышно шагов по крыше и скрипа (%s)" % [Sfx.played])
	Nav.show_menu()
	await _settle(tree)

	# 7. Настройки: три ползунка
	Nav.show_settings()
	await _settle(tree)
	var sliders := 0
	for c: Control in _controls(Nav.host.current):
		if c is HSlider and c.name.begins_with("Volume_"):
			sliders += 1
			if c.name == "Volume_Music":
				(c as HSlider).value = 0.3
	ok += _expect(fails, sliders == 3, "в настройках ползунков громкости %d из 3" % sliders)
	ok += _expect(fails, absf(float(Save.volumes[&"Music"]) - 0.3) < 0.01, "ползунок музыки не меняет громкость")
	Save.set_volume(&"Music", 0.7)

	print("=== звук: %d проверок ===" % (ok + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — все звуки на месте, каждое событие звучит, громкость и сворачивание работают")
		tree.quit(0)
	else:
		for f2: String in fails:
			print("  ✗ " + f2)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)



# =============================================================
# Живой день (Task 23–24): камера ближе и идёт за игроком, ходьба тапом,
# дела по посёлку, запасы, пустая работа и клевета, фонари ночью.
# =============================================================
## Сколько порций у сегодняшних дел — столько запасов можно набрать за день.
static func _portions(m: Match) -> int:
	var n := 0
	for j: JobDef in m.jobs:
		if j.kind != JobDef.Kind.BOX:
			n += j.portions
	return n


static func village() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	Save.set_difficulty("normal")
	var v := Nav.village
	var vp := Nav.frame.get_viewport_rect().size

	Nav.start_match()
	await _settle(tree)
	var scale_wide := v.scale.x
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _settle(tree)
	var day := Nav.host.current as DayScreen
	var scale_day := v.scale.x
	var m := Game.m
	var cr := v.crowd
	var me: VillagerFigure = cr.figures[0]

	# 1. Камера: днём ближе, игрок в кадре
	ok += _expect(fails, v.scale.x > scale_wide * 1.2, "днём камера не приблизилась (%.2f против %.2f)" % [v.scale.x, scale_wide])
	ok += _expect(fails, v.follow == me, "камера не следит за игроком")
	# 2. Запасы и значки дел
	ok += _expect(fails, m.supply_total == _portions(m) and m.supply_total >= 8, "запасов на день %d — ждём сумму порций дел" % m.supply_total)
	ok += _expect(fails, day.supplies != null and day.supplies.text() == "Запасы 0 из %d" % m.supply_total, "капсула запасов не показана или врёт")
	ok += _expect(fails, v.jobs_layer.visible and m.jobs.size() >= 5, "значков дел нет на поле")
	var small := false
	for ji in range(m.jobs.size()):
		var r := v.jobs_layer.icon_rect_global(ji)
		if r.size.x < 84.0 or r.size.y < 84.0:
			small = true
	ok += _expect(fails, not small, "значок дела меньше 84 px (48 dp)")

	# 3. Ходьба тапом и камера за игроком
	var target_g := v.to_global(Vector2(150, 420))
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": target_g}, day)
	await _frames(tree, 4)
	ok += _expect(fails, me.position.distance_to(cr.walk_clamp(Vector2(150, 420))) < 2.0, "тап по земле не увёл игрока (%s)" % me.position)
	var mx := me.get_global_transform_with_canvas().origin.x
	var left_edge := v.to_global(Vector2(0, 0)).x
	var at_left := absf(v.cam_x - v._clamp_cam(-9999.0, v.scale.x)) < 0.5
	ok += _expect(fails, (mx > vp.x * 0.25 and mx < vp.x * 0.75) or at_left, "камера не пошла за игроком (игрок на x=%d)" % int(mx))
	ok += _expect(fails, left_edge <= 20.0 * v.scale.x + 1.0, "камера ушла за левый край посёлка")
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.to_global(Vector2(900, 380))}, day)
	await _frames(tree, 4)
	ok += _expect(fails, me.position.x <= VillageView.SAFE_X.y + 0.5, "игрок ушёл за край посёлка (x=%d)" % int(me.position.x))
	ok += _expect(fails, v.to_global(Vector2(VillageView.LOGICAL.x, 0)).x >= vp.x - 20.0 * v.scale.x - 1.0, "камера ушла за правый край посёлка")

	# 4. Дело игрока: дошёл, поработал, запасы выросли
	var ji := m.job_index(&"water")
	var left0 := m.job_left[ji]
	Sfx.played.clear()
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.jobs_layer.icon_rect_global(ji).get_center()}, day)
	await _frames(tree, 3)
	ok += _expect(fails, Game.player_job == ji and me.working, "тап по делу не поставил игрока работать")
	ok += _expect(fails, me.position.distance_to(m.jobs[ji].pos) < 60.0, "игрок работает не у дела")
	var t_start := Game.day_t
	var guard := 0.0
	while Game.player_job >= 0 and guard < 10.0:
		await tree.create_timer(0.1).timeout
		guard += 0.1
	var waited := Game.day_t - t_start
	await _frames(tree, 2)
	ok += _expect(fails, m.supply_done == 1 and m.job_left[ji] == left0 - 1, "дело не засчиталось (запасы %d, осталось %d)" % [m.supply_done, m.job_left[ji]])
	ok += _expect(fails, waited >= m.jobs[ji].work_sec - 0.6, "дело сделалось слишком быстро (%.1f с)" % waited)
	ok += _expect(fails, Sfx.played.has(&"job_done") and not me.working, "без звука «готово» или игрок всё ещё работает")
	ok += _expect(fails, day.supplies.text() == "Запасы 1 из %d" % m.supply_total, "капсула запасов не обновилась: «%s»" % day.supplies.text())

	# 5. Ушёл от дела — работа брошена, запасы не растут
	var wood := m.job_index(&"wood")
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.jobs_layer.icon_rect_global(wood).get_center()}, day)
	await _frames(tree, 3)
	ok += _expect(fails, Game.player_job == wood, "к дровам не встал")
	(v.crowd.figures[0] as VillagerFigure).position = Vector2(360, 470)   # палец ровно на своей фигуре: это шаг, а не пояснение
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.to_global(Vector2(360, 470))}, day)
	await _frames(tree, 3)
	await tree.create_timer(0.4).timeout
	ok += _expect(fails, Game.player_job == -1 and not me.working and m.supply_done == 1, "ушёл от дела, а работа продолжилась")

	# 6. Пауза: открыт вопрос — время дня и работа стоят
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.jobs_layer.icon_rect_global(wood).get_center()}, day)
	await _frames(tree, 3)
	Game.hold(&"dialog")
	var t0 := Game.day_t
	var p0 := Game.player_job_progress()
	await tree.create_timer(0.5).timeout
	ok += _expect(fails, Game.day_t == t0 and Game.player_job_progress() == p0, "на паузе время дня или работа идут")
	Game.release(&"dialog")
	Game.cancel_player_job()

	# 7. Дело уже сделано — не встать
	m.job_left[wood] = 0
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.jobs_layer.icon_rect_global(wood).get_center()}, day)
	await _frames(tree, 3)
	ok += _expect(fails, Game.player_job == -1, "встал к делу, которое на сегодня сделано")
	m.job_left[wood] = m.jobs[wood].portions

	# 8. Бот: пошёл к делу, работал, вернулся; пустая работа запасов не даёт
	# под нагрузкой (CI) кадры длинные: день успевает дойти до сундука или колокола — здесь они не нужны
	Game.box_at = -1.0
	Game.meeting_check_at = -1.0
	# тап по сделанному делу открывает его карточку; под нагрузкой она успевает открыться позже — закрываем
	for sh: Node in tree.root.find_children("*", "ActionSheet", true, false):
		(sh as ActionSheet).close(-1)
	await _frames(tree, 2)
	ok += _expect(fails, not Game.held(), "часы дня стоят без открытого окна: %s" % [Game.clock._holds.keys()])
	var bot: Villager = m.alive_bots()[0]
	var bf: VillagerFigure = cr.figures[bot.id]
	var home: Vector2 = cr.ring[bot.id]
	for real: bool in [false, true]:
		var t := Director.JobTask.new()
		t.vid = bot.id
		t.job = ji
		t.start = Game.day_t
		t.real = real
		var only: Array[Director.JobTask] = [t]
		Game.tasks = only
		await _frames(tree, 3)
		ok += _expect(fails, bf.working and bf.position.distance_to(m.jobs[ji].pos) < 110.0, "бот не пошёл к делу или не работает")
		ok += _expect(fails, Game.busy_job(bot.id) == ji, "сессия не знает, что бот занят делом")
		var before := m.supply_done
		Sfx.played.clear()
		t.start = Game.day_t - Director.WORK_SEC - 0.1
		await _frames(tree, 3)
		ok += _expect(fails, t.done and not bf.working and bf.position.distance_to(home) < 2.0, "бот не вернулся на своё место")
		if real:
			ok += _expect(fails, m.supply_done == before + 1, "честная работа бота не дала запасов")
		else:
			ok += _expect(fails, m.supply_done == before and Sfx.played.has(&"job_fail"), "пустая работа дала запасы или прошла без звука")

	# 9. Пустую работу замечают: улика и реплика с местом
	var upyr: Villager = null
	var human: Villager = null
	for b: Villager in m.alive_bots():
		if b.is_upyr and upyr == null:
			upyr = b
		if not b.is_upyr and human == null:
			human = b
	var seen_line: ChatLine = null
	for k in range(80):
		var ls := Game.director.after_job(bot.id, ji, false, false)
		if not ls.is_empty():
			seen_line = ls[0]
			break
	ok += _expect(fails, seen_line != null and seen_line.text.contains(m.jobs[ji].place.split(" ")[1].left(5)), "пустую работу никто не заметил или реплика без места")
	ok += _expect(fails, Game.director.badges(bot.id).has("fake"), "у замеченного нет улики «работал впустую»")
	ok += _expect(fails, Game.director.evidence_text(bot).contains("впустую"), "в шторке нет улики словами")
	# клевета: упырь говорит «впустую» про честного работника
	if upyr != null and human != null:
		var lie: ChatLine = null
		for k in range(120):
			var ls2 := Game.director.after_job(human.id, ji, true, true)
			for l: ChatLine in ls2:
				if l.speaker.is_upyr and l.speaker != human:
					lie = l
			if lie != null:
				break
		ok += _expect(fails, lie != null and Game.director.badges(human.id).has("fake"), "упыри не клевещут на честных работников")

	# 10. Пузырь едет за говорящим
	var speaker: Villager = m.alive_bots()[1]
	var sf: VillagerFigure = cr.figures[speaker.id]
	m.post(ChatLine.say(speaker, "Пойду-ка я за водой."))
	await _frames(tree, 2)
	sf.walk_to(sf.position + Vector2(-90, 20))
	await _frames(tree, 3)
	var bb: Bubbles.Bubble = null
	for b: Bubbles.Bubble in Nav.bubbles.alive():
		if b.who == speaker.name:
			bb = b
	var head := sf.head_global()
	ok += _expect(fails, bb != null and absf(bb.anchor.x - head.x) < 1.0 and bb.rect.end.y <= head.y + 1.0, "пузырь не поехал за говорящим")
	# двое из одного ряда, далеко друг от друга: пузыри рядом на одной высоте.
	# Оба идут в одну точку — пузыри обязаны расступиться, а не лечь друг на друга
	Nav.bubbles.clear()
	var row: Array[Villager] = []
	var row_y: float = cr.ring[m.alive_bots()[0].id].y
	for b2: Villager in m.alive_bots():
		if absf(cr.ring[b2.id].y - row_y) < 1.0:
			cr.figures[b2.id].walk_to(cr.ring[b2.id])
			row.append(b2)
	await _frames(tree, 4)
	# двое ближе всех к середине кадра — их пузыри стоят ровно над головами, а не прижаты к краю
	var cx := vp.x * 0.5
	row.sort_custom(func(a: Villager, c: Villager) -> bool:
		return absf(cr.figures[a.id].head_global().x - cx) < absf(cr.figures[c.id].head_global().x - cx))
	var pair: Array[Villager] = [row[0], row[1]]
	for tv: Villager in pair:
		m.post(ChatLine.say(tv, "Я тут."))
		await _frames(tree, 1)
	var meet := (cr.figures[pair[0].id].position + cr.figures[pair[1].id].position) * 0.5
	for tv: Villager in pair:
		(cr.figures[tv.id] as VillagerFigure).walk_to(meet)
	await _frames(tree, 3)
	var stacked := true
	var live := Nav.bubbles.alive()
	for i in range(live.size()):
		for j in range(i + 1, live.size()):
			if live[i].rect.grow(-1.0).intersects(live[j].rect.grow(-1.0)):
				stacked = false
	ok += _expect(fails, stacked and live.size() == 2, "говорящие сошлись — пузыри налезли друг на друга (пузырей %d)" % live.size())

	# 11. Ночь: горит столько фонарей, сколько заправили; полные запасы — меньше гибели на улице
	m.supply_done = m.supply_total
	var full := m.outside_death_chance()
	ok += _expect(fails, absf(m.config.outside_death_chance(m.day) - full - Match.SUPPLY_BONUS) < 0.001, "полные запасы не снижают шанс гибели на улице")
	Game.end_day()
	await _settle(tree)
	if m.phase == Match.Phase.VOTE:
		Game.vote(-1)
		await _settle(tree)
		Game.proceed()
		await _settle(tree)
	ok += _expect(fails, v.lamps_fueled == v.def.lamps.size(), "при полных запасах горят не все фонари (%d)" % v.lamps_fueled)
	ok += _expect(fails, not v.jobs_layer.visible and v.follow == null, "ночью остались значки дел или камера следит")
	ok += _expect(fails, v.scale.x < scale_day / 1.2, "ночью камера не отъехала (%.2f, днём %.2f)" % [v.scale.x, scale_day])
	# новый день — запасы с нуля, пустые фонари ночью
	Game.choose_house(0)
	await _settle(tree)
	if m.phase == Match.Phase.DOOR:
		if Game.door_role() == Match.DoorRole.GUEST:
			Game.plea("beg")
			await _settle(tree)
			Game.proceed()
		else:
			var none: Array[int] = []
			Game.admit(none)
		await _settle(tree)
	if m.phase == Match.Phase.MORNING:
		Game.proceed()
		await _settle(tree)
	if m.phase == Match.Phase.DAY:
		ji = m.job_index(&"water")
		ok += _expect(fails, m.supply_done == 0 and m.job_left[ji] == m.jobs[ji].portions and m.supply_total == _portions(m), "новый день начался не с пустыми запасами")
		Game.end_day()
		await _settle(tree)
		if m.phase == Match.Phase.VOTE:
			Game.vote(-1)
			await _settle(tree)
			Game.proceed()
			await _settle(tree)
		if m.phase == Match.Phase.NIGHT:
			ok += _expect(fails, v.lamps_fueled == 0, "без запасов ночью горят фонари (%d)" % v.lamps_fueled)

	print("=== живой день: %d проверок ===" % (ok + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — камера идёт за игроком, ходьба и дела работают, запасы зажигают фонари")
		tree.quit(0)
	else:
		for f2: String in fails:
			print("  ✗ " + f2)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)



# =============================================================
# Обереги (Task 25): целый, треснул, расколот. Слабеют за ночь, днём их чинят как дело.
# Расколотый пускает тварь из леса в дом, где ночуют вдвоём; целый бережёт одиночку.
# =============================================================
## Ночь по правилам: together людей в доме 0 (первый добежавший — хозяин, впускает всех),
## остальные в доме 1. Оберег дома 0 перед ночью — tal0.
static func _rules_night(seed_v: int, tal0: int, together: int) -> Dictionary:
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	var m := Match.new()
	m.start(c, seed_v)
	m.begin_day()
	m.end_day()
	var humans: Array[Villager] = []
	for v: Villager in m.villagers:
		if not v.is_upyr:
			humans.append(v)
	var ch: Dictionary[int, int] = {}
	var arr: Dictionary[int, float] = {}
	for v: Villager in m.alive():
		ch[v.id] = 1
	for k in range(together):
		ch[humans[k].id] = 0
		arr[humans[k].id] = float(k)
	m.seat_night(ch, arr)
	for s: Match.Seat in m.seats:
		var ids: Array[int] = []
		if s.house == 0:
			for v: Villager in s.queue:
				ids.append(v.id)
		m.admit(s, ids)
	m.talisman[0] = tal0
	var before := m.talisman.duplicate()
	var r := m.resolve_night()
	return {"m": m, "r": r, "humans": humans, "before": before}


static func _count(r: NightReport, kind: NightReport.Kind, house: int) -> int:
	var n := 0
	for e: NightReport.Entry in r.entries:
		if e.kind == kind and e.house == house:
			n += 1
	return n


static func talisman() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()

	# 1. Правила: старт — все целы, кроме одного; дело починки только у треснувшего
	var m0 := Match.new()
	m0.start((load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig, 77)
	var cracked := 0
	for t: int in m0.talisman:
		if t == Match.TALISMAN_MAX - 1:
			cracked += 1
	ok += _expect(fails, m0.talisman.size() == m0.houses.size() and cracked == 1, "на старте треснувших оберегов %d, ждём ровно один" % cracked)
	m0.begin_day()
	var tjobs := 0
	var portions := 0
	for j: JobDef in m0.jobs:
		portions += j.portions
		if j.kind == JobDef.Kind.TALISMAN:
			tjobs += 1
			ok += _expect(fails, j.house >= 0 and m0.talisman[j.house] < Match.TALISMAN_MAX and j.portions == Match.TALISMAN_MAX - m0.talisman[j.house],
				"дело починки не у того дома или не столько порций")
	ok += _expect(fails, tjobs == 1 and m0.supply_total == portions, "дел починки %d, запасов %d из %d порций" % [tjobs, m0.supply_total, portions])
	var tj := m0.job_index(StringName("talisman_%d" % m0.talisman.find(Match.TALISMAN_MAX - 1)))
	var th := m0.jobs[tj].house
	ok += _expect(fails, not m0.do_job(m0.player(), tj, false) and m0.talisman[th] == Match.TALISMAN_MAX - 1, "работа впустую починила оберег")
	ok += _expect(fails, m0.do_job(m0.player(), tj, true) and m0.talisman[th] == Match.TALISMAN_MAX and not m0.job_available(tj), "честная работа не починила оберег")

	# 2. Расколотый оберег: тварь забирает одного из двоих примерно в 70% ночей. Целый — никогда.
	var runs := 400
	var kill0 := 0
	var kill2 := 0
	var host_first := true
	for i in range(runs):
		var a := _rules_night(1000 + i, 0, 2)
		kill0 += _count(a.r, NightReport.Kind.KILLED_CREATURE, 0)
		var seat0: Match.Seat = null
		for s: Match.Seat in (a.m as Match).seats:
			if s.house == 0:
				seat0 = s
		if seat0 == null or seat0.host != (a.humans as Array)[0]:
			host_first = false
		var b := _rules_night(1000 + i, Match.TALISMAN_MAX, 2)
		kill2 += _count(b.r, NightReport.Kind.KILLED_CREATURE, 0)
	print("тварь у расколотого: %d из %d ночей, у целого: %d" % [kill0, runs, kill2])
	ok += _expect(fails, kill0 > runs * 0.6 and kill0 < runs * 0.8, "тварь у расколотого оберега в %d из %d ночей, ждём около 70%%" % [kill0, runs])
	ok += _expect(fails, kill2 == 0, "тварь пришла в дом с целым оберегом (%d раз)" % kill2)
	ok += _expect(fails, host_first, "хозяином двери стал не тот, кто добежал первым")

	# 3. Одиночка: целый оберег бережёт (×0.8), расколотый — тварь (не меньше 70%)
	var alone2 := 0
	var alone0 := 0
	for i in range(runs):
		alone2 += _count(_rules_night(5000 + i, Match.TALISMAN_MAX, 1).r, NightReport.Kind.KILLED_ALONE, 0)
		alone0 += _count(_rules_night(5000 + i, 0, 1).r, NightReport.Kind.KILLED_ALONE, 0)
	var p_out := (load("res://config/balance_7.tres") as GameConfig).outside_death_chance(1)
	print("одиночка: гибель при целом %d, при расколотом %d из %d (без оберега было бы %.0f%%)" % [alone2, alone0, runs, p_out * 100.0])
	ok += _expect(fails, absf(float(alone2) / runs - p_out * Match.ALONE_SAFE) < 0.07, "целый оберег не бережёт одиночку (%d из %d)" % [alone2, runs])
	ok += _expect(fails, absf(float(alone0) / runs - maxf(p_out, Match.CREATURE_KILL)) < 0.07, "расколотый оберег не опасен одиночке (%d из %d)" % [alone0, runs])

	# 4. Обереги слабеют: около половины за ночь, каждое ослабление — в утренней сводке
	var could := 0
	var worn := 0
	var reported := true
	for i in range(runs):
		var a := _rules_night(9000 + i, Match.TALISMAN_MAX, 2)
		var mm: Match = a.m
		var bf: PackedInt32Array = a.before
		for h in range(bf.size()):
			if bf[h] > 0:
				could += 1
				var dropped := bf[h] - mm.talisman[h]
				worn += dropped
				if dropped != _count(a.r, NightReport.Kind.TALISMAN_WORN, h):
					reported = false
	ok += _expect(fails, absf(float(worn) / maxf(1.0, could) - Match.TALISMAN_DECAY) < 0.06, "обереги слабеют в %d из %d случаев, ждём около половины" % [worn, could])
	ok += _expect(fails, reported, "ослабший оберег не попал в утреннюю сводку")

	# 5. Утренние строки
	var ms := MorningScreen.new()
	ms.m = m0
	var e1 := NightReport.Entry.new()
	e1.kind = NightReport.Kind.KILLED_CREATURE
	e1.who = m0.villagers[1]
	e1.house = 0
	var e2 := NightReport.Entry.new()
	e2.kind = NightReport.Kind.TALISMAN_WORN
	e2.house = 0
	var t1 := ms._text(e1)
	var t2 := ms._text(e2)
	ms.free()
	ok += _expect(fails, t1.contains("Тварь") and t1.contains("Оберег"), "утром не сказано про тварь: «%s»" % t1)
	ok += _expect(fails, t2.contains("Оберег") and t2.contains("подправить"), "утром не сказано, что оберег ослаб: «%s»" % t2)

	# 6. На поле: оберег виден, его дело — значок у дома; починил — оберег цел
	Save.set_difficulty("normal")
	var v := Nav.village
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _settle(tree)
	var m := Game.m
	var day := Nav.host.current as DayScreen
	ok += _expect(fails, v.talismans == m.talisman, "на поле обереги не те, что в правилах")
	var h := m.talisman.find(Match.TALISMAN_MAX - 1)
	var ji := m.job_index(StringName("talisman_%d" % h))
	ok += _expect(fails, h >= 0 and ji >= 0 and m.jobs[ji].kind == JobDef.Kind.TALISMAN, "у треснувшего оберега нет дела починки")
	if ji >= 0:
		var icon := v.jobs_layer.icon_rect_global(ji)
		var house_g := v.to_global(v.def.shelters[h].pos)
		ok += _expect(fails, icon.get_center().distance_to(house_g) < 260.0 * v.scale.x, "значок починки далеко от своего дома")
		Nav.handle_intent(Intent.FIELD_TAP, {"pos": icon.get_center()}, day)
		await _frames(tree, 3)
		ok += _expect(fails, Game.player_job == ji, "тап по значку починки не поставил игрока работать")
		var guard := 0.0
		while Game.player_job >= 0 and guard < 8.0:
			await tree.create_timer(0.1).timeout
			guard += 0.1
		await _frames(tree, 2)
		ok += _expect(fails, m.talisman[h] == Match.TALISMAN_MAX and v.talismans[h] == Match.TALISMAN_MAX, "починил, а оберег не цел (правила %d, поле %d)" % [m.talisman[h], v.talismans[h]])
	# ночью в списке видно, какой оберег ослаб
	m.talisman[0] = 0
	if m.houses.size() > 1:
		m.talisman[1] = 1
	Game.end_day()
	await _settle(tree)
	if m.phase == Match.Phase.VOTE:
		Game.vote(-1)
		await _settle(tree)
		Game.proceed()
		await _settle(tree)
	var ns := Nav.host.current as NightScreen
	ok += _expect(fails, ns != null and ns._rows[0].text.contains("оберег расколот") and (m.houses.size() < 2 or ns._rows[1].text.contains("оберег треснул")),
		"в списке домов не видно, что оберег ослаб")
	ok += _expect(fails, v.talismans[0] == 0, "ночью на поле оберег не расколот")

	print("=== обереги: %d проверок ===" % (ok + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — обереги слабеют, чинятся делом, расколотый пускает тварь, целый бережёт")
		tree.quit(0)
	else:
		for f2: String in fails:
			print("  ✗ " + f2)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)



# =============================================================
# Колокол (Task 26): по звону все бегут к домам в реальном времени. Кто первым
# у двери — хозяин, очередь в порядке прибытия. Не выбрал дом за звон — бежишь последним.
# =============================================================
## Довести партию до ночи: день → (голосование) → колокол.
static func _to_night(tree: SceneTree) -> void:
	Game.end_day()
	await _settle(tree)
	if Game.m.phase == Match.Phase.VOTE:
		Game.vote(-1)
		await _settle(tree)
		Game.proceed()
		await _settle(tree)


static func _new_day(tree: SceneTree) -> void:
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _settle(tree)


## Очередь у каждой двери идёт по времени прибытия, хозяин — первый.
static func _seats_in_order(m: Match, arrive: Dictionary[int, float]) -> bool:
	for s: Match.Seat in m.seats:
		var line: Array[Villager] = [s.host]
		line.append_array(s.queue)
		for k in range(1, line.size()):
			if arrive.get(line[k - 1].id, 1.0e6) > arrive.get(line[k].id, 1.0e6):
				return false
	return true


static func bell() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()

	# 1. Правила: порядок у двери — по прибытию; кого нет во временах, тот после всех
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	var m0 := Match.new()
	m0.start(c, 31)
	m0.begin_day()
	m0.end_day()
	var ch: Dictionary[int, int] = {}
	var arr: Dictionary[int, float] = {}
	var ids: Array[int] = []
	for v: Villager in m0.alive():
		ch[v.id] = 0
		ids.append(v.id)
	for k in range(ids.size() - 1):
		arr[ids[k]] = 10.0 - k        # последний в списке без времени — опоздал
	m0.seat_night(ch, arr)
	var s0: Match.Seat = m0.seats[0]
	ok += _expect(fails, s0.host.id == ids[ids.size() - 2] and s0.queue.back().id == ids.back() and _seats_in_order(m0, arr),
		"у двери стоят не в порядке прибытия")

	# 2. Пресеты: звон короче на сложной, длиннее на лёгкой; ползунок в настройках
	ok += _expect(fails, Difficulty.preset("easy").run_seconds > Difficulty.preset("normal").run_seconds and Difficulty.preset("hard").run_seconds < Difficulty.preset("normal").run_seconds,
		"время колокола не зависит от сложности")
	ok += _expect(fails, GameConfig.LABELS.has("run_seconds"), "нет ползунка «Бег до дома»")

	# 3. Колокол: бег начался, у ботов реакция и время прибытия, идёт отсчёт
	Save.set_difficulty("normal")
	var v := Nav.village
	await _new_day(tree)
	await _to_night(tree)
	Game.hold(&"test")
	await _settle(tree)
	var m := Game.m
	var ns := Nav.host.current as NightScreen
	var all_bots := true
	var times_ok := true
	for b: Villager in m.alive_bots():
		if not Game.run_choices.has(b.id):
			all_bots = false
			continue
		var rt: float = Game.run_react[b.id]
		if rt < Director.RUN_REACT_FAST.x - 0.001 or rt > Director.RUN_REACT.y + 0.001 or Game.run_arrive[b.id] <= rt:
			times_ok = false
	ok += _expect(fails, m.phase == Match.Phase.NIGHT and Game.run_on and Game.run_house == -1 and all_bots, "колокол не отправил всех ботов бежать")
	ok += _expect(fails, times_ok, "у ботов нет реакции на колокол или время прибытия раньше старта")
	ok += _expect(fails, Game.clock.running() and Game.clock.time_left() > m.config.run_seconds - 1.0 and Game.clock.time_left() <= m.config.run_seconds,
		"нет обратного отсчёта колокола (%.1f с)" % Game.clock.time_left())
	ok += _expect(fails, ns != null and _find_button(ns, "Идти") == null and ns._status.text.contains("колокол"), "на экране ночи кнопка «Идти» или нет призыва бежать")
	# первая ночь с подсказкой: колокол ждёт новичка, боты стоят на местах
	var standing := true
	for b: Villager in m.alive_bots():
		if v.crowd.figures[b.id].position.distance_to(v.crowd.ring[b.id]) > 2.0:
			standing = false
	ok += _expect(fails, Game.held_by(&"hint") and standing, "первая ночь не ждёт, пока новичок прочтёт подсказку")

	# 4. Пауза: время бега и отсчёт стоят
	var rt0 := Game.run_t
	var cl0 := Game.clock.time_left()
	await tree.create_timer(0.3).timeout
	ok += _expect(fails, Game.run_t == rt0 and Game.clock.time_left() == cl0, "на паузе бег продолжается")

	# 5. Выбрал дом — время до двери считается от того места, где стоишь; передумал — пересчёт
	var d0: float = Game.run_distance.call(0, 0)
	ns.select_house(0)
	await _frames(tree, 2)
	ok += _expect(fails, Game.run_house == 0 and absf(Game.run_arrive[0] - (Game.run_t + d0 / (Director.RUN_SPEED * Game.PLAYER_RUN))) < 0.01, "время прибытия игрока посчитано неверно")
	ok += _expect(fails, ns._status.text.contains(m.houses[0]), "на экране не сказано, куда бежишь")
	ok += _expect(fails, not Game.held_by(&"hint"), "выбрал дом, а колокол всё ещё ждёт")
	var ahead := Nav.run_ahead()
	ok += _expect(fails, ns._status.text.contains("Добежишь первым") if ahead.is_empty() else ns._status.text.contains("Раньше тебя у двери: " + ", ".join(ahead)),
		"на экране не сказано, кто добежит раньше тебя: «%s»" % ns._status.text)
	var d1: float = Game.run_distance.call(0, 1)
	ns.select_house(1)
	await _frames(tree, 2)
	ok += _expect(fails, Game.run_house == 1 and absf(Game.run_arrive[0] - (Game.run_t + d1 / (Director.RUN_SPEED * Game.PLAYER_RUN))) < 0.01, "смена дома на бегу не пересчитала время")
	# на поле: у каждой двери первым стоит тот, кто добежит первым
	var cr := v.crowd
	var first_ok := true
	for hh in range(v.open_count):
		var group: Array[int] = []
		for vid: int in Game.run_choices:
			if Game.run_choices[vid] == hh and m.get_villager(vid).alive:
				group.append(vid)
		if hh == 1:
			group.append(0)
		if group.size() < 2:
			continue
		group.sort_custom(func(a: int, b: int) -> bool: return Game.run_arrive[a] < Game.run_arrive[b])
		var d_first := cr.figures[group[0]].position.distance_to(v.def.shelters[hh].pos)
		for k in range(1, group.size()):
			if cr.figures[group[k]].position.distance_to(v.def.shelters[hh].pos) < d_first - 1.0:
				first_ok = false
	ok += _expect(fails, first_ok, "на поле ближе к двери стоит не тот, кто добежит первым")

	# 6. Все добежали — ночь начинается до конца звона, очередь по времени прибытия
	Game.release(&"test")
	var ran := 0.0
	while m.phase == Match.Phase.NIGHT and ran < float(m.config.run_seconds) + 2.0:
		await tree.process_frame
		ran += maxf(tree.root.get_process_delta_time(), 0.001)
	ok += _expect(fails, m.phase != Match.Phase.NIGHT and m.player().night_house == 1, "бег не закончился во втором доме")
	ok += _expect(fails, _seats_in_order(m, Game.run_arrive), "очередь у двери не по времени прибытия")
	ok += _expect(fails, Game.run_t < float(m.config.run_seconds), "ночь ждала конца звона, хотя все добежали")

	# 7. Колокол отзвонил, дом не выбран: бежишь туда, куда собирался днём, — последним
	await _new_day(tree)
	m = Game.m
	m.player().announced_house = 1
	await _to_night(tree)
	ok += _expect(fails, Game.run_on and Game.run_house == -1, "второй колокол не начался")
	Game.clock.start(0.05)
	var w := 0.0
	while m.phase == Match.Phase.NIGHT and w < 2.0:
		await tree.process_frame
		w += maxf(tree.root.get_process_delta_time(), 0.001)
	var my_seat: Match.Seat = null
	for s: Match.Seat in m.seats:
		if s.host == m.player() or s.queue.has(m.player()):
			my_seat = s
	ok += _expect(fails, m.phase != Match.Phase.NIGHT and m.player().night_house == 1, "по концу звона игрок не побежал туда, куда собирался")
	ok += _expect(fails, my_seat != null and (my_seat.queue.is_empty() and my_seat.host == m.player() or my_seat.queue.back() == m.player()),
		"опоздавший игрок встал не последним")

	# 8. Не собирался никуда — бежит к ближайшему дому
	await _new_day(tree)
	m = Game.m
	m.player().announced_house = -1
	await _to_night(tree)
	var near := 0
	for hh in range(m.houses.size()):
		if float(Game.run_distance.call(0, hh)) < float(Game.run_distance.call(0, near)):
			near = hh
	Game.clock.start(0.05)
	w = 0.0
	while m.phase == Match.Phase.NIGHT and w < 2.0:
		await tree.process_frame
		w += maxf(tree.root.get_process_delta_time(), 0.001)
	ok += _expect(fails, m.player().night_house == near, "без выбора игрок побежал не к ближайшему дому (%d, ближе %d)" % [m.player().night_house, near])

	# 9. Мёртвому колокол не нужен: без бега и отсчёта, кнопка «Дальше»
	await _new_day(tree)
	m = Game.m
	m.player().alive = false
	await _to_night(tree)
	ns = Nav.host.current as NightScreen
	var next := _find_button(ns, "Дальше") if ns != null else null
	ok += _expect(fails, not Game.run_on and not Game.clock.running() and next != null, "мёртвому игроку запущен бег или нет «Дальше»")
	if next != null:
		next.pressed.emit()
		await _settle(tree)
	ok += _expect(fails, m.phase != Match.Phase.NIGHT, "без игрока ночь не пошла дальше")

	# 10. Запоздалый бег бота: стоит, пока не услышал колокол, потом бежит
	Juice.instant = false
	var probe: VillagerFigure = cr.figures[m.alive_bots()[0].id]
	var p0 := probe.position
	probe.run_to(p0 + Vector2(60, 0), 0.4, 0.6)
	await tree.create_timer(0.3).timeout
	var still := probe.position.distance_to(p0) < 0.5
	await tree.create_timer(1.2).timeout
	Juice.instant = true
	ok += _expect(fails, still and probe.position.distance_to(p0 + Vector2(60, 0)) < 1.0, "задержка перед бегом не работает")

	print("=== колокол: %d проверок ===" % (ok + fails.size()))
	if fails.is_empty():
		print("ИТОГ: OK — колокол, бег в реальном времени, очередь по прибытию, опоздавший последний")
		tree.quit(0)
	else:
		for f2: String in fails:
			print("  ✗ " + f2)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)



# =============================================================
# Общее для задач 27–30: партия по правилам, доведённая до ночи нужного дня.
# =============================================================
static func _rules_to_night(seed_v: int, night: int, force_event: int = -1) -> Match:
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	var m := Match.new()
	m.start(c, seed_v)
	m.force_event = force_event
	m.begin_day()
	m.day = night
	m.end_day()
	if m.phase == Match.Phase.VOTE:
		var none: Dictionary[int, int] = {}
		m.apply_vote(none)
		m.after_vote()
	return m


## Ночь по правилам: все разбегаются как попало, двери открывают боты (и игрок — первому в очереди).
static func _rules_seat(m: Match, d: Director) -> void:
	var ch := d.night_choices()
	ch[0] = m.rng.randi_range(0, m.houses.size() - 1)
	m.seat_night(ch)


## Весь текст экрана двери лежит на тёмной плотной подложке.
static func _on_plate(ds: DoorScreen) -> bool:
	var plate := ds._box.get_parent() as PanelContainer if ds._box != null else null
	if plate == null:
		return false
	var sb := plate.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null or sb.bg_color.a < 0.8 or sb.bg_color.v > 0.2:
		return false
	for c: Control in _controls(ds.body):
		if c is Label and c.is_visible_in_tree() and not plate.is_ancestor_of(c):
			return false
	return ds.footer.get_parent() is PanelContainer   # кнопки тоже на подложке


## Нажать «Подробнее» на экране и вернуть текст шторки (шторка закрывается).
static func _more_text(s: Node) -> String:
	var b := s.find_child("More", true, false) as Button
	if b == null:
		return ""
	b.pressed.emit()
	var sh := s.find_child("InfoSheet", true, false) as InfoSheet
	if sh == null:
		return ""
	var t := _all_text(sh)
	sh.close()
	sh.get_parent().remove_child(sh)       # уйдёт из дерева сразу, удалится в конце кадра
	return t


static func _all_text(root: Node) -> String:
	var out := PackedStringArray()
	for c: Control in _controls(root):
		if c is Label and c.is_visible_in_tree():
			out.append((c as Label).text)
		elif c is Button and c.is_visible_in_tree():
			out.append((c as Button).text)
	return "\n".join(out)


static func _finish(fails: PackedStringArray, ok: int, title: String, good: String) -> void:
	var tree := Nav.get_tree()
	print("=== %s: %d проверок ===" % [title, ok + fails.size()])
	if fails.is_empty():
		print("ИТОГ: OK — " + good)
		tree.quit(0)
	else:
		for f2: String in fails:
			print("  ✗ " + f2)
		print("ИТОГ: НАРУШЕНИЙ: %d" % fails.size())
		tree.quit(1)


# =============================================================
# События ночи (Task 30): туман, полная луна, тихая ночь, ливень. Со второй ночи,
# примерно в половине ночей. Объявляются с колоколом, утром — в сводке.
# =============================================================
static func events() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()

	# 1. Первая ночь всегда обычная; со второй — около половины ночей, все четыре события бывают
	var first := 0
	for i in range(200):
		if _rules_to_night(100 + i, 1).night_event != Match.Event.NONE:
			first += 1
	var seen: Dictionary[int, int] = {}
	var nights := 0
	var with_event := 0
	for i in range(400):
		var m := _rules_to_night(700 + i, 2)
		if m.phase != Match.Phase.NIGHT:
			continue
		nights += 1
		if m.night_event != Match.Event.NONE:
			with_event += 1
			seen[m.night_event] = seen.get(m.night_event, 0) + 1
	print("события: первая ночь %d из 200, со второй %d из %d, виды %s" % [first, with_event, nights, seen])
	ok += _expect(fails, first == 0, "событие в первую ночь (%d раз)" % first)
	ok += _expect(fails, absf(float(with_event) / maxf(1, nights) - Match.EVENT_P) < 0.08, "события в %d из %d ночей, ждём около половины" % [with_event, nights])
	ok += _expect(fails, seen.size() == 4, "бывают не все события: %s" % seen)

	# 2. Что меняет каждое событие
	var fog := _rules_to_night(5, 2, Match.Event.FOG)
	var calm := _rules_to_night(5, 2, Match.Event.NONE)
	fog.supply_done = fog.supply_total      # подальше от потолка 95%: туман должен прибавить ровно свои 10%
	calm.supply_done = calm.supply_total
	ok += _expect(fails, fog.run_seconds() == fog.config.run_seconds - Match.FOG_RUN and calm.run_seconds() == calm.config.run_seconds, "туман не укорачивает звон")
	ok += _expect(fails, absf(fog.outside_death_chance() - calm.outside_death_chance() - Match.FOG_DEATH) < 0.001, "в тумане улица не опаснее")
	var quiet := _rules_to_night(5, 2, Match.Event.QUIET)
	quiet.supply_done = quiet.supply_total
	ok += _expect(fails, absf(calm.outside_death_chance() - quiet.outside_death_chance() - Match.QUIET_SAFE) < 0.001, "тихая ночь не бережёт на улице")
	var rain := _rules_to_night(5, 2, Match.Event.RAIN)
	calm.supply_done = calm.supply_total
	rain.supply_done = rain.supply_total
	ok += _expect(fails, rain.outside_death_chance() > calm.outside_death_chance() + Match.SUPPLY_BONUS - 0.001, "в ливень запасы всё ещё спасают на улице")
	# полная луна: к утру слабеют все обереги
	var moon := _rules_to_night(5, 2, Match.Event.MOON)
	var d := Director.new()
	d.attach(moon)
	_rules_seat(moon, d)
	for s: Match.Seat in moon.seats:
		var none: Array[int] = []
		moon.admit(s, none)
	var before := moon.talisman.duplicate()
	moon.resolve_night()
	var all_down := true
	for h in range(before.size()):
		if before[h] > 0 and moon.talisman[h] != before[h] - 1:
			all_down = false
	ok += _expect(fails, all_down, "в полнолуние ослабли не все обереги")
	# тихая ночь: Подражатель не приходит
	var mimics := 0
	for i in range(200):
		var mq := _rules_to_night(900 + i, 2, Match.Event.QUIET)
		if mq.phase != Match.Phase.NIGHT:
			continue
		var dq := Director.new()
		dq.attach(mq)
		_rules_seat(mq, dq)
		for s: Match.Seat in mq.seats:
			if s.mimic != null:
				mimics += 1
	ok += _expect(fails, mimics == 0, "в тихую ночь пришёл Подражатель (%d раз)" % mimics)

	# 3. На экране: колокол объявляет событие, в тумане отсчёт короче, в ливень фонари не горят
	Save.set_difficulty("normal")
	var v := Nav.village
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	Game.m.force_event = Match.Event.FOG
	Game.m.day = 2
	Game.m.config.vote_from_day = 9      # без изгнания: игрок точно жив и бежит по колоколу
	await _to_night(tree)
	var ns := Nav.host.current as NightScreen
	ok += _expect(fails, ns != null and _all_text(ns).contains(Match.event_title(Match.Event.FOG)) and ns.find_child("Event", true, false).get_child(0) is Glyph, "колокол не объявил туман значком")
	ok += _expect(fails, ns != null and _more_text(ns).contains(Match.event_text(Match.Event.FOG)), "в «Подробнее» нет, что делает туман")
	ok += _expect(fails, Game.clock.time_left() <= float(Game.m.config.run_seconds - Match.FOG_RUN) + 0.01, "в тумане отсчёт не короче (%.1f с)" % Game.clock.time_left())
	Game.choose_house(0)
	await _settle(tree)
	if Game.m.phase == Match.Phase.DOOR:
		if Game.door_role() == Match.DoorRole.GUEST:
			Game.plea("beg")
			await _settle(tree)
			Game.proceed()
		else:
			var none: Array[int] = []
			Game.admit(none)
		await _settle(tree)
	if Game.m.phase == Match.Phase.MORNING:
		await tree.create_timer(0.3).timeout
		await _settle(tree)
		ok += _expect(fails, _all_text(Nav.host.current).contains(Match.event_text(Match.Event.FOG)), "утром не сказано про туман")
		Game.proceed()
		await _settle(tree)
	if Game.m.phase == Match.Phase.DAY:
		ok += _expect(fails, Game.m.night_event == Match.Event.NONE, "событие ночи осталось на день")
	# ливень: при полных запасах фонари не горят; без ливня — горят
	for ev: int in [Match.Event.NONE, Match.Event.RAIN]:
		Nav.start_match()
		await _settle(tree)
		Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
		await _settle(tree)
		Game.m.force_event = ev
		Game.m.day = 2
		Game.m.config.vote_from_day = 9
		Game.m.supply_done = Game.m.supply_total
		await _to_night(tree)
		var lit := v.lamps_fueled
		if ev == Match.Event.RAIN:
			ok += _expect(fails, Game.m.phase == Match.Phase.NIGHT and lit == 0, "в ливень горят фонари (%d)" % lit)
		else:
			ok += _expect(fails, Game.m.phase == Match.Phase.NIGHT and lit == v.def.lamps.size(), "без ливня при полных запасах горят не все фонари (%d)" % lit)

	_finish(fails, ok, "события ночи", "туман, луна, тишина и ливень меняют ночь и видны игроку")


# =============================================================
# Подражатель у двери (Task 27): со второй ночи тварь стучит в одну из дверей голосом
# жителя, которого там быть не может. Впустили — забирает одного из тех, кто внутри.
# =============================================================
static func mimic() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()

	# 1. Когда и чьим голосом
	var first := 0
	var later := 0
	var nights := 0
	var voice_ok := true
	var sample: Match = null
	for i in range(400):
		var m1 := _rules_to_night(300 + i, 1, Match.Event.NONE)
		var d1 := Director.new()
		d1.attach(m1)
		_rules_seat(m1, d1)
		for s: Match.Seat in m1.seats:
			if s.mimic != null:
				first += 1
		var m2 := _rules_to_night(300 + i, 2, Match.Event.NONE)
		if m2.phase != Match.Phase.NIGHT:
			continue
		var d2 := Director.new()
		d2.attach(m2)
		_rules_seat(m2, d2)
		nights += 1
		for s: Match.Seat in m2.seats:
			if s.mimic == null:
				continue
			later += 1
			if sample == null:
				sample = m2
			if s.mimic.is_player or s.mimic == s.host or s.queue.has(s.mimic) or (s.mimic.alive and s.mimic.night_house == s.house):
				voice_ok = false
			var kn := s.knockers()
			if kn.size() != s.queue.size() + 1 or kn[s.mimic_at] != s.mimic:
				voice_ok = false
	print("Подражатель: первая ночь %d, вторая %d из %d ночей" % [first, later, nights])
	ok += _expect(fails, first == 0, "Подражатель пришёл в первую ночь")
	ok += _expect(fails, absf(float(later) / maxf(1, nights) - Match.MIMIC_P) < 0.08, "Подражатель приходит в %d из %d ночей, ждём около %d%%" % [later, nights, int(Match.MIMIC_P * 100)])
	ok += _expect(fails, voice_ok, "Подражатель говорит голосом того, кто стоит у этой же двери, или игрока")

	# 2. Впустили — забирает одного (около 85%), не впустили — стук слышат все
	var killed := 0
	var admitted := 0
	var knocks := 0
	var cap_ok := true
	var texts_ok := true
	for i in range(600):
		var m := _rules_to_night(2000 + i, 2, Match.Event.NONE)
		if m.phase != Match.Phase.NIGHT:
			continue
		var d := Director.new()
		d.attach(m)
		_rules_seat(m, d)
		var let_in := i % 2 == 0
		for s: Match.Seat in m.seats:
			var ids: Array[int] = []
			if s.mimic != null and let_in:
				s.mimic_at = 0               # голос первым в очереди: открыли ему — места больше нет
				ids.append(s.mimic.id)
			if not s.queue.is_empty():
				ids.append(s.queue[0].id)    # места на всех нет: кто стоит раньше, тот и войдёт
			m.admit(s, ids)
			if s.mimic_in:
				admitted += 1
				if s.admitted.size() + 1 > m.config.capacity - 1:
					cap_ok = false
		var r := m.resolve_night()
		var ms := MorningScreen.new()
		ms.m = m
		for e: NightReport.Entry in r.entries:
			match e.kind:
				NightReport.Kind.KILLED_MIMIC:
					killed += 1
					var t := ms._text(e)
					if not (t.contains("голос") and t.contains(e.voice.name) and t.contains("Подражатель")):
						texts_ok = false
				NightReport.Kind.MIMIC_KNOCK:
					knocks += 1
					if not ms._text(e).contains("стучали голосом"):
						texts_ok = false
		ms.free()
	print("Подражатель впущен %d раз, забрал %d; стучал без ответа %d" % [admitted, killed, knocks])
	ok += _expect(fails, admitted > 40 and float(killed) / admitted > 0.7 and float(killed) / admitted < 0.95, "впущенный Подражатель забирает %d из %d, ждём 70–95%%" % [killed, admitted])
	ok += _expect(fails, knocks > 20, "стук Подражателя не попадает в утреннюю сводку")
	ok += _expect(fails, cap_ok, "Подражатель не занимает место в доме")
	ok += _expect(fails, texts_ok, "утром не сказано, чьим голосом стучали")

	# 3. Боты-хозяева: голос погибшего почти не пускают, голос живого — иногда
	var dead_in := 0
	var alive_in := 0
	var tries := 400
	var base := _rules_to_night(77, 2, Match.Event.NONE)
	var db := Director.new()
	db.attach(base)
	var host: Villager = base.alive_bots()[0]
	var voice: Villager = base.alive_bots()[1]
	for i in range(tries):
		var s := Match.Seat.new()
		s.house = 0
		s.host = host
		s.mimic = voice
		voice.alive = false
		if db.host_decide(s).has(voice.id):
			dead_in += 1
		voice.alive = true
		voice.announced_house = -1
		if db.host_decide(s).has(voice.id):
			alive_in += 1
	print("боты впускают голос: погибшего %d, живого %d из %d" % [dead_in, alive_in, tries])
	ok += _expect(fails, float(dead_in) / tries < 0.1, "боты впускают голос погибшего (%d из %d)" % [dead_in, tries])
	ok += _expect(fails, alive_in > dead_in * 3 and float(alive_in) / tries < 0.5, "боты-хозяева не различают голоса (%d против %d)" % [alive_in, dead_in])

	# 4. Экран двери: голос стоит в очереди со своей мольбой; впустил — Подражатель внутри
	Save.set_difficulty("normal")
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	var m := Game.m
	var bots := m.alive_bots()
	var seat := Match.Seat.new()
	seat.house = 0
	seat.host = m.player()
	seat.queue = [bots[0]] as Array[Villager]
	seat.mimic = bots[1]
	seat.mimic_at = 0
	var other := Match.Seat.new()
	other.house = 1
	other.host = bots[1]        # тот, чьим голосом стучат, на самом деле у другой двери
	m.seats = [seat, other] as Array[Match.Seat]
	var ds := DoorScreen.new()
	ds.role = Match.DoorRole.HOST
	ds.seat = seat
	ds.pleas = {bots[0].id: Game.director.plea_for(bots[0]), bots[1].id: Game.director.mimic_plea(bots[1])}
	Nav.show(ds)
	await _settle(tree)
	var txt := _all_text(ds)
	ok += _expect(fails, _more_text(ds).contains("У других дверей: %s." % bots[1].name), "хозяин не видит, кто сейчас у других дверей")
	ok += _expect(fails, ds._rows.size() == 2 and ds._rows.has(bots[1].id) and txt.contains(bots[1].name), "голоса за дверью нет в очереди")
	var plea_ok := false
	for line: String in Phrases.b("MIMIC_PLEAS"):
		if txt.contains(Phrases.fill(line, {"who": bots[1].name, "me_f": bots[1].female})):
			plea_ok = true
	ok += _expect(fails, plea_ok, "у голоса за дверью не его странная мольба")
	ok += _expect(fails, _on_plate(ds), "текст двери не на тёмной подложке: свет из двери его засветит")
	# гость: слышит голос за спиной
	var gseat := Match.Seat.new()
	gseat.house = 1
	gseat.host = bots[2]
	gseat.queue = [m.player()] as Array[Villager]
	gseat.mimic = bots[3]
	var gs := DoorScreen.new()
	gs.role = Match.DoorRole.GUEST
	gs.seat = gseat
	Nav.show(gs)
	await _settle(tree)
	ok += _expect(fails, _all_text(gs).contains("Голос за спиной: %s" % bots[3].name) and _more_text(gs).contains("голосом %s" % _ru_case("gen", bots[3].name)), "гость не слышит голоса Подражателя за спиной")
	ok += _expect(fails, _on_plate(gs), "текст у чужой двери не на тёмной подложке")
	Nav.show_menu()
	await _settle(tree)

	_finish(fails, ok, "Подражатель", "стучит со второй ночи чужим голосом, впустили — забирает, утром все знают")


# =============================================================
# Саботаж (Task 28): упырь портит сделанное — запасы −1, порция возвращается делу.
# Испорченное видят все, кто это был — иногда видит сосед. Игрок-упырь тоже может портить.
# =============================================================
static func sabotage() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()

	# 1. Правила: портить можно только сделанное
	var m0 := Match.new()
	m0.start((load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig, 41)
	m0.begin_day()
	var w := m0.job_index(&"water")
	ok += _expect(fails, not m0.can_sabotage(w) and not m0.sabotage(w), "испортили дело, где ещё ничего не сделано")
	m0.do_job(m0.player(), m0.job_index(&"wood"), true)
	ok += _expect(fails, not m0.can_sabotage(w), "у колодца ничего не сделано, а испортить можно (запасы есть у дров)")
	m0.do_job(m0.player(), w, true)
	var left := m0.job_left[w]
	ok += _expect(fails, m0.can_sabotage(w) and m0.sabotage(w) and m0.supply_done == 1 and m0.job_left[w] == left + 1, "саботаж не забрал запасы или не вернул порцию")
	var tj := -1
	for i in range(m0.jobs.size()):
		if m0.jobs[i].kind == JobDef.Kind.TALISMAN:
			tj = i
	if tj >= 0:
		m0.do_job(m0.player(), w, true)
		m0.do_job(m0.player(), tj, true)
		ok += _expect(fails, not m0.can_sabotage(tj), "оберег можно испортить как дело")

	# 2. Боты: портят только упыри и только вместо настоящей работы
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	var sab := 0
	var fake_upyr := 0
	var wrong := false
	for i in range(300):
		var m := Match.new()
		var d := Director.new()
		m.start(c, 600 + i)
		d.attach(m)
		m.begin_day()
		for t: Director.JobTask in d.plan_jobs(90):
			var who := m.get_villager(t.vid)
			if t.sabotage:
				sab += 1
				if not who.is_upyr or t.real:
					wrong = true
			if who.is_upyr and not t.real:
				fake_upyr += 1
	print("саботаж: %d из %d пустых работ упырей" % [sab, fake_upyr])
	ok += _expect(fails, not wrong, "портит человек или тот, кто работает по-настоящему")
	ok += _expect(fails, absf(float(sab) / maxf(1, fake_upyr) - Director.SABOTAGE_P) < 0.1, "упыри портят в %d из %d случаев" % [sab, fake_upyr])

	# 3. Испорченное видят все; кто это был — иногда видит сосед, это улика
	var seen := 0
	var sys_ok := true
	var md := Match.new()
	var dd := Director.new()
	md.start(c, 9)
	dd.attach(md)
	md.begin_day()
	var upyr: Villager = null
	for b: Villager in md.alive_bots():
		if b.is_upyr:
			upyr = b
	for k in range(200):
		md.do_job(md.player(), w, true)
		var spoiled := md.sabotage(w)
		var lines := dd.after_sabotage(upyr.id, w, spoiled)
		if lines.is_empty() or lines[0].speaker != null or not lines[0].text.contains(md.jobs[w].place):
			sys_ok = false
		if lines.size() > 1:
			seen += 1
	ok += _expect(fails, sys_ok, "испорченное не видно всем: нет строки с местом")
	ok += _expect(fails, seen > 20 and seen < 160, "соседи замечают саботаж в %d из 200 случаев" % seen)
	ok += _expect(fails, dd.badges(upyr.id).has("sabotage") and dd.evidence_text(upyr).contains("испорченного"), "у замеченного нет улики")

	# 4. На поле: бот-упырь испортил — «−1» над делом, запасы меньше
	Save.set_difficulty("normal")
	var v := Nav.village
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _settle(tree)
	var m := Game.m
	var day := Nav.host.current as DayScreen
	var ji := m.job_index(&"water")
	m.do_job(m.player(), ji, true)
	var bad: Villager = m.alive_bots()[0]
	for b: Villager in m.alive_bots():
		if b.is_upyr:
			bad = b
	var t := Director.JobTask.new()
	t.vid = bad.id
	t.job = ji
	t.start = Game.day_t
	t.real = false
	t.sabotage = true
	var only: Array[Director.JobTask] = [t]
	Game.tasks = only
	await _frames(tree, 3)
	Sfx.played.clear()
	t.start = Game.day_t - Director.WORK_SEC - 0.1
	await _frames(tree, 3)
	var popped := false
	for p: Dictionary in v.jobs_layer._pops:
		if p.text == "−1":
			popped = true
	ok += _expect(fails, m.supply_done == 0 and popped and Sfx.played.has(&"job_fail"), "на поле не видно, что дело испортили")
	ok += _expect(fails, day.supplies.text() == "Запасы 0 из %d" % m.supply_total, "капсула запасов не обновилась")

	# 5. Игрок-упырь: у сделанного дела выбор «работать или испортить»; человек выбора не видит
	m.do_job(m.player(), ji, true)
	var was_upyr := m.player().is_upyr
	m.player().is_upyr = false
	await _frames(tree, 2)
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.jobs_layer.icon_rect_global(ji).get_center()}, day)
	await _frames(tree, 3)
	ok += _expect(fails, _sheet(day) == null and Game.player_job == ji, "человеку предложили испортить дело")
	Game.cancel_player_job()
	m.player().is_upyr = true
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.jobs_layer.icon_rect_global(ji).get_center()}, day)
	await _frames(tree, 3)
	var sh := _sheet(day)
	ok += _expect(fails, sh != null, "упырю не предложили испортить дело")
	if sh != null:
		var done0 := m.supply_done
		sh.close(1)
		await _frames(tree, 4)
		ok += _expect(fails, Game.player_job == ji and Game.player_sab, "упырь не пошёл портить")
		var guard := 0.0
		while Game.player_job >= 0 and guard < 8.0:
			await tree.create_timer(0.1).timeout
			guard += 0.1
		await _frames(tree, 2)
		ok += _expect(fails, m.supply_done == done0 - 1, "игрок-упырь ничего не испортил (запасы %d, было %d)" % [m.supply_done, done0])
	m.player().is_upyr = was_upyr
	Nav.show_menu()
	await _settle(tree)

	_finish(fails, ok, "саботаж", "упыри портят сделанное, все видят, сосед иногда замечает, игрок-упырь тоже может")


# =============================================================
# Ящик (Task 29): со второго дня днём на площади появляется ящик. Кто первым откроет,
# тому находка. Записка честная: один из двоих — упырь. Упырь-бот врёт о ней.
# =============================================================
static func box() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig

	# 1. Когда бывает и что внутри
	var day1 := 0
	var day2 := 0
	var loot: Dictionary[int, int] = {}
	var note_ok := true
	var supply_ok := true
	for i in range(400):
		var m := Match.new()
		m.start(c, 1500 + i)
		m.begin_day()
		if m.box_today:
			day1 += 1
		m.day = 2
		m.phase = Match.Phase.MORNING
		m.begin_day()
		if not m.box_today:
			continue
		day2 += 1
		var total := m.supply_total
		var ji := m.place_box()
		if ji < 0 or m.jobs[ji].kind != JobDef.Kind.BOX or m.supply_total != total or m.place_box() != ji:
			supply_ok = false
		var opener: Villager = m.alive_bots()[0]
		var before := m.supply_done
		var res := m.open_box(opener)
		loot[int(res.loot)] = loot.get(int(res.loot), 0) + 1
		if not m.open_box(m.alive_bots()[1]).is_empty() or m.box_opened_by != opener.id:
			note_ok = false
		match int(res.loot):
			Match.Loot.NOTE:
				var a: Villager = res.a
				var b: Villager = res.b
				if a == opener or b == opener or a.is_upyr == b.is_upyr:
					note_ok = false
			Match.Loot.OIL:
				if m.supply_done != mini(m.supply_total, before + Match.BOX_OIL):
					supply_ok = false
	print("ящик: в первый день %d, во второй %d из 400; находки %s" % [day1, day2, loot])
	ok += _expect(fails, day1 == 0, "ящик в первый день")
	ok += _expect(fails, absf(day2 / 400.0 - Match.BOX_P) < 0.08, "ящик во второй день %d из 400, ждём около 60%%" % day2)
	ok += _expect(fails, loot.size() == 3, "бывают не все находки: %s" % loot)
	ok += _expect(fails, note_ok, "записка не честная или ящик открыли дважды")
	ok += _expect(fails, supply_ok, "ящик меняет план запасов или масло не прибавило запасов")

	# 2. Что говорит бот: человек — правду, упырь — называет двух людей
	var mm := Match.new()
	var dm := Director.new()
	mm.start(c, 5)
	dm.attach(mm)
	mm.begin_day()
	var human: Villager = null
	var upyr: Villager = null
	for b: Villager in mm.alive_bots():
		if b.is_upyr and upyr == null:
			upyr = b
		if not b.is_upyr and human == null:
			human = b
	var hl := dm.after_box(human.id, {"loot": Match.Loot.NOTE, "a": upyr, "b": human})
	ok += _expect(fails, hl.size() == 1 and hl[0].text.contains(upyr.name), "человек не рассказал, что в записке")
	var lie_ok := true
	for k in range(30):
		var ul := dm.after_box(upyr.id, {"loot": Match.Loot.NOTE, "a": human, "b": upyr})
		for b: Villager in mm.villagers:
			if b.is_upyr and ul[0].text.contains("«%s " % b.name) or b.is_upyr and ul[0].text.contains(" %s»" % b.name):
				lie_ok = false
	ok += _expect(fails, lie_ok, "упырь честно пересказал записку")
	ok += _expect(fails, dm.after_box(0, {"loot": Match.Loot.NOTE, "a": human, "b": upyr}).is_empty(), "за игрока рассказали, что в записке")

	# 3. На поле: ящик появился, игрок успел первым и прочитал записку
	Save.set_difficulty("normal")
	var v := Nav.village
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _settle(tree)
	var m := Game.m
	var day := Nav.host.current as DayScreen
	m.box_today = true
	m.box_pos = v.def.box_spots[0]
	m.box_loot = Match.Loot.NOTE
	Game.tasks.clear()
	Sfx.played.clear()
	Game.box_at = Game.day_t + 0.05
	await tree.create_timer(0.3).timeout
	var bj := m.job_index(&"box")
	ok += _expect(fails, bj >= 0 and v.jobs_layer.icon_rect_global(bj).size.x >= 84.0, "ящик не появился на поле")
	var announced := false
	for l: ChatLine in m.chat:
		if l.text.contains("ящик"):
			announced = true
	ok += _expect(fails, announced and Sfx.played.has(&"knock"), "о ящике не сказано или не слышно")
	var runner := -1
	for t: Director.JobTask in Game.tasks:
		if t.job == bj:
			runner = t.vid
	ok += _expect(fails, runner > 0, "за ящиком не пошёл ни один бот")
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": v.jobs_layer.icon_rect_global(bj).get_center()}, day)
	await _frames(tree, 3)
	ok += _expect(fails, Game.player_job == bj, "тап по ящику не поставил игрока его открывать")
	var guard := 0.0
	while Game.player_job >= 0 and guard < 6.0:
		await tree.create_timer(0.1).timeout
		guard += 0.1
	await _frames(tree, 2)
	var note_line := ""
	for l: ChatLine in m.chat:
		if l.text.begins_with("В ящике записка"):
			note_line = l.text
	ok += _expect(fails, m.box_opened_by == 0 and note_line.contains("видишь только ты"), "игрок открыл ящик, но не увидел записку")
	# бот добежал позже — ящик уже пуст, ничего не говорит
	var said := m.chat.size()
	for t: Director.JobTask in Game.tasks:
		if t.job == bj:
			t.start = Game.day_t - Director.WORK_SEC - 0.1
	await _frames(tree, 4)
	ok += _expect(fails, m.chat.size() == said, "бот рассказал про ящик, который уже открыли")
	Nav.show_menu()
	await _settle(tree)

	_finish(fails, ok, "ящик", "появляется со второго дня, первый открывший получает находку, записка честная")



# =============================================================
# Роли (Task 31): старожил, знахарь, староста.
# =============================================================
static func roles() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig

	# 1. Раздача: каждая роль ровно у одного человека, у упырей ролей нет, игроку тоже достаются
	var deal_ok := true
	var player_roles := 0
	for i in range(200):
		var m := Match.new()
		m.start(c, 50 + i)
		var count := {}
		for v: Villager in m.villagers:
			if v.role != Match.Role.NONE:
				count[v.role] = count.get(v.role, 0) + 1
				if v.is_upyr:
					deal_ok = false
		if count.size() != 3 or count.values().any(func(x: int) -> bool: return x != 1):
			deal_ok = false
		if m.player().role != Match.Role.NONE:
			player_roles += 1
	ok += _expect(fails, deal_ok, "роли розданы неверно: не по одной или достались упырю")
	ok += _expect(fails, player_roles > 40, "игроку почти не достаются роли (%d из 200)" % player_roles)

	# 2. Старожил: правда, один раз, только днём, только сам старожил
	var me := Match.new()
	me.start(c, 7)
	me.begin_day()
	var elder := me.role_holder(Match.Role.ELDER)
	var upyr: Villager = null
	var other: Villager = null
	for v: Villager in me.villagers:
		if v.is_upyr and upyr == null:
			upyr = v
		if not v.is_upyr and v != elder and other == null:
			other = v
	ok += _expect(fails, me.elder_check(other, upyr) == -1, "смотреть рисунки может не старожил")
	ok += _expect(fails, me.elder_check(elder, upyr) == 1 and elder.role_used, "старожил не узнал упыря")
	ok += _expect(fails, me.elder_check(elder, other) == -1, "старожил смотрит рисунки второй раз")

	# 3. Знахарь: взял травы — того, на кого напали рядом, выходил. Себя — нет.
	var c3 := c.duplicate() as GameConfig
	c3.capacity = 3
	var saved := 0
	var died_healed := 0
	var died_plain := 0
	for i in range(200):
		for heal: bool in [true, false]:
			var m := Match.new()
			m.start(c3, 3000 + i)
			m.begin_day()
			m.end_day()
			var h := m.role_holder(Match.Role.HEALER)
			var x: Villager = null
			var u: Villager = null
			for v: Villager in m.villagers:
				if v.is_upyr and u == null:
					u = v
				if not v.is_upyr and v != h and x == null:
					x = v
			var ch: Dictionary[int, int] = {}
			var arr: Dictionary[int, float] = {}
			for v: Villager in m.alive():
				ch[v.id] = 1
			for v: Villager in [h, x, u]:
				ch[v.id] = 0
			arr[h.id] = 0.0
			arr[x.id] = 1.0
			arr[u.id] = 2.0
			m.seat_night(ch, arr)
			for s: Match.Seat in m.seats:
				var ids: Array[int] = []
				for v: Villager in s.queue:
					ids.append(v.id)
				m.admit(s, ids)
			if heal:
				m.heal_tonight(h)
			var r := m.resolve_night()
			for e: NightReport.Entry in r.entries:
				if e.house != 0:
					continue
				if e.kind == NightReport.Kind.SAVED and e.who == x and e.cause == "upyr" and e.others[0] == h:
					saved += 1
				if e.kind == NightReport.Kind.KILLED_INSIDE and e.who == x:
					if heal:
						died_healed += 1
					else:
						died_plain += 1
	print("знахарь: выходил %d, погибли рядом с травами %d, без трав %d" % [saved, died_healed, died_plain])
	ok += _expect(fails, saved > 40 and died_healed == 0, "знахарь с травами не спасает соседа (спас %d, погибли %d)" % [saved, died_healed])
	ok += _expect(fails, died_plain > 40, "без трав сосед не погибает — проверка слепая")

	# 4. Староста: голос за двоих
	var hm := me.role_holder(Match.Role.HEADMAN)
	ok += _expect(fails, me.vote_weight(hm.id) == 2 and me.vote_weight(other.id if other != hm else upyr.id) == 1, "голос старосты не за двоих")

	# 5. Боты: настоящий старожил говорит правду, упырь называется старожилом и топит человека
	var real_ok := true
	var reals := 0
	var fakes := 0
	for i in range(300):
		var m := Match.new()
		var d := Director.new()
		m.start(c, 9000 + i)
		d.attach(m)
		m.begin_day()
		m.day = 2
		d.plan_day()
		for vid: int in m.claims:
			var who := m.get_villager(vid)
			if not m.claim_elder.has(vid):
				continue
			var text: String = m.claims[vid]
			if who.is_upyr:
				fakes += 1
			elif who.role == Match.Role.ELDER:
				reals += 1
				for t: Villager in m.villagers:
					if text.contains(": %s — " % t.name) and (text.ends_with("упырь") != t.is_upyr):
						real_ok = false
	print("старожилы: настоящих заявлений %d, ложных %d из 300 партий" % [reals, fakes])
	ok += _expect(fails, reals > 150 and real_ok, "старожил-бот молчит или врёт (%d)" % reals)
	ok += _expect(fails, fakes > 60, "упыри не называются старожилами (%d)" % fakes)

	# 6. Экран: роль в прологе, рисунки в шторке, травы ночью, староста на голосовании
	Save.set_difficulty("normal")
	Nav.start_match()
	await _settle(tree)
	var m := Game.m
	var you := m.player()
	you.is_upyr = false
	for v: Villager in m.villagers:
		if v.role == Match.Role.ELDER:
			v.role = Match.Role.NONE
	you.role = Match.Role.ELDER
	you.role_used = false
	Nav.show(PrologueScreen.new())
	await _settle(tree)
	ok += _expect(fails, _all_text(Nav.host.current).contains("Ты старожил"), "в прологе не сказано про роль")
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	var day := Nav.host.current as DayScreen
	var target: Villager = m.alive_bots()[0]
	day.person_actions(target)
	await _frames(tree, 3)
	var sh := _sheet(day)
	ok += _expect(fails, sh != null and _all_text(sh).contains("рисунки"), "в шторке жителя нет рисунков старожила")
	if sh != null:
		sh.close(3)
		await _frames(tree, 3)
	var seen := ""
	for l: ChatLine in m.chat:
		if l.text.begins_with("Рисунки старожила"):
			seen = l.text
	ok += _expect(fails, seen.contains(target.name) and seen.contains("упырь" if target.is_upyr else "человек") and you.role_used, "старожил не увидел правду: «%s»" % seen)
	day.person_actions(target)
	await _frames(tree, 3)
	sh = _sheet(day)
	ok += _expect(fails, sh != null and not _all_text(sh).contains("рисунки"), "рисунки можно смотреть второй раз")
	if sh != null:
		sh.close(-1)
		await _frames(tree, 2)
	# знахарь ночью
	you.role = Match.Role.HEALER
	you.role_used = false
	Save.mark_hint("night")
	Game.end_day()
	await _settle(tree)
	if m.phase == Match.Phase.VOTE:
		Game.vote(-1)
		await _settle(tree)
		Game.proceed()
		await _settle(tree)
	var ns := Nav.host.current as NightScreen
	ok += _expect(fails, ns != null and ns.heal_button != null, "у знахаря ночью нет кнопки трав")
	if ns != null and ns.heal_button != null:
		ns.heal_button.pressed.emit()
		await _frames(tree, 2)
		ok += _expect(fails, m.healer_on.get(0, false) and ns.heal_button.disabled, "травы не взяты")
	# староста на голосовании
	Nav.show_menu()
	await _settle(tree)
	Nav.start_match()
	await _settle(tree)
	m = Game.m
	for v: Villager in m.villagers:
		if v.role == Match.Role.HEADMAN:
			v.role = Match.Role.NONE
	m.player().is_upyr = false
	m.player().role = Match.Role.HEADMAN
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	m.day = 2
	Game.end_day()
	await _settle(tree)
	ok += _expect(fails, m.phase == Match.Phase.VOTE and _all_text(Nav.host.current).contains("голос считается за двоих"), "на голосовании не сказано, что голос старосты за двоих")
	if m.phase == Match.Phase.VOTE:
		var tgt: Villager = m.alive_bots()[0]
		var got := {}
		Game.vote_resolved.connect(func(t: Dictionary, _e: Villager) -> void: got.merge(t), CONNECT_ONE_SHOT)
		var voters := m.alive_bots().size()
		Game.vote(tgt.id)
		await _frames(tree, 2)
		var total := 0
		for k: Variant in got:
			total += int(got[k])
		# у ботов голос за одного, у игрока-старосты за двоих
		ok += _expect(fails, total == voters + 2, "голос старосты не за двоих: всего голосов %d при %d ботах" % [total, voters])
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "роли", "старожил видит правду, знахарь спасает, староста голосует за двоих, боты пользуются ролями")


# =============================================================
# Экстренный сбор (Task 32): раз за партию ударить в колокол днём — сразу голосование.
# =============================================================
static func meeting() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig

	# 1. Правила
	var m0 := Match.new()
	m0.start(c, 11)
	m0.begin_day()
	var b0: Villager = m0.alive_bots()[0]
	ok += _expect(fails, not m0.vote_open() and m0.call_meeting(b0) and m0.phase == Match.Phase.VOTE and m0.meeting_by == b0.id, "сбор в первый день не открыл голосование")
	var none: Dictionary[int, int] = {}
	m0.apply_vote(none)
	m0.after_vote()
	if m0.phase == Match.Phase.NIGHT:
		var d0 := Director.new()
		d0.attach(m0)
		_rules_seat(m0, d0)
		for s: Match.Seat in m0.seats:
			var ids: Array[int] = []
			m0.admit(s, ids)
		m0.resolve_night()
		m0.end_morning()
	ok += _expect(fails, m0.phase != Match.Phase.DAY or (m0.meeting_by == -1 and not m0.can_meeting(b0)), "второй сбор от того же жителя или сбор не сбросился за ночь")

	# 2. Боты бьют в колокол, когда кого-то сильно подозревают и голосования иначе не будет
	var called := 0
	var silent := 0
	for i in range(200):
		var m := Match.new()
		var d := Director.new()
		m.start(c, 400 + i)
		d.attach(m)
		m.begin_day()
		if d.meeting_caller() != null:
			silent += 1
		d.public_susp[m.alive_bots()[1].id] = Director.MEETING_SUSP + 0.5
		var who := d.meeting_caller()
		if who != null:
			called += 1
			if who == m.alive_bots()[1]:
				silent += 1000
	print("сбор ботов: при подозрении %d из 200, без подозрения %d" % [called, silent])
	ok += _expect(fails, silent == 0, "боты бьют в колокол без причины или зовёт сам подозреваемый")
	ok += _expect(fails, absf(called / 200.0 - Director.MEETING_P) < 0.1, "боты бьют в колокол в %d из 200 случаев" % called)

	# 3. Игрок: кнопка «Сбор!», подтверждение, голосование в первый день
	Save.set_difficulty("normal")
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _settle(tree)
	var m := Game.m
	var day := Nav.host.current as DayScreen
	var btn := _find_button(day, "Сбор")
	ok += _expect(fails, btn != null, "на экране дня нет кнопки «Сбор!»")
	if btn != null:
		btn.pressed.emit()
		await _frames(tree, 3)
		var sh := _sheet(day)
		ok += _expect(fails, sh != null, "сбор без подтверждения")
		if sh != null:
			sh.close(0)
			await _settle(tree)
	ok += _expect(fails, m.phase == Match.Phase.VOTE and m.day == 1 and _all_text(Nav.host.current).contains("Экстренный сбор"), "сбор игрока не открыл голосование в первый день")
	if m.phase == Match.Phase.VOTE:
		Game.vote(-1)
		await _settle(tree)
		Game.proceed()
		await _settle(tree)

	# 4. Бот бьёт в колокол прямо в игре
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _settle(tree)
	m = Game.m
	Game.director.public_susp[m.alive_bots()[0].id] = 5.0
	var caller: Villager = null
	for k in range(20):
		Game.meeting_check_at = Game.day_t
		await _frames(tree, 2)
		if m.phase == Match.Phase.VOTE:
			caller = m.get_villager(m.meeting_by)
			break
	ok += _expect(fails, caller != null and not caller.is_player, "бот не ударил в колокол, хотя подозрение сильное")
	var line_ok := false
	for l: ChatLine in m.chat:
		if l.text.contains("бьёт в колокол"):
			line_ok = true
	ok += _expect(fails, line_ok, "в журнале не сказано, кто ударил в колокол")
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "экстренный сбор", "колокол днём: раз за партию, сразу голосование, боты бьют, когда есть кого подозревать")


# =============================================================
# Туннель (Task 33): ход между двумя убежищами. Не пустили — можно пролезть на другой конец.
# =============================================================
static func tunnel() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	var c := (load("res://config/balance_10.tres") as GameConfig).duplicate() as GameConfig

	# 1. Где туннель
	var pair_ok := true
	for i in range(100):
		var m := Match.new()
		m.start(c, 70 + i)
		var t := m.tunnel
		if t.x < 0 or t.x == t.y or t.y >= m.houses.size() or m.tunnel_to(t.x) != t.y or m.tunnel_to(t.y) != t.x:
			pair_ok = false
		for h in range(m.houses.size()):
			if h != t.x and h != t.y and m.tunnel_to(h) != -1:
				pair_ok = false
	ok += _expect(fails, pair_ok, "туннель не между двумя разными убежищами")

	# 2. Кого не пустили у дома с туннелем — лезут; упыри охотнее; место на том конце соблюдается
	var hum_try := 0
	var hum_go := 0
	var up_try := 0
	var up_go := 0
	var cap_ok := true
	var report_ok := true
	for i in range(500):
		var m := Match.new()
		m.start(c, 5000 + i)
		m.begin_day()
		m.end_day()
		m.tunnel = Vector2i(0, 1)
		var ch: Dictionary[int, int] = {}
		for v: Villager in m.alive():
			ch[v.id] = 2
		var al := m.alive()
		ch[al[1].id] = 0
		ch[al[2].id] = 0      # к дому 0 двое: хозяин и тот, кого не пустят
		ch[al[3].id] = 1      # в доме 1 один — места есть
		m.seat_night(ch)
		for s: Match.Seat in m.seats:
			var ids: Array[int] = []
			if s.house == 2:
				for v: Villager in s.queue:
					ids.append(v.id)
			m.admit(s, ids)
		var out_v: Villager = null
		for s: Match.Seat in m.seats:
			if s.house == 0 and not s.queue.is_empty():
				out_v = s.queue[0]
		m.tunnel_pass(false)
		var went := m.tunnel_log.size() == 1
		if out_v.is_upyr:
			up_try += 1
			up_go += 1 if went else 0
		else:
			hum_try += 1
			hum_go += 1 if went else 0
		for s: Match.Seat in m.seats:
			if s.inside().size() > m.config.capacity:
				cap_ok = false
			if went and s.house == 0 and s.queue.has(out_v):
				cap_ok = false
		var r := m.resolve_night()
		var n := 0
		for e: NightReport.Entry in r.entries:
			if e.kind == NightReport.Kind.TUNNEL and e.who == out_v and e.house == 1 and e.said_house == 0:
				n += 1
		if n != (1 if went else 0):
			report_ok = false
	print("туннель: люди %d из %d, упыри %d из %d" % [hum_go, hum_try, up_go, up_try])
	ok += _expect(fails, absf(float(hum_go) / maxf(1, hum_try) - Match.TUNNEL_HUMAN) < 0.1 and absf(float(up_go) / maxf(1, up_try) - Match.TUNNEL_UPYR) < 0.12, "в туннель лезут не так: люди %d/%d, упыри %d/%d" % [hum_go, hum_try, up_go, up_try])
	ok += _expect(fails, cap_ok, "туннель переполнил дом или пролезший остался в очереди")
	# на том конце мест нет — никто не лезет
	var crowded := 0
	for i in range(100):
		var m := Match.new()
		m.start(c, 8000 + i)
		m.begin_day()
		m.end_day()
		m.tunnel = Vector2i(0, 1)
		var ch: Dictionary[int, int] = {}
		for v: Villager in m.alive():
			ch[v.id] = 2
		var al := m.alive()
		ch[al[1].id] = 0
		ch[al[2].id] = 0
		ch[al[3].id] = 1
		ch[al[4].id] = 1      # в доме 1 хозяин и гость — дом полон
		m.seat_night(ch)
		for s: Match.Seat in m.seats:
			var ids: Array[int] = []
			if s.house != 0:
				for v: Villager in s.queue:
					ids.append(v.id)
			m.admit(s, ids)
		m.tunnel_pass(true)
		crowded += m.tunnel_log.size()
	ok += _expect(fails, crowded == 0, "пролезли туннелем в полный дом (%d раз)" % crowded)
	ok += _expect(fails, report_ok, "утром не сказано, кто пролез туннелем")

	# 3. На поле и в списке ночью видно туннель
	Save.set_difficulty("normal")
	var v := Nav.village
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	var m := Game.m
	m.tunnel = Vector2i(0, 1)
	Save.mark_hint("night")
	m.config.vote_from_day = 9
	Game.end_day()
	await _settle(tree)
	var vp := Nav.frame.get_viewport_rect().size
	var hp := v.to_global(v.hatch_pos(0))
	ok += _expect(fails, v.tunnel == m.tunnel and hp.x > 0 and hp.x < vp.x and hp.y > 0 and hp.y < vp.y, "люка туннеля не видно на поле")
	ok += _expect(fails, _all_text(Nav.host.current).contains("туннель в «%s»" % m.houses[1]), "в списке домов не сказано про туннель")

	# 4. Игрока не пустили — он лезет туннелем
	Game.choose_house(0)
	await _settle(tree)
	if m.phase == Match.Phase.DOOR:
		var bots := m.alive_bots()
		var a := Match.Seat.new()
		a.house = 0
		a.host = bots[0]
		a.queue = [m.player()] as Array[Villager]
		var b := Match.Seat.new()
		b.house = 1
		b.host = bots[1]
		m.seats = [a, b] as Array[Match.Seat]
		var none: Array[int] = []
		m.admit(a, none)
		m.admit(b, none)
		m.player().night_house = 0
		var gs := DoorScreen.new()
		gs.role = Match.DoorRole.GUEST
		gs.seat = a
		Nav.show(gs)
		await _settle(tree)
		gs.show_guest_result(false)
		for k in range(40):
			if gs.result_shown:
				break
			await tree.process_frame
		var hole := _find_button(gs, "Лезть туннелем")
		ok += _expect(fails, hole != null, "после отказа нет кнопки «Лезть в туннель»")
		if hole != null:
			hole.pressed.emit()
			await _settle(tree)
			ok += _expect(fails, m.player().night_house == 1 and b.admitted.has(m.player()), "игрок не пролез туннелем")
			ok += _expect(fails, m.phase == Match.Phase.MORNING or m.phase == Match.Phase.OVER, "после туннеля ночь не прошла")
			if m.phase == Match.Phase.MORNING:
				await tree.create_timer(0.3).timeout
				await _settle(tree)
				ok += _expect(fails, _all_text(Nav.host.current).contains("туннелем"), "утром не сказано про туннель")
	else:
		fails.append("не дошли до двери (%s)" % Match.Phase.keys()[m.phase])
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "туннель", "ход между домами: не пустили — лезешь, упыри охотнее, утром все знают")


# =============================================================
# Дневник (Task 34): всё о каждом жителе в одном месте.
# =============================================================
static func diary() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig

	# 1. Строки дневника по правилам: где ночевал, что говорил, кто погиб, улики, заявления
	var m0 := Match.new()
	var d0 := Director.new()
	m0.start(c, 21)
	d0.attach(m0)
	m0.begin_day()
	var bots := m0.alive_bots()
	var liar: Villager = bots[0]
	liar.announced_house = 1
	m0.end_day()
	var ch: Dictionary[int, int] = {}
	for v: Villager in m0.alive():
		ch[v.id] = 0
	m0.seat_night(ch)
	for s: Match.Seat in m0.seats:
		var none: Array[int] = []
		m0.admit(s, none)
	var r := m0.resolve_night()
	d0.read_report(r)
	var f := "\n".join(DiarySheet.facts(m0, d0, liar))
	var where := "улица" if liar.night_house < 0 else m0.house_name(liar.night_house)
	ok += _expect(fails, f.contains("Ночи: 1 — %s" % where), "в дневнике нет, где житель ночевал: «%s»" % f)
	ok += _expect(fails, f.contains("говорил") and f.contains(m0.house_name(1)), "в дневнике не видно, что житель говорил одно, а ночевал в другом: «%s»" % f)
	var dead_ok := true
	for e: NightReport.Entry in r.deaths():
		if not e.who.is_player and not "\n".join(DiarySheet.facts(m0, d0, e.who)).contains("в ночь 1"):
			dead_ok = false
	ok += _expect(fails, dead_ok, "в дневнике не сказано, кто погиб и когда")
	var ev_ok := true
	for v: Villager in bots:
		var et := d0.evidence_text(v)
		if not et.is_empty() and not "\n".join(DiarySheet.facts(m0, d0, v)).contains(et):
			ev_ok = false
	ok += _expect(fails, ev_ok, "улики не попали в дневник")
	m0.claim(bots[1], bots[0], "назвал себя старожилом: Рита — упырь", true)
	m0.player_seen[bots[2].id] = 1
	ok += _expect(fails, "\n".join(DiarySheet.facts(m0, d0, bots[1])).contains("Назвал себя старожилом"), "заявление не попало в дневник")
	var rita := m0.get_villager(bots[3].id)
	m0.claim(bots[1], rita, "назвал себя старожилом: %s — упырь" % rita.name, true)
	ok += _expect(fails, "\n".join(DiarySheet.facts(m0, d0, rita)).contains("%s назвал себя старожилом" % bots[1].name), "в карточке обвинённого не видно, кто его назвал")
	ok += _expect(fails, "\n".join(DiarySheet.facts(m0, d0, bots[2])).contains("Твои рисунки: упырь"), "твои рисунки не попали в дневник")

	# знание жителей и обещания (TASK-003, TASK-004)
	ok += PlanTests.knowledge_and_promises(fails)
	ok += PlanTests.behaviour(fails)
	ok += PlanTests.group_four(fails)

	# 2. Экран: кнопка «Дневник», карточка на каждого, всё в кадре, закрывается
	Save.set_difficulty("normal")
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	var m := Game.m
	var day := Nav.host.current as DayScreen
	var btn := _find_button(day, "Дневник")
	ok += _expect(fails, btn != null, "на экране дня нет кнопки «Дневник»")
	if btn != null:
		btn.pressed.emit()
		await _frames(tree, 4)
		var ds: DiarySheet = null
		for ch2: Node in day.get_children():
			if ch2 is DiarySheet:
				ds = ch2
		ok += _expect(fails, ds != null and ds.cards.size() == m.villagers.size() - 1, "в дневнике не все жители")
		if ds != null:
			var vp := Nav.frame.get_viewport_rect().size
			var inside := true
			for card: Control in ds.cards.values():
				var cr := card.get_global_rect()
				if cr.position.x < -1.0 or cr.end.x > vp.x + 1.0:
					inside = false
			ok += _expect(fails, inside, "карточки дневника вылезают за экран")
			ds.close()
			await _frames(tree, 2)
	# обещание из карточки жителя (TASK-004): пункт в шторке, фраза игрока, ответ жителя
	var pt: Villager = m.alive_bots()[0]
	day.person_actions(pt)
	await _frames(tree, 3)
	var psh := _sheet(day)
	ok += _expect(fails, psh != null and _all_text(psh).contains(L.t("day.p_promise")), "в шторке жителя нет обещания")
	if psh != null:
		psh.close(-1)
		await _frames(tree, 2)
	day.promise_actions(pt)
	await _frames(tree, 3)
	psh = _sheet(day)
	ok += _expect(fails, psh != null and _all_text(psh).contains(L.t("day.promise_open", {"who": pt})), "нет выбора, что пообещать")
	if psh != null:
		psh.close(0)
		await _frames(tree, 3)
	ok += _expect(fails, not m.promises_today(0, pt.id).is_empty(), "обещание из шторки не записалось")
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "дневник", "где ночевал, что говорил, улики, заявления и твои рисунки — в одном месте")



# =============================================================
# Разбор партии (Task 38): почему ты погиб, что решило партию, лента по ночам.
# =============================================================
static func recap() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	# память кампании и откровения (TASK-002, TASK-005)
	ok += PlanTests.campaign_memory(fails)
	ok += PlanTests.revelations(fails)
	ok += PlanTests.feelings_and_bonds(fails)
	ok += await PlanTests.chapter_one(tree, fails)
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig

	# 1. Причина гибели игрока — по-настоящему из партий, каждого вида
	var kinds: Dictionary = {}
	var why_ok := true
	var bad := ""
	for g in range(600):
		var m := Match.new()
		var d := Director.new()
		m.start(c, 20000 + g)
		d.attach(m)
		m.begin_day()
		while m.phase != Match.Phase.OVER and m.player().alive:
			match m.phase:
				Match.Phase.DAY:
					d.plan_day()
					d.run_jobs_instant(d.plan_jobs(90))
					m.end_day()
				Match.Phase.VOTE:
					var none: Dictionary[int, int] = {}
					m.apply_vote(none)
					m.after_vote()
				Match.Phase.NIGHT:
					_rules_seat(m, d)
				Match.Phase.DOOR:
					for s: Match.Seat in m.seats:
						var ids: Array[int] = []
						if s.host.is_player:
							for v: Villager in s.knockers():
								ids.append(v.id)
						else:
							ids = d.host_decide(s, "beg")
						m.admit(s, ids)
					m.tunnel_pass(false)
					d.after_door(m.seats)
					d.read_report(m.resolve_night())
				Match.Phase.MORNING:
					m.end_morning()
		var e := m.player_death
		if e == null:
			continue
		kinds[e.kind] = kinds.get(e.kind, 0) + 1
		var t := "\n".join(Recap.death_lines(m, e, m.report))
		var good := true
		match e.kind:
			NightReport.Kind.KILLED_INSIDE:
				good = e.killer != null and e.killer.is_upyr and t.contains(e.killer.name) and t.contains("упыр")
			NightReport.Kind.KILLED_STREET:
				good = t.contains(m.house_name(e.house)) and t.contains("%")
			NightReport.Kind.KILLED_ALONE:
				good = t.contains("один")
			NightReport.Kind.KILLED_CREATURE:
				good = t.contains("Оберег") and t.contains("подправить")
			NightReport.Kind.KILLED_MIMIC:
				good = t.contains("Подражатель") and t.contains(_ru_case("gen", e.voice.name))
		if not good:
			why_ok = false
			bad = "%s: «%s»" % [NightReport.Kind.keys()[e.kind], t]
		if not Recap.verdict(m, d).begins_with("Ты погиб в ночь"):
			why_ok = false
			bad = "итог: «%s»" % Recap.verdict(m, d)
	print("гибель игрока по видам: %s" % kinds)
	ok += _expect(fails, kinds.size() >= 4, "в разборе встретились не все виды гибели: %s" % kinds)
	ok += _expect(fails, why_ok, "причина гибели объяснена неверно — %s" % bad)

	# 2. Что решило партию: впустил упыря, изгнал упыря, изгнал человека, изгнан сам, чистая партия
	var m2 := Match.new()
	m2.start(c, 33)
	var up: Villager = null
	var hu: Villager = null
	for v: Villager in m2.alive_bots():
		if v.is_upyr and up == null:
			up = v
		if not v.is_upyr and hu == null:
			hu = v
	m2.player().is_upyr = false
	ok += _expect(fails, Recap.verdict(m2, null).contains("ни разу не открыл"), "чистая партия без итога")
	up.exiled = true
	up.alive = false
	up.exiled_day = 2
	m2.player_votes.append({"day": 2, "who": up})
	ok += _expect(fails, Recap.verdict(m2, null).contains("помог изгнать упыря") and Recap.verdict(m2, null).contains(up.name), "не засчитан голос против упыря")
	m2.player_votes.clear()
	hu.exiled = true
	hu.alive = false
	hu.exiled_day = 2
	m2.player_votes.append({"day": 2, "who": hu})
	ok += _expect(fails, Recap.verdict(m2, null).contains("человеком") and Recap.verdict(m2, null).contains(_ru_case("gen", hu.name)), "не сказано, что изгнали человека")
	m2.player_admits.append({"day": 1, "who": up, "mimic": false})
	ok += _expect(fails, Recap.verdict(m2, null).contains("впустил") and Recap.verdict(m2, null).contains(_ru_case("acc", up.name)), "не сказано, что ты впустил упыря: «%s»" % Recap.verdict(m2, null))
	m2.player().exiled = true
	m2.player().alive = false
	m2.player().exiled_day = 3
	m2.vote_log.append({"day": 3, "votes": {hu.id: 0, up.id: 0}, "exiled": m2.player()})
	var ev := Recap.verdict(m2, null)
	ok += _expect(fails, ev.contains("изгнали в день 3") and ev.contains(up.name), "не сказано, кто голосовал против тебя: «%s»" % ev)

	# решения игрока записываются по ходу партии: кого впустил, за кого голосовал
	var m4 := _rules_to_night(77, 1, Match.Event.NONE)
	var ch4: Dictionary[int, int] = {}
	var arr4: Dictionary[int, float] = {}
	for v: Villager in m4.alive():
		ch4[v.id] = 0
		arr4[v.id] = 5.0
	arr4[0] = 0.0
	m4.seat_night(ch4, arr4)
	var guest: Villager = m4.seats[0].queue[0]
	var g_ids: Array[int] = [guest.id]
	m4.admit(m4.seats[0], g_ids)
	ok += _expect(fails, m4.player_admits.size() == 1 and m4.player_admits[0].who == guest, "не записано, кого впустил игрок")

	# 3. Лента: разделы по ночам и дням, строки без приставки
	var m3 := Match.new()
	m3.start(c, 5)
	m3.chron.assign([{"title": "Ночь 1", "text": "в «Сарае» ночевали Рита и Нина — все целы."}, {"title": "", "text": "оберег у «Сарая» треснул."},
		{"title": "День 2", "text": "посёлок изгнал Тимура."}, {"title": "Ночь 2", "text": "туман."}])
	var tl := Recap.timeline(m3)
	ok += _expect(fails, tl.size() == 3 and tl[0].title == "Ночь 1" and (tl[0].lines as PackedStringArray).size() == 2 and tl[1].title == "День 2"
		and String((tl[0].lines as PackedStringArray)[0]).begins_with("В «Сарае»"), "лента партии разбита неверно: %s" % [tl])

	# 4. Экраны: утро с «почему ты погиб», финал с итогом, ролями и лентой
	Save.set_difficulty("normal")
	Nav.start_match()
	await _settle(tree)
	var m := Game.m
	var r := NightReport.new()
	r.p_out = 0.9
	var e2 := r.add(NightReport.Kind.KILLED_STREET, m.player(), 0)
	e2.host = m.alive_bots()[0]
	m.player().alive = false
	m.report = r
	m.player_death = e2
	Nav.show(MorningScreen.new())
	await _settle(tree)
	var mt := _all_text(Nav.host.current)
	ok += _expect(fails, mt.contains("Почему ты погиб") and mt.contains(m.alive_bots()[0].name) and mt.contains("90%"), "утром не видно, почему ты погиб")
	m.winner = Match.Team.UPYRI
	m.chron.append({"title": "Ночь 1", "text": "проверка ленты."})
	Nav.show(EndScreen.new())
	await _settle(tree)
	var et := _all_text(Nav.host.current)
	var role_holder := m.role_holder(Match.Role.ELDER)
	ok += _expect(fails, et.contains("Что решило партию") and et.contains("Ты погиб в ночь"), "на финале нет итога партии")
	ok += _expect(fails, role_holder == null or et.contains("%s — человек, старожил" % role_holder.name), "на финале не видно ролей")
	ok += _expect(fails, et.contains("Ночь 1") and et.contains("Проверка ленты."), "на финале нет ленты по ночам")
	# 5. Голоса жителей (51): у каждого свой характер, банк большой, реплики не повторяются
	ok += _expect(fails, Voices.total() >= 200, "в банке голосов мало строк: %d" % Voices.total())
	var personas_ok := true
	var personas: Dictionary = {}
	for v: Villager in m.alive_bots():
		if v.persona < 0:
			personas_ok = false
		personas[v.persona] = true
	ok += _expect(fails, personas_ok and personas.size() >= 3, "жителям не назначены характеры: %s" % [personas.keys()])
	var dv := Director.new()
	dv.attach(m)
	var heard: Dictionary = {}
	var repeats := 0
	var talker: Villager = m.alive_bots()[0]
	var bank_size := Phrases.b("FILLER").size() + Voices.lines(talker.persona, "FILLER").size()
	for _i in range(mini(bank_size, 40)):
		var t := dv._say(talker, "FILLER").text
		if heard.has(t):
			repeats += 1
		heard[t] = true
	ok += _expect(fails, repeats == 0, "житель повторил реплику %d раз, пока банк не исчерпан" % repeats)
	var own_heard := false
	var own_pool := Voices.lines(talker.persona, "FILLER")
	for t: String in heard:
		for o: String in own_pool:
			if L.fill(o, {"me": talker, "player_name": m.player().name}) == t:
				own_heard = true
	ok += _expect(fails, own_heard, "житель ни разу не сказал своим голосом")

	# 6. Горе и месть (53): погибла жена на улице — муж в трауре, винит хозяина двери, не работает
	var mg := Match.new()
	mg.start(c, 77)
	var widow: Villager = null
	var lost_one: Villager = null
	for v: Villager in mg.alive_bots():
		var pv := mg.get_villager(v.partner_id) if v.partner_id >= 0 else null
		if pv != null and not pv.is_player and not v.is_upyr and widow == null:
			widow = v
			lost_one = pv
	var grief_ok := widow != null
	var revenge_ok := false
	var sad_ok := false
	var idle_ok := false
	var blamed: Villager = null
	if widow != null:
		for v: Villager in mg.alive_bots():
			if v != widow and v != lost_one and blamed == null:
				blamed = v
		var rg := NightReport.new()
		var eg := rg.add(NightReport.Kind.KILLED_STREET, lost_one, 0)
		eg.host = blamed
		# вдова стояла у той же двери и видела отказ сам(а): винить может (TASK-003)
		mg.world.add(WorldLog.Kind.REFUSE, mg.day, blamed.id, lost_one.id, 0, [blamed.id, lost_one.id, widow.id])
		lost_one.alive = false
		mg._apply_grief(rg)
		mg.report = rg
		grief_ok = widow.grief_for == lost_one.id and widow.grief_days == Match.GRIEF_DAYS \
			and widow.blame_id == blamed.id and not lost_one.last_words.is_empty()
		var dg := Director.new()
		dg.attach(mg)
		for line: ChatLine in dg.grief_lines():
			if line.speaker == widow and line.emotion == "sad" and line.text.contains(lost_one.name.left(maxi(3, lost_one.name.length() - 1))):
				sad_ok = true
			if line.speaker == widow and line.about == blamed:
				revenge_ok = true
		mg.begin_day()
		var workers := 0
		idle_ok = widow.grief_days > 0
		for jt: Director.JobTask in dg.plan_jobs(90):
			workers += 1
			if jt.vid == widow.id:
				idle_ok = false
		idle_ok = idle_ok and workers > 0
	ok += _expect(fails, grief_ok, "после гибели жены муж не в трауре или не винит хозяина двери")
	ok += _expect(fails, sad_ok, "в трауре житель не говорит о погибшей по имени")
	ok += _expect(fails, revenge_ok, "в трауре житель не обвиняет того, кто не открыл дверь")
	ok += _expect(fails, idle_ok, "в трауре житель всё равно идёт работать")

	# 7. Утро с потерей (54): карточка с портретом, последними словами и горем родных
	var victim: Villager = null
	for v: Villager in m.alive_bots():
		var pv := m.get_villager(v.partner_id) if v.partner_id >= 0 else null
		if pv != null and pv.alive and not pv.is_player:
			victim = v
	if victim == null:
		victim = m.alive_bots()[0]
	var rl := NightReport.new()
	var el := rl.add(NightReport.Kind.KILLED_STREET, victim, 0)
	el.host = m.alive_bots()[-1] if m.alive_bots()[-1] != victim else m.alive_bots()[0]
	victim.alive = false
	m.player().alive = true
	m.player_death = null
	m._apply_grief(rl)
	m.report = rl
	Nav.show(MorningScreen.new())
	await _settle(tree)
	var loss: Control = null
	for n: Node in Nav.host.current.find_children("Loss_*", "", true, false):
		loss = n as Control
	var portrait := loss.find_child("Portrait", true, false) as TextureRect if loss != null else null
	var lt := _all_text(loss) if loss != null else ""
	ok += _expect(fails, loss != null and loss.get_meta("loss", -1) == victim.id, "утром гибель жителя показана строкой без сцены потери")
	ok += _expect(fails, portrait != null and portrait.texture != null, "в сцене потери нет портрета")
	ok += _expect(fails, lt.contains(victim.name) and loss != null and loss.find_child("LastWords", true, false) != null, "в сцене потери нет имени или последних слов")
	var kin_ok := true
	for kin: Villager in m.mourners(victim):
		if loss.find_child("Mourner_%d" % kin.id, true, false) == null:
			kin_ok = false
	ok += _expect(fails, kin_ok, "в сцене потери не видно, как горюют близкие")
	ok += _expect(fails, MorningScreen.LOSS_HOLD >= 1.5, "сцену потери можно пролистнуть сразу")
	# 8. Дилеммы у двери (56): семь видов, цена выбора, итог в разборе
	var kinds_seen: Dictionary = {}
	var dl_ok := true
	for kind: String in ["couple", "refuser", "voted", "accuser", "grieving", "crowd", "oil"]:
		var md := Match.new()
		md.start(c, 900 + kinds_seen.size())
		md.day = 2
		md.phase = Match.Phase.DOOR
		var bots := md.alive_bots()
		var pair_a: Villager = null
		var pair_b: Villager = null
		for v: Villager in bots:
			if v.partner_id >= 0 and pair_a == null:
				pair_a = v
				pair_b = md.get_villager(v.partner_id)
		var loners: Array[Villager] = []
		for v: Villager in bots:
			if v.partner_id < 0 and v.family_id < 0:
				loners.append(v)
		var st := Match.Seat.new()
		st.host = md.player()
		st.house = 0
		var x: Villager = loners[0]
		match kind:
			"couple":
				st.queue.assign([pair_a, pair_b, loners[0]])
				md.config.capacity = 3
			"refuser":
				md.refused_player.append({"day": 1, "by": x})
				st.queue.assign([x])
			"voted":
				md.player_votes.append({"day": 2, "who": x})
				st.queue.assign([x])
			"accuser":
				md.accused_player[x.id] = 2
				st.queue.assign([x])
			"grieving":
				x.grief_days = 1
				x.grief_for = loners[1].id
				st.queue.assign([x])
			"crowd":
				md.config.capacity = 2
				st.queue.assign([loners[0], loners[1], loners[2]])
			"oil":
				md.talisman[0] = 0
				st.queue.assign([x])
		var d := md.door_dilemma(st)
		for _try in range(80):
			if not d.is_empty() and String(d.kind) == kind:
				break
			d = md.door_dilemma(st)
		if d.is_empty() or String(d.kind) != kind:
			dl_ok = false
			print("дилемма: ждали %s, вышло %s" % [kind, d])
			continue
		kinds_seen[kind] = true
		var card := DoorScreen.dilemma_card(md, d)
		var ctext := _all_text_raw(card)
		card.free()
		if (kind != "crowd" and not ctext.contains(md.get_villager(int(d.who)).name.left(3))) or ctext.contains("{"):
			dl_ok = false
			print("карточка дилеммы %s: %s" % [kind, ctext])
		var ids: Array[int] = [int(d.who)]
		var tal_before := md.talisman[0]
		md.admit(st, ids)
		var rec: Dictionary = md.dilemmas[-1] if not md.dilemmas.is_empty() else {}
		if rec.is_empty() or not bool(rec.admitted):
			dl_ok = false
		if kind == "oil" and md.talisman[0] != tal_before + 1:
			dl_ok = false
			print("масло не укрепило оберег")
		if kind == "refuser":
			# долг платежом красен: теперь он хозяин, игрок стучит — откроет
			var dd := Director.new()
			dd.attach(md)
			var back := Match.Seat.new()
			back.host = x
			back.house = 1
			back.queue.assign([md.player()])
			md.phase = Match.Phase.DOOR
			if not dd.host_decide(back, "beg").has(md.player().id):
				dl_ok = false
				print("должник не открыл игроку")
		var rr := NightReport.new()
		rr.add(NightReport.Kind.KILLED_STREET, md.get_villager(int(d.who)), 1)
		md._dilemma_fate(rr)
		var lines := Recap.dilemma_lines(md)
		if lines.is_empty() or "".join(lines).contains("{"):
			dl_ok = false
			print("разбор дилеммы: %s" % [lines])
		# одна дилемма за ночь: вторая в ту же ночь не появляется
		if not md.door_dilemma(st).is_empty():
			dl_ok = false
			print("вторая дилемма в ту же ночь")
	ok += _expect(fails, dl_ok and kinds_seen.size() == 7, "дилеммы у двери: видов %d из 7" % kinds_seen.size())

	# 9. Изгнание (55): уходит в лес с последними словами; изгнали тебя — смотреть или закончить; ночью зов
	var npc: Villager = m.alive_bots()[0]
	m.phase = Match.Phase.VOTE
	var tally: Dictionary[int, int] = {npc.id: 3}
	var ex := m.apply_vote(tally)
	var vs := VoteScreen.new()
	Nav.show(vs)
	await _settle(tree)
	vs.show_result(tally, ex)
	await _settle(tree)
	var fate_card := vs.find_child("ExileFate", true, false)
	ok += _expect(fails, fate_card != null and fate_card.find_child("LastWords", true, false) != null
		and fate_card.find_child("Portrait", true, false) != null, "изгнанный уходит без сцены: нет портрета или последних слов")
	m.forest_call_day = m.day
	m.last_exiled = npc
	m.phase = Match.Phase.NIGHT
	Nav.show(NightScreen.new())
	await _settle(tree)
	var call := Nav.host.current.find_child("ForestCall", true, false)
	ok += _expect(fails, call != null and _all_text(call).contains(m.player().name), "ночью после изгнания из леса не зовут игрока по имени")
	m.phase = Match.Phase.VOTE
	npc.alive = true
	npc.exiled = false
	var ptally: Dictionary[int, int] = {m.player().id: 5}
	var pex := m.apply_vote(ptally)
	var vs2 := VoteScreen.new()
	Nav.show(vs2)
	await _settle(tree)
	vs2.show_result(ptally, pex)
	await _settle(tree)
	ok += _expect(fails, vs2.find_child("YouExiled", true, false) != null and (m.upyri_alive() == 0 or vs2.find_child("SkipToEnd", true, false) != null),
		"тебя изгнали, а экрана изгнания и кнопки «Закончить партию» нет")

	# 10. Твоя смерть (55): портрет, что слышал последним, посёлок без тебя; «Закончить» доигрывает партию
	m.player().alive = true
	m.player().exiled = false
	m.vote_log.clear()
	m.winner = Match.Team.NONE
	m.phase = Match.Phase.MORNING
	var rd := NightReport.new()
	var ed := rd.add(NightReport.Kind.KILLED_STREET, m.player(), 0)
	ed.host = m.alive_bots()[0]
	m.player().alive = false
	m.player_death = ed
	m.report = rd
	Nav.show(MorningScreen.new())
	await _settle(tree)
	var why := Nav.host.current.find_child("WhyDead", true, false)
	var skip := Nav.host.current.find_child("SkipToEnd", true, false) as Button
	ok += _expect(fails, why != null and why.find_child("LastHeard", true, false) != null and why.find_child("WithoutYou", true, false) != null
		and why.find_child("Portrait", true, false) != null, "экран твоей смерти без портрета, последнего звука или того, что будет дальше")
	ok += _expect(fails, skip != null, "после твоей смерти нельзя закончить партию сразу")
	if skip != null:
		skip.pressed.emit()
		await _settle(tree)
	ok += _expect(fails, m.phase == Match.Phase.OVER and Nav.host.current is EndScreen, "«Закончить партию» не довело до итога (фаза %s)" % Match.Phase.keys()[m.phase])

	# 11. Конец главы (55): исход, кто дожил, разоблачение каждого упыря, решения у двери
	m.dilemmas.append({"day": 1, "kind": "voted", "who": m.alive_bots()[0].id if not m.alive_bots().is_empty() else npc.id, "other": -1,
		"house": 0, "admitted": true, "fate": "alive"})
	Nav.show(EndScreen.new())
	await _settle(tree)
	var es := Nav.host.current
	var bot_upyri := 0
	var reveal_ok := true
	for v: Villager in m.villagers:
		if v.is_upyr and not v.is_player:
			bot_upyri += 1
			var rc := es.find_child("Reveal_%d" % v.id, true, false)
			if rc == null or not _all_text(rc).contains(v.name):
				reveal_ok = false
	ok += _expect(fails, es.find_child("Ending", true, false) != null and es.find_child("Survivors", true, false) != null, "в конце главы нет исхода и списка выживших")
	ok += _expect(fails, reveal_ok and bot_upyri > 0, "в конце не разоблачены упыри (%d)" % bot_upyri)
	ok += _expect(fails, es.find_child("Dilemmas", true, false) != null, "в конце нет решений у двери")
	ok += _expect(fails, not _all_text(es).contains("{"), "в конце главы осталась метка подстановки")
	var end_s := es as EndScreen
	var sl := end_s.open_slides()
	await _frames(tree, 2)
	var art := sl.find_child("Art", true, false) as TextureRect if sl != null else null
	ok += _expect(fails, art != null and art.texture != null and art.size.x > end_s.get_viewport_rect().size.x,
		"нет заставки финала с картинкой, которая проплывает по экрану")
	ok += _expect(fails, not end_s.slide_text(0).contains("{") and not end_s.slide_text(1).contains("{") and not end_s.slide_text(1).is_empty(),
		"в слайдах финала метка подстановки")
	ok += _expect(fails, end_s.music() == (&"end_dawn" if m.winner == Match.Team.PEOPLE else &"end_dark") and Sfx.has_sound(end_s.music()),
		"у финала нет своей музыки")
	end_s.close_slides()
	await _frames(tree, 3)
	ok += _expect(fails, end_s.slides == null and not is_instance_valid(sl), "заставка финала не закрывается")

	ok += await _campaign_checks(tree, fails)
	ok += await _guests_progress_checks(tree, fails)

	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "разбор партии", "почему ты погиб, что решило партию, кто кем был и как всё шло по ночам")



# =============================================================
# Новые жители (Task 35–37): Folk — пол, приметы, эмоции всем телом, анимация, реакции толпы.
# =============================================================
static func folk() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	var book := load("res://config/looks.tres") as LookBook

	# 0. Новый лист: все 16 спрайтов загружаются, женские и мужские типы не смешаны.
	var all_sprites_loaded := true
	for sprite_id in range(1, 17):
		var tex: Texture2D = VillagerFigure.folk_tex(sprite_id)
		if tex == null or tex.get_width() < 50 or tex.get_height() < 180:
			all_sprites_loaded = false
	var pools_ok := true
	for sprite_id in range(9, 13):
		if not VillagerFigure.FOLK_FEMALE.has(sprite_id) or VillagerFigure.FOLK_MALE.has(sprite_id):
			pools_ok = false
	for sprite_id in range(13, 17):
		if not VillagerFigure.FOLK_MALE.has(sprite_id) or VillagerFigure.FOLK_FEMALE.has(sprite_id):
			pools_ok = false
	var young_woman := LookDef.new()
	young_woman.female = true
	young_woman.age = 0
	var adult_woman := LookDef.new()
	adult_woman.female = true
	var old_woman := LookDef.new()
	old_woman.female = true
	old_woman.age = 2
	var boy := LookDef.new()
	boy.age = 0
	boy.height = 0.9
	var bearded_man := LookDef.new()
	bearded_man.beard = LookDef.Beard.FULL
	var prefs_ok := VillagerFigure.sprite_pref(young_woman)[0] == 9 \
		and VillagerFigure.sprite_pref(adult_woman)[0] == 10 \
		and VillagerFigure.sprite_pref(old_woman)[0] == 11 \
		and VillagerFigure.sprite_pref(boy)[0] == 15 \
		and VillagerFigure.sprite_pref(bearded_man)[0] == 16
	ok += _expect(fails, all_sprites_loaded, "не загрузился один из спрайтов f1–f16")
	ok += _expect(fails, pools_ok, "спрайты f9–f16 распределены по неверному полу")
	ok += _expect(fails, prefs_ok, "возраст или борода не выбирают подходящий новый спрайт")
	var female_used: Dictionary = {}
	var male_used: Dictionary = {}
	var unique_ok := true
	for _i in range(VillagerFigure.FOLK_FEMALE.size()):
		var before_female := female_used.size()
		var picked_female := VillagerFigure.pick_sprite(adult_woman, female_used)
		if not VillagerFigure.FOLK_FEMALE.has(picked_female) or female_used.size() != before_female + 1:
			unique_ok = false
	for _i in range(VillagerFigure.FOLK_MALE.size()):
		var before_male := male_used.size()
		var picked_male := VillagerFigure.pick_sprite(bearded_man, male_used)
		if not VillagerFigure.FOLK_MALE.has(picked_male) or male_used.size() != before_male + 1:
			unique_ok = false
	ok += _expect(fails, unique_ok and female_used.size() == VillagerFigure.FOLK_FEMALE.size()
		and male_used.size() == VillagerFigure.FOLK_MALE.size(), "новые спрайты повторяются до исчерпания списка пола")

	# 1. Внешности: девушки — с женскими приметами, у каждого свой набор примет
	var sig: Dictionary = {}
	var fem_ok := true
	for l: LookDef in book.looks:
		var f := L.female_names().has(l.who)
		if f != l.female:
			fem_ok = false
		if f and not (l.outfit == LookDef.Outfit.DRESS and (l.bow != LookDef.Bow.NONE or l.earrings or l.hair_style in [LookDef.Hair.LONG, LookDef.Hair.BRAIDS, LookDef.Hair.PIGTAILS, LookDef.Hair.PONYTAIL, LookDef.Hair.BUN, LookDef.Hair.BOB, LookDef.Hair.CURLY])):
			fem_ok = false
		var key := "%d-%d-%d-%d-%d-%s-%s-%s" % [l.hair_style, l.head, l.beard, l.outfit, l.age, l.glasses, l.freckles, l.scar]
		sig[key] = sig.get(key, 0) + 1
	ok += _expect(fails, fem_ok, "у девушек нет женских примет (платье, причёска, украшения) или пол перепутан")
	ok += _expect(fails, sig.size() == book.looks.size(), "двое жителей выглядят одинаково: %d наборов примет на %d жителей" % [sig.size(), book.looks.size()])

	# 2. Эмоции: каждое лицо рисуется, у сильных эмоций своя поза тела
	var probe := Node2D.new()
	tree.root.add_child(probe)
	var drawn := [0]          # лямбда захватывает копию числа — счётчик в массиве
	probe.draw.connect(func() -> void:
		for f2: String in Folk.FACES:
			Folk.figure(probe, Vector2(100, 200), 0.6, book.looks[0], f2, {})
			drawn[0] += 1)
	probe.queue_redraw()
	await _frames(tree, 3)
	probe.queue_free()
	ok += _expect(fails, drawn[0] >= Folk.FACES.size(), "не все эмоции нарисовались (%d из %d)" % [drawn[0], Folk.FACES.size()])
	var poses := {}
	for f3: String in ["scared", "angry", "happy", "sad", "cold", "shocked"]:
		poses[str(Folk.emotion_pose(f3))] = true
	ok += _expect(fails, poses.size() == 6, "у сильных эмоций одинаковые позы тела")

	# 3. Анимация: на бегу ноги идут каждый кадр, в покое — почти без перерисовки
	Save.set_difficulty("normal")
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _settle(tree)
	var m := Game.m
	var cr := Nav.village.crowd
	var bot: Villager = m.alive_bots()[0]
	var f4: VillagerFigure = cr.figures[bot.id]
	var palettes := {}
	var readable := true
	for figure: VillagerFigure in cr.figures.values():
		palettes[figure.identity_color.to_html()] = true
		readable = readable and not cr._hidden(figure.position, true)
	ok += _expect(fails, palettes.size() == cr.figures.size(), "цвета одежды жителей повторяются")
	ok += _expect(fails, readable, "на дневной стоянке дом закрывает тело жителя")
	var visible_lamps := 0
	for prop: VillageProp in Nav.village._props:
		if prop.has_meta("street_lamp") and prop.z_index == 0:
			visible_lamps += 1
	ok += _expect(fails, visible_lamps == Nav.village.def.lamps.size(), "фонари спрятаны под слоем земли")
	var no_dye := true
	for figure: VillagerFigure in cr.figures.values():
		no_dye = no_dye and figure._door_rig.material == null
	ok += _expect(fails, no_dye, "одежду закрывает цветная маска")
	var draws := [0]
	f4.body.draw.connect(func() -> void: draws[0] += 1)
	Game.hold(&"test")            # реплики ботов стоят: говорящий шевелит ртом — это честная перерисовка
	f4._talk_t = 0.0
	f4._emotion_t = 0.0
	f4._blink_in = 5.0
	f4.fidgets_on = false         # действия от скуки проверяются отдельно (п. 9)
	f4.fidget = ""
	Juice.instant = false
	await tree.create_timer(0.6).timeout
	var idle_draws: int = draws[0]
	draws[0] = 0
	var walk0 := f4._walk
	f4.walk_to(f4.position + Vector2(160, 0))
	var shape_error := 0.0
	var root_hop := 0.0
	var feet_motion := 0.0
	var head_motion := 0.0
	var movement_until := Time.get_ticks_msec() + 600
	while Time.get_ticks_msec() < movement_until:
		await tree.process_frame
		shape_error = maxf(shape_error, f4.body.scale.abs().distance_to(Vector2.ONE))
		root_hop = maxf(root_hop, absf(f4.body.position.y))
		var points: PackedVector2Array = f4._door_rig.polygon
		for vertex in range(mini(points.size(), f4._door_base.size())):
			var base: Vector2 = f4._door_base[vertex]
			var moved := points[vertex].distance_to(base)
			if base.y > -12.0:
				feet_motion = maxf(feet_motion, moved)
			if base.y < -72.0:
				head_motion = maxf(head_motion, moved)
	var run_draws: int = draws[0]
	print("шаг: деформация корпуса %.3f, подскок %.3f, движение стоп %.2f, головы %.2f" % [shape_error, root_hop, feet_motion, head_motion])
	ok += _expect(fails, shape_error < 0.01 and root_hop < 0.01, "шаг сжимает тело или подбрасывает его (форма %.3f, подскок %.3f)" % [shape_error, root_hop])
	ok += _expect(fails, feet_motion > 0.5 and head_motion < 0.1, "шагают не ноги (стопы %.2f, голова %.2f)" % [feet_motion, head_motion])
	ok += _expect(fails, run_draws >= 8 and f4._walk != walk0, "на бегу ноги не двигаются (перерисовок %d)" % run_draws)
	ok += _expect(fails, idle_draws <= 3, "в покое житель перерисовывается слишком часто (%d за 0,6 с)" % idle_draws)
	await tree.create_timer(1.0).timeout
	Juice.instant = true
	Game.release(&"test")

	# 4. Работа с инструментом по виду дела
	var wj := m.job_index(&"water")
	cr.send_to_job(bot.id, wj)
	await _frames(tree, 3)
	ok += _expect(fails, f4.working and f4.tool == "bucket", "у колодца житель работает без ведра (инструмент «%s»)" % f4.tool)
	cr.leave_job(bot.id)
	await _frames(tree, 2)

	# 5. Голова к говорящему, толпа — к обвинённому
	var speaker: Villager = m.alive_bots()[1]
	var sf: VillagerFigure = cr.figures[speaker.id]
	m.post(ChatLine.say(speaker, "Слушайте все."))
	await _frames(tree, 2)
	var turned := 0
	var right_way := true
	for v: Villager in m.alive():
		if v == speaker:
			continue
		var fv: VillagerFigure = cr.figures[v.id]
		if absf(fv.position.x - sf.position.x) <= 260.0 and absf(fv.position.x - sf.position.x) > 10.0:
			if fv.turn != 0.0:
				turned += 1
				if signf(fv.turn) != signf(sf.position.x - fv.position.x):
					right_way = false
	ok += _expect(fails, turned >= 2 and right_way, "жители не поворачиваются к говорящему (повернулись %d)" % turned)
	var target: Villager = m.alive_bots()[2]
	cr.day_life = false               # чтобы наклон не пришёл от шёпота соседу
	for v: Villager in m.alive():
		var fz: VillagerFigure = cr.figures[v.id]
		fz.fidgets_on = false
		fz.fidget = ""
		fz._lean = 0.0
	Nav._accuse_fx(m.player(), target)
	await _frames(tree, 2)
	var sus := 0
	for v: Villager in m.alive_bots():
		if v != target and (cr.figures[v.id] as VillagerFigure).emotion == "suspicious":
			sus += 1
	ok += _expect(fails, (cr.figures[target.id] as VillagerFigure).emotion == "shocked", "обвинённый не испугался")
	var tf: VillagerFigure = cr.figures[target.id]
	var tpose: Dictionary = tf.pose_now()[1]
	var lean_world: float = tpose.get("lean", 0.0) * tf._face      # поза в координатах тела, тело развёрнуто по _face
	ok += _expect(fails, lean_world != 0.0 and signf(lean_world) == signf(tf.position.x - cr.figures[0].position.x), "обвинённый не отшатнулся от обвинителя")
	print("на обвинение прищурились: %d" % sus)

	# 6. Изгнание: изгнанный в страхе, толпа смотрит на него
	Nav._exile_fx(target)
	await _frames(tree, 2)
	ok += _expect(fails, (cr.figures[target.id] as VillagerFigure).emotion == "scared", "изгнанный не испугался")

	# 7. Ухмылка упыря: только у упырей
	var sly_ok := true
	var sly_n := 0
	for k in range(30):
		for v: Villager in m.alive_bots():
			(cr.figures[v.id] as VillagerFigure).emotion = ""
		Nav._sly_in = 0.0
		Nav._sly_step(0.016)
		for v: Villager in m.alive_bots():
			if (cr.figures[v.id] as VillagerFigure).emotion == "sly":
				sly_n += 1
				if not v.is_upyr:
					sly_ok = false
	ok += _expect(fails, sly_ok and sly_n > 0, "ухмылка мелькает не у упыря или не мелькает совсем (%d)" % sly_n)

	# 9. Жизнь на площади: за минуту дня каждый живой что-то делает, все остаются на местах
	Game.hold(&"test")
	cr.day_life = true
	var pos0: Dictionary[int, Vector2] = {}
	for v: Villager in m.alive():
		var fv: VillagerFigure = cr.figures[v.id]
		fv.fidgets_on = true
		fv.fidget_count = 0
		fv._emotion_t = 0.0
		fv.emotion = ""
		fv._talk_t = 0.0
		pos0[v.id] = fv.position
	cr.whispers = 0
	var kinds: Dictionary = {}
	for step in range(600):
		for v: Villager in m.alive():
			var fv: VillagerFigure = cr.figures[v.id]
			fv._process(0.1)
			if fv.fidget != "":
				kinds[fv.fidget] = true
		cr.life_step(0.1)
		for v: Villager in m.alive():
			var fv: VillagerFigure = cr.figures[v.id]
			if fv.fidget != "" and not kinds.has("pose:" + fv.fidget) and fv.pose_now()[1] != _plain_pose(fv):
				kinds["pose:" + fv.fidget] = true
	var idle_ones: PackedStringArray = []
	var moved: PackedStringArray = []
	var vr := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	for v: Villager in m.alive():
		var fv: VillagerFigure = cr.figures[v.id]
		if fv.fidget_count < 1:
			idle_ones.append(v.name)
		var gp := fv.get_global_transform_with_canvas().origin
		if fv.position.distance_to(pos0[v.id]) > 0.5 or not vr.has_point(gp):
			moved.append(v.name)
	ok += _expect(fails, idle_ones.is_empty(), "за минуту дня ничего не сделали: %s" % ", ".join(idle_ones))
	ok += _expect(fails, moved.is_empty(), "от действий сдвинулись или ушли из кадра: %s" % ", ".join(moved))
	var posed := kinds.keys().filter(func(k: String) -> bool: return k.begins_with("pose:"))
	ok += _expect(fails, kinds.size() - posed.size() >= 4, "действий мало: %s" % ", ".join(kinds.keys()))
	ok += _expect(fails, posed.size() == kinds.size() - posed.size(), "не все действия меняют позу тела: %s" % ", ".join(kinds.keys()))
	ok += _expect(fails, cr.whispers >= 3, "соседи почти не шепчутся (%d раз за минуту)" % cr.whispers)
	print("за минуту: действия %s, шёпотов %d" % [", ".join(posed), cr.whispers])
	Game.release(&"test")

	# 8. Ночь: у двери все ёжатся, днём — нет
	Save.mark_hint("night")
	Game.end_day()
	await _settle(tree)
	if m.phase == Match.Phase.VOTE:
		Game.vote(-1)
		await _settle(tree)
		Game.proceed()
		await _settle(tree)
	var cold_all := true
	for v: Villager in m.alive():
		if not (cr.figures[v.id] as VillagerFigure).cold:
			cold_all = false
	ok += _expect(fails, cold_all, "ночью жители не ёжатся от холода")
	ok += _expect(fails, cr.flinched == m.alive().size(), "на колокол вздрогнули %d из %d" % [cr.flinched, m.alive().size()])
	var day_still := true
	for v: Villager in m.alive():
		if (cr.figures[v.id] as VillagerFigure).fidgets_on:
			day_still = false
	ok += _expect(fails, day_still and not cr.day_life, "ночью жители продолжают дневные действия")
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "новые жители", "девушки отличаются, у каждого свои приметы, эмоции всем телом, ноги идут, толпа реагирует, днём все чем-то заняты")


static func _plain_pose(fv: VillagerFigure) -> Dictionary:
	var keep := fv.fidget
	fv.fidget = ""
	var p: Dictionary = fv.pose_now()[1]
	fv.fidget = keep
	return p


## Имя в падеже по русской грамматике — для проверок русских текстов.
static func _ru_case(case: String, name: String) -> String:
	return L.gram().name_case(name, case, false)


# =============================================================
# Языки (задачи 39–43)
# =============================================================
## Каждый язык: все ключи русского на месте, метки шаблонов те же, тексты партий собираются
## без недоставленных меток и русских букв, в посёлке 12 жителей со своими внешностями и 5 домов с падежами.
static func loc() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var fails := PackedStringArray()
	var ok := 0
	var ru_d := (L._load("ru")).d()
	var re_var := RegEx.create_from_string("\\{(\\w+)[.}:#]")
	var re_left := RegEx.create_from_string("[{}\\[\\]]|\\|")
	var re_cyr := RegEx.create_from_string("[А-Яа-яЁё]")
	var c := load("res://config/balance_7.tres") as GameConfig
	var langs_ok := 0
	for code: String in L.LANGS:
		var path := "res://scripts/loc/%s.gd" % code
		if not ResourceLoader.exists(path):
			fails.append("%s: нет файла языка" % code)
			continue
		var g := L._load(code)
		var d := g.d()
		var miss := PackedStringArray()
		var bad_vars := PackedStringArray()
		for key: String in ru_d:
			if not d.has(key):
				miss.append(key)
				continue
			if key in ["houses", "houses_mill", "houses_monastery", "houses_station", "names", "looks", "you", "someone"]:
				continue
			if (ru_d[key] is Array) != (d[key] is Array):
				bad_vars.append("%s: строка вместо банка или наоборот" % key)
				continue
			var ru_vars := _vars_of(re_var, ru_d[key])
			for v: String in _vars_of(re_var, d[key]):
				if not ru_vars.has(v) and v != "who" and v != "me":
					bad_vars.append("%s: метка {%s}, которой нет в русском" % [key, v])
		for key: String in d:
			if not ru_d.has(key) and not key.begins_with("intent.") and key != "looks":
				bad_vars.append("%s: лишний ключ" % key)
		ok += _expect(fails, miss.is_empty(), "%s: нет %d ключей: %s" % [code, miss.size(), ", ".join(miss.slice(0, 8))])
		ok += _expect(fails, bad_vars.is_empty(), "%s: %s" % [code, "; ".join(bad_vars.slice(0, 6))])
		var hs: Array = d.get("houses", [])
		ok += _expect(fails, hs.size() == (ru_d.houses as Array).size(), "%s: убежищ %d, нужно %d" % [code, hs.size(), (ru_d.houses as Array).size()])
		for h: Variant in hs:
			for k: String in (ru_d.houses[0] as Dictionary):
				if String((h as Dictionary).get(k, "")).is_empty():
					fails.append("%s: у дома «%s» нет формы %s" % [code, (h as Dictionary).get("nom", "?"), k])
		var nm: Array = d.get("names", [])
		var fem := 0
		var seen: Dictionary = {}
		for n: Variant in nm:
			fem += 1 if bool(n[1]) else 0
			seen[String(n[0])] = true
		ok += _expect(fails, nm.size() == 12 and fem == 6 and seen.size() == 12, "%s: жителей %d (женщин %d, разных имён %d), нужно 12 и 6" % [code, nm.size(), fem, seen.size()])
		var book := load(String(d.get("looks", ""))) as LookBook if ResourceLoader.exists(String(d.get("looks", ""))) else null
		ok += _expect(fails, book != null, "%s: нет внешностей посёлка %s" % [code, d.get("looks", "")])
		if book != null:
			var lost := PackedStringArray()
			for n: Variant in nm:
				var found := false
				for l: LookDef in book.looks:
					if l.who == String(n[0]):
						found = true
						if l.female != bool(n[1]):
							lost.append("%s: пол не совпадает" % n[0])
				if not found:
					lost.append(String(n[0]))
			ok += _expect(fails, lost.is_empty() and book.player != null, "%s: нет внешности у %s" % [code, ", ".join(lost)])

		# тексты на этом языке: все ключи с разными подстановками и полные партии
		L.use(code)
		L.missing.clear()
		var texts := PackedStringArray()
		var m := Match.new()
		m.start(c, 77)
		var bm: Villager = null
		var bf: Villager = null
		for v: Villager in m.alive_bots():
			if v.female and bf == null:
				bf = v
			elif not v.female and bm == null:
				bm = v
		for key: String in d:
			if key in ["houses", "houses_mill", "houses_monastery", "houses_station", "names", "looks", "you", "someone"] or key.begins_with("intent."):
				continue
			var lines: PackedStringArray = L.arr(key)
			for who: Villager in [bm, bf, m.player()]:
				for n: int in [1, 2, 5, 21]:
					var a := {"who": who, "me": bf if who == bm else bm, "voice": bm, "h": who, "a": bm, "b": m.player(),
						"house": m.houses[0], "from": m.houses[1], "said": m.houses[1], "away": m.houses[1], "to": m.houses[1],
						"others": [who], "list": [bm, bf, m.player()], "n": n, "p": n, "u": n, "d": n, "s": n, "c": n,
						"e": "e", "text": "t", "ev": "ev", "job": "Job", "place": "place", "what": "w", "role": "role",
						"healer": "healer", "title": "T", "rest": "r", "where": "w", "why": "y", "lost": bf, "kin": bm, "player_name": "Name", "other": bm, "name": "Name", "choice": "c", "fate": "f", "m": n, "of": n}
					for line: String in lines:
						texts.append(L.fill(line, a))
		texts.append_array(collect_texts(c, 25))
		var social_rng := RandomNumberGenerator.new()
		social_rng.seed = 91
		for case_index in range(3):
			texts.append(SocialContent.case_title(case_index))
			texts.append(SocialContent.case_hook(case_index))
			for anchor_index in range(3):
				for speaker: Villager in [bm, bf]:
					texts.append(SocialContent.anchor_title(anchor_index, speaker.female if speaker != null else false))
					for chapter_index in range(2):
						texts.append(SocialContent.anchor_chapter(anchor_index, chapter_index, speaker))
		for speaker: Villager in [bm, bf]:
			for story_index in range(12):
				texts.append(SocialContent.story(story_index, speaker))
				speaker.story_id = story_index
				speaker.age = SocialContent.story_age(story_index)
				texts.append(SocialContent.person_title(speaker))
				for chapter in range(3):
					texts.append(SocialContent.personal_chapter(speaker, chapter))
		texts.append(SocialContent.village_intro(m))
		# задача 65: истории, пара, осмотр у двери и мелочи интерфейса на всех языках, не по-английски
		for beat: Array in SocialContent.opening_beats(m):
			texts.append(String(beat[0]))
			texts.append(String(beat[1]))
		var dn := Director.new()
		dn.m = m
		for kind: String in ["first", "answer", "exiled", "together", "apart"]:
			for i in range(8):
				for sp: Villager in [bm, bf]:
					texts.append(L.fill(dn._couple_pick(kind), {"me": sp, "other": bf if sp == bm else bm, "name": "Name"}))
		for salt in range(8):
			texts.append(L.fill(SocialContent.door_sign(&"ordinary", salt), {"who": bf}))
			texts.append(L.fill(SocialContent.door_sign(&"ordinary", salt), {"who": bm}))
		for sp: Villager in [bm, bf]:
			texts.append(SocialContent.grief_text(sp, bf if sp == bm else bm))
			sp.story_step = 1
			var keep_story := sp.story_id
			for sid in range(12):
				sp.story_id = sid
				texts.append(SocialContent.epilogue(sp))
			sp.story_id = keep_story
			sp.story_step = 0
		for bid: String in ["none", "sun", "bone", "seal"]:
			texts.append(Cosmetics.title("brooch", bid))
		if code != "ru" and code != "en":
			var need: PackedStringArray = StoryLoc.DATA["de"].keys()
			var have: Dictionary = StoryLoc.DATA.get(code, {})
			var gaps := PackedStringArray()
			for k: String in need:
				if not have.has(k):
					gaps.append(k)
			ok += _expect(fails, gaps.is_empty(), "%s: в StoryLoc нет %s" % [code, ", ".join(gaps)])
			texts.append_array(PackedStringArray(have.get("misc", [])))
		# голоса жителей (русский банк по характерам): все метки подставляются при любом роде
		if code == "ru":
			for persona: int in Voices.RU:
				for bank: String in Voices.RU[persona]:
					for line: String in Voices.RU[persona][bank]:
						for sp: Villager in [bm, bf]:
							for tg: Villager in [bm, bf, m.player()]:
								var lost_v: Villager = bf if sp == bm else bm
								texts.append(L.fill(line, {"me": sp, "who": tg if bank != "REVENGE" or not tg.is_player else tg.name,
									"lost": lost_v, "house": m.houses[0], "player_name": m.player().name}))
		for key: String in ["cast", "personal", "listen", "doubt", "later", "thanks", "hurt"]:
			texts.append(L.fill(SocialContent.narrative_ui(key), {"me": bf}))
		texts.append(SocialContent.door_mimic_title())
		for tag: String in SocialContent.question_tags():
			texts.append(tag)
		for tell: StringName in [&"breath", &"rhythm", &"shadow", &"ordinary"]:
			texts.append(SocialContent.door_sign(tell))
			texts.append(SocialContent.door_record(2, tell))
		texts.append(SocialContent.case_recap(0, 2))
		for key: String in ["inspect", "done", "limit"]:
			texts.append(SocialContent.door_ui(key))
		for topic: String in ["arrival", "night", "alibi", "work", "sabotage", "death", "tunnel", "trust", "rumor"]:
			texts.append(SocialContent.question(topic, m.player().name, social_rng))
		var marks := PackedStringArray()
		var cyr := PackedStringArray()
		for t: String in texts:
			if re_left.search(t) != null and marks.size() < 5:
				marks.append(t)
			if code != "ru" and re_cyr.search(t) != null and cyr.size() < 5:
				cyr.append(t)
		ok += _expect(fails, marks.is_empty(), "%s: недоставленные метки: %s" % [code, " / ".join(marks)])
		ok += _expect(fails, cyr.is_empty(), "%s: русские буквы в тексте: %s" % [code, " / ".join(cyr)])
		ok += _expect(fails, L.missing.is_empty(), "%s: игра просила ключи, которых нет: %s" % [code, ", ".join(PackedStringArray(L.missing.keys()).slice(0, 8))])
		var glyphs := _missing_glyphs(texts)
		ok += _expect(fails, glyphs.is_empty(), "%s: шрифт не рисует %d знаков: %s" % [code, glyphs.length(), glyphs.left(40)])
		print("%s: %d строк, ключей %d" % [code, texts.size(), d.size()])
		langs_ok += 1
	L.use("ru")

	# грамматика: падежи и числа
	var ru := L._load("ru")
	var cases := {"Марина": ["Марину", "Марины", "Марине", "Мариной"], "Тимур": ["Тимура", "Тимура", "Тимуру", "Тимуром"],
		"Гриша": ["Гришу", "Гриши", "Грише", "Гришей"], "Женя": ["Женю", "Жени", "Жене", "Женей"]}
	for n: String in cases:
		var got := [ru.name_case(n, "acc", false), ru.name_case(n, "gen", false), ru.name_case(n, "dat", false), ru.name_case(n, "ins", false)]
		ok += _expect(fails, got == cases[n], "падежи «%s»: %s" % [n, got])
	ok += _expect(fails, [ru.plural_index(1), ru.plural_index(3), ru.plural_index(5), ru.plural_index(11), ru.plural_index(21), ru.plural_index(24)] == [0, 1, 2, 2, 0, 1], "русские числа: 1 житель, 3 жителя, 5 жителей")
	ok += _expect(fails, L.detect("pt_BR") == "pt" and L.detect("zh_CN") == "zh" and L.detect("es_MX") == "es" and L.detect("ru_RU") == "ru" and L.detect("uk_UA") == "ru" and L.detect("ja_JP") == "en", "язык телефона определяется неверно")

	# смена языка в настройках: экраны и посёлок перестраиваются
	Nav.show_settings()
	await _settle(tree)
	var before := _all_text(Nav.host.current)
	if L.LANGS.has("en") and ResourceLoader.exists("res://scripts/loc/en.gd"):
		Nav.host.current.emit_intent(Intent.SET_LANG, {"code": "en"})
		await _settle(tree)
		var after := _all_text(Nav.host.current)
		ok += _expect(fails, Save.lang == "en" and after != before and after.contains("English") and re_cyr.search(after) == null, "настройки не перевелись на английский: %s" % after.left(120))
		ok += _expect(fails, Nav.village.titles == L.houses() and Nav.village.titles[0] != "Дом у реки", "посёлок не взял английские дома")
		Nav.host.current.emit_intent(Intent.SET_LANG, {"code": "ru"})
		await _settle(tree)
		ok += _expect(fails, Save.lang == "ru" and _all_text(Nav.host.current).contains("Настройки"), "не вернулся русский")
	# запуск: язык из настроек включается сразу (без экрана — всегда русский)
	L.use("en")
	Save.load_all()
	ok += _expect(fails, L.code == "ru" and Save.lang == "ru", "при запуске язык из настроек не включился: %s" % L.code)
	_finish(fails, ok, "ЯЗЫКИ", "все языки полные, шаблоны без дыр, посёлки на месте (%d из %d)" % [langs_ok, L.LANGS.size()])


static func _vars_of(re: RegEx, v: Variant) -> Dictionary:
	var out := {}
	var lines: Array = v if v is Array else [v]
	for line: Variant in lines:
		for mm: RegExMatch in re.search_all(String(line)):
			out[mm.get_string(1)] = true
	return out


## Знаки, которых нет ни в основном шрифте, ни в запасных (иероглифы, деванагари).
static func _missing_glyphs(texts: PackedStringArray) -> String:
	var base := ThemeFactory.font(650).base_font as FontFile
	var chain: Array[Font] = [base]
	for f: Font in base.fallbacks:
		chain.append(f)
	var seen := {}
	var out := ""
	for t: String in texts:
		for i in range(t.length()):
			var ch := t.unicode_at(i)
			if seen.has(ch) or ch < 32 or ch == 0x200d or ch == 0x200c:
				continue
			seen[ch] = true
			var hit := false
			for f: Font in chain:
				if f.has_char(ch):
					hit = true
					break
			if not hit:
				out += char(ch)
	return out


# =============================================================
# Доступность (задача 46): три размера текста, глаз и улики различимы без цвета
# =============================================================
static func access() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()

	# 1. Размер текста: три кнопки в настройках, тема меняется сразу, выбор сохраняется
	Nav.show_settings()
	await _settle(tree)
	var ss := Nav.host.current as SettingsScreen
	var row := ss.find_child("TextSizes", true, false) as HBoxContainer
	ok += _expect(fails, row != null and row.get_child_count() == 3, "в настройках нет трёх размеров текста")
	var sizes: Array[int] = []
	for i in range(3):
		if row == null:
			break
		(row.get_child(i) as Button).pressed.emit()
		await _settle(tree)
		ss = Nav.host.current as SettingsScreen
		row = ss.find_child("TextSizes", true, false) as HBoxContainer
		var probe := ss.body.get_child(0) as Label
		sizes.append(probe.get_theme_font_size("font_size"))
		var on := (row.get_child(i) as Button).theme_type_variation == &"RowOn"
		ok += _expect(fails, Save.text_size == i and on, "размер %d не выбран или не подсвечен" % i)
	ok += _expect(fails, sizes.size() == 3 and sizes[0] < sizes[1] and sizes[1] < sizes[2], "текст не растёт по ступеням: %s" % str(sizes))
	var cf := ConfigFile.new()
	cf.load(Save.SETTINGS_PATH)
	ok += _expect(fails, int(cf.get_value("ui", "text_size", -1)) == 2, "размер текста не сохранился в настройках")
	# реплика в пузыре тоже крупнее
	Save.set_text_size(2)
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	var bb := Nav.bubbles
	var said: Bubbles.Bubble = null
	if Nav.field_screen != null and bb.field.size.x > 0.0:
		said = bb.say("Тест", "Проверка размера текста в пузыре.", bb.field.get_center(), false)
	ok += _expect(fails, said != null and said.fsize == ThemeFactory.fs(Bubbles.FONT_SIZE) and said.fsize > Bubbles.FONT_SIZE, "пузыри не крупнее при большом тексте")
	Save.set_text_size(0)
	Nav.ui.theme = ThemeFactory.build()

	# 2. Глаз подозрения: на каждом уровне своё число штрихов
	var cr := Nav.village.crowd
	var bot: Villager = Game.m.alive_bots()[0]
	var f: VillagerFigure = cr.figures[bot.id]
	var strokes: Array[int] = []
	for lvl in range(1, 5):
		f.set_marks(lvl, PackedStringArray(), false)
		f.queue_redraw()
		await _frames(tree, 2)
		strokes.append(f.drawn_strokes)
	ok += _expect(fails, str(strokes) == "[1, 2, 3, 4]", "у глаза не различается число штрихов по уровню: %s" % str(strokes))

	# 3. Улики: у каждой свой силуэт рамки, и рамка правда рисуется
	var shapes := {}
	for b: String in Director.BADGES:
		# силуэт по геометрии: число вершин и габариты рамки
		var pts := VillagerFigure.badge_outline(b, Vector2.ZERO)
		var ext := Rect2(pts[0], Vector2.ZERO)
		for q: Vector2 in pts:
			ext = ext.expand(q)
		var key := "%d:%dx%d" % [pts.size(), roundi(ext.size.x), roundi(ext.size.y)]
		shapes[key] = b
	ok += _expect(fails, shapes.size() == Director.BADGES.size(), "у улик одинаковые силуэты: %s" % str(shapes.keys()))
	var drawn := {}
	for i in range(0, Director.BADGES.size(), 2):
		var pair := PackedStringArray([Director.BADGES[i], Director.BADGES[mini(i + 1, Director.BADGES.size() - 1)]])
		f.set_marks(0, pair, false)
		f.queue_redraw()
		await _frames(tree, 2)
		for k in range(f.drawn_frames.size()):
			drawn[pair[k]] = f.drawn_frames[k]
	var same_ok := true
	for b: String in Director.BADGES:
		if int(drawn.get(b, -1)) != VillagerFigure.badge_outline(b, Vector2.ZERO).size():
			same_ok = false
	ok += _expect(fails, same_ok, "рамки улик рисуются не своим силуэтом: %s" % str(drawn))
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "доступность", "три размера текста, глаз со штрихами, у каждой улики свой силуэт")


# =============================================================
# Испытание дня (задача 47): одно правило на дату, одна попытка, серия дней, кнопка в меню
# =============================================================
static func daily() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	Save.daily_last = ""
	Save.daily_streak = 0
	var today := Challenge.today()

	# 1. Правило — от даты: пять дней подряд дают пять разных правил, одна дата — одно правило и посёлок
	var seen := {}
	for i in range(Challenge.RULES.size()):
		seen[Challenge.rule_for(_shift_date(today, i))] = true
	ok += _expect(fails, seen.size() == Challenge.RULES.size(), "правила не идут по кругу: %s" % str(seen.keys()))
	var m1 := Match.new()
	m1.rule = Challenge.rule_for(today)
	m1.start(Challenge.config(m1.rule), Challenge.seed_for(today))
	var m2 := Match.new()
	m2.rule = Challenge.rule_for(today)
	m2.start(Challenge.config(m2.rule), Challenge.seed_for(today))
	var same := true
	for i in range(m1.villagers.size()):
		if m1.villagers[i].name != m2.villagers[i].name or m1.villagers[i].is_upyr != m2.villagers[i].is_upyr or m1.villagers[i].role != m2.villagers[i].role:
			same = false
	var seeds := {}
	for i in range(400):
		seeds[Challenge.seed_for(_shift_date(today, i))] = true
	ok += _expect(fails, same and seeds.size() == 400, "у одной даты разные посёлки или у разных дат одно зерно (%d разных на 400 дней)" % seeds.size())

	# 2. Каждое правило правда меняет партию
	for rule: String in Challenge.RULES:
		var m := Match.new()
		m.rule = rule
		m.start(Challenge.config(rule), 77)
		m.begin_day()
		m.end_day()
		if m.phase == Match.Phase.VOTE:
			m.apply_vote({} as Dictionary[int, int])
			m.after_vote()
		var upyrs := 0
		for v: Villager in m.villagers:
			if v.is_upyr:
				upyrs += 1
		match rule:
			"no_elder":
				ok += _expect(fails, m.role_holder(Match.Role.ELDER) == null, "в испытании без старожила старожил есть")
			"three_upyr":
				ok += _expect(fails, upyrs == 3, "в испытании трёх упырей их %d" % upyrs)
			_:
				ok += _expect(fails, m.phase == Match.Phase.NIGHT and m.night_event == Challenge.night_event(rule), "«%s»: в первую ночь нет своего события (%d)" % [rule, m.night_event])
	# 3. Баланс каждого правила: люди выигрывают от 25 до 75% партий
	for rule: String in Challenge.RULES:
		var r := balance(Challenge.config(rule), 300, rule)
		print("испытание %s: люди побеждают в %.0f%%" % [rule, 100.0 * r.people_win])
		ok += _expect(fails, r.people_win >= 0.25 and r.people_win <= 0.75, "испытание «%s» вне коридора: людей %.0f%%" % [rule, 100.0 * r.people_win])

	# 4. Кнопка в меню запускает испытание дня
	Nav.show_menu()
	await _settle(tree)
	var db := Nav.host.current.find_child("Daily", true, false) as Button
	ok += _expect(fails, db != null and not db.disabled and db.text.contains(Challenge.title(Challenge.rule_for(today))), "в меню нет кнопки испытания дня с сегодняшним правилом")
	var win_streak0 := Save.win_streak
	var diff0 := Save.difficulty
	if db != null:
		db.pressed.emit()
	await _settle(tree)
	ok += _expect(fails, Game.daily == today and Game.m != null and Game.m.rule == Challenge.rule_for(today), "кнопка не начала испытание дня")
	ok += _expect(fails, Nav.host.current.find_child("Daily", true, false) != null, "в прологе не сказано про правило дня")
	# 5. Итог сохраняется, лестница сложности не трогается
	var human := not Game.m.player().is_upyr
	Game.m.winner = Match.Team.PEOPLE if human else Match.Team.UPYRI
	Game.m.phase = Match.Phase.MORNING
	Game.m.end_morning()
	await _settle(tree)
	ok += _expect(fails, Save.daily_last == today and Save.daily_won and Save.daily_streak == 1, "итог испытания не сохранился (%s, %s, %d)" % [Save.daily_last, Save.daily_won, Save.daily_streak])
	ok += _expect(fails, Save.win_streak == win_streak0 and Save.offer == "" and Save.difficulty == diff0, "испытание сдвинуло лестницу сложности")
	ok += _expect(fails, Nav.host.current.find_child("Daily", true, false) != null, "на финале нет итога испытания")
	var cf := ConfigFile.new()
	cf.load(Save.SETTINGS_PATH)
	ok += _expect(fails, String(cf.get_value("daily", "last", "")) == today, "итог испытания не записан в файл")
	# 6. Одна попытка: повтор не начинается и не перезаписывает итог
	Nav.show_menu()
	await _settle(tree)
	db = Nav.host.current.find_child("Daily", true, false) as Button
	ok += _expect(fails, db != null and db.disabled and db.text.contains(L.t("daily.won")), "после испытания кнопка не показывает итог")
	ok += _expect(fails, not Nav.start_daily() and not Save.record_daily(today, false) and Save.daily_won, "испытание можно пройти второй раз")
	# 7. Серия: вчера сыграл — +1, пропустил день — заново
	Save.daily_last = _shift_date(today, -1)
	Save.daily_streak = 3
	ok += _expect(fails, Save.daily_streak_on(today) == 3, "серия пропала до сегодняшней игры")
	Save.record_daily(today, true)
	ok += _expect(fails, Save.daily_streak == 4, "серия не выросла после вчерашнего (%d)" % Save.daily_streak)
	Save.daily_last = _shift_date(today, -3)
	ok += _expect(fails, Save.daily_streak_on(today) == 0, "серия не прервалась после пропуска")
	Save.record_daily(today, false)
	ok += _expect(fails, Save.daily_streak == 1, "после пропуска серия не началась заново (%d)" % Save.daily_streak)
	Save.daily_last = ""
	Save.daily_streak = 0
	Save.flush()
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "испытание дня", "правило по дате у всех одно, одна попытка, итог и серия сохраняются, баланс в коридоре")


## Дата со сдвигом на n дней: «2026-10-11» + 1 → «2026-10-12».
static func _shift_date(date: String, n: int) -> String:
	var t := Time.get_unix_time_from_datetime_string(date + "T12:00:00") + n * 86400
	return Time.get_date_string_from_unix_time(t)


# =============================================================
# Косметика (задача 48): фонари и шапки за победы и испытания, только картинка
# =============================================================
static func cosmetics() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	var stats0 := Save.stats.duplicate()
	var bonds0: Dictionary[String, int] = Save.anchor_bonds.duplicate()
	Save.stats["wins"] = 0
	Save.daily_wins = 0
	Save.daily_best = 0
	Save.anchor_bonds = {"0": 0, "1": 0, "2": 0}
	Save.lantern = "classic"
	Save.hat = "own"
	Save.brooch = "none"

	# 1. С нуля открыто только своё; закрытое не надевается
	var open0 := Cosmetics.open_ids()
	ok += _expect(fails, open0.size() == 6 and open0.has("lantern:classic") and open0.has("hat:own") and open0.has("brooch:seal"), "с нуля неверный набор: %s" % ", ".join(open0))
	ok += _expect(fails, not Save.wear("lantern", "copper") and Save.lantern == "classic", "закрытый фонарь надевается")
	ok += _expect(fails, not Cosmetics.is_open(Cosmetics.item("hat", "flower")) and Cosmetics.is_open(Cosmetics.item("hat", "flower"), {"bond": 6}), "венок не открывается доверием к постоянным жителям")
	ok += _expect(fails, Cosmetics.is_open(Cosmetics.item("hat", "flower"), {"streak": 5}) and not Cosmetics.is_open(Cosmetics.item("hat", "flower"), {"streak": 4}), "венок, открытый прежней серией из пяти дней, потерян")
	for it: Dictionary in Cosmetics.LANTERNS + Cosmetics.HATS:
		if not it.need.is_empty() and Cosmetics.need_text(it) == "":
			fails.append("у «%s» не написано, как открыть" % it.id)

	# 2. Победа открывает медный фонарь — на финале об этом сказано
	Save.set_difficulty("normal")
	await _finish_match(tree, true)
	ok += _expect(fails, Game.new_items.has("lantern:copper"), "победа не открыла медный фонарь: %s" % ", ".join(Game.new_items))
	ok += _expect(fails, Nav.host.current is EndScreen and Nav.host.current.find_child("NewItems", true, false) != null, "на финале не сказано, что открылось")

	# 3. Шкаф: открытые надеваются, закрытые серые с условием
	Save.stats["wins"] = 3
	Save.daily_wins = 1
	Nav.show_wardrobe()
	await _settle(tree)
	var ws := Nav.host.current as WardrobeScreen
	var lg := ws.find_child("Grid_lantern", true, false) as GridContainer
	var hg := ws.find_child("Grid_hat", true, false) as GridContainer
	var bg := ws.find_child("Grid_brooch", true, false) as GridContainer
	ok += _expect(fails, lg != null and hg != null and bg != null and lg.get_child_count() == Cosmetics.LANTERNS.size() and hg.get_child_count() == Cosmetics.HATS.size() and bg.get_child_count() == Cosmetics.BROOCHES.size(), "в шкафу не все вещи")
	var frost := ws.find_child("lantern_frost", true, false) as Button
	ok += _expect(fails, frost != null and frost.disabled and frost.text.contains(Cosmetics.need_text(Cosmetics.item("lantern", "frost"))), "закрытый фонарь без условия или нажимается")
	(ws.find_child("lantern_paper", true, false) as Button).pressed.emit()
	await _settle(tree)
	ws = Nav.host.current as WardrobeScreen
	(ws.find_child("hat_top_hat", true, false) as Button).pressed.emit()
	await _settle(tree)
	ws = Nav.host.current as WardrobeScreen
	(ws.find_child("brooch_sun", true, false) as Button).pressed.emit()
	await _settle(tree)
	ws = Nav.host.current as WardrobeScreen
	ok += _expect(fails, Save.lantern == "paper" and Save.hat == "top_hat" and Save.brooch == "sun", "вещи не надеваются (%s, %s, %s)" % [Save.lantern, Save.hat, Save.brooch])
	ok += _expect(fails, ws.preview.look.head == LookDef.Head.TOP_HAT and ws.preview.lantern_id == "paper", "в примерке не видно надетого")
	ok += _expect(fails, (ws.find_child("hat_top_hat", true, false) as Button).theme_type_variation == &"RowOn", "надетая шапка не подсвечена")
	var cf := ConfigFile.new()
	cf.load(Save.SETTINGS_PATH)
	ok += _expect(fails, String(cf.get_value("look", "lantern", "")) == "paper" and String(cf.get_value("look", "hat", "")) == "top_hat" and String(cf.get_value("look", "brooch", "")) == "sun", "выбор не сохранился")

	# 4. В партии твой житель в цилиндре и с бумажным фонарём; у других всё как было
	Nav.start_match()
	await _settle(tree)
	var me: VillagerFigure = Nav.village.crowd.figures[0]
	var style: Dictionary = me.pose_now()[1].get("lantern_style", {})
	ok += _expect(fails, me.look.head == LookDef.Head.TOP_HAT and String(style.get("shape", "")) == "paper" and me.brooch_id == "sun", "на поле житель не в своём (шапка %d, фонарь %s)" % [me.look.head, style.get("shape", "")])
	var other: VillagerFigure = Nav.village.crowd.figures[1]
	ok += _expect(fails, not other.pose_now()[1].has("lantern_style"), "фонарь игрока достался боту")
	# фонарь героя меняет цвет стекла на самой картинке (без наклеек поверх), рост с шапкой тот же
	var base_lantern := Vector2.ZERO
	var heights_ok := true
	for hat: String in ["own", "top_hat", "beret", "straw", "ushanka", "flower", "jester"]:
		me.set_hero_hat(hat)
		var lp := me._hero_lantern_pos()
		if hat == "own":
			base_lantern = lp
		elif absf(lp.y - base_lantern.y) > 7.0:
			heights_ok = false
	ok += _expect(fails, heights_ok, "с шапкой герой другого роста: фонарь в руке съезжает по высоте")
	me.set_hero_hat("own")
	me.set_lantern("frost")
	me.body.queue_redraw()
	await _frames(tree, 2)
	var mat := me._door_rig.material as ShaderMaterial
	var lr := VillagerFigure.lantern_rect(me._hero_texture())
	ok += _expect(fails, mat != null and float(mat.get_shader_parameter("strength")) > 0.5 and lr.size.x > 0.02 and lr.size.x < 0.5,
		"ледяной фонарь не перекрасил фонарь на картинке героя (рамка %s)" % lr)
	me.set_lantern("classic")
	me.body.queue_redraw()
	await _frames(tree, 2)
	ok += _expect(fails, me._door_rig.material == null, "у обычного фонаря остался перекрас")
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	await _settle(tree)
	var first_resident := Game.m.alive_bots()[0]
	Game.personal_talk(first_resident.id, 0)
	ok += _expect(fails, Game.first_contact and Game.inspection_bonus == 1, "первый разговор не дал третий осмотр")
	Game.personal_talk(first_resident.id, 0)
	ok += _expect(fails, Game.inspection_bonus == 1, "повторный разговор начислил лишний осмотр")

	# 5. На партию не влияет: игра и боты не знают о вещах, итоги прогона те же
	var clean := true
	for path: String in ["res://scripts/core/match.gd", "res://scripts/ai/director.gd", "res://scripts/ai/bot_brain.gd", "res://scripts/core/game_config.gd"]:
		var src := FileAccess.get_file_as_string(path)
		if src.contains("Cosmetics") or src.contains("Save.lantern") or src.contains("Save.hat"):
			clean = false
	ok += _expect(fails, clean, "правила или боты читают косметику")
	var cfg := Difficulty.preset("normal")
	var r1 := balance(cfg, 60)
	Save.lantern = "classic"
	Save.hat = "own"
	Save.brooch = "none"
	var r2 := balance(cfg, 60)
	ok += _expect(fails, r1.people_win == r2.people_win and r1.avg_nights == r2.avg_nights, "косметика меняет исход партий")

	Save.stats = stats0
	Save.daily_wins = 0
	Save.daily_best = 0
	Save.anchor_bonds = bonds0
	Save.lantern = "classic"
	Save.hat = "own"
	Save.flush()
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "косметика", "фонари и шапки открываются победами и испытаниями, видны на поле, на исход не влияют")


# =============================================================
# Подстройка ботов (задача 49): проигрываешь подряд — боты поддаются, часто выигрываешь — собираются.
# Ступень сложности при этом не меняется; баланс проверяется на каждой ступени.
# =============================================================
static func adapt() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	var recent0 := Save.recent.duplicate()
	var diff0 := Save.difficulty

	# 1. Когда боты поддаются, а когда собираются
	var cases := [[[1, 0, 0], 0.0], [[1, 0, 0, 0], -0.5], [[0, 0, 0, 0, 0], -1.0], [[1, 0, 1, 0, 1, 0], 0.0],
		[[1, 1, 1, 1, 0, 1, 1, 1, 0, 1], 0.5], [[1, 1, 1, 1, 1], 1.0]]
	for c: Array in cases:
		Save.recent = PackedInt32Array(c[0])
		ok += _expect(fails, is_equal_approx(Save.tune(), float(c[1])), "по итогам %s подстройка %.2f, ждали %.2f" % [str(c[0]), Save.tune(), c[1]])
	# три поражения подряд через настоящую запись итогов; ступень та же
	Save.set_difficulty("normal")
	Save.recent = PackedInt32Array([1, 1])
	for i in range(3):
		Save.record_result(false, false)
	ok += _expect(fails, Save.tune() < 0.0 and Save.difficulty == "normal", "после трёх поражений боты не поддаются или сменилась ступень")
	var cf := ConfigFile.new()
	cf.load(Save.SETTINGS_PATH)
	ok += _expect(fails, String(cf.get_value("game", "recent", "")).ends_with("0,0,0"), "итоги для подстройки не сохраняются")

	# 2. Партия берёт подстройку; испытание дня — нет
	Nav.start_match()
	await _settle(tree)
	ok += _expect(fails, Game.director.tune == Save.tune(), "партия не взяла подстройку")
	Game.start(Challenge.config("fog"), "2026-10-11")
	await _settle(tree)
	ok += _expect(fails, Game.director.tune == 0.0, "испытание дня подстроилось под игрока")

	# 3. Чем именно поддаются: ложь упыря слабее, хозяин-человек ошибается чаще
	var m := Match.new()
	m.start(Difficulty.preset("normal"), 5)
	var d := Director.new()
	d.attach(m)
	m.player().is_upyr = false
	d.tune = -1.0
	var weak := d.lie_weight(Director.W_FAKE)
	d.tune = 1.0
	var strong := d.lie_weight(Director.W_FAKE)
	ok += _expect(fails, weak < Director.W_FAKE and strong > Director.W_FAKE, "ложь упыря не зависит от подстройки (%.2f / %.2f)" % [weak, strong])
	var host: Villager = null
	for v: Villager in m.villagers:
		if not v.is_upyr and not v.is_player:
			host = v
	m.player().is_upyr = true
	d.tune = -1.0
	var n_easy := d.door_noise(host)
	d.tune = 1.0
	var n_hard := d.door_noise(host)
	ok += _expect(fails, n_easy > 0.4 and n_hard < 0.4, "хозяин-человек ошибается у двери одинаково (%.2f / %.2f)" % [n_easy, n_hard])
	# и правда ошибается: из двух гостей пускает подозрительного то чаще, то реже
	var guests: Array[Villager] = []
	for v: Villager in m.villagers:
		if not v.is_player and v != host and guests.size() < 2:
			guests.append(v)
	d.public_susp[guests[0].id] = 0.5
	d.public_susp[guests[1].id] = 0.0
	var wrong := {}
	for t: float in [-1.0, 1.0]:
		d.tune = t
		var n := 0
		for i in range(400):
			var seat := Match.Seat.new()
			seat.house = 0
			seat.host = host
			seat.queue = [guests[0], guests[1]] as Array[Villager]
			var ids := d.host_decide(seat)
			if ids.size() == 1 and ids[0] == guests[0].id:
				n += 1
		wrong[t] = n
	ok += _expect(fails, int(wrong[-1.0]) > int(wrong[1.0]) and int(wrong[-1.0]) > 10, "ошибки у двери не зависят от подстройки (%s)" % str(wrong))

	# 4. Баланс на каждой ступени: поддавки помогают игроку за обе стороны, собранность мешает
	for diff: String in Difficulty.LADDER:
		var cfg := Difficulty.preset(diff)
		var r: Array[Dictionary] = []
		for t: float in [-1.0, 0.0, 1.0]:
			r.append(balance(cfg, 500, "", t))
		print("%s: человек %.0f / %.0f / %.0f%%, упырь %.0f / %.0f / %.0f%% (поддавки / как есть / собранные)" % [diff,
			100 * r[0].human_win, 100 * r[1].human_win, 100 * r[2].human_win, 100 * r[0].upyr_win, 100 * r[1].upyr_win, 100 * r[2].upyr_win])
		ok += _expect(fails, r[0].human_win > r[1].human_win and r[1].human_win > r[2].human_win, "%s: подстройка не меняет шансы игрока-человека" % diff)
		if not cfg.player_always_human:
			# В 500 партиях за упыря выпадает около 150 ролей: соседние оценки могут
			# различаться на пару пунктов из-за выбора роли и домов по seed.
			ok += _expect(fails, r[0].upyr_win > r[2].upyr_win + 0.03 and r[0].upyr_win + 0.03 >= r[1].upyr_win and r[1].upyr_win + 0.03 >= r[2].upyr_win, "%s: подстройка не меняет шансы игрока-упыря" % diff)
		# подстройка мягкая: шанс игрока сдвигается не больше чем на 20 пунктов
		for x: Dictionary in [r[0], r[2]]:
			ok += _expect(fails, absf(x.human_win - r[1].human_win) <= 0.2 and absf(x.upyr_win - r[1].upyr_win) <= 0.2, "%s: подстройка слишком резкая" % diff)
		# на обычной и сложной общий баланс остаётся в коридоре 25–75% при любой подстройке
		if diff != "easy":
			for x: Dictionary in r:
				ok += _expect(fails, x.people_win >= 0.25 and x.people_win <= 0.75, "%s: баланс вне коридора при подстройке (%.0f%%)" % [diff, 100 * x.people_win])

	Save.recent = recent0
	Save.set_difficulty(diff0 if Difficulty.PRESETS.has(diff0) else "easy")
	Save.flush()
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "подстройка ботов", "три поражения — боты поддаются, частые победы — собираются, ступень та же, баланс на каждой ступени в коридоре")


# =============================================================
# Жесты без слов (задача 50): долгое нажатие на жителя — показать пальцем, «верю», «не верю»
# =============================================================
static func gestures() -> void:
	var tree := Nav.get_tree()
	var fails: PackedStringArray = []
	var ok := 0
	tree.root.size = Vector2i(1080, 2340)
	await _frames(tree, 3)
	Nav.frame.refresh()
	Save.set_difficulty("normal")
	Nav.start_match()
	await _settle(tree)
	Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
	Game._feed_gen += 1
	await _settle(tree)
	var day: DayScreen = Nav.host.current as DayScreen
	var m := Game.m
	var d := Game.director
	var cr := Nav.village.crowd
	var target: Villager = m.alive_bots()[1]
	var tf: VillagerFigure = cr.figures[target.id]
	var at: Vector2 = tf.hit_rect_global().get_center() - day.field_spacer.get_global_rect().position

	# 1. Долгое нажатие открывает жесты, отпускание после него — не тап
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	day._on_field_tap_input(press)
	await tree.create_timer(Screen.HOLD_SEC + 0.15).timeout
	var sheets: Array[Node] = day.find_children("*", "ActionSheet", true, false)
	ok += _expect(fails, sheets.size() == 1 and _all_text(sheets[0]).contains(target.name) and _all_text(sheets[0]).contains(L.t("gest.trust")), "долгое нажатие не открыло жесты")
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	day._on_field_tap_input(release)
	await _frames(tree, 2)
	ok += _expect(fails, day.find_children("*", "ActionSheet", true, false).size() == 1, "отпускание после жеста открыло ещё и обычное меню")
	# короткий тап по-прежнему открывает обычное меню, а не жесты
	if not sheets.is_empty():
		(sheets[0] as ActionSheet).close(-1)
	await _frames(tree, 2)
	var tap := press.duplicate() as InputEventMouseButton
	day._on_field_tap_input(tap)
	day._on_field_tap_input(release)
	await _frames(tree, 3)
	var tap_sheets: Array[Node] = day.find_children("*", "ActionSheet", true, false)
	ok += _expect(fails, tap_sheets.size() == 1 and _all_text(tap_sheets[0]).contains(L.t("day.p_ask")), "короткий тап не открыл обычное меню жителя")
	for sh: Node in tap_sheets:
		(sh as ActionSheet).close(-1)
	# повёл пальцем — не жест
	day._on_field_tap_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = at + Vector2(60, 0)
	day._on_field_tap_input(drag)
	await tree.create_timer(Screen.HOLD_SEC + 0.15).timeout
	ok += _expect(fails, day.find_children("*", "ActionSheet", true, false).is_empty(), "жест открылся, хотя палец сдвинулся")
	day._on_field_tap_input(release)
	await _frames(tree, 2)
	ok += _expect(fails, day.find_children("*", "ActionSheet", true, false).is_empty(), "отпускание после движения открыло меню")
	for sh: Node in day.find_children("*", "ActionSheet", true, false):
		(sh as ActionSheet).close(-1)
	await _frames(tree, 2)

	# 2. Показать пальцем: ты указываешь, он вздрагивает, посёлок чуть больше его подозревает, он отвечает
	Game.hold(&"test")
	var s0 := d.susp(target.id)
	Nav.handle_intent(Intent.GESTURE, {"kind": "point", "id": target.id}, day)
	await _frames(tree, 2)
	var me: VillagerFigure = cr.figures[0]
	ok += _expect(fails, me.pose_now()[1].get("point", false) and tf.emotion == "shocked", "жест не виден: игрок не показывает пальцем или житель не вздрогнул")
	ok += _expect(fails, is_equal_approx(d.susp(target.id), s0 + Director.GEST_POINT), "палец не добавил подозрений (%.2f → %.2f)" % [s0, d.susp(target.id)])
	ok += _expect(fails, m.chat.back().kind == ChatLine.Kind.SYSTEM and m.chat.back().text.contains(_ru_case("acc", target.name)), "жеста нет в журнале")
	Game.release(&"test")
	var replied := false
	var pointed: Array = []      # реплики с подставленным родом: «[сделал|сделала]» → как сказал бы этот житель
	for tpl: String in Phrases.b("GEST_POINTED") + Voices.lines(target.persona, "GEST_POINTED"):   # общий банк и свой голос
		pointed.append(L.fill(tpl, {"me": target}))
	var wait_until := Time.get_ticks_msec() + 12000   # по часам, а не по кадрам: под нагрузкой кадры идут иначе
	while Time.get_ticks_msec() < wait_until:
		for l: ChatLine in m.chat:
			if l.speaker == target and pointed.has(l.text):
				replied = true
		if replied:
			break
		await tree.process_frame
	ok += _expect(fails, replied, "житель не ответил на палец")
	Game.hold(&"test")
	Nav.handle_intent(Intent.GESTURE, {"kind": "point", "id": target.id}, day)
	ok += _expect(fails, is_equal_approx(d.susp(target.id), s0 + Director.GEST_POINT), "повторный палец снова добавил подозрений")

	# 3. «Верю»: этот житель лучше думает о тебе (охотнее пустит); «не верю»: подозрение и обида
	var friend: Villager = m.alive_bots()[2]
	var v0 := d.view(friend, m.player())
	Nav.handle_intent(Intent.GESTURE, {"kind": "trust", "id": friend.id}, day)
	ok += _expect(fails, d.view(friend, m.player()) < v0 - 0.5, "«верю» не изменило отношение жителя к тебе")
	ok += _expect(fails, (cr.figures[friend.id] as VillagerFigure).emotion == "relieved", "на «верю» житель не ответил лицом")
	var foe: Villager = m.alive_bots()[3]
	var f0 := d.susp(foe.id)
	var g0: float = d.brains[foe.id].grudge.get(0, 0.0)
	Nav.handle_intent(Intent.GESTURE, {"kind": "distrust", "id": foe.id}, day)
	ok += _expect(fails, d.susp(foe.id) > f0 and float(d.brains[foe.id].grudge.get(0, 0.0)) > g0, "«не верю» ничего не изменило")
	var lines := d.gesture("distrust", foe)
	ok += _expect(fails, lines.size() >= 1 and lines[0].speaker == foe, "житель не отвечает на «не верю»")
	Game.release(&"test")
	# 4. Ночью и мёртвым жесты не работают
	Game.m.phase = Match.Phase.VOTE
	var other: Villager = m.alive_bots()[4]
	var s1 := d.susp(other.id)
	Game.gesture("point", other.id)
	ok += _expect(fails, d.susp(other.id) == s1, "жест сработал не днём")
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "жесты", "долгое нажатие — палец, «верю», «не верю»; видно на поле, есть в журнале, боты отвечают и запоминают")
