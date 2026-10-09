class_name Director
extends RefCounted
## Управляет всеми ботами. Читает Match, но не меняет фазы — только предлагает
## решения (кто куда идёт, кого пускает, за кого голосует) и реплики.
## Слова игрока реально двигают подозрения и договорённости.

const W_STREET := 2.4      ## вернулся живым с улицы
const W_ALONE := 1.0       ## погас оберег, а он цел
const W_DEATH_ROOM := 2.2  ## ночевал там, где кто-то умер
const W_LIAR := 1.3        ## сказал одно, сделал другое
const W_CLEAN := 0.4       ## тихая ночь слегка обеляет
const W_FAKE := 0.6        ## стоял у дела, а запасов не прибавилось

## Дела по посёлку. Люди работают по-настоящему и изредка срываются;
## упыри делают вид и чаще всего впустую. Сосед может это заметить.
const WORK_SEC := 8.0      ## дорога к делу и работа бота
const HUMAN_FAIL := 0.15   ## ведро сорвалось — у человека тоже бывает
const UPYR_REAL := 0.6    ## упырь доделывает дело по-настоящему чуть больше чем в половине случаев
const NOTICE_P := 0.25      ## шанс, что каждый отдельный сосед заметит пустую работу
const DONE_LINE_P := 0.25  ## шанс, что житель похвастается сделанным
const LIE_P := 0.2         ## шанс, что упырь оболжёт честного работника: «работал впустую»


class JobTask:
	var vid: int
	var job: int
	var start: float
	var real: bool
	var started := false
	var done := false

var m: Match
var rng := RandomNumberGenerator.new()
var public_susp: Dictionary[int, float] = {}
var brains: Dictionary[int, BotBrain] = {}
var street_last_night: Dictionary[int, bool] = {}
var liar_last_night: Dictionary[int, int] = {}   ## id -> дом, о котором врал
var evidence: Dictionary = {}                    ## id -> {"street": n, "liar": n, "death": n} за всю партию


func attach(match_ref: Match) -> void:
	m = match_ref
	rng.seed = m.rng.seed + 7
	public_susp.clear()
	brains.clear()
	street_last_night.clear()
	liar_last_night.clear()
	evidence.clear()
	for v: Villager in m.villagers:
		public_susp[v.id] = 0.0
		if not v.is_player:
			brains[v.id] = BotBrain.new(v)


func susp(vid: int) -> float:
	return public_susp.get(vid, 0.0)


func view(bot: Villager, other: Villager) -> float:
	return brains[bot.id].view(other.id, susp(other.id))


func _note_evidence(vid: int, key: String) -> void:
	if not evidence.has(vid):
		evidence[vid] = {}
	evidence[vid][key] = int(evidence[vid].get(key, 0)) + 1


## Что видит посёлок: 0 — подозрений нет, 4 — почти уверены.
func eye_level(vid: int) -> int:
	var s := susp(vid)
	if s < 0.3:
		return 0
	if s < 1.2:
		return 1
	if s < 2.2:
		return 2
	if s < 3.2:
		return 3
	return 4


func badges(vid: int) -> PackedStringArray:
	var out := PackedStringArray()
	var ev: Dictionary = evidence.get(vid, {})
	for k: String in ["death", "street", "liar", "fake"]:
		if int(ev.get(k, 0)) > 0:
			out.append(k)
	return out


## Улики словами — для шторки по тапу на жителя.
func evidence_text(v: Villager) -> String:
	var ev: Dictionary = evidence.get(v.id, {})
	var parts := PackedStringArray()
	var n := int(ev.get("street", 0))
	if n > 0:
		parts.append(Ru.g(v, "вернулся с улицы живым", "вернулась с улицы живой", "вернулись с улицы живыми") + (" (%d раза)" % n if n > 1 else ""))
	if int(ev.get("liar", 0)) > 0:
		parts.append(Ru.g(v, "соврал", "соврала", "соврали") + ", где ночует")
	if int(ev.get("death", 0)) > 0:
		parts.append(Ru.g(v, "был", "была", "были") + " рядом, когда кто-то погиб")
	if int(ev.get("fake", 0)) > 0:
		parts.append(Ru.g(v, "работал", "работала", "работали") + " впустую")
	return "; ".join(parts)


