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
	print("ИТОГ: %s" % ("OK" if ok else "БАЛАНС ВНЕ КОРИДОРА 30–70%, ИГРОК НЕ ВИДИТ ОДНУ ИЗ РОЛЕЙ У ДВЕРИ ИЛИ ОШИБКИ В ТЕКСТАХ"))
	tree.quit(0 if ok else 1)


## Грамматика реплик и хроники: «Рита был», «на Женя», недоставленные метки, «Вы» в третьем лице.
static func grammar(cfg: GameConfig, games: int = 250) -> Dictionary:
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
							for line: String in Phrases.JOB_FAKE:
								texts.append(Phrases.fill(line, {"who": t.name, "who_f": t.female, "me_f": false, "place": j.place}))
								texts.append(Phrases.fill(line, {"who": t.name, "who_f": t.female, "me_f": true, "place": j.place}))
							for line: String in Phrases.JOB_FAKE_AT_PLAYER:
								texts.append(Phrases.fill(line, {"me_f": t.female, "place": j.place}))
					# Подражатель, саботаж, ящик: все реплики для каждого жителя
					for t: Villager in m.villagers:
						if t.is_player:
							continue
						for line: String in Phrases.MIMIC_PLEAS:
							texts.append(Phrases.fill(line, {"who": t.name, "me_f": t.female}))
						for line: String in Phrases.SABOTAGE_SEEN:
							texts.append(Phrases.fill(line, {"who": t.name, "who_f": t.female, "me_f": not t.female, "place": "у колодца"}))
						for line: String in Phrases.SABOTAGE_SEEN_AT_PLAYER:
							texts.append(Phrases.fill(line, {"me_f": t.female, "place": "у колодца"}))
						for bank: PackedStringArray in [Phrases.BOX_NOTE, Phrases.BOX_OIL, Phrases.BOX_CHALK]:
							for line: String in bank:
								texts.append(Phrases.fill(line, {"me_f": t.female, "a": t.name, "b": "Вы", "house": m.houses[0]}))
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

	var fem := "(?:" + "|".join(Match.FEMALE) + ")"
	var males: PackedStringArray = []
	for n: String in Match.NAMES:
		if not Match.FEMALE.has(n):
			males.append(n)
	var mal := "(?:" + "|".join(males) + ")"
	var all_names := "(?:" + "|".join(Match.NAMES) + ")"
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
	for h: String in Match.HOUSES:
		if Ru.house_in(h).is_empty() or Ru.house_of(h).is_empty() or Ru.house_in(h) == h:
			errors.append("нет падежей для убежища «%s»: где «%s», чего «%s»" % [h, Ru.house_in(h), Ru.house_of(h)])
	var seen: Dictionary[String, bool] = {}
	for t: String in texts:
		for r: Array in rules:
			if (r[0] as RegEx).search(t) != null and not seen.has(t):
				seen[t] = true
				errors.append("%s: «%s»" % [r[1], t])
	return {"checked": texts.size(), "errors": errors}


## Прогон партий без экрана. Игрок ходит случайно — это нижняя граница его силы.
static func balance(cfg: GameConfig, runs: int = 3000) -> Dictionary:
	var wins := 0
	var nights := 0
	var guest_turns := 0
	var host_turns := 0
	for g in range(runs):
		var m := Match.new()
		var d := Director.new()
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
	return {
		"runs": runs,
		"people_win": float(wins) / runs,
		"avg_nights": float(nights) / runs,
		"player_host": host_turns,
		"player_guest": guest_turns,
	}


