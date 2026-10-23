class_name SettingsScreen
extends Screen
## Ползунки строятся автоматически из @export_range полей GameConfig.

var cfg: GameConfig
var haptics: bool = true
var reset_hints: bool = false
var difficulty: String = "custom"
var _chips: Dictionary = {}
var _tab := "sound"
var _about_open := false
## Авторы записей звука и музыки с OpenGameArt.org (docs/sound-sources.md). Имена не переводятся.
const AUDIO_AUTHORS := "rubberduck, Robin Lamb, PolygonDan, SkyleTheFrench, Kistol, isaiah658, Ted Kerr, SketchMan3, RandomMind, AuraVoice, Nocturnal_Vanguard, HaelDB, marcelofg55, GboxMikeFozzy, Ogrebane."
var _taps := DebugScreen.TapCounter.new()


func screen_id() -> String:
	return "settings"


func title() -> String:
	return L.t("settings.title")


func mood() -> Vector2:
	return Vector2(0.8, 0.6)


func build() -> void:
	W.clear(body)
	W.clear(footer)
	var tab_buttons: Array[Button] = []
	for pair: Array in [["sound", L.t("settings.sound")], ["display", L.t("settings.tab_display")], ["controls", L.t("settings.tab_controls")], ["game", L.t("settings.difficulty")]]:
		var key := String(pair[0])
		var tab_button := W.button(String(pair[1]), &"RowOn" if _tab == key else &"Row")
		tab_button.name = "Tab_" + key
		tab_button.pressed.connect(func() -> void:
			_tab = key
			build())
		tab_buttons.append(tab_button)
	body.add_child(W.fit_row(tab_buttons))
	match _tab:
		"sound": _build_sound_tab()
		"display": _build_display_tab()
		"controls": _build_controls_tab()
		_: _build_game_tab()

	body.add_child(_about_block())
	body.add_child(_version_row())
	var go := W.button(L.t("settings.start"))
	go.pressed.connect(func() -> void: emit_intent(Intent.START, {"cfg": cfg, "haptics": haptics, "reset_hints": reset_hints, "difficulty": difficulty}))
	footer.add_child(go)
	var back := W.button(L.t("ui.back"), &"Ghost")
	back.pressed.connect(func() -> void: emit_intent(Intent.BACK, {"cfg": cfg, "haptics": haptics, "reset_hints": reset_hints, "difficulty": difficulty}))
	footer.add_child(back)


## «Об игре»: авторы записей звука и шрифтов раскрываются по нажатию (аудит F-17).
func _about_block() -> Control:
	var box := VBoxContainer.new()
	box.name = "About"
	var toggle := W.button(L.t("about.title"), &"RowOn" if _about_open else &"Row")
	toggle.name = "AboutToggle"
	toggle.pressed.connect(func() -> void:
		_about_open = not _about_open
		build())
	box.add_child(toggle)
	if _about_open:
		var text := W.label("%s %s\n%s\n%s" % [L.t("about.audio"), AUDIO_AUTHORS, L.t("about.own"), L.t("about.fonts")], &"Small")
		text.name = "AboutText"
		box.add_child(text)
	return box


## Строка версии внизу. Пять быстрых тапов в отладочной сборке открывают скрытое меню (TASK-096).
func _version_row() -> Label:
	var v := W.label("v%s" % ProjectSettings.get_setting("application/config/version", "?"), &"Small")
	v.name = "Version"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.modulate = Color(1, 1, 1, 0.5)
	v.custom_minimum_size = Vector2(0, 40)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	if DebugScreen.available():
		v.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				if _taps.hit(Time.get_ticks_msec()):
					emit_intent(Intent.OPEN_DEBUG, {}))
	return v


func _build_sound_tab() -> void:
	body.add_child(W.label(L.t("settings.sound"), &"Hint"))
	for row: Array in [[&"Master", L.t("settings.master")], [&"Music", L.t("settings.music")], [&"Sfx", L.t("settings.sfx")], [&"Ambience", L.t("settings.ambience")]]:
		body.add_child(_volume_row(row[0], row[1]))
	body.add_child(W.label(L.t("settings.sound_note"), &"Small"))


func _build_display_tab() -> void:
	var simple := W.button(L.t("settings.simplified_graphics"), &"RowOn" if Save.simplified_graphics else &"Row")
	simple.name = "SimplifiedGraphics"
	simple.pressed.connect(func() -> void:
		Save.set_simplified_graphics(not Save.simplified_graphics)
		Nav.set_simplified_graphics(Save.simplified_graphics)
		build())
	body.add_child(simple)
	if OS.has_feature("mobile"):
		body.add_child(W.label(L.t("settings.mobile_display"), &"Small"))
		return
	var full := W.button(L.t("settings.fullscreen" if Save.window_fullscreen else "settings.windowed"), &"RowOn" if Save.window_fullscreen else &"Row")
	full.name = "Fullscreen"
	full.pressed.connect(func() -> void:
		Save.set_display(not Save.window_fullscreen, Save.window_resolution)
		build())
	body.add_child(full)
	body.add_child(W.label(L.t("settings.resolution"), &"Hint"))
	var resolutions := W.hbox(8)
	for res: Vector2i in [Vector2i(720, 1280), Vector2i(900, 1600), Vector2i(1080, 1920)]:
		var key := res
		var label := "%d × %d" % [res.x, res.y]
		var b := W.button(label, &"RowOn" if Save.window_resolution == res else &"Row", 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: Save.set_display(Save.window_fullscreen, key); build())
		resolutions.add_child(b)
	body.add_child(resolutions)


