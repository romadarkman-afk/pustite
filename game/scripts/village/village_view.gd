class_name VillageView
extends Node2D
## Игровое поле: посёлок. Земля с площадью, рекой и лесом — картинка (днём и ночью своя);
## дома, колодец, фонари и реквизит дел — отдельные картинки из assets/village, жители — из assets/folk.
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
var _lamp_lights: Array[PointLight2D] = []
var _tex: Dictionary = {}                  ## имя картинки -> Texture2D
var _props: Array[VillageProp] = []        ## дома, колодец, фонари и реквизит — в слое толпы
var _labels: Node2D                        ## таблички убежищ — над толпой
var _occluders: Array[LightOccluder2D] = []
var _backdrop: Backdrop                    ## небо и лес за посёлком: сдвигаются медленнее камеры
var _branches: Branches                    ## ветки по верхним углам поля — поверх посёлка
var _fog_bands: Array[Sprite2D] = []       ## полосы тумана над землёй, ползут вбок
var _smoke: Node2D                         ## дым из труб
var _field := Rect2()                      ## где поле на экране (для веток)
var blood_spots := PackedVector2Array()    ## утром: где ночью погибли (до следующей ночи)
var trail_doors := PackedVector2Array()    ## утром: к каким дверям из леса ведут следы
var loss_houses: Dictionary = {}            ## дом -> 1 память о погибшем, 2 изгнание
var rain := false                          ## лужи после дождливой ночи

## Камера. Днём приближена и следует за игроком по горизонтали; в остальных фазах
## показывает посёлок целиком. Двигается только узел: посёлок от этого не перерисовывается.
var follow: Node2D                         ## за кем следит камера; null — стоит на месте
var cam_x: float = 360.0                   ## какая точка посёлка по горизонтали в центре кадра
var _vp_w: float = 720.0
var _framing := false                      ## идёт переход кадра — камера не дёргается
var lamps_fueled: int = 99                 ## сколько фонарей заправлено на эту ночь
var talismans: PackedInt32Array = PackedInt32Array()   ## состояние оберегов открытых убежищ: 2 целый … 0 расколот
var jobs_layer: JobLayer
var _tw_frame: Tween
var _tw_night: Tween
var _t: float = 0.0
var _vignette: Sprite2D
var _unease := 0.0


func setup(village: VillageDef, open: int, names: PackedStringArray) -> void:
	def = village
	titles = names
	_font = ThemeFactory.font_bold()
	_load_art()
	_backdrop = Backdrop.new()
	_backdrop.view = self
	add_child(_backdrop)
	_build_fog_bands()
	_build_particles()
	_build_thresholds()
	_build_lights()
	eyes = Eyes.new()
	add_child(eyes)
	crowd = Crowd.new()
	crowd.view = self
	crowd.book = L.looks()
	add_child(crowd)
	_build_props()
	_smoke = Node2D.new()
	_smoke.name = "Smoke"
	add_child(_smoke)
	_labels = Node2D.new()
	_labels.name = "Plaques"
	_labels.draw.connect(_draw_plaques)
	add_child(_labels)
	_branches = Branches.new()
	_branches.view = self
	add_child(_branches)
	jobs_layer = JobLayer.new()
	jobs_layer.view = self
	jobs_layer.visible = false
	add_child(jobs_layer)
	_vignette = Sprite2D.new()
	_vignette.name = "NightVignette"
	_vignette.texture = _make_vignette()
	_vignette.position = LOGICAL * 0.5
	_vignette.scale = LOGICAL / 128.0
	add_child(_vignette)
	set_open_count(open)


func _make_vignette() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var d := Vector2((float(x) - 63.5) / 64.0, (float(y) - 63.5) / 64.0).length()
			var a := pow(clampf((d - 0.45) / 0.6, 0.0, 1.0), 1.8) * 0.72
			img.set_pixel(x, y, Color(0.035, 0.04, 0.075, a))
	return ImageTexture.create_from_image(img)


func set_unease(day: int) -> void:
	_unease = clampf(0.45 + 0.1 * float(day - 1), 0.45, 0.9) if day > 0 else 0.0


## Другая карта (акт II — мельница): земля, дома, фонари, тени и предметы строятся заново.
func set_village(village: VillageDef, open: int, names: PackedStringArray) -> void:
	titles = names
	if village == def:
		set_open_count(open)
		return
	def = village
	loss_houses.clear()
	_load_art()
	for l: PointLight2D in _lamp_lights:
		l.queue_free()
	_lamp_lights.clear()
	for o: LightOccluder2D in _occluders:
		o.queue_free()
	_occluders.clear()
	_build_thresholds()
	_build_lights()
	_build_props()
	set_open_count(open)


func set_open_count(n: int) -> void:
	open_count = clampi(n, 1, def.shelters.size())
	_build_glows()
	_build_smoke()
	_refresh()


func open_shelters() -> int:
	return open_count


func boarded_shelters() -> int:
	return def.shelters.size() - open_count


func set_night(v: float) -> void:
	night = clampf(v, 0.0, 1.0)
	if _fog != null:
		_fog.modulate.a = 0.35 + 0.65 * night
		_dust.modulate.a = 0.12 + 0.88 * (1.0 - night)
	for i in range(_fog_bands.size()):
		_fog_bands[i].modulate = Color(0.8, 0.86, 0.9).lerp(Color(0.62, 0.7, 0.86), night)
		_fog_bands[i].modulate.a = (0.24 + 0.4 * night) * (1.0 if i == 0 else 0.75)
	if _smoke != null:
		_smoke.modulate = Color(0.92, 0.92, 0.9, 0.85).lerp(Color(0.5, 0.55, 0.7, 0.4), night)
	if _branches != null:
		_branches.modulate = Color(0.85, 0.9, 0.9).lerp(Color(0.42, 0.46, 0.62), night)
	if crowd != null:
		crowd.set_night(night)
	if eyes != null:
		eyes.night = night
	# статика перерисовывается ступеньками: сумерки плавные, а кадры не проседают
	var q := snappedf(night, 0.025)
	if q != _q:
		_q = q
		_refresh()


