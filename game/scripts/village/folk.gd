class_name Folk
extends RefCounted
## Жители нового образца: крупная голова (больше половины роста), лицо с белками глаз,
## бровями, носом и ртом, свои приметы у каждого. Девушку видно по силуэту: платье,
## косы или длинные волосы, ресницы, губы, заколка. Эмоция меняет всё лицо — рот во всю
## ширину, брови, цвет кожи — и даёт значок над головой и позу тела: её видно с поля.
## Тело собрано из частей и рисуется по позе: так получаются шаг, жесты и работа у дела.
##
## Координаты: начало — между ступнями, вверх — минус. Рост при s = 1 около 130 единиц,
## голова — круг радиусом 34 с центром на высоте 92.

const HEAD_Y := -92.0
const HEAD_R := 34.0
const HIP_Y := -24.0
const SHOULDER_Y := -54.0
const TOP := -134.0          ## макушка (без шляп и значков) при s = 1

## Все лица, которые умеют рисоваться. Самотест проверяет, что каждое рисует своё.
const FACES: PackedStringArray = ["neutral", "blink", "talk", "happy", "shocked", "scared", "angry",
	"suspicious", "sad", "relieved", "sly", "confused", "cold"]

const MOUTH := Color("5c2028")
const TONGUE := Color("e07a7a")
const TEETH := Color(1.0, 0.98, 0.94)
const TEAR := Color(0.55, 0.82, 1.0, 0.95)


