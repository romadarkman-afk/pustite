class_name Folk
extends RefCounted
## Жители нового образца: крупная голова (больше половины роста), лицо с белками глаз,
## бровями, носом и ртом, свои приметы у каждого. Тело собрано из частей — ноги, руки,
## туловище, голова — и рисуется по позе: так получаются шаг, жесты и работа у дела.
##
## Координаты: начало — между ступнями, вверх — минус. Рост при s = 1 около 126 единиц,
## голова — круг радиусом 34 с центром на высоте 90.

const HEAD_Y := -90.0
const HEAD_R := 34.0
const HIP_Y := -22.0
const SHOULDER_Y := -52.0

## Все лица, которые умеют рисоваться. Самотест проверяет, что каждое рисует своё.
const FACES: PackedStringArray = ["neutral", "blink", "talk", "happy", "shocked", "scared", "angry",
	"suspicious", "sad", "relieved", "sly", "confused", "cold"]


## Палитра по внешности. n — ночь 0..1: краски уходят в синеву.
static func palette(look: LookDef, n: float = 0.0) -> Dictionary:
	var coat := _bright(look.coat)
	var hair := look.hair
	if look.age >= 2:
		hair = hair.lerp(Color("c9c4bc"), 0.75)
	return {
		"coat": Art.dn(coat, n), "coat_d": Art.dn(coat.darkened(0.22), n),
		"skin": Art.dn(look.skin.lightened(0.06), n), "skin_d": Art.dn(look.skin.darkened(0.12), n),
		"hair": Art.dn(hair, n), "hair_d": Art.dn(hair.darkened(0.25), n),
		"accent": Art.dn(_bright(look.accent), n), "eye": Art.dn(look.eye, n),
		"pants": Art.dn(Color("3b3346"), n), "shoe": Art.dn(Color("2e2420"), n),
		"hat": Art.dn(_hat_color(look, coat), n), "ink": Art.ink(n),
	}


static func _bright(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.25 + 0.08), minf(1.0, c.v * 1.4 + 0.08), c.a)


static func _hat_color(look: LookDef, coat: Color) -> Color:
	match look.head:
		LookDef.Head.CAP: return coat.darkened(0.4)
		LookDef.Head.SCARF: return _bright(look.accent)
		LookDef.Head.HOOD: return _bright(look.accent).darkened(0.1)
	return Color("3b3b58")


