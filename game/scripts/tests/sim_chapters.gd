class_name SimChapters
extends RefCounted
## Баланс глав кампании (TASK-091). Каждая из 12 глав играется без экрана тремя стилями игрока.
## Глава собирается как в Game.start: состав, гости, карта, особые условия, событие, директор.
## Игрок ходит по стилю, остальные решают боты Director. Роль игрока, его дневные работы и
## дилеммы у двери не моделируются: это нижняя оценка для внимательного и верхняя для небрежного.

const STYLES: PackedStringArray = ["careful", "kind", "random"]
const STYLE_RU := {"careful": "осторожный", "kind": "добрый", "random": "случайный"}
const SEED_BASE := 70000
const GUARD := 400
const CORRIDOR_MIN := 0.35          ## доля выживших жителей, нижняя граница
const CORRIDOR_MAX := 0.65
const FIRST_CHAPTER_MIN := 0.55     ## глава 1 щадящая: выживших не меньше

static var _villages: Dictionary = {}


## Одна партия в ходе игры. Хранит всё, что нужно стилям игрока между фазами.
class Run:
	var id: String
	var ch: Dictionary
	var style: String
	var opt: Dictionary
	var m: Match
	var d: Director
	var rng := RandomNumberGenerator.new()
	var done: Dictionary = {}
	var ann: Dictionary = {}              ## кто днём сказал, в какой дом пойдёт (слышат все)
	var suspects: Array[Villager] = []    ## звонил колокол: кто говорил, что пойдёт в этот дом
	var trial_lost := false
	var humans0 := 0
	var ended := false
	var traces := 0
	var causes: Dictionary = {}           ## причина гибели -> сколько человек за главу


## Ступень сложности, на которой считается коридор. Основа партии главы (смерть на улице, время) берётся из ступени игрока,
## поэтому от профиля на диске результат зависеть не должен: «обычная» это эталон, «лёгкая» и «сложная» идут справкой.
const REFERENCE_DIFFICULTY := "normal"

## Партии считаются на чистой кампании: ни погибших, ни памяти, ни обид, ступень сложности задана явно.
## Файл сохранения не трогаем.
static func fresh_campaign(diff: String = REFERENCE_DIFFICULTY) -> Dictionary:
	var snap := {"config": Save.config, "difficulty": Save.difficulty, "stars": Save.campaign_stars.duplicate(), "dead": Save.campaign_dead.duplicate(), "seed": Save.campaign_seed,
		"memory": Save.campaign_memory.duplicate(true), "bonds": Save.campaign_bonds.duplicate(true),
		"dead_guests": Save.campaign_dead_guests.duplicate(), "name": Save.player_name}
	Save.campaign_stars.clear()
	Save.campaign_dead.clear()
	Save.campaign_memory.clear()
	Save.campaign_bonds.clear()
	Save.campaign_dead_guests.clear()
	Save.campaign_seed = 1
	Save.player_name = ""
	Save.config = Difficulty.preset(diff)
	Save.difficulty = diff
	return snap


static func restore_campaign(snap: Dictionary) -> void:
	Save.config = snap.config
	Save.difficulty = String(snap.difficulty)
	Save.campaign_stars = snap.stars
	Save.campaign_dead = snap.dead
	Save.campaign_seed = int(snap.seed)
	Save.campaign_memory = snap.memory
	Save.campaign_bonds = snap.bonds
	Save.campaign_dead_guests = snap.dead_guests
	Save.player_name = String(snap.name)


static func village(id: String) -> VillageDef:
	if not _villages.has(id):
		_villages[id] = Campaign.village_for_chapter(id)
	return _villages[id]


static func play(id: String, style: String, seed_n: int, opt: Dictionary = {}) -> Dictionary:
	var r := play_run(id, style, seed_n, opt)
	return _result(r, r.ended)


