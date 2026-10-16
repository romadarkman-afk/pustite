class_name Glyph
extends Control
## Значок кодом: дверь, стук, оберег, туннель, клык, череп и т. д.
## Ночью и у двери он заменяет фразу: читать в напряжённый момент некогда.
## Рисуется в квадрате 48×48, масштабируется под размер.

const KINDS: PackedStringArray = ["door", "knock", "lock", "alone", "seat", "seat_on", "fang", "mimic", "people",
	"skull", "street", "street_ok", "safe", "liar", "claw", "talisman", "talisman_cracked", "talisman_broken",
	"heal", "tunnel", "pact", "fog", "moon", "quiet", "rain", "bell", "info",
	"mark_eye", "mark_pact", "mark_street", "mark_liar", "mark_death", "mark_fake", "mark_tunnel", "mark_sabotage"]

var kind := "door"
var col := ThemeFactory.BONE


static func make(k: String, px: float = 44.0, c: Color = ThemeFactory.BONE) -> Glyph:
	var g := Glyph.new()
	g.kind = k
	g.col = c
	g.custom_minimum_size = Vector2(px, px)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## Цвет значка по смыслу: смерть и угроза — красным, спасение — тёплым светом.
static func tint(k: String) -> Color:
	match k:
		"skull", "fang", "claw", "mimic", "talisman_broken", "liar": return ThemeFactory.BLOOD
		"safe", "street_ok", "heal", "seat_on", "pact": return ThemeFactory.LAMP
	return ThemeFactory.BONE