## Палитра по внешности. n — ночь 0..1: краски уходят в синеву.
static func palette(look: LookDef, n: float = 0.0) -> Dictionary:
	var coat := _bright(look.coat)
	var hair := look.hair
	if look.age >= 2:
		hair = hair.lerp(Color("cfcac2"), 0.75)
	return {
		"coat": Art.dn(coat, n), "coat_d": Art.dn(coat.darkened(0.22), n), "coat_l": Art.dn(coat.lightened(0.18), n),
		"skin": Art.dn(look.skin.lightened(0.06), n), "skin_d": Art.dn(look.skin.darkened(0.12), n),
		"hair": Art.dn(hair, n), "hair_d": Art.dn(hair.darkened(0.28), n), "hair_l": Art.dn(hair.lightened(0.25), n),
		"accent": Art.dn(_bright(look.accent), n), "eye": Art.dn(look.eye, n),
		"pants": Art.dn(Color("3b3346"), n), "shoe": Art.dn(Color("2e2420"), n),
		"tights": Art.dn(Color("4a3a4e") if look.female else Color("3b3346"), n),
		"lips": Art.dn(Color("c8505a"), n),
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


## Поза тела по эмоции: страх — руки к лицу, злость — сжатые кулаки и наклон вперёд,
## радость — руки вверх, горе — голова вниз, холод — обнять себя.
static func emotion_pose(face: String) -> Dictionary:
	match face:
		"scared": return {"arm_l": -2.6, "arm_r": -2.6, "crouch": 0.35, "tilt": 0.0}
		"shocked": return {"arm_l": 1.4, "arm_r": 1.4}
		"angry": return {"arm_l": 0.55, "arm_r": 0.55, "lean": 0.12, "fists": true}
		"happy": return {"arm_l": 2.5, "arm_r": 2.5, "hop": 1.0}
		"sad": return {"arm_l": 0.05, "arm_r": 0.05, "tilt": 0.0, "droop": 1.0}
		"cold": return {"shiver": true}
		"confused": return {"arm_r": 2.2, "tilt": 0.18}
		"suspicious": return {"arm_l": 0.7, "arm_r": 0.7, "tilt": -0.12}
		"relieved": return {"arm_l": 0.3, "arm_r": 0.3, "droop": 0.3}
	return {}


## Нарисовать жителя целиком. pose: walk (фаза шага 0..1), amp (размах шага 0..1),
## arm_l / arm_r (угол руки от опущенной, рад), look (Vector2, куда смотрят глаза),
## turn (−1..1, поворот головы вбок), tilt (наклон головы, рад), lantern, point (указать рукой),
## dir (±1, куда указывает), shiver, crouch, lean, hop, droop, fists,
## tool ("bucket", "axe", "oar", "can", "chalk") и work (фаза работы 0..1), breath (0..1).
## emote — рисовать ли значок эмоции над головой (по умолчанию да).
static func figure(ci: CanvasItem, o: Vector2, s: float, look: LookDef, face: String, pose: Dictionary = {}, pal: Dictionary = {}) -> void:
	if pal.is_empty():
		pal = palette(look)
	var ep := emotion_pose(face)
	for key: String in ep:
		if not pose.has(key):
			pose[key] = ep[key]
	var k: Color = pal.ink
	var lw := 2.8 * s
	var h: float = look.height
	var ph: float = pose.get("walk", 0.0)
	var amp: float = pose.get("amp", 0.0)
	var sw := sin(ph * TAU) * amp
	var crouch: float = pose.get("crouch", 0.0)
	var hop: float = pose.get("hop", 0.0)
	var lean: float = pose.get("lean", 0.0)
	var breath: float = pose.get("breath", 0.0)
	var bob := -absf(sin(ph * TAU)) * 3.5 * amp * s - hop * 5.0 * s + crouch * 8.0 * s
	var shiver: bool = pose.get("shiver", false)
	var p := o + Vector2(0, bob)

	ci.draw_colored_polygon(Art.ellipse(o + Vector2(0, 1.5 * s), Vector2(24 * s * (1.0 - hop * 0.2), 5 * s), 18), Color(0, 0, 0, 0.22))

	# ноги: у девушки в платье — тонкие в колготках, у остальных — штаны
	var fem := look.female
	var leg_w := 8.0 * s if fem else 10.5 * s
	var leg_col: Color = pal.tights if fem else pal.pants
	for side: float in [-1.0, 1.0]:
		var swing := sw * side
		var hip := p + Vector2(side * 7.0 * s, HIP_Y * s * h)
		var foot := o + Vector2(side * (7.5 + crouch * 3.0) * s + swing * 9.0 * s, -maxf(0.0, swing) * 6.0 * s - hop * 4.0 * s)
		_limb(ci, hip, foot, leg_w, leg_col, k, lw * 0.9)
		Art.shape(ci, Art.ellipse(foot + Vector2(side * 1.5 * s, -1.5 * s), Vector2(7.5 * s, 4.2 * s), 12), pal.shoe, k, lw * 0.8)

	var arm_l: float = pose.get("arm_l", 0.12 + sw * 0.55)
	var arm_r: float = pose.get("arm_r", 0.12 - sw * 0.55)
	if shiver:
		arm_l = -2.3
		arm_r = -2.3
	var tool: String = pose.get("tool", "")
	var work: float = pose.get("work", 0.0)
	if tool != "":
		var t := _tool_pose(tool, work)
		arm_l = t.x
		arm_r = t.y

	# туловище: у мужчин плечи шире, у девушек — платье-трапеция до колен
	var sh_y := SHOULDER_Y * s * h + breath * 1.2 * s
	var top := p.y + sh_y - 6.0 * s
	var bottom := p.y + HIP_Y * s * h + 4.0 * s
	var lx := lean * 30.0 * s
	var sh_w := 13.0 * s if fem else 16.5 * s
	var body: PackedVector2Array
	if fem and look.outfit == LookDef.Outfit.DRESS:
		var hem := p.y + HIP_Y * s * h + 14.0 * s
		body = PackedVector2Array([
			Vector2(p.x - sh_w + lx, top), Vector2(p.x + sh_w + lx, top),
			Vector2(p.x + 12 * s + lx * 0.5, top + 20 * s),
			Vector2(p.x + 25 * s, hem - 3 * s), Vector2(p.x + 22 * s, hem), Vector2(p.x - 22 * s, hem), Vector2(p.x - 25 * s, hem - 3 * s),
			Vector2(p.x - 12 * s + lx * 0.5, top + 20 * s)])
	else:
		var flare := 19.0 * s if fem else 21.0 * s
		body = PackedVector2Array([
			Vector2(p.x - sh_w + lx, top), Vector2(p.x + sh_w + lx, top),
			Vector2(p.x + flare, bottom - 4 * s), Vector2(p.x + flare - 3 * s, bottom), Vector2(p.x - flare + 3 * s, bottom), Vector2(p.x - flare, bottom - 4 * s)])
	Art.shape(ci, body, pal.coat, k, lw)
	# тень на правом боку и детали одежды
	var b0: Vector2 = body[1]
	var b2: Vector2 = body[body.size() / 2 - 1]
	ci.draw_colored_polygon(PackedVector2Array([b0 + Vector2(-8 * s, 2 * s), b0 + Vector2(-1 * s, 2 * s), b2 + Vector2(-2 * s, -2 * s), b2 + Vector2(-11 * s, -1 * s)]), Color(pal.coat_d, 0.55))
	match look.outfit:
		LookDef.Outfit.DRESS:
			ci.draw_line(Vector2(p.x - 12 * s + lx * 0.5, top + 20 * s), Vector2(p.x + 12 * s + lx * 0.5, top + 20 * s), pal.accent, 3.2 * s, true)
			for i in range(3):
				ci.draw_circle(Vector2(p.x - 12 * s + i * 12 * s, p.y + HIP_Y * s * h + 10 * s), 2.2 * s, Color(pal.coat_l, 0.9))
		LookDef.Outfit.SWEATER:
			for yy: float in [0.35, 0.6]:
				var y := lerpf(top, bottom, yy)
				var zz := PackedVector2Array()
				for i in range(7):
					zz.append(Vector2(p.x - 14 * s + i * 4.6 * s, y + (2.0 if i % 2 == 0 else -2.0) * s))
				ci.draw_polyline(zz, pal.coat_l, 2.0 * s, true)
		LookDef.Outfit.JACKET:
			ci.draw_line(Vector2(p.x + lx, top + 4 * s), Vector2(p.x, bottom - 2 * s), Color(k, 0.6), 1.8 * s, true)
			for side2: float in [-1.0, 1.0]:
				ci.draw_rect(Rect2(p.x + side2 * 11 * s - 4 * s, lerpf(top, bottom, 0.6), 8 * s, 2.5 * s), Color(k, 0.5))
		_:
			for by: float in [0.38, 0.7]:
				ci.draw_circle(Vector2(p.x - 1.5 * s, lerpf(top, bottom, by)), 2.0 * s, Color(k, 0.75))

	var lsh := Vector2(p.x - sh_w + lx, p.y + sh_y)
	var rsh := Vector2(p.x + sh_w + lx, p.y + sh_y)
	var arm_len := 23.0 * s
	var lhand := lsh + Vector2(-sin(arm_l), cos(arm_l)) * arm_len
	var rhand := rsh + Vector2(sin(arm_r), cos(arm_r)) * arm_len
	if pose.get("point", false):
		var dir: float = pose.get("dir", 1.0)
		if dir > 0.0:
			rhand = rsh + Vector2(0.95, -0.35).normalized() * arm_len * 1.15
		else:
			lhand = lsh + Vector2(-0.95, -0.35).normalized() * arm_len * 1.15
	var sleeve := 7.0 * s if fem else 8.5 * s
	_limb(ci, lsh, lhand, sleeve, pal.coat, k, lw * 0.85)
	_limb(ci, rsh, rhand, sleeve, pal.coat, k, lw * 0.85)
	var fists: bool = pose.get("fists", false)
	for hand: Vector2 in [lhand, rhand]:
		ci.draw_circle(hand, (5.8 if fists else 5.2) * s, k)
		ci.draw_circle(hand, (4.6 if fists else 4.0) * s, pal.skin)
	if tool != "":
		_draw_tool(ci, tool, lhand, rhand, work, s, k)
	if pose.get("lantern", false) and tool == "":
		var hand := rhand
		ci.draw_line(hand, hand + Vector2(0, 5 * s), k, 2.2 * s, true)
		var lr := Rect2(hand.x - 7 * s, hand.y + 5 * s, 14 * s, 18 * s)
		Art.shape(ci, Art.rrect(lr, 4 * s), Color("ffcf6b"), k, lw * 0.8)
		ci.draw_line(Vector2(lr.position.x, lr.position.y + 5 * s), Vector2(lr.end.x, lr.position.y + 5 * s), k, 1.6 * s)
		ci.draw_circle(lr.get_center() + Vector2(0, 2 * s), 3.2 * s, Color(1, 0.95, 0.7))

	# шарф или воротник
	if look.outfit == LookDef.Outfit.DRESS:
		Art.shape(ci, Art.ellipse(Vector2(p.x + lx, top + 1 * s), Vector2(11 * s, 5 * s), 14), pal.coat_l, k, lw * 0.7)
	else:
		Art.shape(ci, Art.rrect(Rect2(p.x - 17 * s + lx, top - 6 * s, 34 * s, 11 * s), 5 * s), pal.accent, k, lw * 0.85)
		ci.draw_line(Vector2(p.x + 8 * s + lx, top + 3 * s), Vector2(p.x + 11 * s + lx, top + 16 * s), k, 7.5 * s, true)
		ci.draw_line(Vector2(p.x + 8 * s + lx, top + 3 * s), Vector2(p.x + 11 * s + lx, top + 16 * s), pal.accent, 4.8 * s, true)

	var droop: float = pose.get("droop", 0.0)
	var hc := Vector2(p.x + lx * 1.4, p.y + HEAD_Y * s * h + droop * 6.0 * s + breath * 1.5 * s)
	head(ci, hc, s, look, face, pose, pal)


## Голова с лицом, причёской и значком эмоции. Отдельно — для портретов на экранах.
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
	# у мужчин лицо чуть квадратнее, у девушек — круглее и уже к подбородку
	var head_pts := _head_shape(o, r, look)
	ci.draw_colored_polygon(head_pts, pal.skin_d)
	var inner := PackedVector2Array()
	for pt: Vector2 in head_pts:
		inner.append(pt * 0.94 + Vector2(-2.5 * s, -2 * s))
	ci.draw_colored_polygon(inner, pal.skin)
	# цвет лица по эмоции: злость краснеет, страх и холод бледнеют
	match face:
		"angry":
			var flush := PackedVector2Array()
			for pt2: Vector2 in inner:
				if pt2.y < -r * 0.1:
					flush.append(pt2)
			flush.append(Vector2(r * 0.9, -r * 0.1))
			flush.append(Vector2(-r * 0.9, -r * 0.1))
			if flush.size() >= 3:
				ci.draw_colored_polygon(flush, Color(0.9, 0.15, 0.1, 0.32))
		"scared", "cold":
			ci.draw_colored_polygon(inner, Color(0.6, 0.75, 1.0, 0.26))
		"sly":
			ci.draw_colored_polygon(inner, Color(0.55, 0.7, 0.3, 0.16))
	var outl := head_pts.duplicate()
	outl.append(head_pts[0])
	ci.draw_polyline(outl, k, lw, true)
	for side: float in [-1.0, 1.0]:
		var ear := o + Vector2(side * (r * 1.0 - turn * side * 3 * s), 4 * s)
		Art.shape(ci, Art.ellipse(ear, Vector2(4.5 * s, 7 * s), 10), pal.skin, k, lw * 0.75)
		if look.earrings:
			ci.draw_circle(ear + Vector2(0, 8 * s), 2.6 * s, k)
			ci.draw_circle(ear + Vector2(0, 8 * s), 1.8 * s, Color("f2c94c"))
	var fo := o + Vector2(turn * 7.0 * s, 0)
	_face(ci, fo, s, look, face, pose, pal, k)
	_hair_front(ci, o, s, look, pal, k, lw)
	_hat(ci, o, s, look, pal, k, lw)
	_bow(ci, o, s, look, pal, k, lw)
	if pose.get("emote", true):
		_emote(ci, o + Vector2(r * 0.95, -r * 1.25), s, face, k)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _head_shape(o: Vector2, r: float, look: LookDef) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(36):
		var a := TAU * i / 36.0
		var x := cos(a)
		var y := sin(a)
		var rx := r * 1.03
		var ry := r
		if y > 0.0:
			if look.female:
				rx *= 1.0 - 0.1 * y * y        # подбородок уже
			else:
				rx *= 1.0 + 0.04 * y           # челюсть шире
				ry *= 1.0 - 0.04 * y
		pts.append(o + Vector2(x * rx, y * ry))
	return pts


# ---------------------------------------------------------------
# Лицо
# ---------------------------------------------------------------
static func _face(ci: CanvasItem, o: Vector2, s: float, look: LookDef, face: String, pose: Dictionary, pal: Dictionary, k: Color) -> void:
	var ex := 12.5 * s
	var ey := 1.0 * s
	var look_dir: Vector2 = pose.get("look", Vector2.ZERO)
	var fem := look.female
	# румянец: у девушек ярче, от радости и смущения — сильнее
	var blush_a := 0.42 if fem else 0.26
	if face == "happy" or face == "relieved":
		blush_a += 0.18
	if face != "sly" and face != "cold" and face != "scared":
		for sx: float in [-1.0, 1.0]:
			ci.draw_colored_polygon(Art.ellipse(o + Vector2(sx * 21 * s, 14 * s), Vector2(7 * s, 4.5 * s), 14), Color(1.0, 0.42, 0.45, blush_a))
	if look.freckles:
		for sx: float in [-1.0, 1.0]:
			for f: Vector2 in [Vector2(17, 9), Vector2(22, 11), Vector2(19, 14), Vector2(24, 15)]:
				ci.draw_circle(o + Vector2(sx * f.x * s, f.y * s), 1.2 * s, Color(pal.skin_d.darkened(0.3), 0.9))
	if look.age >= 2:
		for sx: float in [-1.0, 1.0]:
			ci.draw_line(o + Vector2(sx * 22 * s, ey - 1 * s), o + Vector2(sx * 25 * s, ey - 3 * s), Color(k, 0.45), 1.3 * s, true)
			ci.draw_line(o + Vector2(sx * 22 * s, ey + 2 * s), o + Vector2(sx * 25 * s, ey + 3 * s), Color(k, 0.45), 1.3 * s, true)
		ci.draw_line(o + Vector2(-8 * s, -18 * s), o + Vector2(8 * s, -18 * s), Color(k, 0.3), 1.3 * s, true)

	# глаза: эмоция меняет форму, размер зрачка и веки
	match face:
		"blink", "relieved":
			for sx: float in [-1.0, 1.0]:
				ci.draw_arc(o + Vector2(sx * ex, ey + 1 * s), 6 * s, 0.2, PI - 0.2, 10, k, 3.0 * s, true)
				if fem:
					_lashes_closed(ci, o + Vector2(sx * ex, ey + 1 * s), s, sx, k)
		"happy":
			for sx: float in [-1.0, 1.0]:
				ci.draw_arc(o + Vector2(sx * ex, ey + 4 * s), 6.5 * s, PI * 1.08, PI * 1.92, 12, k, 3.4 * s, true)
				if fem:
					ci.draw_line(o + Vector2(sx * (ex + 6 * s), ey + 1 * s), o + Vector2(sx * (ex + 9.5 * s), ey - 1.5 * s), k, 2.0 * s, true)
		"sly":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey), s, pal, k, look_dir + Vector2(sx * 0.35, 0), 0.5, Color(0.98, 0.82, 0.25), 1.0, true)
		"shocked":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey - 1 * s), s * 1.25, pal, k, look_dir, 0.0, pal.eye, 0.42)
		"scared":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey - 1 * s), s * 1.18, pal, k, look_dir, 0.0, pal.eye, 0.5)
		"angry":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey + 1 * s), s, pal, k, look_dir, 0.42, pal.eye, 0.85, false, sx)
		"suspicious":
			_eye(ci, o + Vector2(-ex, ey), s, pal, k, look_dir + Vector2(0.9, 0), 0.25)
			_eye(ci, o + Vector2(ex, ey + 1 * s), s, pal, k, look_dir + Vector2(0.9, 0), 0.62)
		"sad":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey + 1 * s), s, pal, k, look_dir + Vector2(0, 0.7), 0.35, pal.eye, 1.05, false, -sx)
		"cold":
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey), s, pal, k, look_dir, 0.38)
		"confused":
			_eye(ci, o + Vector2(-ex, ey), s, pal, k, look_dir + Vector2(-0.4, -0.6), 0.0, pal.eye, 0.9)
			_eye(ci, o + Vector2(ex, ey + 1 * s), s * 0.85, pal, k, look_dir + Vector2(-0.4, -0.6), 0.2, pal.eye, 0.9)
		_:
			for sx: float in [-1.0, 1.0]:
				_eye(ci, o + Vector2(sx * ex, ey), s, pal, k, look_dir, 0.0)
	if fem and face != "blink" and face != "relieved" and face != "happy":
		for sx: float in [-1.0, 1.0]:
			_lashes(ci, o + Vector2(sx * ex, ey), s, sx, k)

	# брови
	var bw := 2.4 * s if look.brows == LookDef.Brows.THIN else 4.4 * s
	if fem:
		bw = minf(bw, 2.8 * s)
	var base_tilt := 0.25 if look.brows == LookDef.Brows.STERN else 0.0
	var by := -11.0 * s
	for sx: float in [-1.0, 1.0]:
		var inner := o + Vector2(sx * 5.5 * s, by)
		var outer := o + Vector2(sx * 19.5 * s, by - 2 * s)
		var lift := base_tilt
		var up := 0.0
		match face:
			"angry": lift = 1.0
			"suspicious": lift = 0.6 if sx > 0 else -0.2
			"sad", "cold": lift = -0.85
			"scared": lift = -0.9
			"shocked": up = 5.0
			"confused": lift = 0.7 if sx > 0 else -0.6
			"sly": lift = 0.75
			"happy", "relieved": up = 1.5
		if face == "scared":
			up = 4.0
		inner.y += lift * 8 * s - up * s
		outer.y -= lift * 2.5 * s + up * s
		var brow_col: Color = pal.hair_d if look.age < 2 else pal.hair
		var mid := (inner + outer) * 0.5 + Vector2(0, -2.5 * s)
		ci.draw_polyline(PackedVector2Array([inner, mid, outer]), brow_col, bw, true)

	# нос: у девушек всегда маленький
	var nc := o + Vector2(0, 9 * s)
	var nose := LookDef.Nose.BUTTON if fem and look.nose == LookDef.Nose.LONG else look.nose
	match nose:
		LookDef.Nose.LONG:
			ci.draw_polyline(PackedVector2Array([nc + Vector2(0, -6 * s), nc + Vector2(2.8 * s, 3 * s), nc + Vector2(-1.5 * s, 4.8 * s)]), Color(k, 0.75), 2.0 * s, true)
		LookDef.Nose.ROUND:
			Art.shape(ci, Art.ellipse(nc + Vector2(0, 1 * s), Vector2(5 * s, 4.2 * s), 12), pal.skin_d, Color(k, 0.5), 1.4 * s)
		_:
			ci.draw_colored_polygon(Art.ellipse(nc, Vector2(2.6 * s, 2.0 * s), 10), pal.skin_d)
			ci.draw_arc(nc, 2.6 * s, 0.2, PI - 0.2, 6, Color(k, 0.5), 1.3 * s, true)

	_mouth(ci, o + Vector2(0, 20 * s), s, face, fem, pal, k)

	# слёзы, пот, дыхание на холоде — крупно, чтобы читалось с поля
	match face:
		"sad":
			for sx: float in [-1.0, 1.0]:
				var tp := o + Vector2(sx * (ex + 1 * s), ey + 8 * s)
				ci.draw_colored_polygon(PackedVector2Array([tp + Vector2(-2 * s, 0), tp + Vector2(2 * s, 0), tp + Vector2(1.5 * s, 12 * s), tp + Vector2(-1.5 * s, 12 * s)]), TEAR)
				ci.draw_circle(tp + Vector2(0, 13 * s), 2.6 * s, TEAR)
		"scared", "shocked":
			for d: Vector2 in [Vector2(-29, -14), Vector2(30, -6)]:
				_drop(ci, o + d * s, s * 1.1)
		"cold":
			var mc := o + Vector2(0, 20 * s)
			for i in range(3):
				ci.draw_circle(mc + Vector2(10 * s + i * 6 * s, 2 * s - i * 3 * s), (2.5 + i) * s, Color(1, 1, 1, 0.55 - i * 0.12))

	# приметы поверх лица
	var mc2 := o + Vector2(0, 20 * s)
	match look.beard:
		LookDef.Beard.STUBBLE:
			for i in range(18):
				var a := 0.3 + (PI - 0.6) * i / 17.0
				ci.draw_circle(o + Vector2(cos(a) * 25 * s, 8 * s + sin(a) * 19 * s), 1.0 * s, Color(pal.hair_d, 0.85))
		LookDef.Beard.MUSTACHE:
			for sx: float in [-1.0, 1.0]:
				Art.shape(ci, PackedVector2Array([mc2 + Vector2(0, -6 * s), mc2 + Vector2(sx * 11 * s, -5 * s), mc2 + Vector2(sx * 13 * s, -1.5 * s), mc2 + Vector2(sx * 4 * s, -3 * s)]), pal.hair, k, 1.5 * s)
		LookDef.Beard.FULL:
			var bpts := PackedVector2Array()
			for i in range(13):
				var a := 0.15 + (PI - 0.3) * i / 12.0
				bpts.append(o + Vector2(cos(a) * 30 * s, 6 * s + sin(a) * 31 * s))
			bpts.append(mc2 + Vector2(-9 * s, -4 * s))
			bpts.append(mc2 + Vector2(0, -7 * s))
			bpts.append(mc2 + Vector2(9 * s, -4 * s))
			Art.shape(ci, bpts, pal.hair, k, 2.0 * s)
			_mouth(ci, mc2, s * 0.8, face, false, pal, k)
	if look.scar:
		var sa := o + Vector2(20 * s, 6 * s)
		var sb := o + Vector2(27 * s, 21 * s)
		ci.draw_line(sa, sb, Color("b0574a"), 2.0 * s, true)
		for t: float in [0.25, 0.5, 0.75]:
			var sp := sa.lerp(sb, t)
			ci.draw_line(sp + Vector2(-2.5 * s, 1 * s), sp + Vector2(2.5 * s, -1 * s), Color("b0574a"), 1.2 * s, true)
	if look.glasses:
		for sx: float in [-1.0, 1.0]:
			ci.draw_circle(o + Vector2(sx * ex, ey), 9.4 * s, Color(1, 1, 1, 0.14))
			ci.draw_arc(o + Vector2(sx * ex, ey), 9.4 * s, 0, TAU, 20, k, 2.0 * s, true)
		ci.draw_line(o + Vector2(-ex + 9 * s, ey - 1 * s), o + Vector2(ex - 9 * s, ey - 1 * s), k, 2.0 * s, true)


