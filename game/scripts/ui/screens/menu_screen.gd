class_name MenuScreen
extends Screen


var difficulty: String = "easy"
var cfg: GameConfig


func screen_id() -> String:
	return "menu"


func field_ratio() -> float:
	# Живая деревня с жителями остаётся на экране над плитками.
	return 0.40


func mood() -> Vector2:
	return Vector2(0.78, 1.2)


func ambience() -> StringName:
	return &"amb_night"


func ambience_volume_db() -> float:
	return -32.0


func music() -> StringName:
	return Sfx.menu_music()


func build() -> void:
	body.add_theme_constant_override("separation", 4)

	var title_label := W.label(L.t("game.title"), &"Title")
	title_label.add_theme_font_size_override("font_size", ThemeFactory.fs(29))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title_label)

	var case_file := W.label(L.t("menu.case_file"), &"Speaker")
	case_file.add_theme_font_size_override("font_size", ThemeFactory.fs(12))
	case_file.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(case_file)

	var name_button := W.button(SocialContent.player_name_label(Save.player_display_name()), &"Compact", 46)
	name_button.name = "PlayerName"
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.add_theme_font_size_override("font_size", ThemeFactory.fs(14))
	name_button.pressed.connect(func() -> void: emit_intent(Intent.SET_PLAYER_NAME))
	body.add_child(name_button)

	var modes := GridContainer.new()
	modes.name = "ModeCards"
	modes.columns = 2
	modes.add_theme_constant_override("h_separation", 8)
	modes.add_theme_constant_override("v_separation", 8)
	modes.add_child(_mode_tile(L.t("menu.mode_campaign"), L.t("menu.mode_campaign_desc"),
		"Campaign", &"RowOn", Intent.OPEN_CAMPAIGN))
	modes.add_child(_mode_tile(L.t("menu.mode_solo"), L.t("menu.mode_solo_desc"),
		"Start", &"RowOn", Intent.START_SOLO))
	modes.add_child(_mode_tile(L.t("menu.online"), L.t("camp.soon"),
		"Online", &"Row", &"", true))
	modes.add_child(_mode_tile(L.t("settings.title"), L.t("settings.sound"),
		"Settings", &"Row", Intent.OPEN_SETTINGS))
	body.add_child(modes)

	var daily := daily_button()
	body.add_child(daily)

	var utility := GridContainer.new()
	utility.name = "MenuTools"
	utility.columns = 2
	utility.add_theme_constant_override("h_separation", 8)
	utility.add_theme_constant_override("v_separation", 6)

	var how := _small_button(L.t("menu.howto"), "HowTo")
	how.pressed.connect(func() -> void: emit_intent(Intent.OPEN_HOWTO))
	utility.add_child(how)

	var language := lang_button(self)
	language.custom_minimum_size.y = 48
	language.add_theme_font_size_override("font_size", ThemeFactory.fs(14))
	utility.add_child(language)

	var wardrobe := _small_button(L.t("menu.look"), "Wardrobe")
	wardrobe.pressed.connect(func() -> void: emit_intent(Intent.OPEN_WARDROBE))
	utility.add_child(wardrobe)

	var book := _small_button(L.t("menu.book"), "Book")
	book.pressed.connect(func() -> void: emit_intent(Intent.OPEN_BOOK))
	utility.add_child(book)
	body.add_child(utility)

	var footer_actions: Array[Button] = []
	if not Campaign.is_new():
		var chapter := Campaign.current()
		var resume := W.button(L.t("camp.continue", {"title": L.t("camp.%s.title" % chapter)}), &"RowOn", 44)
		resume.name = "Continue"
		resume.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
		resume.pressed.connect(func() -> void: emit_intent(Intent.PLAY_CHAPTER, {"id": chapter}))
		footer_actions.append(resume)
	var exit := W.button(L.t("ui.exit"), &"Ghost", 44)
	exit.name = "Exit"
	exit.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
	exit.pressed.connect(func() -> void:
		var choice: int = await ActionSheet.ask(self, L.t("menu.exit_confirm"), PackedStringArray([L.t("ui.exit"), L.t("ui.back")]))
		if choice == 0:
			emit_intent(Intent.EXIT))
	footer_actions.append(exit)
	footer.add_child(W.fit_row(footer_actions))
	refresh(difficulty, cfg)


func _mode_tile(heading: String, detail: String, node_name: String, variation: StringName,
		action: StringName, disabled: bool = false) -> Button:
	var button := W.button("", variation, 64)
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.tooltip_text = heading + " · " + detail
	var text_box := W.vbox(1)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_box.offset_left = 9.0
	text_box.offset_right = -9.0
	var title_label := W.label(heading, &"Speaker")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", ThemeFactory.fs(15))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)
	var detail_label := W.label(detail, &"Small")
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", ThemeFactory.fs(11))
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(detail_label)
	button.add_child(text_box)
	if not disabled:
		button.pressed.connect(func() -> void: emit_intent(action))
	return button


func _small_button(text: String, node_name: String) -> Button:
	var button := W.button(text, &"Compact", 42)
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
	return button


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
	var b := W.wrap(W.button(txt, &"RowOn" if not done else &"Row", 44))
	b.name = "Daily"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
	b.disabled = done
	b.pressed.connect(func() -> void: emit_intent(Intent.DAILY))
	return b


## Кнопка языка: название на самом языке, чтобы его нашёл тот, кто не читает текущий.
static func lang_button(s: Screen) -> Button:
	var b := W.button(String(L.NATIVE.get(L.code, L.code)), &"Row", 42)
	b.name = "Lang"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	b.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
	b.pressed.connect(func() -> void:
		var names := PackedStringArray()
		for c: String in L.LANGS:
			names.append(String(L.NATIVE[c]))
		var i: int = await ActionSheet.ask(s, L.t("lang.pick"), names)
		if i >= 0 and L.LANGS[i] != L.code:
			s.emit_intent(Intent.SET_LANG, {"code": L.LANGS[i]}))
	return b


func refresh(d: String, c: GameConfig) -> void:
	difficulty = d
	cfg = c
	var name_button := find_child("PlayerName", true, false) as Button
	if name_button != null:
		name_button.text = SocialContent.player_name_label(Save.player_display_name())
