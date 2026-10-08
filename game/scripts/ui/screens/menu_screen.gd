class_name MenuScreen
extends Screen


func screen_id() -> String:
	return "menu"


func field_ratio() -> float:
	return 0.4


func mood() -> Vector2:
	return Vector2(1.0, 1.2)


var difficulty: String = "easy"
var cfg: GameConfig
var _diff_buttons: Dictionary = {}
var _diff_note: Label


func build() -> void:
	var t := W.label("Пустите", &"Title")
	t.add_theme_font_size_override("font_size", 74)
	body.add_child(t)
	body.add_child(W.label(
		"Ночью на улице никто не выживает.\nУбежищ меньше, чем людей.\n\nКто-то стоит у двери и просит впустить. Кто-то внутри решает.",
		&"Tale"))
	body.add_child(W.gap(6))
	body.add_child(W.label("Упыри среди вас. Они и сами не знают друг друга.", &"Hint"))

	var start := W.button("Играть")
	start.pressed.connect(func() -> void: emit_intent(Intent.START))
	footer.add_child(start)
	var row := W.hbox(8)
	for d: String in ["easy", "normal", "hard", "custom"]:
		var b := W.button(String(Difficulty.NAMES[d]) + ("…" if d == "custom" else ""), &"Row")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key := d
		b.pressed.connect(func() -> void:
			if key == "custom":
				emit_intent(Intent.OPEN_SETTINGS)
			else:
				emit_intent(Intent.SET_DIFFICULTY, {"d": key}))
		row.add_child(b)
		_diff_buttons[d] = b
	footer.add_child(row)
	_diff_note = W.label("", &"Small")
	footer.add_child(_diff_note)
	refresh(difficulty, cfg)
	for i in range(body.get_child_count()):
		Juice.pop_in(body.get_child(i) as Control, 0.08 * i)



## Nav вызывает после смены сложности: подсветка ступени и строка о партии.
func refresh(d: String, c: GameConfig) -> void:
	difficulty = d
	cfg = c
	for k: String in _diff_buttons:
		(_diff_buttons[k] as Button).theme_type_variation = &"RowOn" if k == d else &"Row"
	if c != null and _diff_note != null:
		_diff_note.text = "%s: %s" % [Difficulty.NAMES[d], Difficulty.describe(d, c)]