## Нарисовать жителя целиком. pose: walk (фаза шага 0..1), amp (размах шага 0..1),
## arm_l / arm_r (угол руки от опущенной, рад), look (Vector2, куда смотрят глаза),
## turn (−1..1, поворот головы вбок), tilt (наклон головы, рад), lantern, point (указать рукой),
## shiver (ёжится от холода), tool ("bucket", "axe", "oar", "can", "chalk") и work (фаза работы 0..1).
static func figure(ci: CanvasItem, o: Vector2, s: float, look: LookDef, face: String, pose: Dictionary = {}, pal: Dictionary = {}) -> void:
	if pal.is_empty():
		pal = palette(look)
	var k: Color = pal.ink
	var lw := 2.8 * s
	var h: float = look.height
	var ph: float = pose.get("walk", 0.0)
	var amp: float = pose.get("amp", 0.0)
	var sw := sin(ph * TAU) * amp
	var bob := -absf(sin(ph * TAU)) * 3.0 * amp * s
	var shiver: bool = pose.get("shiver", false)
	var jit := Vector2(sin(Time.get_ticks_msec() * 0.06) * 0.8 * s, 0.0) if shiver else Vector2.ZERO
	var p := o + Vector2(0, bob) + jit

	# тень под ногами
	ci.draw_colored_polygon(Art.ellipse(o + Vector2(0, 1.5 * s), Vector2(24 * s, 5 * s), 18), Color(0, 0, 0, 0.22))

	# ноги: шаг — бёдра качаются вперёд-назад, стопа поднимается
	for side: float in [-1.0, 1.0]:
		var swing := sw * side
		var hip := p + Vector2(side * 7.5 * s, HIP_Y * s * h)
		var foot := o + Vector2(side * 7.5 * s + swing * 9.0 * s, -maxf(0.0, swing) * 6.0 * s)
		_limb(ci, hip, foot, 10.5 * s, pal.pants, k, lw * 0.9)
		Art.shape(ci, Art.ellipse(foot + Vector2(side * 1.5 * s, -1.5 * s), Vector2(7.5 * s, 4.2 * s), 12), pal.shoe, k, lw * 0.8)

	# дальняя рука — за туловищем
	var arm_l: float = pose.get("arm_l", 0.12 + sw * 0.55)
	var arm_r: float = pose.get("arm_r", 0.12 - sw * 0.55)
	if shiver:
		arm_l = -2.2
		arm_r = -2.2
	var sh_y := SHOULDER_Y * s * h
	var tool: String = pose.get("tool", "")
	var work: float = pose.get("work", 0.0)
	if tool != "":
		var t := _tool_pose(tool, work)
		arm_l = t.x
		arm_r = t.y

	# туловище: пальто трапецией, пуговицы, шарф
	var top := p.y + sh_y - 6.0 * s
	var bottom := p.y + HIP_Y * s * h + 4.0 * s
	var body := PackedVector2Array([
		Vector2(p.x - 15 * s, top), Vector2(p.x + 15 * s, top),
		Vector2(p.x + 21 * s, bottom - 4 * s), Vector2(p.x + 18 * s, bottom), Vector2(p.x - 18 * s, bottom), Vector2(p.x - 21 * s, bottom - 4 * s)])
	Art.shape(ci, body, pal.coat, k, lw)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(p.x + 4 * s, top + 2 * s), Vector2(p.x + 14 * s, top + 2 * s),
		Vector2(p.x + 19 * s, bottom - 5 * s), Vector2(p.x + 8 * s, bottom - 2 * s)]), Color(pal.coat_d, 0.55))
	for by: float in [0.38, 0.7]:
		ci.draw_circle(Vector2(p.x - 1.5 * s, lerpf(top, bottom, by)), 2.0 * s, Color(k, 0.75))

	var lsh := Vector2(p.x - 15 * s, p.y + sh_y)
	var rsh := Vector2(p.x + 15 * s, p.y + sh_y)
	var arm_len := 23.0 * s
	var lhand := lsh + Vector2(-sin(arm_l), cos(arm_l)) * arm_len
	var rhand := rsh + Vector2(sin(arm_r), cos(arm_r)) * arm_len
	if pose.get("point", false):
		var dir: float = pose.get("dir", 1.0)
		if dir > 0.0:
			rhand = rsh + Vector2(0.95, -0.35).normalized() * arm_len * 1.15
		else:
			lhand = lsh + Vector2(-0.95, -0.35).normalized() * arm_len * 1.15
	_limb(ci, lsh, lhand, 8.5 * s, pal.coat, k, lw * 0.85)
	_limb(ci, rsh, rhand, 8.5 * s, pal.coat, k, lw * 0.85)
	for hand: Vector2 in [lhand, rhand]:
		ci.draw_circle(hand, 5.2 * s, k)
		ci.draw_circle(hand, 4.0 * s, pal.skin)
	if tool != "":
		_draw_tool(ci, tool, lhand, rhand, work, s, k)
	if pose.get("lantern", false) and tool == "":
		var hand := rhand
		ci.draw_line(hand, hand + Vector2(0, 5 * s), k, 2.2 * s, true)
		var lr := Rect2(hand.x - 7 * s, hand.y + 5 * s, 14 * s, 18 * s)
		Art.shape(ci, Art.rrect(lr, 4 * s), Color("ffcf6b"), k, lw * 0.8)
		ci.draw_line(Vector2(lr.position.x, lr.position.y + 5 * s), Vector2(lr.end.x, lr.position.y + 5 * s), k, 1.6 * s)
		ci.draw_circle(lr.get_center() + Vector2(0, 2 * s), 3.2 * s, Color(1, 0.95, 0.7))

	# шарф поверх шеи
	Art.shape(ci, Art.rrect(Rect2(p.x - 17 * s, top - 6 * s, 34 * s, 11 * s), 5 * s), pal.accent, k, lw * 0.85)
	ci.draw_line(Vector2(p.x + 8 * s, top + 3 * s), Vector2(p.x + 11 * s, top + 16 * s), k, 7.5 * s, true)
	ci.draw_line(Vector2(p.x + 8 * s, top + 3 * s), Vector2(p.x + 11 * s, top + 16 * s), pal.accent, 4.8 * s, true)

	# голова
	var hc := Vector2(p.x, p.y + HEAD_Y * s * h)
	head(ci, hc, s, look, face, pose, pal)