## Прогон через настоящие экраны и настоящие обработчики Nav и Game.
## Требует, чтобы игрок побывал во ВСЕХ ролях у двери. Иначе — код выхода 1.
static func flow() -> void:
	var tree := Nav.get_tree()
	var seen: Dictionary[String, int] = {}
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
							var ids: Array[int] = [ds.seat.knockers()[0].id]
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
	print("=== экраны: %d партий, записано в статистику: %d ===" % [matches, recorded])
	print("посещено: " + ", ".join(keys))
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
					var ids: Array[int] = [ds.seat.queue[0].id]
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
	return n


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
		if not c.is_visible_in_tree() or c is ActionSheet:
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
			var need := f.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
			if r.size.x + 1.0 < need:
				out.append("%s: текст на кнопке обрезан: «%s» (%d px из нужных %d)" % [w, b.text.replace("\n", " ").left(30), int(r.size.x), int(need)])
	return 1


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
	for i in range(mini(vd.shelters.size(), Match.HOUSES.size())):
		ok += _expect(fails, vd.shelters[i].title == Match.HOUSES[i],
			"убежище %d в ресурсе «%s», а в правилах «%s»" % [i, vd.shelters[i].title, Match.HOUSES[i]])

	Nav.show_menu()
	await _settle(tree)
	ok += _expect(fails, v.modulate.a > 0.9, "в меню посёлок не виден")
	ok += _expect(fails, v.open_shelters() == Save.config.shelters and v.boarded_shelters() == 5 - Save.config.shelters,
		"открыто убежищ %d, заколочено %d — а по балансу открыто %d" % [v.open_shelters(), v.boarded_shelters(), Save.config.shelters])
	ok += _expect(fails, v.fog().emitting and v.fog().amount >= 10 and v.fog().initial_velocity_min > 0.0,
		"туман не идёт или стоит на месте")
	ok += _expect(fails, v.dust().emitting, "пыль не летит")

	var d0 := v.draws
	await _frames(tree, 60)
	ok += _expect(fails, v.draws - d0 <= 1, "посёлок перерисовывается в покое: %d раз за 60 кадров" % (v.draws - d0))
	await tree.create_timer(1.8).timeout
	ok += _expect(fails, Engine.max_fps == Juice.FPS_IDLE, "в покое %d fps вместо %d" % [Engine.max_fps, Juice.FPS_IDLE])

	Nav.start_match()
	await _settle(tree)
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
		var d := (f.position - sq) / v.def.square_radii
		if d.length() > 1.0:
			inside = false
	ok += _expect(fails, inside, "кто-то из жителей стоит за пределами площади")

	# дыхание: 8 замеров за секунду — размах масштаба тела. Два замера давали ложные провалы,
	# когда попадали симметрично по разные стороны от вершины вдоха.
	var probe: VillagerFigure = cr.figures[1]
	var lo_b := 9.0
	var hi_b := 0.0
	for k in range(8):
		await tree.create_timer(0.13).timeout
		lo_b = minf(lo_b, probe.body_scale().y)
		hi_b = maxf(hi_b, probe.body_scale().y)
	ok += _expect(fails, hi_b - lo_b > 0.01, "жители не дышат (размах масштаба тела %.3f)" % (hi_b - lo_b))

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
	ok += _expect(fails, hi > 1.08 and lo < 0.86, "бег без пружины: растяжение %.2f, сжатие %.2f" % [hi, lo])
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
	for hi in range(vv.open_count):
		var plaque := vv.shelter_label_rect_global(hi).grow(-1.0)
		for f: VillagerFigure in figs:
			if plaque.intersects(f.body_rect_global().grow(-2.0)) or plaque.intersects(f.label_rect_global().grow(-1.0)):
				out.append("%s: табличку «%s» закрывает %s" % [tag, vv._title(hi), f.who])
	for i in range(figs.size()):
		for j in range(figs.size()):
			if i == j:
				continue
			var a := figs[i]
			var b := figs[j]
			var la := a.label_rect_global().grow(-1.0)
			if j > i and la.intersects(b.label_rect_global().grow(-1.0)):
				out.append("%s: имена «%s» и «%s» налезают друг на друга" % [tag, a.who, b.who])
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
	for bank: PackedStringArray in [Phrases.ACCUSE_STRONG, Phrases.UPYR_DEFLECT, Phrases.DEFEND, Phrases.FILLER, Phrases.ANNOUNCE]:
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
		Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
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
			if newest == null or newest.who != Ru.nom(who):
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
	await _settle(tree)
	var cr := Nav.village.crowd
	var day := Nav.host.current as DayScreen
	var clean := true
	for f: VillagerFigure in cr.figures.values():
		if f.eye_level != 0 or not f.badges.is_empty():
			clean = false
	ok += _expect(fails, clean, "в начале партии у кого-то уже есть глаз или значки")

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

	# тап по жителю → шторка про него → обвинить → глаз изменился, ответил
	var bots := Game.m.alive_bots()
	var target: Villager = bots[0]
	var before: int = cr.figures[target.id].eye_level
	Nav.handle_intent(Intent.FIELD_TAP, {"pos": cr.figures[target.id].hit_rect_global().get_center()}, day)
	await _frames(tree, 2)
	var sh := _sheet(day)
	var title_ok := false
	if sh != null:
		for c: Node in sh.get_children():
			for l: Node in c.get_children():
				for t in l.get_children():
					if t is Label and (t as Label).text.begins_with(target.name):
						title_ok = true
	ok += _expect(fails, sh != null and title_ok, "тап по %s не открыл шторку с его именем" % target.name)
	var chat_before := Game.m.chat.size()
	if sh != null:
		sh.close(0)
	await _frames(tree, 4)
	ok += _expect(fails, cr.figures[target.id].eye_level > before,
		"обвинили %s — глаз не изменился (%d → %d)" % [Ru.accusative(target.name), before, cr.figures[target.id].eye_level])
	var replied := false
	for i in range(chat_before, Game.m.chat.size()):
		if Game.m.chat[i].speaker == target:
			replied = true
	ok += _expect(fails, replied, "обвинённый %s не ответил" % target.name)

	# позвать с собой — кто-нибудь согласится; кольцо уговора; ночью вместе к одной двери
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
		Nav.handle_intent(Intent.CONTINUE, {}, Nav.host.current)
		await _settle(tree)
		var tag := "%d×%d" % [sz.x, sz.y]
		var day := Nav.host.current as DayScreen
		var vp := Nav.frame.get_viewport_rect().size

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
	ok += _expect(fails, Game.m.phase != Match.Phase.NIGHT and Game.m.player().night_house == 1, "бег не привёл во второй дом (дом %d, фаза %s)" % [Game.m.player().night_house, Match.Phase.keys()[Game.m.phase]])
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
	ok += _expect(fails, total < 1024 * 1024, "звуки весят %d КБ — больше 1 МБ" % (total / 1024))

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
			ok += _expect(fails, Sfx.played.has(&"reveal") and Sfx.ambience_name == &"amb_night", "пролог без звука раскрытия роли")
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
			ok += _expect(fails, Sfx.played.has(&"bell") and Sfx.ambience_name == &"amb_night" and Sfx.music_name == &"",
				"ночь без колокола или ночного фона (%s / %s)" % [Sfx.ambience_name, Sfx.music_name])
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
	ok += _expect(fails, ns != null and _all_text(ns).contains(Match.EVENT_TEXT[Match.Event.FOG]), "колокол не объявил туман")
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
		ok += _expect(fails, _all_text(Nav.host.current).contains("Этой ночью: туман."), "утром не сказано про туман")
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
	ok += _expect(fails, txt.contains("У других дверей: %s." % bots[1].name), "хозяин не видит, кто сейчас у других дверей")
	ok += _expect(fails, ds._rows.size() == 2 and ds._rows.has(bots[1].id) and txt.contains(bots[1].name), "голоса за дверью нет в очереди")
	var plea_ok := false
	for line: String in Phrases.MIMIC_PLEAS:
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
	ok += _expect(fails, _all_text(gs).contains("голосом %s" % Ru.genitive(bots[3].name)), "гость не слышит голоса Подражателя за спиной")
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
	var ups: Array[Villager] = []
	for b: Villager in mm.villagers:
		if b.is_upyr and b != upyr:
			ups.append(b)
	var hl := dm.after_box(human.id, {"loot": Match.Loot.NOTE, "a": ups[0], "b": mm.villagers[0]})
	ok += _expect(fails, hl.size() == 1 and hl[0].text.contains(ups[0].name), "человек не рассказал, что в записке")
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
			var text: String = m.claims[vid]
			if not text.contains("старожил"):
				continue
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
	m0.claims[bots[1].id] = "назвал себя старожилом: Рита — упырь"
	m0.player_seen[bots[2].id] = 1
	ok += _expect(fails, "\n".join(DiarySheet.facts(m0, d0, bots[1])).contains("Назвал себя старожилом"), "заявление не попало в дневник")
	var rita := m0.get_villager(bots[3].id)
	m0.claims[bots[1].id] = "назвал себя старожилом: %s — упырь" % rita.name
	ok += _expect(fails, "\n".join(DiarySheet.facts(m0, d0, rita)).contains("%s назвал себя старожилом" % bots[1].name), "в карточке обвинённого не видно, кто его назвал")
	ok += _expect(fails, "\n".join(DiarySheet.facts(m0, d0, bots[2])).contains("Твои рисунки: упырь"), "твои рисунки не попали в дневник")

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
				good = t.contains("Подражатель") and t.contains(Ru.genitive(e.voice.name))
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
	ok += _expect(fails, Recap.verdict(m2, null).contains("человеком") and Recap.verdict(m2, null).contains(Ru.genitive(hu.name)), "не сказано, что изгнали человека")
	m2.player_admits.append({"day": 1, "who": up, "mimic": false})
	ok += _expect(fails, Recap.verdict(m2, null).contains("впустил") and Recap.verdict(m2, null).contains(Ru.accusative(up.name)), "не сказано, что ты впустил упыря: «%s»" % Recap.verdict(m2, null))
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
	m3.chronicle = PackedStringArray(["Ночь 1: в «Сарае» ночевали Рита и Нина — все целы.", "Утром: оберег у «Сарая» треснул.", "День 2: посёлок изгнал Тимура.", "Ночь 2: туман."])
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
	m.chronicle.append("Ночь 1: проверка ленты.")
	Nav.show(EndScreen.new())
	await _settle(tree)
	var et := _all_text(Nav.host.current)
	var role_holder := m.role_holder(Match.Role.ELDER)
	ok += _expect(fails, et.contains("Что решило партию") and et.contains("Ты погиб в ночь"), "на финале нет итога партии")
	ok += _expect(fails, role_holder == null or et.contains("%s — человек, старожил" % role_holder.name), "на финале не видно ролей")
	ok += _expect(fails, et.contains("Ночь 1") and et.contains("Проверка ленты."), "на финале нет ленты по ночам")
	Nav.show_menu()
	await _settle(tree)
	_finish(fails, ok, "разбор партии", "почему ты погиб, что решило партию, кто кем был и как всё шло по ночам")