# =============================================================
# Дела по посёлку
# =============================================================
## План дел ботов на день: кто, какое дело, с какой секунды дня, по-настоящему или нет.
## Боты оставляют пару порций игроку — иначе ему нечего делать.
func plan_jobs(day_sec: float) -> Array[JobTask]:
	var out: Array[JobTask] = []
	if m.jobs.is_empty():
		return out
	var load: Array[int] = []
	load.resize(m.jobs.size())
	var cap := maxi(0, m.supply_total - 2)
	var planned := 0
	for bot: Villager in m.alive_bots():
		var n := 0
		if bot.is_upyr:
			n = 1 if rng.randf() < 0.75 else 0
		elif rng.randf() < 0.8:
			n = 2 if rng.randf() < 0.35 else 1
		var t := rng.randf_range(6.0, maxf(8.0, day_sec * 0.45))
		for k in range(n):
			if t > day_sec - WORK_SEC - 3.0 or planned >= cap:
				break
			var ji := _pick_job(load)
			if ji < 0:
				break
			load[ji] += 1
			planned += 1
			var task := JobTask.new()
			task.vid = bot.id
			task.job = ji
			task.start = t
			task.real = rng.randf() < (UPYR_REAL if bot.is_upyr else 1.0 - HUMAN_FAIL)
			out.append(task)
			t += WORK_SEC + rng.randf_range(6.0, 14.0)
	out.sort_custom(func(a: JobTask, b: JobTask) -> bool: return a.start < b.start)
	return out


func _pick_job(load: Array[int]) -> int:
	var total := 0
	for i in range(m.jobs.size()):
		total += maxi(0, m.jobs[i].portions - load[i])
	if total <= 0:
		return -1
	var r := rng.randi_range(1, total)
	for i in range(m.jobs.size()):
		r -= maxi(0, m.jobs[i].portions - load[i])
		if r <= 0:
			return i
	return -1


## Дело закончено. counted — запасы выросли. Пустая работа (упырь или сорвалось)
## может попасться соседу на глаза: улика «работал впустую» и реплика вслух.
func after_job(vid: int, ji: int, counted: bool, real: bool) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var worker := m.get_villager(vid)
	if worker == null or not worker.alive or ji < 0 or ji >= m.jobs.size():
		return out
	var job: JobDef = m.jobs[ji]
	if counted:
		if not worker.is_player and rng.randf() < DONE_LINE_P:
			out.append(ChatLine.say(worker, job.done_line))
		# упырь клевещет на честного: игрок, видевший «+1» над делом, может поймать его на лжи
		if not worker.is_upyr and rng.randf() < LIE_P:
			var liars: Array[Villager] = []
			for b: Villager in m.alive_bots():
				if b.is_upyr and b != worker:
					liars.append(b)
			if not liars.is_empty():
				out.append(_blame_fake(liars[rng.randi_range(0, liars.size() - 1)], worker, job))
		return out
	if real or worker.is_player:
		return out
	for o: Villager in m.alive_bots():
		if o == worker or rng.randf() >= NOTICE_P:
			continue
		out.append(_blame_fake(o, worker, job))
		break
	return out


## Сказать вслух «работал впустую» — честно или облыжно. Посёлок верит на слово.
func _blame_fake(speaker: Villager, worker: Villager, job: JobDef) -> ChatLine:
	_bump(worker.id, W_FAKE)
	_note_evidence(worker.id, "fake")
	if worker.is_player:
		return ChatLine.say(speaker, Phrases.pick(Phrases.JOB_FAKE_AT_PLAYER, rng, {"place": job.place, "me_f": speaker.female}))
	return _say(speaker, Phrases.JOB_FAKE, worker, {"place": job.place})


## Для прогона без экрана: все дела дня разом. Игрок делает одно дело с шансом 50%.
func run_jobs_instant(tasks: Array[JobTask]) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var me := m.player()
	if me.alive and not m.jobs.is_empty() and rng.randf() < 0.5:
		var pj := rng.randi_range(0, m.jobs.size() - 1)
		out.append_array(after_job(me.id, pj, m.do_job(me, pj, true), true))
	for t: JobTask in tasks:
		var counted := m.do_job(m.get_villager(t.vid), t.job, t.real)
		out.append_array(after_job(t.vid, t.job, counted, t.real))
	return out


