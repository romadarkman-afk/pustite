class_name PlanTests
extends RefCounted
## Проверки задач плана хоррор-кампании (docs/horror-plan.md). Вызываются из флагов SelfTest:
## --sim — журнал событий в 500 партиях (TASK-001), --diary — знание жителей и обещания (TASK-003, 004),
## --recap — память кампании и откровения (TASK-002, 005).


# =============================================================
# TASK-001. Журнал событий: все виды встречаются, журнал совпадает со старыми списками
# =============================================================
static func world_log_sim(games: int = 500) -> Dictionary:
	var cfg := load("res://config/balance_7.tres") as GameConfig
	var seen: Dictionary = {}
	var mismatch := PackedStringArray()
	for g in range(games):
		var m := Match.new()
		var d := Director.new()
		m.start(cfg, 7000 + g)
		d.attach(m)
		m.begin_day()
		var pr := RandomNumberGenerator.new()
		pr.seed = 900 + g
		while m.phase != Match.Phase.OVER:
			match m.phase:
				Match.Phase.DAY:
					d.plan_day()
					d.opening_lines()
					var bots := m.alive_bots()
					if m.player().alive and not bots.is_empty():
						var t: Villager = bots[pr.randi_range(0, bots.size() - 1)]
						d.player_promise(t, "open" if pr.randf() < 0.5 else "come")
						d.personal_talk(bots[pr.randi_range(0, bots.size() - 1)].id, pr.randi_range(0, 1))
						if pr.randf() < 0.3:
							m.post(_accuse(m.player(), t))
					d.run_jobs_instant(d.plan_jobs(m.config.day_seconds))
					m.end_day()
				Match.Phase.VOTE:
					var tally: Dictionary[int, int] = {}
					var bv := d.votes()
					for voter: int in bv:
						tally[bv[voter]] = tally.get(bv[voter], 0) + m.vote_weight(voter)
					if m.player().alive and not m.alive_bots().is_empty():
						var target := m.alive_bots()[0]
						bv[0] = target.id
						tally[target.id] = tally.get(target.id, 0) + 1
						m.note_player_vote(target)
					m.apply_vote(tally, bv)
					m.after_vote()
				Match.Phase.NIGHT:
					var ch := d.night_choices()
					if m.player().alive:
						ch[0] = pr.randi_range(0, m.houses.size() - 1)
					m.seat_night(ch)
				Match.Phase.DOOR:
					for s: Match.Seat in m.seats:
						if s.host.is_player:
							m.door_dilemma(s)
							var ids: Array[int] = []
							for v: Villager in s.knockers():
								if pr.randf() < 0.5:
									ids.append(v.id)
							m.admit(s, ids)
						else:
							m.admit(s, d.host_decide(s, "beg"))
					m.tunnel_pass(false)
					d.after_door(m.seats)
					d.read_report(m.resolve_night())
				Match.Phase.MORNING:
					m.end_morning()
		for e: WorldLog.Event in m.world.events:
			seen[e.kind] = true
		var w := m.world
		var votes := 0
		var exiles := 0
		for rec: Dictionary in m.vote_log:
			votes += (rec.votes as Dictionary).size()
			exiles += 1 if rec.exiled != null else 0
		var dead := 0
		for rec: Dictionary in m.history:
			dead += (rec.dead as Array).size()
		var admits_by_player := 0
		var refused_player := 0
		for e: WorldLog.Event in w.events:
			if e.kind == WorldLog.Kind.ADMIT and e.actor == 0:
				admits_by_player += 1
			if e.kind == WorldLog.Kind.REFUSE and e.target == 0 and e.actor != 0:
				refused_player += 1
		var checks := [
			["голоса", w.count(WorldLog.Kind.VOTE), votes],
			["изгнания", w.count(WorldLog.Kind.EXILED), exiles],
			["гибели", w.count(WorldLog.Kind.DIED), dead],
			["впустил игрок", admits_by_player, m.player_admits.size()],
			["не открыли игроку", refused_player, m.refused_player.size()],
			["дилеммы", w.count(WorldLog.Kind.DILEMMA), m.dilemmas.size()],
		]
		for c: Array in checks:
			if int(c[1]) != int(c[2]) and mismatch.size() < 8:
				mismatch.append("партия %d: %s в журнале %d, в старом списке %d" % [g, c[0], c[1], c[2]])
	var missing := PackedStringArray()
	for k in range(WorldLog.KEYS.size()):
		if not seen.has(k):
			missing.append(WorldLog.KEYS[k])
	return {"games": games, "missing": missing, "mismatch": mismatch}


