class_name WorldLog
extends RefCounted
## Журнал событий партии (TASK-001): кто, кому, в какой день, что сделал и кто это знает.
## Пишется рядом со старыми списками Match (history, vote_log, player_admits, dilemmas), их не заменяет.
## Чистая логика без экранов и без случайности: ход партии от журнала не меняется.
##
## Знание (TASK-003). У каждого события свой круг знающих: публичное знают все живые,
## остальное — свидетели и те, кому свидетели рассказали. Для каждого знающего хранится,
## откуда он знает: видел сам или кто рассказал. Реакции называют этот источник.

enum Kind { ADMIT, REFUSE, ACCUSE, VOTE, PROMISE, PROMISE_KEPT, PROMISE_BROKEN, DIED, EXILED, DILEMMA, LISTENED,
	REACTION, CHOICE }
const KEYS: PackedStringArray = ["admit", "refuse", "accuse", "vote", "promise", "promise_kept", "promise_broken",
	"died", "exiled", "dilemma", "listened",
	"reaction", "choice"]
## Виды, которые бывают в обычной партии без сюжета: их проверяет --sim. Реакции и выбор в сценах — только в кампании.
const MATCH_KINDS := 11

const SAW := "saw"        ## был рядом и видел или слышал сам
const TOLD := "told"      ## рассказал другой житель (via)
const PUBLIC := "public"  ## было при всех: сбор, голосование, утренний итог


class Event:
	var kind: int = 0
	var day: int = 0
	var actor: int = -1        ## кто сделал: хозяин двери, обвинитель, голосующий, обещавший
	var target: int = -1       ## с кем: стучавший, обвинённый, погибший
	var house: int = -1
	var public: bool = false
	var info: Dictionary = {}  ## подробности вида: mimic, cause, kind дилеммы, promise
	var known: Dictionary = {} ## id жителя -> [как узнал, от кого (id)]


var events: Array[Event] = []


func clear() -> void:
	events.clear()


## Записать событие. witnesses — кто видел сам. public — знают все.
func add(kind: Kind, day: int, actor: int, target: int, house: int = -1, witnesses: Array = [],
		public: bool = false, info: Dictionary = {}) -> Event:
	var e := Event.new()
	e.kind = kind
	e.day = day
	e.actor = actor
	e.target = target
	e.house = house
	e.public = public
	e.info = info
	for w: Variant in witnesses:
		var wid := int(w)
		if wid >= 0 and not e.known.has(wid):
			e.known[wid] = [SAW, wid]
	events.append(e)
	return e


## Знает ли житель vid о событии.
## Решение у двери переиграли: убрать записи этой двери за день.
func drop_door(day: int, house: int) -> void:
	for i in range(events.size() - 1, -1, -1):
		var e := events[i]
		if e.day == day and e.house == house and (e.kind == Kind.ADMIT or e.kind == Kind.REFUSE):
			events.remove_at(i)


func knows(vid: int, e: Event) -> bool:
	return e != null and (e.public or e.known.has(vid))


## Откуда житель знает: {"how": saw/told/public, "via": id}. Пусто — не знает.
func source(vid: int, e: Event) -> Dictionary:
	if e == null:
		return {}
	if e.known.has(vid):
		var k: Array = e.known[vid]
		return {"how": String(k[0]), "via": int(k[1])}
	if e.public:
		return {"how": PUBLIC, "via": -1}
	return {}


## via рассказал vid. Кто уже знает, тот знает по-прежнему: первый источник остаётся.
func tell(e: Event, vid: int, via: int) -> bool:
	if e == null or vid < 0 or knows(vid, e) or not knows(via, e):
		return false
	e.known[vid] = [TOLD, via]
	return true


func of(kind: Kind, day: int = -1) -> Array[Event]:
	var out: Array[Event] = []
	for e: Event in events:
		if e.kind == kind and (day < 0 or e.day == day):
			out.append(e)
	return out


func count(kind: Kind) -> int:
	var n := 0
	for e: Event in events:
		if e.kind == kind:
			n += 1
	return n


