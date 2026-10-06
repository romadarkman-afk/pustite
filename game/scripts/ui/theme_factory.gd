class_name ThemeFactory
extends RefCounted
## Один Theme на всё приложение. Узлы просто ставят theme_type_variation.
## В v0.1 стиль вешался вручную на каждую ноду — сотни лишних объектов.

const NIGHT := Color("0a1013")
const PANEL := Color("162126")
const PANEL_2 := Color("1d2b32")
const EDGE := Color("26363d")
const BONE := Color("e3d9c8")
const FROST := Color("74898f")
const LAMP := Color("d9a24e")
const LAMP_D := Color("8a6c39")
const BLOOD := Color("8c3a33")
const MINE := Color("20302a")
const MINE_EDGE := Color("2f463a")
const CLEAR := Color(0, 0, 0, 0)

## Минимальная высота касания в пикселях вьюпорта.
## Вьюпорт 720 по ширине → на телефоне 1080 px масштаб 1.5 → 88 px ≈ 50 dp (норма Android ≥ 48 dp).
const TOUCH := 88


static func build() -> Theme:
	var t := Theme.new()
	var ui_font: FontFile = load("res://fonts/UI.ttf")
	t.default_font = ui_font
	t.default_font_size = 23

	var serif_regular := _serif(400)
	var serif_strong := _serif(560)

	t.set_color("font_color", "Label", BONE)
	t.set_constant("line_spacing", "Label", 6)

	_label(t, "Title", serif_strong, 52, BONE, 10)
	_label(t, "Tale", serif_regular, 27, BONE, 11)
	_label(t, "Body", ui_font, 23, BONE, 7)
	_label(t, "Small", ui_font, 20, FROST, 6)
	_label(t, "Speaker", ui_font, 18, LAMP_D, 2)
	_label(t, "Hint", ui_font, 19, LAMP_D, 5)
	_label(t, "Clock", ui_font, 23, FROST, 0)
	_label(t, "Danger", ui_font, 22, BLOOD, 6)

	_button(t, "Primary", LAMP, Color("1c1408"), LAMP, 25)
	_button(t, "Ghost", CLEAR, FROST, EDGE, 23)
	_button(t, "Danger", CLEAR, BLOOD, BLOOD, 23)
	_button(t, "Row", PANEL, BONE, EDGE, 23)
	_button(t, "RowOn", PANEL_2, BONE, LAMP, 23)
	_button(t, "Chip", CLEAR, FROST, EDGE, 19, 10)
	_button(t, "ChipYou", CLEAR, LAMP, LAMP_D, 19, 10)
	_button(t, "ChipDead", CLEAR, Color("54403d"), Color("3a2926"), 19, 10)
	_button(t, "ChipUpyr", CLEAR, BLOOD, BLOOD, 19, 10)
	_button(t, "Quick", PANEL, LAMP, EDGE, 20, 12)

	_panel(t, "Bubble", PANEL, EDGE)
	_panel(t, "BubbleMine", MINE, MINE_EDGE)
	_panel(t, "Card", PANEL, EDGE)
	_panel(t, "Sheet", Color("0f171b"), EDGE, 18)

	var le_normal := _box(NIGHT, EDGE)
	var le_focus := _box(NIGHT, LAMP_D)
	t.set_stylebox("normal", "LineEdit", le_normal)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", le_normal)
	t.set_color("font_color", "LineEdit", BONE)
	t.set_color("font_placeholder_color", "LineEdit", Color(FROST, 0.7))
	t.set_color("caret_color", "LineEdit", LAMP)
	t.set_font_size("font_size", "LineEdit", 23)

	var track := StyleBoxFlat.new()
	track.bg_color = EDGE
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	track.set_corner_radius_all(3)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = LAMP_D
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var knob := _circle(38, LAMP)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)

	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(EDGE, 0.0)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(FROST, 0.35)
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", bar)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)

	t.set_constant("h_separation", "HFlowContainer", 8)
	t.set_constant("v_separation", "HFlowContainer", 8)
	return t


static func _serif(weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load("res://fonts/Lora.ttf")
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	f.variation_opentype = {tag: weight}
	return f


static func _label(t: Theme, name: StringName, font: Font, size: int, col: Color, spacing: int) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, col)
	t.set_constant("line_spacing", name, spacing)


static func _box(bg: Color, border: Color, radius: int = 4, pad: int = 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 2
	s.content_margin_right = pad + 2
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


static func _button(t: Theme, name: StringName, bg: Color, fg: Color, edge: Color, size: int, pad: int = 20) -> void:
	t.set_type_variation(name, "Button")
	t.set_stylebox("normal", name, _box(bg, edge, 4, pad))
	t.set_stylebox("hover", name, _box(bg, edge, 4, pad))
	t.set_stylebox("pressed", name, _box(bg.darkened(0.2) if bg.a > 0 else Color(edge, 0.25), edge, 4, pad))
	t.set_stylebox("hover_pressed", name, _box(bg.darkened(0.2) if bg.a > 0 else Color(edge, 0.25), edge, 4, pad))
	t.set_stylebox("disabled", name, _box(Color(bg, bg.a * 0.35), Color(edge, 0.35), 4, pad))
	t.set_stylebox("focus", name, StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, name, fg)
	t.set_color("font_disabled_color", name, Color(fg, 0.4))
	t.set_font_size("font_size", name, size)


static func _panel(t: Theme, name: StringName, bg: Color, edge: Color, pad: int = 18) -> void:
	t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", name, _box(bg, edge, 4, pad))


static func _circle(d: int, col: Color) -> ImageTexture:
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in range(d):
		for x in range(d):
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)
