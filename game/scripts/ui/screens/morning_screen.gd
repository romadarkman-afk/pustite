class_name MorningScreen
extends Screen
## Утро. Отчёт раскрывается построчно: каждая смерть — отдельный удар.

signal death_fx

var revealed := false


func screen_id() -> String:
	return "morning"


func title() -> String:
	return "Утро"


func mood() -> Vector2:
	return Vector2(0.1, 0.3)


func build() -> void:
	var r := m.report
	var deaths := r.deaths()
	var head := W.label(
		"Все дожили" if deaths.is_empty()
		else ("Одного не досчитались" if deaths.size() == 1 else "Не досчитались: %d" % deaths.size()),
		&"Title")
	head.add_theme_font_size_override("font_size", 44)
	body.add_child(head)
	_reveal(r)


func _reveal(r: NightReport) -> void:
	var lines: Array[Array] = []
	for e: NightReport.Entry in r.entries:
		if e.is_death():
			lines.append([_text(e), &"Body", true])
	for e: NightReport.Entry in r.entries:
		if not e.is_death():
			lines.append([_text(e), &"Hint" if e.kind != NightReport.Kind.CLEAN_ROOM else &"Small", false])

	await Juice.wait(0.6)
	for l: Array in lines:
		if not is_instance_valid(self):
			return
		var lab := W.label(l[0], l[1])
		body.add_child(lab)
		Juice.pop_in(lab)
		if l[2]:
			Juice.haptic(Juice.Haptic.DEATH)
			death_fx.emit()
			Juice.shake(self, 8.0, 0.25)
			await Juice.wait(0.7)
		else:
			await Juice.wait(0.32)

	body.add_child(people_strip())
	var next := W.button("Дальше")
	next.pressed.connect(func() -> void: commit(Intent.CONTINUE))
	footer.add_child(next)
	Juice.pop_in(next)
	revealed = true


func _text(e: NightReport.Entry) -> String:
	var house := m.house_name(e.house) if e.house >= 0 else ""
	match e.kind:
		NightReport.Kind.KILLED_STREET:
			return "%s не пустили в «%s». Найден на улице." % [e.who.name, house]
		NightReport.Kind.KILLED_ALONE:
			return "%s остался один в «%s». Оберег погас." % [e.who.name, house]
		NightReport.Kind.KILLED_INSIDE:
			var names := PackedStringArray()
			for o: Villager in e.others:
				names.append(o.name)
			return "%s погиб в «%s». Ночь там провёл: %s." % [e.who.name, house, ", ".join(names)]
		NightReport.Kind.SURVIVED_STREET:
			return "%s провёл ночь на улице. И вернулся." % e.who.name
		NightReport.Kind.SURVIVED_ALONE:
			return "%s был один в «%s» — и цел." % [e.who.name, house]
		NightReport.Kind.CLEAN_ROOM:
			var names2 := PackedStringArray()
			for o: Villager in e.others:
				names2.append(o.name)
			return "В «%s» ночевали %s — все целы." % [house, " и ".join(names2)]
		NightReport.Kind.LIAR:
			return "%s говорил про «%s», а ночевал в «%s»." % [e.who.name, m.house_name(e.said_house), house]
	return ""
