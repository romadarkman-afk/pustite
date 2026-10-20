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
const RUN_SPEED := 145.0                  ## соответствует ходьбе фигурки
const RUN_REACT := Vector2(2.0, 5.0)      ## через сколько секунд бот срывается с места: дослушать, оглядеться, решиться
const RUN_REACT_FAST := Vector2(0.5, 1.5) ## а этот был наготове и рванул сразу
const RUN_FAST_P := 0.25                  ## доля таких шустрых: замешкался на пару секунд — у двери уже кто-то есть
const SABOTAGE_P := 0.5    ## упырь, который не работает по-настоящему, портит сделанное в половине случаев
const W_SABOTAGE := 1.0    ## видели у испорченного дела
const SABOTAGE_NOTICE := 0.35   ## шанс, что кто-то из людей заметит, кто испортил
const W_NOTE := 0.8        ## назван в записке из ящика
## Подражатель у двери: шанс, что бот-хозяин впустит голос. Погибшего узнают почти всегда.
const MIMIC_TRUST_DEAD := 0.05
const MIMIC_TRUST_ELSEWHERE := 0.2   ## говорил днём, что ночует в другом доме
const MIMIC_TRUST := 0.35
const W_ELDER := 3.0       ## старожил назвал упырём — посёлок почти уверен
const W_ELDER_CLEAR := 1.0 ## старожил назвал человеком
const ELDER_DAY1_P := 0.4  ## старожил смотрит рисунки уже в первый день
const ELDER_SPEAK_CLEAR := 0.6   ## проверил человека — скажет об этом вслух
const FAKE_ELDER_P := 0.5  ## упырь назовётся старожилом (раз за партию, со второго дня)
const ELDER_HUNT_P := 0.6  ## голодный упырь идёт ночевать к тому, кто назвался старожилом
const W_TUNNEL := 0.8      ## пролез туннелем в чужой дом
const HEAL_P := 0.6        ## знахарка берёт травы, когда ночует не одна
const MEETING_SUSP := 2.0  ## бот бьёт в колокол днём, если кого-то подозревают хотя бы так
const MEETING_P := 0.6
## Жесты игрока без слов: слабее сказанного вслух. Повтор того же жеста тому же жителю в тот же день ничего не добавляет.
const GEST_POINT := 0.4       ## показал пальцем — молчаливое обвинение
const GEST_DISTRUST := 0.25   ## «не верю»
const GEST_TRUST := 0.6       ## «верю»: этот бот лучше думает об игроке и охотнее пустит его


class JobTask:
	var vid: int
	var job: int
	var start: float
	var real: bool
	var sabotage := false     ## упырь идёт портить сделанное
	var started := false
	var done := false

var m: Match
var rng := RandomNumberGenerator.new()
var public_susp: Dictionary[int, float] = {}
var brains: Dictionary[int, BotBrain] = {}
var street_last_night: Dictionary[int, bool] = {}
var liar_last_night: Dictionary[int, int] = {}   ## id -> дом, о котором врал
var evidence: Dictionary = {}                    ## id -> {"street": n, "liar": n, "death": n} за всю партию
var pending_lines: Array[ChatLine] = []          ## что скажут первым делом утром (старожил)
var fake_elder_done := false
var gestured: Dictionary = {}   ## «жест:id:день» — какие жесты уже засчитаны
var last_question_topic := ""
var said: Dictionary = {}      ## шаблоны, уже прозвучавшие в этой партии: второй раз — только если других нет
const OWN_VOICE_P := 0.75      ## как часто житель говорит строкой своего характера, а не общей
const W_REVENGE := 0.8         ## утро после гибели близкого: тот, кто не открыл ему дверь, под подозрением
var last_questioner := -1
## Обещания (TASK-004): что скажут утром о сдержанном и нарушенном слове.
var promise_lines: Array[ChatLine] = []
var scene_lines: Array[ChatLine] = []     ## что скажут днём после сцены (отозвался на зов у реки)
var first_chapter := false                ## глава «Стук»: в первый день кто-то обязательно обещает открыть
var chapter_id := ""                      ## глава кампании или "" — обычная партия
const W_BOAT_BACK := 0.8
const W_CONFRONT := 0.4                   ## спросили при всех о противоречии
const W_DENY := 0.3                       ## отпирается, когда улики против
const UPYR_FAKE_ADMIT := 0.25             ## упырь иногда «признаётся» с правдоподобным объяснением
const PROMISE_BOT_P := 0.35       ## шанс, что утром кто-то из жителей сам пообещает игроку открыть
const PROMISE_UPYR_KEEP := 0.5    ## упырь держит слово только в половине случаев
const PROMISE_HOST := 2.5         ## вес обещания «открою тебе» для хозяина двери
const W_PROMISE_BROKEN := 0.3     ## нарушил слово при всех: подозрение посёлка
## Подстройка под игрока (задача 49): −1 — игрок проиграл несколько раз подряд, боты слабее;
## +1 — игрок часто выигрывает, боты собраннее. Ступень сложности не меняется.
## Слабее значит: против игрока-человека упыри врут неубедительно, люди-хозяева лучше верят игроку;
## против игрока-упыря люди чаще ошибаются у двери и медленнее его подозревают.
var tune := 0.0


func attach(match_ref: Match) -> void:
	m = match_ref
	rng.seed = m.rng.seed + 7
	public_susp.clear()
	brains.clear()
	street_last_night.clear()
	liar_last_night.clear()
	evidence.clear()
	last_question_topic = ""
	last_questioner = -1
	said.clear()
	promise_lines.clear()
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


## Все виды улик-значков над жителем, по важности.
const BADGES: PackedStringArray = ["death", "sabotage", "street", "liar", "tunnel", "fake"]


func badges(vid: int) -> PackedStringArray:
	var out := PackedStringArray()
	var ev: Dictionary = evidence.get(vid, {})
	for k: String in BADGES:
		if int(ev.get(k, 0)) > 0:
			out.append(k)
	return out


## Улики словами — для шторки по тапу на жителя.
func evidence_text(v: Villager) -> String:
	var ev: Dictionary = evidence.get(v.id, {})
	var parts := PackedStringArray()
	var n := int(ev.get("street", 0))
	var a := {"who": v, "n": n}
	if n > 0:
		parts.append(L.t("ev.street", a) + (L.t("ev.times", a) if n > 1 else ""))
	for k: String in ["liar", "death", "fake", "sabotage", "tunnel"]:
		if int(ev.get(k, 0)) > 0:
			parts.append(L.t("ev." + k, a))
	return L.t("ev.sep").join(parts)


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
		if bot.grief_days > 0 and not bot.is_upyr:
			n = 0                     # в трауре: не до вёдер и дров
		elif bot.is_upyr:
			n = 1 if rng.randf() < 0.75 else 0
		elif rng.randf() < 0.85:
			n = 2 if rng.randf() < 0.4 else 1
		var tired := m.feelings.get_f(bot.id, Feelings.F.EXHAUSTION)
		if tired >= 0.7 and not bot.is_upyr:
			n = mini(n, 1)                # не спал ночь: на второе дело сил нет
		# за дело берутся с первых секунд дня, а не к середине: посёлок с утра в работе
		var t := rng.randf_range(2.5, maxf(5.0, day_sec * 0.3))
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
			task.sabotage = bot.is_upyr and not task.real and rng.randf() < SABOTAGE_P
			out.append(task)
			t += WORK_SEC + rng.randf_range(4.0, 9.0) + tired * 8.0     # уставший долго собирается
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
				out.append(_blame_fake(liars[rng.randi_range(0, liars.size() - 1)], worker, job, true))
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
func _blame_fake(speaker: Villager, worker: Villager, job: JobDef, lie: bool = false) -> ChatLine:
	_bump(worker.id, lie_weight(W_FAKE) if lie else W_FAKE)
	if lie:
		_lie_exposed(speaker)
	_note_evidence(worker.id, "fake")
	if worker.is_player:
		return _say(speaker, "JOB_FAKE_AT_PLAYER", worker, {"place": job.place})
	return _say(speaker, "JOB_FAKE", worker, {"place": job.place})


## Для прогона без экрана: все дела дня разом. Игрок делает одно дело с шансом 50%.
## Ящик, если он сегодня есть, открывает случайный живой житель.
func run_jobs_instant(tasks: Array[JobTask]) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var me := m.player()
	if me.alive and not m.jobs.is_empty() and rng.randf() < 0.5:
		var pj := rng.randi_range(0, m.jobs.size() - 1)
		out.append_array(after_job(me.id, pj, m.do_job(me, pj, true), true))
	for t: JobTask in tasks:
		if t.sabotage:
			out.append_array(after_sabotage(t.vid, t.job, m.sabotage(t.job)))
			continue
		var counted := m.do_job(m.get_villager(t.vid), t.job, t.real)
		out.append_array(after_job(t.vid, t.job, counted, t.real))
	if m.box_today and m.place_box() >= 0:
		var al := m.alive()
		var opener: Villager = al[rng.randi_range(0, al.size() - 1)]
		out.append_array(after_box(opener.id, m.open_box(opener)))
	return out


# =============================================================
# Саботаж
# =============================================================
## Упырь закончил портить. spoiled — правда ли что-то испортилось (было что портить).
## Испорченное видят все: системная строка. Сосед мог заметить, кто это был.
func after_sabotage(vid: int, ji: int, spoiled: bool) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var worker := m.get_villager(vid)
	if worker == null or not worker.alive or ji < 0 or ji >= m.jobs.size():
		return out
	var job: JobDef = m.jobs[ji]
	if not spoiled:
		return after_job(vid, ji, false, false)   # портить было нечего — со стороны пустая работа
	out.append(ChatLine.system(L.t("sys.sabotage", {"place": job.place, "what": Phrases.spoil(job.kind)})))
	if rng.randf() >= SABOTAGE_NOTICE:
		return out
	var eyes: Array[Villager] = []
	for o: Villager in m.alive_bots():
		if o != worker and not o.is_upyr:
			eyes.append(o)
	if eyes.is_empty():
		return out
	var o: Villager = eyes[rng.randi_range(0, eyes.size() - 1)]
	_bump(worker.id, W_SABOTAGE)
	_note_evidence(worker.id, "sabotage")
	if worker.is_player:
		out.append(_say(o, "SABOTAGE_SEEN_AT_PLAYER", worker, {"place": job.place}))
	else:
		out.append(_say(o, "SABOTAGE_SEEN", worker, {"place": job.place}))
	return out


