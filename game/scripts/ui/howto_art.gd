class_name HowToArt
extends Control
## Картинка для «Как играть»: те же фигурки, дома, обереги и значки, что в игре.
## kind: day, night, door, talisman, marks, jobs, events, roles, campaign.

const COVER_PATH := "res://assets/ui/campaign_cover.png"
const GROUND_DAY := preload("res://assets/village/realistic/ground_day.jpg")
const GROUND_NIGHT := preload("res://assets/village/realistic/ground_night.jpg")
const GROUND_MILL := preload("res://assets/village/realistic/ground_mill_day.jpg")
const GROUND_STATION := preload("res://assets/village/realistic/ground_station_day.jpg")
const GROUND_MONASTERY := preload("res://assets/village/realistic/ground_monastery_night.jpg")
const HOUSE_DAY := preload("res://assets/village/realistic/house_day.png")
const HOUSE_NIGHT := preload("res://assets/village/realistic/house_night.png")
const DOOR_CLOSED := preload("res://assets/ui/door_closed.png")
const CHARMS := [
	preload("res://assets/village/talisman.png"),
	preload("res://assets/village/talisman_cracked.png"),
	preload("res://assets/village/talisman_broken.png")
]

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
	var used := {}
	for n: Array in names:
		var f := VillagerFigure.new()
		f.setup(n[0], _book.for_name(n[0], n[1]), n[1])
		if not bool(n[1]):
			var sprite := VillagerFigure.pick_sprite(f.look, used)
			used[sprite] = true
			f.set_sprite(sprite)
		add_child(f)
		if _is_night():
			f.set_night(0.86)
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
	var sc := clampf(minf(h / 172.0, w / 340.0), 0.75, 1.45)
	for f: VillagerFigure in figures:
		f.scale = Vector2(sc, sc)
	match kind:
		"day":
			for i in range(figures.size()):
				figures[i].position = Vector2(w * (0.14 + 0.18 * i), h * 0.76)
		"night":
			for i in range(figures.size()):
				figures[i].position = Vector2(w * (0.12 + 0.19 * i), h * 0.76)
		"door":
			figures[0].position = Vector2(w * 0.30, h * 0.76)
			figures[1].position = Vector2(w * 0.70, h * 0.76)
		"talisman":
			figures[0].position = Vector2(w * 0.18, h * 0.76)
			figures[1].position = Vector2(w * 0.82, h * 0.76)
		"marks":
			for i in range(figures.size()):
				figures[i].position = Vector2(w * (0.12 + 0.19 * i), h * 0.76)
		"jobs":
			for i in range(figures.size()):
				figures[i].scale = Vector2.ONE * sc * 0.77
				figures[i].position = Vector2(w * (0.17 + 0.33 * i), h * 0.86)
		"events":
			figures[0].position = Vector2(w * 0.20, h * 0.76)
			figures[1].position = Vector2(w * 0.80, h * 0.76)
			for i in range(_glyphs.size()):
				_glyphs[i].size = Vector2(56, 56)
				_glyphs[i].position = Vector2(w * (0.14 + 0.24 * i) - 28.0, h * 0.14)
		"roles":
			for i in range(figures.size()):
				figures[i].position = Vector2(w * (0.20 + 0.30 * i), h * 0.76)
			if not _glyphs.is_empty():
				_glyphs[0].size = Vector2(64, 64)
				_glyphs[0].position = Vector2(w * 0.5 - 32.0, 6.0)
		"campaign":
			figures[0].position = Vector2(w * 0.62, h * 0.76)
			figures[1].position = Vector2(w * 0.77, h * 0.76)
			figures[2].position = Vector2(w * 0.92, h * 0.76)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if kind == "door":
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var night := _is_night()
	# Та же карта, что в партии: кадрирование без растягивания.
	var ground: Texture2D = GROUND_NIGHT if night else GROUND_DAY
	match kind:
		"jobs": ground = GROUND_MILL
		"roles", "campaign": ground = GROUND_STATION
		"talisman", "events": ground = GROUND_MONASTERY
	var source := Rect2(Vector2.ZERO, ground.get_size())
	var target_ratio := w / maxf(h, 1.0)
	var source_ratio := source.size.x / maxf(source.size.y, 1.0)
	if source_ratio > target_ratio:
		var cropped_width := source.size.y * target_ratio
		source.position.x = (source.size.x - cropped_width) * 0.5
		source.size.x = cropped_width
	else:
		var cropped_height := source.size.x / target_ratio
		source.position.y = (source.size.y - cropped_height) * 0.5
		source.size.y = cropped_height
	draw_texture_rect_region(ground, Rect2(Vector2.ZERO, size), source)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.03, 0.25))
	var corner := StyleBoxFlat.new()
	corner.bg_color = Color(0, 0, 0, 0)
	corner.border_color = ThemeFactory.EDGE
	corner.set_border_width_all(1)
	corner.set_corner_radius_all(12)
	match kind:
		"day":
			_house(Rect2(w * 0.08, h * 0.30, w * 0.22, h * 0.30), false)
			_house(Rect2(w * 0.70, h * 0.30, w * 0.22, h * 0.30), false)
			_speech(Vector2(w * 0.14, maxf(35.0, h * 0.20)), L.t("howto.art_accuse"))
		"night":
			_house(Rect2(w * 0.10, h * 0.28, w * 0.28, h * 0.34), true)
			_house(Rect2(w * 0.62, h * 0.28, w * 0.28, h * 0.34), true)
			_draw_night_location()
		"door":
			var dh := h * 0.53
			var dw := minf(w * 0.27, dh * DOOR_CLOSED.get_width() / maxf(DOOR_CLOSED.get_height(), 1.0))
			draw_texture_rect(DOOR_CLOSED, Rect2(w * 0.5 - dw * 0.5, h * 0.22, dw, dh), false)

		"talisman":
			# те же обереги, что у двери в игре: целый, треснувший, расколотый
			_house(Rect2(w * 0.30, h * 0.43, w * 0.40, h * 0.48), true)
			var charm_size := clampf(h * 0.25, 36.0, 62.0)
			for i in range(3):
				var c := Vector2(w * (0.22 + 0.28 * i), h * 0.24)
				draw_texture_rect(CHARMS[i], Rect2(c - Vector2.ONE * charm_size * 0.5, Vector2.ONE * charm_size), false)
		"jobs":
			_draw_job_examples()
		"campaign":
			if _cover != null:
				var ch := h * 0.84
				var cw := ch * float(_cover.get_width()) / float(_cover.get_height())
				draw_texture_rect(_cover, Rect2(w * 0.06, h * 0.06, cw, ch), false)
	draw_style_box(corner, Rect2(Vector2.ZERO, size))


