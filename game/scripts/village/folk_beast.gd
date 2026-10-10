class_name FolkBeast
extends RefCounted
## Звериные головы для персонажей-символов стран: медведь, панда, царь обезьян, слон, тигр…
## Рисуются в той же манере, что люди: толстый контур, крупные глаза с белками, брови и рот
## по эмоции — грусть, страх и злость читаются так же, как у людей.
## Цвета: шерсть — look.hair, морда и светлые места — look.skin, приметы (гребень, пятна) — look.accent.
##
## Координаты — как в Folk.head: o — центр головы, r = Folk.HEAD_R * s.

const NOSE := Color("2a1c1c")
const PINK := Color("f2a0a8")
const HORN := Color("e8dcc0")
const BEAK := Color("f2b23c")

## Под какими головными уборами звериные уши на макушке не рисуются.
const COVERING: Array = [LookDef.Head.HAT, LookDef.Head.HOOD, LookDef.Head.SCARF, LookDef.Head.USHANKA,
	LookDef.Head.SOMBRERO, LookDef.Head.TURBAN, LookDef.Head.CONICAL, LookDef.Head.MUSKETEER,
	LookDef.Head.CANGACEIRO, LookDef.Head.STRAW, LookDef.Head.JESTER, LookDef.Head.TOP_HAT,
	LookDef.Head.CATRINA, LookDef.Head.DEERSTALKER, LookDef.Head.PHRYGIAN, LookDef.Head.FEZ, LookDef.Head.BERET]


