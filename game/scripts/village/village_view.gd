class_name VillageView
extends Node2D
## Игровое поле: посёлок, нарисованный кодом. Ни одной картинки.
## Статика (небо, дома, площадь) перерисовывается только при смене дня и ночи.
## Живое — туман, пыль, мерцание фонарей — частицы и свечение, без перерисовки.

const LOGICAL := Vector2(720, 600)
const BAND := Rect2(0, 120, 720, 400)    ## полоса с домами — её кадрирует камера

var def: VillageDef
var open_count: int = 2
var titles: PackedStringArray = []
var night: float = 1.0: set = set_night
var draws: int = 0                         ## счётчик перерисовок — для самотеста
var crowd: Crowd

var _font: Font
var _fog: CPUParticles2D
var _dust: CPUParticles2D
var _lamp_glows: Array[Sprite2D] = []
var _house_glows: Array[Sprite2D] = []
var _stones: PackedVector3Array = PackedVector3Array()
var _trees: PackedVector2Array = PackedVector2Array()
var _tw_frame: Tween
var _tw_night: Tween
var _t: float = 0.0


func setup(village: VillageDef, open: int, names: PackedStringArray) -> void:
	def = village
	titles = names
	_font = load("res://fonts/UI.ttf")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_build_trees(rng)
	_build_stones(rng)
	_build_particles()
	crowd = Crowd.new()
	crowd.view = self
	crowd.book = load("res://config/looks.tres") as LookBook
	add_child(crowd)
	set_open_count(open)


func set_open_count(n: int) -> void:
	open_count = clampi(n, 1, def.shelters.size())
	_build_glows()
	queue_redraw()


func open_shelters() -> int:
	return open_count


func boarded_shelters() -> int:
	return def.shelters.size() - open_count


func set_night(v: float) -> void:
	night = clampf(v, 0.0, 1.0)
	if _fog != null:
		_fog.modulate.a = 0.35 + 0.65 * night
		_dust.modulate.a = 0.12 + 0.88 * (1.0 - night)
	if crowd != null:
		crowd.modulate = Color(1, 1, 1).lerp(Color(0.6, 0.65, 0.76), night)
	queue_redraw()


func set_mood(v: float, dur: float) -> void:
	if _tw_night != null:
		_tw_night.kill()
	if dur <= 0.0:
		set_night(v)
		return
	_tw_night = create_tween().set_trans(Tween.TRANS_SINE)
	_tw_night.tween_property(self, "night", v, dur)


## Вписать полосу с домами в прямоугольник поля. vp_w — ширина экрана.
func frame_to(rect: Rect2, vp_w: float, dur: float) -> void:
	var s := minf(vp_w / LOGICAL.x, rect.size.y / BAND.size.y)
	s = maxf(s, 0.5)
	var target := Vector2(vp_w * 0.5 - LOGICAL.x * 0.5 * s,
		rect.position.y + rect.size.y * 0.5 - (BAND.position.y + BAND.size.y * 0.5) * s)
	if _tw_frame != null:
		_tw_frame.kill()
	if dur <= 0.0:
		position = target
		scale = Vector2(s, s)
		return
	_tw_frame = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_frame.tween_property(self, "position", target, dur)
	_tw_frame.tween_property(self, "scale", Vector2(s, s), dur)


func band_global_rect() -> Rect2:
	return Rect2(to_global(BAND.position), BAND.size * scale)


func _process(delta: float) -> void:
	_t += delta
	for i in range(_lamp_glows.size()):
		var g := _lamp_glows[i]
		var base: float = 0.02 + 0.24 * night
		g.modulate.a = base * (0.88 + 0.12 * sin(_t * 7.3 + i * 1.9) * sin(_t * 3.1 + i))
	for g: Sprite2D in _house_glows:
		g.modulate.a = 0.28 * night