static func _accuse(by: Villager, t: Villager) -> ChatLine:
	var l := ChatLine.say(by, "!")
	l.about = t
	return l


# =============================================================
# TASK-003 и TASK-004: кто что знает, обещания
# =============================================================
static func knowledge_and_promises(fails: PackedStringArray) -> int:
	var ok := 0
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	# три сценария отказа у двери: со свидетелем, без свидетеля, стучавший выжил
	for scenario in ["witness", "alone", "survived"]:
		var m := Match.new()
		var d := Director.new()
		m.start(c, 31)
		d.attach(m)
		var victim: Villager = null
		var kin: Villager = null
		for v: Villager in m.alive_bots():
			var k := m.get_villager(v.partner_id if v.partner_id >= 0 else v.family_id)
			if k != null and not k.is_player:
				victim = v
				kin = k
				break
		var others: Array[Villager] = []
		for v: Villager in m.alive_bots():
			if v != victim and v != kin:
				others.append(v)
		if victim == null or others.size() < 2:
			fails.append("знание: в составе нет близких для проверки")
			return ok
		var host: Villager = others[0]
		var witness: Villager = others[1]
		m.phase = Match.Phase.DOOR
		var s := Match.Seat.new()
		s.house = 0
		s.host = host
		s.queue.append(victim)
		if scenario == "witness":
			s.queue.append(witness)
		m.seats = [s]
		var admit_ids: Array[int] = []
		if scenario == "witness":
			admit_ids.append(witness.id)
		m.admit(s, admit_ids)
		var refusal := m.world.last(WorldLog.Kind.REFUSE, host.id, victim.id, m.day)
		ok += SelfTest._expect(fails, refusal != null and m.world.knows(host.id, refusal) and m.world.knows(victim.id, refusal)
			and not m.world.knows(kin.id, refusal), "знание (%s): отказ у двери знают не те" % scenario)
		var r := NightReport.new()
		if scenario != "survived":
			victim.alive = false
			var e := r.add(NightReport.Kind.KILLED_STREET, victim, 0)
			e.host = host
		m._spread_news()
		m._apply_grief(r)
		match scenario:
			"witness":
				var src := m.world.source(kin.id, refusal)
				ok += SelfTest._expect(fails, src.get("how", "") == WorldLog.TOLD and int(src.get("via", -1)) == witness.id,
					"знание: свидетель не рассказал близким погибшего (%s)" % str(src))
				ok += SelfTest._expect(fails, kin.blame_id == host.id and kin.blame_via == witness.id, "знание: близкий не винит хозяина двери")
				m.phase = Match.Phase.DAY
				var lines := d.grief_lines()
				var said := ""
				for l: ChatLine in lines:
					said += l.text + "\n"
				ok += SelfTest._expect(fails, said.contains(L.t("know.told", {"who": witness, "lost": victim})),
					"знание: в обвинении не назван источник: %s" % said)
			"alone":
				ok += SelfTest._expect(fails, not m.world.knows(kin.id, refusal) and kin.blame_id < 0,
					"знание: отказ без свидетелей стал известен близким")
			"survived":
				var src2 := m.world.source(kin.id, refusal)
				ok += SelfTest._expect(fails, src2.get("how", "") == WorldLog.TOLD and int(src2.get("via", -1)) == victim.id,
					"знание: выживший не рассказал своим об отказе")

	# обещания: игрок обещает открыть и не открывает — утром упрёк при всех и дневник
	var pm := Match.new()
	var pd := Director.new()
	pm.start(c, 41)
	pd.attach(pm)
	pm.begin_day()
	var friend: Villager = pm.alive_bots()[0]
	var pal: Villager = pm.alive_bots()[1]
	var said_lines := pd.player_promise(friend, "open")
	pd.player_promise(pal, "come")
	ok += SelfTest._expect(fails, said_lines.size() == 1 and pm.promises.size() == 2 and pm.world.count(WorldLog.Kind.PROMISE) == 2,
		"обещание: житель не ответил или обещание не записано")
	ok += SelfTest._expect(fails, "\n".join(DiarySheet.facts(pm, pd, friend)).contains(L.t("diary.promise_state_open")),
		"обещание не видно в дневнике днём")
	pm.phase = Match.Phase.DOOR
	var seat := Match.Seat.new()
	seat.house = 0
	seat.host = pm.player()
	seat.queue.append(friend)
	pm.seats = [seat]
	pm.player().night_house = 0
	pal.night_house = 0
	seat.queue.append(pal)
	var only_pal: Array[int] = [pal.id]
	pm.admit(seat, only_pal)
	pm._night_ids.assign([0, friend.id, pal.id])
	friend.night_house = -1
	pm._settle_promises()
	ok += SelfTest._expect(fails, String(pm.promises[0].state) == "broken" and String(pm.promises[1].state) == "kept",
		"обещание: итог ночи посчитан неверно (%s, %s)" % [pm.promises[0].state, pm.promises[1].state])
	var grudge_before: float = pd.brains[friend.id].grudge.get(0, 0.0)
	pd._settle_promise_lines()
	var morning := ""
	var about_player := false
	for l: ChatLine in pd.promise_lines:
		morning += l.text + "\n"
		about_player = about_player or (l.speaker == friend and l.about == pm.player())
	ok += SelfTest._expect(fails, about_player and pd.brains[friend.id].grudge.get(0, 0.0) > grudge_before,
		"обещание: утром нет упрёка или доверие не упало: %s" % morning)
	var broken_ev := pm.world.last(WorldLog.Kind.PROMISE_BROKEN, 0, friend.id)
	ok += SelfTest._expect(fails, broken_ev != null and broken_ev.public, "обещание: нарушенное слово не стало известно всем")
	ok += SelfTest._expect(fails, "\n".join(DiarySheet.facts(pm, pd, friend)).contains(L.t("diary.promise_state_broken"))
		and "\n".join(DiarySheet.facts(pm, pd, pal)).contains(L.t("diary.promise_state_kept")), "обещание: итог не виден в дневнике")

	# житель обещает открыть игроку и держит слово: хозяин-человек пускает игрока первым
	var hm := Match.new()
	var hd := Director.new()
	hm.start(c, 51)
	hd.attach(hm)
	hm.begin_day()
	var human_host: Villager = null
	for v: Villager in hm.alive_bots():
		if not v.is_upyr:
			human_host = v
			break
	var rival: Villager = hm.alive_bots()[0] if hm.alive_bots()[0] != human_host else hm.alive_bots()[1]
	hd.brains[human_host.id].private_delta[0] = 1.5      # без обещания игроку не верит
	hm.promise(human_host, hm.player(), "open")
	var ss := Match.Seat.new()
	ss.house = 0
	ss.host = human_host
	ss.queue.assign([rival, hm.player()])
	var picked := hd.host_decide(ss, "beg")
	ok += SelfTest._expect(fails, picked.has(0), "обещание: хозяин-человек не пустил игрока, которому обещал открыть")
	var bot_said := 0
	for day_i in range(1, 12):
		hm.day = day_i
		if hd.bot_promise() != null:
			bot_said += 1
	ok += SelfTest._expect(fails, bot_said > 0, "обещание: жители сами никогда не обещают")
	return ok


