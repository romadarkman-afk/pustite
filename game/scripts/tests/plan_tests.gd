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
	for k in range(WorldLog.MATCH_KINDS):
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


# =============================================================
# Группа 2. TASK-006, 007, 010: чувства, связи, реакции на утрату
# =============================================================
static func _pair(m: Match, older_story: int, younger_story: int) -> Array:
	var a: Villager = null
	var b: Villager = null
	for v: Villager in m.villagers:
		if v.story_id == older_story and v.guest_id.is_empty():
			a = v
		if v.story_id == younger_story and v.guest_id.is_empty():
			b = v
	return [a, b]


static func feelings_and_bonds(fails: PackedStringArray) -> int:
	var ok := 0
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	c.players = 12
	# TASK-007: в любой партии с Лидой и Костей они бабушка и внук; давние связи на месте
	var family_ok := true
	for seed_i in range(5):
		var fm := Match.new()
		fm.start(c, 800 + seed_i)
		var p := _pair(fm, 2, 3)
		var lida: Villager = p[0]
		var kostya: Villager = p[1]
		if lida != null and kostya != null:
			family_ok = family_ok and lida.family_id == kostya.id and lida.family_kind == "grandchild" and kostya.family_kind == "grandparent"
			family_ok = family_ok and SocialContent.bond_text(lida, fm).contains(kostya.name) and SocialContent.bond_text(lida, fm).contains("внук")
			family_ok = family_ok and SocialContent.bond_text(kostya, fm).contains("бабушка")
		var t := _pair(fm, 5, 9)
		if t[0] != null and t[1] != null:
			family_ok = family_ok and (t[0] as Villager).tie_id == (t[1] as Villager).id and (t[0] as Villager).tie_kind == "engaged"
			family_ok = family_ok and SocialContent.bond_text(t[0], fm).contains((t[1] as Villager).name.left(3))
	ok += SelfTest._expect(fails, family_ok, "связи: Лида и Костя не бабушка и внук или нет давних связей")
	ok += SelfTest._expect(fails, SocialContent.PEOPLE_RU[3][1].begins_with("Сестра") and SocialContent.PEOPLE_RU[2][1].contains("сестра Кости"),
		"связи: биографии Лиды и Кости противоречат друг другу")

	# TASK-006: вдовец горюет сильно наутро и почти отпускает через четыре дня
	var m := Match.new()
	m.start(c, 811)
	var widow: Villager = null
	var lost: Villager = null
	for v: Villager in m.alive_bots():
		if v.partner_id >= 0 and widow == null:
			widow = v
			lost = m.get_villager(v.partner_id)
	if widow == null:
		fails.append("чувства: в составе нет пары")
		return ok
	var r := NightReport.new()
	r.add(NightReport.Kind.KILLED_INSIDE, lost, 0, [] as Array[Villager])
	lost.alive = false
	m._apply_grief(r)
	m.feelings.morning(r)
	var g0 := m.feelings.get_f(widow.id, Feelings.F.GRIEF)
	for i in range(4):
		m.feelings.morning(NightReport.new())
	var g4 := m.feelings.get_f(widow.id, Feelings.F.GRIEF)
	ok += SelfTest._expect(fails, g0 > 0.7 and g4 < 0.3, "чувства: горе наутро %.2f, через четыре дня %.2f" % [g0, g4])
	ok += SelfTest._expect(fails, m.feelings.main(widow.id) != "grief", "чувства: через четыре дня горе всё ещё главное")
	# характер: паникёр пугается сильнее тихони
	var panic: Villager = null
	var quiet: Villager = null
	for v: Villager in m.alive_bots():
		if v.persona == Voices.Persona.PANIC and panic == null: panic = v
		if v.persona == Voices.Persona.QUIET and quiet == null: quiet = v
	if panic != null and quiet != null:
		var p0 := m.feelings.get_f(panic.id, Feelings.F.FEAR)
		var q0 := m.feelings.get_f(quiet.id, Feelings.F.FEAR)
		m.feelings.add(panic.id, Feelings.F.FEAR, 0.3)
		m.feelings.add(quiet.id, Feelings.F.FEAR, 0.3)
		ok += SelfTest._expect(fails, m.feelings.get_f(panic.id, Feelings.F.FEAR) - p0 > m.feelings.get_f(quiet.id, Feelings.F.FEAR) - q0,
			"чувства: характер не влияет на силу страха")
	ok += reactions(fails)
	return ok


## TASK-010: пять ситуаций с Лидой и Костей дают ожидаемую реакцию, и она переходит в следующую главу.
static func reactions(fails: PackedStringArray) -> int:
	var ok := 0
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	c.players = 12
	var cases := [
		{"name": "не знала об отказе", "knew": false, "full": false, "rel": 0.0, "want": "withdraw"},
		{"name": "знала, мест не было", "knew": true, "full": true, "rel": 0.0, "want": "defend"},
		{"name": "знала, места были", "knew": true, "full": false, "rel": 0.0, "want": "accuse"},
		{"name": "знала, игрок враг", "knew": true, "full": false, "rel": -1.2, "want": "revenge"},
		{"name": "знала, игроку верит", "knew": true, "full": false, "rel": 0.9, "want": "withdraw"},
	]
	var path := ProjectSettings.globalize_path(Save.SETTINGS_PATH)
	var backup := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	for cs: Dictionary in cases:
		var m := Match.new()
		var d := Director.new()
		var sd := 821
		m.start(c, sd)
		while (_pair(m, 2, 3)[1] == null or _pair(m, 2, 3)[0] == null) and sd < 900:
			sd += 1
			m = Match.new()
			m.start(c, sd)
		d.attach(m)
		var p := _pair(m, 2, 3)
		var lida: Villager = p[0]
		var kostya: Villager = p[1]
		if lida == null or kostya == null:
			fails.append("реакции: в составе нет Лиды и Кости")
			return ok
		m.begin_day()
		m.phase = Match.Phase.DOOR
		var s := Match.Seat.new()
		s.house = 0
		s.host = m.player()
		s.queue.append(kostya)
		var filler: Villager = null
		if bool(cs.full):
			for v: Villager in m.alive_bots():
				if v != lida and v != kostya:
					filler = v
					break
			s.queue.append(filler)
		if bool(cs.knew):
			s.queue.append(lida)
		m.seats = [s]
		var ids: Array[int] = []
		if filler != null:
			ids.append(filler.id)
		m.admit(s, ids)
		lida.relationship = 0                  # память прошлых партий в этой проверке не участвует
		d.public_susp[0] = 0.0
		d.brains[lida.id].private_delta[0] = -float(cs.rel)
		var r := NightReport.new()
		var e := r.add(NightReport.Kind.KILLED_STREET, kostya, 0)
		e.host = m.player()
		kostya.alive = false
		m._spread_news()
		m._apply_grief(r)
		d.read_report(r)
		ok += SelfTest._expect(fails, lida.reaction == String(cs.want),
			"реакции (%s): Лида выбрала «%s», ждали «%s»" % [cs.name, lida.reaction, cs.want])
		var lines := d.grief_lines()
		var said := ""
		var asks := false
		for l: ChatLine in lines:
			if l.speaker == lida:
				said += l.text
				asks = asks or l.asks_player
		if String(cs.want) == "accuse":
			ok += SelfTest._expect(fails, said == GriefReactions.line(lida, kostya, "accuse") and asks, "реакции: обвинение не сказано или нет вопроса игроку")
			var reply := d.answer_grief(lida, 1)
			ok += SelfTest._expect(fails, reply.size() == 1 and lida.reaction == "withdraw", "реакции: извинение не смягчило Лиду")
		if String(cs.want) == "revenge":
			# месть переходит в следующую главу и мешает игроку там
			var recs := m.world.campaign_records(m)
			Save.record_chapter("a1c1", 2, [], PackedStringArray(), recs)
			ok += SelfTest._expect(fails, Campaign.active_grudges().has(2), "реакции: месть Лиды не перешла в следующую главу")
			var m2 := Match.new()
			var d2 := Director.new()
			m2.start(c, 822)
			d2.attach(m2)
			d2.apply_campaign(Save.campaign_bonds, Campaign.active_grudges(), Campaign.defenders())
			var lida2: Villager = _pair(m2, 2, 3)[0]
			ok += SelfTest._expect(fails, lida2 != null and d2.brains[lida2.id].grudge.get(0, 0.0) > 1.0 and int(m2.feelings.rage_at.get(lida2.id, -1)) == 0,
				"реакции: в следующей главе Лида не помнит обиду")
			# игрок впустил её в новой главе — обида прощена
			Save.record_chapter("a1c2", 2, [], PackedStringArray(), [{"kind": "admitted", "who": 2, "day": 1, "knew": []}])
			ok += SelfTest._expect(fails, not Campaign.active_grudges().has(2), "реакции: поступок игрока не исправил обиду")
	# отношения между главами (TASK-007): доверие к игроку и между жителями переходит в память кампании
	var mb := Match.new()
	var db := Director.new()
	mb.start(c, 831)
	db.attach(mb)
	var a: Villager = mb.alive_bots()[0]
	var b: Villager = mb.alive_bots()[1]
	db.brains[a.id].private_delta[0] = -0.9
	db.brains[a.id].private_delta[b.id] = 0.6
	var bonds := db.campaign_bonds()
	ok += SelfTest._expect(fails, int(bonds.get("%d>p" % a.story_id, 0)) == 3 and int(bonds.get("%d>%d" % [a.story_id, b.story_id], 0)) == -2,
		"связи: отношения не записались в память кампании: %s" % str(bonds))
	if backup.is_empty():
		DirAccess.remove_absolute(path)
	else:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	Save.load_all()
	return ok


