class_name Feelings
extends RefCounted
## Чувства жителей (TASK-006). Девять состояний с силой 0..1, каждое утро затухают со своей скоростью.
## Источник — события ночи и журнал партии (WorldLog), характер жителя задаёт наклонность.
## Без случайности: от чувств ход партии меняется только через решения ботов (TASK-008).
##
## Каждое состояние что-то меняет:
##   страх — у двери пускает только своих; отчаяние — может уйти ночью на голос к реке;
##   ярость — голосует против обидчика и не пускает его; вина — пускает того, кому раньше отказал;
##   горе — не работает, стоит в стороне; истощение — работает медленнее;
##   надежда и доверие — поддерживают обвинение игрока; подозрение — реже соглашается с игроком.

enum F { FEAR, HOPE, GRIEF, RAGE, DESPAIR, GUILT, SUSPICION, TRUST, EXHAUSTION }
const KEYS: PackedStringArray = ["fear", "hope", "grief", "rage", "despair", "guilt", "suspicion", "trust", "exhaustion"]
## Сколько остаётся к следующему утру (умножается раз в сутки).
const KEEP: PackedFloat32Array = [0.55, 0.75, 0.72, 0.6, 0.7, 0.8, 0.75, 0.9, 0.45]
const SHOW_FROM := 0.45          ## с какой силы состояние видно на поле и в карточке

var m: Match
var level: Dictionary = {}        ## id -> PackedFloat32Array(9)
var rage_at: Dictionary = {}      ## id -> на кого злится
var guilt_for: Dictionary = {}    ## id -> перед кем виноват (кому не открыл)
var nights_awake: Dictionary = {} ## id -> сколько ночей подряд не спал (улица, гибель рядом)


func attach(match_ref: Match) -> void:
	m = match_ref
	level.clear()
	rage_at.clear()
	guilt_for.clear()
	nights_awake.clear()
	for v: Villager in m.villagers:
		var a := PackedFloat32Array()
		a.resize(KEYS.size())
		a.fill(0.0)
		a[F.FEAR] = 0.3
		a[F.HOPE] = 0.3
		level[v.id] = a


func get_f(vid: int, f: F) -> float:
	var a: PackedFloat32Array = level.get(vid, PackedFloat32Array())
	return a[f] if a.size() > f else 0.0


func set_f(vid: int, f: F, value: float) -> void:
	if not level.has(vid):
		return
	var a: PackedFloat32Array = level[vid]
	a[f] = clampf(value, 0.0, 1.0)
	level[vid] = a


## Добавить с учётом характера: паникёр боится сильнее, циник медленнее доверяет, горячая голова злится сильнее.
func add(vid: int, f: F, amount: float) -> void:
	var v := m.get_villager(vid)
	var k := 1.0
	if v != null:
		match v.persona:
			Voices.Persona.PANIC:
				k = 1.4 if f == F.FEAR else (0.8 if f == F.TRUST else 1.0)
			Voices.Persona.CYNIC:
				k = 0.6 if f == F.TRUST or f == F.HOPE else (1.2 if f == F.SUSPICION else 1.0)
			Voices.Persona.GRUFF, Voices.Persona.YOUNG:
				k = 1.3 if f == F.RAGE else 1.0
			Voices.Persona.PIOUS:
				k = 1.3 if f == F.GUILT or f == F.HOPE else 1.0
			Voices.Persona.QUIET:
				k = 1.2 if f == F.DESPAIR else 1.0
	set_f(vid, f, get_f(vid, f) + amount * (k if amount > 0.0 else 1.0))


## Главное состояние жителя для поля и карточки: "" — ничего заметного.
func main(vid: int) -> String:
	var best := ""
	var best_v := SHOW_FROM
	for f in [F.GRIEF, F.DESPAIR, F.RAGE, F.FEAR, F.GUILT, F.EXHAUSTION, F.HOPE]:
		var x := get_f(vid, f)
		if x >= best_v:
			best_v = x
			best = KEYS[f]
	return best


