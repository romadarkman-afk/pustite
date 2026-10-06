class_name EndScreen
extends Screen


func screen_id() -> String:
	return "end"


func title() -> String:
	return "Разбор"


func mood() -> Vector2:
	return Vector2(0.55, 0.85)


func build() -> void:
	var you := m.player()
	var people_won := m.winner == Match.Team.PEOPLE
	var won := people_won != you.is_upyr
	body.add_child(W.label("Люди выстояли" if people_won else "Посёлок опустел", &"Title"))
	body.add_child(W.label("Ты в выигравшей стороне." if won else "Ты проиграл.", &"Tale"))
	Juice.haptic(Juice.Haptic.SUCCESS if won else Juice.Haptic.DEATH)

	var flow := HFlowContainer.new()
	var i := 0
	for v: Villager in m.villagers:
		var c := W.chip("%s — %s" % [v.name, "упырь" if v.is_upyr else "человек"],
			&"ChipUpyr" if v.is_upyr else (&"ChipDead" if not v.alive else &"Chip"))
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(c)
		Juice.pop_in(c, 0.4 + 0.12 * i)
		i += 1
	body.add_child(flow)

	body.add_child(W.label("Как это было", &"Hint"))
	for line: String in m.chronicle.slice(maxi(0, m.chronicle.size() - 14)):
		body.add_child(W.label(line, &"Small"))

	var again := W.button("Ещё партию")
	again.pressed.connect(func() -> void: commit(Intent.AGAIN))
	footer.add_child(again)
	var opts := W.button("Настроить баланс", &"Ghost")
	opts.pressed.connect(func() -> void: commit(Intent.OPEN_SETTINGS))
	footer.add_child(opts)
