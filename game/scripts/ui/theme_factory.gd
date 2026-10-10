class_name ThemeFactory
extends RefCounted
## Один Theme на всё приложение. Узлы просто ставят theme_type_variation.
## Стиль «уютный ужас»: глубокий фиолетово-чёрный фон, стеклянные панели,
## тёплый янтарь, мягкий округлый шрифт Nunito (лицензия OFL, fonts/Nunito-OFL.txt).

const NIGHT := Color("110e1c")
const PANEL := Color(0.10, 0.09, 0.16, 0.9)
const PANEL_2 := Color("2a2440")
const EDGE := Color(1, 1, 1, 0.14)
const BONE := Color("f6f1e8")
const FROST := Color("a3a8c6")
const LAMP := Color("ffb54d")
const LAMP_D := Color("e0a050")
const BLOOD := Color("ff6b6b")
const MINE := Color("2d2618")
const MINE_EDGE := Color("e0a050")
const RADIUS := 24

static var _fonts: Dictionary = {}


## Шрифт Nunito нужной толщины: 600 — текст, 800 — кнопки и имена, 900 — заголовки.
## Запасные шрифты письменностей, которых нет в Nunito: иероглифы (урезаны до ~3900 частых)
## и деванагари. Подключены к самому Nunito, поэтому работают во всех надписях и списке языков.
const FALLBACKS: PackedStringArray = ["res://fonts/NotoSansSC.ttf", "res://fonts/NotoSansDevanagari.ttf"]


static func _base() -> FontFile:
	var base := load("res://fonts/Nunito.ttf") as FontFile
	if base.fallbacks.is_empty():
		var fb: Array[Font] = []
		for p: String in FALLBACKS:
			var f := load(p) as Font
			if f != null:
				fb.append(f)
		base.fallbacks = fb
	return base


static func font(weight: int = 650) -> FontVariation:
	if not _fonts.has(weight):
		var f := FontVariation.new()
		f.base_font = _base()
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = f
	return _fonts[weight]


## Сменился язык: шрифты строятся заново (запасные шрифты письменностей — в font()).
static func refresh_fonts() -> void:
	_fonts.clear()


static func font_bold() -> FontVariation:
	return font(850)
const CLEAR := Color(0, 0, 0, 0)

## Минимальная высота касания в пикселях вьюпорта.
## Вьюпорт 720 по ширине → на телефоне 1080 px масштаб 1.5 → 88 px ≈ 50 dp (норма Android ≥ 48 dp).
const TOUCH := 88


static func build() -> Theme:
	var t := Theme.new()
	var ui_font := font(650)
	var bold := font(850)
	t.default_font = ui_font
	t.default_font_size = 23

	var serif_regular := font(600)
	var serif_strong := font(900)

	t.set_color("font_color", "Label", BONE)
	t.set_constant("line_spacing", "Label", 6)

	_label(t, "Title", serif_strong, 50, BONE, 8)
	_label(t, "Tale", serif_regular, 26, BONE, 9)
	_label(t, "Body", ui_font, 23, BONE, 7)
	_label(t, "Small", ui_font, 20, FROST, 6)
	_label(t, "Speaker", bold, 19, LAMP_D, 2)
	_label(t, "Hint", bold, 19, LAMP_D, 5)
	_label(t, "Clock", ui_font, 23, FROST, 0)
	_label(t, "Danger", ui_font, 22, BLOOD, 6)

	_button(t, "Primary", LAMP, Color("2a1606"), Color("ffe1a0"), 25)
	_button(t, "Ghost", Color(1, 1, 1, 0.05), BONE, Color(1, 1, 1, 0.3), 23)
	_button(t, "Danger", Color(BLOOD, 0.12), BLOOD, BLOOD, 23)
	_button(t, "Row", PANEL, BONE, EDGE, 23)
	_button(t, "RowOn", Color("3a2f22"), BONE, LAMP, 23)
	_button(t, "Chip", Color(1, 1, 1, 0.05), FROST, EDGE, 19, 12)
	_button(t, "ChipYou", Color(LAMP, 0.12), LAMP, LAMP_D, 19, 12)
	_button(t, "ChipDead", CLEAR, Color("6a5a68"), Color(1, 1, 1, 0.08), 19, 12)
	_button(t, "ChipUpyr", Color(BLOOD, 0.12), BLOOD, BLOOD, 19, 12)
	_button(t, "Quick", PANEL, LAMP, EDGE, 20, 14)
	for bn: StringName in [&"Primary", &"Ghost", &"Danger", &"Row", &"RowOn", &"Chip", &"ChipYou", &"ChipDead", &"ChipUpyr", &"Quick"]:
		t.set_font("font", bn, bold)

	_panel(t, "Bubble", PANEL, EDGE)
	_panel(t, "BubbleMine", MINE, MINE_EDGE)
	_panel(t, "Card", PANEL, EDGE)
	_panel(t, "Sheet", Color(0.08, 0.07, 0.13, 0.97), EDGE, 22)

	var le_normal := _box(Color(1, 1, 1, 0.06), EDGE, RADIUS)
	var le_focus := _box(Color(1, 1, 1, 0.08), LAMP_D, RADIUS)
	t.set_stylebox("normal", "LineEdit", le_normal)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", le_normal)
	t.set_color("font_color", "LineEdit", BONE)
	t.set_color("font_placeholder_color", "LineEdit", Color(FROST, 0.7))
	t.set_color("caret_color", "LineEdit", LAMP)
	t.set_font_size("font_size", "LineEdit", 23)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	track.set_corner_radius_all(3)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = LAMP
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
	t.set_stylebox("normal", name, _box(bg, edge, RADIUS, pad))
	t.set_stylebox("hover", name, _box(bg, edge, RADIUS, pad))
	t.set_stylebox("pressed", name, _box(bg.darkened(0.2) if bg.a > 0.2 else Color(1, 1, 1, 0.14), edge, RADIUS, pad))
	t.set_stylebox("hover_pressed", name, _box(bg.darkened(0.2) if bg.a > 0.2 else Color(1, 1, 1, 0.14), edge, RADIUS, pad))
	t.set_stylebox("disabled", name, _box(Color(bg, bg.a * 0.35), Color(edge, edge.a * 0.35), RADIUS, pad))
	t.set_stylebox("focus", name, StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, name, fg)
	t.set_color("font_disabled_color", name, Color(fg, 0.4))
	t.set_font_size("font_size", name, size)


static func _panel(t: Theme, name: StringName, bg: Color, edge: Color, pad: int = 18) -> void:
	t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", name, _box(bg, edge, RADIUS, pad))


static func _circle(d: int, col: Color) -> ImageTexture:
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in range(d):
		for x in range(d):
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)
