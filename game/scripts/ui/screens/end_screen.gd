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
	body.add_child(_verdict_card())
	if offer != "":
		body.add_child(_offer_card())

	body.add_child(W.label("Кто кем был", &"Hint"))
	var flow := HFlowContainer.new()
	var i := 0
	for v: Villager in m.villagers:
		var who := "упырь" if v.is_upyr else "человек"
		if v.role != Match.Role.NONE:
			who += ", " + Match.role_name(v).to_lower()
		var c := W.chip("%s — %s" % [v.name, who],
			&"ChipUpyr" if v.is_upyr else (&"ChipDead" if not v.alive else &"Chip"))
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(c)
		Juice.pop_in(c, 0.4 + 0.12 * i)
		i += 1
	body.add_child(flow)

	body.add_child(W.label("Как это было", &"Hint"))
	for sec: Dictionary in Recap.timeline(m):
		if String(sec.title) != "":
			body.add_child(W.label(sec.title, &"Speaker"))
		for line: String in sec.lines:
			body.add_child(W.label(line, &"Small"))

	var again := W.button("Ещё партию")
	again.pressed.connect(func() -> void: commit(Intent.AGAIN))
	footer.add_child(again)
	var opts := W.button("Сложность", &"Ghost")
	opts.pressed.connect(func() -> void: commit(Intent.OPEN_SETTINGS))
	footer.add_child(opts)


## Главное в разборе: что решило твою партию — и, если тебя не стало, почему.
func _verdict_card() -> Control:
	var card := W.panel(&"Sheet")
	card.name = "Verdict"
	var box := W.vbox(8)
	card.add_child(box)
	box.add_child(W.label("Что решило партию", &"Speaker"))
	box.add_child(W.label(Recap.verdict(m, director), &"Body"))
	var more := PackedStringArray()
	if m.player().exiled:
		more = Recap.exile_lines(m, director).slice(1)
	elif m.player_death != null:
		more = Recap.death_lines(m, m.player_death).slice(1)
	for l: String in more:
		box.add_child(W.label(l, &"Small"))
	return card


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
