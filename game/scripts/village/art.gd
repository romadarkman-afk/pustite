class_name Art
extends RefCounted
## Приёмы рисования в стиле «уютный ужас»: толстый тёплый контур, пухлые формы,
## тень одним тоном. Пользуются посёлок, жители и картинки «Как играть».

const INK := Color("2b1d1a")
const INK_N := Color("120d18")
const NIGHT_TINT := Color(0.40, 0.42, 0.68)


## Цвет днём → ночью: ночь не просто темнее, а уходит в фиолетовую синеву.
static func dn(day: Color, n: float) -> Color:
	return day.lerp(Color(day.r * NIGHT_TINT.r, day.g * NIGHT_TINT.g, day.b * NIGHT_TINT.b, day.a), n)


static func ink(n: float) -> Color:
	return INK.lerp(INK_N, n)


static func rrect(r: Rect2, rad: float, seg: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rr := minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var corners := [Vector2(r.end.x - rr, r.position.y + rr), Vector2(r.end.x - rr, r.end.y - rr),
		Vector2(r.position.x + rr, r.end.y - rr), Vector2(r.position.x + rr, r.position.y + rr)]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in range(4):
		for i in range(seg + 1):
			var a: float = starts[c] + PI * 0.5 * i / seg
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * rr)
	return pts


static func ellipse(c: Vector2, r: Vector2, seg: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


static func shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line: Color, width: float) -> void:
	ci.draw_colored_polygon(pts, fill)
	if width > 0.0:
		var o := pts.duplicate()
		o.append(pts[0])
		ci.draw_polyline(o, line, width, true)


static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	for i in range(8):
		var k := 1.0 - i / 8.0
		ci.draw_circle(c, r * (0.25 + 0.75 * (i + 1) / 8.0), Color(col, col.a * 0.1 * k))


static func tree(ci: CanvasItem, p: Vector2, s: float, col: Color, ink_c: Color) -> void:
	ci.draw_line(p, p + Vector2(0, -22 * s), ink_c, 10 * s, true)
	ci.draw_line(p, p + Vector2(0, -22 * s), col.darkened(0.55), 6 * s, true)
	var blobs := [Vector3(0, -48, 24), Vector3(-16, -34, 18), Vector3(16, -35, 18), Vector3(0, -64, 16)]
	for b: Vector3 in blobs:
		ci.draw_circle(p + Vector2(b.x, b.y) * s, (b.z + 2.5) * s, ink_c)
	for b: Vector3 in blobs:
		ci.draw_circle(p + Vector2(b.x, b.y) * s, b.z * s, col)
		ci.draw_circle(p + Vector2(b.x - 5, b.y - 5) * s, b.z * 0.42 * s, col.lightened(0.14))


