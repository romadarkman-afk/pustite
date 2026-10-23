class_name StoryTests
extends RefCounted
## Ветки сюжета кампании (TASK-092). Журнал кампании задаётся руками, дальше проверяется,
## какая сцена, реплика и концовка из него получается. Экранов нет: только данные, поэтому быстро.
## Состояние Save в памяти подменяется и возвращается, файл настроек восстанавливается байт в байт.

const FIRST_THREE := [0, 1, 2]       ## Марина, Тимур, Лида: считаются в концовке акта


static func _ok(fails: PackedStringArray, cond: bool, msg: String) -> int:
	if not cond:
		fails.append(msg)
	return 1 if cond else 0


static func _mem(kind: String, who: int, ch: String = "a1c2") -> Dictionary:
	return {"ch": ch, "kind": kind, "who": who, "day": 1, "knew": []}


static func _journal(list: Array) -> void:
	var out: Array[Dictionary] = []
	for rec: Variant in list:
		out.append(rec as Dictionary)
	Save.campaign_memory = out


static func _dead(list: Array) -> void:
	var out: Array[int] = []
	for i: Variant in list:
		out.append(int(i))
	Save.campaign_dead = out


## Партия главы так, как её собирает Game.start. Погибшие из Save.campaign_dead в состав не входят.
static func _match(id: String, seed_n: int = 11) -> Match:
	var ch := Campaign.chapter(id)
	var m := Match.new()
	m.cast = Campaign.cast(id)
	m.guests = Campaign.guests(id)
	m.guest_roles_fixed = String(ch.get("guest_roles", "story")) == "story"
	if id in ["a1c2", "a1c3"]:
		m.plant_chapter = id
	Campaign.setup_match(m, ch)
	m.village = SimChapters.village(id)
	m.start(Campaign.config(id), seed_n)
	m.begin_day()
	return m


static func _story_ids(m: Match) -> Array[int]:
	var out: Array[int] = []
	for v: Villager in m.villagers:
		if not v.is_player and v.guest_id.is_empty():
			out.append(v.story_id)
	return out


static func _frames_text(sc: Dictionary) -> String:
	var out := PackedStringArray()
	for f: Dictionary in sc.get("frames", []):
		for line: Dictionary in f.get("lines", []):
			out.append(String(line.get("text", "")))
	return "\n".join(out)


# =============================================================
# Суд в крипте
# =============================================================
static func trial(fails: PackedStringArray) -> int:
	var ok := 0
	var cases := [
		["пустой журнал", [], true, 0, 0],
		["добро перевешивает", [_mem("admitted", 0), _mem("kept", 1), _mem("listened", 2), _mem("refused_died", 3), _mem("refused", 4)], true, 3, 2],
		["зло перевешивает", [_mem("kept", 0), _mem("refused_died", 1), _mem("broken", 2), _mem("exiled_by_you", 3)], false, 1, 3],
		["ничья в пользу игрока", [_mem("kept", 0), _mem("refused", 1)], true, 1, 1],
		["записи без жителя не считаются", [_mem("admitted", -1), _mem("refused_died", -1)], true, 0, 0],
		["реакции близких", [_mem("react_defend", 0), _mem("react_accuse", 1), _mem("react_revenge", 2)], false, 1, 2],
	]
	for c: Array in cases:
		_journal(c[1])
		var t := Campaign.trial(null)
		ok += _ok(fails, bool(t.acquit) == bool(c[2]), "суд «%s»: оправдан %s, ожидали %s" % [c[0], t.acquit, c[2]])
		ok += _ok(fails, (t.def as Array).size() == int(c[3]) and (t.acc as Array).size() == int(c[4]),
			"суд «%s»: защитников %d, обвинителей %d, ожидали %d и %d" % [c[0], (t.def as Array).size(), (t.acc as Array).size(), c[3], c[4]])
		var m := _match("a3c3")
		var sc := Scenes.trial(m)
		ok += _ok(fails, bool(sc.acquit) == bool(c[2]), "сцена суда «%s» расходится с исходом" % c[0])
		ok += _ok(fails, Scenes.sound_problems(sc, true).is_empty(), "сцена суда «%s»: звуки не сходятся" % c[0])
		var text := _frames_text(sc)
		ok += _ok(fails, text.contains(L.t("sc.trial.acquit" if bool(c[2]) else "sc.trial.convict")), "сцена суда «%s»: нет приговора" % c[0])
		var nobody := text.contains(L.t("sc.trial.nobody"))
		ok += _ok(fails, nobody == (int(c[3]) + int(c[4]) == 0), "сцена суда «%s»: строка «никто не пришёл» %s" % [c[0], "лишняя" if nobody else "пропала"])
	# исходы: оправдали, доверие не падает; осудили, игрока изгоняют и глава идёт без него
	_journal([])
	var won := _match("a3c3")
	var d1 := Director.new()
	d1.attach(won)
	var trust := won.trust
	d1.trial_result(true)
	ok += _ok(fails, won.trust >= trust and won.player().alive, "оправдание уронило доверие или убило игрока")
	ok += _ok(fails, not d1.scene_lines.is_empty(), "после оправдания Анфиса молчит")
	var lost := _match("a3c3")
	var d2 := Director.new()
	d2.attach(lost)
	d2.trial_result(false)
	ok += _ok(fails, not lost.player().alive and lost.player().exiled, "осуждённого игрока не изгнали")
	return ok


