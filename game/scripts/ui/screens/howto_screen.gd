class_name HowToScreen
extends Screen
## «Как играть»: карточки с картинками. Перед первой партией показываются три основные, один раз,
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
const CORE := 3                   ## сколько карточек видит новичок перед первой партией

var page: int = 0
var then_play: bool = false       ## true — после последней карточки начинается партия
var art: HowToArt
var _press_x := INF


func screen_id() -> String:
	return "howto"


## Сколько карточек в этом показе: перед первой партией основные, из меню все.
func page_count() -> int:
	return CORE if then_play else PAGES.size()


func title() -> String:
	return L.t("howto.title", {"a": page + 1, "b": page_count()})


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
	heading.add_theme_font_size_override("font_size", ThemeFactory.fs(28))
	body.add_child(heading)
	var description := W.label(L.t(String(card[1])), &"Tale")
	description.add_theme_font_size_override("font_size", ThemeFactory.fs(17))
	body.add_child(description)
	for row: Array in card[3]:
		var line := W.icon_line(String(row[0]), L.t(String(row[1])), &"Small", 40.0)
		line.name = "Row_" + String(row[0])
		body.add_child(line)
	var last := page == page_count() - 1
	if last and then_play:
		body.add_child(W.label(L.t("howto.more"), &"Hint"))

	var controls := W.hbox(8)
	if page > 0:
		var previous := W.button(L.t("ui.back"), &"Ghost", 50)
		previous.name = "PreviousPage"
		previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		previous.add_theme_font_size_override("font_size", ThemeFactory.fs(15))
		previous.pressed.connect(prev_page)
		controls.add_child(previous)
	var next := W.button(L.t(("menu.play" if then_play else "howto.got_it") if last else "ui.next"), &"Primary", 56)
	next.name = "NextPage"
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.add_theme_font_size_override("font_size", ThemeFactory.fs(16))
	next.pressed.connect(next_page)
	controls.add_child(next)
	footer.add_child(controls)

	if not last:
		var skip := W.button(L.t("ui.skip"), &"Ghost", 48)
		skip.name = "SkipHowTo"
		skip.add_theme_font_size_override("font_size", ThemeFactory.fs(14))
		skip.pressed.connect(func() -> void: commit(Intent.HOWTO_DONE, {"play": then_play}))
		footer.add_child(skip)


## Иллюстрация занимает меньше места, чтобы текст и навигация оставались видны.
func _size_art() -> void:
	if is_instance_valid(art):
		var rows: int = (PAGES[page][3] as Array).size()
		var share := 0.32 if rows <= 3 else 0.24
		art.custom_minimum_size = Vector2(0, clampf(size.y * share, 140.0, 230.0) if size.y > 0.0 else 180.0)


func next_page() -> void:
	if page >= page_count() - 1:
		commit(Intent.HOWTO_DONE, {"play": then_play})
		return
	page += 1
	_refresh()


func prev_page() -> void:
	if page > 0:
		page -= 1
		_refresh()


func _refresh() -> void:
	build()
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