## Голова с лицом и причёской. Отдельно — для портретов на экранах и в дневнике.
static func head(ci: CanvasItem, c: Vector2, s: float, look: LookDef, face: String, pose: Dictionary = {}, pal: Dictionary = {}) -> void:
	if pal.is_empty():
		pal = palette(look)
	var k: Color = pal.ink
	var lw := 2.8 * s
	var tilt: float = pose.get("tilt", 0.0)
	var turn: float = clampf(pose.get("turn", 0.0), -1.0, 1.0)
	ci.draw_set_transform(c, tilt, Vector2.ONE)
	var o := Vector2.ZERO
	var r := HEAD_R * s
	_hair_back(ci, o, s, look, pal, k, lw)
	# лицо: чуть шире, чем выше; тень одним тоном с края
	var head_pts := Art.ellipse(o, Vector2(r * 1.03, r), 36)
	ci.draw_colored_polygon(head_pts, pal.skin_d)
	ci.draw_colored_polygon(Art.ellipse(o + Vector2(-2.5 * s, -2 * s), Vector2(r * 0.95, r * 0.93), 36), pal.skin)
	var outl := head_pts.duplicate()
	outl.append(head_pts[0])
	ci.draw_polyline(outl, k, lw, true)
	# уши
	for side: float in [-1.0, 1.0]:
		var ear := o + Vector2(side * (r * 1.02 - turn * side * 3 * s), 4 * s)
		Art.shape(ci, Art.ellipse(ear, Vector2(4.5 * s, 7 * s), 10), pal.skin, k, lw * 0.75)
	var fo := o + Vector2(turn * 7.0 * s, 0)    # черты лица уезжают в сторону поворота
	_face(ci, fo, s, look, face, pose, pal, k)
	_hair_front(ci, o, s, look, pal, k, lw)
	_hat(ci, o, s, look, pal, k, lw)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------