# =============================================================
# Замены погибших рассказчиков
# =============================================================
static func replacements(fails: PackedStringArray) -> int:
	var ok := 0
	for id: String in Revelations.LIST:
		var srcs: Array = Revelations.LIST[id].sources
		var main := int(srcs[0])
		var spare := int(srcs[1])
		var main_name := String(L.names()[main][0])
		# оба живы: рассказывает главный
		_dead([])
		var s0 := Revelations.source(id)
		ok += _ok(fails, int(s0.who) == main and int(s0.lost) == -1, "%s: при живых рассказывает %d, потерь %d" % [id, s0.who, s0.lost])
		# главный погиб: запасной, и сцена говорит о потере
		_dead([main])
		var s1 := Revelations.source(id)
		ok += _ok(fails, int(s1.who) == spare and int(s1.lost) == main, "%s: без главного рассказывает %d, потеря %d" % [id, s1.who, s1.lost])
		var beat := Revelations.beat(id)
		ok += _ok(fails, String(beat[1]).begins_with(L.t("rev.instead", {"lost": Revelations._person(main, null)})) and String(beat[1]).contains(main_name),
			"%s: сцена не называет погибшего «%s»" % [id, main_name])
		# погибли оба: находка вместо рассказа
		_dead([main, spare])
		var s2 := Revelations.source(id)
		ok += _ok(fails, int(s2.who) == -1 and int(s2.lost) == main, "%s: без обоих рассказчик %d" % [id, s2.who])
		ok += _ok(fails, String(Revelations.beat(id)[1]).contains(L.t("rev.%s.item" % id)), "%s: нет находки вместо рассказа" % id)
		# запасной погиб, главный жив: ничего не меняется
		_dead([spare])
		var s3 := Revelations.source(id)
		ok += _ok(fails, int(s3.who) == main and int(s3.lost) == -1, "%s: гибель запасного сдвинула рассказчика" % id)
		# главный жив, но его нет в главе: рассказывает запасной, о потере не говорят
		_dead([])
		var s4 := Revelations.source(id, [spare])
		ok += _ok(fails, int(s4.who) == spare and int(s4.lost) == -1, "%s: отсутствующий главный считается погибшим" % id)
	# Лида (2) и «Имя на доске»: рассказывает Рита, потом никто
	for dead_list: Array in [[], [2], [2, 7]]:
		_dead(dead_list)
		var m := _match("a1c3")
		var present := _story_ids(m)
		var expect := -1                                  # Рита может не попасть в состав главы: тогда у доски никого
		for idx: int in [2, 7]:
			if present.has(idx):
				expect = idx
				break
		var sc := Scenes.board(m)
		var teller := m.get_villager(int(sc.teller))
		var who := teller.story_id if teller != null else -1
		ok += _ok(fails, who == expect, "доска, погибшие %s: рассказчик %d, ожидали %d" % [str(dead_list), who, expect])
		var text := _frames_text(sc)
		var lost := dead_list.has(2)
		ok += _ok(fails, text.contains(L.t("rev.instead", {"lost": Revelations._person(2, null)})) == lost, "доска, погибшие %s: строка о потере %s" % [str(dead_list), "пропала" if lost else "лишняя"])
		ok += _ok(fails, text.contains(L.t("sc.board.alone")) == (expect < 0), "доска, погибшие %s: строка «один у доски» не там" % str(dead_list))
		ok += _ok(fails, Scenes.sound_problems(sc, true).is_empty(), "доска, погибшие %s: звуки не сходятся" % str(dead_list))
	# Тимур (1) и «Чужаки»: могилу находит Тимур, без него Миша, без обоих любой местный
	for dead_list: Array in [[], [1], [1, 8]]:
		_dead(dead_list)
		var m2 := _match("a2c2")
		var present := _story_ids(m2)
		var expect := -2
		for idx: int in [1, 8]:
			if present.has(idx):
				expect = idx
				break
		var sc2 := Scenes.grave(m2)
		var finder := m2.get_villager(int(sc2.finder))
		ok += _ok(fails, finder != null, "могила, погибшие %s: некому найти" % str(dead_list))
		if finder != null:
			if expect >= 0:
				ok += _ok(fails, finder.story_id == expect, "могила, погибшие %s: нашёл %d, ожидали %d" % [str(dead_list), finder.story_id, expect])
			else:
				ok += _ok(fails, finder.guest_id.is_empty() and not finder.is_player, "могила, погибшие %s: нашёл гость или игрок" % str(dead_list))
		ok += _ok(fails, Scenes.sound_problems(sc2, true).is_empty(), "могила, погибшие %s: звуки не сходятся" % str(dead_list))
	# нож в могиле: хозяйка ножа жива и есть в составе, иначе чужой путник
	_dead([])
	var knife := _match("a2c2")
	var has_nina := _story_ids(knife).has(9)
	var knife_sc := Scenes.grave(knife)
	ok += _ok(fails, (int(knife_sc.hunter) >= 0) == has_nina, "нож: охотница %s, а в сцене её %s" % [str(has_nina), "нет" if int(knife_sc.hunter) < 0 else "есть"])
	_dead([9])
	var no_knife := Scenes.grave(_match("a2c2"))
	ok += _ok(fails, int(no_knife.hunter) < 0 and _frames_text(no_knife).contains(L.t("sc.grave.stranger")), "нож: без охотницы в могиле должен лежать чужой путник")
	return ok


