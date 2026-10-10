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
	var t := W.label(L.t("game.title"), &"Title")
	t.add_theme_font_size_override("font_size", 74)
	body.add_child(t)
	body.add_child(W.label(
		L.t("menu.tale"),
		&"Tale"))
	body.add_child(W.gap(6))
	body.add_child(W.label(L.t("menu.hint"), &"Hint"))
	var row0 := W.hbox(8)
	var how := W.button(L.t("menu.howto"), &"Row")
	how.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	how.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	how.pressed.connect(func() -> void: emit_intent(Intent.OPEN_HOWTO))
	row0.add_child(how)
	row0.add_child(lang_button(self))
	body.add_child(row0)

	var start := W.button(L.t("menu.play"))
	start.pressed.connect(func() -> void: emit_intent(Intent.START))
	footer.add_child(start)
	var row := W.hbox(8)
	for d: String in ["easy", "normal", "hard", "custom"]:
		var b := W.button(Difficulty.title(d) + ("…" if d == "custom" else ""), &"Row")
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
		_diff_note.text = L.t("diff.note", {"d": Difficulty.title(d), "text": Difficulty.describe(d, c)})


## Кнопка языка: название на самом языке, чтобы его нашёл тот, кто не читает текущий.
static func lang_button(s: Screen) -> Button:
	var b := W.button(String(L.NATIVE.get(L.code, L.code)), &"Row")
	b.name = "Lang"
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	b.pressed.connect(func() -> void:
		var names := PackedStringArray()
		for c: String in L.LANGS:
			names.append(String(L.NATIVE[c]))
		var i: int = await ActionSheet.ask(s, L.t("lang.pick"), names)
		if i >= 0 and L.LANGS[i] != L.code:
			s.emit_intent(Intent.SET_LANG, {"code": L.LANGS[i]}))
	return b
