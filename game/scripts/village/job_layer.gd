class_name JobLayer
extends Node2D
## Места работы: предмет на земле и деревянный указатель с названием и остатком дел.
## Маркер привязан к координатам посёлка; касание работает по указателю и рабочей точке.

const ICON_Y := -62.0
const SIGN_H := 26.0
const TOUCH_SIZE := 84.0
const MARKER_REACH := 72.0
const STATION_OFFSET := Vector2(-19, 2)
const STATION_ART := {
	JobDef.Kind.WATER: preload("res://assets/village/realistic/barrel.png"),
	JobDef.Kind.WOOD: preload("res://assets/village/realistic/prop_stump_axe.png"),
	JobDef.Kind.LAMP: preload("res://assets/village/realistic/lamp_day.png"),
	JobDef.Kind.TALISMAN: preload("res://assets/village/talisman.png"),
	JobDef.Kind.FISH: preload("res://assets/village/realistic/prop_nets.png"),
	JobDef.Kind.BOX: preload("res://assets/village/realistic/prop_crates.png")
}

var view: VillageView
var m: Match
var progress_job: int = -1
var progress: float = 0.0
var _pops: Array[Dictionary] = []
var _t := 0.0
var _font: Font
var _marker_rects: Array[Rect2] = []
var _layout_frame := -1
var _layout_transform := Transform2D.IDENTITY
var _layout_match: Match
var _actor_obstacles: Array[Rect2] = []


func _ready() -> void:
	_font = ThemeFactory.font_bold()


func _sign_width(title: String) -> float:
	var f := _font if _font != null else ThemeFactory.font_bold()
	var size := maxi(9, roundi(10.0 * ThemeFactory.text_scale))
	return clampf(f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 39.0, 68.0, 109.0)


func _marker_title(job: JobDef) -> String:
	if job.house >= 0 and view != null and job.house < view.def.shelters.size():
		return view._title(job.house)
	return L.t("job.short.%s" % key_for(job.kind))


static func key_for(kind: JobDef.Kind) -> String:
	match kind:
		JobDef.Kind.WATER: return "water"
		JobDef.Kind.WOOD: return "wood"
		JobDef.Kind.LAMP: return "lamp"
		JobDef.Kind.TALISMAN: return "talisman"
		JobDef.Kind.FISH: return "fish"
		_: return "box"


## Фиксированный экранный размер независимо от приближения камеры.
func _ui_scale() -> float:
	return 1.0 / maxf(absf(view.scale.x), 0.5) if view != null else 1.0


## Положение таблички задаётся в экранных координатах, чтобы зум карты не раздувал её.
func icon_pos(ji: int) -> Vector2:
	if m == null or ji < 0 or ji >= m.jobs.size():
		return Vector2.ZERO
	var rect := sign_rect_global(ji)
	if not rect.has_area():
		return m.jobs[ji].pos + Vector2(0, ICON_Y)
	return get_global_transform_with_canvas().affine_inverse() * rect.get_center()


