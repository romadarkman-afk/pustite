class_name VillageView
extends Node2D
## Игровое поле: посёлок, нарисованный кодом. Ни одной картинки.
## Статика (небо, дома, площадь) перерисовывается только при смене дня и ночи.
## Живое — туман, пыль, мерцание фонарей — частицы и свечение, без перерисовки.

const LOGICAL := Vector2(720, 600)
const BAND := Rect2(0, 120, 720, 400)    ## полоса с домами — её кадрирует камера
## Сколько ширины посёлка обязано войти в кадр. По краям только фоновые дома и река —
## их можно подрезать, а фигурки от этого крупнее.
const SIDE_VISIBLE := 0.88
const SKY_SHARE := 0.75                   ## какая доля лишней высоты поля уходит в небо
const SAFE_X := Vector2(84, 624)          ## куда можно ставить жителей: слева половина имени, справа колонка отметок

var def: VillageDef
var open_count: int = 2
var titles: PackedStringArray = []
var night: float = 1.0: set = set_night
var draws: int = 0                         ## счётчик перерисовок — для самотеста
var draw_usec_total: int = 0               ## суммарное время рисования, мкс — для самотеста
var crowd: Crowd
var eyes: Eyes
var selected_house: int = -1               ## ночью: дом, который выбрал игрок
var show_going: bool = false               ## ночью: на табличках число тех, кто туда идёт
var house_going: PackedInt32Array = PackedInt32Array()
var _q: float = -1.0                       ## ночь, с которой посёлок нарисован (ступеньками по 0.025)
var _light_th: Dictionary = {}             ## дом -> порог, с которого загораются его окна
var _lamp_th: PackedFloat32Array = PackedFloat32Array()

var _font: Font
var _fog: CPUParticles2D
var _dust: CPUParticles2D
var _lamp_glows: Array[Sprite2D] = []
var _house_glows: Array[Sprite2D] = []
var _stones: PackedVector3Array = PackedVector3Array()
var _tree_spots: PackedVector3Array = PackedVector3Array()
var _grass: PackedVector2Array = PackedVector2Array()
var _lamp_lights: Array[PointLight2D] = []

## Камера. Днём приближена и следует за игроком по горизонтали; в остальных фазах
## показывает посёлок целиком. Двигается только узел: посёлок от этого не перерисовывается.
var follow: Node2D                         ## за кем следит камера; null — стоит на месте
var cam_x: float = 360.0                   ## какая точка посёлка по горизонтали в центре кадра
var _vp_w: float = 720.0
var _framing := false                      ## идёт переход кадра — камера не дёргается
var lamps_fueled: int = 99                 ## сколько фонарей заправлено на эту ночь
var jobs_layer: JobLayer
var _tw_frame: Tween
var _tw_night: Tween
var _t: float = 0.0


func setup(village: VillageDef, open: int, names: PackedStringArray) -> void:
	def = village
	titles = names
	_font = ThemeFactory.font_bold()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_build_trees(rng)
	_build_stones(rng)
	_build_particles()
	_build_thresholds()
	_build_lights()
	eyes = Eyes.new()
	add_child(eyes)
	crowd = Crowd.new()
	crowd.view = self
	crowd.book = load("res://config/looks.tres") as LookBook
	add_child(crowd)
	jobs_layer = JobLayer.new()
	jobs_layer.view = self
	jobs_layer.visible = false
	add_child(jobs_layer)
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
		crowd.modulate = Color(1, 1, 1).lerp(Color(0.62, 0.64, 0.86), night)
		crowd.set_night(night)
	if eyes != null:
		eyes.night = night
	# статика перерисовывается ступеньками: сумерки плавные, а кадры не проседают
	var q := snappedf(night, 0.025)
	if q != _q:
		_q = q
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
## Кадрировать поле в прямоугольник экрана rect. zoom > 1 — приблизить посёлок
## (по высоте он всё равно поместится в поле), камера встаёт на focus_x.
func frame_to(rect: Rect2, vp_w: float, dur: float, zoom: float = 1.0, focus_x: float = -1.0) -> void:
	var base := minf(vp_w / (LOGICAL.x * SIDE_VISIBLE), rect.size.y / BAND.size.y)
	var s := minf(base * zoom, rect.size.y / BAND.size.y)
	s = maxf(s, 0.5)
	_vp_w = vp_w
	if focus_x >= 0.0:
		cam_x = focus_x
	elif zoom <= 1.0:
		cam_x = LOGICAL.x * 0.5
	cam_x = _clamp_cam(cam_x, s)
	# поле выше полосы с домами: лишнее место уходит в основном в небо (3/4 сверху),
	# а не в пустую траву под толпой
	var extra := maxf(0.0, rect.size.y - BAND.size.y * s)
	var target := Vector2(vp_w * 0.5 - cam_x * s, rect.position.y + extra * SKY_SHARE - BAND.position.y * s)
	if _tw_frame != null:
		_tw_frame.kill()
	if dur <= 0.0:
		position = target
		scale = Vector2(s, s)
		_framing = false
		return
	_framing = true
	_tw_frame = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_frame.tween_property(self, "position", target, dur)
	_tw_frame.tween_property(self, "scale", Vector2(s, s), dur)
	_tw_frame.chain().tween_callback(func() -> void: _framing = false)