# Лицо
# ---------------------------------------------------------------
static func _face(ci: CanvasItem, o: Vector2, s: float, look: LookDef, face: String, pose: Dictionary, pal: Dictionary, k: Color) -> void:
	var ex := 12.5 * s
	var ey := 1.0 * s
	var look_dir: Vector2 = pose.get("look", Vector2.ZERO)
	var blush := Color(1.0, 0.42, 0.42, 0.32)
	if face != "sly" and face != "cold":
		for sx: float in [-1.0, 1.0]:
			ci.draw_circle(o + Vector2(sx * 21 * s, 14 * s), 6 * s, blush)
	if face == "cold":
		for sx: float in [-1.0, 1.0]:
			ci.draw_circle(o + Vector2(sx * 21 * s, 14 * s), 6 * s, Color(0.55, 0.75, 1.0, 0.35))
	if look.freckles:
		for sx: float in [-1.0, 1.0]:
			for f: Vector2 in [Vector2(18, 9), Vector2(23, 11), Vector2(20, 14), Vector2(25, 15)]:
				ci.draw_circle(o + Vector2(sx * f.x * s, f.y * s), 1.15 * s, Color(pal.skin_d.darkened(0.25), 0.9))
	if look.age >= 2:
		for sx: float in [-1.0, 1.0]:
			ci.draw_line(o + Vector2(sx * 22 * s, ey - 1 * s), o + Vector2(sx * 25 * s, ey - 3 * s), Color(k, 0.45), 1.3 * s, true)
			ci.draw_line(o + Vector2(sx * 22 * s, ey + 2 * s), o + Vector2(sx * 25 * s, ey + 3 * s), Color(k, 0.45), 1.3 * s, true)
		ci.draw_line(o + Vector2(-8 * s, -17 * s), o + Vector2(8 * s, -17 * s), Color(k, 0.3), 1.3 * s, true)

	# глаза
	match face:
		"blink", "relieved":
			for sx: float in [-1.0, 1.0]:
				ci.draw_arc(o + Vector2(sx * ex, ey + 1 * s), 5.5 * s, 0.25, PI - 0.25, 10, k, 2.6 * s, true)
		"happy":
			for sx: float in [-1.0, 1.0]:
				ci.draw_arc(o + Vector2(sx * ex, ey + 3 * s), 5.5 * s, PI * 1.1, PI * 1.9, 10, k, 2.8 * s, true)
		"sly":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey), s, pal, k, look_dir + Vector2(sx * 0.3, 0), 0.55, Color(0.95, 0.85, 0.4))
		"shocked", "scared":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey), s * 1.18, pal, k, look_dir, 0.0, pal.eye, 0.55)
		"suspicious":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey), s, pal, k, look_dir + Vector2(0.8, 0), 0.5)
		"sad":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey + 1 * s), s, pal, k, look_dir + Vector2(0, 0.6), 0.3)
		"cold":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey), s, pal, k, look_dir, 0.35)
		_:
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey), s, pal, k, look_dir, 0.0)

	# брови: толщина и наклон — свои у каждого, эмоция их сдвигает
	var bw := 2.4 * s if look.brows == LookDef.Brows.THIN else 4.2 * s
	var base_tilt := 0.25 if look.brows == LookDef.Brows.STERN else 0.0
	var by := -10.0 * s
	for sx: float in [-1.0, 1.0]:
		var inner := o + Vector2(sx * 6 * s, by)
		var outer := o + Vector2(sx * 19 * s, by - 2 * s)
		var lift := base_tilt
		match face:
			"angry": lift = 0.75
			"suspicious": lift = 0.45 if sx > 0 else -0.25
			"sad", "scared", "cold": lift = -0.6
			"shocked": lift = -0.2
			"confused": lift = 0.5 if sx < 0 else -0.5
			"sly": lift = 0.55
			"happy", "relieved": lift = -0.15
		inner.y += lift * 7 * s
		outer.y -= lift * 2 * s
		if face == "shocked" or face == "scared":
			inner.y -= 4 * s
			outer.y -= 4 * s
		ci.draw_line(inner, outer, pal.hair_d if look.age < 2 else pal.hair, bw, true)

	# нос
	var nc := o + Vector2(0, 9 * s)
	match look.nose:
		LookDef.Nose.LONG:
			ci.draw_polyline(PackedVector2Array([nc + Vector2(0, -6 * s), nc + Vector2(2.5 * s, 3 * s), nc + Vector2(-1.5 * s, 4.5 * s)]), Color(k, 0.75), 2.0 * s, true)
		LookDef.Nose.ROUND:
			Art.shape(ci, Art.ellipse(nc + Vector2(0, 1 * s), Vector2(4.8 * s, 4.0 * s), 12), pal.skin_d, Color(k, 0.5), 1.4 * s)
		_:
			ci.draw_colored_polygon(Art.ellipse(nc, Vector2(2.8 * s, 2.2 * s), 10), pal.skin_d)
			ci.draw_arc(nc, 2.8 * s, 0.2, PI - 0.2, 6, Color(k, 0.55), 1.4 * s, true)

	# рот
	var mc := o + Vector2(0, 19 * s)
	var mouth_in := Color("5a2a2a")
	match face:
		"talk":
			Art.shape(ci, Art.ellipse(mc, Vector2(5.5 * s, 4.6 * s), 14), mouth_in, k, 2.0 * s)
			ci.draw_colored_polygon(Art.ellipse(mc + Vector2(0, 2.2 * s), Vector2(3.2 * s, 1.6 * s), 10), Color("d06a6a"))
		"happy":
			var pts := PackedVector2Array()
			for i in range(9):
				var a := PI * i / 8.0
				pts.append(mc + Vector2(cos(a) * 8 * s, sin(a) * 6 * s - 2 * s))
			Art.shape(ci, pts, mouth_in, k, 2.0 * s)
		"shocked":
			Art.shape(ci, Art.ellipse(mc + Vector2(0, 1 * s), Vector2(4.5 * s, 6 * s), 14), mouth_in, k, 2.0 * s)
		"scared":
			var zz := PackedVector2Array()
			for i in range(7):
				zz.append(mc + Vector2(-8 * s + i * 2.66 * s, (1.5 if i % 2 == 0 else -1.5) * s))
			ci.draw_polyline(zz, k, 2.2 * s, true)
		"angry":
			Art.shape(ci, Art.rrect(Rect2(mc.x - 7 * s, mc.y - 2 * s, 14 * s, 7 * s), 3 * s), mouth_in, k, 2.0 * s)
			ci.draw_line(mc + Vector2(-5 * s, -0.5 * s), mc + Vector2(5 * s, -0.5 * s), Color(1, 1, 1, 0.85), 1.6 * s)
		"suspicious", "confused":
			ci.draw_line(mc + Vector2(-6 * s, 1 * s), mc + Vector2(6 * s, -1.5 * s), k, 2.4 * s, true)
		"sad":
			ci.draw_arc(mc + Vector2(0, 5 * s), 6 * s, PI + 0.5, TAU - 0.5, 10, k, 2.4 * s, true)
			ci.draw_colored_polygon(Art.ellipse(o + Vector2(-ex, 10 * s), Vector2(1.8 * s, 3 * s), 8), Color(0.55, 0.8, 1.0, 0.9))
		"relieved":
			ci.draw_arc(mc + Vector2(0, -3 * s), 6 * s, 0.4, PI - 0.4, 10, k, 2.4 * s, true)
		"sly":
			var g := PackedVector2Array()
			for i in range(11):
				var t := float(i) / 10.0
				g.append(mc + Vector2((t - 0.5) * 22 * s, -2 * s + sin(t * PI) * 6 * s))
			for i in range(10, -1, -1):
				var t2 := float(i) / 10.0
				g.append(mc + Vector2((t2 - 0.5) * 22 * s, -2 * s + sin(t2 * PI) * 1.5 * s))
			Art.shape(ci, g, Color("3a0d0d"), k, 1.8 * s)
			for i in range(5):
				var tx := mc.x + (-8 + i * 4) * s
				ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 1.6 * s, mc.y - 1 * s), Vector2(tx + 1.6 * s, mc.y - 1 * s), Vector2(tx, mc.y + 2.5 * s)]), Color(1, 1, 0.9))
		"cold":
			var zz2 := PackedVector2Array()
			for i in range(5):
				zz2.append(mc + Vector2(-5 * s + i * 2.5 * s, (1.0 if i % 2 == 0 else -1.0) * s))
			ci.draw_polyline(zz2, k, 2.0 * s, true)
		_:
			ci.draw_arc(mc + Vector2(0, -2 * s), 5 * s, 0.5, PI - 0.5, 8, k, 2.3 * s, true)

	# приметы поверх лица
	match look.beard:
		LookDef.Beard.STUBBLE:
			for i in range(16):
				var a := 0.35 + (PI - 0.7) * i / 15.0
				ci.draw_circle(o + Vector2(cos(a) * 25 * s, 8 * s + sin(a) * 18 * s), 0.9 * s, Color(pal.hair_d, 0.8))
		LookDef.Beard.MUSTACHE:
			for sx: float in [-1.0, 1.0]:
				Art.shape(ci, PackedVector2Array([mc + Vector2(0, -5 * s), mc + Vector2(sx * 10 * s, -4 * s), mc + Vector2(sx * 12 * s, -1 * s), mc + Vector2(sx * 4 * s, -2.5 * s)]), pal.hair, k, 1.5 * s)
		LookDef.Beard.FULL:
			var bpts := PackedVector2Array()
			for i in range(13):
				var a := 0.15 + (PI - 0.3) * i / 12.0
				bpts.append(o + Vector2(cos(a) * 30 * s, 6 * s + sin(a) * 30 * s))
			bpts.append(mc + Vector2(-8 * s, -3 * s))
			bpts.append(mc + Vector2(0, -6 * s))
			bpts.append(mc + Vector2(8 * s, -3 * s))
			Art.shape(ci, bpts, pal.hair, k, 2.0 * s)
			if face == "talk" or face == "shocked" or face == "happy":
				Art.shape(ci, Art.ellipse(mc + Vector2(0, 1 * s), Vector2(4.5 * s, 3.5 * s), 12), mouth_in, k, 1.6 * s)
	if look.scar:
		# шрам через щёку, в стороне от глаза
		var sa := o + Vector2(20 * s, 6 * s)
		var sb := o + Vector2(27 * s, 21 * s)
		ci.draw_line(sa, sb, Color("b0574a"), 2.0 * s, true)
		for t: float in [0.25, 0.5, 0.75]:
			var sp := sa.lerp(sb, t)
			ci.draw_line(sp + Vector2(-2.5 * s, 1 * s), sp + Vector2(2.5 * s, -1 * s), Color("b0574a"), 1.2 * s, true)
	if look.glasses:
		for sx: float in [-1.0, 1.0]:
			ci.draw_circle(o + Vector2(sx * ex, ey), 9.2 * s, Color(1, 1, 1, 0.16))
			ci.draw_arc(o + Vector2(sx * ex, ey), 9.2 * s, 0, TAU, 20, k, 2.0 * s, true)
		ci.draw_line(o + Vector2(-ex + 9 * s, ey - 1 * s), o + Vector2(ex - 9 * s, ey - 1 * s), k, 2.0 * s, true)
	if face == "confused":
		ci.draw_string(ThemeFactory.font_bold(), o + Vector2(24 * s, -22 * s), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * s), k)
	if face == "shocked" or face == "scared":
		var dp := o + Vector2(28 * s, -16 * s)
		ci.draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -8 * s), dp + Vector2(4.5 * s, 1 * s), dp + Vector2(-4.5 * s, 1 * s)]), Color("7cc6ff"))
		ci.draw_circle(dp + Vector2(0, 2 * s), 4.5 * s, Color("7cc6ff"))