static func head(ci: CanvasItem, o: Vector2, s: float, look: LookDef, face: String, pose: Dictionary, pal: Dictionary, k: Color, lw: float) -> void:
	var r := Folk.HEAD_R * s
	var n: float = pal.get("n", 0.0)
	var fur: Color = pal.hair
	var muz: Color = pal.skin
	var dark: Color = pal.hair_d
	var acc: Color = pal.accent
	var a := look.animal
	if a == LookDef.Animal.PANDA:
		fur = Art.dn(Color("f4f1ea"), n)
		dark = Art.dn(Color("26242c"), n)
		muz = fur
	var turn: float = clampf(pose.get("turn", 0.0), -1.0, 1.0)
	var fo := o + Vector2(turn * 6.0 * s, 0)
	var covered := COVERING.has(look.head)
	var look_dir: Vector2 = pose.get("look", Vector2.ZERO)

	# --- за головой: уши, рога, хохолки ---
	match a:
		LookDef.Animal.BEAR, LookDef.Animal.PANDA:
			if not covered:
				for sx: float in [-1.0, 1.0]:
					var ec := o + Vector2(sx * r * 0.78, -r * 0.78)
					Art.shape(ci, Art.ellipse(ec, Vector2(r * 0.33, r * 0.33), 16), dark if a == LookDef.Animal.PANDA else fur, k, lw)
					ci.draw_colored_polygon(Art.ellipse(ec + Vector2(0, 2 * s), Vector2(r * 0.18, r * 0.18), 12), muz if a != LookDef.Animal.PANDA else dark.lightened(0.15))
		LookDef.Animal.MONKEY:
			for sx: float in [-1.0, 1.0]:
				var ec := o + Vector2(sx * r * 1.02, r * 0.02)
				Art.shape(ci, Art.ellipse(ec, Vector2(r * 0.3, r * 0.32), 16), fur, k, lw)
				ci.draw_colored_polygon(Art.ellipse(ec, Vector2(r * 0.17, r * 0.19), 12), muz)
		LookDef.Animal.PIG:
			if not covered:
				for sx: float in [-1.0, 1.0]:
					Art.shape(ci, PackedVector2Array([o + Vector2(sx * r * 0.35, -r * 0.85), o + Vector2(sx * r * 0.95, -r * 1.05),
						o + Vector2(sx * r * 0.85, -r * 0.45)]), fur, k, lw)
		LookDef.Animal.CAT, LookDef.Animal.TIGER, LookDef.Animal.JAGUAR, LookDef.Animal.WOLF, LookDef.Animal.FOX:
			if not covered:
				var tall := 0.72 if a == LookDef.Animal.WOLF or a == LookDef.Animal.FOX else 0.55
				for sx: float in [-1.0, 1.0]:
					var b1 := o + Vector2(sx * r * 0.28, -r * 0.82)
					var b2 := o + Vector2(sx * r * 0.92, -r * 0.5)
					var tip := o + Vector2(sx * r * 0.78, -r * (0.82 + tall))
					Art.shape(ci, PackedVector2Array([b1, tip, b2]), fur, k, lw)
					ci.draw_colored_polygon(PackedVector2Array([b1.lerp(b2, 0.2) + Vector2(0, -2 * s), tip.lerp((b1 + b2) * 0.5, 0.28), b1.lerp(b2, 0.8) + Vector2(0, -2 * s)]),
						Art.dn(PINK, n) if a == LookDef.Animal.CAT else dark)
					if a == LookDef.Animal.FOX:
						ci.draw_colored_polygon(PackedVector2Array([tip, tip.lerp(b1, 0.28), tip.lerp(b2, 0.28)]), Art.dn(Color("2a2020"), n))
		LookDef.Animal.BULLDOG:
			for sx: float in [-1.0, 1.0]:
				Art.shape(ci, PackedVector2Array([o + Vector2(sx * r * 0.55, -r * 0.85), o + Vector2(sx * r * 1.12, -r * 0.82),
					o + Vector2(sx * r * 1.0, -r * 0.35)]), dark, k, lw)
		LookDef.Animal.RABBIT:
			if not covered:
				for sx: float in [-1.0, 1.0]:
					var ec := o + Vector2(sx * r * 0.34, -r * 1.42)
					Art.shape(ci, Art.ellipse(ec, Vector2(r * 0.21, r * 0.62), 18), fur, k, lw)
					ci.draw_colored_polygon(Art.ellipse(ec + Vector2(0, 3 * s), Vector2(r * 0.1, r * 0.45), 12), Art.dn(PINK, n))
		LookDef.Animal.ELEPHANT:
			for sx: float in [-1.0, 1.0]:
				var ec := o + Vector2(sx * r * 1.12, r * 0.08)
				Art.shape(ci, Art.ellipse(ec, Vector2(r * 0.62, r * 0.82), 20), fur.darkened(0.08), k, lw)
				ci.draw_colored_polygon(Art.ellipse(ec + Vector2(sx * 3 * s, 2 * s), Vector2(r * 0.42, r * 0.6), 16), Color(Art.dn(PINK, n), 0.55))
		LookDef.Animal.BUFFALO:
			for sx: float in [-1.0, 1.0]:
				var horn := PackedVector2Array()
				for i in range(9):
					var t := float(i) / 8.0
					horn.append(o + Vector2(sx * (r * 0.55 + t * r * 1.05), -r * 0.62 - sin(t * PI * 0.9) * r * 0.55 + t * t * r * 0.1))
				ci.draw_polyline(horn, k, r * 0.34 + lw * 2.0, true)
				ci.draw_polyline(horn, Art.dn(HORN, n), r * 0.34, true)
				ci.draw_circle(horn[horn.size() - 1], r * 0.12, Art.dn(HORN, n))
				Art.shape(ci, Art.ellipse(o + Vector2(sx * r * 1.08, -r * 0.05), Vector2(r * 0.3, r * 0.14), 12), fur, k, lw * 0.8)
		LookDef.Animal.PEACOCK:
			if not covered:
				for i in range(5):
					var ang := -PI * 0.5 + (i - 2) * 0.28
					var base := o + Vector2(0, -r * 0.92)
					var tip := base + Vector2(cos(ang), sin(ang)) * r * 0.75
					ci.draw_line(base, tip, k, 2.6 * s, true)
					Art.shape(ci, Art.ellipse(tip, Vector2(4.5 * s, 5.5 * s), 10), acc, k, lw * 0.6)
					ci.draw_circle(tip, 2.0 * s, Art.dn(Color("1e4f8a"), n))

	# --- сама голова ---
	var rx := r * 1.05
	var ry := r * 1.0
	match a:
		LookDef.Animal.BULLDOG, LookDef.Animal.BUFFALO:
			rx = r * 1.16
			ry = r * 0.96
		LookDef.Animal.CAT, LookDef.Animal.TIGER, LookDef.Animal.JAGUAR:
			rx = r * 1.1
	var hp := Art.ellipse(o, Vector2(rx, ry), 36)
	ci.draw_colored_polygon(hp, fur.darkened(0.12))
	var inner := PackedVector2Array()
	for pt: Vector2 in hp:
		inner.append(o + (pt - o) * 0.93 + Vector2(-2.5 * s, -2 * s))
	ci.draw_colored_polygon(inner, fur)
	match face:
		"angry":
			ci.draw_colored_polygon(Art.ellipse(o + Vector2(0, -r * 0.35), Vector2(r * 0.8, r * 0.45), 18), Color(0.9, 0.15, 0.1, 0.28))
		"scared", "cold":
			ci.draw_colored_polygon(inner, Color(0.6, 0.75, 1.0, 0.24))
		"sly":
			ci.draw_colored_polygon(inner, Color(0.55, 0.7, 0.3, 0.16))
	var outl := hp.duplicate()
	outl.append(hp[0])
	ci.draw_polyline(outl, k, lw, true)

	# --- окрас и морда (под глазами) ---
	var ex := r * 0.36
	var ey := -r * 0.1
	var mouth_at := fo + Vector2(0, r * 0.52)
	var mouth_s := 0.62
	var beak := false
	match a:
		LookDef.Animal.BEAR, LookDef.Animal.PANDA:
			if a == LookDef.Animal.PANDA:
				for sx: float in [-1.0, 1.0]:
					var pc := fo + Vector2(sx * ex, ey + 2 * s)
					var patch := Art.ellipse(Vector2.ZERO, Vector2(r * 0.31, r * 0.4), 16)
					var rot := PackedVector2Array()
					for q: Vector2 in patch:
						rot.append(pc + q.rotated(-sx * 0.5))
					ci.draw_colored_polygon(rot, dark)
			Art.shape(ci, Art.ellipse(fo + Vector2(0, r * 0.38), Vector2(r * 0.5, r * 0.36), 20), muz if a != LookDef.Animal.PANDA else Art.dn(Color("ffffff"), n), k, lw * 0.7)
			Art.shape(ci, Art.ellipse(fo + Vector2(0, r * 0.22), Vector2(r * 0.18, r * 0.12), 14), Art.dn(NOSE, n), k, lw * 0.5)
			mouth_at = fo + Vector2(0, r * 0.5)
		LookDef.Animal.MONKEY:
			for sx: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(Art.ellipse(fo + Vector2(sx * r * 0.3, ey), Vector2(r * 0.36, r * 0.38), 18), muz)
			Art.shape(ci, Art.ellipse(fo + Vector2(0, r * 0.4), Vector2(r * 0.52, r * 0.38), 20), muz, Color(k, 0.6), lw * 0.6)
			for sx: float in [-1.0, 1.0]:
				ci.draw_circle(fo + Vector2(sx * 3 * s, r * 0.22), 1.8 * s, Art.dn(NOSE, n))
			mouth_at = fo + Vector2(0, r * 0.5)
		LookDef.Animal.PIG:
			Art.shape(ci, Art.ellipse(fo + Vector2(0, r * 0.3), Vector2(r * 0.36, r * 0.26), 18), muz, k, lw * 0.8)
			for sx: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(Art.ellipse(fo + Vector2(sx * r * 0.13, r * 0.3), Vector2(r * 0.06, r * 0.1), 10), fur.darkened(0.45))
			mouth_at = fo + Vector2(0, r * 0.66)
			mouth_s = 0.55
		LookDef.Animal.CAT, LookDef.Animal.TIGER, LookDef.Animal.JAGUAR:
			if a == LookDef.Animal.TIGER or a == LookDef.Animal.CAT:
				var stripe := dark.darkened(0.35) if a == LookDef.Animal.TIGER else Color(dark, 0.6)
				for i in range(3):
					var x := (i - 1) * r * 0.22
					ci.draw_colored_polygon(PackedVector2Array([o + Vector2(x - 3 * s, -r * 0.92), o + Vector2(x + 3 * s, -r * 0.92), o + Vector2(x, -r * 0.55)]), stripe)
				for sx: float in [-1.0, 1.0]:
					for j in range(2):
						var yy := r * (0.05 + j * 0.25)
						ci.draw_colored_polygon(PackedVector2Array([o + Vector2(sx * rx * 0.98, yy - 3 * s), o + Vector2(sx * rx * 0.98, yy + 3 * s), o + Vector2(sx * rx * 0.62, yy)]), stripe)
			elif a == LookDef.Animal.JAGUAR:
				for q: Vector2 in [Vector2(-0.45, -0.55), Vector2(0.0, -0.72), Vector2(0.45, -0.55), Vector2(-0.82, 0.05), Vector2(0.82, 0.05), Vector2(-0.7, 0.42), Vector2(0.7, 0.42)]:
					for d: Vector2 in [Vector2(-3, -1), Vector2(2, -3), Vector2(3, 2), Vector2(-2, 3)]:
						ci.draw_circle(o + q * r + d * s, 1.9 * s, dark.darkened(0.45))
			for sx: float in [-1.0, 1.0]:
				Art.shape(ci, Art.ellipse(fo + Vector2(sx * r * 0.17, r * 0.4), Vector2(r * 0.2, r * 0.15), 14), muz, Color(k, 0.5), lw * 0.5)
				for j in range(3):
					var w0 := fo + Vector2(sx * r * 0.32, r * (0.34 + j * 0.08))
					ci.draw_line(w0, w0 + Vector2(sx * r * 0.55, (j - 1) * r * 0.12), Color(k, 0.7), 1.4 * s, true)
			ci.draw_colored_polygon(PackedVector2Array([fo + Vector2(-r * 0.1, r * 0.24), fo + Vector2(r * 0.1, r * 0.24), fo + Vector2(0, r * 0.34)]), Art.dn(PINK.darkened(0.15), n))
			mouth_at = fo + Vector2(0, r * 0.58)
			mouth_s = 0.55
		LookDef.Animal.WOLF, LookDef.Animal.FOX:
			var cheek := PackedVector2Array([o + Vector2(-rx * 0.98, r * 0.05), o + Vector2(-r * 0.25, r * 0.15), o + Vector2(0, r * 0.98),
				o + Vector2(r * 0.25, r * 0.15), o + Vector2(rx * 0.98, r * 0.05), o + Vector2(rx * 0.7, r * 0.7), o + Vector2(0, r * 1.0), o + Vector2(-rx * 0.7, r * 0.7)])
			var cheek2 := PackedVector2Array()
			for q2: Vector2 in cheek:
				cheek2.append(o + (q2 - o) * 0.9)
			ci.draw_colored_polygon(cheek2, muz)
			Art.shape(ci, Art.ellipse(fo + Vector2(0, r * 0.38), Vector2(r * 0.3, r * 0.36), 18), muz, Color(k, 0.6), lw * 0.6)
			Art.shape(ci, Art.ellipse(fo + Vector2(0, r * 0.2), Vector2(r * 0.15, r * 0.1), 12), Art.dn(NOSE, n), k, lw * 0.4)
			mouth_at = fo + Vector2(0, r * 0.52)
			mouth_s = 0.55
		LookDef.Animal.BULLDOG:
			for sx: float in [-1.0, 1.0]:
				Art.shape(ci, Art.ellipse(fo + Vector2(sx * r * 0.32, r * 0.42), Vector2(r * 0.4, r * 0.32), 18), muz, k, lw * 0.7)
			Art.shape(ci, Art.ellipse(fo + Vector2(0, r * 0.18), Vector2(r * 0.22, r * 0.15), 14), Art.dn(NOSE, n), k, lw * 0.5)
			for i in range(3):
				ci.draw_arc(o + Vector2(0, -r * (0.42 + i * 0.13)), r * 0.35, PI * 1.2, PI * 1.8, 8, Color(k, 0.35), 1.6 * s, true)
			for sx: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([fo + Vector2(sx * r * 0.2, r * 0.66), fo + Vector2(sx * r * 0.3, r * 0.66), fo + Vector2(sx * r * 0.25, r * 0.54)]), Art.dn(Color(1, 0.98, 0.94), n))
			mouth_at = fo + Vector2(0, r * 0.66)
			mouth_s = 0.6
		LookDef.Animal.RABBIT:
			Art.shape(ci, Art.ellipse(fo + Vector2(0, r * 0.38), Vector2(r * 0.34, r * 0.26), 16), muz, Color(k, 0.5), lw * 0.5)
			ci.draw_colored_polygon(PackedVector2Array([fo + Vector2(-r * 0.09, r * 0.24), fo + Vector2(r * 0.09, r * 0.24), fo + Vector2(0, r * 0.32)]), Art.dn(PINK.darkened(0.1), n))
			Art.shape(ci, Art.rrect(Rect2(fo.x - r * 0.1, fo.y + r * 0.5, r * 0.2, r * 0.16), 2 * s), Art.dn(Color(1, 0.98, 0.94), n), k, lw * 0.5)
			mouth_at = fo + Vector2(0, r * 0.68)
			mouth_s = 0.5
		LookDef.Animal.ELEPHANT:
			ex = r * 0.4
			mouth_at = fo + Vector2(-r * 0.42, r * 0.58)
			mouth_s = 0.5
		LookDef.Animal.BUFFALO:
			Art.shape(ci, Art.ellipse(fo + Vector2(0, r * 0.48), Vector2(r * 0.62, r * 0.36), 20), muz, k, lw * 0.7)
			for sx: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(Art.ellipse(fo + Vector2(sx * r * 0.22, r * 0.42), Vector2(r * 0.07, r * 0.1), 10), fur.darkened(0.5))
			mouth_at = fo + Vector2(0, r * 0.66)
			mouth_s = 0.6
		LookDef.Animal.ROOSTER:
			if not covered:
				for i in range(4):
					var cc := o + Vector2((i - 1.5) * r * 0.22, -r * (0.98 + (0.12 if i == 1 or i == 2 else 0.0)))
					Art.shape(ci, Art.ellipse(cc, Vector2(r * 0.16, r * 0.2), 12), Art.dn(Color("d8322a"), n), k, lw * 0.7)
			Art.shape(ci, PackedVector2Array([fo + Vector2(-r * 0.1, r * 0.55), fo + Vector2(r * 0.1, r * 0.55), fo + Vector2(r * 0.12, r * 0.85), fo + Vector2(0, r * 0.98), fo + Vector2(-r * 0.12, r * 0.85)]),
				Art.dn(Color("d8322a"), n), k, lw * 0.7)
			beak = true
		LookDef.Animal.MACAW:
			for sx: float in [-1.0, 1.0]:
				Art.shape(ci, Art.ellipse(fo + Vector2(sx * ex, ey + 2 * s), Vector2(r * 0.3, r * 0.3), 16), Art.dn(Color("f6f2ea"), n), Color(k, 0.4), lw * 0.5)
				for j in range(3):
					ci.draw_line(fo + Vector2(sx * (ex + r * 0.05), ey + r * (0.12 + j * 0.07)), fo + Vector2(sx * (ex + r * 0.2), ey + r * (0.1 + j * 0.07)), Color(k, 0.6), 1.2 * s, true)
			beak = true
		LookDef.Animal.PEACOCK:
			for sx: float in [-1.0, 1.0]:
				ci.draw_line(fo + Vector2(sx * (ex - r * 0.15), ey - r * 0.32), fo + Vector2(sx * (ex + r * 0.3), ey - r * 0.22), Art.dn(Color("f6f2ea"), n), 3.0 * s, true)
				ci.draw_line(fo + Vector2(sx * (ex - r * 0.1), ey + r * 0.3), fo + Vector2(sx * (ex + r * 0.32), ey + r * 0.22), Art.dn(Color("f6f2ea"), n), 3.0 * s, true)
			beak = true

	if look.freckles and not beak:
		for sx: float in [-1.0, 1.0]:
			for f: Vector2 in [Vector2(0.48, 0.22), Vector2(0.6, 0.28), Vector2(0.54, 0.34)]:
				ci.draw_circle(fo + Vector2(sx * f.x * r, f.y * r), 1.2 * s, Color(dark.darkened(0.3), 0.9))

	# --- глаза и брови: те же эмоции, что у людей ---
	Folk._eyes(ci, fo, s * 0.92, look.female, face, look_dir, pal, k, ex, ey)
	var brow_pal := pal.duplicate()
	brow_pal.hair_d = dark.darkened(0.3) if a != LookDef.Animal.PANDA else Art.dn(Color("26242c"), n)
	Folk._brows(ci, fo + Vector2(0, -2 * s), s, look, face, brow_pal, ey - r * 0.36, 1.12)
	if look.glasses:
		for sx: float in [-1.0, 1.0]:
			ci.draw_arc(fo + Vector2(sx * ex, ey), 9.4 * s, 0, TAU, 20, k, 2.0 * s, true)
		ci.draw_line(fo + Vector2(-ex + 9 * s, ey - 1 * s), fo + Vector2(ex - 9 * s, ey - 1 * s), k, 2.0 * s, true)

	# --- хобот и бивни поверх морды ---
	if a == LookDef.Animal.ELEPHANT:
		var trunk := PackedVector2Array()
		var curl := 1.0 if face != "happy" else -1.0
		for i in range(14):
			var t := float(i) / 13.0
			trunk.append(fo + Vector2(sin(t * PI * 0.85) * r * 0.32 * curl - (t * t * r * 0.25 * curl), r * 0.0 + t * r * 1.35))
		# хобот сужается к концу: рисуем отрезками разной толщины
		for i in range(trunk.size() - 1):
			var w := r * lerpf(0.46, 0.24, float(i) / float(trunk.size() - 1))
			ci.draw_line(trunk[i], trunk[i + 1], k, w + lw * 2.0, true)
			ci.draw_circle(trunk[i + 1], (w + lw * 2.0) * 0.5, k)
		for i in range(trunk.size() - 1):
			var w2 := r * lerpf(0.46, 0.24, float(i) / float(trunk.size() - 1))
			ci.draw_line(trunk[i], trunk[i + 1], fur, w2, true)
			ci.draw_circle(trunk[i + 1], w2 * 0.5, fur)
		for i in range(2, 10, 2):
			var c2 := trunk[i]
			ci.draw_line(c2 + Vector2(-r * 0.13, 0), c2 + Vector2(r * 0.13, 0), Color(k, 0.35), 1.3 * s, true)
		Art.shape(ci, Art.ellipse(trunk[trunk.size() - 1], Vector2(r * 0.15, r * 0.09), 12), fur.darkened(0.15), k, lw * 0.6)
		for sx: float in [-1.0, 1.0]:
			var t0 := fo + Vector2(sx * r * 0.26, r * 0.5)
			ci.draw_polyline(PackedVector2Array([t0, t0 + Vector2(sx * r * 0.06, r * 0.18), t0 + Vector2(sx * r * 0.16, r * 0.28)]), k, 6.0 * s, true)
			ci.draw_polyline(PackedVector2Array([t0, t0 + Vector2(sx * r * 0.06, r * 0.18), t0 + Vector2(sx * r * 0.16, r * 0.28)]), Art.dn(HORN, n), 3.6 * s, true)

	# --- рот или клюв ---
	if beak:
		var bc := fo + Vector2(0, r * 0.28)
		var open := 0.0
		match face:
			"talk": open = 0.5
			"shocked": open = 0.8
			"happy": open = 0.45
			"angry", "scared": open = 0.35
		var bw := r * (0.36 if a == LookDef.Animal.MACAW else 0.26)
		var bh := r * (0.56 if a == LookDef.Animal.MACAW else 0.34)
		var bcol := Art.dn(Color("f0e6d2") if a == LookDef.Animal.MACAW else (Color("9a9aa6") if a == LookDef.Animal.PEACOCK else BEAK), n)
		if open > 0.0:
			ci.draw_colored_polygon(Art.ellipse(bc + Vector2(0, bh * 0.35), Vector2(bw * 0.6, bh * 0.5 * open + 2 * s), 12), Folk.MOUTH)
		var up := PackedVector2Array([bc + Vector2(-bw, -bh * 0.15), bc + Vector2(bw, -bh * 0.15), bc + Vector2(bw * 0.35, bh * 0.45),
			bc + Vector2(0, bh * (0.95 if a == LookDef.Animal.MACAW else 0.55) - open * bh * 0.2), bc + Vector2(-bw * 0.35, bh * 0.45)])
		Art.shape(ci, up, bcol, k, lw * 0.7)
		var lo := PackedVector2Array([bc + Vector2(-bw * 0.7, bh * 0.1 + open * bh * 0.5), bc + Vector2(bw * 0.7, bh * 0.1 + open * bh * 0.5), bc + Vector2(0, bh * 0.55 + open * bh * 0.6)])
		Art.shape(ci, lo, Art.dn(Color("2a2428"), n) if a == LookDef.Animal.MACAW else bcol.darkened(0.12), k, lw * 0.6)
		# клюв поверх нижней части: верхний рисуем ещё раз, чтобы он перекрывал нижний
		Art.shape(ci, up, bcol, k, lw * 0.7)
	else:
		Folk._mouth(ci, mouth_at, s * mouth_s, face, false, pal, k)

	# --- слёзы и пот ---
	match face:
		"sad":
			for sx: float in [-1.0, 1.0]:
				var tp := fo + Vector2(sx * (ex + 1 * s), ey + 8 * s)
				ci.draw_colored_polygon(PackedVector2Array([tp + Vector2(-2 * s, 0), tp + Vector2(2 * s, 0), tp + Vector2(1.5 * s, 12 * s), tp + Vector2(-1.5 * s, 12 * s)]), Folk.TEAR)
				ci.draw_circle(tp + Vector2(0, 13 * s), 2.6 * s, Folk.TEAR)
		"scared", "shocked":
			for d: Vector2 in [Vector2(-31, -16), Vector2(32, -8)]:
				Folk._drop(ci, o + d * s, s * 1.1)
