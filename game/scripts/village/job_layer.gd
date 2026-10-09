class_name JobLayer
extends Node2D
## Дела на поле: значок над каждым местом работы, точки — сколько раз ещё можно
## сделать дело сегодня. Пока игрок работает, вокруг значка растёт кольцо.
## Закончил кто-то дело — над значком всплывает «+1» (запасы выросли) или «×» (впустую).
## Живёт в координатах посёлка, поэтому приближается и едет вместе с камерой.
## Рисуется каждый кадр только днём — пять значков, это дёшево.

const ICON_Y := -112.0       ## значок висит над головой работника
const R := 19.0
const HIT := 46.0            ## радиус касания значка в единицах посёлка (не меньше 48 dp на экране)

var view: VillageView
var m: Match
var progress_job: int = -1
var progress: float = 0.0
var _pops: Array[Dictionary] = []
var _t := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeFactory.font_bold()


func icon_pos(ji: int) -> Vector2:
	return m.jobs[ji].pos + Vector2(0, ICON_Y)


## Значок дела в координатах экрана — для касаний и самотестов.
func icon_rect_global(ji: int) -> Rect2:
	var c := view.to_global(icon_pos(ji))
	var r := maxf(HIT * view.scale.x, 42.0)
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


## Дело под пальцем: значок или место, где стоит работник. -1 — мимо.
func job_at(global_pos: Vector2) -> int:
	if not visible or m == null or m.jobs.size() != m.job_left.size():
		return -1
	var best := -1
	var best_d := INF
	for i in range(m.jobs.size()):
		# две зоны: значок и место работника. Не общая рамка — она захватила бы пол-площади
		var spot := view.to_global(m.jobs[i].pos + Vector2(0, -36))
		var spot_rect := Rect2(spot - Vector2(30, 40) * view.scale.x, Vector2(60, 80) * view.scale.x)
		if icon_rect_global(i).has_point(global_pos) or spot_rect.has_point(global_pos):
			var d := minf(icon_rect_global(i).get_center().distance_to(global_pos), spot.distance_to(global_pos))
			if d < best_d:
				best_d = d
				best = i
	return best


## Всплывашка над делом: «+1» — засчитано, «×» — впустую, «·» — уже кто-то сделал,
## «−1» — испортили сделанное, «!» — ящик открыт.
const POP_TEXT := {"done": "+1", "fail": "×", "spoil": "−1", "box": "!"}


func pop(ji: int, kind: String) -> void:
	var text: String = POP_TEXT.get(kind, "·")
	var col := Color(0.75, 0.75, 0.82)
	match kind:
		"done", "box": col = ThemeFactory.LAMP
		"spoil": col = Color("e0533f")
	_pops.append({"pos": icon_pos(ji) + Vector2(0, -R - 8), "text": text, "col": col, "t": 0.0})
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
	var k := Art.INK
	for i in range(m.jobs.size()):
		var j: JobDef = m.jobs[i]
		var left := m.job_left[i] if i < m.job_left.size() else 0
		if j.kind == JobDef.Kind.BOX:
			_crate(j.pos, left <= 0)
		var done := left <= 0
		var c := icon_pos(i) + Vector2(0, 0.0 if done else sin(_t * 2.2 + i) * 2.5)
		var a := 0.5 if done else 1.0
		# хвостик к месту работы
		draw_colored_polygon(PackedVector2Array([c + Vector2(-6, R - 2), c + Vector2(6, R - 2), c + Vector2(0, R + 8)]), Color(1, 1, 1, 0.92 * a))
		draw_circle(c, R + 2.5, Color(k, a))
		draw_circle(c, R, Color(1, 1, 1, 0.95 * a))
		_icon(j.kind, c, Color(k, a), done)
		# сколько раз ещё можно сделать дело сегодня
		var n := j.portions
		for d in range(n):
			var dp := c + Vector2((d - (n - 1) * 0.5) * 8.0, R + 14)
			draw_circle(dp, 3.2, Color(k, 0.8 * a))
			draw_circle(dp, 2.2, ThemeFactory.LAMP if d < left else Color(0.85, 0.85, 0.9, a))
		if done:
			draw_polyline(PackedVector2Array([c + Vector2(-8, 1), c + Vector2(-2, 7), c + Vector2(9, -6)]), Color("4caf6a"), 3.5, true)
		if i == progress_job and progress >= 0.0:
			draw_arc(c, R + 7, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, ThemeFactory.LAMP, 5.0, true)
	for p: Dictionary in _pops:
		var t: float = p.t
		var pc: Vector2 = p.pos + Vector2(0, -28.0 * t)
		var al := clampf(1.6 - t * 1.4, 0.0, 1.0)
		var txt: String = p.text
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string_outline(_font, pc + Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(k, al))
		draw_string(_font, pc + Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(p.col, al))