# =============================================================
# Ящик
# =============================================================
## Открывший ящик рассказывает, что нашёл. Человек говорит правду. Упырь, нашедший записку,
## называет двух людей. Игрок решает сам: его находку видит только он.
func after_box(vid: int, res: Dictionary) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var who := m.get_villager(vid)
	if res.is_empty() or who == null or who.is_player:
		return out
	var g := {"me": who}
	match int(res.loot):
		Match.Loot.NOTE:
			var a: Villager = res.a
			var b: Villager = res.b
			if who.is_upyr:
				var hums: Array[Villager] = []
				for o: Villager in m.alive():
					if o != who and not o.is_upyr:
						hums.append(o)
				_shuffle(hums)
				if hums.size() >= 2:
					a = hums[0]
					b = hums[1]
			g["a"] = a
			g["b"] = b
			_bump(a.id, W_NOTE)
			_bump(b.id, W_NOTE)
			out.append(ChatLine.say(who, Phrases.pick("BOX_NOTE", rng, g)))
		Match.Loot.OIL:
			out.append(ChatLine.say(who, Phrases.pick("BOX_OIL", rng, g)))
		Match.Loot.CHALK:
			g["house"] = m.house_name(int(res.get("house", 0)))
			out.append(ChatLine.say(who, Phrases.pick("BOX_CHALK", rng, g)))
	return out


## Кто из ботов пойдёт к ящику: случайный живой бот.
func box_runner() -> Villager:
	var bots := m.alive_bots()
	return bots[rng.randi_range(0, bots.size() - 1)] if not bots.is_empty() else null


func _bump(vid: int, w: float) -> void:
	if vid == 0 and w > 0.0 and m.player().is_upyr:
		w *= clampf(1.0 - 0.35 * give(), 0.5, 1.4)    # игрок-упырь: подозрение растёт медленнее при поддавках
	public_susp[vid] = maxf(0.0, susp(vid) + w)


## Насколько боты поддаются: +1 — сильно, 0 — как задумано, −1 — собраннее обычного.
func give() -> float:
	return clampf(-tune, -1.0, 1.0)


## Вес лжи упыря: против игрока-человека при поддавках слабее, у собранных ботов — убедительнее.
func lie_weight(w: float) -> float:
	if m.player().is_upyr:
		return w
	return w * clampf(1.0 - 0.5 * give(), 0.3, 1.6)


## Разброс в оценке гостей у двери у бота-человека: чем больше, тем чаще он впускает не того.
func door_noise(host: Villager) -> float:
	if host.is_upyr:
		return 0.4
	var k := 1.5 if m.player().is_upyr else -0.5
	return 0.4 * clampf(1.0 + k * give(), 0.3, 2.5)


## Соврал неубедительно: при поддавках на лгуна самого начинают коситься.
func _lie_exposed(liar: Villager) -> void:
	if give() > 0.0 and not m.player().is_upyr:
		_bump(liar.id, 0.3 * give())


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
## Строка для говорящего: чаще своим голосом (Voices), реже общая; уже сказанное за партию
## берётся, только когда всё остальное в банке исчерпано.
func _pick_line(who: Villager, bank: String) -> String:
	var own := Voices.lines(who.persona if who != null else -1, bank)
	var common := Phrases.b(bank)
	var first := own if not own.is_empty() and rng.randf() < OWN_VOICE_P else common
	var second := common if first == own else own
	for pool: PackedStringArray in [first, second]:
		var fresh: Array[String] = []
		for t: String in pool:
			if not said.has(t):
				fresh.append(t)
		if not fresh.is_empty():
			var t2: String = fresh[rng.randi_range(0, fresh.size() - 1)]
			said[t2] = true
			return t2
	var all := first if not first.is_empty() else common
	if all.is_empty():
		return ""
	return all[rng.randi_range(0, all.size() - 1)]


func _say(who: Villager, bank: String, target: Villager = null, extra: Dictionary = {}) -> ChatLine:
	var vars := extra.duplicate()
	vars["me"] = who
	vars["player_name"] = m.player().name
	if Phrases.mentions_target(bank):
		if target == null:
			vars["who"] = L.raw("someone")
		elif target.is_player:
			if bank in ["ACCUSE_DEATH", "ACCUSE_FAKE", "ACCUSE_SABOTAGE", "ACCUSE_TUNNEL", "REVENGE"]:
				vars["who"] = target.name
			else:
				bank = "AT_PLAYER"
		else:
			vars["who"] = target
	var tpl := _pick_line(who, bank)
	var text := L.fill(tpl, vars)
	if bank == "AT_PLAYER" and not Save.player_name.is_empty():
		text = "%s, %s" % [m.player().name, text.left(1).to_lower() + text.substr(1)]
	var line := ChatLine.say(who, text)
	if target != null and Phrases.ACCUSING.has(bank) and (tpl.contains("{who") or bank.ends_with("AT_PLAYER")):
		line.about = target
	return line


# =============================================================
# День
# =============================================================
## Боты решают, куда пойдут, и объявляют это. Люди — честно,
## упыри — туда, где их пустит человек, которому верят.
func plan_day() -> void:
	bots_vouch()
	if m.train_on:
		secret_listing()                 # союзник вписывает первым, пока список пуст (TASK-034)
	bots_list()
	var counts: Array[int] = []
	counts.resize(m.houses.size())
	counts.fill(0)
	if m.flooded_house >= 0:
		counts[m.flooded_house] = 99           # залитый дом: туда никто не собирается
	for v: Villager in m.alive():
		if v.announced_house >= 0:
			v.announced_house = m.dry_house(v.announced_house)
			counts[v.announced_house] += 1

	for bot: Villager in _by_susp(m.alive_bots()):
		var b: BotBrain = brains[bot.id]
		if b.pact_house >= 0:
			bot.announced_house = b.pact_house
		elif bot.is_upyr:
			bot.announced_house = _house_of_most_trusted(bot, counts)
		else:
			bot.announced_house = _house_with_partner(bot, counts)
		bot.announced_house = m.dry_house(bot.announced_house)
		counts[bot.announced_house] += 1
	_elder_day()
	_plan_wander()


## Отчаяние (TASK-008): житель в сильном отчаянии решает ночью уйти к реке на голос. Утром говорит об этом,
## и его можно остановить: выслушать или пообещать прийти. Свой генератор: обычный ход партии не меняется.
const WANDER_FROM := 0.6
const WANDER_P := 0.5


func _plan_wander() -> void:
	m.wander_plan.clear()
	for bot: Villager in m.alive_bots():
		if bot.is_upyr or m.feelings.get_f(bot.id, Feelings.F.DESPAIR) < WANDER_FROM:
			continue
		var wr := RandomNumberGenerator.new()
		wr.seed = hash("wander:%d:%d:%d" % [m.day, bot.id, m.case_id])
		if wr.randf() < WANDER_P:
			m.wander_plan[bot.id] = true
			var line := ChatLine.say(bot, L.fill(Phrases.pick("WANDER_WARN", wr, {"me": bot}), {}))
			line.emotion = "sad"
			pending_lines.append(line)


## Старожил смотрит рисунки и рассказывает. Упырь иногда называется старожилом и топит человека.
func _elder_day() -> void:
	pending_lines.clear()
	var elder := m.role_holder(Match.Role.ELDER)
	if elder != null and not elder.is_player and elder.alive and not elder.role_used and (m.day >= 2 or rng.randf() < ELDER_DAY1_P):
		var pool := _others(elder)
		pool.sort_custom(func(x: Villager, y: Villager) -> bool: return view(elder, x) > view(elder, y))
		if not pool.is_empty():
			var t: Villager = pool[0]
			if m.elder_check(elder, t) == 1:
				_bump(t.id, W_ELDER)
				m.claim(elder, t, L.t("claim.elder_upyr", {"me": elder, "who": t}), true)
				pending_lines.append(_say(elder, "ELDER_UPYR", t))
			elif rng.randf() < ELDER_SPEAK_CLEAR:
				_bump(t.id, -W_ELDER_CLEAR)
				m.claim(elder, t, L.t("claim.elder_human", {"me": elder, "who": t}), true)
				pending_lines.append(_say(elder, "ELDER_HUMAN", t))
	if not fake_elder_done and m.day >= 2 and rng.randf() < FAKE_ELDER_P:
		var liars: Array[Villager] = []
		for b: Villager in m.alive_bots():
			if b.is_upyr:
				liars.append(b)
		if not liars.is_empty():
			var liar: Villager = liars[rng.randi_range(0, liars.size() - 1)]
			var victims: Array[Villager] = []
			for o: Villager in m.alive():
				if o != liar and not o.is_upyr:
					victims.append(o)
			if not victims.is_empty():
				fake_elder_done = true
				var t2: Villager = victims[rng.randi_range(0, victims.size() - 1)]
				_bump(t2.id, lie_weight(W_ELDER))
				_lie_exposed(liar)
				m.claim(liar, t2, L.t("claim.elder_upyr", {"me": liar, "who": t2}), true)
				pending_lines.append(_say(liar, "ELDER_UPYR", t2))


## Кто назвался старожилом (кроме самого бота) и ещё жив. Упырям он опасен.
func _claimed_elder(bot: Villager) -> Villager:
	for vid: int in m.claims:
		var v := m.get_villager(vid)
		if v != null and v != bot and v.alive and m.claim_elder.has(vid):
			return v
	return null


## Кто из ботов ударит в колокол днём. null — никто. Только когда голосования сегодня иначе не будет.
func meeting_caller() -> Villager:
	if m.vote_open() or m.phase != Match.Phase.DAY:
		return null
	var top: Villager = null
	for v: Villager in m.alive():
		if top == null or susp(v.id) > susp(top.id):
			top = v
	if top == null or susp(top.id) < MEETING_SUSP or rng.randf() >= MEETING_P:
		return null
	var callers: Array[Villager] = []
	for b: Villager in m.alive_bots():
		if b != top and m.can_meeting(b):
			callers.append(b)
	return callers[rng.randi_range(0, callers.size() - 1)] if not callers.is_empty() else null


