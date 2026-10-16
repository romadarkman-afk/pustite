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
	if people_won:
		Sfx.play(&"upyr_cry", 0.9, -7.0)
	body.add_child(_verdict_card())
	var case_card := W.panel(&"Card")
	case_card.name = "CaseRecap"
	var case_box := W.vbox(8)
	case_box.add_child(W.label(SocialContent.case_recap(m.case_id, m.door_inspections.size()), &"Small"))
	for record: Dictionary in m.door_inspections:
		var visitor := m.get_villager(int(record.villager))
		var revealed := SocialContent.door_mimic_title() if bool(record.get("mimic", false)) else L.t("end.upyr" if visitor != null and visitor.is_upyr else "end.human")
		case_box.add_child(W.label(L.t("end.chip", {"who": String(record.get("name", "")), "what": revealed})
			+ "\n" + SocialContent.door_record(int(record.day), StringName(record.tell)), &"Small"))
	case_card.add_child(case_box)
	body.add_child(case_card)
	if m.rule != "":
		var card := W.panel(&"Card")
		card.name = "Daily"
		var date := Challenge.today()
		card.add_child(W.icon_line("safe" if won else "skull",
			L.t("daily.won" if won else "daily.lost") + ". " + L.t("daily.streak", {"n": Save.daily_streak_on(Game.daily if Game.daily != "" else date)}) + ". " + L.t("daily.tomorrow"), &"Body"))
		body.add_child(card)
	if not Game.new_items.is_empty():
		var names := PackedStringArray()
		for key: String in Game.new_items:
			var parts := key.split(":")
			names.append(Cosmetics.title(parts[0], parts[1]))
		var nc := W.panel(&"Card")
		nc.name = "NewItems"
		var nb := W.vbox(8)
		nb.add_child(W.icon_line("street_ok", L.t("cos.new", {"list": L.t("list.sep").join(names)}), &"Body"))
		var wear := W.button(L.t("cos.title"), &"Row")
		wear.pressed.connect(func() -> void: commit(Intent.OPEN_WARDROBE))
		nb.add_child(wear)
		nc.add_child(nb)
		body.add_child(nc)
	if offer != "" and m.rule == "":
		body.add_child(_offer_card())
	var known := W.vbox(8)
	for resident: Villager in m.villagers:
		var ending := SocialContent.epilogue(resident) if not resident.is_player else ""
		if not ending.is_empty():
			known.add_child(W.label(ending, &"Small"))
	if known.get_child_count() > 0:
		var chapter := W.panel(&"Card")
		var chapter_box := W.vbox(8)
		chapter_box.add_child(W.label("После последней ночи" if L.code == "ru" else "After the last night", &"Speaker"))
		chapter_box.add_child(known)
		chapter.add_child(chapter_box)
		body.add_child(chapter)
	else:
		known.queue_free()

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
