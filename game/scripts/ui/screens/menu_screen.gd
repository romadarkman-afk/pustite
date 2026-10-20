class_name MenuScreen
extends Screen


func screen_id() -> String:
	return "menu"


func field_ratio() -> float:
	return 0.32 / ThemeFactory.text_scale     # оставляем место трём режимам игры


func mood() -> Vector2:
	return Vector2(0.78, 1.2)


func ambience() -> StringName:
	return &"amb_night"


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

	body.add_child(W.label(L.t("menu.modes"), &"Speaker"))
	var camp := W.wrap(W.button(L.t("menu.mode_campaign"), &"Row"))
	camp.name = "Campaign"
	camp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camp.pressed.connect(func() -> void: emit_intent(Intent.OPEN_CAMPAIGN))
	body.add_child(camp)
	body.add_child(W.label(L.t("menu.mode_campaign_desc"), &"Small"))
	var start := W.wrap(W.button(L.t("menu.mode_solo"), &"Primary"))
	start.name = "Start"
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(func() -> void: emit_intent(Intent.START_SOLO))
	body.add_child(start)
	body.add_child(W.label(L.t("menu.mode_solo_desc"), &"Small"))
	var online := W.wrap(W.button(L.t("menu.mode_online"), &"Row"))
	online.name = "OnlineSoon"
	online.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online.disabled = true
	body.add_child(online)
	body.add_child(W.label(L.t("menu.mode_online_desc"), &"Small"))

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
	var book := W.button(L.t("menu.book"), &"Row")
	book.name = "Book"
	book.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	book.pressed.connect(func() -> void: emit_intent(Intent.OPEN_BOOK))
	var settings := W.button(L.t("settings.title"), &"Row")
	settings.name = "Settings"
	settings.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	settings.pressed.connect(func() -> void: emit_intent(Intent.OPEN_SETTINGS))
	body.add_child(W.fit_row([how, lb, custom_b, wardrobe, book, settings] as Array[Button]))

	footer.add_child(daily_button())        # испытание дня — на виду, рядом с режимами
	footer.add_child(W.fit_row(dbs))
	var footer_actions: Array[Button] = []
	if not Campaign.is_new():
		var chapter := Campaign.current()
		var resume := W.wrap(W.button(L.t("camp.continue", {"title": L.t("camp.%s.title" % chapter)}), &"RowOn"))
		resume.name = "Continue"
		resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resume.pressed.connect(func() -> void: emit_intent(Intent.PLAY_CHAPTER, {"id": chapter}))
		footer_actions.append(resume)
	var exit := W.button(L.t("ui.exit"), &"Ghost")
	exit.name = "Exit"
	exit.pressed.connect(func() -> void:
		var choice: int = await ActionSheet.ask(self, L.t("menu.exit_confirm"), PackedStringArray([L.t("ui.exit"), L.t("ui.back")]))
		if choice == 0:
			emit_intent(Intent.EXIT))
	footer_actions.append(exit)
	footer.add_child(W.fit_row(footer_actions))
	(start if Campaign.is_new() else footer_actions[0]).call_deferred("grab_focus")
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