## Рот: во всю ширину лица, чтобы эмоция читалась издалека.
static func _mouth(ci: CanvasItem, mc: Vector2, s: float, face: String, fem: bool, pal: Dictionary, k: Color) -> void:
	match face:
		"talk":
			Art.shape(ci, Art.ellipse(mc, Vector2(6.5 * s, 5.5 * s), 16), MOUTH, k, 2.0 * s)
			ci.draw_colored_polygon(Art.ellipse(mc + Vector2(0, 2.6 * s), Vector2(3.8 * s, 2 * s), 10), TONGUE)
		"happy":
			var pts := PackedVector2Array()
			for i in range(11):
				var a := PI * i / 10.0
				pts.append(mc + Vector2(cos(a) * 11 * s, sin(a) * 9 * s - 3 * s))
			Art.shape(ci, pts, MOUTH, k, 2.2 * s)
			ci.draw_colored_polygon(PackedVector2Array([mc + Vector2(-9 * s, -3 * s), mc + Vector2(9 * s, -3 * s), mc + Vector2(7 * s, 0), mc + Vector2(-7 * s, 0)]), TEETH)
			ci.draw_colored_polygon(Art.ellipse(mc + Vector2(0, 4 * s), Vector2(5 * s, 2.5 * s), 10), TONGUE)
		"shocked":
			Art.shape(ci, Art.ellipse(mc + Vector2(0, 2 * s), Vector2(6.5 * s, 8.5 * s), 16), MOUTH, k, 2.2 * s)
			ci.draw_colored_polygon(Art.ellipse(mc + Vector2(0, 7 * s), Vector2(4 * s, 2.5 * s), 10), TONGUE)
		"scared":
			Art.shape(ci, Art.rrect(Rect2(mc.x - 11 * s, mc.y - 3 * s, 22 * s, 9 * s), 4 * s), MOUTH, k, 2.0 * s)
			var zz := PackedVector2Array()
			for i in range(9):
				zz.append(mc + Vector2(-9.5 * s + i * 2.4 * s, 1.5 * s + (1.6 if i % 2 == 0 else -1.6) * s))
			ci.draw_polyline(zz, TEETH, 2.2 * s, true)
		"angry":
			Art.shape(ci, Art.rrect(Rect2(mc.x - 11 * s, mc.y - 3 * s, 22 * s, 9 * s), 3 * s), MOUTH, k, 2.2 * s)
			ci.draw_rect(Rect2(mc.x - 9.5 * s, mc.y - 1.5 * s, 19 * s, 6 * s), TEETH)
			for i in range(5):
				ci.draw_line(mc + Vector2(-6 * s + i * 3 * s, -1.5 * s), mc + Vector2(-6 * s + i * 3 * s, 4.5 * s), Color(k, 0.6), 1.0 * s)
		"suspicious":
			ci.draw_polyline(PackedVector2Array([mc + Vector2(-8 * s, 2 * s), mc + Vector2(2 * s, 1 * s), mc + Vector2(9 * s, -3 * s)]), k, 2.8 * s, true)
		"confused":
			var wv := PackedVector2Array()
			for i in range(9):
				wv.append(mc + Vector2(-9 * s + i * 2.25 * s, sin(i * 1.2) * 2.2 * s))
			ci.draw_polyline(wv, k, 2.6 * s, true)
		"sad":
			ci.draw_arc(mc + Vector2(0, 8 * s), 9 * s, PI + 0.45, TAU - 0.45, 12, k, 3.0 * s, true)
		"relieved":
			ci.draw_arc(mc + Vector2(0, -4 * s), 8 * s, 0.35, PI - 0.35, 12, k, 2.8 * s, true)
		"sly":
			var g := PackedVector2Array()
			for i in range(13):
				var t := float(i) / 12.0
				g.append(mc + Vector2((t - 0.5) * 28 * s, -3 * s + sin(t * PI) * 8 * s))
			for i in range(12, -1, -1):
				var t2 := float(i) / 12.0
				g.append(mc + Vector2((t2 - 0.5) * 28 * s, -3 * s + sin(t2 * PI) * 1.5 * s))
			Art.shape(ci, g, Color("2a0808"), k, 1.8 * s)
			for i in range(6):
				var tx := mc.x + (-10 + i * 4) * s
				var long := i == 1 or i == 4
				ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 1.8 * s, mc.y - 1.5 * s), Vector2(tx + 1.8 * s, mc.y - 1.5 * s),
					Vector2(tx, mc.y + (5.0 if long else 2.5) * s)]), TEETH)
		"cold":
			var zz2 := PackedVector2Array()
			for i in range(7):
				zz2.append(mc + Vector2(-7 * s + i * 2.33 * s, (1.3 if i % 2 == 0 else -1.3) * s))
			ci.draw_polyline(zz2, k, 2.2 * s, true)
		_:
			if fem:
				# губы: верхняя «галочкой», нижняя пухлее
				Art.shape(ci, PackedVector2Array([mc + Vector2(-6 * s, 0), mc + Vector2(-2 * s, -2.2 * s), mc + Vector2(0, -1.2 * s),
					mc + Vector2(2 * s, -2.2 * s), mc + Vector2(6 * s, 0), mc + Vector2(0, 3.2 * s)]), pal.lips, Color(k, 0.6), 1.4 * s)
			else:
				ci.draw_arc(mc + Vector2(0, -3 * s), 6 * s, 0.45, PI - 0.45, 10, k, 2.6 * s, true)


