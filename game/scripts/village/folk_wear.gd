class_name FolkWear
extends RefCounted
## Национальные головные уборы и грим: ушанка, охотничья кепка сыщика, берет, фригийский колпак,
## шляпа мушкетёра, сомбреро, феска, тюрбан, нон-ла, золотой обруч, колпак шута, шляпа кангасейро,
## маска лучадора, шляпа и грим Катрины, венок, цилиндр, соломенная шляпа, кокошник.
## Цвет убора — look.accent или look.coat, у соломы и золота — свои.
## Координаты — как в Folk.head: o — центр головы, r = Folk.HEAD_R * s.

const STRAW := Color("e2c27a")
const GOLD := Color("f2c94c")
const RED := Color("c8352e")


static func _c(pal: Dictionary, col: Color) -> Color:
	return Art.dn(col, float(pal.get("n", 0.0)))


static func hat(ci: CanvasItem, o: Vector2, s: float, look: LookDef, pal: Dictionary, k: Color, lw: float) -> void:
	var r := Folk.HEAD_R * s
	var acc: Color = pal.accent
	var coat: Color = pal.coat_d
	match look.head:
		LookDef.Head.USHANKA:
			var fur := coat.darkened(0.15)
			for sx: float in [-1.0, 1.0]:
				Art.shape(ci, Art.rrect(Rect2(o.x + sx * r * 1.02 - r * 0.22, o.y - r * 0.35, r * 0.44, r * 1.0), 8 * s), fur, k, lw)
			var top := PackedVector2Array()
			for i in range(17):
				var a := PI + PI * i / 16.0
				top.append(o + Vector2(cos(a) * r * 1.1, sin(a) * r * 1.0 - 8 * s))
			Art.shape(ci, top, acc, k, lw)
			Art.shape(ci, Art.rrect(Rect2(o.x - r * 1.2, o.y - r * 0.62, r * 2.4, r * 0.42), 9 * s), fur, k, lw)
			for i in range(9):
				ci.draw_line(o + Vector2(-r * 1.05 + i * r * 0.26, -r * 0.58), o + Vector2(-r * 1.0 + i * r * 0.26, -r * 0.26), Color(k, 0.25), 1.3 * s, true)
		LookDef.Head.DEERSTALKER:
			var cap := PackedVector2Array()
			for i in range(17):
				var a := PI + PI * i / 16.0
				cap.append(o + Vector2(cos(a) * r * 1.06, sin(a) * r * 0.92 - 8 * s))
			Art.shape(ci, cap, acc, k, lw)
			for i in range(5):
				var x := o.x - r * 0.8 + i * r * 0.4
				ci.draw_line(Vector2(x, o.y - r * 0.95), Vector2(x, o.y - r * 0.15), Color(k, 0.3), 1.4 * s, true)
			for j in range(2):
				var y := o.y - r * (0.75 - j * 0.3)
				ci.draw_line(Vector2(o.x - r * 0.95, y), Vector2(o.x + r * 0.95, y), Color(k, 0.3), 1.4 * s, true)
			for sx: float in [-1.0, 1.0]:
				Art.shape(ci, PackedVector2Array([o + Vector2(sx * r * 0.2, -r * 0.18), o + Vector2(sx * r * 1.25, -r * 0.12), o + Vector2(sx * r * 0.9, r * 0.02)]), acc.darkened(0.15), k, lw * 0.8)
			Art.shape(ci, Art.ellipse(o + Vector2(0, -r * 1.12), Vector2(5 * s, 3.5 * s), 10), acc.darkened(0.2), k, lw * 0.6)
		LookDef.Head.BERET:
			var bc := o + Vector2(r * 0.12, -r * 0.92)
			var pts := Art.ellipse(bc, Vector2(r * 1.05, r * 0.38), 24)
			var rot := PackedVector2Array()
			for q: Vector2 in pts:
				rot.append(bc + (q - bc).rotated(-0.12))
			Art.shape(ci, rot, coat.darkened(0.2), k, lw)
			ci.draw_line(bc + Vector2(0, -r * 0.36), bc + Vector2(2 * s, -r * 0.52), k, 3.5 * s, true)
		LookDef.Head.PHRYGIAN, LookDef.Head.JESTER:
			var col := _c(pal, RED) if look.head == LookDef.Head.PHRYGIAN else acc
			var cone := PackedVector2Array([o + Vector2(-r * 1.08, -r * 0.35), o + Vector2(-r * 0.9, -r * 1.0), o + Vector2(-r * 0.2, -r * 1.45),
				o + Vector2(r * 0.55, -r * 1.55), o + Vector2(r * 1.1, -r * 1.2), o + Vector2(r * 0.95, -r * 0.95), o + Vector2(r * 1.08, -r * 0.35)])
			Art.shape(ci, cone, col, k, lw)
			Art.shape(ci, Art.rrect(Rect2(o.x - r * 1.12, o.y - r * 0.5, r * 2.24, r * 0.26), 5 * s), col.darkened(0.2), k, lw * 0.8)
			if look.head == LookDef.Head.PHRYGIAN:
				var ck := o + Vector2(-r * 0.62, -r * 0.62)
				for c: Array in [[7.0, Color("2f5fb3")], [5.0, Color(1, 1, 1)], [3.0, Color("c8352e")]]:
					ci.draw_circle(ck, float(c[0]) * s, _c(pal, c[1]))
			else:
				# второй рог колпака и бубенцы
				Art.shape(ci, PackedVector2Array([o + Vector2(-r * 0.6, -r * 0.9), o + Vector2(-r * 1.45, -r * 1.25), o + Vector2(-r * 1.05, -r * 0.55)]), pal.coat, k, lw)
				for b: Vector2 in [Vector2(1.12, -1.22), Vector2(-1.48, -1.27)]:
					ci.draw_circle(o + b * r, 5.5 * s, k)
					ci.draw_circle(o + b * r, 4.2 * s, _c(pal, GOLD))
		LookDef.Head.MUSKETEER, LookDef.Head.CANGACEIRO, LookDef.Head.CATRINA, LookDef.Head.SOMBRERO, LookDef.Head.STRAW:
			_wide_hat(ci, o, s, look, pal, k, lw)
		LookDef.Head.FEZ:
			var fz := PackedVector2Array([o + Vector2(-r * 0.62, -r * 0.62), o + Vector2(r * 0.62, -r * 0.62), o + Vector2(r * 0.5, -r * 1.42), o + Vector2(-r * 0.5, -r * 1.42)])
			Art.shape(ci, fz, _c(pal, RED), k, lw)
			ci.draw_line(o + Vector2(0, -r * 1.42), o + Vector2(r * 0.42, -r * 1.12), k, 2.0 * s, true)
			Art.shape(ci, Art.ellipse(o + Vector2(r * 0.48, -r * 0.95), Vector2(3 * s, 7 * s), 10), Art.ink(0.0).lightened(0.15), k, lw * 0.5)
		LookDef.Head.TURBAN:
			var tb := PackedVector2Array()
			for i in range(19):
				var a := PI + PI * i / 18.0
				tb.append(o + Vector2(cos(a) * r * 1.16, sin(a) * r * 1.02 - 10 * s))
			tb.append(o + Vector2(r * 1.12, -r * 0.2))
			tb.append(o + Vector2(-r * 1.12, -r * 0.2))
			Art.shape(ci, tb, acc, k, lw)
			for i in range(4):
				ci.draw_arc(o + Vector2(0, -r * 0.2 + i * 2 * s), r * (0.55 + i * 0.16), PI * 1.15, PI * 1.85, 10, Color(k, 0.3), 1.6 * s, true)
			Art.shape(ci, Art.ellipse(o + Vector2(0, -r * 0.62), Vector2(5 * s, 6 * s), 10), _c(pal, Color("2fa37a")), k, lw * 0.6)
		LookDef.Head.CONICAL:
			var nl := PackedVector2Array([o + Vector2(-r * 1.65, -r * 0.42), o + Vector2(0, -r * 1.75), o + Vector2(r * 1.65, -r * 0.42), o + Vector2(0, -r * 0.3)])
			Art.shape(ci, nl, _c(pal, STRAW), k, lw)
			for i in range(1, 4):
				var t := float(i) / 4.0
				ci.draw_line(o + Vector2(-r * 1.65 * t, -r * (1.75 - 1.33 * t)), o + Vector2(r * 1.65 * t, -r * (1.75 - 1.33 * t)), Color(k, 0.25), 1.4 * s, true)
			for sx: float in [-1.0, 1.0]:
				ci.draw_line(o + Vector2(sx * r * 0.85, -r * 0.4), o + Vector2(sx * r * 0.45, r * 0.95), Color(acc, 0.9), 2.0 * s, true)
		LookDef.Head.GOLD_BAND:
			var band := PackedVector2Array()
			for i in range(13):
				var a := PI * 1.12 + PI * 0.76 * i / 12.0
				band.append(o + Vector2(cos(a) * r * 1.02, sin(a) * r * 0.62 - r * 0.25))
			ci.draw_polyline(band, k, 8.5 * s, true)
			ci.draw_polyline(band, _c(pal, GOLD), 5.5 * s, true)
			for sx: float in [-1.0, 1.0]:
				var e: Vector2 = band[0] if sx < 0 else band[band.size() - 1]
				ci.draw_arc(e + Vector2(sx * 5 * s, -5 * s), 5 * s, 0, TAU * 0.8, 10, _c(pal, GOLD), 3.0 * s, true)
		LookDef.Head.FLOWER_CROWN:
			for i in range(7):
				var a := PI * 1.08 + PI * 0.84 * i / 6.0
				var c := o + Vector2(cos(a) * r * 0.98, sin(a) * r * 0.9 - 2 * s)
				var cols := [Color("e8505b"), Color("f9a03f"), Color("f6d743"), Color("e8505b"), Color("b05fd0"), Color("f9a03f"), Color("e8505b")]
				for j in range(5):
					var aj := TAU * j / 5.0
					ci.draw_circle(c + Vector2(cos(aj), sin(aj)) * 3.6 * s, 3.2 * s, _c(pal, cols[i]))
				ci.draw_circle(c, 2.2 * s, _c(pal, GOLD))
		LookDef.Head.TOP_HAT:
			Art.shape(ci, Art.rrect(Rect2(o.x - r * 1.25, o.y - r * 0.72, r * 2.5, 8 * s), 4 * s), coat.darkened(0.3), k, lw)
			Art.shape(ci, Art.rrect(Rect2(o.x - r * 0.72, o.y - r * 1.95, r * 1.44, r * 1.28), 4 * s), coat.darkened(0.3), k, lw)
			ci.draw_rect(Rect2(o.x - r * 0.7, o.y - r * 0.92, r * 1.4, 6 * s), acc)
		LookDef.Head.KOKOSHNIK:
			var kk := PackedVector2Array()
			for i in range(17):
				var a := PI + PI * i / 16.0
				kk.append(o + Vector2(cos(a) * r * 1.08, sin(a) * r * 1.55 - r * 0.3))
			Art.shape(ci, kk, _c(pal, RED), k, lw)
			ci.draw_arc(o + Vector2(0, -r * 0.3), r * 0.9, PI * 1.08, PI * 1.92, 16, _c(pal, GOLD), 3.2 * s, true)
			for i in range(5):
				var a2 := PI * 1.2 + PI * 0.6 * i / 4.0
				ci.draw_circle(o + Vector2(cos(a2) * r * 0.62, sin(a2) * r * 1.0 - r * 0.3), 3.4 * s, _c(pal, Color(1, 0.96, 0.85)))
			Art.shape(ci, Art.ellipse(o + Vector2(0, -r * 1.42), Vector2(6 * s, 6 * s), 12), _c(pal, Color("2f5fb3")), k, lw * 0.6)