# =============================================================
# Концовки
# =============================================================
static func endings(fails: PackedStringArray) -> int:
	var ok := 0
	# концовка акта по трём первым жителям: все живы, кто-то погиб, никого
	for act in range(1, Campaign.ENDING_ACTS + 1):
		var cases := [[[], "all"], [[0], "some"], [[1, 2], "some"], [[0, 1, 2], "none"], [[5, 6, 7, 8], "all"]]
		for c: Array in cases:
			_dead(c[0])
			var want := "act%d_%s" % [act, c[1]]
			ok += _ok(fails, Campaign.act_ending_id(act) == want, "акт %d, погибшие %s: концовка %s, ожидали %s" % [act, str(c[0]), Campaign.act_ending_id(act), want])
		for kind: String in ["all", "some", "none"]:
			ok += _ok(fails, L.has("camp.act%d.end_%s" % [act, kind]), "нет текста camp.act%d.end_%s" % [act, kind])
		_dead([])
		ok += _ok(fails, not Campaign.act_ending(act).is_empty(), "акт %d: пустой текст концовки" % act)
	_dead([])
	ok += _ok(fails, Campaign.act_ending_id(0).is_empty() and Campaign.act_ending_id(Campaign.ENDING_ACTS + 1).is_empty(), "концовка вне актов не пустая")
	# акт I помнит лодку и доску
	_journal([])
	var a1_open := Campaign.act_ending(1)
	ok += _ok(fails, a1_open.contains(L.t("camp.act1.boat_open")) and not a1_open.contains(L.t("camp.act1.boat")), "акт I: без находок лодка должна оставаться загадкой")
	_journal([_mem("clue_boat", -1), _mem("clue_boat", -1, "a1c3"), _mem("clue_boat", -1, "a1c3"), _mem("board_deny", -1, "a1c3")])
	var a1_solved := Campaign.act_ending(1)
	ok += _ok(fails, Campaign.boat_clues() == 3 and Campaign.board_choice() == "deny", "журнал: лодка %d, доска «%s»" % [Campaign.boat_clues(), Campaign.board_choice()])
	ok += _ok(fails, a1_solved.contains(L.t("camp.act1.boat")) and a1_solved.contains(L.t("camp.act1.board_deny")), "акт I: разгаданная лодка и ответ у доски не в тексте")
	# акт II: мельник и число потерь за два акта
	for c: Array in [[[0, 1], "camp.act2.sum_few"], [[0, 1, 2, 3, 4], "camp.act2.sum_some"], [[0, 1, 2, 3, 4, 5], "camp.act2.sum_many"]]:
		_dead(c[0])
		_journal([_mem("miller_keep", -1, "a2c3")])
		var a2 := Campaign.act_ending(2)
		ok += _ok(fails, a2.contains(L.t(String(c[1]), {"n": (c[0] as Array).size()})), "акт II, погибших %d: нет итога %s" % [(c[0] as Array).size(), c[1]])
		ok += _ok(fails, a2.contains(L.t("camp.act2.miller_keep")), "акт II: нет ответа о мельнике")
	# акт III: проигранный суд даёт свою концовку, выигранный дописывается
	_dead([])
	_journal([_mem("trial_lost", -1, "a3c3")])
	ok += _ok(fails, Campaign.act_ending(3) == L.t("camp.act3.end_trial"), "акт III: проигранный суд не заменил концовку")
	_journal([_mem("trial_won", -1, "a3c3")])
	ok += _ok(fails, Campaign.act_ending(3).ends_with(L.t("camp.act3.trial_won")), "акт III: выигранный суд не дописан")
	# четыре финала
	_journal([])
	var train := _match("a4c3")
	train.train_list.clear()
	_dead([])
	ok += _ok(fails, Campaign.final_ending("open", train) == "final_shore", "финал: открытая дверь должна вести на тот берег")
	var upyr: Villager = null
	var human: Villager = null
	for v: Villager in train.alive_bots():
		if v.is_upyr and upyr == null:
			upyr = v
		elif not v.is_upyr and human == null:
			human = v
	ok += _ok(fails, upyr != null and human != null, "финал: в партии нет упыря и человека")
	if upyr != null and human != null:
		train.train_add(human, human)
		ok += _ok(fails, Campaign.final_ending("train", train) == "final_many", "финал: поезд без упыря и без потерь не «многие»")
		_dead([0, 1, 2, 3])
		ok += _ok(fails, Campaign.final_ending("train", train) == "final_many", "финал: четыре потери ещё «многие»")
		_dead([0, 1, 2, 3, 4])
		ok += _ok(fails, Campaign.final_ending("train", train) == "final_few", "финал: пять потерь должны дать «немногих»")
		train.train_add(human, upyr)
		ok += _ok(fails, Campaign.final_ending("train", train) == "final_upyr", "финал: упырь в списке должен ехать в вагоне")
		_dead([])
		ok += _ok(fails, Campaign.final_ending("train", train) == "final_upyr", "финал: упырь в списке важнее числа потерь")
	_dead([])
	ok += _ok(fails, Campaign.final_ending("train", null) == "final_many", "финал без партии: никто не потерян, «многие»")
	for ending: String in Campaign.FINAL_ENDINGS:
		ok += _ok(fails, Progress.ENDINGS.has(ending) and L.has("ending." + ending), "финал %s: нет в списке концовок или без названия" % ending)
	# эпилог: по строке на каждого жителя, погибшие отмечены
	for ending: String in Campaign.FINAL_ENDINGS:
		_dead([3, 4])
		var epi := Campaign.epilogue_lines(train, ending)
		ok += _ok(fails, epi.size() == L.names().size(), "эпилог %s: %d строк на %d жителей" % [ending, epi.size(), L.names().size()])
		var empty := 0
		for line: String in epi:
			empty += 1 if line.strip_edges().is_empty() else 0
		ok += _ok(fails, empty == 0, "эпилог %s: пустых строк %d" % [ending, empty])
		ok += _ok(fails, epi[3] == L.t("fin.epi.dead", {"who": Revelations._person(3, train)}), "эпилог %s: погибший Костя не отмечен" % ending)
	_dead([])
	return ok