# =============================================================
# Дома
# =============================================================
## state: 0 — фон, 1 — открытое убежище, 2 — заколоченное. lit — насколько горят окна (0..1).
static func house(ci: CanvasItem, kind: int, base: Vector2, w: float, h: float, pal: Dictionary, n: float, lit: float, state: int, tal: int = 2) -> void:
	var k := ink(n)
	var wall: Color = dn(pal.wall, n)
	var wall_d: Color = dn(pal.wall_d, n)
	var roof: Color = dn(pal.roof, n)
	if state == 2:
		wall = wall.darkened(0.25)
		wall_d = wall_d.darkened(0.25)
		roof = roof.darkened(0.25)
	var x0 := base.x - w * 0.5
	var top := base.y - h
	ci.draw_colored_polygon(ellipse(base + Vector2(5, 3), Vector2(w * 0.62, 9)), Color(0, 0, 0, 0.22))
	match kind:
		HouseDef.Kind.CELLAR:
			_cellar(ci, base, w, h, pal, n, lit, state, k, tal)
			return
		HouseDef.Kind.GARAGE:
			var body := Rect2(x0, top + h * 0.12, w, h * 0.88)
			ci.draw_colored_polygon(rrect(body, 7), wall_d)
			ci.draw_colored_polygon(rrect(Rect2(body.position, Vector2(body.size.x * 0.84, body.size.y)), 7), wall)
			_outline(ci, rrect(body, 7), k, 3.0)
			shape(ci, rrect(Rect2(x0 - 7, top + h * 0.04, w + 14, h * 0.14), 5), roof, k, 3.0)
			var dr := Rect2(base.x - w * 0.28, top + h * 0.36, w * 0.56, h * 0.64)
			shape(ci, rrect(dr, 5), dn(Color("c9c2b6"), n).darkened(0.2 if state == 2 else 0.0), k, 2.5)
			for i in range(1, 6):
				var yy := dr.position.y + dr.size.y * i / 6.0
				ci.draw_line(Vector2(dr.position.x + 3, yy), Vector2(dr.end.x - 3, yy), Color(k, 0.35), 1.6)
			_window(ci, Rect2(x0 + w * 0.06, top + h * 0.3, w * 0.12, w * 0.12), n, lit, state, k)
			if state == 2:
				_planks(ci, dr.grow(2), n, k)
			return
		_:
			pass
	var bw := w * (0.8 if kind == HouseDef.Kind.CHURCH else 1.0)
	var bx := base.x - bw * 0.5
	var body2 := Rect2(bx, top, bw, h)
	ci.draw_colored_polygon(rrect(body2, 8), wall_d)
	ci.draw_colored_polygon(rrect(Rect2(bx, top, bw * 0.84, h), 8), wall)
	for kk in range(1, 6):
		var yy2 := top + h * kk / 6.0
		ci.draw_line(Vector2(bx + 5, yy2), Vector2(bx + bw - 5, yy2), Color(k, 0.1), 1.6)
	_outline(ci, rrect(body2, 8), k, 3.2)
	var rp: PackedVector2Array
	match kind:
		HouseDef.Kind.BARN:
			rp = PackedVector2Array([Vector2(bx - 14, top + 6), Vector2(bx + bw * 0.12, top - h * 0.34), Vector2(base.x, top - h * 0.54),
				Vector2(bx + bw * 0.88, top - h * 0.34), Vector2(bx + bw + 14, top + 6)])
		HouseDef.Kind.CHURCH:
			rp = PackedVector2Array([Vector2(bx - 12, top + 6), Vector2(base.x - 6, top - h * 0.62), Vector2(base.x + 6, top - h * 0.62), Vector2(bx + bw + 12, top + 6)])
		HouseDef.Kind.SHED:
			rp = PackedVector2Array([Vector2(bx - 10, top + 6), Vector2(bx - 6, top - h * 0.3), Vector2(bx + bw + 10, top - h * 0.05), Vector2(bx + bw + 10, top + 6)])
		_:
			rp = PackedVector2Array([Vector2(bx - 14, top + 6), Vector2(base.x - 7, top - h * 0.58), Vector2(base.x + 7, top - h * 0.58), Vector2(bx + bw + 14, top + 6)])
	ci.draw_colored_polygon(rp, roof)
	if kind != HouseDef.Kind.SHED:
		var peak := top - h * (0.54 if kind == HouseDef.Kind.BARN else 0.6)
		for row in range(1, 5):
			var yy3 := top + 6 - (top + 6 - peak) * row / 5.0
			var half := (bw * 0.5 + 14) * (1.0 - float(row) / 5.0)
			var xx := base.x - half
			while xx < base.x + half - 7:
				ci.draw_arc(Vector2(xx + 7, yy3), 7, 0.2, PI - 0.2, 6, Color(roof.darkened(0.3), 0.85), 1.8, true)
				xx += 14
	_outline(ci, rp, k, 3.4)
	if kind == HouseDef.Kind.CHURCH:
		_chapel_top(ci, base, bw, h, top, roof, wall, k, n)
	elif kind == HouseDef.Kind.HOME:
		shape(ci, rrect(Rect2(bx + bw * 0.68, top - h * 0.46, bw * 0.12, h * 0.28), 3), wall_d.darkened(0.15), k, 2.6)
	var ws := bw * 0.19
	if kind == HouseDef.Kind.BARN:
		_window(ci, Rect2(base.x - ws * 0.4, top - h * 0.26, ws * 0.8, ws * 0.8), n, lit, state, k, true)
	elif kind != HouseDef.Kind.SHED:
		for wx in [bx + bw * 0.12, bx + bw * 0.88 - ws]:
			var wr := Rect2(wx, top + h * 0.2, ws, ws * 1.05)
			_window(ci, wr, n, lit, state, k)
			if state != 2 and n < 0.6:
				var boxc := Color(dn(Color("8a5a3a"), n), 1.0 - n)
				shape(ci, rrect(Rect2(wr.position.x - 3, wr.end.y + 1, ws + 6, 7), 3), boxc, Color(k, 1.0 - n), 2.0)
				for fi in range(3):
					ci.draw_circle(Vector2(wr.position.x + 3 + fi * (ws / 2.0), wr.end.y - 1), 3.6,
						Color([Color("ff7a8a"), Color("ffd166"), Color("c9a2ff")][fi], 1.0 - n))
	var dw := bw * (0.42 if kind == HouseDef.Kind.BARN else 0.24)
	var dh := h * (0.62 if kind == HouseDef.Kind.BARN else 0.5)
	var dr2 := Rect2(base.x - dw * 0.5, base.y - dh, dw, dh)
	var door_col := dn(Color("7a4a2c"), n)
	shape(ci, rrect(dr2, dw * (0.2 if kind == HouseDef.Kind.BARN else 0.45)), door_col.darkened(0.3 if state == 2 else 0.0), k, 2.8)
	if kind == HouseDef.Kind.BARN:
		ci.draw_line(dr2.position + Vector2(3, 3), dr2.end - Vector2(3, 3), Color(k, 0.6), 2.4)
		ci.draw_line(Vector2(dr2.end.x - 3, dr2.position.y + 3), Vector2(dr2.position.x + 3, dr2.end.y - 3), Color(k, 0.6), 2.4)
		ci.draw_line(Vector2(dr2.get_center().x, dr2.position.y), Vector2(dr2.get_center().x, dr2.end.y), k, 2.0)
	else:
		ci.draw_circle(Vector2(dr2.end.x - 5, dr2.get_center().y + 4), 2.6, dn(Color("ffd166"), n * 0.5))
	if state == 1 and lit > 0.2:
		ci.draw_line(Vector2(dr2.position.x + 4, dr2.end.y - 1.5), Vector2(dr2.end.x - 4, dr2.end.y - 1.5), Color(1.0, 0.8, 0.45, 0.9 * lit), 3.0)
	shape(ci, rrect(Rect2(dr2.position.x - 6, base.y - 4, dw + 12, 7), 3), dn(Color("9a9088"), n), k, 2.2)
	if state == 2:
		_planks(ci, dr2.grow(3), n, k)
	if state == 1:
		_talisman(ci, Vector2(dr2.position.x - 14, base.y - 10), n, k, tal)