# =============================================================
# TASK-008, 009: чувства меняют поведение и видны
# =============================================================
static func behaviour(fails: PackedStringArray) -> int:
	var ok := 0
	var c := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	c.players = 12
	var m := Match.new()
	var d := Director.new()
	m.start(c, 841)
	d.attach(m)
	m.begin_day()
	var humans: Array[Villager] = []
	for v: Villager in m.alive_bots():
		if not v.is_upyr:
			humans.append(v)
	var host: Villager = humans[0]
	var foe: Villager = humans[1]
	var other: Villager = humans[2]
	for v: Villager in [foe, other]:
		d.brains[host.id].private_delta[v.id] = 0.0
		d.public_susp[v.id] = 0.0
	var seat := Match.Seat.new()
	seat.host = host
	seat.house = 0
	seat.queue.assign([foe, other])
	# ярость: обидчика не пускает
	m.feelings.set_f(host.id, Feelings.F.RAGE, 0.9)
	m.feelings.rage_at[host.id] = foe.id
	ok += SelfTest._expect(fails, d.host_decide(seat).has(other.id) and not d.host_decide(seat).has(foe.id), "поведение: злой хозяин впустил обидчика")
	# вина: пускает того, кому отказал
	m.feelings.set_f(host.id, Feelings.F.RAGE, 0.0)
	m.feelings.rage_at.clear()
	m.feelings.set_f(host.id, Feelings.F.GUILT, 0.9)
	m.feelings.guilt_for[host.id] = foe.id
	ok += SelfTest._expect(fails, d.host_decide(seat).has(foe.id), "поведение: виноватый хозяин не впустил того, кому отказал")
	# страх: открывает только своим
	m.feelings.set_f(host.id, Feelings.F.GUILT, 0.0)
	m.feelings.guilt_for.clear()
	d.brains[host.id].pact_id = other.id
	m.feelings.set_f(host.id, Feelings.F.FEAR, 0.95)
	d.brains[host.id].private_delta[foe.id] = -0.5          # чужому даже немного верит
	ok += SelfTest._expect(fails, d.host_decide(seat).has(other.id) and not d.host_decide(seat).has(foe.id), "поведение: напуганный хозяин открыл чужому")
	d.brains[host.id].pact_id = -1
	# ярость: голосует против обидчика
	m.feelings.set_f(other.id, Feelings.F.RAGE, 0.9)
	m.feelings.rage_at[other.id] = foe.id
	m.phase = Match.Phase.VOTE
	ok += SelfTest._expect(fails, int(d.votes().get(other.id, -1)) == foe.id, "поведение: злой житель голосует не против обидчика")
	# надежда и доверие: поддерживает обвинение игрока
	var ally: Villager = humans[3]
	m.feelings.set_f(ally.id, Feelings.F.TRUST, 0.8)
	m.feelings.set_f(ally.id, Feelings.F.HOPE, 0.7)
	var accused: Villager = humans[4]
	var l := ChatLine.say(m.player(), "!")
	l.about = accused
	m.post(l)
	ok += SelfTest._expect(fails, int(d.votes().get(ally.id, -1)) == accused.id, "поведение: верящий игроку не поддержал его обвинение")
	# истощение: не больше одного дела
	m.phase = Match.Phase.DAY
	var tired := humans[5]
	m.feelings.set_f(tired.id, Feelings.F.EXHAUSTION, 0.95)
	var tasks := 0
	for k in range(20):
		for t: Director.JobTask in d.plan_jobs(90.0):
			tasks += 1 if t.vid == tired.id else 0
	ok += SelfTest._expect(fails, tasks <= 20, "поведение: уставший работает больше одного дела за день (%d за 20 дней)" % tasks)
	# отчаяние: уходит ночью к реке; выслушал днём — остаётся
	var lost_one := humans[6]
	m.feelings.set_f(lost_one.id, Feelings.F.DESPAIR, 0.95)
	var gone := false
	for day_i in range(1, 9):
		m.day = day_i
		d.plan_day()
		if m.wander_plan.has(lost_one.id):
			gone = true
			break
	ok += SelfTest._expect(fails, gone and not d.pending_lines.is_empty(), "поведение: отчаявшийся не собрался к реке или не сказал об этом")
	lost_one.personal_day = -1
	d.personal_talk(lost_one.id, 0)
	ok += SelfTest._expect(fails, not m.wander_plan.has(lost_one.id), "поведение: разговор не остановил отчаявшегося")
	m.wander_plan[lost_one.id] = true
	m.phase = Match.Phase.NIGHT
	var ch := d.night_choices()
	ch[0] = 0
	m.seat_night(ch)
	var seated := false
	for st: Match.Seat in m.seats:
		seated = seated or st.host == lost_one or st.queue.has(lost_one)
	var rn := m.resolve_night()
	var river := false
	for e: NightReport.Entry in rn.entries:
		river = river or (e.who == lost_one and e.cause == "river")
	ok += SelfTest._expect(fails, not seated and river, "поведение: ушедший к реке ночевал в доме или утро о нём молчит")
	# TASK-009: состояние словами в карточке
	m.feelings.set_f(foe.id, Feelings.F.FEAR, 0.95)
	ok += SelfTest._expect(fails, m.feelings.status_text(foe) == L.t("feel.fear", {"me": foe}), "видимость: в карточке нет состояния жителя")
	return ok


# =============================================================
# TASK-012: движок сцен — кадры, выбор в журнал, «Назад», сворачивание
# =============================================================
static func scene_engine(tree: SceneTree, fails: PackedStringArray) -> int:
	var ok := 0
	Nav.start_match()
	await SelfTest._frames(tree, 3)
	var host: Control = Nav.host.current
	var m := Game.m
	var sc := {"id": "test", "frames": [
		{"art": "res://assets/scenes/none.jpg", "lines": [{"text": "один"}], "sound": [{"at": 0.0, "do": "play", "id": "knock"}]},
		{"portrait": m.alive_bots()[0], "lines": [{"who": "Кто-то", "text": "два"}, {"text": "три"}]},
		{"art": "res://assets/scenes/a1c2.jpg", "weather": "rain", "lines": [{"text": "четыре"}]},
	], "choice": {"prompt": "Что делать?", "options": [{"id": "a", "text": "Первое"}, {"id": "b", "text": "Второе"}]}}
	var sp := ScenePlayer.new()
	sp.scene = sc
	sp.m = m
	host.add_child(sp)
	sp._build()
	ok += SelfTest._expect(fails, Game.held() and sp.frame_i == 0 and not sp._art.visible, "сцены: без картинки кадр не пошёл поверх посёлка или часы не встали")
	var guard := 0
	while sp._choices.visible == false and guard < 400:
		guard += 1
		await tree.process_frame
	ok += SelfTest._expect(fails, sp._choices.visible and sp._choices.get_child_count() == 2, "сцены: кадры не дошли до выбора")
	(sp._choices.get_child(1) as Button).pressed.emit()
	await SelfTest._frames(tree, 2)
	var ev := m.world.last(WorldLog.Kind.CHOICE)
	ok += SelfTest._expect(fails, ev != null and ev.info.get("choice", "") == "b" and ev.info.get("scene", "") == "test", "сцены: выбор не записан в журнал")
	ok += SelfTest._expect(fails, not Game.held(), "сцены: после сцены часы партии стоят")
	# «Назад» доводит до выбора, сворачивание ставит на паузу
	var sp2 := ScenePlayer.new()
	sp2.scene = sc
	sp2.m = m
	host.add_child(sp2)
	sp2._build()
	sp2._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var before := sp2.line_i
	await SelfTest._frames(tree, 10)
	ok += SelfTest._expect(fails, sp2.line_i == before and sp2.frame_i == 0, "сцены: свёрнутая игра листает сцену")
	sp2._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	ok += SelfTest._expect(fails, (host as Screen).handle_back() and sp2._in_choice, "сцены: «Назад» не довёл сцену до выбора")
	sp2.choose("a")
	await SelfTest._frames(tree, 2)
	Nav.show_menu()
	await SelfTest._frames(tree, 2)
	return ok