## Глаз: белок, радужка цвета глаз, зрачок, блик. lid — насколько прикрыт веком сверху (0..1).
static func _eye(ci: CanvasItem, c: Vector2, s: float, pal: Dictionary, k: Color, dir: Vector2, lid: float, iris: Color = Color(0, 0, 0, 0), iris_scale: float = 1.0) -> void:
	var rx := 7.2 * s
	var ry := 8.6 * s
	Art.shape(ci, Art.ellipse(c, Vector2(rx, ry), 18), Color(1, 1, 1), k, 1.8 * s)
	var d := dir.limit_length(1.0) * Vector2(2.6 * s, 2.4 * s)
	var ic: Color = pal.eye if iris.a == 0.0 else iris
	ci.draw_circle(c + d, 4.6 * s * iris_scale, ic)
	ci.draw_circle(c + d, 2.4 * s * iris_scale, Color("140c0c"))
	ci.draw_circle(c + d + Vector2(-1.5 * s, -2 * s), 1.4 * s, Color(1, 1, 1))
	if lid > 0.0:
		var top := c.y - ry
		var cut := top + ry * 2.0 * lid
		var pts := PackedVector2Array()
		for i in range(13):
			var a := PI + PI * i / 12.0
			var pt := c + Vector2(cos(a) * (rx + 0.6 * s), sin(a) * (ry + 0.6 * s))
			pts.append(Vector2(pt.x, minf(pt.y, cut)))
		pts.append(Vector2(c.x + rx + 0.6 * s, cut))
		pts.append(Vector2(c.x - rx - 0.6 * s, cut))
		ci.draw_colored_polygon(pts, pal.skin_d)
		ci.draw_line(Vector2(c.x - rx, cut), Vector2(c.x + rx, cut), k, 1.8 * s, true)


