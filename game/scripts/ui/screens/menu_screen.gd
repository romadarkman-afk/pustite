class_name MenuScreen
extends Screen


## Фоновые заставки главного меню. Две картинки держим в памяти для плавного перехода.
const MENU_ART: PackedStringArray = [
	"res://assets/scenes/end_upyri.jpg",
	"res://assets/scenes/end_people.jpg",
	"res://assets/scenes/a2c1.jpg",
	"res://assets/scenes/a1c1.jpg",
	"res://assets/scenes/river.jpg",
]

var difficulty: String = "easy"
var cfg: GameConfig
var _menu_art_nodes: Array[TextureRect] = []
var _menu_art_front := 0
var _menu_art_index := 0
var _menu_backdrop: Control


func screen_id() -> String:
	return "menu"


func field_ratio() -> float:
	return 0.0


func mood() -> Vector2:
	return Vector2(0.78, 1.2)


func ambience() -> StringName:
	return &"amb_night"


func ambience_volume_db() -> float:
	return -32.0


func music() -> StringName:
	return Sfx.menu_music()


func build() -> void:
	_install_menu_art()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER

	var brand := W.label(L.t("game.title"), &"Title")
	brand.name = "MenuTitle"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", ThemeFactory.fs(31))
	body.add_child(brand)
	var case_file := W.label(L.t("menu.case_file"), &"Speaker")
	case_file.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	case_file.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
	body.add_child(case_file)

	var modes := GridContainer.new()
	modes.name = "ModeCards"
	modes.columns = 2
	modes.add_theme_constant_override("h_separation", 8)
	modes.add_theme_constant_override("v_separation", 8)
	modes.add_child(_mode_tile(L.t("menu.mode_campaign"), "",
		"Campaign", &"RowOn", Intent.OPEN_CAMPAIGN))
	modes.add_child(_mode_tile(L.t("menu.mode_solo"), "",
		"Start", &"RowOn", Intent.START_SOLO))
	modes.add_child(_mode_tile(L.t("menu.online"), L.t("camp.soon"),
		"Online", &"Row", &"", true))
	modes.add_child(_mode_tile(L.t("settings.title"), "",
		"Settings", &"Row", Intent.OPEN_SETTINGS))
	body.add_child(modes)

	var more := W.button(L.t("menu.more"), &"Compact", 56)
	more.name = "More"
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
	more.pressed.connect(_open_more)
	body.add_child(more)

	var footer_actions: Array[Button] = []
	if not Campaign.is_new():
		var chapter := Campaign.current()
		var resume := W.button(L.t("ui.continue"), &"RowOn", 48)
		resume.name = "Continue"
		resume.tooltip_text = L.t("camp.continue", {"title": L.t("camp.%s.title" % chapter)})
		resume.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
		resume.pressed.connect(func() -> void: emit_intent(Intent.PLAY_CHAPTER, {"id": chapter}))
		footer_actions.append(resume)
	var exit := W.button(L.t("ui.exit"), &"Ghost", 48)
	exit.name = "Exit"
	exit.add_theme_font_size_override("font_size", ThemeFactory.fs(13))
	exit.pressed.connect(func() -> void:
		var choice: int = await ActionSheet.ask(self, L.t("menu.exit_confirm"), PackedStringArray([L.t("ui.exit"), L.t("ui.back")]))
		if choice == 0:
			emit_intent(Intent.EXIT))
	footer_actions.append(exit)
	footer.add_child(W.fit_row(footer_actions))
	refresh(difficulty, cfg)


func _install_menu_art() -> void:
	if not is_instance_valid(Nav.ui) or MENU_ART.is_empty():
		return
	_menu_backdrop = Control.new()
	_menu_backdrop.name = "MenuBackdrop"
	_menu_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Nav.ui.add_child(_menu_backdrop)
	Nav.ui.move_child(_menu_backdrop, 0)
	for i in range(2):
		var art := TextureRect.new()
		art.name = "MenuBackdrop%d" % i
		art.texture = load(MENU_ART[i % MENU_ART.size()]) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.modulate.a = 1.0 if i == 0 else 0.0
		art.visible = i == 0
		_menu_backdrop.add_child(art)
		_menu_art_nodes.append(art)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.56, 1.0])
	gradient.colors = PackedColorArray([
		Color(ThemeFactory.NIGHT, 0.12),
		Color(ThemeFactory.NIGHT, 0.48),
		Color(ThemeFactory.NIGHT, 1.0),
	])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(0.0, 1.0)
	var shade := TextureRect.new()
	shade.name = "MenuBackdropShade"
	shade.texture = gradient_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_backdrop.add_child(shade)

	var timer := Timer.new()
	timer.name = "MenuBackdropTimer"
	timer.wait_time = 6.5
	timer.autostart = true
	timer.timeout.connect(_advance_menu_art)
	add_child(timer)