# =============================================================
# Рисование
# =============================================================
func _draw() -> void:
	if def == null:
		return
	draws += 1
	var n := night

	# небо до горизонта
	_vgrad(Rect2(-2000, -2400, 4720, 2590), Color("2f3e44").lerp(Color("091114"), n), Color("4d5d62").lerp(Color("16232a"), n))
	# луна ночью, бледный диск днём
	var moon := Vector2(568, 70)
	for i in range(4):
		draw_circle(moon, 30.0 + i * 16.0, Color(0.85, 0.87, 0.80, (0.05 - i * 0.011) * (0.3 + n)))
	draw_circle(moon, 24.0, Color(0.86, 0.87, 0.80, 0.18 + 0.72 * n))
	draw_circle(moon + Vector2(-7, -5), 6.0, Color(0.70, 0.72, 0.66, 0.25 * n))
	# лес на горизонте
	draw_colored_polygon(_trees, Color("101a1e").lerp(Color("060c0e"), n))
	# земля
	draw_rect(Rect2(-2000, 188, 4720, 3200), Color("2a353a").lerp(Color("10191d"), n))
	if def.river:
		_draw_river(n)
	_draw_square(n)

	# дома: дальние раньше ближних
	var items: Array = []
	for h: HouseDef in def.decor:
		items.append([h, 0])
	for i in range(def.shelters.size()):
		items.append([def.shelters[i], 1 if i < open_count else 2])
	items.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as HouseDef).pos.y < (b[0] as HouseDef).pos.y)
	for it: Array in items:
		var h: HouseDef = it[0]
		if h.pos.y > def.well.y:
			continue
		_draw_house(h, it[1], n)
	_draw_well(n)
	for p: Vector2 in def.lamps:
		_draw_lamp_post(p, n)
	for it: Array in items:
		var h: HouseDef = it[0]
		if h.pos.y <= def.well.y:
			continue
		_draw_house(h, it[1], n)
	_draw_fences(n)

	# подписи открытых убежищ
	for i in range(open_count):
		var h: HouseDef = def.shelters[i]
		var label: String = titles[i] if i < titles.size() else h.title
		var y := h.pos.y + 24.0
		draw_string(_font, Vector2(h.pos.x - 90, y + 1), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 17, Color(0, 0, 0, 0.6))
		draw_string(_font, Vector2(h.pos.x - 90, y), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 17, Color(ThemeFactory.BONE, 0.92))


func _draw_river(n: float) -> void:
	var pts := PackedVector2Array([Vector2(-600, 214), Vector2(52, 214), Vector2(84, 262), Vector2(58, 330),
		Vector2(96, 410), Vector2(64, 520), Vector2(102, 900), Vector2(-600, 900)])
	var bank := PackedVector2Array()
	for p: Vector2 in pts:
		bank.append(p + (Vector2(9, 0) if p.x > 0.0 else Vector2.ZERO))
	draw_colored_polygon(bank, Color("3b4636").lerp(Color("182019"), n))
	draw_colored_polygon(pts, Color("456674").lerp(Color("132a35"), n))
	var shine := Color(0.80, 0.88, 0.92, 0.16 + 0.10 * n)
	for y in [246, 302, 368, 432, 494]:
		var x: float = 22.0 + 14.0 * sin(y * 0.05)
		draw_line(Vector2(x - 18, y), Vector2(x + 12, y), shine, 2.0)


func _draw_square(n: float) -> void:
	var c := def.square_center
	draw_colored_polygon(_ellipse(c, def.square_radii + Vector2(10, 6)), Color("323e43").lerp(Color("141e22"), n))
	draw_colored_polygon(_ellipse(c, def.square_radii), Color("3a464b").lerp(Color("19242a"), n))
	var stone := Color("47545a").lerp(Color("223038"), n)
	for s: Vector3 in _stones:
		draw_colored_polygon(_ellipse(Vector2(s.x, s.y), Vector2(s.z, s.z * 0.45), 10), stone)
	# дорожки к убежищам
	var path := Color("33403f").lerp(Color("172126"), n)
	for i in range(def.shelters.size()):
		var h: HouseDef = def.shelters[i]
		var dir := (h.pos - c).normalized()
		var a := c + Vector2(dir.x * def.square_radii.x, dir.y * def.square_radii.y) * 0.92
		draw_line(a, h.pos + Vector2(0, 2), path, 16.0)