## Статус вынесен в свободный промежуток над жителями, чтобы не закрывать их силуэты.
func _draw_night_location() -> void:
	var label := L.t("howto.art_street").to_upper()
	var text_w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var label_y := maxf(4.0, size.y * 0.28 - 26.0)
	var r := Rect2(size.x * 0.5 - (text_w + 18.0) * 0.5, label_y, text_w + 18.0, 24.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("211813", 0.92)
	sb.border_color = Color(ThemeFactory.BLOOD, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	draw_style_box(sb, r)
	draw_string(_font, Vector2(r.position.x + 9.0, r.position.y + 16.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18.0, 13, ThemeFactory.BLOOD)


## Образцы тех же указателей, которые появляются на карте.
func _draw_job_examples() -> void:
	var kinds: Array[JobDef.Kind] = [JobDef.Kind.WATER, JobDef.Kind.WOOD, JobDef.Kind.LAMP,
		JobDef.Kind.FISH, JobDef.Kind.TALISMAN, JobDef.Kind.BOX]
	var keys: Array[String] = ["water", "wood", "lamp", "fish", "talisman", "box"]
	var box := StyleBoxFlat.new()
	box.bg_color = Color("211811", 0.78)
	box.border_color = ThemeFactory.LAMP_D
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	var width := minf(154.0, size.x * 0.31)
	for i in range(kinds.size()):
		var center := Vector2(size.x * (float(i % 3) + 0.5) / 3.0, size.y * (0.15 if i < 3 else 0.36))
		var r := Rect2(center - Vector2(width * 0.5, 14.0), Vector2(width, 28.0))
		draw_style_box(box, r)
		JobLayer.draw_job_icon(self, kinds[i], Vector2(r.position.x + 13.0, center.y))
		var label := L.t("job." + keys[i] + ".title")
		var font_size := 12
		while font_size > 9 and _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width - 27.0:
			font_size -= 1
		draw_string(_font, Vector2(r.position.x + 25.0, center.y + 4.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, width - 27.0, font_size, ThemeFactory.BONE)


func _house(r: Rect2, lit: bool) -> void:
	var tex: Texture2D = HOUSE_NIGHT if lit else HOUSE_DAY
	var image_rect := Rect2(r.position.x, r.position.y - r.size.y * 0.45, r.size.x, r.size.y * 1.45)
	draw_texture_rect(tex, image_rect, false)


func _speech(anchor: Vector2, text: String) -> void:
	var tw := minf(size.x - 32.0, _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	var r := Rect2(clampf(anchor.x - tw * 0.5 - 9.0, 6.0, size.x - tw - 24.0), maxf(5.0, anchor.y - 30.0), tw + 18.0, 24.0)
	var tail_x := clampf(anchor.x, r.position.x + 8.0, r.end.x - 8.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeFactory.PANEL_2
	sb.border_color = ThemeFactory.EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	draw_style_box(sb, r)
	draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 5, r.end.y - 1), Vector2(tail_x + 5, r.end.y - 1), Vector2(tail_x, r.end.y + 6)]), ThemeFactory.PANEL_2)
	draw_string(_font, Vector2(r.position.x + 9, r.position.y + 16), text, HORIZONTAL_ALIGNMENT_LEFT, tw, 13, ThemeFactory.BONE)