# =============================================================
# TASK-011, 013, 014, 015: глава «Стук» от реки до итога
# =============================================================
static func chapter_one(tree: SceneTree, fails: PackedStringArray) -> int:
	var ok := 0
	var path := ProjectSettings.globalize_path(Save.SETTINGS_PATH)
	var backup := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	Save.campaign_reset()
	Nav.start_chapter("a1c1")
	var ds: DoorScreen = null
	var river: ScenePlayer = null
	for i in range(60):
		await tree.process_frame
		if Nav.host.current is DoorScreen:
			ds = Nav.host.current as DoorScreen
			for ch: Node in ds.get_children():
				if ch is ScenePlayer and String((ch as ScenePlayer).scene.get("id", "")) == "a1c1_river":
					river = ch
		if river != null:
			break
	ok += SelfTest._expect(fails, river != null, "глава «Стук»: нет сцены у реки перед первым стуком")
	if river == null:
		return ok
	var guard := 0
	while not river._in_choice and guard < 400:
		guard += 1
		await tree.process_frame
	river.choose("answer")
	for i in range(200):
		await tree.process_frame
		if ds.find_children("*", "ScenePlayer", true, false).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty():
			break
	ok += SelfTest._expect(fails, Game.m.world.last(WorldLog.Kind.CHOICE) != null and not Game.director.scene_lines.is_empty(),
		"глава «Стук»: ответ на зов не записан или перевозчица о нём не вспомнит")
	# у двери: вопрос «Кто там?» один за ночь
	var g: Villager = ds.seat.knockers()[0]
	ds.ask_who(g.id)
	var note: Label = ds._observations.get(g.id)
	ok += SelfTest._expect(fails, note != null and note.visible and not note.text.is_empty() and ds._asked, "глава «Стук»: на «Кто там?» никто не ответил")
	var ids: Array[int] = [g.id]
	ds._finish_host(ids)
	var mo: MorningScreen = null
	for i in range(200):
		await tree.process_frame
		if Nav.host.current is MorningScreen:
			mo = Nav.host.current
			break
	ok += SelfTest._expect(fails, mo != null and mo.scene_shown.begins_with("a1c1_morning_"), "глава «Стук»: первое утро без сцены")
	var outcome := Scenes.first_night_outcome(Game.m)
	ok += SelfTest._expect(fails, mo != null and mo.scene_shown == "a1c1_morning_" + String(outcome.kind) and int(outcome.who) == g.id,
		"глава «Стук»: сцена утра не та, что вышла ночью")
	for i in range(400):
		if mo == null or mo.revealed:
			break
		await tree.process_frame
	# три исхода — три разных утра
	var kinds := {}
	for sd in range(1, 40):
		var mm := Match.new()
		mm.start(Campaign.config("a1c1"), 900 + sd)
		mm.begin_day()
		mm.phase = Match.Phase.DOOR
		var s := Match.Seat.new()
		s.host = mm.player()
		s.house = 0
		var bots := mm.alive_bots()
		s.queue.assign([bots[sd % bots.size()]])
		mm.seats = [s]
		var adm: Array[int] = []
		if sd % 3 != 0:
			adm.append(bots[sd % bots.size()].id)
		mm.admit(s, adm)
		kinds[String(Scenes.first_morning(mm).id)] = true
	ok += SelfTest._expect(fails, kinds.size() == 3, "глава «Стук»: утр после первой ночи не три: %s" % str(kinds.keys()))
	# день: первое обещание в главе обязательно, перевозчица вспоминает ответ на зов
	Game.proceed()
	for i in range(60):
		await tree.process_frame
		if Nav.host.current is DayScreen:
			break
	var lines := Game.director.opening_lines()
	var promised := not Game.m.promises_today(-1, 0).is_empty()
	ok += SelfTest._expect(fails, promised, "глава «Стук»: в первый день никто не пообещал открыть")
	# TASK-014: сцена утраты для каждого из 12 жителей — свои кадры на русском
	var gm := Match.new()
	var cfg12 := (load("res://config/balance_7.tres") as GameConfig).duplicate() as GameConfig
	cfg12.players = 12
	gm.start(cfg12, 951)
	var bad := PackedStringArray()
	var re_tag := RegEx.create_from_string("[{}\\[\\]|]")
	for v: Villager in gm.alive_bots():
		var sc := Scenes.grief(v, gm.alive_bots()[0] if gm.alive_bots()[0] != v else gm.alive_bots()[1])
		var fr: Array = sc.frames
		var t0 := String((fr[0].lines as Array)[0].text) if not fr.is_empty() else ""
		if fr.size() < 2 or re_tag.search(t0) != null or t0.is_empty():
			bad.append(v.name)
		for kind: String in ["accuse", "defend", "withdraw"]:
			var lt := GriefReactions.line(v, gm.alive_bots()[0], kind)
			if lt.is_empty() or re_tag.search(lt) != null:
				bad.append("%s:%s" % [v.name, kind])
	ok += SelfTest._expect(fails, bad.is_empty(), "сцены утраты: битые кадры или реплики у %s" % ", ".join(bad))
	# TASK-015: «Их память» на итоге главы
	var mem := EndScreen.memory_lines(Game.m)
	ok += SelfTest._expect(fails, not mem.is_empty() and mem.size() <= 4, "итог главы: нет строк «Их память»")
	Game.m.winner = Match.Team.PEOPLE
	Game.chapter_result = Campaign.finish(Game.m, Game.chapter, Game.director)
	Game.m.phase = Match.Phase.OVER
	Nav.show(EndScreen.new())
	await SelfTest._frames(tree, 4)
	ok += SelfTest._expect(fails, Nav.host.current.find_child("TheirMemory", true, false) != null, "итог главы: нет карточки «Их память»")
	Nav.show_menu()
	await SelfTest._frames(tree, 3)
	if backup.is_empty():
		DirAccess.remove_absolute(path)
	else:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	Save.load_all()
	return ok


# =============================================================
# Группа 4. TASK-016–020: туман, улики, пустая лодка, имя на доске, прощание
# =============================================================
static func _chapter_match(ch: String, seed_n: int) -> Array:
	var m := Match.new()
	m.plant_chapter = ch
	m.guests = Campaign.guests(ch)
	m.guest_roles_fixed = true
	m.start(Campaign.config(ch), seed_n)
	var d := Director.new()
	d.attach(m)
	d.chapter_id = ch
	m.begin_day()
	return [m, d]


