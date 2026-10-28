class_name HowToArt
extends Control
## Картинка для «Как играть»: те же фигурки, дома, обереги и значки, что в игре.
## kind: day, night, door, talisman, marks, jobs, events, roles, campaign.

const COVER_PATH := "res://assets/ui/campaign_cover.png"

var kind: String = "day"
var figures: Array[VillagerFigure] = []
var _glyphs: Array[Glyph] = []
var _font: Font
var _book: LookBook
var _t := 0.0
var _cover: Texture2D


func setup(k: String) -> void:
	kind = k
	_font = ThemeFactory.font_bold()
	_book = L.looks()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)


func _ready() -> void:
	_build()
	_layout()


func _is_night() -> bool:
	return kind in ["night", "door", "talisman", "events"]


func _build() -> void:
	# кто стоит на картинке: номера жителей из L.names(), -1 — игрок с фонарём
	var idx: Array = []
	match kind:
		"day": idx = [9, 1, -1, 0, 8]
		"night": idx = [-1, 2, 5, 11, 10]
		"door": idx = [3, 7]
		"talisman": idx = [-1, 4]
		"marks": idx = [0, 1, 3, 5, 8]
		"jobs": idx = [2, 6, -1]
		"events": idx = [-1, 7]
		"roles": idx = [7, 10, 4]
		"campaign": idx = [0, 5, -1]
	var all := L.names()
	var names: Array = []
	for i: int in idx:
		names.append([L.t("you_name"), true] if i < 0 else [String(all[i % all.size()][0]), false])
	for n: Array in names:
		var f := VillagerFigure.new()
		f.setup(n[0], _book.for_name(n[0], n[1]), n[1])
		add_child(f)
		figures.append(f)
	match kind:
		"day":
			figures[2].set_highlight(true)
			figures[3].set_marks(3, PackedStringArray(["street"]), false)
		"marks":
			figures[0].set_marks(1, PackedStringArray(["street"]), false)
			figures[1].set_marks(2, PackedStringArray(["liar"]), false)
			figures[2].set_marks(3, PackedStringArray(["death", "fake"]), false)
			figures[3].set_marks(4, PackedStringArray(["sabotage", "tunnel"]), false)
			figures[4].set_marks(0, PackedStringArray(), true)
		"events":
			for g: String in ["fog", "moon", "quiet", "rain"]:
				_add_glyph(g)
		"roles":
			_add_glyph("bell")
		"campaign":
			_cover = load(COVER_PATH) as Texture2D if ResourceLoader.exists(COVER_PATH) else null


func _add_glyph(g: String) -> void:
	var gl := Glyph.make(g, 56.0, Glyph.tint(g))
	add_child(gl)
	_glyphs.append(gl)


