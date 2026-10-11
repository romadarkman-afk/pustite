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
	if m.player_death != null and r.entries.has(m.player_death):
		var card := W.panel(&"Sheet")
		card.name = "WhyDead"
		var box := W.vbox(6)
		card.add_child(box)
		box.add_child(W.label(L.t("mo.why"), &"Speaker"))
		for l: String in Recap.death_lines(m, m.player_death, r):
			box.add_child(W.label(l, &"Small"))
		body.add_child(card)
	_reveal(r)


func _reveal(r: NightReport) -> void:
	# каждая строка сводки — карточка со значком события: смерть видно до того, как прочитал
	var lines: Array[Array] = []
	for e: NightReport.Entry in r.entries:
		if e.is_death():
			lines.append([_text(e), &"Body", true, _glyph(e)])
	for e: NightReport.Entry in r.entries:
		if not e.is_death():
			lines.append([_text(e), &"Small", false, _glyph(e)])
	if m.night_event != Match.Event.NONE:
		lines.append([Match.event_text(m.night_event), &"Small", false, event_glyph(m.night_event)])

	await Juice.wait(0.6)
	for l: Array in lines:
		if not is_instance_valid(self):
			return
		var card := W.panel(&"Card")
		card.set_meta("entry", true)
		card.add_child(W.icon_line(l[3], l[0], l[1], 44, ThemeFactory.BLOOD if l[2] else Color(0, 0, 0, 0)))
		body.add_child(card)
		Juice.pop_in(card)
		if l[2]:
			Juice.haptic(Juice.Haptic.DEATH)
			Sfx.play(&"death")
			death_fx.emit()
			Juice.shake(self, 8.0, 0.25)
			await Juice.wait(0.7)
		else:
			await Juice.wait(0.32)

	body.add_child(people_strip())
	var next := W.button(L.t("ui.next"))
	next.pressed.connect(func() -> void: commit(Intent.CONTINUE))
	footer.add_child(next)
	Juice.pop_in(next)
	revealed = true


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