## Что скажет бот, ударив в колокол: про самого подозрительного.
func meeting_line(caller: Villager) -> ChatLine:
	var top: Villager = null
	for v: Villager in _others(caller):
		if top == null or susp(v.id) > susp(top.id):
			top = v
	return _say(caller, "MEETING_CALL", top)


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
	out.append_array(pending_lines)
	pending_lines.clear()
	out.append_array(promise_lines)
	promise_lines.clear()
	out.append_array(scene_lines)
	scene_lines.clear()
	out.append_array(chapter_lines())
	out.append_array(act_three_daily())
	out.append_array(grief_lines())
	out.append_array(emotional_lines())

	if m.day > 1:
		for suspect: Villager in _by_susp(m.alive(), false).slice(0, 2):
			if susp(suspect.id) < 1.2:
				continue
			var accuser := _pick_accuser(suspect)
			if accuser == null:
				continue
			var bank := "ACCUSE_STRONG"
			var extra := {}
			if street_last_night.has(suspect.id):
				bank = "ACCUSE_STREET"
			elif liar_last_night.has(suspect.id):
				bank = "ACCUSE_LIAR"
				extra["house"] = m.house_name(liar_last_night[suspect.id])
			else:
				var ev: Dictionary = evidence.get(suspect.id, {})
				if int(ev.get("death", 0)) > 0:
					bank = "ACCUSE_DEATH"
				elif int(ev.get("sabotage", 0)) > 0:
					bank = "ACCUSE_SABOTAGE"
				elif int(ev.get("fake", 0)) > 0:
					bank = "ACCUSE_FAKE"
				elif int(ev.get("tunnel", 0)) > 0:
					bank = "ACCUSE_TUNNEL"
			out.append(_say(accuser, bank, suspect, extra))
			if not suspect.is_player:
				out.append(_say(suspect, "UPYR_DEFLECT" if suspect.is_upyr else "DEFEND", _pick_any(suspect)))

	var shuffled := bots.duplicate()
	_shuffle(shuffled)
	for bot: Villager in shuffled.slice(0, mini(3, shuffled.size())):
		out.append(_say(bot, "ANNOUNCE", null, {"house": m.house_name(bot.announced_house)}))

	if rng.randf() < 0.6:
		out.append(_say(shuffled[shuffled.size() - 1], "FILLER"))
	var offer := bot_promise()
	if offer != null:
		out.append(offer)
	var question := player_question()
	if question != null:
		out.append(question)
	return out


## Житель сам обещает игроку открыть ему ночью (TASK-004). Свой генератор: ход партии не меняется.
## Обещает тот, кто лучше всех думает об игроке. Упыри обещают так же охотно, а держат слово хуже.
func bot_promise() -> ChatLine:
	var me := m.player()
	if not me.alive or m.phase != Match.Phase.DAY:
		return null
	var pr := RandomNumberGenerator.new()
	pr.seed = hash("promise:%d:%d:%d" % [m.day, m.villagers.size(), m.case_id])
	# глава «Стук»: в первый же день, когда можно, кто-то обязательно обещает открыть (TASK-011)
	var first := first_chapter and m.promises.filter(func(p: Dictionary) -> bool: return int(p.to) == me.id).is_empty()
	if pr.randf() >= PROMISE_BOT_P and not first:
		return null
	var best: Villager = null
	for bot: Villager in m.alive_bots():
		if not m.promises_today(bot.id, me.id).is_empty():
			continue
		if best == null or view(bot, me) < view(best, me):
			best = bot
	if best == null or (view(best, me) > 1.2 and not first):
		return null
	m.promise(best, me, "open")
	var line := ChatLine.say(best, L.fill(Phrases.pick("PROMISE_BOT_OPEN", pr, {"me": best}), {}))
	line.emotion = "relieved"
	return line


## Реплики главы (TASK-016): в «Тумане» в первый день солдат Гордей учит спрашивать о памяти,
## вдова Агафья рассказывает, как туман забрал мужа.
func chapter_lines() -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	if m.day == 1:
		out.append_array(act_two_lines())
	if chapter_id != "a1c2" or m.day != 1:
		return out
	for v: Villager in m.alive_bots():
		if v.guest_id == "soldier":
			out.append(ChatLine.say(v, L.t("fog.teach", {"me": v})))
		elif v.guest_id == "widow":
			var l := ChatLine.say(v, L.t("fog.widow", {"me": v}))
			l.emotion = "sad"
			out.append(l)
	return out


# =============================================================
# Акт II (TASK-021–025): мельник, чужаки, половодье, память акта I
# =============================================================
const W_STRANGER := 0.3          ## «Чужаки»: местные с первого дня косятся на гостей
const W_GRAVE := 0.25            ## после могилы деревня винит гостей ещё сильнее
const W_TELL := 0.12             ## рассказал беженцам про мельника — посёлок доверяет больше


## Строка хозяина места в чате.
static func npc_line(id: String, text: String) -> ChatLine:
	var l := ChatLine.system(L.t("npc.line", {"name": Npc.display_name(id), "text": text}))
	l.npc_id = id
	l.npc_text = text
	return l


## Первый день глав акта II и последствия тайны мельника в акте III.
func act_two_lines() -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	match chapter_id:
		"a2c1":
			out.append(npc_line("miller", L.t("npc.miller.rule")))
			var board := Campaign.board_choice()
			if not board.is_empty():
				out.append(npc_line("miller", L.t("npc.miller.board_" + board)))   # ответ у доски меняет мельника (TASK-025)
			out.append_array(carry_lines())
		"a2c2":
			out.append(npc_line("miller", L.t("npc.miller.strangers")))
			for b: Villager in m.alive_bots():
				if not b.guest_id.is_empty():
					continue
				for g: Villager in m.alive_bots():
					if not g.guest_id.is_empty():
						brains[b.id].private_delta[g.id] = brains[b.id].private_delta.get(g.id, 0.0) + W_STRANGER
		"a2c3":
			out.append(npc_line("miller", L.t("npc.miller.flood")))
		"a4c1", "a4c2", "a4c3":
			out.append_array(act_four_open())
		"a3c1", "a3c2", "a3c3":
			out.append_array(act_three_open())
			var mc := Campaign.miller_choice() if chapter_id != "a3c3" else ""
			var bots := m.alive_bots()
			if not mc.is_empty() and not bots.is_empty():
				var v: Villager = bots[0]
				for b: Villager in bots:
					if b.guest_id.is_empty():
						v = b
						break
				if chapter_id == "a3c1":
					out.append(ChatLine.say(v, L.t("carry.miller_" + mc, {"me": v})))
				if mc == "tell":
					for b: Villager in bots:
						brains[b.id].private_delta[0] = brains[b.id].private_delta.get(0, 0.0) - W_TELL
	return out


## Акт III (TASK-026–029): Игнат и Анфиса в первый день главы называют, чем она живёт.
func act_three_open() -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	out.append(npc_line("ignat", L.t("npc.ignat.open_" + chapter_id)))
	out.append(npc_line("anfisa", L.t("npc.anfisa.open_" + chapter_id)))
	return out


## Реплика хозяев монастыря в начале каждого следующего дня: по очереди, своя на каждый день.
func act_three_daily() -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	if not chapter_id.begins_with("a3") or m.day < 2:
		return out
	var who := "ignat" if m.day % 2 == 0 else "anfisa"
	out.append(npc_line(who, L.t("npc.%s.day%d" % [who, clampi(m.day - 1, 1, 3)])))
	return out


## Ответ Игната или Анфисы. Анфиса со второй главы показывает зачёркнутые имена (TASK-027, 028).
func act_three_answer(id: String, topic: String) -> String:
	if id == "anfisa" and topic == "crossed":
		if chapter_id == "a3c1":
			return L.t("npc.anfisa.a_crossed_early")
		m.clues.add("find", -1, L.t("clue.crossed_book"), {"mystery": "crossed"})
		return L.t("npc.anfisa.a_crossed")
	return L.t("npc.%s.a_%s" % [id, topic])


## «Ворота» (TASK-026): днём двое жителей вписывают в книгу того, кому больше всех верят.
## Упырь тоже вписывает: так он выглядит своим. Поручительство — запись в тетради улик.
const VOUCH_BOTS := 2


func bots_vouch() -> void:
	if not m.vouch_on:
		return
	var n := 0
	for bot: Villager in _by_susp(m.alive_bots()):
		if n >= VOUCH_BOTS:
			break
		var best: Villager = null
		for o: Villager in _others(bot):
			if o.is_player or not o.alive:
				continue
			if best == null or view(bot, o) < view(bot, best):
				best = o
		if best != null and m.vouch(bot, best):
			n += 1


# =============================================================
# Акт IV (TASK-032–034): люди станции, список на поезд, союзник
# =============================================================
const LIST_BOTS := 2
var ally_id := -1                ## «Последний поезд»: союзник игрока (или писарь), который тайно вписал упыря


## Первый день глав акта IV: смотритель, рабочий депо, писарь.
func act_four_open() -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	out.append(npc_line("keeper", L.t("npc.keeper.open_" + chapter_id)))
	for g: Villager in m.alive_bots():
		if g.guest_id == "worker" and chapter_id == "a4c1":
			out.append(ChatLine.say(g, L.t("st.worker.open", {"me": g})))
		elif g.guest_id == "clerk" and chapter_id == "a4c2":
			out.append(ChatLine.say(g, L.t("st.clerk.open", {"me": g})))
	if m.train_on:
		secret_listing()
	return out


## Союзник — тот, кто относится к игроку лучше всех. Если особых отношений нет, предаёт писарь.
## Человек тайно вписывает упыря, чтобы тот его не тронул; упырь вписывает сам себя: весь акт он только играл друга.
func pick_ally() -> Villager:
	var best: Villager = null
	var best_v := INF
	var worst_v := -INF
	for b: Villager in m.alive_bots():
		var v := view(b, m.player())
		worst_v = maxf(worst_v, v)
		if b.guest_id.is_empty() and v < best_v:
			best_v = v
			best = b
	if best == null or worst_v - best_v < 0.05:
		for b: Villager in m.alive_bots():
			if b.guest_id == "clerk":
				return b
	return best


