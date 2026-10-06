class_name SettingsScreen
extends Screen
## Ползунки строятся автоматически из @export_range полей GameConfig.

var cfg: GameConfig
var haptics: bool = true


func screen_id() -> String:
	return "settings"


func title() -> String:
	return "Баланс"


func mood() -> Vector2:
	return Vector2(0.8, 0.6)


func build() -> void:
	W.clear(body)
	W.clear(footer)

	var presets := W.hbox(10)
	for p: Array in [["7 игроков", "res://config/balance_7.tres"], ["10 игроков", "res://config/balance_10.tres"]]:
		var b := W.button(p[0], &"Quick")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var path: String = p[1]
		b.pressed.connect(func() -> void:
			cfg = (load(path) as GameConfig).duplicate() as GameConfig
			build())
		presets.add_child(b)
	body.add_child(presets)

	for prop: Dictionary in cfg.get_property_list():
		if not (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) or int(prop.hint) != PROPERTY_HINT_RANGE:
			continue
		var key: String = prop.name
		var range_parts := String(prop.hint_string).split(",")
		var row := W.vbox(2)
		var top := W.hbox(10)
		var lbl := W.label(GameConfig.LABELS.get(key, key), &"Body")
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
			val.text = str(int(v)))
		row.add_child(top)
		row.add_child(sl)
		body.add_child(row)

	var hb := W.button("Вибрация: %s" % ("включена" if haptics else "выключена"), &"Row")
	hb.pressed.connect(func() -> void:
		haptics = not haptics
		Juice.haptics_enabled = haptics
		hb.text = "Вибрация: %s" % ("включена" if haptics else "выключена"))
	body.add_child(hb)
	body.add_child(W.label(
		"Пресеты проверены прогоном по 1500 партий: люди выигрывают 49–53%. Сильнее всего баланс двигают число убежищ и ночей.",
		&"Small"))

	var go := W.button("Начать с этими настройками")
	go.pressed.connect(func() -> void: emit_intent(Intent.START, {"cfg": cfg, "haptics": haptics}))
	footer.add_child(go)
	var back := W.button("Назад", &"Ghost")
	back.pressed.connect(func() -> void: emit_intent(Intent.BACK, {"cfg": cfg, "haptics": haptics}))
	footer.add_child(back)