func _bump(vid: int, w: float) -> void:
	public_susp[vid] = maxf(0.0, susp(vid) + w)


func _by_susp(list: Array[Villager], ascending: bool = true) -> Array[Villager]:
	var a: Array[Villager] = list.duplicate()
	a.sort_custom(func(x: Villager, y: Villager) -> bool:
		return susp(x.id) < susp(y.id) if ascending else susp(x.id) > susp(y.id))
	return a


func _others(of: Villager) -> Array[Villager]:
	var out: Array[Villager] = []
	for v: Villager in m.alive():
		if v != of:
			out.append(v)
	return out


## Реплика с согласованием: род говорящего, род и падеж того, о ком речь.
## Если речь об игроке — нейтральный банк AT_PLAYER (пол игрока неизвестен).
func _say(who: Villager, bank: PackedStringArray, target: Villager = null, extra: Dictionary = {}) -> ChatLine:
	var vars := extra.duplicate()
	vars["me_f"] = who.female
	if Phrases.mentions_target(bank):
		if target == null:
			vars["who"] = "кто-то другой"
			vars["who_acc"] = "других"
		elif target.is_player:
			bank = Phrases.AT_PLAYER
		else:
			vars["who"] = target.name
			vars["who_f"] = target.female
	return ChatLine.say(who, Phrases.pick(bank, rng, vars))


# =============================================================
# День
# =============================================================
## Боты решают, куда пойдут, и объявляют это. Люди — честно,
## упыри — туда, где их пустит человек, которому верят.
func plan_day() -> void:
	var counts: Array[int] = []
	counts.resize(m.houses.size())
	counts.fill(0)
	for v: Villager in m.alive():
		if v.announced_house >= 0:
			counts[v.announced_house] += 1

	for bot: Villager in _by_susp(m.alive_bots()):
		var b: BotBrain = brains[bot.id]
		if b.pact_house >= 0:
			bot.announced_house = b.pact_house
		elif bot.is_upyr:
			bot.announced_house = _house_of_most_trusted(bot, counts)
		else:
			bot.announced_house = _house_with_partner(bot, counts)
		counts[bot.announced_house] += 1


func _emptiest(counts: Array[int]) -> int:
	var best := 0
	for i in range(counts.size()):
		if counts[i] < counts[best]:
			best = i
	return best


func _house_with_partner(bot: Villager, counts: Array[int]) -> int:
	var others := _others(bot)
	others.sort_custom(func(x: Villager, y: Villager) -> bool: return view(bot, x) < view(bot, y))
	for o: Villager in others:
		if o.announced_house >= 0 and counts[o.announced_house] < m.config.capacity and view(bot, o) < 1.8:
			return o.announced_house
	return _emptiest(counts)


func _house_of_most_trusted(bot: Villager, counts: Array[int]) -> int:
	for o: Villager in _by_susp(_others(bot)):
		if o.announced_house >= 0 and counts[o.announced_house] < m.config.capacity:
			return o.announced_house
	return _emptiest(counts)


func opening_lines() -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var bots := m.alive_bots()
	if bots.is_empty():
		return out

	if m.day > 1:
		for suspect: Villager in _by_susp(m.alive(), false).slice(0, 2):
			if susp(suspect.id) < 1.2:
				continue
			var accuser := _pick_accuser(suspect)
			if accuser == null:
				continue
			var bank := Phrases.ACCUSE_STRONG
			var extra := {}
			if street_last_night.has(suspect.id):
				bank = Phrases.ACCUSE_STREET
			elif liar_last_night.has(suspect.id):
				bank = Phrases.ACCUSE_LIAR
				extra["house"] = m.house_name(liar_last_night[suspect.id])
			out.append(_say(accuser, bank, suspect, extra))
			if not suspect.is_player:
				out.append(_say(suspect, Phrases.UPYR_DEFLECT if suspect.is_upyr else Phrases.DEFEND, _pick_any(suspect)))

	var shuffled := bots.duplicate()
	_shuffle(shuffled)
	for bot: Villager in shuffled.slice(0, mini(3, shuffled.size())):
		out.append(_say(bot, Phrases.ANNOUNCE, null, {"house": m.house_name(bot.announced_house)}))

	if rng.randf() < 0.6:
		out.append(_say(shuffled[shuffled.size() - 1], Phrases.FILLER))
	return out