func _draw_house(h: HouseDef, state: int, n: float) -> void:
	var w := h.size.x
	var hh := h.size.y
	var x0 := h.pos.x - w * 0.5
	var top := h.pos.y - hh
	var wall := Color("2a3940").lerp(Color("172228"), n)
	var edge := Color("41535a").lerp(Color("27373e"), n)
	var roof := Color("1d282d").lerp(Color("0d1518"), n)
	var wood := Color("4a3729").lerp(Color("2a1f18"), n)
	var lit := state == 1
	var win := Color("1b262b").lerp(ThemeFactory.LAMP, n * 0.92) if lit else (Color("1b262b").lerp(Color(ThemeFactory.LAMP_D, 1.0), n * 0.35) if state == 0 else Color("0f1619"))

	# тень дома на земле
	draw_colored_polygon(_ellipse(h.pos + Vector2(0, 3), Vector2(w * 0.62, 9)), Color(0, 0, 0, 0.28))

	match h.kind:
		HouseDef.Kind.CELLAR:
			draw_colored_polygon(_half_ellipse(h.pos, Vector2(w * 0.5, hh)), Color("27352f").lerp(Color("111a17"), n))
			draw_polyline(_half_ellipse(h.pos, Vector2(w * 0.5, hh)), edge, 2.0)
			var dw := w * 0.3
			var dr := Rect2(h.pos.x - dw * 0.5, h.pos.y - hh * 0.62, dw, hh * 0.62)
			draw_rect(dr.grow(4), Color("3a3027").lerp(Color("1d1712"), n))
			draw_rect(dr, wood if lit else wood.darkened(0.3))
			draw_line(Vector2(h.pos.x + w * 0.28, h.pos.y - hh * 0.82), Vector2(h.pos.x + w * 0.28, h.pos.y - hh * 1.12), edge, 4.0)
			_mark_door(dr, state, n)
			if lit:
				_door_light(dr, n)
			return
		HouseDef.Kind.GARAGE:
			draw_rect(Rect2(x0, top, w, hh), wall)
			draw_rect(Rect2(x0 - 6, top - 9, w + 12, 10), roof)
			var dr2 := Rect2(h.pos.x - w * 0.3, top + hh * 0.28, w * 0.6, hh * 0.72)
			draw_rect(dr2, Color("2c3639").lerp(Color("161e21"), n))
			for k in range(1, 6):
				var yy := dr2.position.y + dr2.size.y * k / 6.0
				draw_line(Vector2(dr2.position.x, yy), Vector2(dr2.end.x, yy), edge, 1.5)
			draw_rect(Rect2(x0 + w * 0.06, top + hh * 0.3, w * 0.1, hh * 0.22), win)
			draw_rect(Rect2(x0, top, w, hh), edge, false, 2.0)
			_mark_door(dr2, state, n)
			if lit:
				_door_light(dr2, n)
			return
		_:
			pass

	# стены
	draw_rect(Rect2(x0, top, w, hh), wall)
	# крыша
	var roof_pts: PackedVector2Array
	match h.kind:
		HouseDef.Kind.BARN:
			roof_pts = PackedVector2Array([Vector2(x0 - 8, top), Vector2(x0 + w * 0.12, top - hh * 0.36),
				Vector2(h.pos.x, top - hh * 0.56), Vector2(x0 + w * 0.88, top - hh * 0.36), Vector2(x0 + w + 8, top)])
		HouseDef.Kind.CHURCH:
			roof_pts = PackedVector2Array([Vector2(x0 - 6, top), Vector2(h.pos.x, top - hh * 0.62), Vector2(x0 + w + 6, top)])
		HouseDef.Kind.SHED:
			roof_pts = PackedVector2Array([Vector2(x0 - 6, top + 6), Vector2(x0 - 6, top - hh * 0.28), Vector2(x0 + w + 6, top - 2), Vector2(x0 + w + 6, top + 6)])
		_:
			roof_pts = PackedVector2Array([Vector2(x0 - 9, top), Vector2(h.pos.x, top - hh * 0.58), Vector2(x0 + w + 9, top)])
	draw_colored_polygon(roof_pts, roof)
	draw_polyline(roof_pts, edge, 2.0)

	if h.kind == HouseDef.Kind.CHURCH:
		_draw_dome(h, top, roof, edge, n)
	if h.kind == HouseDef.Kind.HOME:
		draw_rect(Rect2(x0 + w * 0.68, top - hh * 0.5, w * 0.1, hh * 0.32), roof)

	# окна
	var ws := w * 0.16
	var wy := top + hh * 0.24
	match h.kind:
		HouseDef.Kind.BARN:
			draw_rect(Rect2(h.pos.x - ws * 0.4, top - hh * 0.22, ws * 0.8, ws * 0.6), win)
		HouseDef.Kind.CHURCH:
			for xx in [x0 + w * 0.16, x0 + w * 0.84 - ws * 0.7]:
				draw_rect(Rect2(xx, wy, ws * 0.7, hh * 0.3), win)
				draw_circle(Vector2(xx + ws * 0.35, wy), ws * 0.35, win)
		HouseDef.Kind.SHED:
			pass
		_:
			for xx in [x0 + w * 0.1, x0 + w * 0.9 - ws]:
				draw_rect(Rect2(xx, wy, ws, ws), win)
				draw_line(Vector2(xx + ws * 0.5, wy), Vector2(xx + ws * 0.5, wy + ws), wall, 2.0)
				if state == 2:
					_planks(Rect2(xx, wy, ws, ws), wood)

	# дверь
	var dw2 := w * (0.42 if h.kind == HouseDef.Kind.BARN else 0.22)
	var dh := hh * (0.66 if h.kind == HouseDef.Kind.BARN else 0.52)
	var dr3 := Rect2(h.pos.x - dw2 * 0.5, h.pos.y - dh, dw2, dh)
	draw_rect(dr3, wood if state != 2 else wood.darkened(0.35))
	if h.kind == HouseDef.Kind.BARN:
		draw_line(dr3.position, dr3.end, wood.darkened(0.4), 3.0)
		draw_line(Vector2(dr3.end.x, dr3.position.y), Vector2(dr3.position.x, dr3.end.y), wood.darkened(0.4), 3.0)
		draw_line(Vector2(h.pos.x, dr3.position.y), Vector2(h.pos.x, dr3.end.y), wood.darkened(0.5), 2.0)
	if h.kind == HouseDef.Kind.CHURCH:
		draw_circle(Vector2(h.pos.x, dr3.position.y), dw2 * 0.5, wood if state != 2 else wood.darkened(0.35))
	draw_rect(Rect2(x0, top, w, hh), edge, false, 2.0)
	_mark_door(dr3, state, n)
	if lit:
		_door_light(dr3, n)