## Запись концовок: все 18 из Progress.ENDINGS записываются, получают название и показываются в книге.
static func recording(fails: PackedStringArray) -> int:
	var ok := 0
	var path := ProjectSettings.globalize_path(Save.SETTINGS_PATH)
	var backup := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var kept := {"xp": Save.xp, "book": Save.book.duplicate(), "endings": Save.endings.duplicate(), "ach": Save.achievements.duplicate()}
	Save.endings = PackedStringArray()
	# обе исходные концовки партии и концовка акта у последней главы акта
	var chapters := {"a1c3": "act1", "a2c3": "act2", "a3c3": "act3", "a4c3": "act4"}
	for cid: String in chapters:
		_dead([])
		_journal([])
		var run := SimChapters.play_run(cid, "careful", 4242)
		var res := {"id": cid, "passed": true, "stars": 2}
		Progress.record(run.m, res)
		var want := "%s_all" % chapters[cid]
		ok += _ok(fails, Save.endings.has(want), "глава %s пройдена: концовка %s не записана (%s)" % [cid, want, ",".join(Save.endings)])
		var not_last := Progress.record(run.m, {"id": "a1c1", "passed": true, "stars": 1})
		ok += _ok(fails, not_last.has("lines"), "Progress.record не вернул строки опыта")
	ok += _ok(fails, Save.endings.has("people") or Save.endings.has("upyri"), "исход партии (люди или упыри) не записан")
	for ending: String in Campaign.FINAL_ENDINGS:
		Save.record_progress(0, [], PackedStringArray([ending]), PackedStringArray())
	var missing := PackedStringArray()
	for ending: String in Progress.ENDINGS:
		Save.record_progress(0, [], PackedStringArray([ending]), PackedStringArray())
		if not Save.endings.has(ending):
			missing.append(ending)
		ok += _ok(fails, L.has("ending." + ending), "нет названия концовки ending.%s" % ending)
	ok += _ok(fails, missing.is_empty(), "не записаны концовки: %s" % ", ".join(missing))
	ok += _ok(fails, Save.endings.size() == Progress.ENDINGS.size(), "записано %d концовок из %d" % [Save.endings.size(), Progress.ENDINGS.size()])
	var seen := {}
	for ending: String in Save.endings:
		seen[ending] = true
	ok += _ok(fails, seen.size() == Save.endings.size(), "концовки записаны повторно")
	# вернуть как было
	Save.xp = int(kept.xp)
	Save.book = kept.book
	Save.endings = kept.endings
	Save.achievements = kept.ach
	if not backup.is_empty():
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(backup)
			f.close()
	return ok