## Центр кадра не уводит камеру за края посёлка.
func _clamp_cam(x: float, s: float) -> float:
	var half := _vp_w / (2.0 * s)
	var lo := half - 20.0
	var hi := LOGICAL.x - half + 20.0
	if lo >= hi:
		return LOGICAL.x * 0.5
	return clampf(x, lo, hi)


## Камера мягко догоняет того, за кем следит.
func _follow_step(delta: float) -> void:
	if follow == null or not is_instance_valid(follow) or _framing:
		return
	var want := _clamp_cam(follow.position.x, scale.x)
	if absf(want - cam_x) < 0.05:
		return
	cam_x = want if Juice.instant else lerpf(cam_x, want, 1.0 - exp(-5.0 * delta))
	position.x = _vp_w * 0.5 - cam_x * scale.x


## Ночью горит столько фонарей, сколько заправили днём.
func set_lamps_fueled(n: int) -> void:
	if n != lamps_fueled:
		lamps_fueled = n
		queue_redraw()


func _lamp_fuel(i: int) -> float:
	return 1.0 if i < lamps_fueled else 0.0


func set_selected_house(i: int) -> void:
	selected_house = i
	queue_redraw()


func set_house_going(counts: PackedInt32Array, on: bool) -> void:
	house_going = counts
	show_going = on
	queue_redraw()