# ---------------------------------------------------------------
# Причёски и шапки
# ---------------------------------------------------------------
static func _hair_back(ci: CanvasItem, o: Vector2, s: float, look: LookDef, pal: Dictionary, k: Color, lw: float) -> void:
	var r := HEAD_R * s
	match look.hair_style:
		LookDef.Hair.LONG:
			Art.shape(ci, Art.rrect(Rect2(o.x - r * 1.12, o.y - r * 0.4, r * 2.24, r * 1.75), r * 0.5), pal.hair_d, k, lw)
		LookDef.Hair.BOB:
			Art.shape(ci, Art.rrect(Rect2(o.x - r * 1.14, o.y - r * 0.5, r * 2.28, r * 1.25), r * 0.45), pal.hair_d, k, lw)
		LookDef.Hair.PONYTAIL:
			var tail := PackedVector2Array([o + Vector2(r * 0.6, -r * 0.7), o + Vector2(r * 1.45, -r * 0.2), o + Vector2(r * 1.5, r * 0.75),
				o + Vector2(r * 1.15, r * 0.55), o + Vector2(r * 0.95, -r * 0.1)])
			Art.shape(ci, tail, pal.hair, k, lw)
		LookDef.Hair.BUN:
			Art.shape(ci, Art.ellipse(o + Vector2(0, -r * 1.12), Vector2(r * 0.42, r * 0.36), 16), pal.hair, k, lw)