static func group_four(fails: PackedStringArray) -> int:
	var ok := 0
	var path := ProjectSettings.globalize_path(Save.SETTINGS_PATH)
	var backup := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var dead_before := Save.campaign_dead.duplicate()
	var mem_before := Save.campaign_memory.duplicate(true)
	var name_before := Save.player_name
	var bad_tag := RegEx.create_from_string("[{}\\[\\]|]")

	# TASK-016: в тумане вопрос есть только после разговора днём; человек помнит, упырь нет
	var humans := 0
	var upyrs := 0
	var fog_bad := 0
	for sd in range(12):
		var md := _chapter_match("a1c2", 3100 + sd)
		var m: Match = md[0]
		var d: Director = md[1]
		for v: Villager in m.alive_bots():
			if not d.memory_answer(v, null).is_empty():
				fog_bad += 1
			m.world.add(WorldLog.Kind.LISTENED, m.day, 0, v.id, -1, [0, v.id])
			var a := d.memory_answer(v, null)
			var text := String(a.get("text", ""))
			if a.is_empty() or bool(a.ok) == v.is_upyr or text.is_empty() or bad_tag.search(text) != null:
				fog_bad += 1
			if v.is_upyr:
				upyrs += 1
			else:
				humans += 1
	ok += SelfTest._expect(fails, fog_bad == 0 and humans > 0 and upyrs > 0,
		"туман: вопрос без разговора или неверная память (ошибок %d, людей %d, упырей %d)" % [fog_bad, humans, upyrs])
	var fog_lines := 0
	for sd in range(40):
		var md := _chapter_match("a1c2", 3200 + sd)
		for l: ChatLine in (md[1] as Director).chapter_lines():
			fog_lines += 1
			if bad_tag.search(l.text) != null:
				fog_bad += 1
	ok += SelfTest._expect(fails, fog_lines > 0 and fog_bad == 0, "туман: солдат и вдова не учат вопросу о памяти")

	# TASK-017, 018: заложенное противоречие есть в обеих главах, спрашивается один раз,
	# человек объясняет, упырь чаще отпирается; находка у реки — в каждой главе
	var plant_bad := PackedStringArray()
	var deny_upyr := 0
	var asked_upyr := 0
	for ch: String in ["a1c2", "a1c3"]:
		for sd in range(30):
			var md := _chapter_match(ch, 3300 + sd)
			var m: Match = md[0]
			var d: Director = md[1]
			var finds := m.clues.entries.filter(func(e: Dictionary) -> bool: return String(e.mystery) == "boat" and int(e.who) < 0)
			if finds.size() != 1:
				plant_bad.append("%s/%d: находка у реки %d" % [ch, sd, finds.size()])
			m.clues.plant(ch)
			var cs := m.clues.contradictions()
			if cs.is_empty():
				plant_bad.append("%s/%d: нет противоречия" % [ch, sd])
				continue
			var a: Dictionary = cs[0][0]
			var b: Dictionary = cs[0][1]
			var t := m.get_villager(int(a.who))
			var lines := d.confront(a, b)
			if lines.is_empty() or not d.confront(a, b).is_empty():
				plant_bad.append("%s/%d: вопрос не прошёл или прошёл дважды" % [ch, sd])
				continue
			var admit := lines[0].emotion == "sad"
			if not t.is_upyr and not admit:
				plant_bad.append("%s/%d: человек отпирается" % [ch, sd])
			if t.is_upyr:
				asked_upyr += 1
				deny_upyr += 0 if admit else 1
			for l: ChatLine in lines:
				if bad_tag.search(l.text) != null:
					plant_bad.append("теги в ответе: " + l.text)
			if Campaign.boat_records(m).size() != 2:
				plant_bad.append("%s/%d: находки лодки не попадут в память" % [ch, sd])
	ok += SelfTest._expect(fails, plant_bad.is_empty(), "улики: " + "; ".join(plant_bad.slice(0, 4)))
	ok += SelfTest._expect(fails, asked_upyr == 0 or deny_upyr * 2 > asked_upyr, "улики: упырь не отпирается (%d из %d)" % [deny_upyr, asked_upyr])
	# противоречие по фактам: сказал одно, у двери видели в другом доме
	var mf: Match = _chapter_match("a1c2", 3400)[0]
	var bot: Villager = mf.alive_bots()[0]
	var c1 := mf.clues.add("claim", bot.id, "c", {"house": 1})
	var c2 := mf.clues.add("seen", bot.id, "s", {"house": 2})
	var c3 := mf.clues.add("seen", bot.id, "s", {"house": 1})
	ok += SelfTest._expect(fails, mf.clues.contradiction(c1, c2) and not mf.clues.contradiction(c1, c3), "улики: сказанное и увиденное сравниваются неверно")
	# тетрадь: две спорящие записи — кнопка «Спросить» доступна днём; заложенные записи не вытесняются
	mf.clues.plant("a1c2")
	for i in range(Clues.MAX * 2):
		mf.clues.add("claim", bot.id, "x%d" % i, {"house": 0})
	var shown_ids := mf.clues.shown().map(func(e: Dictionary) -> String: return String(e.id))
	var planted_ok := mf.clues.shown().size() <= Clues.MAX + 1
	for pc: Array in mf.clues.contradictions():
		if String(pc[0].pair) != "" or String(pc[1].pair) != "":
			planted_ok = planted_ok and shown_ids.has(String(pc[0].id)) and shown_ids.has(String(pc[1].id))
	ok += SelfTest._expect(fails, planted_ok, "тетрадь улик: заложенное противоречие вытеснено новыми записями")
	var host := Control.new()
	host.size = Vector2(720, 1280)
	var book := ClueBook.open(host, mf, null)
	var pair: Array = mf.clues.contradictions()[0]
	book.toggle(String(pair[0].id))
	book.toggle(String(pair[1].id))
	ok += SelfTest._expect(fails, not book.ask_btn.disabled and book.status.text == L.t("clue.conflict"), "тетрадь улик: противоречие не видно")
	host.free()

	# TASK-018: разгадка лодки при любых погибших; конец акта помнит лодку и доску
	for dead: Array in [[], [0], [0, 5], [0, 1, 2, 5, 7]]:
		Save.campaign_dead.assign(dead)
		var b := Revelations.beat("boat_answer")
		var good := not String(b[1]).is_empty() and bad_tag.search(String(b[1])) == null
		if dead.has(0) and dead.has(5):
			good = good and String(b[1]).contains(L.t("rev.boat_answer.item").left(20))
		ok += SelfTest._expect(fails, good, "разгадка лодки при погибших %s: «%s»" % [str(dead), b[1]])
	Save.campaign_dead.assign([])
	Save.campaign_memory.clear()
	var open_text := Campaign.act_ending(1)
	for i in range(Campaign.BOAT_SOLVED):
		Save.campaign_memory.append({"ch": "a1c2", "kind": "clue_boat", "who": -1, "day": 1, "knew": []})
	Save.campaign_memory.append({"ch": "a1c3", "kind": "board_deny", "who": -1, "day": 2, "knew": []})
	var solved_text := Campaign.act_ending(1)
	ok += SelfTest._expect(fails, open_text.contains(L.t("camp.act1.boat_open")) and solved_text.contains(L.t("camp.act1.boat"))
		and solved_text.contains(L.t("camp.act1.board_deny")) and Campaign.board_choice() == "deny", "конец акта: не помнит лодку или доску")
	ok += SelfTest._expect(fails, Save.memory_of(-1).size() >= 0 and Save._memory_record({"ch": "a1c3", "kind": "board_silent", "who": -1}).size() > 0,
		"память: запись без жителя не сохраняется")

	# TASK-019: доска — Лида, без неё Рита, без обеих находка; ответ запоминается
	var board_bad := PackedStringArray()
	var tellers := {}
	for sd in range(60):
		var md := _chapter_match("a1c3", 3500 + sd)
		var m: Match = md[0]
		var d: Director = md[1]
		var pair2 := _pair(m, 2, 7)
		if pair2[0] == null:
			continue
		for kill in range(3):
			if kill >= 1:
				(pair2[0] as Villager).alive = false
			if kill == 2 and pair2[1] != null:
				(pair2[1] as Villager).alive = false
			Save.player_name = "" if kill == 1 else "Влади"
			var sc := Scenes.board(m)
			tellers[int(sc.teller)] = true
			var ok_sc := (sc.frames as Array).size() >= 2 and (sc.choice.options as Array).size() == 3
			for f: Dictionary in sc.frames:
				for ln: Dictionary in f.lines:
					if bad_tag.search(String(ln.text)) != null:
						ok_sc = false
			var t := m.get_villager(int(sc.teller))
			if kill == 0 and (t == null or t.story_id != 2):
				ok_sc = false
			if kill >= 1 and t != null and t.story_id == 2:
				ok_sc = false
			if not ok_sc:
				board_bad.append("%d/%d" % [sd, kill])
			if kill == 0:
				m.world.add(WorldLog.Kind.CHOICE, m.day, 0, -1, -1, [0], false, {"scene": "a1c3_board", "choice": "confess"})
				d.board_answer(t, "confess")
				var recs := m.world.campaign_records(m)
				if d.scene_lines.is_empty() or recs.filter(func(r: Dictionary) -> bool: return String(r.kind) == "board_confess").is_empty():
					board_bad.append("%d: ответ у доски не запомнен" % sd)
				d.scene_lines.clear()
		if tellers.size() >= 3:
			break
	# утро главы «Прощание»: сцена доски один раз за партию, после первой ночи
	var chapter_before := Game.chapter
	Game.chapter = Campaign.chapter("a1c3")
	Game.board_done = false
	var mb: Match = _chapter_match("a1c3", 3550)[0]
	var r0 := NightReport.new()
	var s1 := MorningScreen.morning_scene(mb, r0)
	var s2 := MorningScreen.morning_scene(mb, r0)
	ok += SelfTest._expect(fails, String(s1.get("id", "")) == "a1c3_board" and String(s2.get("id", "")) != "a1c3_board",
		"имя на доске: сцены нет на первом утре или она повторяется")
	Game.chapter = chapter_before
	Game.board_done = false
	ok += SelfTest._expect(fails, board_bad.is_empty() and tellers.has(-1), "имя на доске: " + ", ".join(board_bad.slice(0, 5)) + " рассказчики " + str(tellers.keys()))

	# TASK-020: на лодке — раз за главу и только в «Прощании»; упырь возвращается, человек уплывает
	var send_bad := PackedStringArray()
	var gone := 0
	var back_upyr := 0
	for sd in range(40):
		var md := _chapter_match("a1c3", 3600 + sd)
		var m: Match = md[0]
		var bots := m.alive_bots()
		var v: Villager = bots[sd % bots.size()]
		if not m.send_away(v) or m.send_away(bots[(sd + 1) % bots.size()]):
			send_bad.append("%d: не раз за главу" % sd)
			continue
		var r := NightReport.new()
		m._sail(r)
		if v.is_upyr:
			back_upyr += 1
			if not v.alive or v.departed:
				send_bad.append("%d: упырь уплыл" % sd)
		elif not v.alive:
			gone += 1
			if not v.departed:
				send_bad.append("%d: уплывший считается погибшим" % sd)
		if r.entries.is_empty() or not String(r.entries[0].cause).begins_with("boat"):
			send_bad.append("%d: утро не знает о лодке" % sd)
	var m2: Match = _chapter_match("a1c2", 3700)[0]
	if m2.send_away(m2.alive_bots()[0]):
		send_bad.append("лодка доступна не в «Прощании»")
	ok += SelfTest._expect(fails, send_bad.is_empty() and gone > 0 and back_upyr > 0, "прощание: %s (уплыло %d, упырей вернулось %d)" % [", ".join(send_bad.slice(0, 4)), gone, back_upyr])

	Save.campaign_dead.assign(dead_before)
	Save.campaign_memory.assign(mem_before)
	Save.player_name = name_before
	if not backup.is_empty():
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	return ok