func secret_listing() -> void:
	if ally_id >= 0:
		return
	var ally := pick_ally()
	if ally == null:
		return
	ally_id = ally.id
	m.betrayer_id = ally.id
	var target: Villager = ally if ally.is_upyr else null
	if target == null:
		for u: Villager in m.alive_bots():
			if u.is_upyr and u != ally:
				target = u
				break
	if target != null:
		m.train_add(ally, target, true)


## Днём двое жителей вписывают в список тех, кому больше всех верят.
func bots_list() -> void:
	if not m.train_on:
		return
	var n := 0
	for bot: Villager in _by_susp(m.alive_bots()):
		if n >= LIST_BOTS or m.train_list.size() >= m.train_cap():
			break
		var best: Villager = null
		for o: Villager in _others(bot):
			if o.is_player or not o.alive or m.on_train(o.id) or m.train_struck.has(o.id):
				continue
			if best == null or view(bot, o) < view(bot, best):
				best = o
		if best != null and m.train_add(bot, best):
			n += 1


## Игрок вычеркнул жителя из списка: тот это запомнит. Открывал игроку дверь — скажет об этом.
const W_STRUCK := 0.6


func on_struck(v: Villager) -> ChatLine:
	if v == null or not brains.has(v.id):
		return null
	brains[v.id].private_delta[0] = brains[v.id].private_delta.get(0, 0.0) + W_STRUCK
	var opened := m.world.last(WorldLog.Kind.ADMIT, v.id, 0) != null
	var l := ChatLine.say(v, L.t("st.struck_door" if opened else "st.struck", {"me": v}))
	l.emotion = "angry"
	return l


## Ответ игрока союзнику на перроне: выдать деревне или прикрыть.
func betrayal_answer(choice: String) -> void:
	var a := m.get_villager(ally_id)
	if a == null:
		return
	if choice == "expose":
		_bump(a.id, 1.2)
		for e: Dictionary in m.train_list:
			e.secret = false                     # подпись в списке теперь видят все
		var judge := _pick_bystander([a])
		if judge != null:
			scene_lines.append(_say(judge, "AGREE_ACCUSE", a))
	else:
		brains[a.id].private_delta[0] = brains[a.id].private_delta.get(0, 0.0) - 0.8
		var l := ChatLine.say(a, L.t("st.covered", {"me": a}))
		l.emotion = "relieved"
		scene_lines.append(l)


## Память акта I в первой главе акта II (TASK-025): кто дожил и пришёл, говорит одну строку о том,
## что игрок сделал. Если никого из них нет в главе, один присылает письмо.
func carry_lines() -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var mem := Campaign.act_one_memory(3)
	var absent: Array[Dictionary] = []
	for rec: Dictionary in mem:
		var v: Villager = null
		for b: Villager in m.alive_bots():
			if b.story_id == int(rec.who) and b.guest_id.is_empty():
				v = b
		if v == null:
			absent.append(rec)
			continue
		var l := ChatLine.say(v, L.t("carry." + String(rec.kind), {"me": v}))
		l.emotion = "sad" if String(rec.kind) in ["refused", "refused_died", "broken", "react_accuse", "react_revenge", "react_withdraw"] else "relieved"
		out.append(l)
		if out.size() >= 2:
			break
	if out.is_empty() and not absent.is_empty():
		var rec: Dictionary = absent[0]
		var who := Revelations._person(int(rec.who), m)
		out.append(ChatLine.system(L.t("carry.letter", {"who": who, "text": L.t("carry." + String(rec.kind), {"me": who})})))
	return out


## Хозяин отвечает на один вопрос в день. Ответ зависит от главы и от того, что игрок уже знает.
func npc_answer(topic: String, id: String = "") -> String:
	if id.is_empty():
		id = m.npc_id
	if int(m.npc_asked.get(id, 0)) == m.day:
		return ""
	m.npc_asked[id] = m.day
	if id == "keeper":
		return L.t("npc.keeper.a_%s_%s" % [topic, "list" if m.train_on else "early"]) if topic == "list" else L.t("npc.keeper.a_" + topic)
	if id != "miller":
		return act_three_answer(id, topic)
	var key := "npc.miller.a_" + topic
	if topic == "before" and (Campaign.miller_clues() + Campaign.miller_records(m).size()) >= Campaign.MILLER_KNOWN:
		key += "_known"                     # игрок уже видел книгу или мешок: мельник отвечает резче
	return L.t(key)


## После могилы (TASK-023): деревня винит гостей, в тетради — находка.
func grave_found(hunter_id: int) -> void:
	var hunter := m.get_villager(hunter_id)
	if hunter != null and hunter.alive:
		m.clues.add("find", hunter.id, L.t("sc.grave.knife", {"who": hunter}), {"mystery": "grave"})
	else:
		m.clues.add("find", -1, L.t("sc.grave.stranger"), {"mystery": "grave"})
	var guests: Array[Villager] = []
	for g: Villager in m.alive_bots():
		if not g.guest_id.is_empty():
			guests.append(g)
			_bump(g.id, W_GRAVE)
	var accuser: Villager = null
	for b: Villager in m.alive_bots():
		if b.guest_id.is_empty() and b.id != hunter_id:
			accuser = b
			break
	if accuser != null and not guests.is_empty():
		var l := ChatLine.say(accuser, L.t("sc.grave.blame", {"me": accuser, "who": guests[0]}))
		l.emotion = "angry"
		l.about = guests[0]
		scene_lines.append(l)


## Суд в крипте (TASK-029): оправдали — доверие растёт; осудили — игрока изгоняют, у акта своя концовка.
func trial_result(acquit: bool) -> void:
	m.world.add(WorldLog.Kind.CHOICE, m.day, 0, -1, -1, [0], true, {"scene": "a3c3_trial", "choice": "won" if acquit else "lost"})
	if acquit:
		m.trust_add(1, "trial")
		scene_lines.append(npc_line("anfisa", L.t("npc.anfisa.after_trial")))
	else:
		m.exile_player()


## Тайна мельника (TASK-022): рассказать беженцам или промолчать.
func miller_answer(choice: String) -> void:
	scene_lines.append(npc_line("miller", L.t("npc.miller.after_" + choice)))
	if choice == "tell":
		for b: Villager in m.alive_bots():
			brains[b.id].private_delta[0] = brains[b.id].private_delta.get(0, 0.0) - W_TELL


# =============================================================
# Улики (TASK-017): спросить при всех о противоречии
# =============================================================
## Игрок сравнил две записи и спрашивает жителя при всех. Человек объясняет, упырь чаще отпирается.
## Свой генератор: ответ не меняет ход партии.
func confront(a: Dictionary, b: Dictionary) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var t := m.get_villager(int(a.get("who", -1)))
	if t == null or t.is_player or not t.alive or not m.clues.contradiction(a, b):
		return out
	var key := Clues.pair_key(a, b)
	if m.clues.asked.has(key):
		return out
	m.clues.asked[key] = true
	m.trust_add(1, "confront")            # разобрался в противоречии при всех (TASK-030)
	var ar := RandomNumberGenerator.new()
	ar.seed = hash("confront:%s:%d" % [key, t.id])
	var admit := not t.is_upyr or ar.randf() < UPYR_FAKE_ADMIT
	_bump(t.id, W_CONFRONT + (0.0 if admit else W_DENY))
	var reply := ChatLine.say(t, L.fill(Phrases.pick("CLUE_ADMIT" if admit else "CLUE_DENY", ar, {"me": t}), {}))
	reply.emotion = "sad" if admit else "angry"
	out.append(reply)
	var judge := _pick_bystander([t])
	if judge != null and not admit:
		out.append(_say(judge, "AGREE_ACCUSE", t))
	m.world.add(WorldLog.Kind.ACCUSE, m.day, 0, t.id, -1, [], true, {"clue": key})
	return out


# =============================================================
# Туман (TASK-016): вопрос о том, что знаете только вы двое
# =============================================================
## Был ли у игрока днём разговор с этим жителем: выслушал историю или дал/получил слово.
func shared_memory(v: Villager) -> String:
	if v == null:
		return ""
	if m.world.last(WorldLog.Kind.LISTENED, 0, v.id) != null:
		return "story"
	for p: Dictionary in m.promises:
		if (int(p.by) == 0 and int(p.to) == v.id) or (int(p.to) == 0 and int(p.by) == v.id):
			return "promise"
	return ""


## Ответ голоса из тумана. Человек помнит разговор, упырь и Подражатель — нет: голос подделать можно, память нельзя.
func memory_answer(g: Villager, seat: Match.Seat) -> Dictionary:
	var who := g
	var creature := g.is_upyr or (seat != null and g == seat.mimic)
	var kind := shared_memory(who)
	if kind.is_empty():
		return {}
	if creature:
		var ar := RandomNumberGenerator.new()
		ar.seed = hash("mem:%d:%d" % [m.day, g.id])
		return {"text": L.fill(Phrases.pick("MEM_WRONG", ar, {"me": g}), {}), "ok": false}
	if kind == "story":
		var fact := SocialContent.story(who.story_id, who) if who.story_id >= 0 and who.guest_id.is_empty() else Guests.story(who)
		return {"text": L.t("door.mem_story", {"text": fact.get_slice(".", 0)}), "ok": true}
	return {"text": L.t("door.mem_promise", {"me": g}), "ok": true}


## Вопрос за жетон: стресс сбивает людей, а упырь иногда угадывает чужое воспоминание.
## Ответ даёт вероятностную зацепку и не подтверждает роль сам по себе.
func token_memory_answer(g: Villager, seat: Match.Seat) -> String:
	var kind := shared_memory(g)
	if kind.is_empty():
		return ""
	var correct := L.t("door.mem_promise", {"me": g})
	if kind == "story":
		var fact := SocialContent.story(g.story_id, g) if g.story_id >= 0 and g.guest_id.is_empty() else Guests.story(g)
		correct = L.t("door.mem_story", {"text": fact.get_slice(".", 0)})
	var ar := RandomNumberGenerator.new()
	ar.seed = hash("token-memory:%d:%d:%d" % [m.day, g.id, m.case_id])
	var creature := g.is_upyr or (seat != null and g == seat.mimic)
	var truth_chance := 0.45 if creature else 0.75
	if ar.randf() < truth_chance:
		return correct
	return L.fill(Phrases.pick("MEM_WRONG", ar, {"me": g}), {})