func set_mood(v: float, dur: float) -> void:
	if _tw_night != null:
		_tw_night.kill()
	if dur <= 0.0:
		set_night(v)
		return
	_tw_night = create_tween().set_trans(Tween.TRANS_SINE)
	_tw_night.tween_property(self, "night", v, dur)


## На главном экране оставляем открытое небо; еловая рамка нужна только игровым сценам.
func set_branches_visible(v: bool) -> void:
	if _branches == null:
		return
	_branches.visible = v
	_branches.queue_redraw()


func set_loss_houses(houses: Dictionary) -> void:
	if loss_houses == houses:
		return
	loss_houses = houses.duplicate()
	_refresh()


## Вписать полосу с домами в прямоугольник поля. vp_w — ширина экрана.
## Кадрировать поле в прямоугольник экрана rect. zoom > 1 — приблизить посёлок
## (по высоте он всё равно поместится в поле), камера встаёт на focus_x.
func frame_to(rect: Rect2, vp_w: float, dur: float, zoom: float = 1.0, focus_x: float = -1.0) -> void:
	_field = rect
	if _branches != null:
		_branches.queue_redraw()
	var base := minf(vp_w / (LOGICAL.x * SIDE_VISIBLE), rect.size.y / BAND.size.y)
	var s := minf(base * zoom, rect.size.y / BAND.size.y)
	s = maxf(s, 0.5)
	_vp_w = vp_w
	if focus_x >= 0.0:
		cam_x = focus_x
	elif zoom <= 1.0:
		cam_x = LOGICAL.x * 0.5
	cam_x = _clamp_cam(cam_x, s)
	_backdrop.position.x = (cam_x - LOGICAL.x * 0.5) * Backdrop.PARALLAX
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
	_backdrop.position.x = (cam_x - LOGICAL.x * 0.5) * Backdrop.PARALLAX


var tunnel: Vector2i = Vector2i(-1, -1)   ## туннель между двумя убежищами: у обоих домов люк


func set_tunnel(t: Vector2i) -> void:
	if t != tunnel:
		tunnel = t
		_refresh()


## Где люк туннеля у дома i — справа от двери.
func hatch_pos(i: int) -> Vector2:
	var h: HouseDef = def.shelters[i]
	return h.pos + Vector2(h.size.x * 0.5 + 6.0, 16.0)


## Следы ночи на земле: кровь там, где погибли, и следы когтистых ног к дверям, куда входил упырь.
func set_traces(blood: PackedVector2Array, trails: PackedVector2Array) -> void:
	if blood != blood_spots or trails != trail_doors:
		blood_spots = blood
		trail_doors = trails
		_refresh()


## Станция (TASK-031): перрон из досок, шпалы и два рельса через всю карту. Под людьми и домами.
func _draw_rails(mod: Color) -> void:
	var y := def.rails_y
	var x0 := def.ground_rect.position.x - 40.0
	var x1 := def.ground_rect.end.x + 40.0
	var plank := Color(0.42, 0.33, 0.24).lerp(mod, 0.25)
	draw_rect(Rect2(x0, y - 34.0, x1 - x0, 20.0), Color(plank, 0.95))
	for i in range(int((x1 - x0) / 26.0)):
		draw_line(Vector2(x0 + i * 26.0, y - 34.0), Vector2(x0 + i * 26.0, y - 14.0), Color(0, 0, 0, 0.25), 1.2)
	draw_rect(Rect2(x0, y - 15.0, x1 - x0, 3.0), Color(0.25, 0.2, 0.15, 0.9))
	var sleeper := Color(0.3, 0.22, 0.16).lerp(mod, 0.2)
	var x := x0
	while x < x1:
		draw_rect(Rect2(x, y - 4.0, 9.0, 22.0), sleeper)
		x += 19.0
	var steel := Color(0.62, 0.62, 0.66).lerp(mod, 0.3)
	for ry: float in [y, y + 12.0]:
		draw_line(Vector2(x0, ry), Vector2(x1, ry), Color(0.15, 0.15, 0.17), 3.6)
		draw_line(Vector2(x0, ry - 1.0), Vector2(x1, ry - 1.0), steel, 1.6)


## Залитый дом (TASK-024): вода у стен, -1 — сухо.
var flooded := -1


func set_flood(h: int) -> void:
	if h != flooded:
		flooded = h
		_refresh()


func set_rain(on: bool) -> void:
	if on != rain:
		rain = on
		_refresh()


## Порог дома: туда ведут следы и там остаётся кровь.
func door_point(i: int) -> Vector2:
	return def.shelters[i].pos + Vector2(0, 12) if i >= 0 and i < def.shelters.size() else def.square_center


## Где на улице лежит погибший: на краю площади, своё место у каждого.
func street_point(id: int) -> Vector2:
	var a := 0.6 + float(id) * 2.399
	return def.square_center + Vector2(cos(a) * def.square_radii.x * 0.8, sin(a) * def.square_radii.y * 0.8 + 18.0)


func set_talismans(t: PackedInt32Array) -> void:
	if t != talismans:
		talismans = t.duplicate()
		_refresh()


## Ночью горит столько фонарей, сколько заправили днём.
func set_lamps_fueled(n: int) -> void:
	if n != lamps_fueled:
		lamps_fueled = n
		_refresh()


func _lamp_fuel(i: int) -> float:
	return 1.0 if i < lamps_fueled else 0.0


func set_selected_house(i: int) -> void:
	selected_house = i
	_refresh()


func set_house_going(counts: PackedInt32Array, on: bool) -> void:
	house_going = counts
	show_going = on
	_refresh()


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


