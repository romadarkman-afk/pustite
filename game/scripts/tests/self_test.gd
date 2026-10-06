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
	print("ИТОГ: %s" % ("OK" if ok else "БАЛАНС ВНЕ КОРИДОРА 30–70% ИЛИ ИГРОК НЕ ВИДИТ ОДНУ ИЗ РОЛЕЙ У ДВЕРИ"))
	tree.quit(0 if ok else 1)


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
const MIN_TOUCH := 84.0


static func layout() -> void:
	var tree := Nav.get_tree()
	var problems: PackedStringArray = []
	var checks := 0
	for sz: Vector2i in LAYOUT_SIZES:
		tree.root.size = sz
		await _frames(tree, 3)
		var tag := "%d×%d" % [sz.x, sz.y]

		Nav.show_menu()
		await _frames(tree, 3)
		checks += _check(tag, problems)
		Nav.show_settings()
		await _frames(tree, 3)
		checks += _check(tag, problems)

		Nav.start_match()
		await _frames(tree, 3)
		checks += await _check_doors(tag, problems)

		var guard := 0
		while Game.m.phase != Match.Phase.OVER and guard < 60:
			guard += 1
			await _frames(tree, 3)
			checks += _check(tag, problems)
			checks += await _layout_step(tag, problems)
		await _frames(tree, 3)
		checks += _check(tag, problems)

	print("=== раскладка: %d проверок на %d типах экранов ===" % [checks, LAYOUT_SIZES.size()])
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
			await _frames(tree, 3)
			n += _check_sheet(sheet, tag, out)
			sheet.close(-1)
			var bots := Game.m.alive_bots()
			if Game.m.player().alive and not bots.is_empty():
				Nav.handle_intent(Intent.SAY, {"text": "%s, пойдём в сарай?" % bots[0].name}, s)
				await _frames(tree, 3)
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
				await _frames(tree, 3)
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
					await _frames(tree, 3)
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
			await _frames(tree, 3)
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
		await _frames(Nav.get_tree(), 3)
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
