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
					m.end_day()
				Match.Phase.VOTE:
					var tally: Dictionary[int, int] = {}
					var bv := d.votes()
					for voter: int in bv:
						tally[bv[voter]] = tally.get(bv[voter], 0) + 1
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
					m.end_day()
				Match.Phase.VOTE:
					var tally: Dictionary[int, int] = {}
					var bv := d.votes()
					for voter: int in bv:
						tally[bv[voter]] = tally.get(bv[voter], 0) + 1
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
					Nav.handle_intent(Intent.CHOOSE_HOUSE, {"house": Game.m.rng.randi_range(0, Game.m.houses.size() - 1)}, s)
				Match.Phase.DOOR:
					var ds := s as DoorScreen
					if ds == null:
						continue
					match ds.role:
						Match.DoorRole.HOST:
							var ids: Array[int] = [ds.seat.queue[0].id]
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
	if s.scroll.size.y < vp.y * 0.3:
		out.append("%s: под содержимое всего %d px из %d" % [w, int(s.scroll.size.y), int(vp.y)])
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
		if absf(band.get_center().y - fld.get_center().y) > 3.0:
			out.append("%s: посёлок не по центру своей области (%d vs %d)" % [w, int(band.get_center().y), int(fld.get_center().y)])
		if band.size.y > fld.size.y + 3.0:
			out.append("%s: дома не влезают в поле (%d > %d)" % [w, int(band.size.y), int(fld.size.y)])
		if Nav.village.scale.x < MIN_FIELD_SCALE:
			out.append("%s: дома мельче %d%% от задуманного (масштаб %.2f)" % [w, int(MIN_FIELD_SCALE * 100), Nav.village.scale.x])
		if absf(band.get_center().x - vp.x * 0.5) > 2.0:
			out.append("%s: посёлок не по центру по горизонтали" % w)
		field_scales.append(Nav.village.scale.x)
		if absf(Nav.scrim.top - fld.end.y) > 3.0:
			out.append("%s: затемнение не у нижнего края поля (%d vs %d)" % [w, int(Nav.scrim.top), int(fld.end.y)])
		for f: VillagerFigure in Nav.village.crowd.figures.values():
			if not f.visible or f.state == VillagerFigure.State.GONE:
				continue
			var gp := f.get_global_transform_with_canvas().origin
			var half := 16.0 * Nav.village.scale.x
			if gp.x - half < -1.0 or gp.x + half > vp.x + 1.0:
				out.append("%s: житель %s за краем экрана (x=%d)" % [w, f.who, int(gp.x)])
	elif Nav.village.modulate.a > 0.05:
		out.append("%s: посёлок виден там, где должен быть скрыт" % w)
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

	var probe: VillagerFigure = cr.figures[1]
	var s0 := probe.body_scale()
	await tree.create_timer(0.45).timeout
	ok += _expect(fails, absf(probe.body_scale().y - s0.y) > 0.004, "жители не дышат (масштаб тела не меняется)")

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
	Game.end_day()
	await _settle(tree)
	if Game.m.phase == Match.Phase.VOTE:
		Game.vote(-1)
		await _settle(tree)
		Game.proceed()
		await _settle(tree)
	var runners := 0
	var wrong := PackedStringArray()
	var groups: Dictionary[int, Array] = {}
	for vv: Villager in Game.m.alive_bots():
		if vv.announced_house >= 0 and vv.announced_house < v.open_count:
			if not groups.has(vv.announced_house):
				groups[vv.announced_house] = []
			groups[vv.announced_house].append(vv)
	for hh: int in groups:
		var members: Array = groups[hh]
		var spots := cr.door_spots(hh, members.size(), cr._avoid())
		for k in range(members.size()):
			var vv: Villager = members[k]
			runners += 1
			if cr.figures[vv.id].position.distance_to(spots[k]) > 2.0:
				wrong.append(vv.name)
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
			# ночью: худший случай — все боты у одной двери, по очереди у каждой открытой
			var cr := Nav.village.crowd
			var bots := Game.m.alive_bots()
			for hi in range(Game.m.config.shelters):
				var spots := cr.door_spots(hi, bots.size(), cr._avoid())
				for k in range(bots.size()):
					cr.figures[bots[k].id].position = spots[k]
				await _frames(tree, 1)
				checks += _check_crowd("%s · ночь у «%s»" % [tag, Game.m.house_name(hi)], problems)
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
	for f: VillagerFigure in figs:
		var lr := f.label_rect_global()
		var br := f.body_rect_global()
		var all := lr.merge(br)
		if all.position.x < -1.0 or all.end.x > vp.x + 1.0:
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