# =============================================================
# Прощание (TASK-020)
# =============================================================
## Игрок отправляет жителя на лодке за реку. Ответ зависит от того, как житель к игроку относится.
func farewell(v: Villager) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	if not m.send_away(v):
		return out
	var warm := view(v, m.player()) < 0.6
	var l := ChatLine.say(v, L.t("farewell.warm" if warm else "farewell.cold", {"me": v}))
	l.emotion = "relieved" if warm else "sad"
	out.append(l)
	return out


## «Имя на доске» (TASK-019): ответ игрока меняет отношение рассказчика и посёлка.
func board_answer(teller: Villager, choice: String) -> void:
	if teller != null and brains.has(teller.id):
		match choice:
			"confess":
				brains[teller.id].private_delta[0] = brains[teller.id].private_delta.get(0, 0.0) - 0.4
				_bump(0, 0.3)                     # посёлок насторожился: пришёл с той стороны
			"deny":
				brains[teller.id].private_delta[0] = brains[teller.id].private_delta.get(0, 0.0) + 0.3
	if teller != null:
		var l := ChatLine.say(teller, L.t("sc.board.r_" + choice, {"me": teller}))
		l.emotion = "sad"
		scene_lines.append(l)


## У реки игрок отозвался на зов с того берега, хотя перевозчица просила молчать (TASK-011).
## Она это запомнит: меньше доверия и упрёк днём.
func river_answered() -> void:
	for v: Villager in m.alive_bots():
		if v.story_id == 0 and v.guest_id.is_empty():
			brains[v.id].private_delta[0] = brains[v.id].private_delta.get(0, 0.0) + 0.4
			var l := ChatLine.say(v, L.t("sc.river.answered", {"me": v}))
			l.emotion = "suspicious"
			scene_lines.append(l)


## «Кто там?» у двери (TASK-013). Человек отвечает по делу: называет дом, куда собирался днём,
## или честно говорит, что передумал. Упырь — по делу лишь иногда, чаще уходит от ответа.
## Свой генератор: ответ не меняет ход партии.
func door_answer(g: Villager, seat: Match.Seat) -> String:
	var ar := RandomNumberGenerator.new()
	ar.seed = hash("ask:%d:%d:%d" % [m.day, g.id, m.case_id])
	var creature := g.is_upyr or (seat != null and g == seat.mimic)
	var plain := ar.randf() < (0.4 if creature else 0.85)
	if not plain:
		return L.t("door.ask_vague", {"me": g})
	if seat != null and g.announced_house == seat.house:
		return L.t("door.ask_true", {"me": g, "house": m.house_name(seat.house)})
	return L.t("door.ask_changed", {"me": g})


## Игрок обещает жителю (TASK-004). Житель отвечает своим характером и запоминает.
func player_promise(t: Villager, kind: String) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var me := m.player()
	if t == null or t.is_player or not t.alive or not m.promise(me, t, kind):
		return out
	var b: BotBrain = brains.get(t.id)
	m.wander_plan.erase(t.id)               # дали слово — к реке не пойдёт
	if b != null:
		b.private_delta[me.id] = b.private_delta.get(me.id, 0.0) - 0.2
		if kind == "open" and me.announced_house >= 0 and b.pact_house < 0 and not t.is_upyr:
			t.announced_house = me.announced_house     # раз обещали открыть, пойдёт к тебе
	var pr := RandomNumberGenerator.new()
	pr.seed = hash("promise-reply:%d:%d:%s" % [m.day, t.id, kind])
	var bank := "PROMISE_REPLY_" + kind.to_upper()
	var reply := ChatLine.say(t, L.fill(Phrases.pick(bank, pr, {"me": t, "house": m.house_name(maxi(0, me.announced_house))}), {}))
	reply.emotion = "relieved"
	out.append(reply)
	return out


## Утро: чем кончились вчерашние обещания. Нарушенное слово житель называет вслух, при всех:
## посёлок теперь знает, и доверия к обещавшему меньше. Сдержанное — короткое спасибо.
func _settle_promise_lines() -> void:
	var me := m.player()
	var pr := RandomNumberGenerator.new()
	for p: Dictionary in m.promises:
		if int(p.day) != m.day or String(p.state) == "" or String(p.state) == "void":
			continue
		var by := m.get_villager(int(p.by))
		var to := m.get_villager(int(p.to))
		if by == null or to == null:
			continue
		pr.seed = hash("promise-morning:%d:%d:%d" % [m.day, by.id, to.id])
		var ev := m.world.last(WorldLog.Kind.PROMISE_BROKEN if p.state == "broken" else WorldLog.Kind.PROMISE_KEPT, by.id, to.id, m.day)
		if by.is_player and to.alive and not to.is_player:
			var b: BotBrain = brains.get(to.id)
			var key := "PROMISE_%s_%s" % [String(p.state).to_upper(), String(p.kind).to_upper()]
			var line := ChatLine.say(to, L.fill(Phrases.pick(key, pr, {"me": to}), {}))
			if p.state == "broken":
				line.emotion = "angry"
				line.about = me
				if b != null:
					b.grudge[me.id] = b.grudge.get(me.id, 0.0) + 1.0
				_bump(me.id, W_PROMISE_BROKEN)
				if ev != null:
					ev.public = true             # сказано при всех
			else:
				line.emotion = "relieved"
				if b != null:
					b.private_delta[me.id] = b.private_delta.get(me.id, 0.0) - 0.6
			promise_lines.append(line)
		elif to.is_player and p.state == "broken" and not by.is_player:
			promise_lines.append(ChatLine.system(L.t("promise.bot_broke", {"who": by})))


## Утро после гибели близкого: горе вслух и, если погибшего не пустили, обвинение хозяину той двери.
## Обвинение настоящее: подозрение к виноватому растёт, даже если он человек.
func grief_lines() -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	for v: Villager in m.alive_bots():
		if v.grief_days <= 0 or v.grief_for < 0:
			continue
		var lost := m.get_villager(v.grief_for)
		if lost == null:
			continue
		var fresh_loss := v.grief_days == Match.GRIEF_DAYS
		if fresh_loss and v.reaction != "":
			out.append_array(_reaction_lines(v, lost))
			continue
		var g := _say(v, "GRIEF", null, {"lost": lost})
		g.emotion = "sad"
		out.append(g)
		var blamed := m.get_villager(v.blame_id)
		if fresh_loss and blamed != null and blamed.alive:
			var r := _say(v, "REVENGE", blamed, {"lost": lost})
			var via := m.get_villager(v.blame_via)
			if via != null:
				# откуда знает (TASK-003): видел сам или кто рассказал
				r.text += " " + L.t("know.saw" if via == v else "know.told", {"me": v, "who": via, "lost": lost})
			r.emotion = "angry"
			r.about = blamed
			out.append(r)
			_bump(blamed.id, W_REVENGE)
			if brains.has(v.id):
				brains[v.id].grudge[blamed.id] = brains[v.id].grudge.get(blamed.id, 0.0) + 1.0
	return out


func emotional_lines() -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	out.append_array(tie_lines())
	for v: Villager in m.alive_bots():
		var partner := m.get_villager(v.partner_id)
		if partner == null or (partner.alive and v.id > partner.id):
			continue
		var feeling := "happy"
		if not partner.alive and not partner.exiled:
			continue                  # гибель близкого — в grief_lines, своим голосом
		var kind := "first"
		if not partner.alive:
			feeling = "sad"
			kind = "exiled"
		elif m.day == 1:
			kind = "first"
		elif v.night_house >= 0 and v.night_house == partner.night_house:
			kind = "together"
		else:
			feeling = "sad"
			kind = "apart"
		var args := {"me": v, "other": partner, "name": partner.name}
		var line := ChatLine.say(v, L.fill(_couple_pick(kind), args))
		line.emotion = feeling
		out.append(line)
		if partner.alive and m.day == 1:
			var answer := ChatLine.say(partner, L.fill(_couple_pick("answer"), {"me": partner, "other": v, "name": v.name}))
			answer.emotion = "sad"
			out.append(answer)
		break
	return out


## Давние связи (TASK-007): в первые два дня один из связанных вспоминает о второй стороне вслух.
## Свой генератор: обычный ход партии не меняется.
func tie_lines() -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	if m.day > 2:
		return out
	for v: Villager in m.alive_bots():
		var o := m.get_villager(v.tie_id)
		if o == null or not o.alive or v.id > o.id:
			continue
		var tr := RandomNumberGenerator.new()
		tr.seed = hash("tie:%d:%d:%d" % [m.day, v.id, m.case_id])
		if tr.randf() < 0.5:
			continue
		var first := v if Match.TIES.any(func(t: Array) -> bool: return t[0] == v.story_id) else o
		var second := o if first == v else v
		var line := ChatLine.say(first, L.t("tie.%s_day" % first.tie_kind, {"me": first, "who": second}))
		line.emotion = "sad"
		out.append(line)
		break
	return out