## Дом под пальцем: открытое убежище, в чью зону касания попала точка. -1 — мимо.
func house_at(global_pos: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in range(open_count):
		var r := house_hit_rect_global(i)
		if r.has_point(global_pos):
			var d := r.get_center().distance_to(global_pos)
			if d < best_d:
				best_d = d
				best = i
	return best


## Зона касания дома в координатах экрана: дом с крышей, не меньше 84×84 px.
func house_hit_rect_global(i: int) -> Rect2:
	var h: HouseDef = def.shelters[i]
	var lr := Rect2(h.pos.x - h.size.x * 0.5, h.pos.y - h.size.y * 1.5, h.size.x, h.size.y * 1.5)
	var g := Rect2(to_global(lr.position), lr.size * scale)
	var grow := Vector2(maxf(0.0, (84.0 - g.size.x) * 0.5), maxf(0.0, (84.0 - g.size.y) * 0.5))
	return g.grow_individual(grow.x, grow.y, grow.x, grow.y)


## Сколько окон уже горит (дома с огнём не меньше половины) — для самотеста сумерек.
func lit_count() -> int:
	var n := 0
	for h: HouseDef in _light_th:
		if _lit(h, night) >= 0.5:
			n += 1
	return n


func lights_total() -> int:
	return _light_th.size()


func band_global_rect() -> Rect2:
	return Rect2(to_global(BAND.position), BAND.size * scale)


func _process(delta: float) -> void:
	_follow_step(delta)
	_t += delta
	for i in range(_lamp_lights.size()):
		var on_l := _lamp_on(i, night) * _lamp_fuel(i)
		_lamp_lights[i].visible = on_l > 0.01
		_lamp_lights[i].energy = 0.9 * on_l
	for i in range(_lamp_glows.size()):
		var g := _lamp_glows[i]
		var on := _lamp_on(i, night) * _lamp_fuel(i)
		var flick := 0.88 + 0.12 * sin(_t * 7.3 + i * 1.9) * sin(_t * 3.1 + i)
		if on > 0.0 and on < 1.0 and randf() < 0.35:
			flick *= 0.15               # включение: лампа пару раз мигает
		g.modulate.a = (0.02 + 0.24 * on) * flick
	for i in range(_house_glows.size()):
		var lit := _lit(def.shelters[i], night) if i < def.shelters.size() else night
		_house_glows[i].modulate.a = (0.28 + (0.22 if i == selected_house else 0.0)) * lit


# =============================================================
# Рисование
# =============================================================
const SHELTER_PALS := [
	{"wall": Color("f2b880"), "wall_d": Color("d8955e"), "roof": Color("c9573f")},
	{"wall": Color("d9674f"), "wall_d": Color("b54d38"), "roof": Color("7a3b2e")},
	{"wall": Color("f6dfa4"), "wall_d": Color("dcbf7c"), "roof": Color("8e5a9e")},
	{"wall": Color("7fae68"), "wall_d": Color("5f8c4c"), "roof": Color("5f8c4c")},
	{"wall": Color("9fd0c7"), "wall_d": Color("78ada3"), "roof": Color("5b6fb3")},
]
const DECOR_PALS := [
	{"wall": Color("c7b4e0"), "wall_d": Color("a58fc4"), "roof": Color("5b6fb3")},
	{"wall": Color("f2d0a9"), "wall_d": Color("d6ad80"), "roof": Color("b8574a")},
	{"wall": Color("b9dfb0"), "wall_d": Color("93c088"), "roof": Color("6b8e5a")},
	{"wall": Color("f5c4b8"), "wall_d": Color("dba293"), "roof": Color("8a5a9e")},
]


func _draw() -> void:
	if def == null:
		return
	draws += 1
	var t0 := Time.get_ticks_usec()
	var n := _q if _q >= 0.0 else night
	var k := Art.ink(n)

	# небо: день — голубое с облаками и солнцем; ночь — лиловое со звёздами и луной
	var sky_top := Color("4fb0e0").lerp(Color("0b0a24"), n)
	draw_rect(Rect2(-2000, -2400, 4720, 2000), sky_top)
	Art.vgrad(self, Rect2(-2000, -400, 4720, 600), sky_top, Color("ffe0b8").lerp(Color("33285a"), n))
	if n < 0.95:
		Art.glow(self, Vector2(590, -60), 130, Color(1.0, 0.95, 0.7, 0.9 * (1.0 - n)))
		draw_circle(Vector2(590, -60), 32, Color(1.0, 0.96, 0.77, 1.0 - n))
	if n > 0.05:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in range(70):
			var sp := Vector2(rng.randf_range(-200, 920), rng.randf_range(-380, 150))
			draw_circle(sp, rng.randf_range(0.7, 1.8), Color(1, 1, 1, rng.randf_range(0.4, 0.95) * n))
		var mc := Vector2(560, -70)
		Art.glow(self, mc, 130, Color(0.75, 0.75, 1.0, 0.7 * n))
		draw_circle(mc, 34, Color(0.95, 0.93, 0.82, n))
		for cr: Vector3 in [Vector3(-10, -7, 6), Vector3(9, 11, 4.5), Vector3(12, -13, 3.5)]:
			draw_circle(mc + Vector2(cr.x, cr.y), cr.z, Color(0.87, 0.84, 0.72, n))
	for cl: Vector3 in [Vector3(130, -150, 0.85), Vector3(420, -260, 0.7), Vector3(560, 40, 0.55), Vector3(170, 70, 0.5)]:
		var cc := Color(1, 1, 1, 0.95).lerp(Color(0.16, 0.13, 0.3, 0.85), n)
		for b: Vector3 in [Vector3(0, 0, 34), Vector3(40, 7, 26), Vector3(-36, 9, 24), Vector3(74, 14, 18), Vector3(8, -22, 24)]:
			draw_circle(Vector2(cl.x + b.x * cl.z, cl.y + b.y * cl.z), b.z * cl.z, cc)
	# холмы слоями — дальние светлее
	var hills := [Color("9ec9b4"), Color("78ad94"), Color("5b9278")]
	for li in range(3):
		var pts := PackedVector2Array([Vector2(-600, 260)])
		var x := -600.0
		while x <= 1320.0:
			pts.append(Vector2(x, 140 + li * 16 + sin(x * 0.012 + li * 1.7) * 16 + sin(x * 0.031 + li) * 6))
			x += 24.0
		pts.append(Vector2(1320, 260))
		draw_colored_polygon(pts, Art.dn(hills[li], n))
	for tp: Vector3 in _tree_spots:
		Art.tree(self, Vector2(tp.x, tp.y), tp.z, Art.dn(Color("4f8a5c"), n), k)
	# земля и трава
	Art.vgrad(self, Rect2(-2000, 186, 4720, 3200), Art.dn(Color("a7cf78"), n), Art.dn(Color("7fb35e"), n))
	var gc := Art.dn(Color("6aa04e"), n)
	for g: Vector2 in _grass:
		draw_line(g, g + Vector2(-2.5, -7), gc, 1.8, true)
		draw_line(g, g + Vector2(2.5, -8), gc, 1.8, true)
	if def.river:
		_draw_river(n, k)
	_draw_square(n, k)

	# дома: дальние раньше ближних
	var items: Array = []
	for di in range(def.decor.size()):
		items.append([def.decor[di], 0, DECOR_PALS[di % DECOR_PALS.size()]])
	for i in range(def.shelters.size()):
		items.append([def.shelters[i], 1 if i < open_count else 2, SHELTER_PALS[i % SHELTER_PALS.size()]])
	items.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as HouseDef).pos.y < (b[0] as HouseDef).pos.y)
	for it: Array in items:
		var h: HouseDef = it[0]
		if h.pos.y > def.well.y:
			continue
		Art.house(self, h.kind, h.pos, h.size.x, h.size.y, it[2], n, _lit(h, n), it[1])
	_draw_props(n, k)
	_draw_well(n, k)
	for li2 in range(def.lamps.size()):
		_draw_lamp_post(def.lamps[li2], n, _lamp_on(li2, n) * _lamp_fuel(li2))
	for it: Array in items:
		var h: HouseDef = it[0]
		if h.pos.y <= def.well.y:
			continue
		Art.house(self, h.kind, h.pos, h.size.x, h.size.y, it[2], n, _lit(h, n), it[1])
	_draw_fences(n, k)

	# выбранный ночью дом — тёплая рамка
	if selected_house >= 0 and selected_house < open_count:
		var sh: HouseDef = def.shelters[selected_house]
		var sr := Rect2(sh.pos.x - sh.size.x * 0.5, sh.pos.y - sh.size.y, sh.size.x, sh.size.y).grow(8.0)
		Art._outline(self, Art.rrect(sr, 12), ThemeFactory.LAMP, 3.5)
	# таблички открытых убежищ — капсулы на стене над дверью: очередь у двери их не закрывает
	for i in range(open_count):
		var r := shelter_label_rect_local(i)
		var sel := i == selected_house
		Art.shape(self, Art.rrect(r, r.size.y * 0.5), Color(0.08, 0.06, 0.12, 0.82), ThemeFactory.LAMP if sel else Color(1, 1, 1, 0.3), 2.0 if sel else 1.2)
		var name_w := _font.get_string_size(_title(i), HORIZONTAL_ALIGNMENT_LEFT, -1, PLAQUE_SIZE).x
		var x2 := r.position.x + 8.0
		draw_string(_font, Vector2(x2, r.end.y - 4.5), _title(i), HORIZONTAL_ALIGNMENT_LEFT, -1, PLAQUE_SIZE, Color(1, 1, 1))
		if _going_text(i) != "":
			draw_string(_font, Vector2(x2 + name_w, r.end.y - 4.5), _going_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, PLAQUE_SIZE, ThemeFactory.LAMP)
	draw_usec_total += Time.get_ticks_usec() - t0