func _pick_accuser(suspect: Villager) -> Villager:
	var best: Villager = null
	var best_v := -1.0
	for b: Villager in m.alive_bots():
		if b == suspect or b.is_upyr:
			continue
		var v := view(b, suspect)
		if v > best_v:
			best_v = v
			best = b
	return best


func _pick_any(except: Villager) -> Villager:
	var pool: Array[Villager] = []
	for v: Villager in m.alive():
		if v != except:
			pool.append(v)
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


## Реакция на реплику игрока. Именно здесь слова игрока превращаются в последствия.
func react(intent: IntentParser.Result) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var p := m.player()
	if intent.house >= 0 and intent.kind != IntentParser.Kind.INVITE:
		p.announced_house = intent.house

	match intent.kind:
		IntentParser.Kind.ACCUSE:
			var t := intent.target
			var cred := clampf(1.0 - susp(p.id) / 4.0, 0.2, 1.0)
			_bump(t.id, 0.6 * cred)
			var deflect := _pick_any_bot(t)
			out.append(_say(t, Phrases.REPLY_TO_ACCUSED_UPYR if t.is_upyr else Phrases.REPLY_TO_ACCUSED_HUMAN, deflect))
			var judge := _pick_bystander([t])
			if judge != null:
				out.append(_say(judge, Phrases.AGREE_ACCUSE if view(judge, t) >= 1.0 else Phrases.DISAGREE_ACCUSE, t))

		IntentParser.Kind.INVITE:
			var t := intent.target
			var h := intent.house if intent.house >= 0 else (t.announced_house if t.announced_house >= 0 else 0)
			if accepts_invite(t):
				var b: BotBrain = brains[t.id]
				b.pact_id = p.id
				b.pact_house = h
				t.announced_house = h
				p.announced_house = h
				out.append(_say(t, Phrases.INVITE_YES, null, {"house": m.house_name(h)}))
			else:
				out.append(_say(t, Phrases.INVITE_NO))

		IntentParser.Kind.ASK:
			var t := intent.target
			if t.announced_house >= 0:
				out.append(_say(t, Phrases.ASK_ANSWER_HUMAN, null, {"house": m.house_name(t.announced_house)}))
			else:
				out.append(_say(t, Phrases.ASK_ANSWER_UNSURE))

		IntentParser.Kind.DEFEND:
			if susp(p.id) > 0.0:
				_bump(p.id, -0.3)
			var who := _pick_bystander([])
			if who != null:
				out.append(_say(who, Phrases.PLAYER_DEFEND_REACTION))

		_:
			var who := _pick_bystander([])
			if who != null:
				out.append(_say(who, Phrases.GENERIC_REACTION))
	return out


func accepts_invite(bot: Villager) -> bool:
	if bot.is_upyr:
		return rng.randf() < 0.85
	return view(bot, m.player()) < 1.6 and brains[bot.id].pact_id < 0


## Любой живой бот, кроме указанного: на кого перевести стрелки в ответ игроку.
func _pick_any_bot(except: Villager) -> Villager:
	var pool: Array[Villager] = []
	for v: Villager in m.alive_bots():
		if v != except:
			pool.append(v)
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


func _pick_bystander(exclude: Array[Villager]) -> Villager:
	var pool: Array[Villager] = []
	for v: Villager in m.alive_bots():
		if not exclude.has(v):
			pool.append(v)
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


# =============================================================
# Ночь
# =============================================================
func night_choices() -> Dictionary[int, int]:
	var out: Dictionary[int, int] = {}
	for bot: Villager in m.alive_bots():
		var b: BotBrain = brains[bot.id]
		var h := bot.announced_house if bot.announced_house >= 0 else rng.randi_range(0, m.houses.size() - 1)
		if b.pact_house >= 0:
			h = b.pact_house
		elif bot.is_upyr and not bot.fed and rng.randf() < 0.3:
			h = rng.randi_range(0, m.houses.size() - 1)   # передумал — оставит след во лжи
		out[bot.id] = h
	return out