func _build_controls_tab() -> void:
	body.add_child(W.label(L.t("settings.input_help"), &"Tale"))
	body.add_child(W.label(L.t("settings.haptics"), &"Hint"))
	var levels := W.hbox(8)
	levels.name = "HapticLevels"
	var level_keys := ["settings.haptic_off", "settings.haptic_weak", "settings.haptic_strong"]
	for i in range(3):
		var lb := W.button(L.t(level_keys[i]), &"RowOn" if i == Save.haptic_level else &"Row")
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.name = "Haptic_%d" % i
		var lvl := i
		lb.pressed.connect(func() -> void:
			Save.set_haptic_level(lvl)
			haptics = lvl > 0
			Juice.haptic(Juice.Haptic.KNOCK)           # сразу чувствуешь, какая ступень
			for k in range(levels.get_child_count()):
				(levels.get_child(k) as Button).theme_type_variation = &"RowOn" if k == lvl else &"Row")
		levels.add_child(lb)
	body.add_child(levels)


func _build_game_tab() -> void:
	body.add_child(W.label(L.t("settings.lang"), &"Hint"))
	body.add_child(MenuScreen.lang_button(self))
	body.add_child(W.label(L.t("settings.text"), &"Hint"))
	var sizes := W.hbox(8)
	sizes.name = "TextSizes"
	for i in range(ThemeFactory.TEXT_SCALES.size()):
		var tb := W.button("A" + "+".repeat(i), &"RowOn" if i == Save.text_size else &"Row")
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", roundi(20 * ThemeFactory.TEXT_SCALES[i]))
		var idx := i
		tb.pressed.connect(func() -> void: emit_intent(Intent.SET_TEXT, {"size": idx}))
		sizes.add_child(tb)
	body.add_child(sizes)
	body.add_child(W.label(L.t("settings.difficulty"), &"Hint"))
	var presets := W.hbox(8)
	_chips.clear()
	for d: String in Difficulty.LADDER:
		var b := W.button(Difficulty.title(d), &"RowOn" if d == difficulty else &"Row")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key := d
		b.pressed.connect(func() -> void:
			cfg = Difficulty.preset(key)
			difficulty = key
			build())
		presets.add_child(b)
		_chips[d] = b
	body.add_child(presets)
	body.add_child(W.label(L.t("diff.note_custom" if difficulty == "custom" else "diff.note", {"d": Difficulty.title(difficulty), "text": Difficulty.describe(difficulty, cfg)}), &"Small"))
	for prop: Dictionary in cfg.get_property_list():
		if not (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) or int(prop.hint) != PROPERTY_HINT_RANGE:
			continue
		var key: String = prop.name
		var range_parts := String(prop.hint_string).split(",")
		var row := W.vbox(2)
		var top := W.hbox(10)
		var lbl := W.label(L.t(String(GameConfig.LABELS.get(key, key))), &"Body")
		var val := W.label(str(cfg.get(key)), &"Body")
		val.add_theme_color_override("font_color", ThemeFactory.LAMP)
		val.size_flags_horizontal = Control.SIZE_SHRINK_END
		val.autowrap_mode = TextServer.AUTOWRAP_OFF
		top.add_child(lbl)
		top.add_child(val)
		var sl := HSlider.new()
		sl.min_value = float(range_parts[0])
		sl.max_value = float(range_parts[1])
		sl.step = float(range_parts[2]) if range_parts.size() > 2 else 1.0
		sl.value = float(cfg.get(key))
		sl.custom_minimum_size = Vector2(0, ThemeFactory.TOUCH)
		sl.focus_mode = Control.FOCUS_NONE
		sl.value_changed.connect(func(v: float) -> void:
			cfg.set(key, int(v))
			val.text = str(int(v))
			_to_custom())
		row.add_child(top)
		row.add_child(sl)
		body.add_child(row)
	var hr := W.button(L.t("settings.hints_reset" if reset_hints else "settings.hints"), &"Row")
	hr.pressed.connect(func() -> void: reset_hints = true; hr.text = L.t("settings.hints_reset"))
	body.add_child(hr)
	body.add_child(W.label(L.t("settings.note"), &"Small"))



## Тронули ползунок: это уже своя сложность.
func _to_custom() -> void:
	if difficulty == "custom":
		return
	difficulty = "custom"
	for k: String in _chips:
		(_chips[k] as Button).theme_type_variation = &"Row"



## Громкость канала: слышно сразу при движении, в файл — когда отпустили ползунок.
func _volume_row(bus: StringName, title_text: String) -> Control:
	var row := W.hbox(14)
	var lab := W.label(title_text, &"Body")
	lab.custom_minimum_size = Vector2(150, 0)
	row.add_child(lab)
	var sl := HSlider.new()
	sl.name = "Volume_" + String(bus)
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(Save.volumes.get(bus, 0.8))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(0, ThemeFactory.TOUCH)
	sl.focus_mode = Control.FOCUS_NONE
	var pct := W.label("%d%%" % int(round(sl.value * 100)), &"Small")
	pct.custom_minimum_size = Vector2(64, 0)
	sl.value_changed.connect(func(v: float) -> void:
		Save.set_volume(bus, v, false)
		pct.text = "%d%%" % int(round(v * 100))
		if bus == &"Sfx":
			Sfx.play(&"tap"))
	sl.drag_ended.connect(func(_changed: bool) -> void: Save.flush())
	row.add_child(sl)
	row.add_child(pct)
	return row