func _draw_dome(h: HouseDef, top: float, roof: Color, edge: Color, n: float) -> void:
	var tw := h.size.x * 0.3
	var base_y := top - h.size.y * 0.5
	var tower := Rect2(h.pos.x - tw * 0.5, base_y - h.size.y * 0.42, tw, h.size.y * 0.46)
	draw_rect(tower, roof.lightened(0.06))
	draw_rect(tower, edge, false, 2.0)
	# луковка: правый профиль снизу вверх до острия, затем зеркально вниз — простой многоугольник
	var dy := tower.position.y
	var r := tw * 0.62
	var prof: Array[Vector2] = [Vector2(0.42, 0.0), Vector2(0.80, -0.22), Vector2(1.0, -0.52),
		Vector2(0.92, -0.84), Vector2(0.62, -1.16), Vector2(0.28, -1.42), Vector2(0.0, -1.72)]
	var pts := PackedVector2Array()
	for q: Vector2 in prof:
		pts.append(Vector2(h.pos.x + q.x * r, dy + q.y * r))
	for i in range(prof.size() - 2, -1, -1):
		pts.append(Vector2(h.pos.x - prof[i].x * r, dy + prof[i].y * r))
	draw_colored_polygon(pts, Color("44555b").lerp(Color("1e2b30"), n))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, edge, 2.0)
	var tip := dy - 1.72 * r
	draw_line(Vector2(h.pos.x, tip), Vector2(h.pos.x, tip - r * 0.9), edge, 2.5)
	draw_line(Vector2(h.pos.x - 7, tip - r * 0.6), Vector2(h.pos.x + 7, tip - r * 0.6), edge, 2.5)


