class_name MorningScreen
extends Screen
## Утро. Отчёт раскрывается построчно: каждая смерть — отдельный удар.

signal death_fx

var revealed := false


func screen_id() -> String:
	return "morning"


func is_busy() -> bool:
	return not revealed


func field_ratio() -> float:
	return 0.32


func title() -> String:
	return L.t("mo.title")


func mood() -> Vector2:
	return Vector2(0.1, 0.3)


func build() -> void:
	var r := m.report
	var deaths := r.deaths()
	var head := W.label(
		L.t("mo.all_alive") if deaths.is_empty()
		else (L.t("mo.one_dead") if deaths.size() == 1 else L.t("mo.dead_n", {"n": deaths.size()})),
		&"Title")
	head.add_theme_font_size_override("font_size", ThemeFactory.fs(44))
	body.add_child(head)
	# тебя не стало этой ночью — сразу видно почему: кто был рядом, кто открыл дверь
	# первая глава началась со стука: цели главы — после первой ночи, когда игрок уже понял, что тут происходит
	if bool(Game.chapter.get("cold_open", false)) and m.day == 1:
		body.add_child(PrologueScreen.goals_card(m, Game.chapter, {}))
	if you_died():
		body.add_child(you_dead_card(r))
		Sfx.set_music(&"", 0.3)
		Sfx.play(Dread.death_sound(m.player_death.kind), 1.0, -4.0)
	_scene_then_reveal(r)


## Сцена утра (TASK-013, TASK-014): после первой ночи главы «Стук» — одно из трёх утр,
## в кампании после гибели близкого — сцена того, кто остался. Одна полная сцена за утро,
## остальные утраты — короткими карточками.
var scene_shown := ""


func _scene_then_reveal(r: NightReport) -> void:
	var sc := morning_scene(m, r)
	if not sc.is_empty() and not you_died():
		scene_shown = String(sc.id)
		await ScenePlayer.play(self, sc, m)
		if not is_instance_valid(self):
			return
	_reveal(r)


static func morning_scene(mm: Match, r: NightReport) -> Dictionary:
	if Game.chapter.is_empty():
		return {}
	if String(Game.chapter.get("id", "")) == "a1c1" and mm.day == 1:
		return Scenes.first_morning(mm)
	for e: NightReport.Entry in r.deaths():
		if e.who == null or e.who.is_player:
			continue
		for kin: Villager in mm.kin_of(e.who):
			if not kin.is_player and kin.guest_id.is_empty() and kin.story_id >= 0:
				return Scenes.grief(kin, e.who)
	return {}


func you_died() -> bool:
	return m.player_death != null and m.report != null and m.report.entries.has(m.player_death)


