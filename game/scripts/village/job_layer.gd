class_name JobLayer
extends Node2D
## Места работы: предмет на земле и деревянный указатель с названием и остатком дел.
## Маркер привязан к координатам посёлка; касание работает по указателю и рабочей точке.

const ICON_Y := -62.0
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
	return clampf(f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 36.0, 90.0, 126.0)


## На краю карты указатель остаётся в поле, стойка указывает на место работы.
func _ui_scale() -> float:
	return 1.0 / maxf(absf(view.scale.x), 0.5) if view != null else 1.0


## Положение таблички задаётся в экранных координатах, чтобы зум карты не раздувал её.
func icon_pos(ji: int) -> Vector2:
	if m == null or ji < 0 or ji >= m.jobs.size():
		return Vector2.ZERO
	var transform := get_global_transform_with_canvas()
	if view == null or view._field.size.x <= 0.0 or view._field.size.y <= 0.0:
		return m.jobs[ji].pos + Vector2(0.0, ICON_Y)
	var safe := view._field.grow(-5.0)
	var obstacles := _screen_obstacles()
	var occupied: Array[Rect2] = []
	for previous in range(ji):
		var prior_center := _choose_screen_center(previous, transform, safe, obstacles, occupied)
		occupied.append(_screen_sign_rect(previous, prior_center).grow(6.0))
	var center := _choose_screen_center(ji, transform, safe, obstacles, occupied)
	return transform.affine_inverse() * center


## Разводим таблички по свободным точкам вокруг дела, не меняя масштаб интерфейса.
func _choose_screen_center(ji: int, transform: Transform2D, safe: Rect2,
		obstacles: Array[Rect2], occupied: Array[Rect2]) -> Vector2:
	var preferred := transform * m.jobs[ji].pos + Vector2(0.0, ICON_Y)
	var width := _sign_width(m.jobs[ji].title)
	var half := Vector2(width * 0.5 + 4.0, SIGN_H * 0.5 + 8.0)
	var offsets: Array[Vector2] = [
		Vector2.ZERO, Vector2(0, -34), Vector2(-62, -12), Vector2(62, -12),
		Vector2(0, 38), Vector2(-62, 32), Vector2(62, 32),
		Vector2(0, -76), Vector2(-112, -24), Vector2(112, -24)
	]
	var best := preferred
	var best_cost := INF
	for offset: Vector2 in offsets:
		var candidate := preferred + offset
		candidate.x = clampf(candidate.x, safe.position.x + half.x, safe.end.x - half.x)
		candidate.y = clampf(candidate.y, safe.position.y + half.y, safe.end.y - half.y)
		var rect := _screen_sign_rect(ji, candidate)
		var cost := offset.length() * 0.04
		for blocker: Rect2 in obstacles:
			if rect.intersects(blocker):
				cost += 5000.0 + rect.intersection(blocker).get_area()
		for other: Rect2 in occupied:
			if rect.intersects(other):
				cost += 50000.0 + rect.intersection(other).get_area()
		if cost < best_cost:
			best_cost = cost
			best = candidate
	return best


func _screen_sign_rect(ji: int, center: Vector2) -> Rect2:
	var size := Vector2(_sign_width(m.jobs[ji].title), SIGN_H)
	return Rect2(center - size * 0.5, size)


## Не ставим указатели поверх людей, подписей, домов и реплик.
func _screen_obstacles() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if view == null:
		return out
	if view.crowd != null:
		for figure: VillagerFigure in view.crowd.figures.values():
			if not is_instance_valid(figure) or not figure.is_visible_in_tree():
				continue
			var body := figure.body_rect_global()
			var label := figure.label_rect_global()
			if view._field.intersects(body):
				out.append(body.grow(4.0))
			if view._field.intersects(label):
				out.append(label.grow(4.0))
	for house: HouseDef in view.def.shelters:
		_add_house_obstacle(out, house)
	for house: HouseDef in view.def.decor:
		_add_house_obstacle(out, house)
	if Nav.bubbles != null:
		for bubble in Nav.bubbles.alive():
			if view._field.intersects(bubble.rect):
				out.append(bubble.rect.grow(4.0))
	return out


