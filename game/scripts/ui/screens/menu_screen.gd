class_name MenuScreen
extends Screen


func screen_id() -> String:
	return "menu"


func field_ratio() -> float:
	return 0.4


func mood() -> Vector2:
	return Vector2(1.0, 1.2)


func build() -> void:
	var t := W.label("Пустите", &"Title")
	t.add_theme_font_size_override("font_size", 74)
	body.add_child(t)
	body.add_child(W.label(
		"Ночью на улице никто не выживает.\nУбежищ меньше, чем людей.\n\nКто-то стоит у двери и просит впустить. Кто-то внутри решает.",
		&"Tale"))
	body.add_child(W.gap(6))
	body.add_child(W.label("Упыри среди вас. Они и сами не знают друг друга.", &"Hint"))

	var start := W.button("Начать партию")
	start.pressed.connect(func() -> void: emit_intent(Intent.START))
	footer.add_child(start)
	var opts := W.button("Настроить баланс", &"Ghost")
	opts.pressed.connect(func() -> void: emit_intent(Intent.OPEN_SETTINGS))
	footer.add_child(opts)
	for i in range(body.get_child_count()):
		Juice.pop_in(body.get_child(i) as Control, 0.08 * i)