# =============================================================
# Группа 5. TASK-021–025: мельник, его тайна, чужаки, половодье, память акта I
# =============================================================
static func _act_two(ch: String, seed_n: int) -> Array:
	var m := Match.new()
	Campaign.setup_match(m, Campaign.chapter(ch))
	m.guests = Campaign.guests(ch)
	m.guest_roles_fixed = String(Campaign.chapter(ch).get("guest_roles", "story")) == "story"
	m.village = load(Campaign.MAPS[String(Campaign.chapter(ch).get("map", "mill"))]) as VillageDef if Campaign.chapter(ch).has("map") else null
	m.start(Campaign.config(ch), seed_n)
	var d := Director.new()
	d.attach(m)
	d.chapter_id = ch
	m.begin_day()
	return [m, d]


static func _no_tags(t: String) -> bool:
	return not t.is_empty() and RegEx.create_from_string("[{}\\[\\]|]").search(t) == null


static func group_five(fails: PackedStringArray) -> int:
	var ok := 0
	var path := ProjectSettings.globalize_path(Save.SETTINGS_PATH)
	var backup := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var dead_before := Save.campaign_dead.duplicate()
	var mem_before := Save.campaign_memory.duplicate(true)
	Save.campaign_dead.assign([])
	Save.campaign_memory.clear()

	# TASK-021: мельник отвечает на один вопрос в день, правило главы звучит в первый день
	var md := _act_two("a2c1", 5100)
	var m: Match = md[0]
	var d: Director = md[1]
	var first := d.npc_answer("ford")
	var again := d.npc_answer("night")
	ok += SelfTest._expect(fails, m.npc_id == "miller" and _no_tags(first) and again.is_empty(), "мельник: вопрос не раз в день («%s» / «%s»)" % [first, again])
	var opening := d.act_two_lines()
	ok += SelfTest._expect(fails, not opening.is_empty() and opening[0].text.contains(L.t("npc.miller.rule").left(20)), "мельник не называет правило главы")
	for t: String in Npc.topics("miller"):
		ok += SelfTest._expect(fails, _no_tags(L.t("npc.miller.q_" + t)) and _no_tags(L.t("npc.miller.a_" + t)), "мельник: нет вопроса или ответа «%s»" % t)

	# TASK-022: по находке о мельнике в каждой главе акта II; исповедь и два решения
	var finds := 0
	for ch: String in ["a2c1", "a2c2", "a2c3"]:
		finds += Campaign.miller_records(_act_two(ch, 5200)[0]).size()
	ok += SelfTest._expect(fails, finds == 3, "тайна мельника: находок %d из 3" % finds)
	var sc0 := Scenes.miller_secret(_act_two("a2c3", 5210)[0])
	for i in range(2):
		Save.campaign_memory.append({"ch": "a2c%d" % (i + 1), "kind": "clue_miller", "who": -1, "day": 1, "knew": []})
	var m3: Match = _act_two("a2c3", 5211)[0]
	var sc1 := Scenes.miller_secret(m3)
	ok += SelfTest._expect(fails, String(sc0.frames[0].lines[0].text) == L.t("sc.miller.1") and String(sc1.frames[0].lines[0].text) == L.t("sc.miller.1_known")
		and (sc1.choice.options as Array).size() == 2, "тайна мельника: сцена не зависит от находок")
	m3.world.add(WorldLog.Kind.CHOICE, m3.day, 0, -1, -1, [0], false, {"scene": "a2c3_miller", "choice": "tell"})
	var recs := m3.world.campaign_records(m3)
	ok += SelfTest._expect(fails, not recs.filter(func(r: Dictionary) -> bool: return String(r.kind) == "miller_tell").is_empty(), "тайна мельника: решение не попадёт в память")
	var outcome := {}
	for choice: String in ["tell", "keep"]:
		Save.campaign_memory.assign(Save.campaign_memory.filter(func(r: Dictionary) -> bool: return not String(r.kind).begins_with("miller_")))
		Save.campaign_memory.append({"ch": "a2c3", "kind": "miller_" + choice, "who": -1, "day": 2, "knew": []})
		var ma: Array = _act_two("a3c1", 5300)
		var cracked := 0
		for t: int in (ma[0] as Match).talisman:
			if t < Match.TALISMAN_MAX:
				cracked += 1
		var lines := (ma[1] as Director).act_two_lines()
		var joined := ""
		for ln: ChatLine in lines:
			joined += ln.text + "\n"
		outcome[choice] = [cracked, joined]
	ok += SelfTest._expect(fails, int(outcome.keep[0]) == 0 and int(outcome.tell[0]) == 1 and String(outcome.keep[1]) != String(outcome.tell[1]),
		"тайна мельника: решения не меняют следующую главу %s" % str(outcome))
	Save.campaign_memory.clear()

	# TASK-023: местные косятся на гостей; охотница в составе — упырь; могилу находит Тимур или другой
	var forced := 0
	var stranger_bad := 0
	var grave_bad := PackedStringArray()
	for sd in range(30):
		var mg: Array = _act_two("a2c2", 5400 + sd)
		var gm: Match = mg[0]
		var gd: Director = mg[1]
		var ups := gm.villagers.filter(func(v: Villager) -> bool: return v.is_upyr).size()
		if ups != gm.config.monsters:
			grave_bad.append("%d: упырей %d" % [sd, ups])
		var hunter := Scenes._anchor(gm, 9)
		if hunter != null:
			forced += 1
			if not hunter.is_upyr:
				grave_bad.append("%d: охотница не упырь" % sd)
		gd.act_two_lines()
		for b: Villager in gm.alive_bots():
			for g: Villager in gm.alive_bots():
				if b.guest_id.is_empty() and not g.guest_id.is_empty() and float(gd.brains[b.id].private_delta.get(g.id, 0.0)) < Director.W_STRANGER:
					stranger_bad += 1
		if sd % 2 == 1:
			var tim := Scenes._anchor(gm, 1)
			if tim != null:
				tim.alive = false
		var sc := Scenes.grave(gm)
		var finder := gm.get_villager(int(sc.finder))
		var t0 := String(sc.frames[0].lines[0].text)
		if finder == null or not _no_tags(t0) or (sd % 2 == 1 and finder.story_id == 1):
			grave_bad.append("%d: нашёл %s" % [sd, finder.name if finder != null else "никто"])
		var last := String((sc.frames.back() as Dictionary).lines[0].text)
		if (hunter != null) != (last != L.t("sc.grave.stranger")):
			grave_bad.append("%d: находка в могиле не та" % sd)
		var before := gm.clues.entries.size()
		gd.grave_found(int(sc.hunter))
		if gm.clues.entries.size() != before + 1 or (not gm.villagers.filter(func(v: Villager) -> bool: return not v.guest_id.is_empty() and v.alive).is_empty() and gd.scene_lines.is_empty()):
			grave_bad.append("%d: после могилы ни улики, ни упрёка гостям" % sd)
	ok += SelfTest._expect(fails, grave_bad.is_empty() and forced > 0 and stranger_bad == 0,
		"чужаки: %s (охотница в составе %d раз, без недоверия %d)" % [", ".join(grave_bad.slice(0, 4)), forced, stranger_bad])

	# TASK-024: половодье — залит один низкий дом, туда никто не идёт, остальные теснее.
	# Баланс: те же партии без половодья для сравнения.
	var flood_bad := PackedStringArray()
	var games := 150
	var wins := {"flood": 0, "dry": 0}
	for mode: String in ["flood", "dry"]:
		for sd in range(games):
			var mf: Array = _act_two("a2c3", 5500 + sd)
			var fm: Match = mf[0]
			var fd: Director = mf[1]
			var pr := RandomNumberGenerator.new()
			pr.seed = 77 + sd
			var low := fm.low_houses()
			if low.size() < 2:
				flood_bad.append("низких домов %d" % low.size())
				break
			if mode == "dry":
				fm.flood_day = -1
			fm.flood_choice = low[sd % low.size()]
			var cap0 := fm.config.capacity
			var guard := 0
			while fm.phase != Match.Phase.OVER and guard < 60:
				guard += 1
				match fm.phase:
					Match.Phase.DAY:
						fd.plan_day()
						fd.opening_lines()
						if mode == "flood" and fm.day >= fm.flood_day:
							if fm.flooded_house < 0 or fm.flooded_house == fm.flood_choice or fm.config.capacity != cap0 + Match.FLOOD_EXTRA:
								flood_bad.append("%d: дом не залит или места те же" % sd)
							for v: Villager in fm.alive():
								if v.announced_house == fm.flooded_house:
									flood_bad.append("%d: %s идёт в залитый дом" % [sd, v.name])
						fd.run_jobs_instant(fd.plan_jobs(fm.config.day_seconds))
						fm.end_day()
					Match.Phase.VOTE:
						var tally: Dictionary[int, int] = {}
						var bv := fd.votes()
						for voter: int in bv:
							tally[bv[voter]] = tally.get(bv[voter], 0) + fm.vote_weight(voter)
						fm.apply_vote(tally, bv)
						fm.after_vote()
					Match.Phase.NIGHT:
						var ch := fd.night_choices()
						if fm.player().alive:
							ch[0] = fm.flooded_house if fm.flooded_house >= 0 else pr.randi_range(0, fm.houses.size() - 1)
						fm.seat_night(ch)
						for s: Match.Seat in fm.seats:
							if s.house == fm.flooded_house and fm.flooded_house >= 0:
								flood_bad.append("%d: ночуют в залитом доме" % sd)
					Match.Phase.DOOR:
						for s: Match.Seat in fm.seats:
							if s.host.is_player:
								fm.door_dilemma(s)
								var ids: Array[int] = []
								for v: Villager in s.knockers():
									if pr.randf() < 0.5:
										ids.append(v.id)
								fm.admit(s, ids)
							else:
								fm.admit(s, fd.host_decide(s, "beg"))
						fm.tunnel_pass(false)
						fd.after_door(fm.seats)
						fd.read_report(fm.resolve_night())
					Match.Phase.MORNING:
						fm.end_morning()
			if fm.winner == Match.Team.PEOPLE:
				wins[mode] += 1
	print("половодье: люди победили в %d из %d, без воды %d" % [wins.flood, games, wins.dry])
	ok += SelfTest._expect(fails, flood_bad.is_empty(), "половодье: " + ", ".join(flood_bad.slice(0, 4)))
	ok += SelfTest._expect(fails, absi(int(wins.flood) - int(wins.dry)) <= games * 0.12 and int(wins.flood) > 0,
		"половодье ломает баланс: люди %d из %d, без воды %d" % [wins.flood, games, wins.dry])

	# TASK-025: акт II помнит акт I; без вспомнивших в главе — письмо; доска меняет мельника
	var mc: Array = _act_two("a2c1", 5600)
	var cm: Match = mc[0]
	var cd: Director = mc[1]
	var present := -1
	var absent := -1
	for v: Villager in cm.alive_bots():
		if v.guest_id.is_empty() and v.story_id >= 0:
			present = v.story_id
	for i in range(L.names().size()):
		if cm.villagers.filter(func(v: Villager) -> bool: return v.story_id == i and v.guest_id.is_empty()).is_empty():
			absent = i
	var texts := []
	for kind: String in ["admitted", "refused"]:
		Save.campaign_memory.assign([{"ch": "a1c2", "kind": kind, "who": present, "day": 1, "knew": []}])
		var cl := cd.carry_lines()
		texts.append(cl[0].text if not cl.is_empty() else "")
	Save.campaign_memory.assign([{"ch": "a1c3", "kind": "kept", "who": absent, "day": 1, "knew": []}])
	var letter := cd.carry_lines()
	ok += SelfTest._expect(fails, _no_tags(String(texts[0])) and _no_tags(String(texts[1])) and texts[0] != texts[1]
		and letter.size() == 1 and letter[0].kind == ChatLine.Kind.SYSTEM and _no_tags(letter[0].text),
		"память акта I: реплики %s, письмо %s" % [str(texts), letter[0].text if not letter.is_empty() else "нет"])
	for kind: String in WorldLog.RANK:
		ok += SelfTest._expect(fails, _no_tags(L.t("carry." + kind, {"me": cm.alive_bots()[0]})), "нет реплики памяти «%s»" % kind)
	Save.campaign_memory.assign([{"ch": "a1c3", "kind": "board_confess", "who": -1, "day": 2, "knew": []}])
	var with_board := cd.act_two_lines()
	ok += SelfTest._expect(fails, with_board.size() >= 2 and with_board[1].text.contains(L.t("npc.miller.board_confess").left(15)), "ответ у доски не меняет мельника")
	Save.campaign_memory.assign([{"ch": "a2c3", "kind": "miller_keep", "who": -1, "day": 2, "knew": []}])
	Save.campaign_dead.assign([0, 4, 6])
	var end2 := Campaign.act_ending(2)
	ok += SelfTest._expect(fails, end2.contains(L.t("camp.act2.miller_keep")) and end2.contains(L.t("camp.act2.sum_some", {"n": 3})), "концовка акта II не считает два акта: «%s»" % end2)

	Save.campaign_dead.assign(dead_before)
	Save.campaign_memory.assign(mem_before)
	if not backup.is_empty():
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	return ok