## Зона касания дома в координатах экрана: картинка дома с крышей, не меньше 84×84 px.
func house_hit_rect_global(i: int) -> Rect2:
	var lr := house_rect(def.shelters[i]).grow_individual(-8.0, -6.0, -8.0, 0.0)
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
	if _vignette != null:
		_vignette.modulate.a = night * _unease
	for i in range(_fog_bands.size()):
		var b := _fog_bands[i]
		b.region_rect.position.x = fposmod(b.region_rect.position.x + delta * (9.0 if i == 0 else -6.0) / b.scale.x, 4096.0)
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

	# небо и дальний лес рисует Backdrop (он за посёлком и сдвигается медленнее камеры).
	# Земля — картинка: площадь, тропы, река, лес по верхнему краю; ночью её сменяет ночная
	# картинка того же места. Верх земли тонет в нижнем крае дальнего леса.
	var gr := def.ground_rect
	var forest := Backdrop.FOREST_DAY.lerp(Backdrop.FOREST_NIGHT, n)
	draw_rect(Rect2(-2000, gr.position.y + 40.0, 4720, 3000), Color("4a4636").lerp(Color("1c2430"), n))
	draw_texture_rect(_tex.ground_day, gr, false)
	if n > 0.0:
		draw_texture_rect(_tex.ground_night, gr, false, Color(1, 1, 1, n))
	Art.vgrad(self, Rect2(gr.position.x, gr.position.y, gr.size.x, 40.0), Color(forest, 0.75), Color(forest, 0.0))
	# шов между дальним лесом и землёй прячет полоса дымки
	var mist := Color8(118, 128, 140).lerp(Color8(44, 54, 76), n)
	Art.vgrad(self, Rect2(-2000, gr.position.y - 34.0, 4720, 36.0), Color(mist, 0.0), Color(mist, 0.6))
	Art.vgrad(self, Rect2(-2000, gr.position.y + 2.0, 4720, 48.0), Color(mist, 0.6), Color(mist, 0.0))

	# дома, колодец, фонари, поленница и бочка — предметы в слое толпы (VillageProp):
	# кто стоит за домом, того дом закрывает. Здесь только то, что лежит на земле.
	_draw_traces(n)
	_draw_hatches(n, k)
	_draw_fish(n, k)
	_draw_fences(n, k)
	draw_usec_total += Time.get_ticks_usec() - t0


## Перерисовать посёлок вместе с предметами и табличками.
func _refresh() -> void:
	queue_redraw()
	if _backdrop != null:
		_backdrop.queue_redraw()
	for p: VillageProp in _props:
		p.queue_redraw()
	if _labels != null:
		_labels.queue_redraw()


func _nq() -> float:
	return _q if _q >= 0.0 else night


func _build_props() -> void:
	for p: VillageProp in _props:
		p.queue_free()
	_props.clear()
	for i in range(def.shelters.size()):
		var idx := i
		_add_prop(def.shelters[i].pos, func(ci: CanvasItem) -> void: _paint_shelter(ci, idx))
	for hd: HouseDef in def.decor:
		var h := hd
		_add_prop(h.pos, func(ci: CanvasItem) -> void: _draw_house(ci, h, 0, _nq(), _lit(h, _nq()), 2))
	if def.well_sprite:
		_add_prop(def.well, func(ci: CanvasItem) -> void: _draw_well(ci, _nq()))
	for li in range(def.lamps.size()):
		var lidx := li
		_add_prop(def.lamps[li], func(ci: CanvasItem) -> void:
			_draw_lamp_post(ci, def.lamps[lidx], _nq(), _lamp_on(lidx, _nq()) * _lamp_fuel(lidx)))
		_props.back().set_meta("street_lamp", true)
	for pr: Dictionary in def.props:
		var id := String(pr.id)
		if not _tex.has(id):
			_tex[id] = load(ART_DIR + id + ".png") as Texture2D
		var at: Vector2 = pr.pos
		var pw := float(pr.get("w", 60.0))
		var fl := bool(pr.get("flip", false))
		_add_prop(at, func(ci: CanvasItem) -> void: _decor_prop(ci, id, at, pw, fl, _nq()))
	for j: JobDef in def.jobs:
		var jp := j.pos
		match j.kind:
			JobDef.Kind.WOOD:
				_add_prop(jp + Vector2(36, 4), func(ci: CanvasItem) -> void: _prop(ci, _tex.woodpile, jp + Vector2(36, 4), 76.0, _nq()))
			JobDef.Kind.LAMP:
				_add_prop(jp + Vector2(-30, 3), func(ci: CanvasItem) -> void: _prop(ci, _tex.barrel, jp + Vector2(-30, 3), 30.0, _nq()))


func _add_prop(at: Vector2, paint: Callable, depth: int = 0) -> void:
	var p := VillageProp.new()
	p.position = at
	p.z_index = depth
	p.paint = paint
	crowd.add_child(p)
	_props.append(p)


## Убежище: открытое или заколоченное, с оберегом; выбранное ночью — в тёплой рамке.
func _paint_shelter(ci: CanvasItem, i: int) -> void:
	var h: HouseDef = def.shelters[i]
	var n := _nq()
	_draw_house(ci, h, 1 if i < open_count else 2, n, _lit(h, n), talismans[i] if i < talismans.size() else 2)
	var loss := int(loss_houses.get(i, 0))
	if loss > 0:
		var still_lived_in := false
		if Game.m != null:
			for resident: Villager in Game.m.villagers:
				if resident.alive and not resident.departed and resident.night_house == i:
					still_lived_in = true
					break
		if not still_lived_in:
			var art := _art(h)
			_blit(ci, _tex[art[0] + "_day"], house_rect(h), _flip(h), Color(0.07, 0.09, 0.13, 0.56))
		var door := door_rect(h)
		if loss == 1:
			# Траурная лента видна даже в занятом доме.
			ci.draw_line(door.position + Vector2(-3, 1), door.position + Vector2(6, 17), Color("16161c"), 5.0)
			ci.draw_line(door.position + Vector2(6, 1), door.position + Vector2(-3, 17), Color("292833"), 4.0)
		else:
			# После изгнания дверь оставили приоткрытой.
			ci.draw_colored_polygon(PackedVector2Array([door.position, door.position + Vector2(door.size.x * 0.6, 3), door.position + Vector2(door.size.x * 0.5, door.size.y), Vector2(door.position.x, door.end.y)]), Color("100e13"))
			ci.draw_line(door.position + Vector2(door.size.x * 0.6, 3), door.position + Vector2(door.size.x * 0.5, door.size.y), Color("856849"), 2.0)
	if i == selected_house and i < open_count:
		Art._outline(ci, Art.rrect(house_rect(h).grow(6.0), 12), ThemeFactory.LAMP, 3.5)


