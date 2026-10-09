class_name SettingsScreen
extends Screen
## Ползунки строятся автоматически из @export_range полей GameConfig.

var cfg: GameConfig
var haptics: bool = true
var reset_hints: bool = false
var difficulty: String = "custom"
var _chips: Dictionary = {}


func screen_id() -> String:
	return "settings"


func title() -> String:
	return "Настройки"


func mood() -> Vector2:
	return Vector2(0.8, 0.6)


func build() -> void:
	W.clear(body)
	W.clear(footer)

	# звук и вибрация — наверху: их меняют чаще, чем баланс
	body.add_child(W.label("Звук", &"Hint"))
	for row: Array in [[&"Music", "Музыка"], [&"Sfx", "Звуки"], [&"Ambience", "Атмосфера"]]:
		body.add_child(_volume_row(row[0], row[1]))
	var hb := W.button("Вибрация: %s" % ("включена" if haptics else "выключена"), &"Row")
	hb.pressed.connect(func() -> void:
		haptics = not haptics
		Juice.haptics_enabled = haptics
		hb.text = "Вибрация: %s" % ("включена" if haptics else "выключена"))
	body.add_child(hb)
	body.add_child(W.label("Сложность", &"Hint"))

	var presets := W.hbox(8)
	_chips.clear()
	for d: String in Difficulty.LADDER:
		var b := W.button(String(Difficulty.NAMES[d]), &"RowOn" if d == difficulty else &"Row")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key := d
		b.pressed.connect(func() -> void:
			cfg = Difficulty.preset(key)
			difficulty = key
			build())
		presets.add_child(b)
		_chips[d] = b
	body.add_child(presets)
	body.add_child(W.label(("Своя сложность: " if difficulty == "custom" else String(Difficulty.NAMES[difficulty]) + ": ") + Difficulty.describe(difficulty, cfg), &"Small"))

	for prop: Dictionary in cfg.get_property_list():
		if not (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) or int(prop.hint) != PROPERTY_HINT_RANGE:
			continue
		var key: String = prop.name
		var range_parts := String(prop.hint_string).split(",")
		var row := W.vbox(2)
		var top := W.hbox(10)
		var lbl := W.label(str(GameConfig.LABELS.get(key, key)), &"Body")
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

	var hr := W.button("Подсказки покажутся заново" if reset_hints else "Показать подсказки заново", &"Row")
	hr.pressed.connect(func() -> void:
		reset_hints = true
		hr.text = "Подсказки покажутся заново")
	body.add_child(hr)
	body.add_child(W.label(
		"Ступени проверены прогоном по 1500 партий. Сильнее всего баланс двигают число убежищ и ночей.",
		&"Small"))

	var go := W.button("Начать с этими настройками")
	go.pressed.connect(func() -> void: emit_intent(Intent.START, {"cfg": cfg, "haptics": haptics, "reset_hints": reset_hints, "difficulty": difficulty}))
	footer.add_child(go)
	var back := W.button("Назад", &"Ghost")
	back.pressed.connect(func() -> void: emit_intent(Intent.BACK, {"cfg": cfg, "haptics": haptics, "reset_hints": reset_hints, "difficulty": difficulty}))
	footer.add_child(back)



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