## Реплики пары: несколько вариантов на случай, чтобы от партии к партии не повторялось одно и то же.
## {name} — имя второго, {other:…|…} — род второго, [а|б] — род говорящего.
const COUPLE_LINES := {
	"ru": {
		"first": [
			"Мы с {other.ins} собирались уехать после свадьбы. Теперь прошу только об одном: оставьте нам два места рядом.",
			"{name}, держись рядом. Если нас разведут по разным домам, я не усну.",
			"Мы с {other.ins} даже кольца не успели купить. Я [хотел|хотела] весной, когда сойдёт снег.",
			"Вчера {name} [смеялся|смеялась] над моими страхами. Сегодня не смеётся никто.",
			"Если ночью постучит {name}, я узнаю по стуку. Мы так договорились ещё летом.",
			"Я [обещал|обещала] матери {other.gen} привести {other:его|её} домой живым. Помогите мне сдержать слово.",
		],
		"answer": [
			"Я рядом, {name}. Только если ночью услышу твой голос, всё равно спрошу про нашу первую встречу.",
			"Никуда не денусь, {name}. Но дверь я открою, только если ответишь, где мы познакомились.",
			"Мы справимся, {name}. Только не выходи ночью, даже если позовут моим голосом.",
			"Я с тобой. Если что, наш знак тот же: два коротких, один длинный.",
		],
		"exiled": [
			"{name} {other:обещал|обещала} вернуться. Теперь я даже не знаю, куда нести тёплые вещи.",
			"Вы выгнали {other.acc} в лес. Если {other:он вернётся|она вернётся} ночью, я не знаю, открою ли.",
			"Я всё ещё ставлю две кружки. Привычка. {name} теперь где-то за деревьями.",
		],
		"together": [
			"Утром [проснулся|проснулась] раньше и [слушал|слушала], как ты дышишь, {name}. Так страшно ещё никогда не было.",
			"Мы с {other.ins} всю ночь держались за руки. Пальцы до сих пор не разжимаются.",
			"{name} шептал{other:|а} мне сказки, чтобы я не [слушал|слушала] стук. Помогло.",
		],
		"apart": [
			"{name}, я всю ночь [ждал|ждала] твоего стука. Понимаю, что ты {other:пошёл|пошла} в другой дом. Простить пока не получается.",
			"Ночью мы были в разных домах. Я каждый час [подходил|подходила] к окну, {name}.",
			"Больше не расходимся, {name}. Ещё одну такую ночь я не выдержу.",
		],
	},
	"en": {
		"first": [
			"We meant to leave after our wedding, {name} and I. Now I just want two places together.",
			"Stay close, {name}. If they split us between houses, I won't sleep.",
			"{name} and I didn't even get to buy rings. I wanted to in spring, when the snow melts.",
			"Yesterday {name} laughed at my fears. Today nobody is laughing.",
			"If {name} knocks tonight, I'll know the knock. We agreed on it last summer.",
		],
		"answer": [
			"I'm here, {name}. But if you knock tonight, I will still ask where we first met.",
			"I'm not going anywhere, {name}. But I'll only open if you tell me where we met.",
			"We'll manage, {name}. Just don't go out tonight, even if someone calls in my voice.",
		],
		"exiled": [
			"{name} promised to come back. Where do I take these warm clothes now?",
			"You sent {name} into the forest. If they come back tonight, I don't know if I'll open.",
			"I still set out two cups. Habit. {name} is somewhere beyond the trees now.",
		],
		"together": [
			"I woke first and listened to you breathing, {name}. I have never been so afraid.",
			"{name} and I held hands all night. My fingers still won't let go.",
		],
		"apart": [
			"I waited for your knock all night, {name}. I know why we were apart. It still hurts.",
			"We were in different houses last night. I went to the window every hour, {name}.",
			"No more splitting up, {name}. I can't take another night like that.",
		],
	},
}


func _couple_pick(kind: String) -> String:
	var bank: Dictionary = COUPLE_LINES.get(L.code, StoryLoc.get_v("couple") if StoryLoc.has("couple") else COUPLE_LINES["en"])
	var arr: Array = bank.get(kind, COUPLE_LINES["en"][kind])
	return String(arr[randi() % arr.size()])


func personal_talk(vid: int, choice: int) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var v := m.get_villager(vid)
	if v == null or v.is_player or not v.alive or not brains.has(vid) or v.personal_day == m.day or choice < 0 or choice > 1:
		return out
	v.personal_day = m.day
	v.story_step = mini(v.story_step + 1, 2)
	var page_key := "%s:%d" % [Progress.story_key(v), v.story_step]
	if not m.story_pages_found.has(page_key):
		m.story_pages_found.append(page_key)
	Save.remember_story(Progress.story_key(v), v.story_step)
	if choice == 0:
		m.world.add(WorldLog.Kind.LISTENED, m.day, m.player().id, v.id, -1, [m.player().id, v.id])
	m.feelings.on_talk(v.id, choice == 0)
	var stopped := choice == 0 and m.wander_plan.has(v.id)
	if stopped:
		m.wander_plan.erase(v.id)          # выслушал — остаётся ночевать с людьми
	var brain: BotBrain = brains[vid]
	brain.private_delta[0] = brain.private_delta.get(0, 0.0) + (-0.2 if choice == 0 else 0.25)
	if v.anchor_id >= 0:
		_remember_anchor_answer(v, 1 if choice == 0 else -1)
	out.append(ChatLine.say(m.player(), L.fill(SocialContent.narrative_ui("prompt"), {"who": v.name})))
	var confession := ChatLine.say(v, SocialContent.personal_chapter(v, v.story_step))
	confession.emotion = "sad"
	out.append(confession)
	out.append(ChatLine.say(m.player(), SocialContent.narrative_ui("listen" if choice == 0 else "doubt")))
	var reply := ChatLine.say(v, L.fill(SocialContent.narrative_ui("thanks" if choice == 0 else "hurt"), {"me": v}))
	reply.emotion = "relieved" if choice == 0 else "angry"
	out.append(reply)
	if stopped:
		var stay := ChatLine.say(v, L.fill(Phrases.pick("WANDER_STAY", rng, {"me": v}), {}))
		stay.emotion = "relieved"
		out.append(stay)
	return out


func player_question() -> ChatLine:
	var bots := m.alive_bots()
	if bots.is_empty() or not m.player().alive:
		return null
	var pool: Array[Villager] = []
	for bot: Villager in bots:
		if bot.id != last_questioner:
			pool.append(bot)
	if pool.is_empty():
		pool = bots
	var asker := pool[rng.randi_range(0, pool.size() - 1)]
	last_questioner = asker.id
	var topic := _question_topic()
	var line := ChatLine.say(asker, SocialContent.opening_question(asker.story_id, m.player().name, asker) if topic == "arrival"
		else SocialContent.question(topic, m.player().name, rng))
	line.asks_player = true
	line.question_kind = topic
	return line


func _question_topic() -> String:
	if m.day <= 1:
		return "arrival"
	var ev: Dictionary = evidence.get(m.player().id, {})
	var topics := PackedStringArray()
	if int(ev.get("street", 0)) > 0 or street_last_night.has(m.player().id):
		topics.append("night")
	if int(ev.get("liar", 0)) > 0 or liar_last_night.has(m.player().id):
		topics.append("alibi")
	if int(ev.get("fake", 0)) > 0:
		topics.append("work")
	if int(ev.get("sabotage", 0)) > 0:
		topics.append("sabotage")
	if int(ev.get("death", 0)) > 0:
		topics.append("death")
	if int(ev.get("tunnel", 0)) > 0:
		topics.append("tunnel")
	if topics.is_empty():
		topics.append("trust")
		topics.append("rumor")
	var previous := topics.find(last_question_topic)
	if topics.size() > 1 and previous >= 0:
		topics.remove_at(previous)
	var topic := String(topics[rng.randi_range(0, topics.size() - 1)])
	last_question_topic = topic
	return topic


func answer_player_question(asker: Villager, answer: String, answer_kind: int) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	if asker == null or asker.is_player or not brains.has(asker.id):
		return out
	var brain: BotBrain = brains[asker.id]
	var bond_before := asker.relationship
	match answer_kind:
		0:
			brain.private_delta[0] = brain.private_delta.get(0, 0.0) - 0.3
			_bump(m.player().id, -0.1)
			if asker.anchor_id == 0:
				_remember_anchor_answer(asker, 1)
		1:
			brain.private_delta[0] = brain.private_delta.get(0, 0.0) - 0.05
		2:
			brain.private_delta[0] = brain.private_delta.get(0, 0.0) + 0.35
			_bump(m.player().id, 0.25)
			if asker.anchor_id == 1:
				_remember_anchor_answer(asker, 1)
		_:
			if answer.strip_edges().length() >= 18:
				brain.private_delta[0] = brain.private_delta.get(0, 0.0) - 0.15
				if asker.anchor_id == 2:
					_remember_anchor_answer(asker, 1)
	if answer_kind == 1 and asker.anchor_id == 2:
		_remember_anchor_answer(asker, 1)
	out.append(ChatLine.say(asker, SocialContent.question_reaction(answer_kind, asker.story_id, rng, asker)))
	if asker.anchor_id >= 0:
		if bond_before < 1 and asker.relationship >= 1:
			out.append(ChatLine.say(asker, SocialContent.anchor_chapter(asker.anchor_id, 0, asker)))
		elif bond_before < 3 and asker.relationship >= 3:
			out.append(ChatLine.say(asker, SocialContent.anchor_chapter(asker.anchor_id, 1, asker)))
	return out


func _remember_anchor_answer(asker: Villager, delta: int) -> void:
	if asker.anchor_id < 0:
		return
	asker.relationship = Save.change_anchor_bond(asker.anchor_id, delta)


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
			out.append(_say(t, "REPLY_TO_ACCUSED_UPYR" if t.is_upyr else "REPLY_TO_ACCUSED_HUMAN", deflect))
			var judge := _pick_bystander([t])
			if judge != null:
				var doubts := m.feelings.get_f(judge.id, Feelings.F.SUSPICION) >= 0.5 and view(judge, p) > 0.8
				out.append(_say(judge, "AGREE_ACCUSE" if view(judge, t) >= 1.0 and not doubts else "DISAGREE_ACCUSE", t))

		IntentParser.Kind.INVITE:
			var t := intent.target
			var h := intent.house if intent.house >= 0 else (t.announced_house if t.announced_house >= 0 else 0)
			if accepts_invite(t):
				var b: BotBrain = brains[t.id]
				b.pact_id = p.id
				b.pact_house = h
				t.announced_house = h
				p.announced_house = h
				out.append(_say(t, "INVITE_YES", null, {"house": m.house_name(h)}))
			else:
				out.append(_say(t, "INVITE_NO"))

		IntentParser.Kind.ASK:
			var t := intent.target
			if t.announced_house >= 0:
				out.append(_say(t, "ASK_ANSWER_HUMAN", null, {"house": m.house_name(t.announced_house)}))
			else:
				out.append(_say(t, "ASK_ANSWER_UNSURE"))

		IntentParser.Kind.DEFEND:
			if susp(p.id) > 0.0:
				_bump(p.id, -0.3)
			var who := _pick_bystander([])
			if who != null:
				out.append(_say(who, "PLAYER_DEFEND_REACTION"))

		_:
			var who := _pick_bystander([])
			if who != null:
				out.append(_say(who, "GENERIC_REACTION"))
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
		var hunt := _claimed_elder(bot) if bot.is_upyr and not bot.fed else null
		if b.pact_house >= 0:
			h = b.pact_house
		elif hunt != null and hunt.announced_house >= 0 and rng.randf() < ELDER_HUNT_P:
			h = hunt.announced_house   # старожил раскрылся — упырь идёт за ним
		elif bot.is_upyr and not bot.fed and rng.randf() < 0.3:
			h = rng.randi_range(0, m.houses.size() - 1)   # передумал — оставит след во лжи
		out[bot.id] = m.dry_house(h)
	return out


