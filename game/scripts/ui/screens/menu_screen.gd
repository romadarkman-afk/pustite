class_name MenuScreen
extends Screen


func screen_id() -> String:
	return "menu"


func field_ratio() -> float:
	return 0.38 / ThemeFactory.text_scale     # крупный текст: посёлок ниже, кнопки видны без прокрутки


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
	var name_button := W.wrap(W.button(SocialContent.player_name_label(Save.player_display_name()), &"Row"))
	name_button.name = "PlayerName"
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.pressed.connect(func() -> void: emit_intent(Intent.SET_PLAYER_NAME))
	body.add_child(name_button)
	var dbs: Array[Button] = []
	var custom_b: Button = null
	for d: String in ["easy", "normal", "hard", "custom"]:
		var b := W.button(Difficulty.title(d) + ("…" if d == "custom" else ""), &"Row")
		var key := d
		b.pressed.connect(func() -> void:
			if key == "custom":
				emit_intent(Intent.OPEN_SETTINGS)
			else:
				emit_intent(Intent.SET_DIFFICULTY, {"d": key}))
		if d == "custom":
			custom_b = b
		else:
			dbs.append(b)
		_diff_buttons[d] = b
	# «Своя…» открывает настройки — ей место рядом с «Как играть» и языком, а не в лестнице
	var how := W.button(L.t("menu.howto"), &"Row")
	how.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	how.pressed.connect(func() -> void: emit_intent(Intent.OPEN_HOWTO))
	var lb := lang_button(self)
	lb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	custom_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var wardrobe := W.button(L.t("cos.title"), &"Row")
	wardrobe.name = "Wardrobe"
	wardrobe.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wardrobe.pressed.connect(func() -> void: emit_intent(Intent.OPEN_WARDROBE))
	body.add_child(W.fit_row([how, lb, custom_b, wardrobe] as Array[Button]))

	footer.add_child(daily_button())        # испытание дня — на виду, рядом с «Играть»
	footer.add_child(W.fit_row(dbs))
	# «Играть» — самая нижняя, под большим пальцем; строка о партии — над ступенями сложности
	var start := W.button(L.t("menu.play"))
	start.pressed.connect(func() -> void: emit_intent(Intent.START))
	footer.add_child(start)
	_diff_note = W.label("", &"Small")
	body.add_child(_diff_note)          # над кнопкой «Играть»: при крупном тексте подвал не съедает экран
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
	var name_button := find_child("PlayerName", true, false) as Button
	if name_button != null:
		name_button.text = SocialContent.player_name_label(Save.player_display_name())


## Испытание дня: правило сегодняшнего дня; сыграно — итог, серия и «новое завтра».
func daily_button() -> Button:
	var date := Challenge.today()
	var done := Save.daily_last == date
	var streak := Save.daily_streak_on(date)
	var txt := L.t("daily.title") + ": " + Challenge.title(Challenge.rule_for(date))
	if done:
		txt = L.t("daily.won" if Save.daily_won else "daily.lost") + ". " + L.t("daily.tomorrow")
	if streak > 0:
		txt += " · " + L.t("daily.streak", {"n": streak})
	var b := W.wrap(W.button(txt, &"RowOn" if not done else &"Row"))
	b.name = "Daily"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = done
	b.pressed.connect(func() -> void: emit_intent(Intent.DAILY))
	return b


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