## Глаз: белок, радужка, зрачок, блик. lid — веко сверху 0..1, slant — злой наклон века (знак — сторона).
static func _eye(ci: CanvasItem, c: Vector2, s: float, pal: Dictionary, k: Color, dir: Vector2, lid: float,
		iris: Color = Color(0, 0, 0, 0), iris_scale: float = 1.0, slit: bool = false, slant: float = 0.0) -> void:
	var rx := 7.4 * s
	var ry := 8.8 * s
	Art.shape(ci, Art.ellipse(c, Vector2(rx, ry), 18), Color(1, 1, 1), k, 1.9 * s)
	var d := dir.limit_length(1.0) * Vector2(2.6 * s, 2.4 * s)
	var ic: Color = pal.eye if iris.a == 0.0 else iris
	ci.draw_circle(c + d, 4.8 * s * iris_scale, ic)
	if slit:
		ci.draw_colored_polygon(Art.ellipse(c + d, Vector2(1.2 * s, 4.2 * s), 10), Color("140c0c"))
	else:
		ci.draw_circle(c + d, 2.5 * s * iris_scale, Color("140c0c"))
		ci.draw_circle(c + d + Vector2(-1.6 * s, -2.1 * s), 1.5 * s, Color(1, 1, 1))
	if lid > 0.0:
		# веко: верхняя дуга глаза над линией разреза; разрез может быть наклонён (злость, грусть)
		var rx2 := rx + 0.7 * s
		var ry2 := ry + 0.7 * s
		var base_cut := c.y - ry + ry * 2.0 * lid
		var cut_l := base_cut - 0.5 * slant * -9.0 * s
		var cut_r := base_cut + 0.5 * slant * -9.0 * s
		var line_y := func(x: float) -> float: return lerpf(cut_l, cut_r, (x - (c.x - rx2)) / (2.0 * rx2))
		var pts := PackedVector2Array()
		pts.append(Vector2(c.x - rx2, cut_l))
		for i in range(1, 24):
			var a := PI + PI * i / 24.0
			var pt := c + Vector2(cos(a) * rx2, sin(a) * ry2)
			if pt.y < float(line_y.call(pt.x)) - 0.3:
				pts.append(pt)
		pts.append(Vector2(c.x + rx2, cut_r))
		if pts.size() >= 3:
			ci.draw_colored_polygon(pts, pal.skin_d)
		ci.draw_line(Vector2(c.x - rx, cut_l), Vector2(c.x + rx, cut_r), k, 2.0 * s, true)


