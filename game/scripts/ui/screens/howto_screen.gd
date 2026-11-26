class_name HowToScreen
extends Screen
## «Как играть»: карточки с картинками. Перед первой партией показываются шесть основных, один раз,
## потом по кнопке в меню все. Листается кнопкой «Дальше» и свайпом.

## Карточки: ключ заголовка, ключ текста, картинка (HowToArt.kind) и строки со значками [значок, ключ текста].
## Значки и тексты строк те же, что в игре, поэтому переводить заново нечего.
const PAGES := [
	["howto.day.title", "howto.day.text", "day", []],
	["howto.night.title", "howto.night.text", "night", []],
	["howto.door.title", "howto.door.text", "door", []],
	["howto.talisman.title", "howto.talisman.text", "talisman", [
		["talisman", "door.tal_ok"], ["talisman_cracked", "door.tal_cracked"], ["talisman_broken", "door.tal_broken"]]],
	["howto.marks.title", "howto.marks.text", "marks", [
		["mark_eye", "legend.eye"], ["mark_street", "legend.street"], ["mark_liar", "legend.liar"],
		["mark_death", "legend.death"], ["mark_fake", "legend.fake"], ["mark_sabotage", "legend.sabotage"],
		["mark_tunnel", "legend.tunnel"], ["mark_pact", "legend.pact"]]],
	["howto.jobs.title", "howto.jobs.text", "jobs", []],
	["howto.events.title", "howto.events.text", "events", [
		["fog", "event.fog.text"], ["moon", "event.moon.text"], ["quiet", "event.quiet.text"], ["rain", "event.rain.text"]]],
	["howto.roles.title", "howto.roles.text", "roles", []],
	["howto.campaign.title", "howto.campaign.text", "campaign", []],
]
const CORE := 6                   ## сколько карточек видит новичок перед первой партией

var page: int = 0
var then_play: bool = false       ## true — после последней карточки начинается партия
var art: HowToArt
var _press_x := INF


func show_navigation() -> bool:
	return not then_play


func screen_id() -> String:
	return "howto"


## Сколько карточек в этом показе: перед первой партией основные, из меню все.
func page_count() -> int:
	return CORE if then_play else PAGES.size()


func title() -> String:
	return L.t("howto.title", {"a": page + 1, "b": page_count()})


func music() -> StringName:
	return Sfx.menu_music()


func mood() -> Vector2:
	return Vector2(0.8, 0.6)


func build() -> void:
	W.clear(body)
	W.clear(footer)
	var card: Array = PAGES[page]
	art = HowToArt.new()
	art.setup(String(card[2]))
	_size_art()
	if not resized.is_connected(_size_art):
		resized.connect(_size_art)
	art.gui_input.connect(_on_art_input)
	body.add_child(art)

	var heading := W.label(L.t(String(card[0])), &"Title")
	heading.add_theme_font_size_override("font_size", ThemeFactory.fs(22))
	body.add_child(heading)
	var description := W.label(L.t(String(card[1])), &"Tale")
	description.add_theme_font_size_override("font_size", ThemeFactory.fs(19))
	body.add_child(description)
	if art.kind == "marks":
		_mark_picker(card[3])
	else:
		for row: Array in card[3]:
			var line := W.icon_line(String(row[0]), L.t(String(row[1])), &"Small", 46.0)
			line.name = "Row_" + String(row[0])
			body.add_child(line)
	var last := page == page_count() - 1
	if last and then_play:
		body.add_child(W.label(L.t("howto.more"), &"Hint"))

	var controls := W.hbox(8)
	if page > 0:
		var previous := W.button(L.t("ui.back"), &"Ghost", 55)
		previous.name = "PreviousPage"
		previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		previous.add_theme_font_size_override("font_size", ThemeFactory.fs(15))
		previous.pressed.connect(prev_page)
		controls.add_child(previous)
	var next := W.button(L.t(("menu.play" if then_play else "howto.got_it") if last else "ui.next"), &"Primary", 68)
	next.name = "NextPage"
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.add_theme_font_size_override("font_size", ThemeFactory.fs(18))
	next.pressed.connect(next_page)
	controls.add_child(next)
	footer.add_child(controls)

	if not last:
		var skip := W.button(L.t("ui.skip"), &"Ghost", 48)
		skip.name = "SkipHowTo"
		skip.add_theme_font_size_override("font_size", ThemeFactory.fs(14))
		skip.pressed.connect(func() -> void: commit(Intent.HOWTO_DONE, {"play": then_play}))
		footer.add_child(skip)


func _mark_picker(rows: Array) -> void:
	var grid := GridContainer.new()
	grid.name = "MarkPicker"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var details := W.label(L.t(String(rows[0][1])), &"Small")
	details.name = "MarkMeaning"
	details.add_theme_font_size_override("font_size", ThemeFactory.fs(17))
	var buttons: Array[Button] = []
	for mark: Array in rows:
		var kind := String(mark[0])
		var text := L.t(String(mark[1]))
		var button := W.button("", &"Row", 48)
		button.name = "Row_" + kind
		button.accessibility_name = text
		button.tooltip_text = text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var glyph := Glyph.make(kind, 37.0, Glyph.tint(kind))
		button.add_child(glyph)
		glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
		glyph.offset_left = -18.5
		glyph.offset_top = -18.5
		glyph.offset_right = 18.5
		glyph.offset_bottom = 18.5
		button.pressed.connect(func() -> void:
			details.text = text
			for other: Button in buttons:
				other.theme_type_variation = &"RowOn" if other == button else &"Row")
		buttons.append(button)
		grid.add_child(button)
	buttons[0].theme_type_variation = &"RowOn"
	body.add_child(details)


## Иллюстрация занимает меньше места, чтобы текст и навигация оставались видны.
func _size_art() -> void:
	if is_instance_valid(art):
		var rows: int = (PAGES[page][3] as Array).size()
		var share := 0.32 if rows <= 3 else 0.19
		var minimum := 170.0 if art.kind in ["jobs", "marks"] else 138.0
		var limit := 202.0 if art.kind == "marks" else 255.0
		art.custom_minimum_size = Vector2(0, clampf(size.y * share, minimum, limit))


func next_page() -> void:
	if page >= page_count() - 1:
		commit(Intent.HOWTO_DONE, {"play": then_play, "finished": true})
		return
	page += 1
	_refresh()


func prev_page() -> void:
	if page > 0:
		page -= 1
		_refresh()


func _refresh() -> void:
	build()
	scroll.scroll_vertical = 0
	if _title_label != null:
		_title_label.text = title()
	Juice.haptic(Juice.Haptic.TAP)


func _on_art_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_press_x = mb.position.x
		elif _press_x != INF:
			var dx := mb.position.x - _press_x
			_press_x = INF
			if dx < -60.0:
				next_page()
			elif dx > 60.0:
				prev_page()
