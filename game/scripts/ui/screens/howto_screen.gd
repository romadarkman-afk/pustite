class_name HowToScreen
extends Screen
## «Как играть»: три карточки с картинками. Перед первой партией — один раз,
## потом по кнопке в меню. Листается кнопкой «Дальше» и свайпом.

const PAGES := [
	["День", "В посёлке живут люди, а среди них упыри. Упыри выглядят как все. Ты — житель с фонарём.\n\nДнём все на площади. Нажми на жителя: обвини, позови ночевать вместе или спроси, где ночует. Красный глаз над головой — посёлок его подозревает.\n\nНажми на значок дела: вода, дрова, фонари. Чем больше запасов, тем светлее ночью. Упыри делают вид, что работают, а то и портят сделанное. Иногда на площади появляется ящик: кто первым откроет, тому находка."],
	["Ночь", "Вечером звонит колокол, и все бегут по домам. Пока звенит, нажми на дом. Убежищ меньше, чем людей: кто остался на улице, почти не доживёт до утра.\n\nОдин в доме тоже рискует. Днём договорись, с кем ночуешь, и подправь треснувший оберег: в дом с расколотым приходит тварь из леса."],
	["Дверь", "Кто первым добежал до дома, тот решает, кого впустить.\n\nВпустишь упыря — до утра не доживёшь. Не впустишь никого — останешься один. Утром смотри, кто где ночевал и кто соврал.\n\nБывает, стучат голосом того, кто сейчас в другом доме или уже погиб. Это Подражатель: не открывай.\n\nУ людей бывают роли: старожил, знахарь, староста. Днём можно один раз ударить в колокол и сразу голосовать. Всё, что известно о каждом, — в «Дневнике»."],
]

var page: int = 0
var then_play: bool = false       ## true — после последней карточки начинается партия
var art: HowToArt
var _press_x := INF


func screen_id() -> String:
	return "howto"


func title() -> String:
	return "Как играть · %d из %d" % [page + 1, PAGES.size()]


func mood() -> Vector2:
	return Vector2(0.8, 0.6)


func build() -> void:
	W.clear(body)
	W.clear(footer)
	art = HowToArt.new()
	art.setup(page)
	_size_art()
	if not resized.is_connected(_size_art):
		resized.connect(_size_art)
	art.gui_input.connect(_on_art_input)
	body.add_child(art)
	body.add_child(W.label(String(PAGES[page][0]), &"Title"))
	body.add_child(W.label(String(PAGES[page][1]), &"Tale"))
	var last := page == PAGES.size() - 1
	var next := W.button(("Играть" if then_play else "Понятно") if last else "Дальше")
	next.pressed.connect(next_page)
	footer.add_child(next)
	if not last:
		var skip := W.button("Пропустить", &"Ghost")
		skip.pressed.connect(func() -> void: commit(Intent.HOWTO_DONE, {"play": then_play}))
		footer.add_child(skip)
	if _clock != null:
		pass


## Картинка — 42% высоты экрана. Пересчёт при каждом изменении размера: первая
## карточка строится раньше, чем экран узнаёт свою высоту.
func _size_art() -> void:
	if is_instance_valid(art):
		art.custom_minimum_size = Vector2(0, maxf(260.0, size.y * 0.42) if size.y > 0.0 else 420.0)


func next_page() -> void:
	if page >= PAGES.size() - 1:
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