func _layout_markers() -> void:
	var frame := Engine.get_process_frames()
	var transform := get_global_transform_with_canvas()
	if _layout_frame == frame and _layout_transform == transform and _layout_match == m and _marker_rects.size() == m.jobs.size():
		return
	_layout_frame = frame
	_layout_transform = transform
	_layout_match = m
	_marker_rects.clear()
	_actor_obstacles.clear()
	var field := view._field if view != null else Rect2()
	var safe := field.grow(-5.0)
	var obstacles: Array[Rect2] = []
	if field.has_area():
		obstacles = _screen_obstacles()
		if view.crowd != null:
			for figure: VillagerFigure in view.crowd.figures.values():
				if figure.is_visible_in_tree() and figure.at_field_edge_or_inside():
					var body_rect := figure.body_rect_global()
					var head := figure.head_global()
					var width := clampf(body_rect.size.x * 0.38, 14.0, 36.0)
					_actor_obstacles.append(Rect2(head - Vector2(width * 0.5, 2.0),
						Vector2(width, body_rect.size.y * 0.28 + 5.0)))
					_actor_obstacles.append(figure.label_rect_global().grow(1.0))
	var occupied: Array[Rect2] = []
	var offsets: Array[Vector2] = [
		Vector2(0, 19), Vector2(-35, 22), Vector2(35, 22),
		Vector2(0, -34), Vector2(-43, -28), Vector2(43, -28),
		Vector2(0, 48), Vector2(-53, 0), Vector2(53, 0)
	]
	for job: JobDef in m.jobs:
		var anchor := transform * (job.pos + STATION_OFFSET)
		var size := Vector2(_sign_width(_marker_title(job)), SIGN_H)
		if not field.has_area():
			_marker_rects.append(Rect2(anchor + Vector2(0, ICON_Y) - size * 0.5, size))
			continue
		var best := Rect2()
		var best_cost := INF
		if field.grow(12.0).has_point(anchor) and safe.size.x >= size.x and safe.size.y >= size.y:
			for offset: Vector2 in offsets:
				var minimum := safe.position + size * 0.5
				var maximum := safe.end - size * 0.5
				var center := (anchor + offset).clamp(minimum, maximum)
				if center.distance_to(anchor) > MARKER_REACH:
					continue
				var rect := Rect2(center - size * 0.5, size)
				if occupied.any(func(other: Rect2) -> bool: return rect.intersects(other)):
					continue
				var cost := center.distance_squared_to(anchor + offsets[0])
				for blocker: Rect2 in obstacles:
					if rect.intersects(blocker):
						cost += 600.0 + rect.intersection(blocker).get_area() * 5.0
				for actor: Rect2 in _actor_obstacles:
					if rect.intersects(actor):
						cost += 1050.0 + rect.intersection(actor).get_area() * 10.0
				if cost < best_cost:
					best_cost = cost
					best = rect
		_marker_rects.append(best)
		if best.has_area():
			occupied.append(best.grow(5.0))


## Постройки и их подписи не зависят от движения жителей и не раскачивают таблички.
func _screen_obstacles() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in range(view.open_count):
		var plaque := view.shelter_label_rect_global(i)
		if view._field.intersects(plaque):
			out.append(plaque.grow(6.0))
	for house: HouseDef in view.def.shelters:
		_add_house_obstacle(out, house)
	for house: HouseDef in view.def.decor:
		_add_house_obstacle(out, house)
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
	_layout_markers()
	return _marker_rects[ji]


## Указатель дела — увеличенная зона касания вокруг таблички.
func icon_rect_global(ji: int) -> Rect2:
	var sign := sign_rect_global(ji)
	if not sign.has_area():
		return Rect2()
	var size := Vector2(maxf(sign.size.x, TOUCH_SIZE), maxf(sign.size.y, TOUCH_SIZE))
	return Rect2(sign.get_center() - size * 0.5, size)


## Сначала проверяем видимую табличку, потом расширенную область и рабочую точку.
func marker_at(global_pos: Vector2) -> int:
	var best := -1
	var distance := INF
	for i in range(m.jobs.size()):
		var marker := sign_rect_global(i)
		if marker.has_point(global_pos):
			return i
		var hit := icon_rect_global(i)
		if hit.has_point(global_pos):
			var candidate := hit.get_center().distance_squared_to(global_pos)
			if candidate < distance:
				best = i
				distance = candidate
	return best