# =============================================================
# TASK-002. Память кампании: запись, перезапуск, старое сохранение v0.46
# =============================================================
static func campaign_memory(fails: PackedStringArray) -> int:
	var ok := 0
	var path := ProjectSettings.globalize_path(Save.SETTINGS_PATH)
	var backup := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	# старое сохранение v0.46: формат 1, без памяти
	var old := ConfigFile.new()
	old.set_value("meta", "schema", 1)
	old.set_value("campaign", "stars", "a1c1:2,a1c2:1")
	old.set_value("campaign", "dead", "3")
	old.set_value("campaign", "seed", 77)
	old.set_value("profile", "name", "Тест")
	old.save(Save.SETTINGS_PATH)
	Save.load_all()
	ok += SelfTest._expect(fails, Save.loaded_schema == 1 and Save.campaign_stars.get("a1c2", 0) == 1 and str(Save.campaign_dead) == "[3]"
		and Save.campaign_memory.is_empty() and Save.player_name == "Тест", "память: сохранение v0.46 прочиталось с потерями")

	# глава: игрок не открыл жителю, тот погиб; другому сдержал слово
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	var m := Match.new()
	m.start(c, 61)
	m.begin_day()
	var lost: Villager = m.alive_bots()[0]
	var kept: Villager = m.alive_bots()[1]
	m.promise(m.player(), kept, "come")
	m.phase = Match.Phase.DOOR
	var s := Match.Seat.new()
	s.house = 0
	s.host = m.player()
	s.queue.assign([lost, kept])
	m.seats = [s]
	var ids: Array[int] = [kept.id]
	m.admit(s, ids)
	m._night_ids.assign([0, lost.id, kept.id])
	m.player().night_house = 0
	kept.night_house = 0
	m._settle_promises()
	lost.alive = false
	m.world.add(WorldLog.Kind.DIED, m.day, -1, lost.id, 0, [], true, {"refused_by": 0})
	var recs := m.world.campaign_records(m)
	var kinds := PackedStringArray()
	for r: Dictionary in recs:
		kinds.append(String(r.kind))
	ok += SelfTest._expect(fails, kinds.has("refused_died") and kinds.has("kept") and kinds.has("admitted") and recs[0].kind == "refused_died",
		"память: глава записала не то: %s" % ", ".join(kinds))
	Save.record_chapter("a1c3", 2, [], PackedStringArray(), recs)
	var before := Save.campaign_memory.duplicate(true)
	Save.load_all()
	ok += SelfTest._expect(fails, Save.loaded_schema == Save.SCHEMA and str(Save.campaign_memory) == str(before) and before.size() == recs.size(),
		"память: после перезапуска записи другие (%d и %d)" % [Save.campaign_memory.size(), before.size()])
	var lines := Campaign.memory_lines(lost.story_id)
	ok += SelfTest._expect(fails, not lines.is_empty() and lines[0].contains(lost.name) and lines[0].contains("3"),
		"память: нет строки о жителе: %s" % str(lines))
	# повтор главы заменяет её память, а не дублирует
	Save.record_chapter("a1c3", 3, [], PackedStringArray(), recs.slice(0, 1))
	var n_a1c3 := 0
	for r2: Dictionary in Save.campaign_memory:
		n_a1c3 += 1 if r2.ch == "a1c3" else 0
	ok += SelfTest._expect(fails, n_a1c3 == 1, "память: повтор главы задвоил записи")
	# сброс кампании стирает память
	Save.campaign_reset()
	ok += SelfTest._expect(fails, Save.campaign_memory.is_empty(), "память: сброс кампании её не стёр")
	# вернуть сохранение, как было до проверки
	if backup.is_empty():
		DirAccess.remove_absolute(path)
	else:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	Save.load_all()
	return ok