func _layout() -> void:
	if figures.is_empty():
		return
	var w := size.x
	var h := size.y
	var sc := clampf(h / 230.0, 1.0, 1.8)
	for f: VillagerFigure in figures:
		f.scale = Vector2(sc, sc)
	match kind:
		"day":
			for i in range(figures.size()):
				figures[i].position = Vector2(w * (0.14 + 0.18 * i), h * 0.82)
		"night":
			figures[0].position = Vector2(w * 0.20, h * 0.86)
			figures[1].position = Vector2(w * 0.34, h * 0.76)
			figures[2].position = Vector2(w * 0.66, h * 0.76)
			figures[3].position = Vector2(w * 0.76, h * 0.86)
			figures[4].position = Vector2(w * 0.44, h * 0.92)
		"door":
			figures[0].position = Vector2(w * 0.30, h * 0.90)
			figures[1].position = Vector2(w * 0.70, h * 0.90)
		"talisman":
			figures[0].position = Vector2(w * 0.18, h * 0.92)
			figures[1].position = Vector2(w * 0.82, h * 0.92)
		"marks":
			for i in range(figures.size()):
				figures[i].position = Vector2(w * (0.12 + 0.19 * i), h * 0.90)
		"jobs":
			figures[0].position = Vector2(w * 0.20, h * 0.92)
			figures[1].position = Vector2(w * 0.50, h * 0.92)
			figures[2].position = Vector2(w * 0.80, h * 0.92)
		"events":
			figures[0].position = Vector2(w * 0.20, h * 0.84)
			figures[1].position = Vector2(w * 0.80, h * 0.84)
			for i in range(_glyphs.size()):
				_glyphs[i].size = Vector2(56, 56)
				_glyphs[i].position = Vector2(w * (0.14 + 0.24 * i) - 28.0, h * 0.14)
		"roles":
			for i in range(figures.size()):
				figures[i].position = Vector2(w * (0.20 + 0.30 * i), h * 0.90)
			if not _glyphs.is_empty():
				_glyphs[0].size = Vector2(64, 64)
				_glyphs[0].position = Vector2(w * 0.5 - 32.0, h * 0.10)
		"campaign":
			figures[0].position = Vector2(w * 0.62, h * 0.88)
			figures[1].position = Vector2(w * 0.77, h * 0.88)
			figures[2].position = Vector2(w * 0.92, h * 0.88)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if kind == "door":
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var night := _is_night()
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
	match kind:
		"day":
			draw_circle(Vector2(w * 0.82, h * 0.18), h * 0.07, Color(0.86, 0.87, 0.80, 0.25))
			_house(Rect2(w * 0.08, h * 0.30, w * 0.22, h * 0.30), false)
			_house(Rect2(w * 0.70, h * 0.30, w * 0.22, h * 0.30), false)
			_speech(Vector2(w * 0.14, h * 0.82 - figures[0].scale.y * 62.0), L.t("howto.art_accuse"))
		"night":
			draw_circle(Vector2(w * 0.84, h * 0.16), h * 0.07, Color(0.86, 0.87, 0.80, 0.9))
			_house(Rect2(w * 0.10, h * 0.28, w * 0.28, h * 0.34), true)
			_house(Rect2(w * 0.62, h * 0.28, w * 0.28, h * 0.34), true)
			var out := figures[4]
			draw_string(_font, out.position + Vector2(22.0 * out.scale.x, -22.0 * out.scale.y), L.t("howto.art_street"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(ThemeFactory.BLOOD, 0.95))
		"door":
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
		"talisman":
			# те же обереги, что у двери в игре: целый, треснувший, расколотый
			_house(Rect2(w * 0.36, h * 0.54, w * 0.28, h * 0.26), true)
			var s := clampf(h / 100.0, 1.8, 3.4)
			for i in range(3):
				var c := Vector2(w * (0.22 + 0.28 * i), h * 0.24)
				draw_set_transform(c, 0.0, Vector2(s, s))
				Art._talisman(self, Vector2.ZERO, 0.55, Color("0d1214"), 2 - i)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"marks":
			draw_circle(Vector2(w * 0.86, h * 0.14), h * 0.06, Color(0.86, 0.87, 0.80, 0.25))
		"jobs":
			var tokens: Array = [[0.14, "water"], [0.38, "wood"], [0.62, "lamp"], [0.86, "box"]]
			for tk: Array in tokens:
				_job_token(Vector2(w * float(tk[0]), h * 0.30), String(tk[1]), clampf(h / 230.0, 1.0, 1.6))
		"campaign":
			if _cover != null:
				var ch := h * 0.84
				var cw := ch * float(_cover.get_width()) / float(_cover.get_height())
				draw_texture_rect(_cover, Rect2(w * 0.06, h * 0.06, cw, ch), false)
	draw_style_box(corner, Rect2(Vector2.ZERO, size))


## Значок дела на площади: белый круг с рисунком по виду дела.
func _job_token(c: Vector2, which: String, s: float) -> void:
	var r := 22.0 * s
	var k := Color("5fa8d3")
	draw_circle(c, r + 2.5, Color(k, 0.95))
	draw_circle(c, r, Color(1, 1, 1, 0.95))
	draw_set_transform(c, 0.0, Vector2(s, s))
	match which:
		"water":
			k = Color("3f86b8")
			draw_colored_polygon(PackedVector2Array([Vector2(0, -13), Vector2(8, 2), Vector2(0, 10), Vector2(-8, 2)]), k)
		"wood":
			k = Color("8a5a34")
			draw_rect(Rect2(-11, -8, 22, 7), k)
			draw_rect(Rect2(-11, 1, 22, 7), Color(k, 0.75))
			draw_circle(Vector2(-11, -4.5), 3.5, Color("d9b88a"))
			draw_circle(Vector2(-11, 4.5), 3.5, Color("d9b88a"))
		"lamp":
			k = Color("e0902f")
			draw_arc(Vector2(0, -6), 8, PI, TAU, 10, k, 2.0, true)
			draw_rect(Rect2(-6, -6, 12, 14), Color(k, 0.35))
			draw_rect(Rect2(-6, -6, 12, 14), k, false, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 5), Vector2(3, 5), Vector2(0, -3)]), Color("f27a2b"))
		"box":
			k = Color("7a5a3a")
			draw_rect(Rect2(-11, -2, 22, 13), Color(k, 0.35))
			draw_rect(Rect2(-11, -2, 22, 13), k, false, 2.0)
			draw_rect(Rect2(-12, -8, 24, 7), Color(k, 0.6))
			draw_rect(Rect2(-12, -8, 24, 7), k, false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