## Ресницы: три чёрточки с внешнего края века.
static func _lashes(ci: CanvasItem, c: Vector2, s: float, side: float, k: Color) -> void:
	for i in range(3):
		var a := -PI * 0.5 + side * (0.45 + i * 0.32)
		var p0 := c + Vector2(cos(a) * 7.4 * s, sin(a) * 8.8 * s)
		var p1 := p0 + Vector2(cos(a), sin(a)) * 4.2 * s + Vector2(side * 1.5 * s, -0.5 * s)
		ci.draw_line(p0, p1, k, 2.0 * s, true)


static func _lashes_closed(ci: CanvasItem, c: Vector2, s: float, side: float, k: Color) -> void:
	for i in range(2):
		var p0 := c + Vector2(side * (4 + i * 2.5) * s, 4.5 * s)
		ci.draw_line(p0, p0 + Vector2(side * 2 * s, 3 * s), k, 1.8 * s, true)


static func _drop(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7 * s), p + Vector2(4 * s, 1 * s), p + Vector2(-4 * s, 1 * s)]), Color("7cc6ff"))
	ci.draw_circle(p + Vector2(0, 2 * s), 4 * s, Color("7cc6ff"))
	ci.draw_circle(p + Vector2(-1.2 * s, 1 * s), 1.2 * s, Color(1, 1, 1, 0.8))