## Мельник на карте (TASK-021): отдельная фигура, не житель; виден в кадре, тап по нему — его, а не жителя.
static func npc_on_map(tree: SceneTree, fails: PackedStringArray) -> int:
	var ok := 0
	var path := ProjectSettings.globalize_path(Save.SETTINGS_PATH)
	var backup := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	Save.campaign_reset()
	Game.start(Campaign.config("a2c1"), "", Campaign.chapter("a2c1"))
	for i in range(30):
		await tree.process_frame
	var guard := 0
	while not (Nav.host.current is DayScreen) and guard < 10:
		guard += 1
		if Game.m != null and Game.m.phase != Match.Phase.DAY:
			Game.proceed()
		for i in range(20):
			await tree.process_frame
	var cr := Nav.village.crowd
	var npc := cr.npc
	ok += SelfTest._expect(fails, npc != null and npc.visible, "мельника нет на карте главы «Брод»")
	if npc != null:
		ok += SelfTest._expect(fails, cr.figures.size() == Game.m.villagers.size() and npc.get_parent() == cr and not cr.figures.values().any(func(f: VillagerFigure) -> bool: return f.get_instance_id() == npc.get_instance_id()), "мельник попал в жители")
		var c := npc.hit_rect_global().get_center()
		ok += SelfTest._expect(fails, cr.npc_at(c) == "miller" and cr.figure_at(c) < 0, "тап по мельнику попадает в жителя")
		var vp := Rect2(Vector2.ZERO, tree.root.get_visible_rect().size)
		ok += SelfTest._expect(fails, vp.has_point(c), "мельник за краем экрана: %s" % str(c))
	Game.abandon()
	Nav.show_menu()
	for i in range(10):
		await tree.process_frame
	if not backup.is_empty():
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	return ok


