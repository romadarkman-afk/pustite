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
			Sfx.play(&"death")
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
	var v := e.who
	var house := m.house_name(e.house) if e.house >= 0 else ""
	var here := Ru.house_in(house)
	match e.kind:
		NightReport.Kind.KILLED_STREET:
			return "%s не пустили в «%s». %s" % [Ru.acc(v), house,
				Ru.g(v, "Найден на улице.", "Найдена на улице.", "Вы погибли на улице.")]
		NightReport.Kind.KILLED_ALONE:
			return "%s в «%s». Оберег погас." % [Ru.g(v, "%s остался один" % v.name, "%s осталась одна" % v.name, "Вы остались одни"), here]
		NightReport.Kind.KILLED_INSIDE:
			return "%s %s в «%s». Рядом %s: %s." % [Ru.nom(v), Ru.g(v, "погиб", "погибла", "погибли"), here,
				Ru.were(e.others, "был", "была", "были"), Ru.join(e.others)]
		NightReport.Kind.SURVIVED_STREET:
			return "%s %s ночь на улице. И %s." % [Ru.nom(v), Ru.g(v, "провёл", "провела", "провели"),
				Ru.g(v, "вернулся", "вернулась", "вернулись")]
		NightReport.Kind.SURVIVED_ALONE:
			return "%s в «%s» — и %s." % [Ru.g(v, "%s был один" % v.name, "%s была одна" % v.name, "Вы были одни"), here,
				Ru.g(v, "цел", "цела", "целы")]
		NightReport.Kind.CLEAN_ROOM:
			return "В «%s» ночевали %s — все целы." % [here, Ru.join(e.others)]
		NightReport.Kind.LIAR:
			return "%s %s про «%s», а %s в «%s»." % [Ru.nom(v), Ru.g(v, "говорил", "говорила", "говорили"),
				m.house_name(e.said_house), Ru.g(v, "ночевал", "ночевала", "ночевали"), here]
	return ""


func ambience() -> StringName:
	return &"amb_day"


func music() -> StringName:
	return &""