## Последнее событие вида между actor и target (-1 — любой).
func last(kind: Kind, actor: int = -1, target: int = -1, day: int = -1) -> Event:
	for i in range(events.size() - 1, -1, -1):
		var e := events[i]
		if e.kind == kind and (actor < 0 or e.actor == actor) and (target < 0 or e.target == target) \
				and (day < 0 or e.day == day):
			return e
	return null


## Что из партии важно для кампании (TASK-002): поступки игрока по отношению к жителям
## и их последствия. Ответ — записи с номерами жителей (story_id), без имён.
## Не больше limit записей; важные виды идут первыми.
func campaign_records(m: Match, limit: int = 40) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var me := 0
	var died_after_refusal: Dictionary = {}
	for e: Event in events:
		if e.kind == Kind.DIED and int(e.info.get("refused_by", -1)) == me:
			died_after_refusal[e.target] = true
	for e: Event in events:
		var rec := {}
		match e.kind:
			Kind.REFUSE:
				if e.actor == me:
					rec = {"kind": "refused", "who": e.target}
					if died_after_refusal.has(e.target):
						rec.kind = "refused_died"
				elif e.target == me:
					rec = {"kind": "refused_you", "who": e.actor}
			Kind.ADMIT:
				if e.actor == me and not bool(e.info.get("mimic", false)):
					rec = {"kind": "admitted", "who": e.target}
			Kind.PROMISE_KEPT:
				if e.actor == me:
					rec = {"kind": "kept", "who": e.target}
			Kind.PROMISE_BROKEN:
				if e.actor == me:
					rec = {"kind": "broken", "who": e.target}
				elif e.target == me:
					rec = {"kind": "broke_you", "who": e.actor}
			Kind.LISTENED:
				if e.actor == me:
					rec = {"kind": "listened", "who": e.target}
			Kind.CHOICE:
				# выбор в сюжетной сцене (TASK-019): помнится без привязки к жителю
				if String(e.info.get("scene", "")) == "a1c3_board":
					out.append({"kind": "board_" + String(e.info.get("choice", "silent")), "who": -1, "day": e.day, "knew": []})
				elif String(e.info.get("scene", "")) == "a2c3_miller":     # тайна мельника (TASK-022)
					out.append({"kind": "miller_" + String(e.info.get("choice", "keep")), "who": -1, "day": e.day, "knew": []})
				elif String(e.info.get("scene", "")) == "a4c3_betray":     # союзник на перроне (TASK-034)
					out.append({"kind": "betray_" + String(e.info.get("choice", "cover")), "who": -1, "day": e.day, "knew": []})
				elif String(e.info.get("scene", "")) == "a3c3_trial":      # суд в крипте (TASK-029)
					out.append({"kind": "trial_" + String(e.info.get("choice", "won")), "who": -1, "day": e.day, "knew": []})
				continue
			Kind.REACTION:
				# реакция близкого на гибель у двери игрока (TASK-010): помнится до конца кампании
				if e.target == me:
					rec = {"kind": "react_" + String(e.info.get("reaction", "withdraw")), "who": e.actor}
			Kind.VOTE:
				if e.actor == me:
					var t := m.get_villager(e.target)
					if t != null and t.exiled and t.exiled_day == e.day:
						rec = {"kind": "exiled_by_you", "who": e.target}
		if rec.is_empty():
			continue
		var v := m.get_villager(int(rec.who))
		if v == null or v.is_player or v.story_id < 0 or not v.guest_id.is_empty():
			continue
		rec["who"] = v.story_id
		rec["day"] = e.day
		# кто из жителей знает: тоже номерами историй
		var knew := PackedInt32Array()
		for kid: Variant in e.known:
			var kv := m.get_villager(int(kid))
			if kv != null and not kv.is_player and kv.story_id >= 0 and kv.guest_id.is_empty():
				knew.append(kv.story_id)
		rec["knew"] = knew
		out.append(rec)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return RANK.find(String(a.kind)) < RANK.find(String(b.kind)) if a.kind != b.kind else int(a.day) < int(b.day))
	return out.slice(0, limit)


## Порядок важности записей памяти кампании: при переполнении отрезается конец.
const RANK: PackedStringArray = ["react_revenge", "react_accuse", "react_defend", "react_withdraw", "refused_died",
	"broken", "exiled_by_you", "broke_you", "refused", "refused_you", "kept", "admitted", "listened"]