static func _outline(ci: CanvasItem, pts: PackedVector2Array, k: Color, width: float) -> void:
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, k, width, true)


static func _window(ci: CanvasItem, wr: Rect2, n: float, lit: float, state: int, k: Color, round_win: bool = false) -> void:
	var glass := dn(Color("9fd8f0"), n)
	if state == 1 or state == 0:
		var warm := Color("ffcf6b") if state == 1 else Color("e8b860")
		glass = glass.lerp(warm, lit * (1.0 if state == 1 else 0.7))
	if state == 2:
		glass = dn(Color("3a3a48"), n)
	if round_win:
		shape(ci, ellipse(wr.get_center(), wr.size * 0.5, 18), glass, k, 2.6)
	else:
		shape(ci, rrect(wr, 5), glass, k, 2.6)
		if lit < 0.3 and state != 2 and n < 0.5:
			ci.draw_line(wr.position + Vector2(4, wr.size.y * 0.7), wr.position + Vector2(wr.size.x * 0.6, 4), Color(1, 1, 1, 0.6 * (1.0 - n)), 2.6, true)
		ci.draw_line(Vector2(wr.get_center().x, wr.position.y), Vector2(wr.get_center().x, wr.end.y), k, 2.2)
		ci.draw_line(Vector2(wr.position.x, wr.get_center().y), Vector2(wr.end.x, wr.get_center().y), k, 2.2)
	if state == 2:
		_planks(ci, wr.grow(2), n, k)