# =============================================================
# Группа 6. TASK-026–030: книга у ворот, Игнат и Анфиса, колокол, крипта, доверие
# =============================================================
static func group_six(fails: PackedStringArray) -> int:
	var ok := 0
	var path := ProjectSettings.globalize_path(Save.SETTINGS_PATH)
	var backup := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var dead_before := Save.campaign_dead.duplicate()
	var mem_before := Save.campaign_memory.duplicate(true)
	var name_before := Save.player_name
	Save.campaign_dead.assign([])
	Save.campaign_memory.clear()

	# TASK-027: Игнат и Анфиса — по вопросу в день каждому, свои реплики по дням
	var md := _act_two("a3c1", 6100)
	var m: Match = md[0]
	var d: Director = md[1]
	var a1 := d.npc_answer("night", "ignat")
	var a2 := d.npc_answer("before", "ignat")
	var a3 := d.npc_answer("heal", "anfisa")
	var opening := d.act_two_lines()
	ok += SelfTest._expect(fails, m.all_npcs() == PackedStringArray(["ignat", "anfisa"]) and _no_tags(a1) and a2.is_empty() and _no_tags(a3)
		and opening.size() >= 2, "Игнат и Анфиса: вопрос не по одному в день или нет первых реплик")
	m.day = 2
	var d2 := d.act_three_daily()
	m.day = 3
	var d3 := d.act_three_daily()
	ok += SelfTest._expect(fails, d2.size() == 1 and d3.size() == 1 and d2[0].text != d3[0].text and d2[0].npc_id != d3[0].npc_id, "хозяева монастыря не меняют реплик по дням")
	m.day = 1

	# TASK-026: книга у ворот — игрок одно имя в день; вписанный входит без вопросов; боты тоже вписывают
	var bots := m.alive_bots()
	var v0: Villager = bots[0]
	var v1: Villager = bots[1]
	var first := m.vouch(m.player(), v0)
	var second := m.vouch(m.player(), v1)
	ok += SelfTest._expect(fails, first and not second and m.voucher_of(v0.id, 0) == 0, "книга: игрок вписывает больше одного имени в день")
	var vouch_clues := m.clues.entries.filter(func(e: Dictionary) -> bool: return String(e.kind) == "vouch").size()
	d.bots_vouch()
	var bot_vouches := m.vouches.filter(func(e: Dictionary) -> bool: return int(e.by) != 0).size()
	ok += SelfTest._expect(fails, vouch_clues == 1 and bot_vouches >= 1 and bot_vouches <= Director.VOUCH_BOTS
		and m.clues.entries.filter(func(e: Dictionary) -> bool: return String(e.kind) == "vouch").size() == 1 + bot_vouches,
		"книга: поручительства ботов не попадают в улики (%d)" % bot_vouches)
	m.phase = Match.Phase.DOOR
	var s := Match.Seat.new()
	s.house = 0
	s.host = m.player()
	s.queue.append(v0)
	s.queue.append(v1)
	m.seats.assign([s])
	m.admit(s, [] as Array[int])
	ok += SelfTest._expect(fails, s.admitted.has(v0) and not s.admitted.has(v1), "книга: вписанный не вошёл без вопросов")
	# вписанный упырь у двери игрока: доверие падает на два
	var up: Villager = null
	for v: Villager in m.alive_bots():
		if v.is_upyr:
			up = v
	if up != null:
		m.vouches.append({"by": 0, "who": up.id, "day": 1})
		var s2 := Match.Seat.new()
		s2.house = 0
		s2.host = m.player()
		s2.queue.append(up)
		m.seats.assign([s2])
		m.admit(s2, [] as Array[int])
		var t0 := m.trust
		m._night_trust(NightReport.new())
		ok += SelfTest._expect(fails, s2.admitted.has(up) and m.trust == t0 - 2, "книга: за вписанного упыря доверие не падает вдвое (%d → %d)" % [t0, m.trust])

	# TASK-030: доверие в обе стороны; на нуле голос игрока не считается; переходит в следующую главу
	var mt: Match = _act_two("a3c2", 6200)[0]
	mt.trust = 1
	mt.trust_add(-1, "test")
	var muted := mt.vote_weight(0) == 0 and mt.trust_mute_day == mt.day
	mt.trust_add(2, "test")
	ok += SelfTest._expect(fails, muted and mt.trust == 2 and mt.vote_weight(1) >= 1, "доверие: ноль не глушит голос или не растёт обратно")
	Save.campaign_memory.assign([{"ch": "a3c1", "kind": "trust", "who": -1, "day": 1, "knew": []}])
	ok += SelfTest._expect(fails, Campaign.trust_start("a3c2") == 1 and Campaign.trust_start("a3c1") == Match.TRUST_START, "доверие не переходит между главами акта")
	Save.campaign_memory.clear()
	var mv: Array = _act_two("a3c2", 6210)
	var vm: Match = mv[0]
	var t1 := vm.trust
	var human: Villager = vm.alive_bots().filter(func(v: Villager) -> bool: return not v.is_upyr)[0]
	vm.phase = Match.Phase.VOTE
	var tally: Dictionary[int, int] = {human.id: 5}
	vm.apply_vote(tally, {0: human.id})
	ok += SelfTest._expect(fails, vm.trust == t1 - 1, "доверие: ошибочное изгнание не снижает")

	# TASK-028: колокол бьёт номер дома, где ночью упырь; совпадает всегда
	var bell_bad := PackedStringArray()
	var rings := 0
	for sd in range(40):
		var mb: Array = _act_two("a3c2", 6300 + sd)
		var bm: Match = mb[0]
		var bd: Director = mb[1]
		bd.plan_day()
		bm.end_day()
		if bm.phase == Match.Phase.VOTE:
			var bv := bd.votes()
			var tl: Dictionary[int, int] = {}
			for voter: int in bv:
				tl[bv[voter]] = tl.get(bv[voter], 0) + 1
			bm.apply_vote(tl, bv)
			bm.after_vote()
		if bm.phase != Match.Phase.NIGHT:
			continue
		bm.seat_night(bd.night_choices())
		for st: Match.Seat in bm.seats:
			var adm: Array[int] = []
			if not st.host.is_player:
				adm = bd.host_decide(st)
			bm.admit(st, adm)
		var expect: Array[int] = []
		for st: Match.Seat in bm.seats:
			if st.inside().any(func(v: Villager) -> bool: return v.is_upyr):
				expect.append(st.house + 1)
		expect.sort()
		bm.resolve_night()
		rings += bm.last_bells.size()
		if bm.last_bells != expect:
			bell_bad.append("%d: %s вместо %s" % [sd, str(bm.last_bells), str(expect)])
	ok += SelfTest._expect(fails, bell_bad.is_empty() and rings > 0, "колокол: %s (ударов %d)" % [", ".join(bell_bad.slice(0, 3)), rings])
	ok += SelfTest._expect(fails, _no_tags(L.t("mo.bell", {"n": 3})), "колокол: строка утра с дырой")

	# книга Анфисы: нерешённые загадки она договаривает сама, решённые — нет
	Save.player_name = ""
	var open := Scenes.crossed_book(_act_two("a3c2", 6400)[0])
	for i in range(Campaign.BOAT_SOLVED):
		Save.campaign_memory.append({"ch": "a1c2", "kind": "clue_boat", "who": -1, "day": 1, "knew": []})
	Save.campaign_memory.append({"ch": "a1c3", "kind": "board_deny", "who": -1, "day": 1, "knew": []})
	Save.campaign_memory.append({"ch": "a2c3", "kind": "miller_keep", "who": -1, "day": 2, "knew": []})
	Save.player_name = "Влади"
	var closed := Scenes.crossed_book(_act_two("a3c2", 6401)[0])
	var tags_ok := true
	for sc: Dictionary in [open, closed, Scenes.crypt(_act_two("a3c3", 6402)[0])]:
		for f: Dictionary in sc.frames:
			for ln: Dictionary in f.lines:
				tags_ok = tags_ok and _no_tags(String(ln.text))
	ok += SelfTest._expect(fails, int(open.told) == 3 and int(closed.told) == 0 and tags_ok, "книга Анфисы: ответ не зависит от разгаданного (%d/%d)" % [open.told, closed.told])

	# TASK-029: суд — исход только по журналу; проигрыш изгоняет игрока и даёт свою концовку акта
	var mj: Array = _act_two("a3c3", 6500)
	var jm: Match = mj[0]
	var jd: Director = mj[1]
	var present: Array[int] = []
	for v: Villager in jm.alive_bots():
		if v.guest_id.is_empty():
			present.append(v.story_id)
	Save.campaign_memory.assign([
		{"ch": "a1c2", "kind": "admitted", "who": present[0], "day": 1, "knew": []},
		{"ch": "a2c1", "kind": "kept", "who": present[1], "day": 1, "knew": []},
		{"ch": "a2c2", "kind": "refused", "who": present[2], "day": 1, "knew": []}])
	var good := Scenes.trial(jm)
	Save.campaign_memory.assign([
		{"ch": "a1c2", "kind": "refused", "who": present[0], "day": 1, "knew": []},
		{"ch": "a2c1", "kind": "broken", "who": present[1], "day": 1, "knew": []},
		{"ch": "a2c2", "kind": "kept", "who": present[2], "day": 1, "knew": []}])
	var bad := Scenes.trial(jm)
	var trial_tags := true
	for sc: Dictionary in [good, bad]:
		for f: Dictionary in sc.frames:
			for ln: Dictionary in f.lines:
				trial_tags = trial_tags and _no_tags(String(ln.text))
	ok += SelfTest._expect(fails, bool(good.acquit) and not bool(bad.acquit) and int(good.defenders) == 2 and int(bad.accusers) == 2 and trial_tags,
		"суд: исход не по журналу")
	for k: String in Campaign.TRIAL_DEF + Campaign.TRIAL_ACC:
		var side := "def" if Campaign.TRIAL_DEF.has(k) else "acc"
		ok += SelfTest._expect(fails, _no_tags(L.t("trial.%s.%s" % [side, k], {"me": jm.alive_bots()[0]})), "суд: нет реплики %s" % k)
	jm.phase = Match.Phase.MORNING
	jd.trial_result(false)
	var recs := jm.world.campaign_records(jm)
	ok += SelfTest._expect(fails, not jm.player().alive and jm.player().exiled and not recs.filter(func(r: Dictionary) -> bool: return String(r.kind) == "trial_lost").is_empty(),
		"суд: проигрыш не изгоняет игрока или не попадёт в память")
	Save.campaign_memory.assign([{"ch": "a3c3", "kind": "trial_lost", "who": -1, "day": 2, "knew": []}])
	ok += SelfTest._expect(fails, Campaign.act_ending(3) == L.t("camp.act3.end_trial"), "суд: у проигрыша нет своей концовки акта")

	Save.campaign_dead.assign(dead_before)
	Save.campaign_memory.assign(mem_before)
	Save.player_name = name_before
	if not backup.is_empty():
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	return ok


