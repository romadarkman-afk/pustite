class_name HowToArt
extends Control
## Картинка для «Как играть»: те же процедурные фигурки и дома, что в игре.
## page 0 — день и кто есть кто, 1 — ночь, 2 — дверь.

var page: int = 0
var figures: Array[VillagerFigure] = []
var _font: Font
var _book: LookBook
var _t := 0.0


func setup(p: int) -> void:
	page = p
	_font = ThemeFactory.font_bold()
	_book = L.looks()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)


func _ready() -> void:
	_build()
	_layout()


func _build() -> void:
	# кто стоит на картинке: номера жителей из L.names(), -1 — игрок с фонарём
	var idx: Array = []
	match page:
		0: idx = [9, 1, -1, 0, 8]
		1: idx = [-1, 2, 5, 11, 10]
		2: idx = [3, 7]
	var all := L.names()
	var names: Array = []
	for i: int in idx:
		names.append([L.t("you_name"), true] if i < 0 else [String(all[i % all.size()][0]), false])
	for n: Array in names:
		var f := VillagerFigure.new()
		f.setup(n[0], _book.for_name(n[0], n[1]), n[1])
		add_child(f)
		figures.append(f)
	if page == 0:
		figures[2].set_highlight(true)
		figures[3].set_marks(3, PackedStringArray(["street"]), false)


func _layout() -> void:
	if figures.is_empty():
		return
	var w := size.x
	var h := size.y
	var sc := clampf(h / 230.0, 1.0, 1.8)
	for f: VillagerFigure in figures:
		f.scale = Vector2(sc, sc)
	match page:
		0:
			for i in range(figures.size()):
				figures[i].position = Vector2(w * (0.14 + 0.18 * i), h * 0.82)
		1:
			figures[0].position = Vector2(w * 0.20, h * 0.86)
			figures[1].position = Vector2(w * 0.34, h * 0.76)
			figures[2].position = Vector2(w * 0.66, h * 0.76)
			figures[3].position = Vector2(w * 0.76, h * 0.86)
			figures[4].position = Vector2(w * 0.44, h * 0.95)
		2:
			figures[0].position = Vector2(w * 0.30, h * 0.90)
			figures[1].position = Vector2(w * 0.70, h * 0.90)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if page == 2:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var night := page != 0
	var sky_top := Color("0b1418") if night else Color("2f3e44")
	var sky_bot := Color("17242a") if night else Color("4d5d62")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.62), Vector2(0, h * 0.62)]),
		PackedColorArray([sky_top, sky_top, sky_bot, sky_bot]))
	draw_rect(Rect2(0, h * 0.62, w, h * 0.38), Color("10191d") if night else Color("2a353a"))
	var corner := StyleBoxFlat.new()
	corner.bg_color = Color(0, 0, 0, 0)
	corner.border_color = ThemeFactory.EDGE
	corner.set_border_width_all(1)
	corner.set_corner_radius_all(12)
	match page:
		0:
			draw_circle(Vector2(w * 0.82, h * 0.18), h * 0.07, Color(0.86, 0.87, 0.80, 0.25))
			_house(Rect2(w * 0.08, h * 0.30, w * 0.22, h * 0.30), false)
			_house(Rect2(w * 0.70, h * 0.30, w * 0.22, h * 0.30), false)
			_speech(Vector2(w * 0.14, h * 0.82 - figures[0].scale.y * 62.0), L.t("howto.art_accuse"))
		1:
			draw_circle(Vector2(w * 0.84, h * 0.16), h * 0.07, Color(0.86, 0.87, 0.80, 0.9))
			_house(Rect2(w * 0.10, h * 0.28, w * 0.28, h * 0.34), true)
			_house(Rect2(w * 0.62, h * 0.28, w * 0.28, h * 0.34), true)
			var out := figures[4]
			draw_string(_font, out.position + Vector2(22.0 * out.scale.x, -22.0 * out.scale.y), L.t("howto.art_street"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(ThemeFactory.BLOOD, 0.95))
		2:
			var dw := w * 0.30
			var door := Rect2(w * 0.5 - dw * 0.5, h * 0.12, dw, h * 0.66)
			var open := 0.55 + 0.1 * sin(_t * 2.0)
			for i in range(8):
				var r := (dw * 0.12 + i * dw * 0.09) * open
				draw_rect(Rect2(w * 0.5 - r, door.position.y, r * 2.0, door.size.y), Color(ThemeFactory.LAMP, 0.04 * (1.0 - i / 8.0)))
			draw_rect(door, ThemeFactory.PANEL)
			draw_rect(Rect2(w * 0.5 - 5, door.position.y, 10, door.size.y), Color(ThemeFactory.LAMP, 0.85))
			draw_rect(door, ThemeFactory.EDGE, false, 3.0)
			draw_string(_font, Vector2(0, h * 0.10), L.t("howto.art_door"), HORIZONTAL_ALIGNMENT_CENTER, w, 26, ThemeFactory.LAMP)
	draw_style_box(corner, Rect2(Vector2.ZERO, size))


func _house(r: Rect2, lit: bool) -> void:
	var wall := Color("172228") if lit else Color("2a3940")
	draw_rect(r, wall)
	draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 8, r.position.y), Vector2(r.get_center().x, r.position.y - r.size.y * 0.5),
		Vector2(r.end.x + 8, r.position.y)]), Color("0d1518") if lit else Color("1d282d"))
	var win := ThemeFactory.LAMP if lit else Color("1b262b")
	var ws := r.size.x * 0.18
	draw_rect(Rect2(r.position.x + r.size.x * 0.12, r.position.y + r.size.y * 0.2, ws, ws), win)
	draw_rect(Rect2(r.end.x - r.size.x * 0.12 - ws, r.position.y + r.size.y * 0.2, ws, ws), win)
	draw_rect(Rect2(r.get_center().x - r.size.x * 0.12, r.end.y - r.size.y * 0.5, r.size.x * 0.24, r.size.y * 0.5), Color("3a2c22"))
	draw_rect(r, ThemeFactory.EDGE, false, 2.0)


func _speech(anchor: Vector2, text: String) -> void:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var r := Rect2(clampf(anchor.x - 20, 6, size.x - tw - 30), anchor.y - 44, tw + 24, 34)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeFactory.PANEL_2
	sb.border_color = ThemeFactory.EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	draw_style_box(sb, r)
	draw_colored_polygon(PackedVector2Array([Vector2(anchor.x - 6, r.end.y - 1), Vector2(anchor.x + 6, r.end.y - 1), Vector2(anchor.x, r.end.y + 8)]), ThemeFactory.PANEL_2)
	draw_string(_font, Vector2(r.position.x + 12, r.position.y + 24), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ThemeFactory.BONE)