const PLAQUE_SIZE := 14


func _title(i: int) -> String:
	return titles[i] if i < titles.size() else def.shelters[i].title


## Ночью на табличке: сколько жителей туда собирается.
func _going_text(i: int) -> String:
	if not show_going or i >= house_going.size():
		return ""
	return " · %d" % house_going[i]


## Табличка с названием убежища в координатах посёлка: верх стены, над дверью.
func shelter_label_rect_local(i: int) -> Rect2:
	var h: HouseDef = def.shelters[i]
	var w := _font.get_string_size(_title(i) + _going_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, PLAQUE_SIZE).x + 16.0
	var top := h.pos.y - h.size.y
	return Rect2(h.pos.x - w * 0.5, top + 3.0, w, 19.0)


func shelter_label_rect_global(i: int) -> Rect2:
	var r := shelter_label_rect_local(i)
	return Rect2(to_global(r.position), r.size * scale)


func _draw_river(n: float, k: Color) -> void:
	var pts := PackedVector2Array([Vector2(-600, 214), Vector2(52, 214), Vector2(84, 262), Vector2(58, 330),
		Vector2(96, 410), Vector2(64, 520), Vector2(102, 900), Vector2(-600, 900)])
	draw_colored_polygon(pts, Art.dn(Color("6fb7d9"), n))
	var o := pts.slice(1, 7)
	draw_polyline(o, Color(k, 0.6), 3.0, true)
	var shine := Color(1, 1, 1, 0.55 - 0.25 * n)
	for y in [244, 300, 366, 432, 494]:
		var x: float = 24.0 + 14.0 * sin(y * 0.05)
		draw_line(Vector2(x - 16, y), Vector2(x + 12, y), shine, 2.6, true)