func _icon(kind: JobDef.Kind, c: Vector2, k: Color, dim: bool) -> void:
	var a := 0.5 if dim else 1.0
	match kind:
		JobDef.Kind.WATER:
			Art.shape(self, PackedVector2Array([c + Vector2(-9, -6), c + Vector2(9, -6), c + Vector2(7, 9), c + Vector2(-7, 9)]), Color(0.45, 0.72, 0.95, a), k, 2.0)
			draw_arc(c + Vector2(0, -6), 9, PI, TAU, 10, k, 1.8, true)
			draw_circle(c + Vector2(0, -1), 2.5, Color(1, 1, 1, 0.8 * a))
		JobDef.Kind.WOOD:
			for o: Vector2 in [Vector2(-6, 4), Vector2(6, 4), Vector2(0, -6)]:
				Art.shape(self, Art.ellipse(c + o, Vector2(6, 5.5), 10), Color(0.69, 0.48, 0.29, a), k, 1.8)
				draw_circle(c + o, 2.5, Color(0.91, 0.77, 0.56, a))
		JobDef.Kind.LAMP:
			Art.shape(self, Art.rrect(Rect2(c.x - 6, c.y - 8, 12, 15), 3), Color(1.0, 0.81, 0.42, a), k, 2.0)
			draw_line(c + Vector2(-6, -3), c + Vector2(6, -3), k, 1.6)
			draw_line(c + Vector2(0, -12), c + Vector2(0, -8), k, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 3), c + Vector2(2, 3), c + Vector2(0, -2)]), Color(0.95, 0.45, 0.2, a))
		JobDef.Kind.TALISMAN:
			Art.shape(self, Art.ellipse(c, Vector2(8, 10), 14), Color(0.67, 0.64, 0.6, a), k, 2.0)
			draw_arc(c, 3.6, 0, TAU, 10, k, 1.5, true)
			draw_line(c + Vector2(0, -8), c + Vector2(0, -5), k, 1.5)
			draw_line(c + Vector2(-5.5, 4), c + Vector2(-3, 2), k, 1.5)
			draw_line(c + Vector2(5.5, 4), c + Vector2(3, 2), k, 1.5)
		JobDef.Kind.BOX:
			Art.shape(self, Art.rrect(Rect2(c.x - 10, c.y - 7, 20, 15), 2), Color(0.72, 0.52, 0.32, a), k, 2.0)
			draw_line(c + Vector2(-10, -1), c + Vector2(10, -1), k, 1.6)
			draw_line(c + Vector2(-4, -7), c + Vector2(-4, 8), Color(k, 0.6), 1.2)
			draw_line(c + Vector2(4, -7), c + Vector2(4, 8), Color(k, 0.6), 1.2)
		JobDef.Kind.FISH:
			Art.shape(self, Art.ellipse(c + Vector2(-2, 0), Vector2(9, 5.5), 14), Color(0.55, 0.7, 0.85, a), k, 2.0)
			Art.shape(self, PackedVector2Array([c + Vector2(6, 0), c + Vector2(12, -5), c + Vector2(12, 5)]), Color(0.55, 0.7, 0.85, a), k, 1.8)
			draw_circle(c + Vector2(-7, -1), 1.4, k)


## Сам ящик на земле: закрытый — с крышкой, открытый — крышка откинута.
func _crate(p: Vector2, open: bool) -> void:
	var k := Art.INK
	var wood := Color(0.72, 0.52, 0.32)
	Art.shape(self, Art.ellipse(p + Vector2(0, 4), Vector2(26, 6), 16), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0), 0.0)
	Art.shape(self, Art.rrect(Rect2(p.x - 22, p.y - 28, 44, 30), 3), wood, k, 2.4)
	for x: float in [-8.0, 8.0]:
		draw_line(p + Vector2(x, -27), p + Vector2(x, 1), Color(k, 0.55), 1.6)
	draw_line(p + Vector2(-21, -14), p + Vector2(21, -14), Color(k, 0.55), 1.6)
	if open:
		Art.shape(self, PackedVector2Array([p + Vector2(-22, -28), p + Vector2(22, -28), p + Vector2(26, -40), p + Vector2(-18, -40)]), wood.darkened(0.15), k, 2.0)
	else:
		Art.shape(self, Art.rrect(Rect2(p.x - 24, p.y - 33, 48, 8), 2), wood.lightened(0.08), k, 2.2)