## Где житель спрятался бы за предметом: от верха картинки дома (колодца) до точки, где тот стоит.
## Толпа не ставит туда людей: из-за дома не было бы видно ни фигуры, ни имени.
func hidden_zones() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for h: HouseDef in def.shelters + def.decor:
		var r := house_rect(h)
		out.append(Rect2(r.position.x + r.size.x * 0.08, r.position.y, r.size.x * 0.84, h.pos.y - r.position.y))
	out.append(Rect2(def.well.x - 30.0, def.well.y - 70.0, 60.0, 70.0))
	for pr: Dictionary in def.props:
		var w := float(pr.get("w", 60.0))
		var at: Vector2 = pr.pos
		out.append(Rect2(at.x - w * 0.4, at.y - w * 0.8, w * 0.8, w * 0.8 + 4.0))
	return out


## Таблички открытых убежищ — капсулы на доме над дверью; рисуются над толпой.
func _draw_plaques() -> void:
	for i in range(open_count):
		var r := shelter_label_rect_local(i)
		var sel := i == selected_house
		Art.shape(_labels, Art.rrect(r, r.size.y * 0.5), Color(0.08, 0.06, 0.12, 0.82), ThemeFactory.LAMP if sel else Color(1, 1, 1, 0.3), 2.0 if sel else 1.2)
		var name_w := _font.get_string_size(_title(i), HORIZONTAL_ALIGNMENT_LEFT, -1, PLAQUE_SIZE).x
		var x2 := r.position.x + 8.0
		_labels.draw_string(_font, Vector2(x2, r.end.y - 4.5), _title(i), HORIZONTAL_ALIGNMENT_LEFT, -1, PLAQUE_SIZE, Color(1, 1, 1))
		if _going_text(i) != "":
			_labels.draw_string(_font, Vector2(x2 + name_w, r.end.y - 4.5), _going_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, PLAQUE_SIZE, ThemeFactory.LAMP)


const PLAQUE_SIZE := 14
const ART_DIR := "res://assets/village/"
## Вид дома -> [картинка, ширина на поле в долях h.size.x, дверь на картинке в долях].
## Картинка ставится так, чтобы низ двери пришёлся в h.pos: туда же встаёт очередь.
const HOUSE_ART := {
	HouseDef.Kind.HOME: ["house", 1.4, Rect2(0.20, 0.60, 0.17, 0.30)],
	HouseDef.Kind.BARN: ["barn", 1.45, Rect2(0.19, 0.55, 0.26, 0.40)],
	HouseDef.Kind.CHURCH: ["church", 1.6, Rect2(0.21, 0.70, 0.17, 0.25)],
	HouseDef.Kind.CELLAR: ["cellar", 1.4, Rect2(0.23, 0.14, 0.30, 0.65)],
	HouseDef.Kind.GARAGE: ["garage", 1.25, Rect2(0.10, 0.48, 0.25, 0.40)],
	HouseDef.Kind.SHED: ["shed", 1.4, Rect2(0.17, 0.40, 0.18, 0.45)],
}
## Земля посёлка — одна картинка днём и одна ночью (Nano Banana, 2400×1792, уменьшены).
## Площадь на картинке (центр 1320×1060 px, полуоси 660×340) совпадает с площадью посёлка.
const GROUND_FILES: PackedStringArray = ["ground_day", "ground_night"]
const GROUND_RECT := Rect2(-88.8, 31.6, 816.0, 609.3)   ## деревня; у другой карты — VillageDef.ground_rect
const ART_FILES: PackedStringArray = ["house_day", "house_night", "barn_day", "barn_night", "church_day", "church_night",
	"cellar_day", "cellar_night", "garage_day", "garage_night", "shed_day", "shed_night", "lamp_day", "lamp_night",
	"well", "woodpile", "barrel", "talisman", "talisman_cracked", "talisman_broken", "boards"]
## Небо, дальний лес, ветки, туман и дым — общие для всех карт и стран.
const MAP_FILES: PackedStringArray = ["sky_day.jpg", "sky_dusk.jpg", "sky_night.jpg", "treeline_day.png", "treeline_night.png",
	"branches.png", "fog.png", "smoke.png", "puddles.png", "footprints.png", "blood_mud.png"]
## Где у дома труба на картинке (доли ширины и высоты, дом не отражён). Нет в списке — дом без трубы.
const CHIMNEY := {HouseDef.Kind.HOME: Vector2(0.62, 0.05), HouseDef.Kind.CHURCH: Vector2(0.76, 0.39), HouseDef.Kind.GARAGE: Vector2(0.72, 0.04)}


## Фоны и графика общие для всех языков. Локаль меняет только текст.
func _load_art() -> void:
	for f: String in ART_FILES:
		_tex[f] = load(ART_DIR + f + ".png") as Texture2D
	for g: String in GROUND_FILES:
		_tex[g] = load(ART_DIR + g.replace("ground", def.ground if def != null else "ground") + ".jpg") as Texture2D
	for f: String in MAP_FILES:
		_tex[f.get_basename()] = load(ART_DIR + f) as Texture2D


## Дома слева от площади смотрят дверью вправо, к площади: картинку отражаем.
## Гараж тоже отражён: так он уходит влево от двери и не закрывает поленницу.
func _flip(h: HouseDef) -> bool:
	return h.pos.x < def.square_center.x - 20.0 or h.kind == HouseDef.Kind.GARAGE