func _draw_square(n: float, k: Color) -> void:
	var c := def.square_center
	Art.shape(self, Art.ellipse(c, def.square_radii, 44), Art.dn(Color("e7cf98"), n), Color(k, 0.45), 2.6)
	var stone := Art.dn(Color("d6b97c"), n)
	for st: Vector3 in _stones:
		Art.shape(self, Art.ellipse(Vector2(st.x, st.y), Vector2(st.z, st.z * 0.5), 10), stone, Color(k, 0.22), 1.2)
	var path := Art.dn(Color("e2c88f"), n)
	for i in range(def.shelters.size()):
		var h: HouseDef = def.shelters[i]
		var dir := (h.pos - c).normalized()
		var a := c + Vector2(dir.x * def.square_radii.x, dir.y * def.square_radii.y) * 0.92
		draw_line(a, h.pos + Vector2(0, 2), path, 15.0, true)


## Реквизит дел: поленница и мостки с ведром у реки. Остальные дела — у колодца,
## фонаря и оберега, которые и так стоят на карте.
func _draw_props(n: float, k: Color) -> void:
	for j: JobDef in def.jobs:
		match j.kind:
			JobDef.Kind.WOOD:
				var b := j.pos + Vector2(26, -2)
				var wood := Art.dn(Color("b07a4a"), n)
				var cut := Art.dn(Color("e8c590"), n)
				draw_colored_polygon(Art.ellipse(b + Vector2(0, 3), Vector2(30, 7)), Color(0, 0, 0, 0.22))
				for row in range(3):
					for c in range(3 - row):
						var lc := b + Vector2(-17 + c * 17 + row * 8.5, -8 - row * 14)
						Art.shape(self, Art.ellipse(lc, Vector2(8.5, 7.5), 12), wood, k, 2.2)
						Art.shape(self, Art.ellipse(lc, Vector2(4.5, 4.0), 10), cut, Color(k, 0.5), 1.2)
				# колода с топором
				var st := b + Vector2(-44, 0)
				Art.shape(self, Art.rrect(Rect2(st.x - 10, st.y - 14, 20, 14), 4), wood.darkened(0.15), k, 2.2)
				draw_line(st + Vector2(-2, -14), st + Vector2(10, -32), k, 4.0, true)
				draw_line(st + Vector2(-2, -14), st + Vector2(10, -32), Art.dn(Color("8a5a3a"), n), 2.4, true)
				Art.shape(self, PackedVector2Array([st + Vector2(6, -34), st + Vector2(18, -30), st + Vector2(14, -24), st + Vector2(4, -27)]), Art.dn(Color("c8c8d0"), n), k, 1.8)
			JobDef.Kind.FISH:
				var b2 := j.pos + Vector2(-30, 6)
				var plank := Art.dn(Color("c8925e"), n)
				Art.shape(self, Art.rrect(Rect2(b2.x - 40, b2.y - 8, 52, 12), 4), plank, k, 2.2)
				for px in [-34.0, 2.0]:
					draw_line(b2 + Vector2(px, 4), b2 + Vector2(px, 16), k, 4.0, true)
				# ведро с рыбой
				var bk := j.pos + Vector2(22, 0)
				Art.shape(self, PackedVector2Array([bk + Vector2(-9, -16), bk + Vector2(9, -16), bk + Vector2(7, 0), bk + Vector2(-7, 0)]), Art.dn(Color("9aa6b2"), n), k, 2.2)
				draw_arc(bk + Vector2(0, -16), 9, PI, TAU, 10, k, 1.6, true)
			_:
				pass