# =============================================================
# Память кампании: журнал в реплики и состав
# =============================================================
static func memory(fails: PackedStringArray) -> int:
	var ok := 0
	_dead([])
	# заступники и обиженные: последняя запись решает
	_journal([_mem("react_accuse", 3, "a1c2"), _mem("react_defend", 4, "a1c2"), _mem("react_revenge", 5, "a1c2")])
	ok += _ok(fails, str(Campaign.active_grudges()) == "[3, 5]", "обиды: %s" % str(Campaign.active_grudges()))
	ok += _ok(fails, str(Campaign.defenders()) == "[4]", "заступники: %s" % str(Campaign.defenders()))
	_journal([_mem("react_accuse", 3, "a1c2"), _mem("admitted", 3, "a1c3"), _mem("react_defend", 4, "a1c2"), _mem("broken", 4, "a1c3")])
	ok += _ok(fails, Campaign.active_grudges().is_empty() and Campaign.defenders().is_empty(), "обида прощена, заступничество потеряно: %s %s" % [str(Campaign.active_grudges()), str(Campaign.defenders())])
	# память о жителе: новые сверху, не больше limit, неизвестные записи пропускаются
	_journal([_mem("refused_died", 6, "a1c1"), _mem("admitted", 6, "a1c2"), _mem("no_such_kind", 6, "a1c3"), _mem("kept", 6, "a2c1")])
	var lines := Campaign.memory_lines(6, 2)
	ok += _ok(fails, lines.size() == 2, "память о Захаре: %d строк, ожидали 2" % lines.size())
	ok += _ok(fails, Campaign.memory_lines(11, 3).is_empty() and Campaign.memory_lines(-1).is_empty() and Campaign.memory_lines(99).is_empty(), "память о чужом номере не пуста")
	# акт I в первой главе акта II: погибшие молчат, из записей берётся важнейшая
	_dead([6])
	var memo := Campaign.act_one_memory(3)
	var who: Array[int] = []
	for rec: Dictionary in memo:
		who.append(int(rec.who))
	ok += _ok(fails, not who.has(6), "акт I помнит погибшего Захара")
	_dead([])
	_journal([_mem("refused", 6, "a1c2"), _mem("admitted", 6, "a1c3"), _mem("kept", 7, "a2c1")])
	var memo2 := Campaign.act_one_memory(3)
	ok += _ok(fails, memo2.size() == 1 and int(memo2[0].who) == 6, "акт I: запись из акта II попала в память акта I или важнейшая выбрана неверно")
	# находки тайн
	_journal([_mem("clue_miller", -1, "a2c1"), _mem("clue_miller", -1, "a2c2")])
	ok += _ok(fails, Campaign.miller_clues() == 2 and Campaign.miller_clues() >= Campaign.MILLER_KNOWN, "находки мельника: %d" % Campaign.miller_clues())
	var known := Scenes.miller_secret(_match("a2c3"))
	ok += _ok(fails, _frames_text(known).contains(L.t("sc.miller.1_known")), "тайна мельника: при двух находках игрок спрашивает сам")
	_journal([])
	var unknown := Scenes.miller_secret(_match("a2c3"))
	ok += _ok(fails, _frames_text(unknown).contains(L.t("sc.miller.1")) and not _frames_text(unknown).contains(L.t("sc.miller.1_known")), "тайна мельника: без находок исповедь слушает")
	# книга Анфисы договаривает то, что игрок не разгадал
	_journal([])
	ok += _ok(fails, int(Scenes.crossed_book(_match("a3c2")).told) == 3, "книга Анфисы: без находок она договаривает три загадки")
	_journal([_mem("clue_boat", -1), _mem("clue_boat", -1, "a1c3"), _mem("clue_boat", -1, "a1c3"), _mem("miller_tell", -1, "a2c3"), _mem("board_silent", -1, "a1c3")])
	ok += _ok(fails, int(Scenes.crossed_book(_match("a3c2")).told) == 0, "книга Анфисы: при всех разгаданных загадках она ничего не договаривает")
	_journal([])
	return ok