func _art(h: HouseDef) -> Array:
	if not h.art.is_empty():
		var key := "maps/" + h.art
		if not _tex.has(key + "_day"):
			_tex[key + "_day"] = load(ART_DIR + key + "_day.png") as Texture2D
			var np := ART_DIR + key + "_night.png"
			_tex[key + "_night"] = load(np) as Texture2D if ResourceLoader.exists(np) else null
		return [key, h.art_w, h.art_door]
	return HOUSE_ART.get(h.kind, HOUSE_ART[HouseDef.Kind.HOME])


## Где на поле картинка дома (в координатах посёлка).
func house_rect(h: HouseDef) -> Rect2:
	var a := _art(h)
	var tex: Texture2D = _tex[a[0] + "_day"]
	var w: float = h.size.x * a[1]
	var hh := w * tex.get_height() / tex.get_width()
	var door: Rect2 = a[2]
	var ax := door.get_center().x
	if _flip(h):
		ax = 1.0 - ax
	return Rect2(h.pos.x - ax * w, h.pos.y - door.end.y * hh, w, hh)


## Дверь дома на поле: доски у заколоченных, оберег рядом.
func door_rect(h: HouseDef) -> Rect2:
	var r := house_rect(h)
	var d: Rect2 = _art(h)[2]
	var x := d.position.x if not _flip(h) else 1.0 - d.end.x
	return Rect2(r.position.x + x * r.size.x, r.position.y + d.position.y * r.size.y, d.size.x * r.size.x, d.size.y * r.size.y)


func _night_mod(n: float) -> Color:
	return Color(1, 1, 1).lerp(Art.NIGHT_TINT, n)


## Картинка в прямоугольник; flip — зеркально по горизонтали.
func _blit(ci: CanvasItem, tex: Texture2D, r: Rect2, flip: bool, mod: Color = Color(1, 1, 1)) -> void:
	var off := Vector2.ZERO if ci == self else -(ci as Node2D).position
	if flip:
		ci.draw_set_transform(Vector2(r.end.x, r.position.y) + off, 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(tex, Rect2(Vector2.ZERO, r.size), false, mod)
		ci.draw_set_transform(off)
	else:
		ci.draw_texture_rect(tex, r, false, mod)


## Реквизит для вида (телега, стог, пугало…): низ по центру в точке p, ширина w.
func _decor_prop(ci: CanvasItem, id: String, p: Vector2, w: float, flip: bool, n: float) -> void:
	var tex: Texture2D = _tex.get(id)
	if tex == null:
		return
	var h := w * tex.get_height() / tex.get_width()
	ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, -4), Vector2(w * 0.44, 6)), Color(0, 0, 0, 0.2))
	_blit(ci, tex, Rect2(p.x - w * 0.5, p.y - h, w, h), flip, _night_mod(n).darkened(0.06))


## Реквизит: низ по центру в точке p, ширина w.
func _prop(ci: CanvasItem, tex: Texture2D, p: Vector2, w: float, n: float) -> void:
	var h := w * tex.get_height() / tex.get_width()
	ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, -3), Vector2(w * 0.46, 6)), Color(0, 0, 0, 0.2))
	_blit(ci, tex, Rect2(p.x - w * 0.5, p.y - h, w, h), false, _night_mod(n))


## Дом: дневная картинка, к ночи темнеет; когда в доме загорается свет, поверх ложится
## ночная картинка с горящими окнами. state: 0 — фон, 1 — открытое убежище, 2 — заколоченное.
func _draw_house(ci: CanvasItem, h: HouseDef, state: int, n: float, lit: float, tal: int) -> void:
	var a := _art(h)
	var r := house_rect(h)
	var flip := _flip(h)
	ci.draw_colored_polygon(Art.ellipse(Vector2(r.get_center().x, h.pos.y + 2.0), Vector2(r.size.x * 0.5, 11)), Color(0, 0, 0, 0.2))
	var mod := _night_mod(n)
	if state == 2:
		mod = mod.darkened(0.32)
	elif state == 0:
		mod = mod.darkened(0.08)
	var night_tex: Texture2D = _tex.get(a[0] + "_night")
	if night_tex == null and state != 2:
		# у картинки нет ночной пары: жилой дом ночью теплеет, будто внутри горит свет
		mod = mod.lerp(Color(1.0, 0.82, 0.6), 0.42 * lit)
	_blit(ci, _tex[a[0] + "_day"], r, flip, mod)
	if state != 2 and lit > 0.0 and night_tex != null:
		_blit(ci, night_tex, r, flip, Color(1, 1, 1, lit * (1.0 if state == 1 else 0.85)))
	var dr := door_rect(h)
	if state == 1:
		_draw_talisman(ci, dr, flip, n, tal)
	elif state == 2:
		_draw_boards(ci, dr, flip, n)


## Заколоченная дверь: две доски крест-накрест поверх двери.
func _draw_boards(ci: CanvasItem, dr: Rect2, flip: bool, n: float) -> void:
	var w := clampf(maxf(dr.size.x * 1.35, dr.size.y * 0.85), 22.0, 60.0)
	var hh: float = w * _tex.boards.get_height() / _tex.boards.get_width()
	var c := dr.get_center()
	_blit(ci, _tex.boards, Rect2(c.x - w * 0.5, c.y - hh * 0.5, w, hh), flip, _night_mod(n).darkened(0.1))


## Оберег на стене у двери, со стороны от площади. tal: 2 целый, 1 треснул, 0 расколот.
func _draw_talisman(ci: CanvasItem, dr: Rect2, flip: bool, n: float, tal: int) -> void:
	var w := clampf(dr.size.x * 0.75, 20.0, 26.0)
	var hh: float = w * _tex.talisman.get_height() / _tex.talisman.get_width()
	var cx := dr.position.x - w * 0.62 if not flip else dr.end.x + w * 0.62
	var r := Rect2(cx - w * 0.5, dr.position.y + dr.size.y * 0.05, w, hh)
	var tex: Texture2D = _tex.talisman if tal >= 2 else (_tex.talisman_cracked if tal == 1 else _tex.talisman_broken)
	_blit(ci, tex, r, false, _night_mod(n * 0.6))