func plea_for(bot: Villager) -> String:
	var b: BotBrain = brains[bot.id]
	var g := {"me_f": bot.female}
	if b.pact_id == m.player().id:
		return Phrases.pick(Phrases.PLEA_PACT, rng, g)
	if street_last_night.has(bot.id):
		return Phrases.pick(Phrases.PLEA_AFTER_STREET, rng, g)
	if susp(bot.id) > 2.0:
		return Phrases.pick(Phrases.PLEA_SUSPECT, rng, g)
	return Phrases.pick(Phrases.PLEA_NORMAL, rng, g)


## Бот-хозяин двери решает, кого впустить. player_plea — id мольбы игрока, если он в очереди.
func host_decide(seat: Match.Seat, player_plea: String = "") -> Array[int]:
	var host := seat.host
	var b: BotBrain = brains[host.id]
	var scored: Array = []
	for g: Villager in seat.queue:
		var s := -view(host, g)
		if b.pact_id == g.id:
			s += 3.0
		if g.is_player:
			s += _plea_weight(host, player_plea)
		else:
			s += rng.randf_range(0.0, 0.4)
		if host.is_upyr:
			s += b.grudge.get(g.id, 0.0) * 0.5   # упырю обиды безразличны
		scored.append([s, g.id])
	scored.sort_custom(func(a: Array, c: Array) -> bool: return a[0] > c[0])

	var out: Array[int] = []
	if scored.is_empty():
		return out
	if not host.is_upyr and float(scored[0][0]) < -2.8 and rng.randf() < 0.6:
		return out   # всем не верит — рискнёт остаться один
	for i in range(mini(m.config.capacity - 1, scored.size())):
		out.append(int(scored[i][1]))
	return out


func _plea_weight(host: Villager, plea: String) -> float:
	match plea:
		"shared":
			return 1.2 if brains[host.id].shared_clean.get(m.player().id, 0) > 0 else -0.8
		"promise":
			return 0.5
		"name":
			return 0.6
		"beg":
			return 0.25
	return 0.1


func after_door(seats: Array[Match.Seat]) -> void:
	for s: Match.Seat in seats:
		for v: Villager in s.turned_away():
			if brains.has(v.id):
				brains[v.id].remember_refusal(s.host)


func read_report(r: NightReport) -> void:
	street_last_night.clear()
	liar_last_night.clear()
	for e: NightReport.Entry in r.entries:
		match e.kind:
			NightReport.Kind.SURVIVED_STREET:
				_bump(e.who.id, W_STREET)
				street_last_night[e.who.id] = true
				_note_evidence(e.who.id, "street")
			NightReport.Kind.SURVIVED_ALONE:
				_bump(e.who.id, W_ALONE)
			NightReport.Kind.KILLED_INSIDE:
				for o: Villager in e.others:
					_bump(o.id, W_DEATH_ROOM / float(e.others.size()))
					_note_evidence(o.id, "death")
			NightReport.Kind.CLEAN_ROOM:
				for o: Villager in e.others:
					_bump(o.id, -W_CLEAN)
					if brains.has(o.id):
						for o2: Villager in e.others:
							if o2 != o:
								brains[o.id].remember_clean_night(o2)
			NightReport.Kind.LIAR:
				_bump(e.who.id, W_LIAR)
				liar_last_night[e.who.id] = e.said_house
				_note_evidence(e.who.id, "liar")
	for b: BotBrain in brains.values():
		b.clear_pact()


## Голоса считаются ОДИН раз. (В v0.1 они пересчитывались на каждой итерации
## со случайностью внутри — подсчёт был несогласованным.)
func votes() -> Dictionary[int, int]:
	var out: Dictionary[int, int] = {}
	for bot: Villager in m.alive_bots():
		var pool := _others(bot)
		if pool.is_empty():
			continue
		var target: Villager
		if bot.is_upyr:
			target = _by_susp(pool)[0]   # топит того, кому верят — скорее всего человека
		else:
			pool.sort_custom(func(x: Villager, y: Villager) -> bool: return view(bot, x) > view(bot, y))
			target = pool[0]
			if view(bot, target) < 0.6 and rng.randf() < 0.5:
				target = pool[rng.randi_range(0, pool.size() - 1)]
		out[bot.id] = target.id
	return out


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
