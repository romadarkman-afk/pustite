class_name CampaignScreen
extends Screen
## Кампания «Посёлок за лесом»: акты и главы, звёзды, кто погиб насовсем, концовка акта.
## Закрытые акты видны с названием: что будет дальше.


var _map: CampaignMap
var _selected_act := 0


func screen_id() -> String:
	return "campaign"


func title() -> String:
	return L.t("camp.title")


func show_navigation() -> bool:
	return false


func handle_back() -> bool:
	if _selected_act == 0:
		return false
	_select_act(0)
	return true


func mood() -> Vector2:
	return Vector2(0.85, 0.9)


func build() -> void:
	W.clear(body)
	W.clear(footer)
	_map = CampaignMap.new()
	_map.build()
	_map.act_picked.connect(_select_act)
	_map.visible = _selected_act == 0
	body.add_child(_map)
	var map_caption := W.label(L.t("camp.pick_place"), &"Hint")
	map_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_caption.visible = _map.visible
	body.add_child(map_caption)
	for act: Dictionary in Campaign.ACTS:
		var aid := int(act.id)
		var first := body.get_child_count()
		var head := W.label(L.t("camp.act%d" % aid), &"Speaker")
		head.name = "ActHead_%d" % aid
		body.add_child(head)
		var chapters: Array = act.chapters
		head.visible = aid == _selected_act
		if chapters.is_empty():
			var soon := W.icon_line("lock", L.t("camp.act%d.hook" % aid) + " " + L.t("camp.soon"), &"Small")
			soon.name = "Soon_%d" % aid
			soon.visible = aid == _selected_act
			body.add_child(soon)
			continue
		var n := 0
		for id: String in chapters:
			n += 1
			body.add_child(_chapter_row(id, n))
		if Save.campaign_stars.has(String(chapters[chapters.size() - 1])):
			var end := W.panel(&"Page")
			end.name = "ActEnd_%d" % aid
			end.add_child(W.label(Campaign.act_ending(aid), &"Tale"))
			body.add_child(end)
		for i in range(first, body.get_child_count()):
			(body.get_child(i) as Control).visible = aid == _selected_act
	var fallen := Campaign.fallen()
	if not fallen.is_empty():
		var mem := W.icon_line("skull", L.t("camp.fallen", {"list": fallen}), &"Hint")
		mem.name = "Fallen"
		mem.visible = _selected_act != 0
		body.add_child(mem)
	if not Campaign.is_new():
		var reset := W.wrap(W.button(L.t("camp.reset"), &"Ghost"))
		reset.name = "Reset"
		reset.visible = _selected_act != 0
		reset.pressed.connect(_ask_reset)
		body.add_child(reset)

	var cur := Campaign.current()
	var go := W.button(L.t("camp.continue", {"title": L.t("camp.%s.title" % cur)}) if not Campaign.is_new() else L.t("camp.start"))
	go.name = "Continue"
	go.pressed.connect(func() -> void: _play(cur))
	go.visible = _selected_act == 0
	footer.add_child(go)
	var back := W.button(L.t("ui.back"), &"Ghost")
	back.pressed.connect(func() -> void:
		if not handle_back():
			emit_intent(Intent.BACK))
	footer.add_child(back)
	_fit_map.call_deferred()
	if not scroll.resized.is_connected(_fit_map):
		scroll.resized.connect(_fit_map)


func _select_act(act: int) -> void:
	_selected_act = act
	build()
	scroll.scroll_vertical = 0


func _fit_map() -> void:
	if is_instance_valid(_map) and _map.visible and scroll.size.y > 0:
		_map.height_limit = maxf(210.0, scroll.size.y - 54.0)
		_map.fit_height()


func _chapter_row(id: String, n: int) -> Control:
	var open := Campaign.unlocked(id)
	var stars := int(Save.campaign_stars.get(id, 0))
	var text := L.t("camp.chapter", {"n": n, "title": L.t("camp.%s.title" % id)})
	if stars > 0:
		text += "  " + Campaign.stars_text(stars)
	var box := W.panel(&"Sheet")
	box.name = "ChapterCard_" + id
	var row := W.hbox(12)
	var chapter_texture := Campaign.art(id)
	if chapter_texture != null:
		var art := TextureRect.new()
		art.name = "ChapterArt_" + id
		art.texture = chapter_texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(115, 86)
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(art)
	var copy := W.vbox(5)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := W.wrap(W.button(text, &"RowOn" if open and stars == 0 else &"Row"))
	b.name = "Chapter_" + id
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not open
	b.pressed.connect(func() -> void: _play(id))
	copy.add_child(b)
	# описание — подписью под кнопкой: длинная строка на любом языке переносится как обычный текст
	copy.add_child(W.label(L.t("camp.%s.desc" % id) if open else L.t("camp.locked"), &"Small"))
	if stars > 0:
		var again := W.wrap(W.button(L.t("camp.replay"), &"Ghost"))
		again.name = "Replay_" + id
		again.pressed.connect(func() -> void: _play(id))
		copy.add_child(again)
	row.add_child(copy)
	box.add_child(row)
	return box


## Новая глава начинается сразу. Пройденную сначала объясняют: звёзды растут, историю посёлка повтор не меняет.
func _play(id: String) -> void:
	if not Campaign.is_replay(id):
		emit_intent(Intent.PLAY_CHAPTER, {"id": id})
		return
	var i: int = await ActionSheet.ask(self, L.t("camp.replay_ask", {"title": L.t("camp.%s.title" % id)}),
		PackedStringArray([L.t("camp.replay_yes"), L.t("ui.back")]))
	if i == 0:
		emit_intent(Intent.PLAY_CHAPTER, {"id": id})


func _ask_reset() -> void:
	var i: int = await ActionSheet.ask(self, L.t("camp.reset_ask"), PackedStringArray([L.t("camp.reset_yes"), L.t("ui.back")]))
	if i == 0:
		Save.campaign_reset()
		build()


func music() -> StringName:
	return Sfx.menu_music()
