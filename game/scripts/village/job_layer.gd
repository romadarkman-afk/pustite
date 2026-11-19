class_name JobLayer
extends Node2D
## Места работы: предмет на земле и деревянный указатель с названием и остатком дел.
## Маркер привязан к координатам посёлка; касание работает по указателю и рабочей точке.

const ICON_Y := -112.0
const HIT := 46.0
const SIGN_H := 38.0

var view: VillageView
var m: Match
var progress_job: int = -1
var progress: float = 0.0
var _pops: Array[Dictionary] = []
var _t := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeFactory.font_bold()


func _sign_width(title: String) -> float:
	var f := _font if _font != null else ThemeFactory.font_bold()
	var size := maxi(9, roundi(10.0 * ThemeFactory.text_scale))
	return clampf(f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 43.0, 100.0, 148.0)


## На краю карты указатель остаётся в поле, стойка указывает на место работы.
func icon_pos(ji: int) -> Vector2:
	if m == null or ji < 0 or ji >= m.jobs.size():
		return Vector2.ZERO
	var p: Vector2 = m.jobs[ji].pos + Vector2(0, ICON_Y)
	if view == null or view._field.size.x <= 0.0 or view._field.size.y <= 0.0:
		return p
	var transform := get_global_transform_with_canvas()
	var screen := transform * p
	var safe := view._field.grow(-5.0)
	var sx := maxf(view.scale.x, 0.5)
	var half_w := _sign_width(m.jobs[ji].title) * sx * 0.5 + 4.0
	if safe.size.x > half_w * 2.0:
		screen.x = clampf(screen.x, safe.position.x + half_w, safe.end.x - half_w)
	else:
		screen.x = safe.get_center().x
	var half_h := SIGN_H * sx * 0.5 + 4.0
	if safe.size.y > half_h * 2.0:
		screen.y = clampf(screen.y, safe.position.y + half_h, safe.end.y - half_h)
	return transform.affine_inverse() * screen


## Указатель дела в координатах экрана — для касаний и самотестов.
func icon_rect_global(ji: int) -> Rect2:
	var c := view.to_global(icon_pos(ji))
	var r := maxf(HIT * view.scale.x, 42.0)
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


## Дело под пальцем: указатель или рабочая точка. -1 означает, что игрок нажал мимо.
func job_at(global_pos: Vector2) -> int:
	if not visible or m == null or m.jobs.size() != m.job_left.size():
		return -1
	var best := -1
	var best_d := INF
	for i in range(m.jobs.size()):
		var spot := view.to_global(m.jobs[i].pos + Vector2(0, -36))
		var spot_rect := Rect2(spot - Vector2(30, 40) * view.scale.x, Vector2(60, 80) * view.scale.x)
		var marker := icon_rect_global(i)
		if marker.has_point(global_pos) or spot_rect.has_point(global_pos):
			var d := minf(marker.get_center().distance_to(global_pos), spot.distance_to(global_pos))
			if d < best_d:
				best_d = d
				best = i
	return best


## «+1» — припасы приняты, «×» — работа пропала, «−1» — дело испорчено, «!» — ящик открыт.
const POP_TEXT := {"done": "+1", "fail": "×", "spoil": "−1", "box": "!"}


func pop(ji: int, kind: String) -> void:
	var text: String = POP_TEXT.get(kind, "·")
	var col := Color(0.75, 0.75, 0.82)
	match kind:
		"done", "box": col = ThemeFactory.LAMP
		"spoil": col = Color("e0533f")
	_pops.append({"pos": icon_pos(ji) + Vector2(0, -SIGN_H * 0.5 - 8.0), "text": text, "col": col, "t": 0.0})
	queue_redraw()


func set_progress(ji: int, p: float) -> void:
	progress_job = ji
	progress = p
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for p: Dictionary in _pops:
		p.t = float(p.t) + delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return float(p.t) < 1.4)
	queue_redraw()