## Одна глава до конца. opt: bell (bool), grave (bool), candle (-1..1), inspect (bool), traces (bool),
## add ({"nights": -1, "capacity": 1 ...}: сдвиг настроек главы для подбора баланса).
static func play_run(id: String, style: String, seed_n: int, opt: Dictionary = {}) -> Run:
	var r := Run.new()
	r.id = id
	r.ch = Campaign.chapter(id)
	r.style = style
	r.opt = opt
	r.rng.seed = seed_n + 17
	var m := Match.new()
	m.cast = Campaign.cast(id, int(opt.get("add", {}).get("players", 0)))
	m.guests = Campaign.guests(id)
	m.guest_roles_fixed = String(r.ch.get("guest_roles", "story")) == "story"
	if id in ["a1c2", "a1c3"]:
		m.plant_chapter = id
	Campaign.setup_match(m, r.ch)
	m.village = village(id)
	var cfg := Campaign.config(id)
	for key: String in opt.get("add", {}):         # разведка: сдвиг числа ночей, упырей, убежищ, мест
		cfg.set(key, int(cfg.get(key)) + int(opt.add[key]))
	m.start(cfg, seed_n)
	match String(r.ch.get("event", "")):
		"fog": m.force_event = Match.Event.FOG
		"rain": m.force_event = Match.Event.RAIN
		"moon": m.force_event = Match.Event.MOON
		"quiet": m.force_event = Match.Event.QUIET
	if opt.has("bell"):
		m.bell_on = bool(opt.bell)
	var d := Director.new()
	d.rng.seed = seed_n
	d.tune = float(opt.get("tune", -float(r.ch.get("assist", 0.0))))   # -1: боты поддаются, +1: собраннее обычного
	d.attach(m)
	d.first_chapter = id == "a1c1"
	d.chapter_id = id
	r.m = m
	r.d = d
	for v: Villager in m.villagers:
		if not v.is_upyr:
			r.humans0 += 1
	if bool(r.ch.get("cold_open", false)):
		m.cold_open(d.night_choices())
	else:
		m.begin_day()
	var guard := 0
	while m.phase != Match.Phase.OVER and guard < GUARD:
		guard += 1
		match m.phase:
			Match.Phase.DAY: _day(r)
			Match.Phase.VOTE: _vote(r)
			Match.Phase.NIGHT: _night(r)
			Match.Phase.DOOR: _door(r)
			Match.Phase.MORNING: _morning(r)
			_: break
	r.ended = guard < GUARD
	return r


static func _result(r: Run, ended: bool) -> Dictionary:
	var m := r.m
	var goals := Campaign.goals(m, r.ch)
	var stars := 0
	for g: Dictionary in goals:
		stars += 1 if bool(g.done) else 0
	var alive_h := 0
	for v: Villager in m.villagers:
		if not v.is_upyr and v.alive:
			alive_h += 1
	var wrong := 0
	var wrong_guest := 0
	for rec: Dictionary in m.vote_log:
		var ex: Villager = rec.get("exiled")
		if ex != null and not ex.is_upyr:
			wrong += 1
			wrong_guest += 1 if not ex.guest_id.is_empty() else 0
	return {
		"ended": ended,
		"passed": bool(goals[0].done),
		"stars": stars,
		"people_win": m.winner == Match.Team.PEOPLE,
		"player_alive": m.player().alive,
		"share": float(alive_h) / maxf(1.0, float(r.humans0)),
		"wrong": wrong,
		"wrong_guest": wrong_guest,
		"nights": m.day,
		"trial_lost": r.trial_lost,
		"upyr_left": m.upyri_alive(),
		"traces": r.traces,
		"causes": r.causes,
	}


# =============================================================
# Фазы
# =============================================================
static func _day(r: Run) -> void:
	var m := r.m
	var d := r.d
	d.plan_day()
	d.opening_lines()
	d.run_jobs_instant(d.plan_jobs(m.config.day_seconds))
	if bool(r.opt.get("traces", false)):
		r.traces = maxi(r.traces, m.world.ground_traces(0).size())
	r.ann.clear()
	for v: Villager in m.alive_bots():
		r.ann[v.id] = v.announced_house
	var caller := d.meeting_caller()
	if caller != null:
		m.call_meeting(caller)
	else:
		m.end_day()


static func _vote(r: Run) -> void:
	var m := r.m
	var bv := r.d.votes()
	var votes := bv.duplicate()
	var tally: Dictionary[int, int] = {}
	for voter: int in bv:
		tally[bv[voter]] = tally.get(bv[voter], 0) + m.vote_weight(voter)
	if m.player().alive:
		var t := _player_vote(r)
		if t != null:
			votes[0] = t.id
			tally[t.id] = tally.get(t.id, 0) + m.vote_weight(0)
	m.apply_vote(tally, votes)
	m.after_vote()


static func _night(r: Run) -> void:
	var m := r.m
	var ch := r.d.night_choices()
	if m.player().alive:
		ch[0] = _player_house(r)
	m.seat_night(ch)