# =============================================================
# Группа 7. TASK-031–035: станция, люди станции, список, последний поезд, финал
# =============================================================
static func group_seven(fails: PackedStringArray) -> int:
	var ok := 0
	var path := ProjectSettings.globalize_path(Save.SETTINGS_PATH)
	var backup := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var dead_before := Save.campaign_dead.duplicate()
	var mem_before := Save.campaign_memory.duplicate(true)
	Save.campaign_dead.assign([])
	Save.campaign_memory.clear()

	# TASK-031, 032: рельсы на карте станции; смотритель, рабочий депо и писарь в главах акта IV
	var st := load(Campaign.MAPS["station"]) as VillageDef
	var m1: Array = _act_two("a4c1", 7100)
	var m2: Array = _act_two("a4c2", 7101)
	var g1 := (m1[0] as Match).villagers.filter(func(v: Villager) -> bool: return v.guest_id == "worker")
	var g2 := (m2[0] as Match).villagers.filter(func(v: Villager) -> bool: return v.guest_id == "clerk")
	ok += SelfTest._expect(fails, st.rails_y > 0.0 and (m1[0] as Match).npc_id == "keeper" and g1.size() == 1 and g2.size() == 1,
		"станция: нет рельсов, смотрителя, рабочего или писаря")
	var gtexts := true
	for v: Villager in [g1[0], g2[0]]:
		for step in range(1, Guests.REVEAL_DAY + 1):
			gtexts = gtexts and _no_tags(Guests.clue(v, step))
		gtexts = gtexts and _no_tags(Guests.title(v)) and _no_tags(L.t("guest.%s.reveal_u" % v.guest_id, {"who": v}))
	var opening := (m2[1] as Director).act_two_lines()
	ok += SelfTest._expect(fails, gtexts and opening.size() >= 2 and opening.any(func(l: ChatLine) -> bool: return l.speaker != null and l.speaker.guest_id == "clerk"),
		"люди станции: дыры в текстах или писарь молчит")
	for snd: String in ["whistle", "rails", "typewriter", "train"]:
		ok += SelfTest._expect(fails, ResourceLoader.exists("res://assets/sfx/%s.ogg" % snd), "нет звука %s" % snd)

	# TASK-033, 034: список на поезд; союзник всегда есть и тайно вписывает упыря (или себя, если он сам упырь)
	var list_bad := PackedStringArray()
	var kinds := {}
	for sd in range(30):
		var mt: Array = _act_two("a4c3", 7200 + sd)
		var tm: Match = mt[0]
		var td: Director = mt[1]
		td.plan_day()
		td.act_two_lines()
		var ally := tm.get_villager(td.ally_id)
		if ally == null:
			list_bad.append("%d: нет союзника" % sd)
			continue
		kinds["upyr" if ally.is_upyr else ("clerk" if ally.guest_id == "clerk" else "human")] = true
		var secret := tm.train_list.filter(func(e: Dictionary) -> bool: return bool(e.secret))
		if secret.size() != 1 or not tm.get_villager(int(secret[0].who)).is_upyr or int(secret[0].by) != ally.id:
			list_bad.append("%d: тайной записи нет" % sd)
		if tm.train_list.size() > tm.train_cap():
			list_bad.append("%d: список больше мест" % sd)
		var free: Array = tm.alive_bots().filter(func(v: Villager) -> bool: return not tm.on_train(v.id))
		if free.size() >= 2 and tm.train_list.size() + 2 <= tm.train_cap():
			var a: Villager = free[0]
			var b: Villager = free[1]
			if not tm.train_add(tm.player(), a) or tm.train_add(tm.player(), b):
				list_bad.append("%d: игрок вписывает не одно имя в день" % sd)
			tm.world.add(WorldLog.Kind.ADMIT, tm.day, a.id, 0, 0)
			if not tm.train_strike(tm.player(), a) or tm.train_add(tm.player(), a):
				list_bad.append("%d: вычеркнутого вписали обратно" % sd)
			var l := td.on_struck(a)
			if l == null or l.text != L.t("st.struck_door", {"me": a}):
				list_bad.append("%d: вычеркнутый не вспомнил дверь" % sd)
		var sc := Scenes.betrayal(tm, ally)
		for f: Dictionary in sc.frames:
			for ln: Dictionary in f.lines:
				if not _no_tags(String(ln.text)):
					list_bad.append("%d: дыра в сцене: %s" % [sd, ln.text])
		td.betrayal_answer("expose" if sd % 2 == 0 else "cover")
		if sd % 2 == 0 and tm.train_list.any(func(e: Dictionary) -> bool: return bool(e.secret)):
			list_bad.append("%d: после «выдать» подпись осталась тайной" % sd)
		if sd % 2 == 1 and td.scene_lines.is_empty():
			list_bad.append("%d: прикрытый союзник молчит" % sd)
	ok += SelfTest._expect(fails, list_bad.is_empty() and kinds.size() >= 2, "список и союзник: %s (виды союзника %s)" % [", ".join(list_bad.slice(0, 4)), str(kinds.keys())])

	# TASK-035: финал — четыре концовки достижимы, голос за дверью по журналу, эпилог по всем жителям
	var fm: Match = _act_two("a4c3", 7300)[0]
	var endings := {}
	endings[Campaign.final_ending("open", fm)] = true
	fm.train_list.clear()
	endings[Campaign.final_ending("train", fm)] = true
	Save.campaign_dead.assign([3, 5, 6, 9, 10])
	endings[Campaign.final_ending("train", fm)] = true
	var up: Villager = fm.alive_bots().filter(func(v: Villager) -> bool: return v.is_upyr)[0]
	fm.train_list.append({"who": up.id, "by": 0, "day": 1, "secret": false})
	endings[Campaign.final_ending("train", fm)] = true
	var all_ok := true
	for e: String in Campaign.FINAL_ENDINGS:
		all_ok = all_ok and endings.has(e) and Progress.ENDINGS.has(e) and _no_tags(L.t("ending." + e)) and _no_tags(L.t("fin." + e))
	ok += SelfTest._expect(fails, all_ok, "финал: достижимы не все концовки %s" % str(endings.keys()))
	var door := Scenes.final_door()
	Save.campaign_dead.assign([])
	var door_self := Scenes.final_door()
	ok += SelfTest._expect(fails, String(door.voice) == L.names()[3][0] and String(door_self.voice).is_empty()
		and String(door_self.frames[1].lines[0].text) == L.t("sc.final.voice_self"), "финал: голос за дверью не того, кого потеряли первым")
	var epi := Campaign.epilogue_lines(fm, "final_upyr")
	var epi_ok := epi.size() == L.names().size()
	for line: String in epi:
		epi_ok = epi_ok and _no_tags(line)
	ok += SelfTest._expect(fails, epi_ok, "финал: эпилог не по всем жителям или с дырами")

	Save.campaign_dead.assign(dead_before)
	Save.campaign_memory.assign(mem_before)
	if not backup.is_empty():
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	return ok