func _draw_well(n: float, k: Color) -> void:
	var p := def.well
	draw_colored_polygon(Art.ellipse(p + Vector2(0, 4), Vector2(30, 9)), Color(0, 0, 0, 0.22))
	Art.shape(self, Art.rrect(Rect2(p.x - 25, p.y - 26, 50, 26), 7), Art.dn(Color("b0a59a"), n), k, 3.0)
	Art.shape(self, Art.ellipse(p - Vector2(0, 26), Vector2(25, 8.5), 20), Art.dn(Color("c8beb2"), n), k, 3.0)
	draw_colored_polygon(Art.ellipse(p - Vector2(0, 26), Vector2(17, 5), 16), Art.dn(Color("2a4a6a"), n))
	for sx in [-21.0, 21.0]:
		draw_line(p + Vector2(sx, -26), p + Vector2(sx, -66), k, 7.0, true)
		draw_line(p + Vector2(sx, -26), p + Vector2(sx, -66), Art.dn(Color("8a5a3a"), n), 4.0, true)
	Art.shape(self, PackedVector2Array([p + Vector2(-34, -62), p + Vector2(0, -84), p + Vector2(34, -62)]), Art.dn(Color("c9573f"), n), k, 3.0)


func _draw_lamp_post(p: Vector2, n: float, on: float = -1.0) -> void:
	if on < 0.0:
		on = n
	var k := Art.ink(n)
	draw_colored_polygon(Art.ellipse(p + Vector2(0, 2), Vector2(9, 3.5)), Color(0, 0, 0, 0.22))
	draw_line(p, p + Vector2(0, -74), k, 7.0, true)
	draw_line(p, p + Vector2(0, -74), Art.dn(Color("4a4458"), n), 4.0, true)
	draw_line(p + Vector2(0, -71), p + Vector2(13, -71), k, 4.0, true)
	var lr := Rect2(p.x + 5, p.y - 70, 15, 18)
	Art.shape(self, Art.rrect(lr, 4), Color("fff0c0").lerp(Color("ffcf6b"), on).lerp(Color("4a4458"), n * (1.0 - on)), k, 2.4)


func _draw_fences(n: float, k: Color) -> void:
	var wood := Art.dn(Color("c8925e"), n)
	for row: Vector2 in [Vector2(14, 560), Vector2(604, 560)]:
		for i in range(6):
			Art.shape(self, Art.rrect(Rect2(row.x + i * 17, row.y - 32, 11, 34), 4), wood, k, 2.4)
		draw_line(Vector2(row.x - 3, row.y - 19), Vector2(row.x + 6 * 17, row.y - 19), k, 3.6, true)


## Окна загораются по одному: у каждого дома свой порог «ночи». Убежища — раньше.
func _build_thresholds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	_light_th.clear()
	for h: HouseDef in def.shelters:
		_light_th[h] = rng.randf_range(0.32, 0.62)
	for h: HouseDef in def.decor:
		_light_th[h] = rng.randf_range(0.45, 0.85)
	_lamp_th = PackedFloat32Array()
	for i in range(def.lamps.size()):
		_lamp_th.append(rng.randf_range(0.40, 0.70))


## Ночью фонари — настоящие источники света: дома отбрасывают от них тени.
## Днём источники выключены и ничего не стоят. Работает, потому что посёлок
## живёт в своём слое и свет не задевает интерфейс.
func _build_lights() -> void:
	var tex := _soft_texture()
	for i in range(def.lamps.size()):
		var l := PointLight2D.new()
		l.texture = tex
		l.position = def.lamps[i] + Vector2(12, -61)
		l.texture_scale = 2.4
		l.color = Color(1.0, 0.74, 0.42)
		l.energy = 0.0
		l.visible = false
		l.shadow_enabled = true
		l.shadow_color = Color(0, 0, 0, 0.7)
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = 4.0
		add_child(l)
		_lamp_lights.append(l)
	for h: HouseDef in def.shelters + def.decor:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		var x0 := h.pos.x - h.size.x * 0.5
		poly.polygon = PackedVector2Array([Vector2(x0, h.pos.y - h.size.y), Vector2(x0 + h.size.x, h.pos.y - h.size.y),
			Vector2(x0 + h.size.x, h.pos.y - 2), Vector2(x0, h.pos.y - 2)])
		occ.occluder = poly
		add_child(occ)