## Значок эмоции над головой — как в комиксах: его видно даже на маленьком экране.
static func _emote(ci: CanvasItem, p: Vector2, s: float, face: String, k: Color) -> void:
	var font := ThemeFactory.font_bold()
	match face:
		"angry":
			var red := Color("e0453a")
			for i in range(4):
				var a := TAU * i / 4.0 + PI * 0.25
				var d := Vector2(cos(a), sin(a))
				var q := p + d * 6 * s
				ci.draw_arc(q, 4.5 * s, a + PI * 0.75, a + PI * 1.25, 6, red, 3.2 * s, true)
		"shocked":
			ci.draw_string_outline(font, p + Vector2(-5 * s, 8 * s), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * s), int(5 * s), k)
			ci.draw_string(font, p + Vector2(-5 * s, 8 * s), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * s), Color("ffd84a"))
		"confused":
			ci.draw_string_outline(font, p + Vector2(-6 * s, 8 * s), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * s), int(5 * s), k)
			ci.draw_string(font, p + Vector2(-6 * s, 8 * s), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * s), Color(1, 1, 1))
		"sad":
			var cl := p + Vector2(0, -2 * s)
			for b: Vector3 in [Vector3(-6, 0, 6), Vector3(2, -3, 7.5), Vector3(9, 1, 5.5)]:
				Art.shape(ci, Art.ellipse(cl + Vector2(b.x, b.y) * s, Vector2(b.z, b.z * 0.8) * s, 12), Color("9aa3b5"), k, 1.6 * s)
			for i in range(3):
				ci.draw_line(cl + Vector2((-5 + i * 6) * s, 7 * s), cl + Vector2((-7 + i * 6) * s, 12 * s), Color("7cc6ff"), 2 * s, true)
		"happy":
			for sp: Vector2 in [Vector2(-4, -2), Vector2(7, 4)]:
				var c := p + sp * s
				for i in range(4):
					var a := TAU * i / 4.0
					ci.draw_line(c, c + Vector2(cos(a), sin(a)) * 5 * s, Color("ffd84a"), 2.4 * s, true)
		"suspicious":
			for i in range(3):
				ci.draw_circle(p + Vector2((-6 + i * 6) * s, 4 * s), 2.2 * s, k)
		"cold":
			for i in range(3):
				var a := TAU * i / 6.0
				var d := Vector2(cos(a), sin(a)) * 7 * s
				ci.draw_line(p - d, p + d, Color(0.85, 0.95, 1.0), 2.4 * s, true)
		"scared":
			for i in range(3):
				ci.draw_line(p + Vector2((-6 + i * 6) * s, -4 * s), p + Vector2((-4 + i * 6) * s, 6 * s), Color("7cc6ff"), 2.4 * s, true)