func _exit_tree() -> void:
	if is_instance_valid(_menu_backdrop):
		_menu_backdrop.queue_free()


func _advance_menu_art() -> void:
	if _menu_art_nodes.size() != 2 or not is_inside_tree():
		return
	var back_index := 1 - _menu_art_front
	var incoming := _menu_art_nodes[back_index]
	var outgoing := _menu_art_nodes[_menu_art_front]
	_menu_art_index = (_menu_art_index + 1) % MENU_ART.size()
	incoming.texture = load(MENU_ART[_menu_art_index]) as Texture2D
	incoming.visible = true
	incoming.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(incoming, "modulate:a", 1.0, 1.15)
	tween.tween_property(outgoing, "modulate:a", 0.0, 1.15)
	tween.finished.connect(func() -> void:
		if not is_instance_valid(outgoing):
			return
		outgoing.visible = false
		_menu_art_front = back_index)


func _open_more() -> void:
	var daily_label := L.t("daily.title") + " · " + Challenge.title(Challenge.rule_for(Challenge.today()))
	if Save.daily_last == Challenge.today():
		daily_label = L.t("daily.won" if Save.daily_won else "daily.lost") + " · " + L.t("daily.tomorrow")
	var options := PackedStringArray([
		daily_label, L.t("menu.howto"), L.t("menu.look"), L.t("menu.book"),
		L.t("settings.lang"), L.t("menu.change_name"),
	])
	var actions: Array[StringName] = [
		&"daily", Intent.OPEN_HOWTO, Intent.OPEN_WARDROBE, Intent.OPEN_BOOK, &"language", &"name",
	]
	var choice: int = await ActionSheet.ask(self, L.t("menu.more"), options)
	if choice < 0 or choice >= actions.size():
		return
	match actions[choice]:
		&"daily":
			emit_intent(Intent.DAILY)
		&"language":
			await get_tree().process_frame
			await _choose_language(self)
		&"name":
			emit_intent(Intent.SET_PLAYER_NAME)
		Intent.OPEN_HOWTO:
			emit_intent(Intent.OPEN_HOWTO)
		Intent.OPEN_WARDROBE:
			emit_intent(Intent.OPEN_WARDROBE)
		Intent.OPEN_BOOK:
			emit_intent(Intent.OPEN_BOOK)

func _mode_tile(heading: String, detail: String, node_name: String, variation: StringName,
		action: StringName, disabled: bool = false) -> Button:
	var button := W.button("", variation, 60)
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.tooltip_text = heading if detail.is_empty() else heading + " · " + detail
	var text_box := W.vbox(1)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_box.offset_left = 9.0
	text_box.offset_right = -9.0
	var title_label := W.label(heading, &"Speaker")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", ThemeFactory.fs(14))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)
	if not detail.is_empty():
		var detail_label := W.label(detail, &"Small")
		detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_label.add_theme_font_size_override("font_size", ThemeFactory.fs(10))
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
	b.pressed.connect(func() -> void: _choose_language(s))
	return b


static func _choose_language(s: Screen) -> void:
	var names := PackedStringArray()
	for c: String in L.LANGS:
		names.append(String(L.NATIVE[c]))
	var i: int = await ActionSheet.ask(s, L.t("lang.pick"), names)
	if i >= 0 and i < L.LANGS.size() and L.LANGS[i] != L.code:
		s.emit_intent(Intent.SET_LANG, {"code": L.LANGS[i]})


func refresh(d: String, c: GameConfig) -> void:
	difficulty = d
	cfg = c
	var name_button := find_child("PlayerName", true, false) as Button
	if name_button != null:
		name_button.text = SocialContent.player_name_label(Save.player_display_name())