static func _hair_front(ci: CanvasItem, o: Vector2, s: float, look: LookDef, pal: Dictionary, k: Color, lw: float) -> void:
	if look.head == LookDef.Head.HAT or look.head == LookDef.Head.HOOD or look.head == LookDef.Head.SCARF:
		# под шляпой и платком видна только чёлка
		var fr := PackedVector2Array()
		var r0 := HEAD_R * s
		for i in range(9):
			var a := PI * 1.15 + PI * 0.7 * i / 8.0
			fr.append(o + Vector2(cos(a) * r0, sin(a) * r0 * 0.8 - 2 * s))
		fr.append(o + Vector2(r0 * 0.5, -r0 * 0.45))
		fr.append(o + Vector2(-r0 * 0.5, -r0 * 0.45))
		if look.hair_style != LookDef.Hair.BALD:
			Art.shape(ci, fr, pal.hair, k, lw * 0.8)
		return
	var r := HEAD_R * s
	var cap := PackedVector2Array()
	match look.hair_style:
		LookDef.Hair.BALD:
			ci.draw_arc(o + Vector2(-8 * s, -18 * s), 7 * s, PI * 1.1, PI * 1.6, 6, Color(1, 1, 1, 0.45), 2.4 * s, true)
			for sx: float in [-1.0, 1.0]:
				Art.shape(ci, Art.ellipse(o + Vector2(sx * r * 0.92, -2 * s), Vector2(5 * s, 11 * s), 10), pal.hair, k, lw * 0.7)
			return
		LookDef.Hair.SPIKY:
			for i in range(9):
				var t := float(i) / 8.0
				var a := PI + PI * t
				var rr := r * (1.32 if i % 2 == 1 else 1.0)
				cap.append(o + Vector2(cos(a) * rr, sin(a) * rr - 2 * s))
			cap.append(o + Vector2(r * 0.6, -r * 0.35))
			cap.append(o + Vector2(-r * 0.6, -r * 0.35))
		LookDef.Hair.CURLY:
			for i in range(11):
				var a := PI * 0.95 + PI * 1.1 * i / 10.0
				var c := o + Vector2(cos(a) * r * 0.95, sin(a) * r * 0.92)
				Art.shape(ci, Art.ellipse(c, Vector2(r * 0.3, r * 0.28), 12), pal.hair, k, lw * 0.7)
			return
		LookDef.Hair.BANGS, LookDef.Hair.BOB:
			for i in range(13):
				var a := PI + PI * i / 12.0
				cap.append(o + Vector2(cos(a) * r * 1.06, sin(a) * r * 1.02))
			cap.append(o + Vector2(r * 1.04, -r * 0.05))
			for i in range(6, -1, -1):
				cap.append(o + Vector2((i - 3) * r * 0.32, -r * 0.3 + (2.5 * s if i % 2 == 0 else -2.0 * s)))
			cap.append(o + Vector2(-r * 1.04, -r * 0.05))
		_:
			# короткая, длинная, хвост, пучок: шапочка волос с пробором
			for i in range(13):
				var a := PI + PI * i / 12.0
				cap.append(o + Vector2(cos(a) * r * 1.05, sin(a) * r * 1.02 - 1 * s))
			cap.append(o + Vector2(r * 0.95, -r * 0.25))
			cap.append(o + Vector2(r * 0.2, -r * 0.55))
			cap.append(o + Vector2(-r * 0.15, -r * 0.42))
			cap.append(o + Vector2(-r * 0.95, -r * 0.2))
	Art.shape(ci, cap, pal.hair, k, lw)
	ci.draw_arc(o + Vector2(-r * 0.3, -r * 0.62), r * 0.3, PI * 1.15, PI * 1.6, 6, Color(1, 1, 1, 0.25), 2.2 * s, true)


static func _hat(ci: CanvasItem, o: Vector2, s: float, look: LookDef, pal: Dictionary, k: Color, lw: float) -> void:
	var r := HEAD_R * s
	var hat: Color = pal.hat
	match look.head:
		LookDef.Head.HOOD:
			var pts := PackedVector2Array()
			for i in range(19):
				var a := PI + PI * i / 18.0
				pts.append(o + Vector2(cos(a) * r * 1.08, sin(a) * r * 1.08 - 6 * s))
			Art.shape(ci, pts, hat, k, lw)
			Art.shape(ci, Art.rrect(Rect2(o.x - r * 1.1, o.y - 14 * s, r * 2.2, 11 * s), 5 * s), hat.darkened(0.2), k, lw * 0.9)
			ci.draw_circle(o + Vector2(0, -r * 1.25), 8 * s, k)
			ci.draw_circle(o + Vector2(0, -r * 1.25), 6.4 * s, hat.lightened(0.25))
		LookDef.Head.HAT:
			Art.shape(ci, Art.rrect(Rect2(o.x - r * 1.35, o.y - r * 0.7, r * 2.7, 9 * s), 4 * s), hat, k, lw)
			Art.shape(ci, Art.rrect(Rect2(o.x - r * 0.78, o.y - r * 1.55, r * 1.56, r * 0.9), 7 * s), hat, k, lw)
			ci.draw_rect(Rect2(o.x - r * 0.76, o.y - r * 0.86, r * 1.52, 5 * s), pal.accent)
		LookDef.Head.SCARF:
			var p2 := PackedVector2Array([o + Vector2(-r * 1.12, r * 0.25), o + Vector2(-r * 0.9, -r * 0.75), o + Vector2(0, -r * 1.12),
				o + Vector2(r * 0.9, -r * 0.75), o + Vector2(r * 1.12, r * 0.25), o + Vector2(r * 0.7, -r * 0.28), o + Vector2(-r * 0.7, -r * 0.28)])
			Art.shape(ci, p2, hat, k, lw)
			for dx: float in [-14.0, 0.0, 14.0]:
				ci.draw_circle(o + Vector2(dx * s, -r * 0.62), 2.4 * s, Color(1, 1, 1, 0.7))
		LookDef.Head.CAP:
			var p3 := PackedVector2Array()
			for i in range(15):
				var a := PI + PI * i / 14.0
				p3.append(o + Vector2(cos(a) * r * 1.02, sin(a) * r * 0.85 - 9 * s))
			Art.shape(ci, p3, hat, k, lw)
			Art.shape(ci, Art.rrect(Rect2(o.x - 4 * s, o.y - 14 * s, r * 1.45, 7 * s), 3 * s), hat.darkened(0.25), k, lw * 0.9)


