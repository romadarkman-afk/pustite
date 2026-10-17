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
	var first_day := MorningScreen.morning_scene(mb, r0)
	mb.day = 2
	var s1 := MorningScreen.morning_scene(mb, r0)
	var s2 := MorningScreen.morning_scene(mb, r0)
	ok += SelfTest._expect(fails, String(first_day.get("id", "")) != "a1c3_board" and String(s1.get("id", "")) == "a1c3_board"
		and String(s2.get("id", "")) != "a1c3_board", "имя на доске: сцена не на втором утре или повторяется")
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
