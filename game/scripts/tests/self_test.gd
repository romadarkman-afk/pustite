class_name SelfTest
extends RefCounted
## Проверки, которые CI гоняет перед сборкой APK.
## Падение любой из них = красная сборка, битый APK не выходит.


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


## Прогон через настоящие экраны и настоящие обработчики App.
## Требует, чтобы игрок побывал во ВСЕХ ролях у двери. Иначе — код выхода 1.
static func flow(app: App) -> void:
	var tree := app.get_tree()
	var seen: Dictionary[String, int] = {}
	var required: PackedStringArray = ["menu", "settings", "prologue", "day", "vote",
		"night", "door_host", "door_guest", "morning", "end"]

	app.open_menu()
	await tree.process_frame
	_mark(seen, app)
	app.open_settings()
	await tree.process_frame
	_mark(seen, app)

	var matches := 0
	for attempt in range(60):
		matches += 1
		app.start_match()
		var guard := 0
		while app.game.phase != Match.Phase.OVER and guard < 400:
			guard += 1
			await tree.process_frame
			var s: Screen = app.host.current
			_mark(seen, app)
			match app.game.phase:
				Match.Phase.PROLOGUE:
					app._on_intent(Intent.CONTINUE, {}, s)
				Match.Phase.DAY:
					var bots := app.game.alive_bots()
					if app.game.player().alive and not bots.is_empty():
						app._on_intent(Intent.SAY, {"text": "%s, пойдём в сарай?" % bots[0].name}, s)
						app._on_intent(Intent.ACCUSE, {"id": bots[bots.size() - 1].id}, s)
						app._on_intent(Intent.DEFEND, {}, s)
					app._on_intent(Intent.END_DAY, {}, s)
				Match.Phase.VOTE:
					var vs := s as VoteScreen
					if not vs.result_shown:
						var bots2 := app.game.alive_bots()
						app._on_intent(Intent.VOTE, {"id": bots2[0].id if not bots2.is_empty() else -1}, s)
						for f in range(40):
							if vs.result_shown:
								break
							await tree.process_frame
					app._on_intent(Intent.CONTINUE, {}, s)
				Match.Phase.NIGHT:
					app._on_intent(Intent.CHOOSE_HOUSE, {"house": app.game.rng.randi_range(0, app.game.houses.size() - 1)}, s)
				Match.Phase.DOOR:
					var ds := s as DoorScreen
					if ds == null:
						continue
					match ds.role:
						Match.DoorRole.HOST:
							var ids: Array[int] = [ds.seat.queue[0].id]
							app._on_intent(Intent.ADMIT, {"ids": ids}, s)
						Match.DoorRole.GUEST:
							app._on_intent(Intent.PLEA, {"plea": "shared"}, s)
							for f in range(60):
								if ds.result_shown:
									break
								await tree.process_frame
							app._on_intent(Intent.CONTINUE, {}, s)
						_:
							var none: Array[int] = []
							app._on_intent(Intent.ADMIT, {"ids": none}, s)
				Match.Phase.MORNING:
					var ms := s as MorningScreen
					for f in range(80):
						if ms.revealed:
							break
						await tree.process_frame
					app._on_intent(Intent.CONTINUE, {}, s)
		await tree.process_frame
		_mark(seen, app)
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
	print("=== экраны: %d партий ===" % matches)
	print("посещено: " + ", ".join(keys))
	if missing.is_empty():
		print("ИТОГ: OK — все экраны и обе роли у двери пройдены")
		tree.quit(0)
	else:
		print("ИТОГ: НЕ ПРОЙДЕНЫ: " + ", ".join(missing))
		tree.quit(1)


static func _mark(seen: Dictionary[String, int], app: App) -> void:
	if app.host.current != null:
		var id := app.host.current.screen_id()
		seen[id] = seen.get(id, 0) + 1