## Широкополые шляпы: поле — эллипс, тулья — прямоугольник, украшения по виду.
static func _wide_hat(ci: CanvasItem, o: Vector2, s: float, look: LookDef, pal: Dictionary, k: Color, lw: float) -> void:
	var r := Folk.HEAD_R * s
	var acc: Color = pal.accent
	var col: Color = pal.coat_d
	var brim := 1.55
	var crown_h := 0.95
	match look.head:
		LookDef.Head.SOMBRERO:
			col = _c(pal, STRAW)
			brim = 2.05
			crown_h = 1.2
		LookDef.Head.STRAW:
			col = _c(pal, STRAW)
			brim = 1.6
			crown_h = 0.6
		LookDef.Head.CANGACEIRO:
			col = _c(pal, Color("8a5a32"))
		LookDef.Head.CATRINA:
			col = Art.ink(float(pal.get("n", 0.0))).lightened(0.12)
			brim = 1.75
			crown_h = 0.7
		LookDef.Head.MUSKETEER:
			brim = 1.6
			crown_h = 0.75
	var by := o.y - r * 0.68
	if look.head == LookDef.Head.CANGACEIRO:
		# полумесяц: поле загнуто вверх спереди, по краю звёзды и монетки
		var moon := PackedVector2Array()
		for i in range(19):
			var a := PI + PI * i / 18.0
			moon.append(Vector2(o.x + cos(a) * r * 1.5, by + sin(a) * r * 1.15))
		for i in range(18, -1, -1):
			var a := PI + PI * i / 18.0
			moon.append(Vector2(o.x + cos(a) * r * 1.05, by + 6 * s + sin(a) * r * 0.55))
		Art.shape(ci, moon, col, k, lw)
		for i in range(5):
			var a2 := PI * 1.2 + PI * 0.6 * i / 4.0
			ci.draw_circle(Vector2(o.x + cos(a2) * r * 1.28, by + sin(a2) * r * 0.85), 3.4 * s, _c(pal, GOLD))
		return
	var brim_pts := Art.ellipse(Vector2(o.x, by), Vector2(r * brim, r * 0.26), 28)
	if look.head == LookDef.Head.MUSKETEER:
		var tilted := PackedVector2Array()
		for q: Vector2 in brim_pts:
			var d := q - Vector2(o.x, by)
			tilted.append(Vector2(o.x, by) + Vector2(d.x, d.y - (r * 0.45 if d.x > 0 else 0.0) * (d.x / (r * brim))))
		brim_pts = tilted
	Art.shape(ci, brim_pts, col, k, lw)
	var crown := Art.rrect(Rect2(o.x - r * 0.72, by - r * crown_h, r * 1.44, r * crown_h + 4 * s), 9 * s)
	Art.shape(ci, crown, col, k, lw)
	ci.draw_rect(Rect2(o.x - r * 0.7, by - r * 0.3, r * 1.4, 6 * s), acc)
	match look.head:
		LookDef.Head.SOMBRERO:
			for i in range(9):
				var x := o.x - r * 1.6 + i * r * 0.4
				ci.draw_line(Vector2(x, by - 2 * s), Vector2(x + r * 0.2, by + 4 * s), Color(acc, 0.9), 2.2 * s, true)
		LookDef.Head.MUSKETEER:
			var plume := PackedVector2Array()
			for i in range(10):
				var t := float(i) / 9.0
				plume.append(Vector2(o.x - r * 0.5 - t * r * 1.0, by - r * 0.7 - sin(t * PI) * r * 0.5 + t * r * 0.3))
			ci.draw_polyline(plume, k, 11 * s, true)
			ci.draw_polyline(plume, _c(pal, Color(1, 0.96, 0.9)), 8 * s, true)
		LookDef.Head.CATRINA:
			for q: Vector2 in [Vector2(-0.95, -0.12), Vector2(-0.55, -0.32), Vector2(0.75, -0.2), Vector2(1.15, -0.05)]:
				var c := Vector2(o.x, by) + q * r
				for j in range(6):
					var aj := TAU * j / 6.0
					ci.draw_circle(c + Vector2(cos(aj), sin(aj)) * 4.5 * s, 3.8 * s, _c(pal, Color("e8505b") if q.x < 0 else Color("f9a03f")))
				ci.draw_circle(c, 2.8 * s, _c(pal, GOLD))
			ci.draw_line(Vector2(o.x + r * 0.3, by - r * 0.6), Vector2(o.x + r * 0.9, by - r * 1.3), _c(pal, Color("b05fd0")), 5 * s, true)


