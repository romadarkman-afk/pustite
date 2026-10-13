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


func setup(village: VillageDef, open: int, names: PackedStringArray) -> void:
	def = village
	titles = names
	_font = ThemeFactory.font_bold()
	_load_art()
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
	_labels = Node2D.new()
	_labels.name = "Plaques"
	_labels.draw.connect(_draw_plaques)
	add_child(_labels)
	jobs_layer = JobLayer.new()
	jobs_layer.view = self
	jobs_layer.visible = false
	add_child(jobs_layer)
	set_open_count(open)


func set_open_count(n: int) -> void:
	open_count = clampi(n, 1, def.shelters.size())
	_build_glows()
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


var tunnel: Vector2i = Vector2i(-1, -1)   ## туннель между двумя убежищами: у обоих домов люк


func set_tunnel(t: Vector2i) -> void:
	if t != tunnel:
		tunnel = t
		_refresh()


## Где люк туннеля у дома i — справа от двери.
func hatch_pos(i: int) -> Vector2:
	var h: HouseDef = def.shelters[i]
	return h.pos + Vector2(h.size.x * 0.5 + 6.0, 16.0)


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

	# небо над лесом: днём пасмурное, ночью лиловое со звёздами и луной
	var sky_top := Color("4a5560").lerp(Color("0b0a24"), n)
	draw_rect(Rect2(-2000, -2400, 4720, 2000), sky_top)
	Art.vgrad(self, Rect2(-2000, -400, 4720, 600), sky_top, Color("9aa29a").lerp(Color("2a2448"), n))
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
		var cc := Color(0.78, 0.8, 0.8, 0.85).lerp(Color(0.16, 0.13, 0.3, 0.85), n)
		for b: Vector3 in [Vector3(0, 0, 34), Vector3(40, 7, 26), Vector3(-36, 9, 24), Vector3(74, 14, 18), Vector3(8, -22, 24)]:
			draw_circle(Vector2(cl.x + b.x * cl.z, cl.y + b.y * cl.z), b.z * cl.z, cc)
	# земля — картинка: площадь, тропы, река слева, лес по верхнему краю. Ночью её сменяет ночная
	# картинка того же места. Выше картинки лес темнеет и уходит в небо, края закрыты цветом земли.
	var gr := GROUND_RECT
	var forest := Color("1e2620").lerp(Color("0e1420"), n)
	draw_rect(Rect2(-2000, gr.position.y + 40.0, 4720, 3000), Color("4a4636").lerp(Color("1c2430"), n))
	Art.vgrad(self, Rect2(-2000, gr.position.y - 70.0, 4720, 80.0), Color(forest, 0.0), forest)
	draw_rect(Rect2(-2000, gr.position.y + 9.0, 4720, 40.0), forest)
	draw_texture_rect(_tex.ground_day, gr, false)
	if n > 0.0:
		draw_texture_rect(_tex.ground_night, gr, false, Color(1, 1, 1, n))
	Art.vgrad(self, Rect2(gr.position.x, gr.position.y, gr.size.x, 46.0), forest, Color(forest, 0.0))

	# дома, колодец, фонари, поленница и бочка — предметы в слое толпы (VillageProp):
	# кто стоит за домом, того дом закрывает. Здесь только то, что лежит на земле.
	_draw_hatches(n, k)
	_draw_fish(n, k)
	_draw_fences(n, k)
	draw_usec_total += Time.get_ticks_usec() - t0


## Перерисовать посёлок вместе с предметами и табличками.
func _refresh() -> void:
	queue_redraw()
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
	_add_prop(def.well, func(ci: CanvasItem) -> void: _draw_well(ci, _nq()))
	for li in range(def.lamps.size()):
		var lidx := li
		_add_prop(def.lamps[li], func(ci: CanvasItem) -> void:
			_draw_lamp_post(ci, def.lamps[lidx], _nq(), _lamp_on(lidx, _nq()) * _lamp_fuel(lidx)))
	for j: JobDef in def.jobs:
		var jp := j.pos
		match j.kind:
			JobDef.Kind.WOOD:
				_add_prop(jp + Vector2(36, 4), func(ci: CanvasItem) -> void: _prop(ci, _tex.woodpile, jp + Vector2(36, 4), 76.0, _nq()))
			JobDef.Kind.LAMP:
				_add_prop(jp + Vector2(-30, 3), func(ci: CanvasItem) -> void: _prop(ci, _tex.barrel, jp + Vector2(-30, 3), 30.0, _nq()))