## Бег до дома по колоколу. Каждый бот замечает звон не сразу (реакция) и бежит
## со своей скоростью. dist(vid, house) — путь до двери в единицах посёлка.
## Ответ: {"react": {vid: секунды}, "arrive": {vid: секунды}} от первого удара колокола.
func plan_run(choices: Dictionary[int, int], dist: Callable) -> Dictionary:
	var react: Dictionary[int, float] = {}
	var arrive: Dictionary[int, float] = {}
	for vid: int in choices:
		var rr := RUN_REACT_FAST if rng.randf() < RUN_FAST_P else RUN_REACT
		var r := rng.randf_range(rr.x, rr.y)
		react[vid] = r
		arrive[vid] = r + float(dist.call(vid, choices[vid])) / (RUN_SPEED * rng.randf_range(0.9, 1.1))
	return {"react": react, "arrive": arrive}


## Подражатель говорит голосом жителя — с повторами, будто заучил слова.
func mimic_plea(voice: Villager) -> String:
	return Phrases.pick("MIMIC_PLEAS", rng, {"who": voice, "me": voice})


func plea_for(bot: Villager) -> String:
	var b: BotBrain = brains[bot.id]
	var g := {"me": bot}
	if b.pact_id == m.player().id:
		return Phrases.pick("PLEA_PACT", rng, g)
	if street_last_night.has(bot.id):
		return Phrases.pick("PLEA_AFTER_STREET", rng, g)
	if susp(bot.id) > 2.0:
		return Phrases.pick("PLEA_SUSPECT", rng, g)
	# половодье (TASK-024): кто ночевал бы в залитом доме, просится и говорит о воде
	if m.flooded_house >= 0:
		var fr := RandomNumberGenerator.new()
		fr.seed = hash("flood:%d:%d" % [m.day, bot.id])
		if fr.randf() < 0.6:
			return Phrases.pick("PLEA_FLOOD", fr, {"me": bot, "house": m.house_name(m.flooded_house)})
	# туман, ливень, полная луна: человек у двери говорит о том, что творится снаружи
	# свой генератор: общий ход партии (и баланс) от этих реплик не меняется
	if m.night_event != Match.Event.NONE and m.night_event != Match.Event.QUIET:
		var pr := RandomNumberGenerator.new()
		pr.seed = hash("plea:%d:%d:%d" % [m.day, bot.id, m.villagers.size()])
		if pr.randf() < 0.45:
			return Phrases.pick("PLEA_" + String(Match.EVENT_KEY[m.night_event]).to_upper(), pr, g)
	return L.fill(_pick_line(bot, "PLEA_NORMAL"), g)     # свой голос и у двери


## Бот-хозяин двери решает, кого впустить. player_plea — id мольбы игрока, если он в очереди.
func host_decide(seat: Match.Seat, player_plea: String = "") -> Array[int]:
	var host := seat.host
	var b: BotBrain = brains[host.id]
	var scored: Array = []
	for g: Villager in seat.queue:
		var s := -view(host, g)
		if b.pact_id == g.id:
			s += 3.0
		s += _feeling_door(host, g)
		if not m.promises_today(host.id, g.id).filter(func(p: Dictionary) -> bool: return p.kind == "open").is_empty():
			var keep := not host.is_upyr
			if host.is_upyr:
				var pk := RandomNumberGenerator.new()
				pk.seed = hash("promise-keep:%d:%d:%d" % [m.day, host.id, g.id])
				keep = pk.randf() < PROMISE_UPYR_KEEP
			if keep:
				s += PROMISE_HOST
		if g.is_player:
			s += _plea_weight(host, player_plea)
			if m.owes_player.get(host.id, false):
				s += 4.0                    # ты впустил его, когда он тебе не открыл: теперь он откроет
			if not host.is_upyr:
				s += 0.35 * give()          # при поддавках хозяин-человек охотнее верит игроку
		else:
			s += rng.randf_range(0.0, door_noise(host))
		if host.is_upyr:
			s += b.grudge.get(g.id, 0.0) * 0.5   # упырю обиды безразличны
		scored.append([s, g.id])
	scored.sort_custom(func(a: Array, c: Array) -> bool: return a[0] > c[0])

	var out: Array[int] = []
	var cap := m.config.capacity - 1
	if not scored.is_empty():
		if not host.is_upyr and float(scored[0][0]) < -2.8 and rng.randf() < 0.6:
			return out   # всем не верит — рискнёт остаться один
		for i in range(mini(cap, scored.size())):
			out.append(int(scored[i][1]))
	# голос за дверью, а места ещё есть: погибшего узнают, про ночующего в другом доме — сомневаются
	if seat.mimic != null and out.size() < cap:
		var voice := seat.mimic
		var p := MIMIC_TRUST
		if not voice.alive:
			p = MIMIC_TRUST_DEAD
		elif voice.announced_house >= 0 and voice.announced_house != seat.house:
			p = MIMIC_TRUST_ELSEWHERE
		if rng.randf() < p:
			out.append(voice.id)
	return out


## Чувства хозяина у двери (TASK-008): на обидчика злится и не пускает, перед тем, кому отказал, виноват
## и пускает, со страху открывает только своим. Упырь чувства только изображает: решает по-своему.
func _feeling_door(host: Villager, g: Villager) -> float:
	if host.is_upyr:
		return 0.0
	var f := m.feelings
	var s := 0.0
	if int(f.rage_at.get(host.id, -1)) == g.id:
		s -= 3.0 * f.get_f(host.id, Feelings.F.RAGE)
	if int(f.guilt_for.get(host.id, -1)) == g.id:
		s += 3.0 * f.get_f(host.id, Feelings.F.GUILT)
	var fear := f.get_f(host.id, Feelings.F.FEAR)
	var own := g.id == host.partner_id or g.id == host.family_id or g.id == host.tie_id or brains[host.id].pact_id == g.id
	if fear >= 0.6 and not own:
		s -= 1.5 * fear
	return s


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


## Жест игрока жителю t: подозрения посёлка, личное отношение t к игроку и ответ вслух.
## Показал пальцем — один из соседей, кто тоже подозревает t, поддерживает; кто верит t — заступается.
func gesture(kind: String, t: Villager) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var me := m.player()
	var key := "%s:%d:%d" % [kind, t.id, m.day]
	var fresh := not gestured.has(key)
	gestured[key] = true
	var b: BotBrain = brains.get(t.id)
	match kind:
		"point":
			if fresh:
				_bump(t.id, GEST_POINT)
				if b != null:
					b.grudge[me.id] = b.grudge.get(me.id, 0.0) + 0.5
			out.append(_say(t, "GEST_POINTED"))
			var others: Array[Villager] = []
			for o: Villager in m.alive_bots():
				if o != t:
					others.append(o)
			var side: Villager = others[rng.randi_range(0, others.size() - 1)] if not others.is_empty() else null
			if side != null and rng.randf() < 0.6:
				out.append(_say(side, "AGREE_ACCUSE" if view(side, t) >= 1.0 else "DISAGREE_ACCUSE", t))
		"trust":
			if fresh and b != null:
				b.private_delta[me.id] = b.private_delta.get(me.id, 0.0) - GEST_TRUST
			out.append(_say(t, "GEST_TRUSTED"))
		"distrust":
			if fresh:
				_bump(t.id, GEST_DISTRUST)
				if b != null:
					b.grudge[me.id] = b.grudge.get(me.id, 0.0) + 0.3
			out.append(_say(t, "GEST_DISTRUSTED"))
	return out


func after_door(seats: Array[Match.Seat]) -> void:
	for s: Match.Seat in seats:
		# кого игрок впустил, тот ему благодарен (TASK-013): союзник с первой же ночи
		if s.host.is_player:
			for v: Villager in s.admitted:
				if brains.has(v.id):
					brains[v.id].private_delta[0] = brains[v.id].private_delta.get(0, 0.0) - 0.3
					m.feelings.add(v.id, Feelings.F.TRUST, 0.25)
		for v: Villager in s.turned_away():
			if brains.has(v.id):
				brains[v.id].remember_refusal(s.host)
	# знахарка берёт травы, если ночует не одна
	var healer := m.role_holder(Match.Role.HEALER)
	if healer != null and not healer.is_player and healer.alive and not healer.role_used:
		for s: Match.Seat in seats:
			if s.inside().has(healer) and s.inside().size() >= 2 and rng.randf() < HEAL_P:
				m.heal_tonight(healer)


## Поручитель того, кто ночью убивал, теперь под подозрением (TASK-026).
const W_VOUCHED_KILLER := 0.6