## Маска лучадора: закрывает голову, вокруг глаз и рта — белая окантовка «языками пламени».
static func mask(ci: CanvasItem, o: Vector2, s: float, pal: Dictionary, k: Color, inner: PackedVector2Array) -> void:
	var r := Folk.HEAD_R * s
	var col: Color = pal.accent
	ci.draw_colored_polygon(inner, col)
	var trim := _c(pal, Color(1, 1, 1))
	for sx: float in [-1.0, 1.0]:
		var c := o + Vector2(sx * 12.5 * s, 1 * s)
		var fl := PackedVector2Array()
		for i in range(14):
			var a := TAU * i / 14.0
			var rr := (12.5 if i % 2 == 0 else 10.0) * s
			fl.append(c + Vector2(cos(a) * rr * (1.25 if sx * cos(a) > 0.3 else 1.0), sin(a) * rr))
		Art.shape(ci, fl, trim, Color(k, 0.6), 1.4 * s)
	Art.shape(ci, Art.ellipse(o + Vector2(0, 21 * s), Vector2(12 * s, 8 * s), 16), trim, Color(k, 0.6), 1.4 * s)
	ci.draw_line(o + Vector2(0, -r * 0.95), o + Vector2(0, -r * 0.3), trim, 3 * s, true)


## Грим Катрины: светлое лицо, тёмные круги вокруг глаз с лепестками, нос сердечком.
static func catrina_paint(ci: CanvasItem, o: Vector2, s: float, pal: Dictionary, k: Color, inner: PackedVector2Array) -> void:
	ci.draw_colored_polygon(inner, _c(pal, Color(0.97, 0.95, 0.92)))
	for sx: float in [-1.0, 1.0]:
		var c := o + Vector2(sx * 12.5 * s, 1 * s)
		for j in range(8):
			var aj := TAU * j / 8.0
			ci.draw_circle(c + Vector2(cos(aj), sin(aj)) * 12 * s, 3.2 * s, _c(pal, Color("e8505b") if j % 2 == 0 else Color("2f8fd0")))
		ci.draw_circle(c, 11.5 * s, Art.ink(float(pal.get("n", 0.0))))
	var nc := o + Vector2(0, 9 * s)
	ci.draw_colored_polygon(PackedVector2Array([nc + Vector2(-4 * s, -2 * s), nc + Vector2(4 * s, -2 * s), nc + Vector2(0, 4 * s)]), Art.ink(float(pal.get("n", 0.0))))


## Стежки поперёк рта у Катрины — поверх обычного рта.
static func catrina_stitches(ci: CanvasItem, o: Vector2, s: float, k: Color) -> void:
	var mc := o + Vector2(0, 20 * s)
	ci.draw_line(mc + Vector2(-13 * s, 0), mc + Vector2(13 * s, 0), k, 1.6 * s, true)
	for i in range(7):
		var x := -12 * s + i * 4 * s
		ci.draw_line(mc + Vector2(x, -3.5 * s), mc + Vector2(x, 3.5 * s), k, 1.4 * s, true)