static func _door(r: Run) -> void:
	var m := r.m
	for s: Match.Seat in m.seats:
		if s.host.is_player:
			m.admit(s, _player_admit(r, s))
		else:
			m.admit(s, r.d.host_decide(s, "beg"))
	m.tunnel_pass(false)
	r.d.after_door(m.seats)
	var report := m.resolve_night()
	for e: NightReport.Entry in report.deaths():
		if e.who != null and not e.who.is_upyr:
			var cause := String(NightReport.Kind.keys()[e.kind]).to_lower()
			r.causes[cause] = int(r.causes.get(cause, 0)) + 1
	r.d.read_report(report)
	r.suspects.clear()
	if m.bell_on:
		for bell: int in m.last_bells:
			for v: Villager in m.alive_bots():
				if int(r.ann.get(v.id, -1)) == bell - 1 and not r.suspects.has(v):
					r.suspects.append(v)


## Сцены утра, которые меняют ход главы (как MorningScreen): могила, половодье, тайна мельника,
## суд в крипте, союзник на перроне. Пока игрок жив.
static func _morning(r: Run) -> void:
	var m := r.m
	var d := r.d
	if m.player().alive:
		match r.id:
			"a2c2":
				if not r.done.has("grave") and bool(r.opt.get("grave", true)):
					r.done["grave"] = true
					d.grave_found(int(Scenes.grave(m).get("hunter", -1)))
			"a2c3":
				if not r.done.has("flood") and m.day + 1 == m.flood_day:
					r.done["flood"] = true
					var low := m.low_houses()
					if not low.is_empty():
						m.flood_choice = low[r.rng.randi_range(0, low.size() - 1)]
				elif not r.done.has("miller") and m.day >= 2:
					r.done["miller"] = true
					d.miller_answer(_pick(r, "keep", "tell"))
			"a3c3":
				if r.done.has("crypt") and not r.done.has("trial") and m.day >= 2:
					r.done["trial"] = true
					var acquit := bool(Campaign.trial(m).acquit)
					r.trial_lost = not acquit
					d.trial_result(acquit)
				r.done["crypt"] = true
			"a4c3":
				if not r.done.has("betray") and m.day >= 2:
					var ally := m.get_villager(d.ally_id)
					if ally != null and ally.alive:
						r.done["betray"] = true
						d.betrayal_answer(_pick(r, "expose", "cover"))
	m.end_morning()


## Осторожный и добрый отвечают по характеру, случайный бросает монету.
static func _pick(r: Run, careful: String, kind: String) -> String:
	match r.style:
		"careful": return careful
		"kind": return kind
	return careful if r.rng.randf() < 0.5 else kind


# =============================================================
# Ходы игрока
# =============================================================
static func _by_susp_desc(r: Run, list: Array[Villager]) -> Array[Villager]:
	var out: Array[Villager] = list.duplicate()
	out.sort_custom(func(a: Villager, b: Villager) -> bool: return r.d.susp(a.id) > r.d.susp(b.id))
	return out


static func _player_vote(r: Run) -> Villager:
	var m := r.m
	var pool: Array[Villager] = m.alive_bots()
	if pool.is_empty():
		return null
	match r.style:
		"careful":
			var src: Array[Villager] = pool
			if m.bell_on and not r.suspects.is_empty():
				src = []
				for v: Villager in r.suspects:
					if v.alive:
						src.append(v)
				if src.is_empty():
					src = pool
			var top := _by_susp_desc(r, src)[0]
			return top if r.d.susp(top.id) >= 0.3 or not r.suspects.is_empty() else null
		"kind":
			return null
	return pool[r.rng.randi_range(0, pool.size() - 1)]