## Открытое убежище — тёплая рамка двери. Заколоченное — доски крест-накрест.
func _mark_door(dr: Rect2, state: int, n: float) -> void:
	if state == 1:
		draw_rect(dr.grow(2), Color(ThemeFactory.LAMP_D, 0.55 + 0.4 * n), false, 2.0)
	elif state == 2:
		_planks(dr.grow(3), Color("5a4532").lerp(Color("33261c"), n))


func _door_light(dr: Rect2, n: float) -> void:
	if n < 0.2:
		return
	draw_line(Vector2(dr.position.x + 3, dr.end.y - 1), Vector2(dr.end.x - 3, dr.end.y - 1), Color(ThemeFactory.LAMP, 0.85 * n), 2.0)
	draw_line(Vector2(dr.position.x + dr.size.x * 0.5, dr.position.y + 4), Vector2(dr.position.x + dr.size.x * 0.5, dr.end.y - 3), Color(ThemeFactory.LAMP, 0.55 * n), 2.0)


func _planks(r: Rect2, c: Color) -> void:
	draw_line(r.position + Vector2(-3, 4), r.end + Vector2(3, -4), c, 5.0)
	draw_line(Vector2(r.end.x + 3, r.position.y + 4), Vector2(r.position.x - 3, r.end.y - 4), c, 5.0)


func _draw_well(n: float) -> void:
	var p := def.well
	var stone := Color("4a565b").lerp(Color("25313a"), n)
	draw_colored_polygon(_ellipse(p + Vector2(0, 4), Vector2(30, 11)), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(p.x - 26, p.y - 22, 52, 22), stone)
	draw_colored_polygon(_ellipse(p - Vector2(0, 22), Vector2(26, 9)), stone.lightened(0.08))
	draw_colored_polygon(_ellipse(p - Vector2(0, 22), Vector2(18, 5.5)), Color("0a1114"))
	var post := Color("4a3729").lerp(Color("2a1f18"), n)
	draw_line(Vector2(p.x - 22, p.y - 22), Vector2(p.x - 22, p.y - 64), post, 4.0)
	draw_line(Vector2(p.x + 22, p.y - 22), Vector2(p.x + 22, p.y - 64), post, 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - 34, p.y - 60), Vector2(p.x, p.y - 82), Vector2(p.x + 34, p.y - 60)]),
		Color("1d282d").lerp(Color("0d1518"), n))


func _draw_lamp_post(p: Vector2, n: float) -> void:
	var post := Color("3a464b").lerp(Color("1d282d"), n)
	draw_colored_polygon(_ellipse(p + Vector2(0, 2), Vector2(10, 4)), Color(0, 0, 0, 0.3))
	draw_line(p, p - Vector2(0, 76), post, 4.0)
	draw_line(p - Vector2(0, 72), p - Vector2(-12, 72), post, 3.0)
	draw_rect(Rect2(p.x + 6, p.y - 72, 12, 14), post)
	draw_rect(Rect2(p.x + 8, p.y - 70, 8, 10), Color(0.30, 0.30, 0.28).lerp(ThemeFactory.LAMP, 0.25 + 0.75 * n))


func _draw_fences(n: float) -> void:
	var c := Color("3a3229").lerp(Color("1f1a15"), n)
	for row: Array in [[Vector2(18, 560), 9], [Vector2(612, 560), 9]]:
		var o: Vector2 = row[0]
		for i in range(int(row[1])):
			var x := o.x + i * 11.0
			draw_line(Vector2(x, o.y), Vector2(x, o.y - 26), c, 3.0)
		draw_line(Vector2(o.x - 3, o.y - 17), Vector2(o.x + int(row[1]) * 11.0 - 8, o.y - 17), c, 2.5)