# ---------------------------------------------------------------
# Причёски, шапки, украшения
# ---------------------------------------------------------------
static func _hair_back(ci: CanvasItem, o: Vector2, s: float, look: LookDef, pal: Dictionary, k: Color, lw: float) -> void:
	var r := HEAD_R * s
	match look.hair_style:
		LookDef.Hair.LONG:
			var pts := PackedVector2Array([o + Vector2(-r * 1.12, -r * 0.3), o + Vector2(-r * 1.2, r * 1.15), o + Vector2(-r * 0.7, r * 1.45),
				o + Vector2(0, r * 1.25), o + Vector2(r * 0.7, r * 1.45), o + Vector2(r * 1.2, r * 1.15), o + Vector2(r * 1.12, -r * 0.3), o + Vector2(0, -r * 1.1)])
			Art.shape(ci, pts, pal.hair_d, k, lw)
		LookDef.Hair.BOB:
			Art.shape(ci, Art.rrect(Rect2(o.x - r * 1.15, o.y - r * 0.55, r * 2.3, r * 1.3), r * 0.45), pal.hair_d, k, lw)
		LookDef.Hair.PONYTAIL:
			var tail := PackedVector2Array([o + Vector2(r * 0.55, -r * 0.8), o + Vector2(r * 1.5, -r * 0.35), o + Vector2(r * 1.62, r * 0.85),
				o + Vector2(r * 1.25, r * 0.65), o + Vector2(r * 1.0, -r * 0.1)])
			Art.shape(ci, tail, pal.hair, k, lw)
		LookDef.Hair.BUN:
			Art.shape(ci, Art.ellipse(o + Vector2(0, -r * 1.12), Vector2(r * 0.44, r * 0.38), 16), pal.hair, k, lw)
		LookDef.Hair.BRAIDS:
			for side: float in [-1.0, 1.0]:
				for i in range(4):
					var c := o + Vector2(side * r * 0.98, r * 0.15 + i * r * 0.32)
					Art.shape(ci, Art.ellipse(c, Vector2(r * 0.2, r * 0.19), 12), pal.hair if i % 2 == 0 else pal.hair_d, k, lw * 0.7)
				var tip := o + Vector2(side * r * 0.98, r * 1.42)
				Art.shape(ci, Art.ellipse(tip, Vector2(r * 0.12, r * 0.08), 10), pal.accent, k, lw * 0.6)
		LookDef.Hair.PIGTAILS:
			for side: float in [-1.0, 1.0]:
				var base := o + Vector2(side * r * 1.0, -r * 0.35)
				var tail2 := PackedVector2Array([base, base + Vector2(side * r * 0.55, r * 0.15), base + Vector2(side * r * 0.62, r * 0.8),
					base + Vector2(side * r * 0.25, r * 0.6), base + Vector2(0, r * 0.25)])
				Art.shape(ci, tail2, pal.hair, k, lw)