static func _player_house(r: Run) -> int:
	var m := r.m
	var n := m.houses.size()
	var counts: Array[int] = []
	var mean: Array[float] = []
	for h in range(n):
		var c := 0
		var s := 0.0
		for v: Villager in m.alive_bots():
			if int(r.ann.get(v.id, -1)) == h:
				c += 1
				s += maxf(0.0, r.d.susp(v.id))
		counts.append(c)
		mean.append(s / maxf(1.0, float(c)))
	var best: Array[int] = []
	var best_score := INF
	for h in range(n):
		if m.dry_house(h) != h:
			continue
		var score := 0.0
		match r.style:
			"careful":
				score = mean[h]                                   # к тем, кому верят, и не в одиночку: в доме побольше людей, ближе к тем, кого упырь выбирает случайно
				score -= 0.35 * minf(float(counts[h]), float(m.config.capacity - 1))
				if counts[h] == 0:
					score += 2.0
				if counts[h] >= m.config.capacity:
					score += float(counts[h] - m.config.capacity + 1)
			"kind":
				score = -float(counts[h])
			_:
				score = 0.0
		if score < best_score - 0.0001:
			best_score = score
			best = [h]
		elif absf(score - best_score) <= 0.0001:
			best.append(h)
	if best.is_empty():
		return m.dry_house(0)
	return best[r.rng.randi_range(0, best.size() - 1)]


static func _player_admit(r: Run, s: Match.Seat) -> Array[int]:
	var m := r.m
	var ids: Array[int] = []
	var ks := s.knockers()
	var cap := m.config.capacity - 1
	if ks.is_empty() or cap <= 0:
		return ids
	match r.style:
		"random":
			if not s.queue.is_empty():
				ids.append(s.queue[r.rng.randi_range(0, s.queue.size() - 1)].id)
			return ids
		"kind":
			for v: Villager in ks:
				if ids.size() < cap:
					ids.append(v.id)
			return ids
	# осторожный: свеча, два осмотра самых подозрительных, голос погибшего или чужого дома не пускает
	if r.opt.has("candle"):
		m.set_candle(int(r.opt.candle))
	var tells: Dictionary = {}
	if bool(r.opt.get("inspect", true)):
		var used := 0
		for v: Villager in _by_susp_desc(r, ks):
			if used >= 2:
				break
			var tell := m.inspect_visitor(s, v.id)
			if tell != &"":
				used += 1
				if tell != &"ordinary":
					tells[v.id] = true
	var ok: Array[Villager] = []
	for v: Villager in ks:
		if tells.has(v.id):
			continue
		if v == s.mimic and (not v.alive or v.announced_house != s.house):
			continue
		ok.append(v)
	ok = _by_susp_desc(r, ok)
	ok.reverse()
	if m.door_flicker(s) and ok.size() > 1:
		ok.pop_back()
	for v: Villager in ok:
		if ids.size() < cap:
			ids.append(v.id)
	return ids


# =============================================================
# Таблица
# =============================================================
## rows: по строке на главу и стиль. ids пустой — все главы по порядку.
static func table(runs: int, ids: PackedStringArray = PackedStringArray(), opt: Dictionary = {}, styles: PackedStringArray = STYLES) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: PackedStringArray = ids if not ids.is_empty() else Campaign.ORDER
	for id: String in list:
		for style: String in styles:
			out.append(cell(id, style, runs, opt))
	return out


static func cell(id: String, style: String, runs: int, opt: Dictionary = {}) -> Dictionary:
	var causes: Dictionary = {}
	var row := {"id": id, "style": style, "runs": runs, "ended": 0, "passed": 0, "people_win": 0, "player_alive": 0,
		"share": 0.0, "stars": 0.0, "wrong": 0.0, "wrong_guest": 0.0, "nights": 0.0, "trial_lost": 0, "upyr_left": 0.0}
	for g in range(runs):
		var x := play(id, style, SEED_BASE + g, opt)
		row.ended += 1 if bool(x.ended) else 0
		row.passed += 1 if bool(x.passed) else 0
		row.people_win += 1 if bool(x.people_win) else 0
		row.player_alive += 1 if bool(x.player_alive) else 0
		row.trial_lost += 1 if bool(x.trial_lost) else 0
		row.share += float(x.share)
		row.stars += float(x.stars)
		row.wrong += float(x.wrong)
		row.wrong_guest += float(x.wrong_guest)
		row.nights += float(x.nights)
		row.upyr_left += float(x.upyr_left)
		for k: String in x.causes:
			causes[k] = int(causes.get(k, 0)) + int(x.causes[k])
	var n := float(maxi(1, runs))
	for k: String in causes:
		causes[k] = float(causes[k]) / n
	row["causes"] = causes
	for k: String in ["passed", "people_win", "player_alive", "trial_lost"]:
		row[k + "_p"] = float(row[k]) / n
	for k: String in ["share", "stars", "wrong", "wrong_guest", "nights", "upyr_left"]:
		row[k] = float(row[k]) / n
	return row