static func _planks(ci: CanvasItem, r: Rect2, n: float, k: Color) -> void:
	var wood := dn(Color("b07a4a"), n)
	for pr: Array in [[r.position + Vector2(-2, 4), r.end + Vector2(2, -4)], [Vector2(r.end.x + 2, r.position.y + 4), Vector2(r.position.x - 2, r.end.y - 4)]]:
		ci.draw_line(pr[0], pr[1], k, 7.5, true)
		ci.draw_line(pr[0], pr[1], wood, 5.0, true)


## Обережный камень у двери — свой знак: круг, а под ним два луча и черта сверху.
## tal: 2 — целый (ночью светится), 1 — треснул (трещина, свет слабее), 0 — расколот.
static func _talisman(ci: CanvasItem, c: Vector2, n: float, k: Color, tal: int = 2) -> void:
	var line := Color(k, 0.8)
	if tal <= 0:
		# две половинки врозь, без света, с красноватым отливом
		var stone := dn(Color("a08a84"), n * 0.7)
		var lh := PackedVector2Array([c + Vector2(-2, -10), c + Vector2(-9, -6), c + Vector2(-10, 4), c + Vector2(-5, 10), c + Vector2(-1, 9), c + Vector2(-4, 2), c + Vector2(0, -3)])
		var rh := PackedVector2Array([c + Vector2(3, -10), c + Vector2(4, -3), c + Vector2(1, 2), c + Vector2(5, 9), c + Vector2(10, 9), c + Vector2(12, 1), c + Vector2(10, -7)])
		shape(ci, lh, stone, k, 2.2)
		shape(ci, rh, stone, k, 2.2)
		for sh: Vector2 in [Vector2(-12, 11), Vector2(13, 11), Vector2(2, 12)]:
			ci.draw_circle(c + sh, 1.6, Color(k, 0.7))
		if n > 0.3:
			glow(ci, c, 14, Color(0.9, 0.2, 0.15, 0.35 * n))
		return
	shape(ci, ellipse(c, Vector2(9, 10.5), 16), dn(Color("aaa29a"), n * 0.7), k, 2.4)
	ci.draw_arc(c, 4.2, 0, TAU, 12, line, 1.6, true)
	ci.draw_line(c + Vector2(0, -8.5), c + Vector2(0, -5), line, 1.6)
	ci.draw_line(c + Vector2(-6.5, 4.5), c + Vector2(-3.5, 2), line, 1.6)
	ci.draw_line(c + Vector2(6.5, 4.5), c + Vector2(3.5, 2), line, 1.6)
	if tal == 1:
		ci.draw_polyline(PackedVector2Array([c + Vector2(-3, -10), c + Vector2(1, -4), c + Vector2(-2, 1), c + Vector2(3, 6), c + Vector2(1, 10)]), k, 2.0, true)
	if n > 0.3:
		glow(ci, c, 18, Color(0.6, 0.9, 1.0, (0.45 if tal >= 2 else 0.18) * n))