func _title(i: int) -> String:
	return titles[i] if i < titles.size() else def.shelters[i].title


## Ночью на табличке: сколько жителей туда собирается.
func _going_text(i: int) -> String:
	if not show_going or i >= house_going.size():
		return ""
	return " · %d" % house_going[i]


## Табличка с названием убежища в координатах посёлка: над дверью, но не шире картинки дома.
func shelter_label_rect_local(i: int) -> Rect2:
	var h: HouseDef = def.shelters[i]
	var w := _font.get_string_size(_title(i) + _going_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, PLAQUE_SIZE).x + 16.0
	var top := h.pos.y - h.size.y
	var hr := house_rect(h)
	var x := clampf(h.pos.x - w * 0.5, hr.position.x + 4.0, maxf(hr.position.x + 4.0, hr.end.x - w - 4.0))
	return Rect2(x, top + 3.0, w, 19.0)


func shelter_label_rect_global(i: int) -> Rect2:
	var r := shelter_label_rect_local(i)
	return Rect2(to_global(r.position), r.size * scale)


## Лужи, кровь и следы — плоские картинки на земле, под людьми.
func _draw_traces(n: float) -> void:
	var mod := _night_mod(n)
	if rain:
		var pt: Texture2D = _tex.puddles
		for i in range(def.puddle_spots.size()):
			var sp := def.puddle_spots[i]
			var h := sp.z * pt.get_height() / pt.get_width()
			_blit(self, pt, Rect2(sp.x - sp.z * 0.5, sp.y - h * 0.5, sp.z, h), i % 2 == 1, Color(mod, 0.92))
	if def.rails_y >= 0.0 and def.ground != "ground_station":
		_draw_rails(mod)
	if flooded >= 0 and flooded < def.shelters.size():
		# вода у залитого дома: тёмное пятно с отблеском, поверх земли и под людьми
		var hd: HouseDef = def.shelters[flooded]
		var c := hd.pos + Vector2(0, 16)
		var rx := hd.size.x * 1.05
		var ry := hd.size.y * 0.5
		for k in range(3):
			var pts := PackedVector2Array()
			for i in range(28):
				var a := TAU * i / 28.0
				pts.append(c + Vector2(cos(a) * rx * (1.0 - k * 0.18), sin(a) * ry * (1.0 - k * 0.18)))
			draw_colored_polygon(pts, Color(Color(0.22, 0.36, 0.5).lerp(mod, 0.15), 0.5 + k * 0.14))
		for w in range(3):
			var y := c.y - ry * 0.35 + w * ry * 0.3
			var x0 := c.x - rx * (0.55 - w * 0.12)
			draw_line(Vector2(x0, y), Vector2(x0 + rx * (0.5 + w * 0.1), y - 2.0), Color(0.86, 0.93, 1.0, 0.45), 2.0)
	var ft: Texture2D = _tex.footprints
	for d: Vector2 in trail_doors:
		var from_left := d.x < def.square_center.x
		var w := 118.0
		var h := w * ft.get_height() / ft.get_width()
		# цепочка подходит к порогу сбоку, с края посёлка
		var c := d + Vector2(-w * 0.55 if from_left else w * 0.55, 6.0)
		draw_set_transform(c, 0.0, Vector2(1 if from_left else -1, 1))
		draw_texture_rect(ft, Rect2(-w * 0.5, -h * 0.5, w, h), false, mod.lightened(0.15))
		draw_set_transform(Vector2.ZERO)
	var bt: Texture2D = _tex.blood_mud
	for b: Vector2 in blood_spots:
		var w := 78.0
		var h := w * bt.get_height() / bt.get_width()
		draw_texture_rect(bt, Rect2(b.x - w * 0.5, b.y - h * 0.5, w, h), false, mod.lightened(0.1))


## Реквизит дел: поленница и мостки с ведром у реки. Остальные дела — у колодца,
## фонаря и оберега, которые и так стоят на карте.
func _draw_hatches(n: float, k: Color) -> void:
	for i: int in [tunnel.x, tunnel.y]:
		if i < 0 or i >= open_count or i >= def.shelters.size():
			continue
		var c := hatch_pos(i)
		var wood := Art.dn(Color("8a5a3a"), n)
		draw_colored_polygon(Art.ellipse(c + Vector2(0, 3), Vector2(17, 6)), Color(0, 0, 0, 0.25))
		var pts := PackedVector2Array([c + Vector2(-15, -6), c + Vector2(15, -6), c + Vector2(17, 5), c + Vector2(-17, 5)])
		Art.shape(self, pts, wood, k, 2.2)
		for x: float in [-6.0, 4.0]:
			draw_line(c + Vector2(x, -6), c + Vector2(x * 1.15, 5), Color(k, 0.5), 1.4)
		draw_arc(c + Vector2(9, -1), 3.2, 0, TAU, 10, Art.dn(Color("c8c8d0"), n), 1.6, true)


## Мостки и ведро у реки — плоские, их никто не заслоняет; поленница и бочка — предметы (VillageProp).
func _draw_fish(n: float, k: Color) -> void:
	for j: JobDef in def.jobs:
		match j.kind:
			JobDef.Kind.FISH:
				var b2 := j.pos + Vector2(-30, 6)
				if def.fish_planks:
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


func _draw_well(ci: CanvasItem, n: float) -> void:
	_prop(ci, _tex.well, def.well + Vector2(0, 8), 80.0, n)


## Фонарный столб: фонарь справа на кронштейне, ночью горит, если его заправили днём.
const LAMP_H := 84.0
const LAMP_BASE_X := 0.42                  ## где столб на отражённой картинке, доля ширины