func lamp_lights() -> Array[PointLight2D]:
	return _lamp_lights


func _lit(h: HouseDef, n: float) -> float:
	var th: float = _light_th.get(h, 0.5)
	return clampf((n - th) / 0.12, 0.0, 1.0)


func _lamp_on(i: int, n: float) -> float:
	var th: float = _lamp_th[i] if i < _lamp_th.size() else 0.5
	return clampf((n - th) / 0.08, 0.0, 1.0)


func _build_trees(rng: RandomNumberGenerator) -> void:
	_tree_spots = PackedVector3Array()
	var x := -260.0
	while x < 980.0:
		_tree_spots.append(Vector3(x + rng.randf_range(-6, 6), 204 + rng.randf_range(-6, 4), rng.randf_range(0.55, 0.8)))
		x += rng.randf_range(34, 46)
	_grass = PackedVector2Array()
	for i in range(170):
		var g := Vector2(rng.randf_range(-200, 920), rng.randf_range(214, 600))
		var d := (g - def.square_center) / def.square_radii
		if d.length() > 1.05:
			_grass.append(g)


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



## Глаза в темноте: пары огоньков в лесу и у реки. Появляются к концу сумерек и моргают.
## Отдельный слой — ради них посёлок не перерисовывается.
class Eyes extends Node2D:
	const SPOTS := [Vector2(160, 158), Vector2(300, 176), Vector2(432, 178), Vector2(640, 162), Vector2(28, 330)]
	var night: float = 0.0
	var _blink: PackedFloat32Array = PackedFloat32Array()
	var _closed: PackedByteArray = PackedByteArray()
	var _t := 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		for i in range(SPOTS.size()):
			_blink.append(rng.randf_range(1.0, 4.0))
			_closed.append(0)

	func alpha() -> float:
		return clampf((night - 0.75) / 0.2, 0.0, 1.0)

	## Сколько пар сейчас смотрят — для самотеста.
	func visible_pairs() -> int:
		if alpha() < 0.5:
			return 0
		var n := 0
		for c in _closed:
			if c == 0:
				n += 1
		return n

	func _process(delta: float) -> void:
		if alpha() <= 0.0:
			if _t != 0.0:
				_t = 0.0
				queue_redraw()
			return
		_t += delta
		for i in range(_blink.size()):
			_blink[i] -= delta
			if _blink[i] <= 0.0:
				_closed[i] = 1 - _closed[i]
				_blink[i] = 0.14 if _closed[i] == 1 else randf_range(1.8, 5.0)
		queue_redraw()

	func _draw() -> void:
		var a := alpha()
		if a <= 0.0:
			return
		# тварь выглядывает из просвета между домами — застывшая улыбка, медленный наклон головы
		var pal := {"coat": Color("5d4a6b", a), "coat_d": Color("463652", a), "skin": Color("e2d6c4", a), "skin_d": Color("c2b39e", a),
			"hair": Color("1e1a1a", a), "scarf": Color("2a2a3a", a), "hat": Color("2a2a3a", a), "top": "hat"}
		Art.villager(self, 0.32, pal, "grin", {"origin": Vector2(292, 214), "ink": Color(Art.INK_N, a), "tilt": 0.18 + 0.06 * sin(_t * 0.7)})
		for i in range(SPOTS.size()):
			if _closed[i] == 1:
				continue
			var p: Vector2 = SPOTS[i] + Vector2(sin(_t * 0.4 + i) * 2.0, 0)
			for dx in [-3.6, 3.6]:
				draw_circle(p + Vector2(dx, 0), 6.0, Color(1.0, 0.3, 0.15, 0.12 * a))
				draw_circle(p + Vector2(dx, 0), 2.2, Color(1.0, 0.42, 0.22, 0.95 * a))