func _draw() -> void:
	if view == null or m == null:
		return
	var ink := Art.INK
	for i in range(m.jobs.size()):
		var j: JobDef = m.jobs[i]
		var left := m.job_left[i] if i < m.job_left.size() else 0
		var done := left <= 0
		var site: Vector2 = j.pos
		var c := icon_pos(i)
		_draw_station(j.kind, site + Vector2(-30.0, 2.0), done)
		_draw_sign(j, c, site, left, done)
		if i == progress_job and progress >= 0.0:
			var w := _sign_width(j.title) - 18.0
			var p := c + Vector2(0.0, 23.0)
			draw_rect(Rect2(p.x - w * 0.5, p.y, w, 3.5), Color(ink, 0.85))
			draw_rect(Rect2(p.x - w * 0.5, p.y, w * clampf(progress, 0.0, 1.0), 3.5), ThemeFactory.LAMP)
	for p: Dictionary in _pops:
		var t: float = p.t
		var pc: Vector2 = p.pos + Vector2(0, -28.0 * t)
		var al := clampf(1.6 - t * 1.4, 0.0, 1.0)
		var txt: String = p.text
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string_outline(_font, pc + Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(ink, al))
		draw_string(_font, pc + Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(p.col, al))


func _draw_sign(j: JobDef, c: Vector2, site: Vector2, left: int, done: bool) -> void:
	var width := _sign_width(j.title)
	var r := Rect2(c.x - width * 0.5, c.y - SIGN_H * 0.5, width, SIGN_H)
	var alpha := 0.62 if done else 1.0
	var wood := Color("39271b", alpha)
	var edge := Color(ThemeFactory.LAMP_D, 0.95 * alpha)
	var post := site + Vector2(-30.0, -5.0)
	var foot := c + Vector2(-width * 0.34, SIGN_H * 0.5 - 1.0)
	draw_line(post + Vector2(1.5, 0), foot + Vector2(1.5, 0), Color("17110d", 0.9 * alpha), 7.0, true)
	draw_line(post, foot, Color("795333", 0.98 * alpha), 4.0, true)
	draw_line(post + Vector2(-1.0, 0), foot + Vector2(-1.0, 0), Color("bd8d55", 0.55 * alpha), 1.0, true)
	Art.shape(self, Art.rrect(r.grow(2.0).translated(Vector2(1.0, 3.0)), 5.0), Color(0.01, 0.008, 0.005, 0.62))
	Art.shape(self, Art.rrect(r, 5.0), wood, edge, 2.0)
	Art.shape(self, Art.rrect(r.grow(-3.0), 3.0), Color(0, 0, 0, 0), Color(ThemeFactory.BONE, 0.13 * alpha), 0.9)
	draw_line(Vector2(r.position.x + 6.0, r.position.y + 4.0), Vector2(r.end.x - 6.0, r.position.y + 4.0), Color(ThemeFactory.LAMP, 0.38 * alpha), 1.0, true)
	for nail: Vector2 in [Vector2(r.position.x + 4.5, r.position.y + 5.0), Vector2(r.end.x - 4.5, r.position.y + 5.0),
			Vector2(r.position.x + 4.5, r.end.y - 5.0), Vector2(r.end.x - 4.5, r.end.y - 5.0)]:
		draw_circle(nail, 1.25, Color(ThemeFactory.LAMP_D, 0.85 * alpha))
	_icon(j.kind, Vector2(r.position.x + 17.0, r.get_center().y), done)
	var text_x := r.position.x + 31.0
	var available := width - 48.0
	var size := maxi(8, roundi(10.0 * ThemeFactory.text_scale))
	while size > 8 and _font.get_string_size(j.title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > available:
		size -= 1
	var baseline := Vector2(text_x, r.position.y + 21.0)
	draw_string_outline(_font, baseline, j.title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(Art.INK, 0.95 * alpha))
	draw_string(_font, baseline, j.title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(ThemeFactory.BONE, alpha))
	var count := "%d/%d" % [maxi(left, 0), j.portions]
	draw_string(_font, Vector2(r.end.x - 27.0, r.end.y - 4.0), count, HORIZONTAL_ALIGNMENT_RIGHT, 26.0, 8, Color(ThemeFactory.LAMP, alpha))
	if done:
		var stamp := Vector2(r.end.x - 11.0, r.position.y + 9.0)
		draw_circle(stamp, 5.5, Color("20150f", 0.96))
		draw_arc(stamp, 5.5, 0.0, TAU, 16, Color(ThemeFactory.LAMP_D, 0.9), 1.0, true)
		draw_polyline(PackedVector2Array([stamp + Vector2(-2.5, 0), stamp + Vector2(-0.5, 2.0), stamp + Vector2(3.0, -2.0)]), Color("6da56a"), 1.8, true)


## У каждого дела свой предмет на земле, рядом с тем местом, где житель работает.
func _draw_station(kind: JobDef.Kind, p: Vector2, done: bool) -> void:
	var dim := 0.55 if done else 1.0
	var ink := Art.INK
	Art.shape(self, Art.ellipse(p + Vector2(0, 4), Vector2(26, 7), 18), Color(0, 0, 0, 0.28), Color(0, 0, 0, 0), 0.0)
	match kind:
		JobDef.Kind.WATER:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -18), p + Vector2(11, -18), p + Vector2(8, 3), p + Vector2(-8, 3)]), Color("8a603d", dim))
			draw_arc(p + Vector2(0, -18), 11.0, PI, TAU, 16, Color(ink, dim), 2.0, true)
			draw_line(p + Vector2(-9, -8), p + Vector2(9, -8), Color("b8874e", dim), 2.0, true)
			draw_line(p + Vector2(-6, -3), p + Vector2(6, -3), Color(ink, 0.7 * dim), 1.4, true)
			draw_arc(p + Vector2(19, 2), 9.0, PI, TAU, 18, Color("779eb0", 0.7 * dim), 1.4, true)
		JobDef.Kind.WOOD:
			for k in range(3):
				var center := p + Vector2(0.0, -5.0 - k * 7.0)
				draw_line(center + Vector2(-19, 0), center + Vector2(18, 0), Color(ink, dim), 7.0, true)
				draw_line(center + Vector2(-18, -1), center + Vector2(17, -1), Color("96683d", dim), 4.5, true)
				draw_circle(center + Vector2(-18, -1), 3.0, Color("c7a16c", dim))
				draw_circle(center + Vector2(-18, -1), 1.3, Color("65442d", dim))
		JobDef.Kind.LAMP:
			draw_line(p + Vector2(-8, 3), p + Vector2(8, 3), Color("65442d", dim), 4.0, true)
			draw_line(p + Vector2(0, 1), p + Vector2(0, -22), Color("65442d", dim), 3.0, true)
			draw_line(p + Vector2(-6, -18), p + Vector2(6, -18), Color("65442d", dim), 2.0, true)
			Art.shape(self, Art.rrect(Rect2(p.x - 5.0, p.y - 17.0, 10.0, 13.0), 2.0), Color("f3b75c", dim), ink, 1.6)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-2, -7), p + Vector2(2, -7), p + Vector2(0, -13)]), Color("fff0b0", dim))
			draw_circle(p + Vector2(0, -11), 11.0, Color(ThemeFactory.LAMP, 0.1 * dim))
		JobDef.Kind.TALISMAN:
			draw_line(p + Vector2(0, 3), p + Vector2(0, -21), Color("65442d", dim), 3.0, true)
			draw_line(p + Vector2(-10, -19), p + Vector2(10, -19), Color("9a7046", dim), 3.0, true)
			draw_line(p + Vector2(-6, -16), p + Vector2(-6, -7), Color("b14e3c", dim), 2.0, true)
			draw_line(p + Vector2(6, -16), p + Vector2(6, -7), Color("c8a365", dim), 2.0, true)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -11), p + Vector2(0, -5), p + Vector2(8, -11), p + Vector2(0, -15)]), Color("9b3f32", dim))
		JobDef.Kind.BOX:
			_crate(p, done)
		JobDef.Kind.FISH:
			Art.shape(self, Art.rrect(Rect2(p.x - 15, p.y - 12, 29, 16), 4.0), Color("855738", dim), ink, 1.7)
			draw_line(p + Vector2(-12, -8), p + Vector2(12, -8), Color("c39a66", dim), 1.3, true)
			for x: float in [-8.0, -2.0, 4.0, 10.0]:
				draw_line(p + Vector2(x, -11), p + Vector2(x - 2, 3), Color(ink, 0.5 * dim), 1.0, true)
			draw_colored_polygon(PackedVector2Array([p + Vector2(1, -17), p + Vector2(10, -13), p + Vector2(1, -9), p + Vector2(-7, -13)]), Color("9aa6aa", dim))
			draw_circle(p + Vector2(7, -13), 1.1, ink)