func _add_prop(at: Vector2, paint: Callable) -> void:
	var p := VillageProp.new()
	p.position = at
	p.paint = paint
	crowd.add_child(p)
	_props.append(p)


## Убежище: открытое или заколоченное, с оберегом; выбранное ночью — в тёплой рамке.
func _paint_shelter(ci: CanvasItem, i: int) -> void:
	var h: HouseDef = def.shelters[i]
	var n := _nq()
	_draw_house(ci, h, 1 if i < open_count else 2, n, _lit(h, n), talismans[i] if i < talismans.size() else 2)
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
const GROUND_RECT := Rect2(-88.8, 31.6, 816.0, 609.3)
const ART_FILES: PackedStringArray = ["house_day", "house_night", "barn_day", "barn_night", "church_day", "church_night",
	"cellar_day", "cellar_night", "garage_day", "garage_night", "shed_day", "shed_night", "lamp_day", "lamp_night",
	"well", "woodpile", "barrel", "talisman"]


func _load_art() -> void:
	for f: String in ART_FILES:
		_tex[f] = load(ART_DIR + f + ".png")
	for g: String in GROUND_FILES:
		_tex[g] = load(ART_DIR + g + ".jpg")


## Дома слева от площади смотрят дверью вправо, к площади: картинку отражаем.
## Гараж тоже отражён: так он уходит влево от двери и не закрывает поленницу.
func _flip(h: HouseDef) -> bool:
	return h.pos.x < def.square_center.x - 20.0 or h.kind == HouseDef.Kind.GARAGE


func _art(h: HouseDef) -> Array:
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
	_blit(ci, _tex[a[0] + "_day"], r, flip, mod)
	if state != 2 and lit > 0.0:
		_blit(ci, _tex[a[0] + "_night"], r, flip, Color(1, 1, 1, lit * (1.0 if state == 1 else 0.85)))
	var dr := door_rect(h)
	if state == 2:
		Art._planks(ci, dr.grow(2.0), n, Art.ink(n))
	elif state == 1:
		_draw_talisman(ci, dr, flip, n, tal)


## Оберег на стене у двери, со стороны от площади. tal: 2 целый, 1 треснул, 0 расколот.
func _draw_talisman(ci: CanvasItem, dr: Rect2, flip: bool, n: float, tal: int) -> void:
	var w := clampf(dr.size.x * 0.6, 18.0, 24.0)
	var hh: float = w * _tex.talisman.get_height() / _tex.talisman.get_width()
	var cx := dr.position.x - w * 0.62 if not flip else dr.end.x + w * 0.62
	var r := Rect2(cx - w * 0.5, dr.position.y + dr.size.y * 0.18, w, hh)
	var mod := _night_mod(n * 0.6)
	if tal <= 0:
		mod = mod * Color(0.62, 0.42, 0.42)
	elif tal == 1:
		mod = mod.darkened(0.12)
	_blit(ci, _tex.talisman, r, false, mod)
	if tal < 2:
		var c := r.get_center() + Vector2(0, hh * 0.12)
		var crack := PackedVector2Array([c + Vector2(3, -w * 0.42), c + Vector2(-1, -2), c + Vector2(2, 3), c + Vector2(-2, w * 0.42)])
		ci.draw_polyline(crack, Color(0.08, 0.05, 0.06), 2.6, true)
		if tal <= 0:
			ci.draw_polyline(crack, ThemeFactory.BLOOD, 1.2, true)


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
		var hr := house_rect(h).grow_individual(-0.15 * house_rect(h).size.x, -0.3 * house_rect(h).size.y, -0.15 * house_rect(h).size.x, 0.0)
		poly.polygon = PackedVector2Array([hr.position, Vector2(hr.end.x, hr.position.y),
			Vector2(hr.end.x, h.pos.y - 2), Vector2(hr.position.x, h.pos.y - 2)])
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
		var hr := house_rect(h)
		s.position = hr.get_center() + Vector2(0, hr.size.y * 0.1)
		s.scale = Vector2(hr.size.x / 80.0, hr.size.y / 95.0)
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
	const CREATURE_PATH := "res://assets/village/creature.png"
	const SPOTS := [Vector2(160, 158), Vector2(300, 176), Vector2(432, 178), Vector2(640, 162), Vector2(28, 330)]
	var creature_tex: Texture2D
	var night: float = 0.0
	var _blink: PackedFloat32Array = PackedFloat32Array()
	var _closed: PackedByteArray = PackedByteArray()
	var _t := 0.0

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
		var o := Vector2(300, 245)
		var tilt := 0.05 * sin(_t * 0.7)
		draw_set_transform(o, tilt, Vector2(1.0, 1.08))
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
