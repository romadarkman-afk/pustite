class_name EndScreen
extends Screen


func screen_id() -> String:
	return "end"


func field_ratio() -> float:
	return 0.28


func title() -> String:
	return "Разбор"


func mood() -> Vector2:
	return Vector2(0.55, 0.85)


var offer: String = ""          ## ступень, которую предложить: проиграл — легче, две победы — сложнее
var difficulty: String = "easy"


func build() -> void:
	var you := m.player()
	var people_won := m.winner == Match.Team.PEOPLE
	var won := people_won != you.is_upyr
	body.add_child(W.label("Люди выстояли" if people_won else "Посёлок опустел", &"Title"))
	body.add_child(W.label("Твоя сторона победила." if won else "Твоя сторона проиграла.", &"Tale"))
	Juice.haptic(Juice.Haptic.SUCCESS if won else Juice.Haptic.DEATH)
	Sfx.play(&"win" if won else &"lose")
	if offer != "":
		body.add_child(_offer_card())

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
	var opts := W.button("Сложность", &"Ghost")
	opts.pressed.connect(func() -> void: commit(Intent.OPEN_SETTINGS))
	footer.add_child(opts)


func _offer_card() -> Control:
	var lower := Difficulty.LADDER.find(offer) < Difficulty.LADDER.find(difficulty)
	var card := W.panel(&"Sheet")
	var box := W.vbox(10)
	card.add_child(box)
	box.add_child(W.label("Сделать легче?" if lower else "Две победы подряд. Попробовать сложнее?", &"Speaker"))
	box.add_child(W.label("%s: %s" % [Difficulty.NAMES[offer], Difficulty.describe(offer, Difficulty.preset(offer))], &"Small"))
	var b := W.button("Сделать легче" if lower else "Попробовать сложнее")
	var target := offer
	b.pressed.connect(func() -> void: commit(Intent.AGAIN, {"difficulty": target}))
	box.add_child(b)
	return card
