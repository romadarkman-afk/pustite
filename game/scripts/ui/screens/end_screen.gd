class_name EndScreen
extends Screen


func screen_id() -> String:
	return "end"


func field_ratio() -> float:
	return 0.28


func title() -> String:
	return L.t("end.title")


func mood() -> Vector2:
	return Vector2(0.55, 0.85)


var offer: String = ""          ## ступень, которую предложить: проиграл — легче, две победы — сложнее
var difficulty: String = "easy"


func build() -> void:
	var you := m.player()
	var people_won := m.winner == Match.Team.PEOPLE
	var won := people_won != you.is_upyr
	body.add_child(W.label(L.t("end.people" if people_won else "end.upyri"), &"Title"))
	body.add_child(W.label(L.t("end.won" if won else "end.lost"), &"Tale"))
	Juice.haptic(Juice.Haptic.SUCCESS if won else Juice.Haptic.DEATH)
	Sfx.play(&"win" if won else &"lose")
	body.add_child(_verdict_card())
	if offer != "":
		body.add_child(_offer_card())

	body.add_child(W.label(L.t("end.who"), &"Hint"))
	var flow := HFlowContainer.new()
	var i := 0
	for v: Villager in m.villagers:
		var who := L.t("end.upyr" if v.is_upyr else "end.human")
		if v.role != Match.Role.NONE:
			who = L.t("end.with_role", {"a": who, "role": Match.role_name(v, true)})
		var c := W.chip(L.t("end.chip", {"who": v.name, "what": who}),
			&"ChipUpyr" if v.is_upyr else (&"ChipDead" if not v.alive else &"Chip"))
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(c)
		Juice.pop_in(c, 0.4 + 0.12 * i)
		i += 1
	body.add_child(flow)

	body.add_child(W.label(L.t("end.how"), &"Hint"))
	for sec: Dictionary in Recap.timeline(m):
		if String(sec.title) != "":
			body.add_child(W.label(sec.title, &"Speaker"))
		for line: String in sec.lines:
			body.add_child(W.label(line, &"Small"))

	var again := W.button(L.t("end.again"))
	again.pressed.connect(func() -> void: commit(Intent.AGAIN))
	footer.add_child(again)
	var opts := W.button(L.t("settings.difficulty"), &"Ghost")
	opts.pressed.connect(func() -> void: commit(Intent.OPEN_SETTINGS))
	footer.add_child(opts)


## Главное в разборе: что решило твою партию — и, если тебя не стало, почему.
func _verdict_card() -> Control:
	var card := W.panel(&"Sheet")
	card.name = "Verdict"
	var box := W.vbox(8)
	card.add_child(box)
	box.add_child(W.label(L.t("end.verdict"), &"Speaker"))
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
	box.add_child(W.label(L.t("end.offer_easier" if lower else "end.offer_harder"), &"Speaker"))
	box.add_child(W.label(L.t("diff.note", {"d": Difficulty.title(offer), "text": Difficulty.describe(offer, Difficulty.preset(offer))}), &"Small"))
	var b := W.button(L.t("end.easier" if lower else "end.harder"))
	var target := offer
	b.pressed.connect(func() -> void: commit(Intent.AGAIN, {"difficulty": target}))
	box.add_child(b)
	return card