## Средняя доля выживших по трём стилям для главы.
static func chapter_share(rows: Array[Dictionary], id: String) -> float:
	var s := 0.0
	var k := 0
	for r: Dictionary in rows:
		if String(r.id) == id:
			s += float(r.share)
			k += 1
	return s / maxf(1.0, float(k))


static func report_md(rows: Array[Dictionary], runs: int) -> String:
	var lines := PackedStringArray()
	lines.append("| Глава | Стиль | Выжившие жители | Игрок жив | Глава пройдена | Победа людей | Звёзды | Ошибочные изгнания | Ночей |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for r: Dictionary in rows:
		lines.append("| %s | %s | %.0f%% | %.0f%% | %.0f%% | %.0f%% | %.2f | %.2f | %.2f |" % [
			r.id, STYLE_RU.get(String(r.style), String(r.style)), 100.0 * float(r.share), 100.0 * float(r.player_alive_p),
			100.0 * float(r.passed_p), 100.0 * float(r.people_win_p), float(r.stars), float(r.wrong), float(r.nights)])
	lines.append("")
	lines.append("Партий в каждой ячейке: %d." % runs)
	lines.append("")
	lines.append("Гибель жителей за главу (среднее на партию): в доме от упыря, один дома, на улице, от треснувшего оберега, от Подражателя, изгнан по ошибке.")
	lines.append("")
	lines.append("| Глава | Стиль | В доме | Один | Улица | Оберег | Подражатель | Изгнан |")
	lines.append("|---|---|---|---|---|---|---|---|")
	for r: Dictionary in rows:
		var c: Dictionary = r.causes
		lines.append("| %s | %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |" % [
			r.id, STYLE_RU.get(String(r.style), String(r.style)), float(c.get("killed_inside", 0.0)), float(c.get("killed_alone", 0.0)),
			float(c.get("killed_street", 0.0)), float(c.get("killed_creature", 0.0)), float(c.get("killed_mimic", 0.0)), float(r.wrong)])
	return "\n".join(lines)


## Подбор: перебор сдвигов состава главы. Печатает среднее по трём стилям.
static func _grid(runs: int, ids: PackedStringArray) -> void:
	for id: String in (ids if not ids.is_empty() else Campaign.ORDER):
		for dp: int in [0, 1, 2]:
			for dn: int in [0, -1]:
				for dc: int in [0, 1]:
					for dm: int in [0, -1]:
						var add := {"players": dp, "nights": dn, "capacity": dc, "monsters": dm}
						var rows := table(runs, PackedStringArray([id]), {"add": add})
						var s := 0.0
						var pa := 0.0
						var pw := 0.0
						var pl := 0.0
						for r: Dictionary in rows:
							s += float(r.share)
							pa += float(r.player_alive_p)
							pw += float(r.passed_p)
							pl += float(r.people_win_p)
						var k := float(rows.size())
						print("GRID %s players%+d nights%+d cap%+d mon%+d | выжившие %.0f%% игрок %.0f%% пройдена %.0f%% победа %.0f%%" % [
							id, dp, dn, dc, dm, 100.0 * s / k, 100.0 * pa / k, 100.0 * pw / k, 100.0 * pl / k])


## Проверка в CI и запуск из консоли: --simchapters [--runs=N] [--only=a1c1,a1c2] [--out=путь]
static func cli() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var runs := 500
	var only := PackedStringArray()
	var out_path := ""
	var opt := {}
	var diff := REFERENCE_DIFFICULTY
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--add="):
			var add := {}
			for pair: String in a.substr(6).split(","):
				add[pair.get_slice(":", 0)] = int(pair.get_slice(":", 1))
			opt["add"] = add
			continue
		if a.begins_with("--tune="):
			opt["tune"] = float(a.substr(7))
			continue
		if a.begins_with("--diff="):
			diff = a.substr(7)
			continue
		if a.begins_with("--runs="):
			runs = maxi(1, int(a.substr(7)))
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
		elif a.begins_with("--out="):
			out_path = a.substr(6)
	var t0 := Time.get_ticks_msec()
	var snap := fresh_campaign(diff)
	if OS.get_cmdline_user_args().has("--grid"):
		_grid(runs, only)
		restore_campaign(snap)
		tree.quit(0)
		return
	if OS.get_cmdline_user_args().has("--campaign"):
		for r: Dictionary in campaign_table(runs, opt):
			print("кампания %s: погибших насовсем %.1f (после актов: %.1f / %.1f / %.1f / %.1f), финал «многие» %.0f%%, попыток на главу %.2f, не пройдено %.2f, жителей в главе %.1f" % [
				STYLE_RU[r.style], r.dead, r.after[0], r.after[1], r.after[2], r.after[3], 100.0 * float(r.many), float(r.attempts) / 12.0, r.failed, r.cast])
		restore_campaign(snap)
		tree.quit(0)
		return
	if OS.get_cmdline_user_args().has("--checks"):
		for c: Dictionary in checks(runs):
			print("%s %s: %s" % ["OK " if bool(c.ok) else "ЛОЖЬ", c.name, c.note])
		restore_campaign(snap)
		tree.quit(0)
		return
	var rows := table(runs, only, opt)
	var md := report_md(rows, runs)
	print(md)
	print("время: %.1f с" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	if not out_path.is_empty():
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(md + "\n")
			f.close()
	var ok := true
	for r: Dictionary in rows:
		if int(r.ended) != runs:
			ok = false
			print("  ✗ %s %s: партий без конца %d" % [r.id, r.style, runs - int(r.ended)])
	print("ИТОГ: %s" % ("OK" if ok else "ЕСТЬ ПАРТИИ, КОТОРЫЕ НЕ ЗАКАНЧИВАЮТСЯ"))
	restore_campaign(snap)
	tree.quit(0 if ok else 1)


# =============================================================
# Вся кампания подряд
# =============================================================
## Двенадцать глав подряд одним стилем. Погибшие насовсем в следующие главы не приходят, как в Campaign.finish,
## непройденную главу играют заново (не больше MAX_ATTEMPTS попыток). Файл сохранения не трогаем.
const MAX_ATTEMPTS := 3


static func campaign(style: String, seed_n: int, opt: Dictionary = {}) -> Dictionary:
	Save.campaign_stars.clear()
	Save.campaign_dead.clear()
	Save.campaign_memory.clear()
	Save.campaign_bonds.clear()
	Save.campaign_dead_guests.clear()
	Save.campaign_seed = 1 + seed_n
	var dead_after_act := [0, 0, 0, 0]
	var attempts := 0
	var failed := 0
	var cast_sum := 0
	var humans_sum := 0
	for id: String in Campaign.ORDER:
		var ch := Campaign.chapter(id)
		var passed := false
		for attempt in range(MAX_ATTEMPTS):
			attempts += 1
			var r := play_run(id, style, SEED_BASE + seed_n * 101 + attempt * 7 + Campaign.ORDER.find(id), opt)
			passed = bool(Campaign.goals(r.m, ch)[0].done)
			if attempt == 0:
				cast_sum += r.m.villagers.size()
				humans_sum += r.humans0
			if passed or attempt == MAX_ATTEMPTS - 1:
				if not passed:
					failed += 1
				_commit(r, id, passed)
				break
		dead_after_act[int(ch.act) - 1] = Save.campaign_dead.size()
	return {"dead": Save.campaign_dead.size(), "dead_after_act": dead_after_act, "attempts": attempts, "failed": failed,
		"cast": float(cast_sum) / float(Campaign.ORDER.size()), "humans": float(humans_sum) / float(Campaign.ORDER.size()),
		"ending": "final_many" if Save.campaign_dead.size() <= 4 else "final_few"}


## Итог главы в кампанию, как Campaign.finish и Save.record_chapter, но без записи на диск.
static func _commit(r: Run, id: String, passed: bool) -> void:
	if not passed:
		return
	var m := r.m
	for v: Villager in m.villagers:
		if v.is_player or v.alive or v.departed:
			continue
		if not v.guest_id.is_empty():
			if not Save.campaign_dead_guests.has(v.guest_id):
				Save.campaign_dead_guests.append(v.guest_id)
		elif v.story_id >= 0 and not Save.campaign_dead.has(v.story_id):
			Save.campaign_dead.append(v.story_id)
	Save.campaign_stars[id] = 1


## Таблица кампаний: по стилям, runs кампаний на стиль.
static func campaign_table(runs: int, opt: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for style: String in STYLES:
		var dead := 0.0
		var many := 0
		var attempts := 0.0
		var failed := 0.0
		var cast := 0.0
		var after := [0.0, 0.0, 0.0, 0.0]
		for g in range(runs):
			var x := campaign(style, g, opt)
			dead += float(x.dead)
			many += 1 if String(x.ending) == "final_many" else 0
			attempts += float(x.attempts)
			failed += float(x.failed)
			cast += float(x.cast)
			for a in range(4):
				after[a] += float(x.dead_after_act[a])
		var n := float(maxi(1, runs))
		out.append({"style": style, "dead": dead / n, "many": float(many) / n, "attempts": attempts / n, "failed": failed / n,
			"cast": cast / n, "after": [after[0] / n, after[1] / n, after[2] / n, after[3] / n]})
	return out


# =============================================================
# Известные перекосы (TASK-091)
# =============================================================
## Колокол в a3c2, могила в a2c2, свеча и осмотр (TASK-073), суд с пустым журналом, следы (TASK-065, 090).
## Каждая проверка: {"name", "ok", "note"}. runs — партий в ячейке.
static func checks(runs: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# колокол: звон показывает дом с упырём, но не должен решать главу сам
	var bell_on := cell("a3c2", "careful", runs)
	var bell_off := cell("a3c2", "careful", runs, {"bell": false})
	var d_bell: float = float(bell_on.people_win_p) - float(bell_off.people_win_p)
	out.append({"name": "колокол a3c2", "ok": d_bell <= BELL_MAX_GAIN and float(bell_on.people_win_p) < 0.97,
		"note": "победа людей с колоколом %.0f%%, без колокола %.0f%%, прибавка %+.0f п.п. (допуск до %.0f)" % [
			100.0 * float(bell_on.people_win_p), 100.0 * float(bell_off.people_win_p), 100.0 * d_bell, 100.0 * BELL_MAX_GAIN]})
	# могила: деревня винит гостей, но глава не должна превращаться в охоту на гостей
	var grave_on := cell("a2c2", "careful", runs)
	var grave_off := cell("a2c2", "careful", runs, {"grave": false})
	var d_guest: float = float(grave_on.wrong_guest) - float(grave_off.wrong_guest)
	var d_win: float = float(grave_on.people_win_p) - float(grave_off.people_win_p)
	out.append({"name": "нож в могиле a2c2", "ok": d_guest <= GRAVE_MAX_GUEST_EXILES and absf(d_win) <= GRAVE_MAX_SHIFT,
		"note": "ошибочно изгнанных гостей на партию: с могилой %.2f, без %.2f (%+.2f); победа людей %+.0f п.п." % [
			float(grave_on.wrong_guest), float(grave_off.wrong_guest), d_guest, 100.0 * d_win]})
	# свеча и осмотр: лучшая тактика не должна давать больше допуска против худшей
	for id: String in ["a1c3", "a3c3", "a4c3"]:
		var best := -1.0
		var worst := 2.0
		var detail := PackedStringArray()
		for variant: Array in [["без осмотра", {"inspect": false}], ["тусклая", {"candle": -1}], ["обычная", {"candle": 0}], ["яркая", {"candle": 1}]]:
			var c := cell(id, "careful", runs, variant[1])
			var v: float = float(c.share)
			best = maxf(best, v)
			worst = minf(worst, v)
			detail.append("%s %.0f%%" % [variant[0], 100.0 * v])
		out.append({"name": "свеча %s" % id, "ok": best - worst <= CANDLE_MAX_SPREAD,
			"note": "выжившие: %s; разброс %.0f п.п. (допуск до %.0f)" % [", ".join(detail), 100.0 * (best - worst), 100.0 * CANDLE_MAX_SPREAD]})
	# суд с пустым журналом: ни обвинения, ни защиты. Оправдан, сцена собирается
	var m := Match.new()
	m.chapter_id = "a3c3"
	m.village = village("a3c3")
	m.start(Campaign.config("a3c3"), SEED_BASE)
	var t := Campaign.trial(m)
	var fresh: bool = Save.campaign_memory.is_empty()
	var sc := Scenes.trial(m)
	out.append({"name": "суд с пустым журналом", "ok": fresh and bool(t.acquit) and (t.def as Array).is_empty() and (t.acc as Array).is_empty() and not (sc.get("frames", []) as Array).is_empty(),
		"note": "журнал кампании пуст: %s; оправдан: %s; кадров в сцене: %d" % [str(fresh), str(t.acquit), (sc.get("frames", []) as Array).size()]})
	# следы на земле только читают журнал: ход главы не меняется
	var same := true
	for g in range(30):
		var a := play("a1c3", "careful", SEED_BASE + g)
		var b := play("a1c3", "careful", SEED_BASE + g, {"traces": true})
		for k: String in ["passed", "people_win", "player_alive", "share", "nights", "wrong"]:
			same = same and a[k] == b[k]
	out.append({"name": "следы не меняют ход", "ok": same, "note": "30 одинаковых зёрен с чтением следов и без: ходы %s" % ("совпали" if same else "разошлись")})
	return out


const BELL_MAX_GAIN := 0.12
const GRAVE_MAX_GUEST_EXILES := 0.12
const GRAVE_MAX_SHIFT := 0.12
const CANDLE_MAX_SPREAD := 0.12


## Самотест --chapters: все главы тремя стилями на небольшом числе партий, затем проверки перекосов.
## Полная таблица на 500 партий: --simchapters. Границы здесь шире коридора: на малом числе партий разброс ±8 п.п.
static func selftest() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var snap := fresh_campaign()
	var runs := 50
	var fails := PackedStringArray()
	var t0 := Time.get_ticks_msec()
	var rows := table(runs)
	var endless := 0
	for r: Dictionary in rows:
		endless += runs - int(r.ended)
	if endless > 0:
		fails.append("партий без конца: %d" % endless)
	print("главы: %d ячеек по %d партий, без конца %d" % [rows.size(), runs, endless])
	for id: String in Campaign.ORDER:
		var share := chapter_share(rows, id)
		var low := FIRST_CHAPTER_MIN if id == "a1c1" else CORRIDOR_MIN
		var ok := share >= low - SELFTEST_SLACK and share <= CORRIDOR_MAX + SELFTEST_SLACK
		print("  %s %s: выжившие %.0f%% (коридор %.0f–%.0f%%)" % ["OK " if ok else "ЛОЖЬ", id, 100.0 * share, 100.0 * low, 100.0 * CORRIDOR_MAX])
		if not ok:
			fails.append("%s вне коридора: %.0f%%" % [id, 100.0 * share])
	# осторожный играет не хуже случайного: иначе решения игрока ничего не стоят
	var careful := 0.0
	var random := 0.0
	for r: Dictionary in rows:
		if String(r.style) == "careful":
			careful += float(r.share)
		elif String(r.style) == "random":
			random += float(r.share)
	var gap := (careful - random) / float(Campaign.ORDER.size())
	print("  %s осторожный минус случайный: %+.1f п.п. (не меньше %+.0f)" % ["OK " if gap >= -0.01 else "ЛОЖЬ", 100.0 * gap, -1.0])
	if gap < -0.01:
		fails.append("осторожный играет хуже случайного: %+.1f п.п." % (100.0 * gap))
	for c: Dictionary in checks(runs):
		print("  %s %s: %s" % ["OK " if bool(c.ok) else "ЛОЖЬ", c.name, c.note])
		if not bool(c.ok):
			fails.append(String(c.name))
	# лёгкая ступень не тяжелее сложной (в кампании ступень меняет только смерть на улице: числа берутся из главы)
	var ladder := {}
	for dname: String in ["easy", "normal", "hard"]:
		restore_campaign(snap)
		snap = fresh_campaign(dname)
		var sum := 0.0
		for id: String in Campaign.ORDER:
			sum += chapter_share(table(LADDER_RUNS, PackedStringArray([id]), {}, PackedStringArray(["careful"])), id)
		ladder[dname] = sum / float(Campaign.ORDER.size())
	var ladder_ok: bool = float(ladder.easy) >= float(ladder.hard) - 0.02
	print("  %s ступени сложности (осторожный, среднее по главам): лёгкая %.0f%%, обычная %.0f%%, сложная %.0f%%" % [
		"OK " if ladder_ok else "ЛОЖЬ", 100.0 * float(ladder.easy), 100.0 * float(ladder.normal), 100.0 * float(ladder.hard)])
	if not ladder_ok:
		fails.append("ступени сложности идут не по порядку")
	print("время: %.1f с" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	restore_campaign(snap)
	print("ИТОГ: %s" % ("OK" if fails.is_empty() else "ПРОВАЛ: " + "; ".join(fails)))
	tree.quit(0 if fails.is_empty() else 1)


const SELFTEST_SLACK := 0.08
const LADDER_RUNS := 30