func _draw_lamp_post(ci: CanvasItem, p: Vector2, n: float, on: float = -1.0) -> void:
	if on < 0.0:
		on = n
	var w: float = LAMP_H * _tex.lamp_day.get_width() / _tex.lamp_day.get_height()
	var r := Rect2(p.x - LAMP_BASE_X * w, p.y - LAMP_H * 0.98, w, LAMP_H)
	ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, 2), Vector2(9, 3.5)), Color(0, 0, 0, 0.22))
	_blit(ci, _tex.lamp_day, r, true, _night_mod(n))
	if on > 0.0:
		_blit(ci, _tex.lamp_night, r, true, Color(1, 1, 1, on))


func _draw_fences(n: float, k: Color) -> void:
	var wood := Art.dn(Color("9a7652"), n)
	for row: Vector2 in def.fences:
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
		var hr := house_rect(h).grow_individual(-0.15 * house_rect(h).size.x, -0.3 * house_rect(h).size.y, -0.15 * house_rect(h).size.x, 0.0)
		poly.polygon = PackedVector2Array([hr.position, Vector2(hr.end.x, hr.position.y),
			Vector2(hr.end.x, h.pos.y - 2), Vector2(hr.position.x, h.pos.y - 2)])
		occ.occluder = poly
		add_child(occ)
		_occluders.append(occ)


func lamp_lights() -> Array[PointLight2D]:
	return _lamp_lights


func _lit(h: HouseDef, n: float) -> float:
	var th: float = _light_th.get(h, 0.5)
	return clampf((n - th) / 0.12, 0.0, 1.0)


func _lamp_on(i: int, n: float) -> float:
	var th: float = _lamp_th[i] if i < _lamp_th.size() else 0.5
	return clampf((n - th) / 0.08, 0.0, 1.0)


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
		s.z_index = 0
		s.position = p - Vector2(-12, 65)
		s.scale = Vector2(2.1, 2.1)
		s.modulate = Color(ThemeFactory.LAMP, 0.0)
		add_child(s)
		move_child(s, crowd.get_index())
		_lamp_glows.append(s)
	for i in range(open_count):
		var h: HouseDef = def.shelters[i]
		var s := Sprite2D.new()
		s.texture = tex
		s.material = add
		s.z_index = 0
		var hr := house_rect(h)
		s.position = hr.get_center() + Vector2(0, hr.size.y * 0.1)
		s.scale = Vector2(hr.size.x / 80.0, hr.size.y / 95.0)
		s.modulate = Color(ThemeFactory.LAMP, 0.0)
		add_child(s)
		move_child(s, crowd.get_index())
		_house_glows.append(s)


## Туман полосами: две ленты из картинки fog.png ползут в разные стороны над землёй, за людьми.
func _build_fog_bands() -> void:
	var tex: Texture2D = _tex.fog
	var half := tex.get_height() * 0.5
	for i in range(2):
		var b := Sprite2D.new()
		b.name = "FogBand%d" % i
		b.texture = tex
		b.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
		b.region_enabled = true
		var sc := 0.42 if i == 0 else 0.6
		b.scale = Vector2(sc, sc)
		b.region_rect = Rect2(i * 700.0, i * half, 3600.0 / sc, half)
		b.position = Vector2(360, 196.0 if i == 0 else 470.0)
		add_child(b)
		_fog_bands.append(b)


## Дым из труб: из жилых домов, у заколоченных убежищ печь не топят.
func _build_smoke() -> void:
	if _smoke == null:
		return
	for c in _smoke.get_children():
		c.queue_free()
	var homes: Array[HouseDef] = []
	for i in range(mini(open_count, def.shelters.size())):
		homes.append(def.shelters[i])
	homes.append_array(def.decor)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.15, Color(1, 1, 1, 0.75))
	ramp.add_point(0.6, Color(1, 1, 1, 0.4))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.0))
	var k := 0
	for h: HouseDef in homes:
		var f: Vector2 = h.art_chimney if not h.art.is_empty() else CHIMNEY.get(h.kind, Vector2(-1, -1))
		if f.x < 0.0:
			continue
		var r := house_rect(h)
		var p := CPUParticles2D.new()
		p.texture = _tex.smoke
		p.position = Vector2(r.position.x + r.size.x * (1.0 - f.x if _flip(h) else f.x), r.position.y + r.size.y * f.y - 6.0)
		p.amount = 5
		p.lifetime = 7.0
		p.preprocess = 7.0
		p.randomness = 0.4
		p.direction = Vector2(0.25, -1)
		p.spread = 10.0
		p.gravity = Vector2(1.8, -1.0)
		p.initial_velocity_min = 7.0
		p.initial_velocity_max = 11.0
		p.angle_min = -12.0
		p.angle_max = 12.0
		p.scale_amount_min = 0.2
		p.scale_amount_max = 0.26
		p.scale_amount_curve = grow
		p.color_ramp = ramp
		p.seed = 31 + k
		p.use_fixed_seed = true
		_smoke.add_child(p)
		k += 1