# ---------------------------------------------------------------
# Части тела и инструменты
# ---------------------------------------------------------------
static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color, k: Color, lw: float) -> void:
	ci.draw_line(a, b, k, w + lw * 2.0, true)
	ci.draw_circle(a, (w + lw * 2.0) * 0.5, k)
	ci.draw_circle(b, (w + lw * 2.0) * 0.5, k)
	ci.draw_line(a, b, col, w, true)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)


## Углы рук для работы: (левая, правая) от опущенного положения.
static func _tool_pose(tool: String, w: float) -> Vector2:
	var t := sin(w * TAU)
	match tool:
		"axe": return Vector2(2.4 + t * 0.9, 2.4 + t * 0.9)
		"bucket": return Vector2(0.3, 0.2 + maxf(0.0, t) * 1.6)
		"oar": return Vector2(1.3 + t * 0.6, 1.0 - t * 0.6)
		"can": return Vector2(0.4, 1.6 + t * 0.3)
		"chalk": return Vector2(0.3, 1.9 + t * 0.4)
	return Vector2(0.12, 0.12)


static func _draw_tool(ci: CanvasItem, tool: String, lh: Vector2, rh: Vector2, w: float, s: float, k: Color) -> void:
	match tool:
		"axe":
			var grip := (lh + rh) * 0.5
			var up := Vector2(0, -1).rotated(sin(w * TAU) * 0.9)
			var tip := grip + up * 26 * s
			ci.draw_line(grip, tip, k, 5 * s, true)
			ci.draw_line(grip, tip, Color("8a5a3a"), 3 * s, true)
			Art.shape(ci, PackedVector2Array([tip + Vector2(-2 * s, -3 * s), tip + Vector2(10 * s, -6 * s), tip + Vector2(10 * s, 5 * s), tip + Vector2(-2 * s, 3 * s)]), Color("c8c8d0"), k, 1.6 * s)
		"bucket":
			var b := rh + Vector2(0, 4 * s)
			Art.shape(ci, PackedVector2Array([b + Vector2(-7 * s, 0), b + Vector2(7 * s, 0), b + Vector2(5.5 * s, 12 * s), b + Vector2(-5.5 * s, 12 * s)]), Color("7aa7d6"), k, 1.8 * s)
			ci.draw_arc(rh + Vector2(0, 4 * s), 7 * s, PI, TAU, 8, k, 1.6 * s, true)
		"oar":
			var a := lh + (lh - rh).normalized() * 6 * s
			var b2 := rh + (rh - lh).normalized() * 24 * s
			ci.draw_line(a, b2, k, 5 * s, true)
			ci.draw_line(a, b2, Color("c8925e"), 3 * s, true)
			Art.shape(ci, Art.ellipse(b2, Vector2(5 * s, 9 * s), 10), Color("c8925e"), k, 1.6 * s)
		"can":
			Art.shape(ci, Art.rrect(Rect2(rh.x - 6 * s, rh.y - 2 * s, 12 * s, 14 * s), 3 * s), Color("b84a3a"), k, 1.6 * s)
		"chalk":
			ci.draw_line(rh, rh + Vector2(6 * s, -6 * s), Color(1, 1, 1), 3 * s, true)