func job_at(global_pos: Vector2) -> int:
	if not visible or m == null or m.jobs.size() != m.job_left.size():
		return -1
	var marker := marker_at(global_pos)
	if marker >= 0:
		return marker
	var best := -1
	var distance := INF
	var transform := get_global_transform_with_canvas()
	for i in range(m.jobs.size()):
		var spot := transform * (m.jobs[i].pos + STATION_OFFSET + Vector2(0, -16))
		var offset := spot.distance_squared_to(global_pos)
		if offset <= 26.0 * 26.0 and offset < distance:
			best = i
			distance = offset
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
		_draw_station(j.kind, site + STATION_OFFSET, done or (j.kind == JobDef.Kind.BOX and m.box_opened_by >= 0))
		var marker := sign_rect_global(i)
		if not marker.has_area():
			continue
		var c := icon_pos(i)
		_draw_sign(j, c, site + STATION_OFFSET, left, done)
		if i == progress_job and progress >= 0.0:
			var ui_scale := _ui_scale()
			draw_set_transform(c * (1.0 - ui_scale), 0.0, Vector2.ONE * ui_scale)
			var w := _sign_width(_marker_title(j)) - 18.0
			var p := c + Vector2(0.0, 18.0)
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
	var width := _sign_width(_marker_title(j))
	var r := Rect2(c.x - width * 0.5, c.y - SIGN_H * 0.5, width, SIGN_H)
	var alpha := 0.68 if done else 1.0
	var wood := Color("1e1713", 0.62 * alpha)
	var edge := Color(ThemeFactory.LAMP_D, 0.76 * alpha)
	var direction := (_site - c).normalized()
	var stem := Vector2(clampf(direction.x * 26.0, -width * 0.36, width * 0.36), SIGN_H * 0.5 * (1.0 if direction.y > 0.0 else -1.0))
	var base := c + stem
	var tip := base + Vector2(direction.x * 9.0, signf(direction.y) * 7.0)
	draw_colored_polygon(PackedVector2Array([base - Vector2(5, 0), base + Vector2(5, 0), tip]), edge)
	var shadow_rect := r.grow(2.0)
	shadow_rect.position += Vector2(1.0, 3.0)
	Art.shape(self, Art.rrect(shadow_rect, 5.0), Color(0.01, 0.008, 0.005, 0.25), Color(0, 0, 0, 0), 0.0)
	Art.shape(self, Art.rrect(r, 5.0), wood, edge, 1.0)
	Art.shape(self, Art.rrect(r.grow(-3.0), 3.0), Color(0, 0, 0, 0), Color(ThemeFactory.BONE, 0.13 * alpha), 0.9)
	draw_line(Vector2(r.position.x + 6.0, r.position.y + 4.0), Vector2(r.end.x - 6.0, r.position.y + 4.0), Color(ThemeFactory.LAMP, 0.38 * alpha), 1.0, true)
	for nail: Vector2 in [Vector2(r.position.x + 4.5, r.position.y + 5.0), Vector2(r.end.x - 4.5, r.position.y + 5.0),
			Vector2(r.position.x + 4.5, r.end.y - 5.0), Vector2(r.end.x - 4.5, r.end.y - 5.0)]:
		draw_circle(nail, 1.25, Color(ThemeFactory.LAMP_D, 0.85 * alpha))
	draw_job_icon(self, j.kind, Vector2(r.position.x + 17.0, r.get_center().y), done)
	var text_x := r.position.x + 31.0
	var title := _marker_title(j)
	var available := width - 39.0
	var size := maxi(8, roundi(10.0 * ThemeFactory.text_scale))
	while size > 8 and _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > available:
		size -= 1
	var baseline := Vector2(text_x, r.position.y + 13.0)
	draw_string_outline(_font, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(Art.INK, 0.95 * alpha))
	draw_string(_font, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(ThemeFactory.BONE, alpha))
	var count := "%d/%d" % [j.portions - maxi(left, 0), j.portions]
	draw_string(_font, Vector2(r.end.x - 27.0, r.end.y - 4.0), count, HORIZONTAL_ALIGNMENT_RIGHT, 26.0, 8, Color(ThemeFactory.LAMP, alpha))
	if done:
		var stamp := Vector2(r.end.x - 11.0, r.position.y + 9.0)
		draw_circle(stamp, 5.5, Color("20150f", 0.96))
		draw_arc(stamp, 5.5, 0.0, TAU, 16, Color(ThemeFactory.LAMP_D, 0.9), 1.0, true)
		draw_polyline(PackedVector2Array([stamp + Vector2(-2.5, 0), stamp + Vector2(-0.5, 2.0), stamp + Vector2(3.0, -2.0)]), Color("6da56a"), 1.8, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## У каждого дела свой предмет на земле, рядом с тем местом, где житель работает.
func _draw_station(kind: JobDef.Kind, p: Vector2, done: bool) -> void:
	if kind == JobDef.Kind.BOX and done:
		_crate(p, true)
		return
	var tex := STATION_ART[kind] as Texture2D
	var height := 44.0 if kind == JobDef.Kind.LAMP else 28.0
	var width := minf(64.0, height * float(tex.get_width()) / maxf(1.0, float(tex.get_height())))
	var rect := Rect2(p.x - width * 0.5, p.y - height, width, height)
	draw_texture_rect(tex, rect, false, Color(0.75, 0.72, 0.68) if done else Color.WHITE)
	if kind == JobDef.Kind.BOX:
		var glow := 0.65 + 0.25 * sin(_t * 3.5)
		draw_circle(rect.get_center() + Vector2(0, 3), 3.5, Color(ThemeFactory.LAMP, glow))


## Гравированный знак на табличке. У каждого дела свой силуэт и цвет.
static func draw_job_icon(canvas: CanvasItem, kind: JobDef.Kind, c: Vector2, dim: bool = false) -> void:
	var a := 0.58 if dim else 1.0
	var ink := Art.INK
	match kind:
		JobDef.Kind.WATER:
			Art.shape(canvas, PackedVector2Array([c + Vector2(-7, -5), c + Vector2(7, -5), c + Vector2(5, 7), c + Vector2(-5, 7)]), Color("78a8bb", a), ink, 1.5)
			canvas.draw_arc(c + Vector2(0, -5), 7.0, PI, TAU, 12, Color(ink, a), 1.5, true)
			canvas.draw_line(c + Vector2(-5, -1), c + Vector2(5, -1), Color("d4bd91", a), 1.4, true)
		JobDef.Kind.WOOD:
			for y: float in [-4.0, 1.0, 6.0]:
				canvas.draw_line(c + Vector2(-7, y), c + Vector2(7, y), Color("a97849", a), 3.6, true)
				canvas.draw_circle(c + Vector2(-6.0, y), 1.5, Color("d2aa72", a))
		JobDef.Kind.LAMP:
			Art.shape(canvas, Art.rrect(Rect2(c.x - 5.0, c.y - 6.0, 10.0, 13.0), 2.0), Color("f1b457", a), ink, 1.4)
			canvas.draw_line(c + Vector2(-6, -3), c + Vector2(6, -3), Color(ink, a), 1.3, true)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 2), c + Vector2(2, 2), c + Vector2(0, -3)]), Color("fff0b0", a))
		JobDef.Kind.TALISMAN:
			canvas.draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color("c8a365", a), 2.0, true)
			canvas.draw_line(c + Vector2(-6, -4), c + Vector2(6, -4), Color("c8a365", a), 2.0, true)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 1), c + Vector2(0, 7), c + Vector2(4, 1), c + Vector2(0, -3)]), Color("a64335", a))
		JobDef.Kind.BOX:
			Art.shape(canvas, Art.rrect(Rect2(c.x - 7.0, c.y - 5.0, 14.0, 11.0), 1.0), Color("a8794e", a), ink, 1.5)
			canvas.draw_line(c + Vector2(-7, -1), c + Vector2(7, -1), Color(ink, a), 1.2, true)
			canvas.draw_line(c + Vector2(0, -5), c + Vector2(0, 6), Color("e0b476", a), 1.0, true)
		JobDef.Kind.FISH:
			Art.shape(canvas, Art.ellipse(c + Vector2(-1, 0), Vector2(7, 4.5), 12), Color("9aadb0", a), ink, 1.3)
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(5, 0), c + Vector2(10, -4), c + Vector2(10, 4)]), Color("9aadb0", a))
			canvas.draw_circle(c + Vector2(-4, -1), 1.0, ink)


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