# =============================================================
# Подготовка
# =============================================================
func _build_trees(rng: RandomNumberGenerator) -> void:
	_trees = PackedVector2Array([Vector2(-900, 200)])
	var x := -900.0
	while x < 1620.0:
		var h := rng.randf_range(16, 46)
		_trees.append(Vector2(x + 10, 192 - h * 0.45))
		_trees.append(Vector2(x + 20, 192 - h))
		_trees.append(Vector2(x + 30, 192 - h * 0.45))
		x += rng.randf_range(22, 38)
	_trees.append(Vector2(1620, 200))


func _build_stones(rng: RandomNumberGenerator) -> void:
	_stones = PackedVector3Array()
	var c := def.square_center
	var r := def.square_radii
	var tries := 0
	while _stones.size() < 80 and tries < 2000:
		tries += 1
		var p := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if p.length() > 0.93:
			continue
		var pos := c + Vector2(p.x * r.x, p.y * r.y)
		if pos.distance_to(def.well) < 40.0:
			continue
		_stones.append(Vector3(pos.x, pos.y, rng.randf_range(6, 11)))


func _soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	return t


func _build_glows() -> void:
	for g in _lamp_glows + _house_glows:
		g.queue_free()
	_lamp_glows.clear()
	_house_glows.clear()
	var tex := _soft_texture()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for p: Vector2 in def.lamps:
		var s := Sprite2D.new()
		s.texture = tex
		s.material = add
		s.position = p - Vector2(-12, 65)
		s.scale = Vector2(2.1, 2.1)
		s.modulate = Color(ThemeFactory.LAMP, 0.0)
		add_child(s)
		_lamp_glows.append(s)
	for i in range(open_count):
		var h: HouseDef = def.shelters[i]
		var s := Sprite2D.new()
		s.texture = tex
		s.material = add
		s.position = h.pos - Vector2(0, h.size.y * 0.45)
		s.scale = Vector2(h.size.x / 60.0, h.size.y / 70.0)
		s.modulate = Color(ThemeFactory.LAMP, 0.0)
		add_child(s)
		_house_glows.append(s)


func _build_particles() -> void:
	var tex := _soft_texture()
	_fog = CPUParticles2D.new()
	_fog.texture = tex
	_fog.amount = 14
	_fog.lifetime = 22.0
	_fog.preprocess = 22.0
	_fog.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fog.emission_rect_extents = Vector2(520, 90)
	_fog.position = Vector2(360, 420)
	_fog.direction = Vector2(1, 0)
	_fog.spread = 8.0
	_fog.gravity = Vector2.ZERO
	_fog.initial_velocity_min = 5.0
	_fog.initial_velocity_max = 13.0
	_fog.scale_amount_min = 3.2
	_fog.scale_amount_max = 5.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.86, 0.90, 0.0))
	ramp.add_point(0.3, Color(0.78, 0.86, 0.90, 0.09))
	ramp.add_point(0.7, Color(0.78, 0.86, 0.90, 0.09))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.78, 0.86, 0.90, 0.0))
	_fog.color_ramp = ramp
	add_child(_fog)

	_dust = CPUParticles2D.new()
	_dust.texture = tex
	_dust.amount = 24
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(330, 120)
	_dust.position = Vector2(360, 360)
	_dust.direction = Vector2(0, -1)
	_dust.spread = 70.0
	_dust.gravity = Vector2(0, -3)
	_dust.initial_velocity_min = 2.0
	_dust.initial_velocity_max = 7.0
	_dust.scale_amount_min = 0.04
	_dust.scale_amount_max = 0.09
	var dr := Gradient.new()
	dr.set_color(0, Color(1.0, 0.92, 0.75, 0.0))
	dr.add_point(0.5, Color(1.0, 0.92, 0.75, 0.55))
	dr.set_color(dr.get_point_count() - 1, Color(1.0, 0.92, 0.75, 0.0))
	_dust.color_ramp = dr
	add_child(_dust)
	set_night(night)


func fog() -> CPUParticles2D:
	return _fog


func dust() -> CPUParticles2D:
	return _dust


# =============================================================
func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _ellipse(c: Vector2, r: Vector2, seg: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _half_ellipse(base: Vector2, r: Vector2, seg: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg + 1):
		var a := PI * i / seg
		pts.append(base + Vector2(cos(a) * r.x, -sin(a) * r.y))
	return pts