func _add_house_obstacle(out: Array[Rect2], house: HouseDef) -> void:
	var local_rect := view.house_rect(house)
	var transform := view.get_global_transform_with_canvas()
	var a := transform * local_rect.position
	var b := transform * local_rect.end
	var screen_rect := Rect2(a, b - a).abs()
	if view._field.intersects(screen_rect):
		out.append(screen_rect.grow(3.0))


## Точный прямоугольник таблички в экранных координатах.
func sign_rect_global(ji: int) -> Rect2:
	if m == null or ji < 0 or ji >= m.jobs.size():
		return Rect2()
	var c := get_global_transform_with_canvas() * icon_pos(ji)
	var width := _sign_width(m.jobs[ji].title)
	return Rect2(c - Vector2(width * 0.5, SIGN_H * 0.5), Vector2(width, SIGN_H))


## Указатель дела — увеличенная зона касания вокруг таблички.
func icon_rect_global(ji: int) -> Rect2:
	var sign := sign_rect_global(ji)
	var size := Vector2(maxf(sign.size.x, 84.0), maxf(sign.size.y, 84.0))
	return Rect2(sign.get_center() - size * 0.5, size)


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
	_pops.append({"pos": icon_pos(ji) + Vector2(0, -SIGN_H * 0.5 - 8.0) * _ui_scale(), "text": text, "col": col, "t": 0.0})
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
			var ui_scale := _ui_scale()
			draw_set_transform(c * (1.0 - ui_scale), 0.0, Vector2.ONE * ui_scale)
			var w := _sign_width(j.title) - 18.0
			var p := c + Vector2(0.0, 23.0)
			draw_rect(Rect2(p.x - w * 0.5, p.y, w, 3.5), Color(ink, 0.85))
			draw_rect(Rect2(p.x - w * 0.5, p.y, w * clampf(progress, 0.0, 1.0), 3.5), ThemeFactory.LAMP)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p: Dictionary in _pops:
		var t: float = p.t
		var ui_scale := _ui_scale()
		var pc: Vector2 = p.pos + Vector2(0, -28.0 * t * ui_scale)
		var al := clampf(1.6 - t * 1.4, 0.0, 1.0)
		var txt: String = p.text
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_set_transform(pc * (1.0 - ui_scale), 0.0, Vector2.ONE * ui_scale)
		draw_string_outline(_font, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(ink, al))
		draw_string(_font, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(p.col, al))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sign(j: JobDef, c: Vector2, _site: Vector2, left: int, done: bool) -> void:
	var ui_scale := _ui_scale()
	draw_set_transform(c * (1.0 - ui_scale), 0.0, Vector2.ONE * ui_scale)
	var width := _sign_width(j.title)
	var r := Rect2(c.x - width * 0.5, c.y - SIGN_H * 0.5, width, SIGN_H)
	var alpha := 0.62 if done else 1.0
	var wood := Color("39271b", alpha)
	var edge := Color(ThemeFactory.LAMP_D, 0.95 * alpha)
	var pointer := PackedVector2Array([
		Vector2(c.x - 5.0, r.end.y - 2.0), Vector2(c.x + 5.0, r.end.y - 2.0), Vector2(c.x, r.end.y + 7.0)
	])
	var station_top := _site + Vector2(0.0, -16.0)
	if pointer[2].distance_to(station_top) > 18.0:
		draw_line(pointer[2], station_top, Color(ThemeFactory.LAMP_D, 0.56 * alpha), 1.0, true)
	draw_colored_polygon(pointer, wood)
	draw_polyline(PackedVector2Array([pointer[0], pointer[1], pointer[2], pointer[0]]), edge, 1.4, true)
	var shadow_rect := r.grow(2.0)
	shadow_rect.position += Vector2(1.0, 3.0)
	Art.shape(self, Art.rrect(shadow_rect, 5.0), Color(0.01, 0.008, 0.005, 0.62), Color(0, 0, 0, 0), 0.0)
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