## Гравированный знак на табличке. У каждого дела свой силуэт и цвет.
func _icon(kind: JobDef.Kind, c: Vector2, dim: bool) -> void:
	var a := 0.58 if dim else 1.0
	var ink := Art.INK
	match kind:
		JobDef.Kind.WATER:
			Art.shape(self, PackedVector2Array([c + Vector2(-7, -5), c + Vector2(7, -5), c + Vector2(5, 7), c + Vector2(-5, 7)]), Color("78a8bb", a), ink, 1.5)
			draw_arc(c + Vector2(0, -5), 7.0, PI, TAU, 12, Color(ink, a), 1.5, true)
			draw_line(c + Vector2(-5, -1), c + Vector2(5, -1), Color("d4bd91", a), 1.4, true)
		JobDef.Kind.WOOD:
			for y: float in [-4.0, 1.0, 6.0]:
				draw_line(c + Vector2(-7, y), c + Vector2(7, y), Color("a97849", a), 3.6, true)
				draw_circle(c + Vector2(-6.0, y), 1.5, Color("d2aa72", a))
		JobDef.Kind.LAMP:
			Art.shape(self, Art.rrect(Rect2(c.x - 5.0, c.y - 6.0, 10.0, 13.0), 2.0), Color("f1b457", a), ink, 1.4)
			draw_line(c + Vector2(-6, -3), c + Vector2(6, -3), Color(ink, a), 1.3, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 2), c + Vector2(2, 2), c + Vector2(0, -3)]), Color("fff0b0", a))
		JobDef.Kind.TALISMAN:
			draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color("c8a365", a), 2.0, true)
			draw_line(c + Vector2(-6, -4), c + Vector2(6, -4), Color("c8a365", a), 2.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 1), c + Vector2(0, 7), c + Vector2(4, 1), c + Vector2(0, -3)]), Color("a64335", a))
		JobDef.Kind.BOX:
			Art.shape(self, Art.rrect(Rect2(c.x - 7.0, c.y - 5.0, 14.0, 11.0), 1.0), Color("a8794e", a), ink, 1.5)
			draw_line(c + Vector2(-7, -1), c + Vector2(7, -1), Color(ink, a), 1.2, true)
			draw_line(c + Vector2(0, -5), c + Vector2(0, 6), Color("e0b476", a), 1.0, true)
		JobDef.Kind.FISH:
			Art.shape(self, Art.ellipse(c + Vector2(-1, 0), Vector2(7, 4.5), 12), Color("9aadb0", a), ink, 1.3)
			draw_colored_polygon(PackedVector2Array([c + Vector2(5, 0), c + Vector2(10, -4), c + Vector2(10, 4)]), Color("9aadb0", a))
			draw_circle(c + Vector2(-4, -1), 1.0, ink)


## Ящик на земле: открытый показывает тёмную пустоту, закрытый закреплён планкой.
func _crate(p: Vector2, open: bool) -> void:
	var k := Art.INK
	var wood := Color("805a38")
	Art.shape(self, Art.ellipse(p + Vector2(0, 4), Vector2(24, 6), 16), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0), 0.0)
	Art.shape(self, Art.rrect(Rect2(p.x - 22, p.y - 28, 44, 30), 3), wood, k, 2.4)
	for x: float in [-8.0, 8.0]:
		draw_line(p + Vector2(x, -27), p + Vector2(x, 1), Color(k, 0.55), 1.6)
	draw_line(p + Vector2(-21, -14), p + Vector2(21, -14), Color(k, 0.55), 1.6)
	if open:
		Art.shape(self, PackedVector2Array([p + Vector2(-22, -28), p + Vector2(22, -28), p + Vector2(26, -40), p + Vector2(-18, -40)]), wood.darkened(0.15), k, 2.0)
	else:
		Art.shape(self, Art.rrect(Rect2(p.x - 24, p.y - 33, 48, 8), 2), wood.lightened(0.08), k, 2.2)