static func _chapel_top(ci: CanvasItem, base: Vector2, bw: float, h: float, top: float, roof: Color, wall: Color, k: Color, n: float) -> void:
	var tw := bw * 0.34
	var ty := top - h * 0.56
	var tower := Rect2(base.x - tw * 0.5, ty - h * 0.36, tw, h * 0.4)
	shape(ci, rrect(tower, 4), wall, k, 2.8)
	shape(ci, ellipse(tower.get_center() + Vector2(0, 2), Vector2(tw * 0.22, tw * 0.22), 14), dn(Color("ffd166"), n * 0.6), k, 2.0)
	var r := tw * 0.62
	var dy := tower.position.y
	var prof: Array[Vector2] = [Vector2(0.45, 0.0), Vector2(0.85, -0.25), Vector2(1.0, -0.55), Vector2(0.88, -0.88),
		Vector2(0.55, -1.18), Vector2(0.22, -1.42), Vector2(0.0, -1.66)]
	var pts := PackedVector2Array()
	for q: Vector2 in prof:
		pts.append(Vector2(base.x + q.x * r, dy + q.y * r))
	for i in range(prof.size() - 2, -1, -1):
		pts.append(Vector2(base.x - prof[i].x * r, dy + prof[i].y * r))
	shape(ci, pts, dn(Color("5fb3a6"), n), k, 2.8)
	var tip := dy - 1.66 * r
	ci.draw_line(Vector2(base.x, tip), Vector2(base.x, tip - r * 0.8), k, 2.6)
	ci.draw_circle(Vector2(base.x, tip - r * 0.85), 3.2, dn(Color("ffd166"), n * 0.5))


static func _cellar(ci: CanvasItem, base: Vector2, w: float, h: float, pal: Dictionary, n: float, lit: float, state: int, k: Color, tal: int = 2) -> void:
	var pts := PackedVector2Array()
	for i in range(25):
		var a := PI * i / 24.0
		pts.append(base + Vector2(cos(a) * w * 0.5, -sin(a) * h))
	var earth := dn(Color("7fae68"), n).darkened(0.2 if state == 2 else 0.0)
	shape(ci, pts, earth, k, 3.2)
	for i in range(7):
		var a2 := PI * (0.15 + 0.7 * i / 6.0)
		var gp := base + Vector2(cos(a2) * w * 0.44, -sin(a2) * h * 0.9)
		ci.draw_line(gp, gp + Vector2(-2, -6), dn(Color("5c8a48"), n), 1.8, true)
		ci.draw_line(gp, gp + Vector2(2, -7), dn(Color("5c8a48"), n), 1.8, true)
	var dw := w * 0.32
	var dr := Rect2(base.x - dw * 0.5, base.y - h * 0.62, dw, h * 0.62)
	shape(ci, rrect(dr.grow(4), 6), dn(Color("9a9088"), n), k, 2.6)
	shape(ci, rrect(dr, 5), dn(Color("7a4a2c"), n).darkened(0.3 if state == 2 else 0.0), k, 2.4)
	if state == 1 and lit > 0.2:
		ci.draw_line(Vector2(dr.position.x + 3, dr.end.y - 1.5), Vector2(dr.end.x - 3, dr.end.y - 1.5), Color(1.0, 0.8, 0.45, 0.9 * lit), 3.0)
	if state == 2:
		_planks(ci, dr.grow(3), n, k)
	if state == 1:
		_talisman(ci, Vector2(dr.position.x - 16, base.y - 9), n, k, tal)