## Все сцены веток собираются и сходятся по звуку при любом журнале.
static func scenes(fails: PackedStringArray) -> int:
	var ok := 0
	var journals := [[], [_mem("admitted", 0), _mem("kept", 1)], [_mem("refused_died", 0), _mem("broken", 2), _mem("exiled_by_you", 3)]]
	for j: Array in journals:
		_journal(j)
		for dead_list: Array in [[], [0, 2], [1, 8, 9]]:
			_dead(dead_list)
			var m1 := _match("a1c3")
			var m2 := _match("a2c3")
			var m3 := _match("a3c3")
			var m4 := _match("a4c3")
			var list: Array[Dictionary] = [Scenes.board(m1), Scenes.grave(_match("a2c2")), Scenes.miller_secret(m2), Scenes.crossed_book(_match("a3c2")),
				Scenes.crypt(m3), Scenes.trial(m3), Scenes.final_door()]
			for v: Villager in m4.alive_bots():
				list.append(Scenes.betrayal(m4, v))
				break
			for sc: Dictionary in list:
				ok += _ok(fails, not (sc.get("frames", []) as Array).is_empty(), "сцена %s без кадров (журнал %d, погибших %d)" % [sc.get("id", "?"), j.size(), dead_list.size()])
				ok += _ok(fails, Scenes.sound_problems(sc, true).is_empty(), "сцена %s: звуки не сходятся" % sc.get("id", "?"))
				ok += _ok(fails, not _frames_text(sc).contains("sc.") and not _frames_text(sc).contains("{"), "сцена %s: в тексте остался ключ или метка" % sc.get("id", "?"))
	_dead([])
	_journal([])
	return ok


## Запуск: --story
static func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	var snap := SimChapters.fresh_campaign()
	var fails := PackedStringArray()
	var ok := 0
	ok += trial(fails)
	ok += replacements(fails)
	ok += endings(fails)
	ok += memory(fails)
	ok += scenes(fails)
	ok += recording(fails)
	SimChapters.restore_campaign(snap)
	for f: String in fails:
		print("  ✗ " + f)
	print("проверок пройдено %d, ошибок %d, время %.1f с" % [ok, fails.size(), float(Time.get_ticks_msec() - t0) / 1000.0])
	print("ИТОГ: %s" % ("OK" if fails.is_empty() else "ВЕТКИ СЮЖЕТА: %d ОШИБОК" % fails.size()))
	tree.quit(0 if fails.is_empty() else 1)
