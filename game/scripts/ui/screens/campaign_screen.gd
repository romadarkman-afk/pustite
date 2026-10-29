class_name CampaignScreen
extends Screen
## Кампания «Посёлок за лесом»: акты и главы, звёзды, кто погиб насовсем, концовка акта.
## Закрытые акты видны с названием: что будет дальше.


const COVER_PATH := "res://assets/ui/campaign_cover.png"
var _act_heads: Dictionary = {}     ## номер акта -> заголовок в списке глав


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
	body.add_child(_book_header())
	var map := CampaignMap.new()
	map.build()
	map.act_picked.connect(_scroll_to_act)
	body.add_child(map)
	_act_heads.clear()
	for act: Dictionary in Campaign.ACTS:
		var aid := int(act.id)
		var head := W.label(L.t("camp.act%d" % aid), &"Speaker")
		head.name = "ActHead_%d" % aid
		_act_heads[aid] = head
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
			var end := W.panel(&"Page")
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
	go.pressed.connect(func() -> void: _play(cur))
	footer.add_child(go)
	var back := W.button(L.t("ui.back"), &"Ghost")
	back.pressed.connect(func() -> void: emit_intent(Intent.BACK))
	footer.add_child(back)


## Обложка книги и вступление. В начале кампании обложка крупнее.
func _book_header() -> Control:
	var row := W.hbox(14)
	row.name = "BookHeader"
	var px := 150.0 if Campaign.is_new() else 88.0
	var cover := TextureRect.new()
	cover.name = "BookCover"
	cover.texture = load(COVER_PATH) as Texture2D if ResourceLoader.exists(COVER_PATH) else null
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.custom_minimum_size = Vector2(px, px * 1.5)
	cover.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cover)
	var intro := W.label(L.t("camp.intro"), &"Tale")
	intro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(intro)
	return row


## Нажали на место на карте: список прокручивается к заголовку акта.
func _scroll_to_act(act: int) -> void:
	var head: Control = _act_heads.get(act)
	if head == null or scroll == null or not is_instance_valid(head):
		return
	var y := int(head.global_position.y - scroll.global_position.y) + scroll.scroll_vertical - 8
	if Juice.instant:
		scroll.scroll_vertical = maxi(y, 0)
	else:
		Juice.tween().tween_property(scroll, "scroll_vertical", maxi(y, 0), 0.35)


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
		art.custom_minimum_size = Vector2(92, 68)
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