func set_kind(k: String) -> void:
	if k != kind:
		kind = k
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) / 48.0
	var o := (size - Vector2(48, 48) * s) * 0.5
	draw_set_transform(o, 0.0, Vector2(s, s))
	var w := 3.0
	var c := col
	var dim := Color(c, 0.35)
	match kind:
		"door", "knock", "lock":
			draw_rect(Rect2(14, 8, 20, 34), Color(c, 0.12))
			draw_rect(Rect2(14, 8, 20, 34), c, false, w)
			draw_circle(Vector2(29, 26), 2.2, c)
			if kind == "knock":
				for r: float in [6.0, 11.0]:
					draw_arc(Vector2(38, 18), r, -0.9, 0.9, 8, c, 2.2)
			elif kind == "lock":
				draw_rect(Rect2(19, 22, 10, 9), c)
				draw_arc(Vector2(24, 22), 4.0, PI, TAU, 8, c, 2.4)
		"alone":
			_person(Vector2(24, 26), c, true)
			draw_arc(Vector2(24, 26), 18.0, -2.4, -0.7, 10, dim, 2.0)
		"seat", "seat_on":
			_person(Vector2(24, 26), c, kind == "seat_on")
		"people":
			_person(Vector2(16, 28), dim, true)
			_person(Vector2(32, 28), dim, true)
			_person(Vector2(24, 24), c, true)
		"fang":
			draw_arc(Vector2(24, 14), 14.0, 0.15, PI - 0.15, 12, c, w)
			draw_colored_polygon(PackedVector2Array([Vector2(14, 18), Vector2(20, 18), Vector2(17, 34)]), c)
			draw_colored_polygon(PackedVector2Array([Vector2(28, 18), Vector2(34, 18), Vector2(31, 34)]), c)
		"mimic":   # пузырь речи с чужим ртом-волной
			_bubble(c)
			draw_polyline(PackedVector2Array([Vector2(14, 20), Vector2(19, 16), Vector2(24, 20), Vector2(29, 16), Vector2(34, 20)]), c, 2.4)
			draw_circle(Vector2(24, 27), 2.0, c)
		"liar":
			_bubble(c)
			draw_line(Vector2(17, 13), Vector2(31, 27), c, w)
			draw_line(Vector2(31, 13), Vector2(17, 27), c, w)
		"skull":
			draw_circle(Vector2(24, 21), 13.0, Color(c, 0.18))
			draw_arc(Vector2(24, 21), 13.0, 0.0, TAU, 20, c, w)
			draw_rect(Rect2(17, 32, 14, 8), Color(c, 0.18))
			draw_rect(Rect2(17, 32, 14, 8), c, false, 2.4)
			draw_circle(Vector2(19, 21), 3.4, c)
			draw_circle(Vector2(29, 21), 3.4, c)
			draw_line(Vector2(22, 34), Vector2(22, 40), c, 1.8)
			draw_line(Vector2(26, 34), Vector2(26, 40), c, 1.8)
		"street", "street_ok":   # фонарный столб
			draw_line(Vector2(24, 42), Vector2(24, 14), c, w)
			draw_line(Vector2(16, 42), Vector2(32, 42), c, w)
			draw_rect(Rect2(19, 6, 10, 10), Color(c, 0.2))
			draw_rect(Rect2(19, 6, 10, 10), c, false, 2.4)
			if kind == "street_ok":
				draw_circle(Vector2(24, 11), 3.0, c)
		"safe":   # щит с галочкой
			var sh := PackedVector2Array([Vector2(24, 6), Vector2(38, 11), Vector2(36, 28), Vector2(24, 42), Vector2(12, 28), Vector2(10, 11), Vector2(24, 6)])
			draw_colored_polygon(sh, Color(c, 0.15))
			draw_polyline(sh, c, w)
			draw_polyline(PackedVector2Array([Vector2(17, 24), Vector2(22, 30), Vector2(31, 17)]), c, w)
		"claw":
			for i in range(3):
				var x := 14.0 + i * 9.0
				draw_line(Vector2(x + 6, 8), Vector2(x - 2, 40), c, w)
		"talisman", "talisman_cracked", "talisman_broken":
			var cc := Vector2(24, 24)
			draw_arc(cc, 15.0, 0.0, TAU, 24, c, w)
			draw_line(cc + Vector2(0, -15), cc + Vector2(0, 15), c, 2.2)
			draw_line(cc + Vector2(-13, -7), cc + Vector2(13, 7), c, 2.2)
			draw_line(cc + Vector2(13, -7), cc + Vector2(-13, 7), c, 2.2)
			if kind != "talisman":
				var cr := PackedVector2Array([Vector2(30, 6), Vector2(24, 18), Vector2(29, 26), Vector2(22, 42)])
				draw_polyline(cr, ThemeFactory.NIGHT, 5.0)
				if kind == "talisman_broken":
					draw_polyline(cr, ThemeFactory.BLOOD, 2.0)
		"heal":   # лист
			var leaf := PackedVector2Array([Vector2(10, 38), Vector2(14, 16), Vector2(30, 8), Vector2(40, 8), Vector2(38, 22), Vector2(28, 36), Vector2(10, 38)])
			draw_colored_polygon(leaf, Color(c, 0.2))
			draw_polyline(leaf, c, w)
			draw_line(Vector2(10, 38), Vector2(32, 16), c, 2.0)
		"tunnel":   # люк
			draw_rect(Rect2(8, 16, 32, 22), Color(c, 0.15))
			draw_rect(Rect2(8, 16, 32, 22), c, false, w)
			draw_line(Vector2(8, 27), Vector2(40, 27), c, 2.0)
			draw_circle(Vector2(32, 22), 2.4, c)
			draw_line(Vector2(24, 4), Vector2(24, 12), c, 2.4)
			draw_polyline(PackedVector2Array([Vector2(19, 8), Vector2(24, 13), Vector2(29, 8)]), c, 2.4)
		"pact":   # два сцепленных кольца
			draw_arc(Vector2(18, 24), 10.0, 0.0, TAU, 20, c, w)
			draw_arc(Vector2(30, 24), 10.0, 0.0, TAU, 20, c, w)
		"fog":
			for i in range(4):
				var y := 12.0 + i * 8.0
				var pts := PackedVector2Array()
				for k in range(9):
					pts.append(Vector2(8 + k * 4, y + sin(k * 1.4 + i) * 2.4))
				draw_polyline(pts, c if i % 2 == 0 else dim, 2.6)
		"moon":
			draw_circle(Vector2(24, 24), 15.0, Color(c, 0.25))
			draw_arc(Vector2(24, 24), 15.0, 0.0, TAU, 24, c, w)
			draw_circle(Vector2(19, 20), 3.0, dim)
			draw_circle(Vector2(29, 29), 2.2, dim)
		"quiet":   # полумесяц и «z»
			draw_arc(Vector2(20, 26), 14.0, 0.8, 5.5, 20, c, w)
			draw_polyline(PackedVector2Array([Vector2(30, 10), Vector2(40, 10), Vector2(30, 20), Vector2(40, 20)]), c, 2.4)
		"rain":
			for i in range(3):
				var x := 14.0 + i * 10.0
				var top := 10.0 + (i % 2) * 8.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + 4, top + 10), Vector2(x, top + 14), Vector2(x - 4, top + 10)]), c)
		"bell":
			var b := PackedVector2Array([Vector2(14, 34), Vector2(16, 18), Vector2(24, 9), Vector2(32, 18), Vector2(34, 34), Vector2(14, 34)])
			draw_colored_polygon(b, Color(c, 0.2))
			draw_polyline(b, c, w)
			draw_line(Vector2(10, 34), Vector2(38, 34), c, w)
			draw_circle(Vector2(24, 39), 3.0, c)
		"mark_eye":
			draw_set_transform(o + Vector2(24, 24) * s, 0.0, Vector2(s, s) * 1.6)
			VillagerFigure.paint_eye(self, Vector2.ZERO, 3)
		"mark_pact":
			draw_set_transform(o + Vector2(24, 30) * s, 0.0, Vector2(s, s) * 1.25)
			VillagerFigure.paint_pact(self, Vector2.ZERO)
		"mark_street", "mark_liar", "mark_death", "mark_fake", "mark_tunnel", "mark_sabotage":
			draw_set_transform(o + Vector2(24, 24) * s, 0.0, Vector2(s, s) * 1.7)
			VillagerFigure.paint_badge(self, kind.substr(5), Vector2.ZERO)
		"info":
			draw_arc(Vector2(24, 24), 16.0, 0.0, TAU, 24, c, 2.6)
			draw_circle(Vector2(24, 15), 2.6, c)
			draw_line(Vector2(24, 21), Vector2(24, 34), c, 3.4)
	draw_set_transform(Vector2.ZERO)


## Человечек: голова и плечи. filled — сплошной, иначе контур (свободное место).
func _person(at: Vector2, c: Color, filled: bool) -> void:
	var head := at + Vector2(0, -9)
	var shoulders := PackedVector2Array([at + Vector2(-11, 14), at + Vector2(-10, 4), at + Vector2(-5, 0), at + Vector2(5, 0), at + Vector2(10, 4), at + Vector2(11, 14)])
	if filled:
		draw_circle(head, 7.0, c)
		draw_colored_polygon(shoulders, c)
	else:
		draw_arc(head, 7.0, 0.0, TAU, 16, c, 2.4)
		var closed := shoulders.duplicate()
		closed.append(shoulders[0])
		draw_polyline(closed, c, 2.4)


func _bubble(c: Color) -> void:
	var r := Rect2(8, 6, 32, 28)
	draw_rect(r, Color(c, 0.15))
	draw_rect(r, c, false, 2.6)
	draw_colored_polygon(PackedVector2Array([Vector2(14, 34), Vector2(22, 34), Vector2(12, 42)]), c)