# =============================================================
# TASK-005. Откровения: гибель любого и всех троих постоянных — каждое находит рассказчика
# =============================================================
static func revelations(fails: PackedStringArray) -> int:
	var ok := 0
	var dead_before := Save.campaign_dead.duplicate()
	var cases: Array = [[], [0], [1], [2], [0, 1, 2], [0, 1, 2, 5, 7, 8]]
	var bad_tag := RegEx.create_from_string("[{}\\[\\]|]")
	for dead: Array in cases:
		Save.campaign_dead.assign(dead)
		for id: String in Revelations.ORDER:
			var src := Revelations.source(id)
			var b := Revelations.beat(id)
			var text := String(b[1])
			var primary := int(Revelations.LIST[id].sources[0])
			var good := not text.is_empty() and bad_tag.search(text) == null and not String(b[0]).is_empty()
			if dead.has(primary):
				good = good and int(src.lost) == primary and text.contains(L.names()[primary][0])
			if int(src.who) < 0:
				good = good and text.contains(L.t("rev.%s.item" % id).left(20))
			else:
				good = good and not dead.has(int(src.who))
			ok += SelfTest._expect(fails, good, "откровение %s при погибших %s: «%s»" % [id, str(dead), text])
	Save.campaign_dead.assign(dead_before)
	ok += SelfTest._expect(fails, PrologueScreen.chapter_beats("a1c2").size() == 3 and PrologueScreen.chapter_beats("a1c1").size() == 2,
		"откровения не попали в сцену главы")
	return ok