# =============================================================
# Житель: фасолина-тело, большая голова, лицо с эмоцией
# =============================================================
## pal: coat, coat_d, skin, skin_d, hair, scarf, hat, top ("hair"/"beanie"/"cap"/"hat"/"kerchief").
## face: normal, blink, happy, talk, shocked, angry, suspicious, worried, grin.
## opt: origin (точка ног), ink, dir, tilt, point, lantern.
static func villager(ci: CanvasItem, s: float, pal: Dictionary, face: String, opt: Dictionary = {}) -> void:
	var k: Color = opt.get("ink", INK)
	var lw := 3.0 * s
	var dir: float = opt.get("dir", 1.0)
	var p: Vector2 = opt.get("origin", Vector2.ZERO)
	for lx in [-11.0, 4.0]:
		shape(ci, rrect(Rect2(p.x + lx * s, p.y - 15 * s, 8 * s, 15 * s), 4 * s), Color("3a2e2a"), k, lw * 0.8)
	if opt.get("point", false):
		var a0 := p + Vector2(18 * dir * s, -54 * s)
		var a1 := p + Vector2(62 * dir * s, -74 * s)
		ci.draw_line(a0, a1, k, 12 * s, true)
		ci.draw_line(a0, a1, pal.coat, 7.5 * s, true)
		ci.draw_circle(a1, 6.5 * s, k)
		ci.draw_circle(a1, 4.8 * s, pal.skin)
	var body := Rect2(p.x - 28 * s, p.y - 74 * s, 56 * s, 62 * s)
	ci.draw_colored_polygon(rrect(body, 24 * s), pal.coat_d)
	ci.draw_colored_polygon(rrect(Rect2(body.position + Vector2(-2 * s, 0), body.size - Vector2(10 * s, 6 * s)), 22 * s), pal.coat)
	_outline(ci, rrect(body, 24 * s), k, lw)
	for by in [-50.0, -36.0]:
		ci.draw_circle(p + Vector2(-2 * s, by * s), 2.3 * s, Color(k, 0.7))
	shape(ci, rrect(Rect2(p.x - 24 * s, p.y - 78 * s, 48 * s, 12 * s), 6 * s), pal.scarf, k, lw * 0.85)
	ci.draw_line(p + Vector2(10 * s, -68 * s), p + Vector2(14 * s, -53 * s), k, 8.5 * s, true)
	ci.draw_line(p + Vector2(10 * s, -68 * s), p + Vector2(14 * s, -53 * s), pal.scarf, 5.5 * s, true)
	if opt.get("lantern", false):
		var h0 := p + Vector2(25 * dir * s, -38 * s)
		ci.draw_line(p + Vector2(19 * dir * s, -54 * s), h0, k, 11 * s, true)
		ci.draw_line(p + Vector2(19 * dir * s, -54 * s), h0, pal.coat, 6.5 * s, true)
		var lr := Rect2(h0.x - 7.5 * s, h0.y + 4 * s, 15 * s, 19 * s)
		ci.draw_line(h0, h0 + Vector2(0, 4 * s), k, 2.4 * s, true)
		shape(ci, rrect(lr, 4 * s), Color("ffcf6b"), k, lw * 0.8)
		ci.draw_line(Vector2(lr.position.x, lr.position.y + 5.5 * s), Vector2(lr.end.x, lr.position.y + 5.5 * s), k, 1.8 * s)
	var hc := p + Vector2(0, -104 * s)
	var tilt: float = opt.get("tilt", 0.0)
	ci.draw_set_transform(hc, tilt, Vector2.ONE)
	var o := Vector2.ZERO
	ci.draw_circle(o, 29 * s, pal.skin_d)
	ci.draw_circle(o + Vector2(-3 * s, -2 * s), 26 * s, pal.skin)
	_outline(ci, ellipse(o, Vector2(29 * s, 29 * s), 32), k, lw)
	_hair(ci, o, s, pal, k, lw)
	_face(ci, o, s, face, k)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _hair(ci: CanvasItem, o: Vector2, s: float, pal: Dictionary, k: Color, lw: float) -> void:
	var hat: Color = pal.get("hat", Color("3a3a58"))
	match String(pal.get("top", "hair")):
		"beanie":
			var pts := PackedVector2Array()
			for i in range(19):
				var a := PI + PI * i / 18.0
				pts.append(o + Vector2(cos(a) * 30 * s, sin(a) * 30 * s - 4 * s))
			shape(ci, pts, hat, k, lw)
			shape(ci, rrect(Rect2(o.x - 31 * s, o.y - 12 * s, 62 * s, 10 * s), 5 * s), hat.darkened(0.2), k, lw * 0.9)
			ci.draw_circle(o + Vector2(0, -35 * s), 7.5 * s, k)
			ci.draw_circle(o + Vector2(0, -35 * s), 5.8 * s, hat.lightened(0.25))
		"hat":
			shape(ci, rrect(Rect2(o.x - 38 * s, o.y - 21 * s, 76 * s, 9 * s), 4 * s), hat, k, lw)
			shape(ci, rrect(Rect2(o.x - 23 * s, o.y - 47 * s, 46 * s, 30 * s), 7 * s), hat, k, lw)
			ci.draw_rect(Rect2(o.x - 22 * s, o.y - 26 * s, 44 * s, 5 * s), pal.get("scarf", Color("c9573f")))
		"kerchief":
			var pts2 := PackedVector2Array([o + Vector2(-32 * s, 4 * s), o + Vector2(-25 * s, -21 * s), o + Vector2(0, -33 * s),
				o + Vector2(25 * s, -21 * s), o + Vector2(32 * s, 4 * s), o + Vector2(19 * s, -9 * s), o + Vector2(-19 * s, -9 * s)])
			shape(ci, pts2, hat, k, lw)
			for dx in [-13.0, 0.0, 13.0]:
				ci.draw_circle(o + Vector2(dx * s, -19 * s), 2.3 * s, Color(1, 1, 1, 0.7))
		"cap":
			var pts3 := PackedVector2Array()
			for i in range(15):
				var a := PI + PI * i / 14.0
				pts3.append(o + Vector2(cos(a) * 29 * s, sin(a) * 25 * s - 8 * s))
			shape(ci, pts3, hat, k, lw)
			shape(ci, rrect(Rect2(o.x - 5 * s, o.y - 13 * s, 42 * s, 7 * s), 3 * s), hat.darkened(0.25), k, lw * 0.9)
		_:
			var pts4 := PackedVector2Array()
			for i in range(21):
				var a := PI + PI * i / 20.0
				var rr := 30.0 + (3.0 if i % 4 == 2 else 0.0)
				pts4.append(o + Vector2(cos(a) * rr * s, sin(a) * rr * s * 0.95 - 2 * s))
			pts4.append(o + Vector2(19 * s, -8 * s))
			pts4.append(o + Vector2(-8 * s, -15 * s))
			pts4.append(o + Vector2(-23 * s, -6 * s))
			shape(ci, pts4, pal.hair, k, lw)


