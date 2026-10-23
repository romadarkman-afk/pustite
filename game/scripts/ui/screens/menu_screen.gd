class_name MenuScreen
extends Screen


const MENU_ART: Array[Texture2D] = [
	preload("res://assets/scenes/end_upyri.jpg"),
	preload("res://assets/scenes/end_people.jpg"),
	preload("res://assets/scenes/a2c1.jpg"),
	preload("res://assets/scenes/a1c1.jpg"),
	preload("res://assets/scenes/river.jpg"),
]

var difficulty: String = "easy"
var cfg: GameConfig
var _diff_buttons: Dictionary = {}
var _diff_note: Label
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


func music() -> StringName:
	return &"menu"


func build() -> void:
	_install_menu_art()
	body.add_theme_constant_override("separation", 10)

	var t := W.label(L.t("game.title"), &"Title")
	t.add_theme_font_size_override("font_size", 56)
	body.add_child(t)
	var case_file := W.label(L.t("menu.case_file"), &"Speaker")
	case_file.add_theme_font_size_override("font_size", ThemeFactory.fs(15))
	body.add_child(case_file)
	var hint := W.label(L.t("menu.hint"), &"Hint")
	hint.add_theme_font_size_override("font_size", ThemeFactory.fs(16))
	body.add_child(hint)

	var name_button := W.wrap(W.button(SocialContent.player_name_label(Save.player_display_name()), &"Row"))
	name_button.name = "PlayerName"
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.pressed.connect(func() -> void: emit_intent(Intent.SET_PLAYER_NAME))
	body.add_child(name_button)

	body.add_child(W.label(L.t("menu.modes"), &"Speaker"))
	var modes := GridContainer.new()
	modes.name = "ModeCards"
	modes.columns = 2
	modes.add_theme_constant_override("h_separation", 10)
	modes.add_theme_constant_override("v_separation", 10)
	modes.add_child(_mode_tile(L.t("menu.mode_campaign"), L.t("menu.mode_campaign_desc"), L.t("menu.play"),
		"Campaign", &"Primary", Intent.OPEN_CAMPAIGN))
	modes.add_child(_mode_tile(L.t("menu.mode_solo"), L.t("menu.mode_solo_desc"), L.t("menu.play"),
		"Start", &"RowOn", Intent.START_SOLO))
	modes.add_child(_mode_tile(L.t("menu.mode_online"), L.t("menu.mode_online_desc"), L.t("menu.mode_online"),
		"OnlineSoon", &"Row", &"", true))
	modes.add_child(_mode_tile(L.t("settings.title"), L.t("menu.settings_desc"), L.t("settings.title"),
		"Settings", &"Row", Intent.OPEN_SETTINGS))
	body.add_child(modes)

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
	body.add_child(W.fit_row(dbs))
	body.add_child(daily_button())
	body.add_child(W.fit_row([how, lb, custom_b, wardrobe, book]))
	body.add_child(W.label(L.t("menu.tale"), &"Tale"))

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
	var first_focus := find_child("Start", true, false) as Control if Campaign.is_new() else footer_actions[0]
	if first_focus != null:
		first_focus.call_deferred("grab_focus")
	_diff_note = W.label("", &"Small")
	body.add_child(_diff_note)
	refresh(difficulty, cfg)
	for i in range(body.get_child_count()):
		Juice.pop_in(body.get_child(i) as Control, 0.08 * i)


func _mode_tile(heading: String, description: String, action_text: String, node_name: String,
		variation: StringName, action: StringName, disabled: bool = false) -> PanelContainer:
	var card := W.panel(&"Card")
	card.custom_minimum_size = Vector2(140, ThemeFactory.TOUCH * 1.75)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := W.vbox(6)
	card.add_child(box)
	box.add_child(W.label(heading, &"Speaker"))
	var detail := W.label(description, &"Small")
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(detail)
	var button := W.wrap(W.button(action_text, variation))
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	if not disabled:
		button.pressed.connect(func() -> void: emit_intent(action))
	box.add_child(button)
	return card


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
		art.texture = MENU_ART[i % MENU_ART.size()]
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
	incoming.texture = MENU_ART[_menu_art_index]
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