func smoke_count() -> int:
	return _smoke.get_child_count() if _smoke != null else 0


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
	const CREATURE_PATH := "res://assets/village/creature.png"
	const SPOTS := [Vector2(160, 158), Vector2(300, 176), Vector2(432, 178), Vector2(640, 162), Vector2(28, 330)]
	var creature_tex: Texture2D
	var night: float = 0.0
	var _blink: PackedFloat32Array = PackedFloat32Array()
	var _closed: PackedByteArray = PackedByteArray()
	var _t := 0.0
	var _peek_in := 8.0
	var _peek_left := 0.0

	func _ready() -> void:
		creature_tex = load(CREATURE_PATH) as Texture2D
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
		_peek_in -= delta
		if _peek_in <= 0.0:
			_peek_left = 0.5
			_peek_in = randf_range(11.0, 19.0)
		if _peek_left > 0.0:
			_peek_left = maxf(0.0, _peek_left - delta)
		queue_redraw()

	func _draw() -> void:
		var a := alpha()
		if a <= 0.0:
			return
		# прозрачный рисунок твари выглядывает из просвета между домами. Глаза и улыбка
		# остаются на отдельном слое; движение добавляет лёгкий наклон.
		var tex: Texture2D = creature_tex if creature_tex != null else VillagerFigure.folk_tex(2)
		if tex == null:
			return
		var h := 74.0
		var w := h * tex.get_width() / tex.get_height()
		# стоит в просвете между домом и часовней; его глаза — вторая пара красных огоньков (SPOTS[1])
		var peek := sin((1.0 - _peek_left / 0.5) * PI) if _peek_left > 0.0 else 0.0
		var o := Vector2(300 + 2.4 * peek, 245 + 1.0 * sin(_t * 0.45))
		var tilt := 0.05 * sin(_t * 0.7) + 0.055 * peek
		var breath := sin(_t * 0.6)
		draw_set_transform(o, tilt, Vector2(1.0 + 0.008 * breath, 1.08 + 0.012 * breath - 0.015 * peek))
		draw_texture_rect(tex, Rect2(-w * 0.5, -h, w, h), false, Color(0.62, 0.60, 0.65, 0.94 * a))
		draw_arc(Vector2(0, -h * 0.86 + 5.0), 4.5, 0.35, PI - 0.35, 8, Color(0.92, 0.9, 0.8, 0.7 * a), 1.2, true)
		draw_set_transform(Vector2.ZERO)
		for i in range(SPOTS.size()):
			if _closed[i] == 1:
				continue
			var p: Vector2 = SPOTS[i] + Vector2(sin(_t * 0.4 + i) * 2.0, 0)
			for dx in [-3.6, 3.6]:
				draw_circle(p + Vector2(dx, 0), 6.0, Color(1.0, 0.3, 0.15, 0.12 * a))
				draw_circle(p + Vector2(dx, 0), 2.2, Color(1.0, 0.42, 0.22, 0.95 * a))



## Небо и дальний лес за посёлком: три неба (день, сумерки, ночь) и две полосы леса.
## Картинки повторяются зеркально по горизонтали: на широком планшете края не видны.
## Сдвигается за камерой с долей PARALLAX — так лес выглядит дальше домов.
class Backdrop extends Node2D:
	const PARALLAX := 0.35
	const SKY_W := 1150.0
	const TREE_W := 780.0
	const SKY_TOP := {"sky_day": Color8(84, 95, 90), "sky_dusk": Color8(53, 60, 83), "sky_night": Color8(16, 23, 41)}
	const FOREST_DAY := Color8(14, 17, 25)
	const FOREST_NIGHT := Color8(10, 12, 23)
	var view: VillageView

	func _ready() -> void:
		show_behind_parent = true

	func _draw() -> void:
		if view == null or view.def == null:
			return
		var n := view._nq()
		var gy := view.def.ground_rect.position.y
		var bottom := gy + 10.0
		# сумерки: день → сумерки к середине, сумерки → ночь ко второй половине
		var layers := [["sky_day", 1.0], ["sky_dusk", clampf(n * 2.2, 0.0, 1.0)], ["sky_night", clampf((n - 0.5) * 2.2, 0.0, 1.0)]]
		for l: Array in layers:
			var a: float = l[1]
			if a <= 0.0:
				continue
			var tex: Texture2D = view._tex[l[0]]
			var h := SKY_W * tex.get_height() / tex.get_width()
			draw_rect(Rect2(-3000, bottom - h - 3000, 6720, 3002), Color(SKY_TOP[l[0]], a))
			_strip(tex, bottom - h, SKY_W, h, Color(1, 1, 1, a))
		# Дальний лес ниже в кадре, чтобы над верхушками оставалось чистое небо.
		for i in range(2):
			var a := clampf(1.0 - (n - 0.3) * 1.6, 0.0, 1.0) if i == 0 else clampf(n * 1.6, 0.0, 1.0)
			if a <= 0.0:
				continue
			var tex: Texture2D = view._tex["treeline_day" if i == 0 else "treeline_night"]
			var h := TREE_W * tex.get_height() / tex.get_width()
			_strip(tex, gy + h * 0.5 - h, TREE_W, h, Color(1, 1, 1, a))
		var forest := FOREST_DAY.lerp(FOREST_NIGHT, n)
		draw_rect(Rect2(-3000, gy + 50.0, 6720, 60.0), forest)

	## Полоса картинки по всей ширине, копии через одну отражены — шов не виден.
	func _strip(tex: Texture2D, y: float, w: float, h: float, mod: Color) -> void:
		var x0 := VillageView.LOGICAL.x * 0.5 - w * 0.5
		for k in range(-3, 4):
			var r := Rect2(x0 + k * w, y, w, h)
			if k % 2 != 0:
				draw_set_transform(Vector2(r.end.x, y), 0.0, Vector2(-1, 1))
				draw_texture_rect(tex, Rect2(Vector2.ZERO, r.size), false, mod)
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture_rect(tex, r, false, mod)


## Еловые ветки по верхним углам поля: рамка кадра, поверх посёлка. Стоят на экране, а не в посёлке:
## камера под ними двигается. Не ловят касания.
class Branches extends Node2D:
	var view: VillageView

	func _ready() -> void:
		top_level = true
		z_index = 1

	func _draw() -> void:
		if view == null or view._field.size.x <= 0.0:
			return
		var tex: Texture2D = view._tex.branches
		var f := view._field
		var w := clampf(f.size.x * 0.24, 90.0, 260.0)
		var h := w * tex.get_height() / tex.get_width()
		draw_texture_rect(tex, Rect2(f.position.x - w * 0.08, f.position.y - h * 0.3, w, h), false)
		var w2 := w * 0.8
		var h2 := w2 * tex.get_height() / tex.get_width()
		draw_set_transform(Vector2(f.end.x + w2 * 0.1, f.position.y - h2 * 0.38), 0.0, Vector2(-1, 1))
		draw_texture_rect(tex, Rect2(0, 0, w2, h2), false)
		draw_set_transform(Vector2.ZERO)