static func _face(ci: CanvasItem, o: Vector2, s: float, face: String, k: Color) -> void:
	var ey := -2.0 * s
	var ex := 10.5 * s
	if face != "grin":
		for sx in [-1.0, 1.0]:
			ci.draw_circle(o + Vector2(sx * 16 * s, 9 * s), 5.6 * s, Color(1.0, 0.45, 0.45, 0.35))
	match face:
		"blink":
			for sx in [-1.0, 1.0]:
				ci.draw_line(o + Vector2(sx * ex - 4.5 * s, ey), o + Vector2(sx * ex + 4.5 * s, ey), k, 2.8 * s, true)
			ci.draw_arc(o + Vector2(0, 7 * s), 6.5 * s, 0.4, PI - 0.4, 10, k, 2.6 * s, true)
		"happy":
			for sx in [-1.0, 1.0]:
				ci.draw_arc(o + Vector2(sx * ex, ey + 3 * s), 4.8 * s, PI * 1.1, PI * 1.9, 8, k, 2.8 * s, true)
			ci.draw_arc(o + Vector2(0, 8 * s), 7.5 * s, 0.25, PI - 0.25, 10, k, 2.8 * s, true)
		"talk":
			_eyes(ci, o, s, ex, ey, k)
			shape(ci, ellipse(o + Vector2(0, 11 * s), Vector2(5.5 * s, 4.8 * s), 14), Color("5a2a2a"), k, 2.2 * s)
		"shocked":
			for sx in [-1.0, 1.0]:
				ci.draw_circle(o + Vector2(sx * ex, ey), 8 * s, k)
				ci.draw_circle(o + Vector2(sx * ex, ey), 6.6 * s, Color(1, 1, 1))
				ci.draw_circle(o + Vector2(sx * ex, ey + 1 * s), 2.8 * s, k)
			shape(ci, ellipse(o + Vector2(0, 14 * s), Vector2(4.8 * s, 6.5 * s), 14), Color("5a2a2a"), k, 2.2 * s)
			var dp := o + Vector2(26 * s, -17 * s)
			ci.draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -8.5 * s), dp + Vector2(4.8 * s, 1 * s), dp + Vector2(-4.8 * s, 1 * s)]), Color("7cc6ff"))
			ci.draw_circle(dp + Vector2(0, 2 * s), 4.8 * s, Color("7cc6ff"))
		"angry":
			for sx in [-1.0, 1.0]:
				ci.draw_colored_polygon(ellipse(o + Vector2(sx * ex, ey + 1 * s), Vector2(4.3 * s, 5.6 * s), 12), k)
				ci.draw_line(o + Vector2(sx * (ex + 7 * s), ey - 11 * s), o + Vector2(sx * (ex - 6 * s), ey - 5.5 * s), k, 3.2 * s, true)
			shape(ci, rrect(Rect2(o.x - 8.5 * s, o.y + 8.5 * s, 17 * s, 10 * s), 5 * s), Color("5a2a2a"), k, 2.2 * s)
		"suspicious":
			for sx in [-1.0, 1.0]:
				ci.draw_colored_polygon(ellipse(o + Vector2(sx * ex, ey + 1 * s), Vector2(4.6 * s, 5.6 * s), 12), k)
				ci.draw_line(o + Vector2(sx * ex - 6.5 * s, ey - 1 * s), o + Vector2(sx * ex + 6.5 * s, ey - 2 * s), k, 3 * s, true)
			ci.draw_line(o + Vector2(-4 * s, 11 * s), o + Vector2(7 * s, 9.5 * s), k, 2.8 * s, true)
		"worried":
			_eyes(ci, o, s, ex, ey, k)
			for sx in [-1.0, 1.0]:
				ci.draw_line(o + Vector2(sx * (ex - 6 * s), ey - 12 * s), o + Vector2(sx * (ex + 6 * s), ey - 8.5 * s), k, 2.8 * s, true)
			var wv := PackedVector2Array()
			for i in range(9):
				wv.append(o + Vector2(-7.5 * s + i * 1.9 * s, 12.5 * s + sin(i * 1.4) * 1.5 * s))
			ci.draw_polyline(wv, k, 2.4 * s, true)
		"grin":
			for sx in [-1.0, 1.0]:
				shape(ci, ellipse(o + Vector2(sx * ex, ey - 1 * s), Vector2(6.2 * s, 7.2 * s), 14), Color("0a0608"), k, 1.0)
				ci.draw_circle(o + Vector2(sx * ex, ey), 1.8 * s, Color(1.0, 0.25, 0.15))
			var top := PackedVector2Array()
			var bot := PackedVector2Array()
			for i in range(17):
				var a := PI * 0.08 + PI * 0.84 * i / 16.0
				top.append(o + Vector2(-cos(a) * 21 * s, 8 * s + sin(a) * 3 * s))
				bot.append(o + Vector2(-cos(a) * 19 * s, 9 * s + sin(a) * 12 * s))
			var mouth := top.duplicate()
			for i in range(bot.size() - 1, -1, -1):
				mouth.append(bot[i])
			shape(ci, mouth, Color("f4efe0"), k, 2.2 * s)
			for i in range(1, 9):
				var x := -19 * s + i * 4.2 * s
				ci.draw_line(o + Vector2(x, 9 * s), o + Vector2(x, 9 * s + 10 * s * sin(PI * i / 9.0)), Color(k, 0.8), 1.3 * s)
		_:
			_eyes(ci, o, s, ex, ey, k)
			ci.draw_arc(o + Vector2(0, 7 * s), 6.5 * s, 0.4, PI - 0.4, 10, k, 2.6 * s, true)


static func _eyes(ci: CanvasItem, o: Vector2, s: float, ex: float, ey: float, k: Color) -> void:
	for sx in [-1.0, 1.0]:
		ci.draw_colored_polygon(ellipse(o + Vector2(sx * ex, ey + 1 * s), Vector2(4.3 * s, 5.8 * s), 12), k)
		ci.draw_circle(o + Vector2(sx * ex - 1.4 * s, ey - 1.5 * s), 1.6 * s, Color(1, 1, 1))