## Утро: вчерашние чувства слабеют, ночь даёт новые. Вызывается после итога ночи (Match.resolve_night).
func morning(r: NightReport) -> void:
	for vid: Variant in level.keys():
		var a: PackedFloat32Array = level[vid]
		for i in range(a.size()):
			a[i] *= KEEP[i]
		level[vid] = a
	for vid: Variant in rage_at.keys():
		if get_f(int(vid), F.RAGE) < 0.15:
			rage_at.erase(vid)
	for vid: Variant in guilt_for.keys():
		if get_f(int(vid), F.GUILT) < 0.15:
			guilt_for.erase(vid)
	var awake: Dictionary = {}
	var any_death := not r.deaths().is_empty()
	for e: NightReport.Entry in r.entries:
		var who := e.who
		match e.kind:
			NightReport.Kind.SURVIVED_STREET:
				add(who.id, F.FEAR, 0.3)
				add(who.id, F.EXHAUSTION, 0.5)
				awake[who.id] = true
				if e.host != null and e.host != who:
					add(who.id, F.RAGE, 0.6)
					rage_at[who.id] = e.host.id
					if e.host.alive and not e.host.is_upyr:
						add(e.host.id, F.GUILT, 0.4)       # не открыл, а человек выжил: стыдно смотреть в глаза
						guilt_for[e.host.id] = who.id
			NightReport.Kind.KILLED_INSIDE, NightReport.Kind.KILLED_CREATURE, NightReport.Kind.KILLED_MIMIC:
				for o: Villager in e.others:
					add(o.id, F.FEAR, 0.4)
					add(o.id, F.EXHAUSTION, 0.3)
					add(o.id, F.SUSPICION, 0.3)
					awake[o.id] = true
			NightReport.Kind.CLEAN_ROOM:
				for o: Villager in e.others:
					add(o.id, F.TRUST, 0.15 if e.others.size() > 1 else 0.0)
					add(o.id, F.FEAR, -0.1)
			NightReport.Kind.SAVED:
				add(who.id, F.HOPE, 0.3)
				for o: Villager in e.others:
					add(o.id, F.HOPE, 0.2)
	# гибель: страх у всех, горе и отчаяние у близких, вина у того, кто не открыл
	for e: NightReport.Entry in r.deaths():
		var lost := e.who
		if lost == null:
			continue
		for v: Villager in m.alive():
			add(v.id, F.FEAR, 0.12)
			add(v.id, F.HOPE, -0.1)
		for kin: Villager in m.kin_of(lost):
			set_f(kin.id, F.GRIEF, 0.95)
			add(kin.id, F.DESPAIR, 0.35 if m.kin_of(kin).is_empty() else 0.2)
			awake[kin.id] = true
			if kin.blame_id >= 0:
				add(kin.id, F.RAGE, 0.6)
				rage_at[kin.id] = kin.blame_id
		if e.kind == NightReport.Kind.KILLED_STREET and e.host != null and e.host.alive and not e.host.is_upyr:
			add(e.host.id, F.GUILT, 0.6)
			guilt_for[e.host.id] = lost.id
	# второе горе подряд или горе без близких рядом — отчаяние
	for v: Villager in m.alive():
		if get_f(v.id, F.GRIEF) > 0.6 and m.kin_of(v).is_empty():
			add(v.id, F.DESPAIR, 0.3)
	if not any_death:
		for v: Villager in m.alive():
			add(v.id, F.HOPE, 0.08)
	# обещания этой ночи: сдержанное — надежда и доверие, нарушенное — ярость на обещавшего
	for p: Dictionary in m.promises:
		if int(p.day) != m.day:
			continue
		if p.state == "kept":
			add(int(p.to), F.TRUST, 0.3)
			add(int(p.to), F.HOPE, 0.2)
		elif p.state == "broken":
			add(int(p.to), F.RAGE, 0.5)
			rage_at[int(p.to)] = int(p.by)
	for vid: Variant in level.keys():
		nights_awake[vid] = int(nights_awake.get(vid, 0)) + 1 if awake.has(vid) else 0


## Днём игрок выслушал жителя — надежда; усомнился — подозрение и обида.
func on_talk(vid: int, listened: bool) -> void:
	if listened:
		add(vid, F.HOPE, 0.15)
		add(vid, F.TRUST, 0.1)
		add(vid, F.DESPAIR, -0.25)
	else:
		add(vid, F.SUSPICION, 0.2)
		add(vid, F.RAGE, 0.15)


## Обвинили вслух: страх, а на обвинителя — злость.
func on_accused(vid: int, by: int) -> void:
	add(vid, F.FEAR, 0.1)
	add(vid, F.RAGE, 0.25)
	if get_f(vid, F.RAGE) >= 0.4 and not rage_at.has(vid):
		rage_at[vid] = by


## Строка состояния для карточки жителя: словами, без цифр. "" — ничего заметного.
func status_text(v: Villager) -> String:
	var k := main(v.id)
	match k:
		"grief":
			var lost := m.get_villager(v.grief_for)
			if lost != null:
				return L.t("feel.grief", {"me": v, "lost": lost})
			return L.t("feel.grief_any", {"me": v})
		"rage":
			var t := m.get_villager(int(rage_at.get(v.id, -1)))
			return L.t("feel.rage", {"me": v, "who": t}) if t != null else L.t("feel.rage_any", {"me": v})
		"despair":
			return L.t("feel.despair", {"me": v})
		"fear":
			return L.t("feel.fear", {"me": v})
		"guilt":
			return L.t("feel.guilt", {"me": v})
		"exhaustion":
			var n := int(nights_awake.get(v.id, 0))
			return L.t("feel.awake", {"me": v, "n": n}) if n >= 2 else L.t("feel.tired", {"me": v})
		"hope":
			return L.t("feel.hope", {"me": v})
	return ""