func read_report(r: NightReport) -> void:
	for e: NightReport.Entry in r.entries:
		if e.kind == NightReport.Kind.KILLED_INSIDE and e.killer != null:
			var by := m.voucher_of(e.killer.id)
			if by > 0 and m.get_villager(by) != null and m.get_villager(by).alive:
				_bump(by, W_VOUCHED_KILLER)
	# тайна гостя раскрылась этим утром: посёлок по-новому смотрит на него
	for v: Villager in m.alive_bots():
		if not v.guest_id.is_empty() and m.day == Guests.REVEAL_DAY:
			_bump(v.id, Guests.W_REVEAL_UPYR if v.is_upyr else Guests.W_REVEAL_HUMAN)
	street_last_night.clear()
	liar_last_night.clear()
	for e: NightReport.Entry in r.entries:
		match e.kind:
			NightReport.Kind.SURVIVED_STREET:
				_bump(e.who.id, W_STREET)
				street_last_night[e.who.id] = true
				_note_evidence(e.who.id, "street")
			NightReport.Kind.SURVIVED_ALONE:
				if e.cause == "boat_back":
					_bump(e.who.id, W_BOAT_BACK)        # лодка вернулась пустой: странно, но не доказательство
				elif e.cause != "boat":
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
			NightReport.Kind.SAVED:
				# напал упырь — значит, он среди тех, кто был в доме (кроме жертвы и знахарки)
				if e.cause == "upyr":
					for st: Match.Seat in m.seats:
						if st.house != e.house:
							continue
						for o: Villager in st.inside():
							if o != e.who and not e.others.has(o):
								_bump(o.id, W_DEATH_ROOM)
								_note_evidence(o.id, "death")
				for hlr: Villager in e.others:
					_bump(hlr.id, -W_CLEAN * 2.0)
			NightReport.Kind.TUNNEL:
				_bump(e.who.id, W_TUNNEL)
				_note_evidence(e.who.id, "tunnel")
			NightReport.Kind.LIAR:
				_bump(e.who.id, W_LIAR)
				liar_last_night[e.who.id] = e.said_house
				_note_evidence(e.who.id, "liar")
	for b: BotBrain in brains.values():
		b.clear_pact()
	_settle_promise_lines()
	_decide_reactions()


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
			var felt := _feeling_vote(bot, pool)
			if felt != null:
				target = felt
		out[bot.id] = target.id
	return out


# =============================================================
# Реакция на трагедию (TASK-010)
# =============================================================
## Как близкий принимает гибель того, кому игрок не открыл. По таблице, не наугад:
##   не знает об отказе                                 → замыкается (withdraw)
##   знает, но мест не было или погибший казался упырём  → защищает игрока (defend), если не враждует с ним
##   знает, места были, игрок ему враг                   → тихо мстит до конца кампании (revenge)
##   знает, места были, горячий нрав или не друг игроку  → обвиняет при всех (accuse)
##   знает, места были, но игроку верит                  → замыкается (withdraw)
func decide_reaction(kin: Villager, lost: Villager, refusal: WorldLog.Event) -> String:
	var src := m.world.source(kin.id, refusal)
	if src.is_empty():
		return "withdraw"
	var rel := -view(kin, m.player())                 # больше нуля — относится к игроку хорошо
	var full := bool(refusal.info.get("full", false))
	var feared := susp(lost.id) >= 1.2 and view(kin, lost) >= 0.5
	if full or feared:
		return "defend" if rel >= -0.5 else "withdraw"
	if rel <= -0.6:
		return "revenge"
	if kin.persona in [Voices.Persona.GRUFF, Voices.Persona.YOUNG, Voices.Persona.PANIC] or rel < 0.3:
		return "accuse"
	return "withdraw"


func _decide_reactions() -> void:
	for kin: Villager in m.alive_bots():
		kin.reaction = ""
		if kin.grief_days != Match.GRIEF_DAYS or kin.grief_for < 0:
			continue
		var lost := m.get_villager(kin.grief_for)
		var refusal := m.world.last(WorldLog.Kind.REFUSE, m.player().id, kin.grief_for, m.day)
		if lost == null or refusal == null:
			continue
		var kind := decide_reaction(kin, lost, refusal)
		kin.reaction = kind
		m.world.add(WorldLog.Kind.REACTION, m.day, kin.id, m.player().id, -1, [kin.id], kind != "revenge",
			{"reaction": kind, "lost": lost.id})
		var f := m.feelings
		match kind:
			"accuse":
				f.add(kin.id, Feelings.F.RAGE, 0.6)
				f.rage_at[kin.id] = m.player().id
			"revenge":
				f.set_f(kin.id, Feelings.F.RAGE, 0.85)
				f.rage_at[kin.id] = m.player().id
				brains[kin.id].grudge[0] = brains[kin.id].grudge.get(0, 0.0) + 2.0
			"defend":
				f.add(kin.id, Feelings.F.TRUST, 0.2)


## Утро после утраты: реплика реакции. Обвинение и защита — при всех и с вопросом к игроку.
func _reaction_lines(v: Villager, lost: Villager) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	var text := GriefReactions.line(v, lost, v.reaction)
	if text.is_empty():
		var g := _say(v, "GRIEF", null, {"lost": lost})      # месть молчит: на людях только горе
		g.emotion = "sad"
		out.append(g)
		return out
	var line := ChatLine.say(v, text)
	match v.reaction:
		"accuse":
			line.emotion = "angry"
			line.about = m.player()
			_bump(0, W_REVENGE)
			brains[v.id].grudge[0] = brains[v.id].grudge.get(0, 0.0) + 1.0
		"defend":
			line.emotion = "sad"
			_bump(0, -0.3)
		_:
			line.emotion = "sad"
	if m.world.knows(v.id, m.world.last(WorldLog.Kind.REFUSE, 0, lost.id, m.day)):
		line.asks_player = true
		line.question_kind = "grief"
	out.append(line)
	return out


## Ответ игрока на реакцию: 0 — оправдаться, 1 — извиниться, 2 — промолчать.
func answer_grief(asker: Villager, answer_kind: int) -> Array[ChatLine]:
	var out: Array[ChatLine] = []
	if asker == null or asker.is_player or not brains.has(asker.id):
		return out
	var f := m.feelings
	var lost := m.get_villager(asker.grief_for)
	var refusal := m.world.last(WorldLog.Kind.REFUSE, 0, asker.grief_for) if lost != null else null
	var full := refusal != null and bool(refusal.info.get("full", false))
	var result := "same"
	match answer_kind:
		0:
			if asker.reaction == "accuse":
				result = "calm" if full else "harder"
			elif asker.reaction == "defend":
				result = "calm"
		1:
			result = "calm"
		_:
			if asker.reaction == "accuse" and -view(asker, m.player()) < 0.0:
				asker.reaction = "revenge"           # промолчал — обида уходит внутрь
				f.rage_at[asker.id] = 0
				brains[asker.id].grudge[0] = brains[asker.id].grudge.get(0, 0.0) + 1.0
	match result:
		"calm":
			f.add(asker.id, Feelings.F.RAGE, -0.4)
			f.add(asker.id, Feelings.F.TRUST, 0.2)
			brains[asker.id].grudge[0] = maxf(0.0, brains[asker.id].grudge.get(0, 0.0) - 1.0)
			if asker.reaction == "accuse" and answer_kind == 1:
				asker.reaction = "withdraw"
		"harder":
			f.add(asker.id, Feelings.F.RAGE, 0.2)
	var reply := ChatLine.say(asker, L.t("react." + result, {"me": asker, "lost": lost if lost != null else asker}))
	reply.emotion = "sad" if result != "harder" else "angry"
	out.append(reply)
	var ev := m.world.last(WorldLog.Kind.REACTION, asker.id, 0)
	if ev != null:
		ev.info["reaction"] = asker.reaction
		ev.info["answer"] = answer_kind
	return out


# =============================================================
# Кампания: что жители помнят из прошлых глав (TASK-007, TASK-010)
# =============================================================
## Доверие между жителями и к игроку из прошлых глав и непрощённые обиды.
## bonds: «a>b» -> -3..3 (номера историй, p — игрок); grudges: номера тех, кто ещё мстит.
func apply_campaign(bonds: Dictionary, grudges: Array, defenders: Array) -> void:
	for v: Villager in m.alive_bots():
		if not brains.has(v.id) or v.story_id < 0 or not v.guest_id.is_empty():
			continue
		var b: BotBrain = brains[v.id]
		var to_player := int(bonds.get("%d>p" % v.story_id, 0))
		b.private_delta[0] = b.private_delta.get(0, 0.0) - 0.3 * to_player
		for o: Villager in m.alive_bots():
			if o != v and o.story_id >= 0 and o.guest_id.is_empty():
				var k := int(bonds.get("%d>%d" % [v.story_id, o.story_id], 0))
				if k != 0:
					b.private_delta[o.id] = b.private_delta.get(o.id, 0.0) - 0.3 * k
		if grudges.has(v.story_id):
			b.grudge[0] = b.grudge.get(0, 0.0) + 1.5
			m.feelings.add(v.id, Feelings.F.RAGE, 0.5)
			m.feelings.rage_at[v.id] = 0
			var cold := ChatLine.say(v, L.t("react.grudge", {"me": v}))
			cold.emotion = "angry"
			pending_lines.append(cold)
		elif defenders.has(v.story_id):
			m.feelings.add(v.id, Feelings.F.TRUST, 0.3)


## Конец главы: как жители относятся друг к другу и к игроку (−3..3) — в память кампании.
func campaign_bonds() -> Dictionary:
	var out := {}
	for v: Villager in m.villagers:
		if v.is_player or v.story_id < 0 or not v.guest_id.is_empty() or not brains.has(v.id):
			continue
		var b: BotBrain = brains[v.id]
		var to_p := clampi(roundi(-(b.private_delta.get(0, 0.0) + b.grudge.get(0, 0.0) * 0.5) / 0.3), -3, 3)
		if to_p != 0:
			out["%d>p" % v.story_id] = to_p
		for o: Villager in m.villagers:
			if o == v or o.is_player or o.story_id < 0 or not o.guest_id.is_empty():
				continue
			var k := clampi(roundi(-(b.private_delta.get(o.id, 0.0) + b.grudge.get(o.id, 0.0) * 0.5) / 0.3), -3, 3)
			if k != 0:
				out["%d>%d" % [v.story_id, o.story_id]] = k
	return out


## Голос по чувствам (TASK-008): сильная ярость — против обидчика; надежда и доверие к игроку —
## за того, кого игрок обвинил сегодня. null — голосует как обычно.
func _feeling_vote(bot: Villager, pool: Array[Villager]) -> Villager:
	var f := m.feelings
	var foe := m.get_villager(int(f.rage_at.get(bot.id, -1)))
	if foe != null and foe.alive and pool.has(foe) and f.get_f(bot.id, Feelings.F.RAGE) >= 0.5:
		return foe
	if f.get_f(bot.id, Feelings.F.TRUST) >= 0.5 and f.get_f(bot.id, Feelings.F.HOPE) >= 0.4 and view(bot, m.player()) < 1.0:
		var acc := m.world.last(WorldLog.Kind.ACCUSE, 0, -1, m.day)
		var t := m.get_villager(acc.target) if acc != null else null
		if t != null and t.alive and pool.has(t) and view(bot, t) > -0.5:
			return t
	return null


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