## Экран твоей смерти (Task 55): портрет, кто не открыл, что ты слышал последним, что будет без тебя.
func you_dead_card(r: NightReport) -> PanelContainer:
	var e := m.player_death
	var card := W.panel(&"Sheet")
	card.name = "WhyDead"
	var row := W.hbox(14)
	card.add_child(row)
	row.add_child(W.portrait(m.player(), Vector2(74, 136), Color(0.55, 0.5, 0.56)))
	var box := W.vbox(6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var t := W.label(L.t("mo.you_dead"), &"Speaker")
	t.add_theme_color_override("font_color", ThemeFactory.BLOOD)
	box.add_child(t)
	box.add_child(W.label(L.t("mo.why"), &"Small"))
	for l: String in Recap.death_lines(m, e, r):
		box.add_child(W.label(l, &"Small"))
	var heard := W.label(last_heard(m, e), &"Tale")
	heard.name = "LastHeard"
	box.add_child(heard)
	var left := W.label(L.t("mo.without_you", {"n": m.alive().size(), "u": m.upyri_alive()}), &"Hint")
	left.name = "WithoutYou"
	box.add_child(left)
	return card


## Что игрок слышал последним — по тому, как погиб.
static func last_heard(mm: Match, e: NightReport.Entry) -> String:
	var args := {"house": mm.house_name(e.house) if e.house >= 0 else "", "who": e.killer if e.killer != null else e.host}
	match e.kind:
		NightReport.Kind.KILLED_STREET:
			return L.t("mo.heard_street", args)
		NightReport.Kind.KILLED_INSIDE:
			return L.t("mo.heard_inside", args) if e.killer != null else L.t("mo.heard_alone", args)
		NightReport.Kind.KILLED_CREATURE:
			return L.t("mo.heard_creature", args)
		NightReport.Kind.KILLED_MIMIC:
			return L.t("mo.heard_mimic", {"who": e.voice if e.voice != null else e.host})
	return L.t("mo.heard_alone", args)


func _reveal(r: NightReport) -> void:
	# каждая строка сводки — карточка со значком события: смерть видно до того, как прочитал
	var lines: Array[Array] = []
	for e: NightReport.Entry in r.entries:
		if e.is_death():
			lines.append([_text(e), &"Body", true, _glyph(e), e.who, e.kind])
	for e: NightReport.Entry in r.entries:
		if not e.is_death():
			lines.append([_text(e), &"Small", false, _glyph(e)])
	if m.night_event != Match.Event.NONE:
		lines.append([Match.event_text(m.night_event), &"Small", false, event_glyph(m.night_event)])

	await Juice.wait(0.6)
	for l: Array in lines:
		if not is_instance_valid(self):
			return
		var lost: Villager = l[4] if l.size() > 4 else null
		var card: Control
		if lost != null and not lost.is_player:
			card = loss_card(lost, l[0])
		else:
			card = W.panel(&"Card")
			card.add_child(W.icon_line(l[3], l[0], l[1], 44, ThemeFactory.BLOOD if l[2] else Color(0, 0, 0, 0)))
		card.set_meta("entry", true)
		body.add_child(card)
		Juice.pop_in(card)
		if lost != null and not lost.is_player:
			# утрата: тишина вместо музыки, крик, долгая пауза — строку не пролистнуть за полсекунды
			Juice.haptic(Juice.Haptic.DEATH)
			Sfx.play(&"death")
			Sfx.play(&"human_cry", 0.9 + randf() * 0.18, -5.0)
			Sfx.play(Dread.death_sound(l[5]), 1.0, -9.0)
			death_fx.emit()
			Juice.shake(self, 8.0, 0.25)
			await Juice.wait(LOSS_HOLD)
		elif l[2]:
			Juice.haptic(Juice.Haptic.DEATH)
			Sfx.play(&"death")
			Sfx.play(&"human_cry", 0.9 + randf() * 0.18, -5.0)
			death_fx.emit()
			Juice.shake(self, 8.0, 0.25)
			await Juice.wait(0.7)
		else:
			await Juice.wait(0.32)

	for c: Dictionary in Guests.morning_clues(m):
		body.add_child(guest_card(c))
		await Juice.wait(0.4)
	body.add_child(people_strip())
	var dead := you_died() and m.phase == Match.Phase.MORNING and m.winner == Match.Team.NONE
	var next := W.button(L.t("mo.watch") if dead else L.t("ui.next"))
	next.pressed.connect(func() -> void: commit(Intent.CONTINUE))
	footer.add_child(next)
	Juice.pop_in(next)
	if dead:
		var stop := W.button(L.t("mo.finish"), &"Ghost")
		stop.name = "SkipToEnd"
		stop.pressed.connect(func() -> void: commit(Intent.SKIP_TO_END))
		footer.add_child(stop)
	revealed = true


const LOSS_HOLD := 1.6


## Сцена утраты: портрет, кем был человек, его последние слова и как горюют близкие.
func loss_card(lost: Villager, what: String) -> PanelContainer:
	var card := W.panel(&"Sheet")
	card.name = "Loss_%d" % lost.id
	card.set_meta("loss", lost.id)
	var row := W.hbox(14)
	card.add_child(row)
	row.add_child(W.portrait(lost, Vector2(70, 128), Color(0.72, 0.7, 0.76)))   # выцветший, как старая карточка
	var info := W.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_l := W.label(lost.name, &"Speaker")
	name_l.add_theme_color_override("font_color", ThemeFactory.BLOOD)
	info.add_child(name_l)
	info.add_child(W.label(SocialContent.person_title(lost), &"Small"))
	info.add_child(W.label(what, &"Body"))
	if not lost.last_words.is_empty():
		var words := W.label("«%s»" % lost.last_words, &"Tale")
		words.name = "LastWords"
		info.add_child(words)
	for kin: Villager in m.mourners(lost):
		var g := W.label(grief_line(kin, lost), &"Hint")
		g.name = "Mourner_%d" % kin.id
		info.add_child(g)
	return card


## Что узнали о госте этим утром: улика или разгадка тайны (Task 60).
func guest_card(c: Dictionary) -> PanelContainer:
	var v: Villager = c.who
	var card := W.panel(&"Card")
	card.name = "Guest_" + v.guest_id
	card.set_meta("entry", true)
	card.set_meta("loss", true)              # своя раскладка с портретом — не строка сводки
	var row := W.hbox(14)
	card.add_child(row)
	row.add_child(W.portrait(v, Vector2(56, 102)))
	var box := W.vbox(4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var head := W.label(L.t("mo.guest_reveal" if bool(c.reveal) else "mo.guest", {"who": v}), &"Speaker")
	if bool(c.reveal):
		head.add_theme_color_override("font_color", ThemeFactory.LAMP)
	box.add_child(head)
	box.add_child(W.label(String(c.text), &"Small"))
	Juice.pop_in(card)
	return card


## Как близкий переживает утрату: муж/жена, родитель, ребёнок.
static func grief_line(kin: Villager, lost: Villager) -> String:
	var key := "grief.partner"
	if kin.partner_id != lost.id:
		key = "grief.parent" if kin.age > lost.age else "grief.child"
	return L.t(key, {"kin": kin, "lost": lost})


## Значок события ночи: туман, луна, тишина, ливень.
static func event_glyph(e: Match.Event) -> String:
	match e:
		Match.Event.FOG: return "fog"
		Match.Event.MOON: return "moon"
		Match.Event.QUIET: return "quiet"
		Match.Event.RAIN: return "rain"
	return "info"


## Значок строки сводки: по нему видно, что случилось, ещё до чтения.
func _glyph(e: NightReport.Entry) -> String:
	match e.kind:
		NightReport.Kind.KILLED_STREET: return "street"
		NightReport.Kind.KILLED_ALONE: return "alone"
		NightReport.Kind.KILLED_INSIDE: return "skull"
		NightReport.Kind.KILLED_CREATURE: return "claw"
		NightReport.Kind.KILLED_MIMIC: return "mimic"
		NightReport.Kind.SURVIVED_STREET: return "street_ok"
		NightReport.Kind.SURVIVED_ALONE: return "alone"
		NightReport.Kind.CLEAN_ROOM: return "safe"
		NightReport.Kind.LIAR: return "liar"
		NightReport.Kind.TALISMAN_WORN:
			var lvl: int = m.talisman[e.house] if e.house >= 0 and e.house < m.talisman.size() else 1
			return "talisman_cracked" if lvl > 0 else "talisman_broken"
		NightReport.Kind.SAVED: return "heal"
		NightReport.Kind.TUNNEL: return "tunnel"
		NightReport.Kind.MIMIC_SPARED: return "mimic"
		NightReport.Kind.MIMIC_KNOCK: return "knock"
	return "info"


func _text(e: NightReport.Entry) -> String:
	var v := e.who
	var house := m.house_name(e.house) if e.house >= 0 else ""
	var a := {"who": v, "house": house}
	if e.cause == "river":
		return L.t("mo.river_dead" if e.is_death() else "mo.river_ok", a)
	match e.kind:
		NightReport.Kind.KILLED_STREET:
			return L.t("mo.street_dead", a)
		NightReport.Kind.KILLED_ALONE:
			return L.t("mo.alone_dead", a)
		NightReport.Kind.KILLED_INSIDE:
			a["others"] = e.others
			return L.t("mo.killed", a)
		NightReport.Kind.SURVIVED_STREET:
			return L.t("mo.street_ok", a)
		NightReport.Kind.SURVIVED_ALONE:
			return L.t("mo.alone_ok", a)
		NightReport.Kind.CLEAN_ROOM:
			a["list"] = e.others
			return L.t("mo.clean", a)
		NightReport.Kind.LIAR:
			a["said"] = m.house_name(e.said_house)
			return L.t("mo.liar", a)
		NightReport.Kind.KILLED_CREATURE:
			return L.t("mo.creature", a)
		NightReport.Kind.TALISMAN_WORN:
			var lvl: int = m.talisman[e.house] if e.house >= 0 and e.house < m.talisman.size() else 1
			return L.t("mo.talisman_cracked" if lvl > 0 else "mo.talisman_broken", a)
		NightReport.Kind.SAVED:
			var hl: Villager = e.others[0]
			a["h"] = hl
			a["healer"] = Match.healer_named(hl)
			return L.t("mo.saved_" + (e.cause if e.cause in ["upyr", "creature", "mimic"] else "upyr"), a)
		NightReport.Kind.TUNNEL:
			a["from"] = m.house_name(e.said_house)
			return L.t("mo.tunnel", a)
		NightReport.Kind.KILLED_MIMIC:
			a["voice"] = e.voice
			return L.t("mo.mimic_kill", a)
		NightReport.Kind.MIMIC_SPARED:
			a["voice"] = e.voice
			return L.t("mo.mimic_spared", a)
		NightReport.Kind.MIMIC_KNOCK:
			a["voice"] = e.voice
			if e.voice.alive and e.voice.night_house >= 0:
				a["away"] = m.house_name(e.voice.night_house)
				return L.t("mo.mimic_knock_away", a)
			return L.t("mo.mimic_knock", a)
	return ""


func ambience() -> StringName:
	return &"amb_day"


func music() -> StringName:
	return &""
