class_name CampaignScreen
extends Screen
## Кампания «Посёлок за лесом»: акты и главы, звёзды, кто погиб насовсем, концовка акта.
## Закрытые акты видны с названием: что будет дальше.


func screen_id() -> String:
	return "campaign"


func title() -> String:
	return L.t("camp.title")


func field_ratio() -> float:
	return 0.34


func mood() -> Vector2:
	return Vector2(0.85, 0.9)


func build() -> void:
	W.clear(body)
	W.clear(footer)
	body.add_child(W.label(L.t("camp.title"), &"Title"))
	body.add_child(W.label(L.t("camp.intro"), &"Tale"))
	for act: Dictionary in Campaign.ACTS:
		var aid := int(act.id)
		var head := W.label(L.t("camp.act%d" % aid), &"Speaker")
		body.add_child(head)
		var chapters: Array = act.chapters
		if chapters.is_empty():
			var soon := W.icon_line("lock", L.t("camp.act%d.hook" % aid) + " " + L.t("camp.soon"), &"Small")
			soon.name = "Soon_%d" % aid
			body.add_child(soon)
			continue
		var n := 0
		for id: String in chapters:
			n += 1
			body.add_child(_chapter_row(id, n))
		if Save.campaign_stars.has(String(chapters[chapters.size() - 1])):
			var end := W.panel(&"Sheet")
			end.name = "ActEnd_%d" % aid
			end.add_child(W.label(Campaign.act_ending(aid), &"Tale"))
			body.add_child(end)
	var fallen := Campaign.fallen()
	if not fallen.is_empty():
		var mem := W.icon_line("skull", L.t("camp.fallen", {"list": fallen}), &"Hint")
		mem.name = "Fallen"
		body.add_child(mem)
	if not Campaign.is_new():
		var reset := W.wrap(W.button(L.t("camp.reset"), &"Ghost"))
		reset.name = "Reset"
		reset.pressed.connect(_ask_reset)
		body.add_child(reset)

	var cur := Campaign.current()
	var go := W.button(L.t("camp.continue", {"title": L.t("camp.%s.title" % cur)}) if not Campaign.is_new() else L.t("camp.start"))
	go.name = "Continue"
	go.pressed.connect(func() -> void: emit_intent(Intent.PLAY_CHAPTER, {"id": cur}))
	footer.add_child(go)
	var back := W.button(L.t("ui.back"), &"Ghost")
	back.pressed.connect(func() -> void: emit_intent(Intent.BACK))
	footer.add_child(back)


func _chapter_row(id: String, n: int) -> Control:
	var open := Campaign.unlocked(id)
	var stars := int(Save.campaign_stars.get(id, 0))
	var text := L.t("camp.chapter", {"n": n, "title": L.t("camp.%s.title" % id)})
	if stars > 0:
		text += "  " + Campaign.stars_text(stars)
	var box := W.vbox(6)
	var b := W.wrap(W.button(text, &"RowOn" if open and stars == 0 else &"Row"))
	b.name = "Chapter_" + id
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not open
	b.pressed.connect(func() -> void: emit_intent(Intent.PLAY_CHAPTER, {"id": id}))
	box.add_child(b)
	# описание — подписью под кнопкой: длинная строка на любом языке переносится как обычный текст
	box.add_child(W.label(L.t("camp.%s.desc" % id) if open else L.t("camp.locked"), &"Small"))
	return box


func _ask_reset() -> void:
	var i: int = await ActionSheet.ask(self, L.t("camp.reset_ask"), PackedStringArray([L.t("camp.reset_yes"), L.t("ui.back")]))
	if i == 0:
		Save.campaign_reset()
		build()


func music() -> StringName:
	return &"menu"