static func _hair_front(ci: CanvasItem, o: Vector2, s: float, look: LookDef, pal: Dictionary, k: Color, lw: float) -> void:
	var r := HEAD_R * s
	if look.head == LookDef.Head.HAT or look.head == LookDef.Head.HOOD or look.head == LookDef.Head.SCARF:
		if look.hair_style != LookDef.Hair.BALD:
			var fr := PackedVector2Array()
			for i in range(9):
				var a := PI * 1.15 + PI * 0.7 * i / 8.0
				fr.append(o + Vector2(cos(a) * r, sin(a) * r * 0.8 - 2 * s))
			fr.append(o + Vector2(r * 0.5, -r * 0.45))
			fr.append(o + Vector2(-r * 0.5, -r * 0.45))
			Art.shape(ci, fr, pal.hair, k, lw * 0.8)
		return
	var cap := PackedVector2Array()
	match look.hair_style:
		LookDef.Hair.BALD:
			ci.draw_arc(o + Vector2(-8 * s, -18 * s), 7 * s, PI * 1.1, PI * 1.6, 6, Color(1, 1, 1, 0.45), 2.4 * s, true)
			for sx: float in [-1.0, 1.0]:
				Art.shape(ci, Art.ellipse(o + Vector2(sx * r * 0.92, -2 * s), Vector2(5 * s, 11 * s), 10), pal.hair, k, lw * 0.7)
			return
		LookDef.Hair.SPIKY:
			for i in range(9):
				var a := PI + PI * float(i) / 8.0
				var rr := r * (1.34 if i % 2 == 1 else 1.0)
				cap.append(o + Vector2(cos(a) * rr, sin(a) * rr - 2 * s))
			cap.append(o + Vector2(r * 0.7, -r * 0.5))
			cap.append(o + Vector2(-r * 0.7, -r * 0.5))
		LookDef.Hair.CURLY:
			for i in range(11):
				var a := PI * 0.95 + PI * 1.1 * i / 10.0
				var c := o + Vector2(cos(a) * r * 0.95, sin(a) * r * 0.92)
				Art.shape(ci, Art.ellipse(c, Vector2(r * 0.3, r * 0.28), 12), pal.hair, k, lw * 0.7)
			if look.female:
				for side: float in [-1.0, 1.0]:
					for i in range(2):
						Art.shape(ci, Art.ellipse(o + Vector2(side * r * 1.0, r * (0.35 + i * 0.4)), Vector2(r * 0.26, r * 0.24), 12), pal.hair, k, lw * 0.7)
			return
		LookDef.Hair.BANGS, LookDef.Hair.BOB:
			for i in range(13):
				var a := PI + PI * i / 12.0
				cap.append(o + Vector2(cos(a) * r * 1.06, sin(a) * r * 1.02))
			cap.append(o + Vector2(r * 1.04, -r * 0.05))
			for i in range(6, -1, -1):
				cap.append(o + Vector2((i - 3) * r * 0.32, -r * 0.32 + (2.5 * s if i % 2 == 0 else -2.0 * s)))
			cap.append(o + Vector2(-r * 1.04, -r * 0.05))
		_:
			if look.female:
				# женская причёска: пробор сбоку, волосы спускаются по вискам
				for i in range(13):
					var a := PI + PI * i / 12.0
					cap.append(o + Vector2(cos(a) * r * 1.06, sin(a) * r * 1.04 - 1 * s))
				cap.append(o + Vector2(r * 1.06, r * 0.3))
				cap.append(o + Vector2(r * 0.82, r * 0.25))
				cap.append(o + Vector2(r * 0.7, -r * 0.35))
				cap.append(o + Vector2(-r * 0.25, -r * 0.62))
				cap.append(o + Vector2(-r * 0.75, -r * 0.3))
				cap.append(o + Vector2(-r * 0.85, r * 0.25))
				cap.append(o + Vector2(-r * 1.06, r * 0.3))
			else:
				for i in range(13):
					var a := PI + PI * i / 12.0
					cap.append(o + Vector2(cos(a) * r * 1.05, sin(a) * r * 1.02 - 1 * s))
				cap.append(o + Vector2(r * 0.95, -r * 0.25))
				cap.append(o + Vector2(r * 0.2, -r * 0.55))
				cap.append(o + Vector2(-r * 0.15, -r * 0.42))
				cap.append(o + Vector2(-r * 0.95, -r * 0.2))
	Art.shape(ci, cap, pal.hair, k, lw)
	ci.draw_arc(o + Vector2(-r * 0.3, -r * 0.62), r * 0.3, PI * 1.15, PI * 1.6, 6, Color(pal.hair_l, 0.55), 2.4 * s, true)


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
			# узелок платка под подбородком
			Art.shape(ci, Art.ellipse(o + Vector2(r * 0.55, r * 0.95), Vector2(5 * s, 4 * s), 10), hat, k, lw * 0.7)
		LookDef.Head.CAP:
			var p3 := PackedVector2Array()
			for i in range(15):
				var a := PI + PI * i / 14.0
				p3.append(o + Vector2(cos(a) * r * 1.02, sin(a) * r * 0.85 - 9 * s))
			Art.shape(ci, p3, hat, k, lw)
			Art.shape(ci, Art.rrect(Rect2(o.x - 4 * s, o.y - 14 * s, r * 1.45, 7 * s), 3 * s), hat.darkened(0.25), k, lw * 0.9)


## Бант, заколка или цветок в волосах.
static func _bow(ci: CanvasItem, o: Vector2, s: float, look: LookDef, pal: Dictionary, k: Color, lw: float) -> void:
	var r := HEAD_R * s
	var c := o + Vector2(r * 0.62, -r * 0.82)
	var col: Color = pal.accent
	match look.bow:
		LookDef.Bow.BOW:
			for side: float in [-1.0, 1.0]:
				Art.shape(ci, PackedVector2Array([c, c + Vector2(side * 10 * s, -7 * s), c + Vector2(side * 11 * s, 6 * s)]), col, k, lw * 0.7)
			Art.shape(ci, Art.ellipse(c, Vector2(3.4 * s, 3.4 * s), 10), col.darkened(0.15), k, lw * 0.6)
		LookDef.Bow.CLIP:
			Art.shape(ci, Art.rrect(Rect2(c.x - 7 * s, c.y - 2.5 * s, 14 * s, 5 * s), 2 * s), col, k, lw * 0.6)
		LookDef.Bow.FLOWER:
			for i in range(5):
				var a := TAU * i / 5.0
				Art.shape(ci, Art.ellipse(c + Vector2(cos(a), sin(a)) * 4.5 * s, Vector2(3.6 * s, 3.6 * s), 10), Color(1, 0.85, 0.9), k, lw * 0.5)
			ci.draw_circle(c, 2.6 * s, Color("f2c94c"))


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
		"axe": return Vector2(2.0 + t * 0.9, 2.0 + t * 0.9)
		"bucket": return Vector2(0.3, 0.2 + maxf(0.0, t) * 1.6)
		"oar": return Vector2(1.3 + t * 0.6, 1.0 - t * 0.6)
		"can": return Vector2(0.4, 1.6 + t * 0.3)
		"chalk": return Vector2(0.3, 1.9 + t * 0.4)
	return Vector2(0.12, 0.12)


static func _draw_tool(ci: CanvasItem, tool: String, lh: Vector2, rh: Vector2, w: float, s: float, k: Color) -> void:
	match tool:
		"axe":
			var grip := (lh + rh) * 0.5
			var up := Vector2(1, -0.4).normalized().rotated(sin(w * TAU) * 0.9)
			var tip := grip + up * 28 * s
			ci.draw_line(grip, tip, k, 5 * s, true)
			ci.draw_line(grip, tip, Color("8a5a3a"), 3 * s, true)
			Art.shape(ci, PackedVector2Array([tip + Vector2(-3 * s, -4 * s), tip + Vector2(9 * s, -8 * s), tip + Vector2(10 * s, 5 * s), tip + Vector2(-2 * s, 3 * s)]), Color("c8c8d0"), k, 1.6 * s)
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
