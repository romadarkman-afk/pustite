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
const SKY_SHARE := 0.50                   ## горизонт не уходит за верх поля на вытянутых экранах
const BUBBLE_HEADROOM := 210.0             ## место над верхним жителем для пузыря на планшетах
const SAFE_X := Vector2(84, 624)          ## куда можно ставить жителей: слева половина имени, справа колонка отметок
const GROUND_BLEED := 4.0                 ## картинка земли выступает за край кадра и не открывает подложку
static var _shadow_outline_cache: Dictionary = {}
static var _water_cache: Dictionary = {}   ## земля -> Image маски воды или null

signal night_changed(value: float)

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
var _lamp_glows: Array[LightHalo] = []
var _house_glows: Array[LightHalo] = []
var _lamp_lights: Array[PointLight2D] = []
var _tex: Dictionary = {}                  ## имя картинки -> Texture2D
var _realistic: Dictionary = {}             ## новые спрайты уже содержат мягкую контактную тень
var _ground_is_composite := false          ## старые картинки земли уже содержат небо и лес
var _ground_cover_scale := 1.0             ## минимальный масштаб текущего перехода кадра, чтобы край земли не открыл фон
var _props: Array[VillageProp] = []        ## дома, колодец, фонари и реквизит — в слое толпы
var _labels: Node2D                        ## таблички убежищ — над толпой
var _occluders: Array[LightOccluder2D] = []
var _backdrop: Backdrop                    ## небо за посёлком: сдвигается медленнее камеры
var _forest: Backdrop                      ## дальний лес перед небом
## Скорости слоёв относительно камеры (TASK-089): дом и земля 1,0. Лес чуть отстаёт, туман и ветки чуть обгоняют.
const SPEED_SKY := 0.65
const SPEED_FOREST := 0.9
const SPEED_FOG := 1.05
const SPEED_BRANCHES := 1.15
const FOG_X := 360.0                       ## где стоят полосы тумана без сдвига камеры
## false на ночном экране и вне дня: слои стоят на местах, как без камеры
var parallax := true:
	set(v):
		if v != parallax:
			parallax = v
			_apply_parallax()
var _branches: Branches                    ## ветки по верхним углам поля — поверх посёлка
var _fog_bands: Array[Sprite2D] = []       ## полосы тумана над землёй, ползут вбок
var _smoke: Node2D                         ## дым из труб
var _field := Rect2()                      ## где поле на экране (для веток)
var blood_spots := PackedVector2Array()    ## утром: где ночью погибли (до следующей ночи)
var trail_doors := PackedVector2Array()    ## утром: к каким дверям из леса ведут следы
var loss_houses: Dictionary = {}            ## дом -> 1 память о погибшем, 2 изгнание
var _empty_loss: Dictionary = {}           ## то же, но только дома, где никто не живёт: они пустеют (TASK-079)
var _creak_in := 4.0                       ## через сколько секунд хлопнет дверь изгнанного
var _gust := 0.0                           ## порыв ветра: 1 в момент скрипа, затухает за 1,7 с
var _ajar_acc := 0.0
var rain := false                          ## лужи после дождливой ночи

## Камера. Днём приближена и следует за игроком по горизонтали; в остальных фазах
## показывает посёлок целиком. Двигается только узел: посёлок от этого не перерисовывается.
var follow: Node2D                         ## за кем следит камера; null — стоит на месте
var cam_x: float = 360.0                   ## какая точка посёлка по горизонтали в центре кадра
var _vp_w: float = 720.0
var _framing := false                      ## идёт переход кадра — камера не дёргается
var browsing := false                      ## игрок тянет карту пальцем: камера не бежит за героем (отзыв тестера 0.65)
var _browse_idle := 0.0                    ## сколько секунд после последнего сдвига пальцем
const BROWSE_RETURN_SEC := 10.0            ## через столько секунд без касаний камера возвращается к герою
var lamps_fueled: int = 99                 ## сколько фонарей заправлено на эту ночь
var talismans: PackedInt32Array = PackedInt32Array()   ## состояние оберегов открытых убежищ: 2 целый … 0 расколот
var jobs_layer: JobLayer
var _tw_frame: Tween
var _tw_night: Tween
var _t: float = 0.0
var _vignette: Sprite2D
var _unease := 0.0
var _contact_shadow_texture: Texture2D
var simplified_graphics := false
var weather: WeatherLayer                  ## осадки и сезонные частицы (TASK-061)
var ground_fx: GroundFx                    ## снег, лужи и трава на земле: шейдеры и MultiMesh
var sky_fx: GroundFx                       ## тени облаков поверх толпы
var weather_state: Dictionary = Weather.EMPTY.duplicate()
var snow_cover := 0.0                      ## 0..1: сколько снега лежит на земле


func setup(village: VillageDef, open: int, names: PackedStringArray) -> void:
	def = village
	titles = names
	_font = ThemeFactory.font_bold()
	_load_art()
	_backdrop = Backdrop.new()
	_backdrop.view = self
	_backdrop.part = "sky"
	_backdrop.speed = SPEED_SKY
	add_child(_backdrop)
	_backdrop.visible = not _ground_is_composite
	_forest = Backdrop.new()
	_forest.view = self
	_forest.part = "forest"
	_forest.speed = SPEED_FOREST
	_forest.name = "Forest"
	add_child(_forest)
	_forest.visible = not _ground_is_composite
	ground_fx = GroundFx.new()
	add_child(ground_fx)
	ground_fx.setup(self, "ground")
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
	crowd.set_color_grade(def.color_grade)
	_build_props()
	sky_fx = GroundFx.new()
	add_child(sky_fx)
	sky_fx.setup(self, "sky")
	_smoke = Node2D.new()
	_smoke.name = "Smoke"
	add_child(_smoke)
	_labels = Node2D.new()
	_labels.name = "Plaques"
	_labels.draw.connect(_draw_plaques)
	add_child(_labels)
	_branches = Branches.new()
	_branches.view = self
	_branches.visible = false # верхние ветки перекрывали небо; дальний лес остаётся на горизонте
	add_child(_branches)
	jobs_layer = JobLayer.new()
	jobs_layer.view = self
	jobs_layer.visible = false
	add_child(jobs_layer)
	weather = WeatherLayer.new()
	weather.view = self
	add_child(weather)
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
	if crowd != null:
		crowd.set_color_grade(def.color_grade)
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
	set_simplified_graphics(simplified_graphics)
	_build_props()
	if ground_fx != null:
		ground_fx.refresh()
	if sky_fx != null:
		sky_fx.refresh()
	set_open_count(open)
	if weather != null:
		weather.refresh_geometry()
	_apply_weather_grade()


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
	night_changed.emit(night)
	var thick := 1.0 + 1.6 * _fog_k()
	if _fog != null:
		_fog.modulate.a = clampf((0.35 + 0.65 * night) * thick, 0.0, 1.0)
		_dust.modulate.a = 0.12 + 0.88 * (1.0 - night)
	for i in range(_fog_bands.size()):
		_fog_bands[i].modulate = Color(0.8, 0.86, 0.9).lerp(Color(0.62, 0.7, 0.86), night)
		_fog_bands[i].modulate.a = clampf((0.24 + 0.4 * night) * (1.0 if i == 0 else 0.75) * (1.0 + 0.9 * _fog_k()), 0.0, 1.0)
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
	var empty := _empty_losses(houses)
	if loss_houses == houses and _empty_loss == empty:
		return
	loss_houses = houses.duplicate()
	_empty_loss = empty
	_creak_in = minf(_creak_in, 2.5)
	_refresh()


## Из домов с потерей оставляем те, где никто не живёт: у них гаснут окна, а у погибшего ещё и заколочена дверь.
func _empty_losses(houses: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in houses:
		var lived := false
		if Game.m != null:
			for resident: Villager in Game.m.villagers:
				if resident.alive and not resident.departed and resident.night_house == int(key):
					lived = true
					break
		if not lived:
			out[int(key)] = int(houses[key])
	return out


## Пустой дом погибшего: тёмные окна, доски крестом, у двери никто не стоит.
func dead_house(i: int) -> bool:
	return int(_empty_loss.get(i, 0)) == 1


## Пустой дом изгнанного: дверь оставлена открытой.
func ajar_house(i: int) -> bool:
	return int(_empty_loss.get(i, 0)) == 2


func ajar_houses() -> Array[int]:
	var out: Array[int] = []
	for key: Variant in _empty_loss:
		if int(_empty_loss[key]) == 2:
			out.append(int(key))
	return out


## Зона перед дверью пустого дома погибшего: сюда не ставят и не водят жителей.
func dead_zone(i: int) -> Rect2:
	var h: HouseDef = def.shelters[i]
	var door := door_rect(h)
	var half := maxf(door.size.x * 0.5 + 18.0, 30.0)
	return Rect2(door.get_center().x - half, h.pos.y - 4.0, half * 2.0, 34.0)


## Освещённость окон убежища: в доме погибшего огня нет.
func house_lit(i: int, n: float) -> float:
	if dead_house(i):
		return 0.0
	return _lit(def.shelters[i], n)


## Вписать полосу с домами в прямоугольник поля. vp_w — ширина экрана.
## Кадрировать поле в прямоугольник экрана rect. zoom > 1 — приблизить посёлок
## (по высоте он всё равно поместится в поле), камера встаёт на focus_x.
func frame_to(rect: Rect2, vp_w: float, dur: float, zoom: float = 1.0, focus_x: float = -1.0, reserve_speech_space: bool = false) -> void:
	_field = rect
	browsing = false
	if _branches != null:
		_branches.queue_redraw()
	var base := minf(vp_w / (LOGICAL.x * SIDE_VISIBLE), rect.size.y / BAND.size.y)
	var s := minf(base * zoom, rect.size.y / BAND.size.y)
	s = maxf(s, 0.5)
	var sky_share := SKY_SHARE
	var top_head_y := INF
	if crowd != null:
		for figure: VillagerFigure in crowd.figures.values():
			if not is_instance_valid(figure):
				continue
			var height := figure.look.height if figure.look != null else 1.0
			top_head_y = minf(top_head_y, figure.position.y - VillagerFigure.FIG_TOP * height)
	if reserve_speech_space and is_finite(top_head_y):
		# пузырь не выше MAX_SHARE поля (Bubbles), поэтому на невысоком поле места над головами нужно меньше, чем на планшете
		var headroom := minf(BUBBLE_HEADROOM, rect.size.y * Bubbles.MAX_SHARE + 56.0)
		var extra_y := maxf(0.0, rect.size.y - BAND.size.y * s)
		var head_gap := extra_y * sky_share + (top_head_y - BAND.position.y) * s
		if head_gap < headroom:
			# Сначала используем свободное место сверху. Если его не хватает,
			# чуть уменьшаем кадр, чтобы верхняя реплика оставалась над жителем.
			sky_share = 1.0
			var head_depth := BAND.end.y - top_head_y
			if head_depth > 0.0:
				var needed_scale := (rect.size.y - headroom) / head_depth
				if needed_scale > 0.0:
					s = maxf(0.5, minf(s, needed_scale))
	if zoom > 1.0:
		# приближенная камера не показывает пустоту за краями посёлка: посёлок (с запасом 18 ед. с каждой стороны) не уже экрана
		s = maxf(s, minf(rect.size.y / BAND.size.y, vp_w / (LOGICAL.x + 36.0)))
	_vp_w = vp_w
	_ground_cover_scale = minf(scale.x if scale.x > 0.01 else s, s)
	queue_redraw()
	var camera_is_framed := focus_x >= 0.0 or zoom > 1.0
	if focus_x >= 0.0:
		cam_x = focus_x
	elif zoom <= 1.0:
		cam_x = LOGICAL.x * 0.5
	if camera_is_framed:
		cam_x = _clamp_cam(cam_x, s)
	else:
		# При полном обзоре центрируем логическую полосу по экрану. Границы разных карт
		# имеют разные смещения и не должны сдвигать посёлок в сторону.
		cam_x = LOGICAL.x * 0.5
	_apply_parallax()
	# Полоса с домами остаётся в поле, лишняя высота делится между небом и передним планом.
	var extra := maxf(0.0, rect.size.y - BAND.size.y * s)
	var target := Vector2(vp_w * 0.5 - cam_x * s, rect.position.y + extra * sky_share - BAND.position.y * s)
	if _tw_frame != null:
		_tw_frame.kill()
	if dur <= 0.0:
		position = target
		scale = Vector2(s, s)
		_ground_cover_scale = s
		_framing = false
		queue_redraw()
		return
	_framing = true
	_tw_frame = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw_frame.tween_property(self, "position", target, dur)
	_tw_frame.tween_property(self, "scale", Vector2(s, s), dur)
	_tw_frame.chain().tween_callback(func() -> void:
		_framing = false
		_ground_cover_scale = scale.x
		queue_redraw()
	)


## Слои стоят там, куда их двигает камера: слой со скоростью k смещается относительно посёлка на (1 - k) от ухода камеры.
## Ветки экранные: по экрану они уезжают не дальше, чем выступают за край поля, поэтому щель не открывается.
func _apply_parallax() -> void:
	var d := (cam_x - LOGICAL.x * 0.5) if parallax else 0.0
	if _backdrop != null:
		_backdrop.position.x = d * (1.0 - SPEED_SKY)
	if _forest != null:
		_forest.position.x = d * (1.0 - SPEED_FOREST)
	for b: Sprite2D in _fog_bands:
		b.position.x = FOG_X + d * (1.0 - SPEED_FOG)
	if _branches != null:
		var hang := _branches.hang()
		_branches.position.x = clampf(-(SPEED_BRANCHES - 1.0) * d * scale.x, -hang, hang)


## Фоновые картинки закрывают окно с небольшим запасом, даже если их исходная ширина короче кадра.
## Добавляется только недостающая ширина, симметрично с обоих краёв.
func _ground_draw_rect() -> Rect2:
	var bounds: Rect2 = def.ground_rect if def != null else GROUND_RECT
	if _vp_w <= 0.0 or _ground_cover_scale <= 0.01:
		return bounds
	var needed := _vp_w / _ground_cover_scale + GROUND_BLEED * 2.0 + 2.0
	if needed > bounds.size.x:
		var extra := needed - bounds.size.x
		bounds.position.x -= extra * 0.5
		bounds.size.x += extra
	return bounds


## Центр кадра не уводит камеру за края посёлка.
func _clamp_cam(x: float, s: float) -> float:
	var bounds: Rect2 = def.ground_rect if def != null else GROUND_RECT
	var half := _vp_w / (2.0 * s)
	# Карты шире логической сцены и у разных регионов разный центр. Камеру ограничивают
	# реальные границы фоновой земли, иначе на широком окне открывается соседний фон.
	var lo := bounds.position.x + GROUND_BLEED + half
	var hi := bounds.end.x - GROUND_BLEED - half
	if lo >= hi:
		return bounds.get_center().x
	return clampf(x, lo, hi)


## Сдвиг камеры пальцем: dx в единицах посёлка, плюс вправо. Герой при этом стоит на месте.
func pan_by(dx: float) -> void:
	if _framing:
		return
	browsing = true
	_browse_idle = 0.0
	cam_x = _clamp_cam(cam_x + dx, scale.x)
	position.x = _vp_w * 0.5 - cam_x * scale.x
	_apply_parallax()


## Камера снова идёт за героем: игрок отправил его в путь или перешёл на другой экран.
func resume_follow() -> void:
	browsing = false


## Камера мягко догоняет того, за кем следит.
func _follow_step(delta: float) -> void:
	if follow == null or not is_instance_valid(follow) or _framing:
		return
	if browsing:
		_browse_idle += delta
		if _browse_idle < BROWSE_RETURN_SEC:
			return
		browsing = false
	var want := _clamp_cam(follow.position.x, scale.x)
	if absf(want - cam_x) < 0.05:
		return
	cam_x = want if Juice.instant else lerpf(cam_x, want, 1.0 - exp(-5.0 * delta))
	position.x = _vp_w * 0.5 - cam_x * scale.x
	_apply_parallax()


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


## Погода поля (TASK-061): осадки, туман, снег на земле и сезонная тонировка.
func set_weather(state: Dictionary) -> void:
	weather_state = state
	snow_cover = float(state.get("cover", 0.0)) if bool(state.get("active", false)) else 0.0
	if weather != null:
		weather.apply(state)
	_apply_weather_grade()
	set_night(night)
	_apply_fog_amount()
	_refresh()


func _fog_k() -> float:
	return float(weather_state.get("fog", 0.0)) if bool(weather_state.get("active", false)) else 0.0


## Сезонный цвет. На упрощённой графике цветокоррекции нет.
func season_mod() -> Color:
	if simplified_graphics or not bool(weather_state.get("active", false)):
		return Color.WHITE
	return Weather.tint(int(weather_state.get("season", Weather.Season.SUMMER)))


func _apply_weather_grade() -> void:
	if crowd != null and def != null:
		crowd.set_color_grade(def.color_grade * season_mod())
		var fx := figure_fx()
		crowd.set_weather_fx(fx.x, fx.y)


## Иней и влага на фигурах: x — иней, y — влага. На упрощённой графике шейдера фигур нет.
func figure_fx() -> Vector2:
	if simplified_graphics or not bool(weather_state.get("active", false)):
		return Vector2.ZERO
	var cover := float(weather_state.get("cover", 0.0))
	var power := float(weather_state.get("power", 0.0))
	var season := int(weather_state.get("season", Weather.Season.SUMMER))
	var frost := 0.0
	var wet := 0.0
	match int(weather_state.get("precip", Weather.Precip.NONE)):
		Weather.Precip.SNOW:
			frost = clampf(cover * 0.6 + power * 0.6, 0.0, 1.0)
		Weather.Precip.RAIN:
			wet = clampf(power * 1.3, 0.0, 1.0)
	if season == Weather.Season.WINTER:
		frost = maxf(frost, cover * 0.7)
	elif season == Weather.Season.SPRING:
		wet = maxf(wet, 0.3 + float(weather_state.get("fog", 0.0)) * 0.3)
		frost = maxf(frost, cover * 0.5)
	return Vector2(frost, wet)


func _apply_fog_amount() -> void:
	if _fog != null:
		var base := 7 if simplified_graphics else 14
		_fog.amount = clampi(roundi(base * (1.0 + _fog_k())), base, 36)


func set_simplified_graphics(on: bool) -> void:
	simplified_graphics = on
	_apply_fog_amount()
	if _dust != null:
		_dust.amount = 12 if on else 24
	for light: PointLight2D in _lamp_lights:
		light.shadow_enabled = not on
	if weather != null:
		weather.set_simplified(on)
	_apply_weather_grade()
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
		_lamp_lights[i].energy = 0.46 * on_l
	for i in range(_lamp_glows.size()):
		var on := _lamp_on(i, night) * _lamp_fuel(i)
		if on > 0.0 and on < 1.0 and randf() < 0.35:
			on *= 0.15               # включение: лампа пару раз мигает
		_lamp_glows[i].set_intensity(on * 0.72)
	_ajar_step(delta)
	for i in range(_house_glows.size()):
		var house_index := int(i / 2)
		var lit := house_lit(house_index, night) if house_index < def.shelters.size() else night
		_house_glows[i].set_intensity(lit * (0.62 if house_index != selected_house else 0.82))


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

	# Небо и дальний лес рисует Backdrop (он за посёлком и сдвигается медленнее камеры).
	# Земля содержит площадку и окружение. Варианты актов сохраняют те же ориентиры.
	var gr := def.ground_rect
	var ground_draw := _ground_draw_rect()
	var forest := Backdrop.FOREST_DAY.lerp(Backdrop.FOREST_NIGHT, n)
	draw_rect(Rect2(-2000, gr.position.y + 40.0, 4720, 3000), Color("4a4636").lerp(Color("1c2430"), n))
	var place_grade: Color = Color.WHITE.lerp(def.color_grade, 0.2) * season_mod()
	draw_texture_rect(_tex.ground_day, ground_draw, false, place_grade)
	if n > 0.0:
		draw_texture_rect(_tex.ground_night, ground_draw, false, Color(place_grade, n))
	if not _tex.has("real_sky_day"):
		Art.vgrad(self, Rect2(ground_draw.position.x, gr.position.y, ground_draw.size.x, 40.0), Color(forest, 0.75), Color(forest, 0.0))
	# Широкая дымка растворяет горизонт в фоне, не оставляя резкой полосы над землёй.
	var mist := Color8(118, 128, 140).lerp(Color8(44, 54, 76), n)
	Art.vgrad(self, Rect2(-2000, gr.position.y - 52.0, 4720, 64.0), Color(mist, 0.0), Color(mist, 0.46))
	Art.vgrad(self, Rect2(-2000, gr.position.y + 12.0, 4720, 104.0), Color(mist, 0.46), Color(mist, 0.0))

	# дома, колодец, фонари, поленница и бочка — предметы в слое толпы (VillageProp):
	# кто стоит за домом, того дом закрывает. Здесь только то, что лежит на земле.
	_draw_traces(n)
	_draw_hatches(n, k)
	draw_usec_total += Time.get_ticks_usec() - t0


## Перерисовать посёлок вместе с предметами и табличками.
func _refresh() -> void:
	queue_redraw()
	if _backdrop != null:
		_backdrop.queue_redraw()
	if _forest != null:
		_forest.queue_redraw()
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
			var realistic_prop := REALISTIC_ART_DIR + id + ".png"
			var has_realistic := ResourceLoader.exists(realistic_prop)
			_realistic[id] = has_realistic
			var prop_path := realistic_prop if has_realistic else ART_DIR + id + ".png"
			_tex[id] = load(prop_path) as Texture2D
		var at: Vector2 = pr.pos
		var pw := float(pr.get("w", 60.0))
		var fl := bool(pr.get("flip", false))
		_add_prop(at, func(ci: CanvasItem) -> void: _decor_prop(ci, id, at, pw, fl, _nq()))
	for row: Vector2 in def.fences:
		var fence_row := row
		_add_prop(fence_row, func(ci: CanvasItem) -> void: _paint_fence(ci, fence_row))
	for j: JobDef in def.jobs:
		var jp := j.pos
		match j.kind:
			JobDef.Kind.WOOD:
				_add_prop(jp + Vector2(36, 4), func(ci: CanvasItem) -> void: _prop(ci, _tex.woodpile, jp + Vector2(36, 4), 76.0, _nq(), bool(_realistic.get("woodpile", false))))
			JobDef.Kind.LAMP:
				_add_prop(jp + Vector2(-30, 3), func(ci: CanvasItem) -> void: _prop(ci, _tex.barrel, jp + Vector2(-30, 3), 30.0, _nq(), bool(_realistic.get("barrel", false))))


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
	var dead := dead_house(i)
	# дом погибшего пуст: доски крестом, окна тёмные, оберега нет
	_draw_house(ci, h, 2 if dead else (1 if i < open_count else 2), n, house_lit(i, n), talismans[i] if i < talismans.size() else 2)
	var loss := int(loss_houses.get(i, 0))
	if loss > 0:
		var empty := _empty_loss.has(i)
		if empty and not dead:
			var art := _art(h)
			_blit(ci, _tex[art[0] + "_day"], house_rect(h), _flip(h), Color(0.07, 0.09, 0.13, 0.56))
		var door := door_rect(h)
		if loss == 1:
			if not dead:
				# Траурная лента видна в занятом доме; в пустом вместо неё доски.
				ci.draw_line(door.position + Vector2(-3, 1), door.position + Vector2(6, 17), Color("16161c"), 5.0)
				ci.draw_line(door.position + Vector2(6, 1), door.position + Vector2(-3, 17), Color("292833"), 4.0)
		else:
			_draw_ajar(ci, door, _flip(h), n)
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


## Полные видимые области предметов для брызг и ряби. Не меняет зоны движения жителей.
func rain_blocked_zones() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if def == null:
		return out
	for house: HouseDef in def.shelters + def.decor:
		out.append(house_rect(house))
	var well_at := def.well + Vector2(0, 8)
	out.append(_rain_prop_rect(well_at, 80.0, _tex.get("well")))
	for at: Vector2 in def.lamps:
		var lamp: Texture2D = _tex.get("lamp_day")
		if lamp != null:
			var w := LAMP_H * lamp.get_width() / lamp.get_height()
			out.append(Rect2(at.x - LAMP_BASE_X * w, at.y - LAMP_H * 0.98, w, LAMP_H))
	for prop: Dictionary in def.props:
		var at: Vector2 = prop.pos
		var tex: Texture2D = _tex.get(String(prop.id))
		out.append(_rain_prop_rect(at, float(prop.get("w", 60.0)), tex))
	for row: Vector2 in def.fences:
		out.append(fence_rect(row))
	for job: JobDef in def.jobs:
		if job.kind == JobDef.Kind.WOOD:
			out.append(_rain_prop_rect(job.pos + Vector2(36, 4), 76.0, _tex.get("woodpile")))
		elif job.kind == JobDef.Kind.LAMP:
			out.append(_rain_prop_rect(job.pos + Vector2(-30, 3), 30.0, _tex.get("barrel")))
	return out


func _rain_prop_rect(at: Vector2, width: float, tex: Texture2D) -> Rect2:
	var height := width
	if tex != null and tex.get_width() > 0:
		height = width * tex.get_height() / tex.get_width()
	return Rect2(at.x - width * 0.5, at.y - height, width, height)


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
const REALISTIC_ART_DIR := "res://assets/village/realistic/"
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
	"well", "woodpile", "barrel", "talisman", "talisman_cracked", "talisman_broken", "boards", "hatch"]
## Небо, дальний лес, ветки, туман и дым — общие для всех карт и стран.
const MAP_FILES: PackedStringArray = ["sky_day.jpg", "sky_dusk.jpg", "sky_night.jpg", "treeline_day.png", "treeline_night.png",
	"branches.png", "fog.png", "smoke.png", "puddles.png", "footprints.png", "blood_mud.png"]
## Где у дома труба на картинке (доли ширины и высоты, дом не отражён). Нет в списке — дом без трубы.
const CHIMNEY := {HouseDef.Kind.HOME: Vector2(0.62, 0.05), HouseDef.Kind.CHURCH: Vector2(0.76, 0.39), HouseDef.Kind.GARAGE: Vector2(0.72, 0.04)}


## Фоны и графика общие для всех языков. Локаль меняет только текст.
func _load_art() -> void:
	var chapter_visuals: Dictionary = {}
	if not Game.chapter.is_empty():
		var chapter_world: Dictionary = Game.chapter.get("world", {})
		chapter_visuals = chapter_world.get("visuals", {})
	for f: String in ART_FILES:
		var realistic_path := REALISTIC_ART_DIR + f + ".png"
		var has_realistic := ResourceLoader.exists(realistic_path)
		_realistic[f] = has_realistic
		var source_path := realistic_path if has_realistic else ART_DIR + f + ".png"
		_tex[f] = load(source_path) as Texture2D
	var fence_path := REALISTIC_ART_DIR + "fence.png"
	_realistic["fence"] = ResourceLoader.exists(fence_path)
	_tex["fence"] = load(fence_path) as Texture2D if _realistic["fence"] else null
	_tex["door_ajar"] = null
	for ajar_dir: String in [REALISTIC_ART_DIR, ART_DIR]:
		if _tex["door_ajar"] == null and ResourceLoader.exists(ajar_dir + "door_ajar.png"):
			_tex["door_ajar"] = load(ajar_dir + "door_ajar.png") as Texture2D
	_ground_is_composite = false
	for g: String in GROUND_FILES:
		var ground_name := g.replace("ground", def.ground if def != null else "ground")
		var realistic_ground := REALISTIC_ART_DIR + ground_name + ".jpg"
		var chapter_path := String(chapter_visuals.get(g, ""))
		var ground_path := ART_DIR + ground_name + ".jpg"
		if ResourceLoader.exists(realistic_ground):
			ground_path = realistic_ground
		if not chapter_path.is_empty() and ResourceLoader.exists(chapter_path):
			ground_path = chapter_path
		_ground_is_composite = _ground_is_composite or (ground_path.begins_with(ART_DIR) and not ground_path.begins_with(REALISTIC_ART_DIR))
		_tex[g] = load(ground_path) as Texture2D
	if is_instance_valid(_backdrop):
		_backdrop.visible = not _ground_is_composite
	if is_instance_valid(_forest):
		_forest.visible = not _ground_is_composite
	var real_sky := true                         # настоящее небо есть: старое не грузим, это 18 МиБ видеопамяти зря (TASK-095)
	for f: String in ["sky_day", "sky_dusk", "sky_night"]:
		real_sky = real_sky and ResourceLoader.exists(REALISTIC_ART_DIR + f + ".jpg")
	for f: String in MAP_FILES:
		var map_key := f.get_basename()
		if real_sky and map_key.begins_with("sky_"):
			_tex.erase(map_key)
			continue
		var chapter_path := String(chapter_visuals.get(map_key, ""))
		var map_path := ART_DIR + f
		if not chapter_path.is_empty() and ResourceLoader.exists(chapter_path):
			map_path = chapter_path
		_tex[map_key] = load(map_path) as Texture2D
	for f: String in ["sky_day", "sky_dusk", "sky_night"]:
		var realistic_sky := REALISTIC_ART_DIR + f + ".jpg"
		if ResourceLoader.exists(realistic_sky):
			_tex["real_" + f] = load(realistic_sky) as Texture2D


## Дома слева от площади смотрят дверью вправо, к площади: картинку отражаем.
## Гараж тоже отражён: так он уходит влево от двери и не закрывает поленницу.
func _flip(h: HouseDef) -> bool:
	return h.pos.x < def.square_center.x - 20.0 or h.kind == HouseDef.Kind.GARAGE


func _art(h: HouseDef) -> Array:
	if not h.art.is_empty():
		var key := "maps/" + h.art
		if not _tex.has(key + "_day"):
			var realistic_day := REALISTIC_ART_DIR + key + "_day.png"
			var has_realistic := ResourceLoader.exists(realistic_day)
			_realistic[key] = has_realistic
			var day_path := realistic_day if has_realistic else ART_DIR + key + "_day.png"
			_tex[key + "_day"] = load(day_path) as Texture2D
			var np := (REALISTIC_ART_DIR if has_realistic else ART_DIR) + key + "_night.png"
			_tex[key + "_night"] = load(np) as Texture2D if ResourceLoader.exists(np) else null
		return [key, h.art_w, h.art_door]
	return HOUSE_ART.get(h.kind, HOUSE_ART[HouseDef.Kind.HOME])


## Где на поле картинка дома (в координатах посёлка).
func ground_texture() -> Texture2D:
	return _tex.get("ground_day")


## Картинка земли для поиска травянистых мест. Пустая, если текстуры нет.
func ground_image() -> Image:
	var t: Texture2D = _tex.get("ground_day")
	if t == null:
		return null
	return t.get_image()


## Вода на земле: белое в маске assets/village/<земля>.png с приставкой water_. Нет файла: воды нет.
## Дома и дела на воду не ставим, самотест это проверяет.
func water_image() -> Image:
	if def == null:
		return null
	if not _water_cache.has(def.ground):
		var path := ART_DIR + "water_" + def.ground + ".png"
		var img: Image = null
		if ResourceLoader.exists(path):
			var t := load(path) as Texture2D
			img = t.get_image() if t != null else null
		_water_cache[def.ground] = img
	return _water_cache[def.ground]


func water_at(p: Vector2) -> bool:
	var img := water_image()
	if img == null:
		return false
	var gr := def.ground_rect
	var u := int((p.x - gr.position.x) / gr.size.x * img.get_width())
	var v := int((p.y - gr.position.y) / gr.size.y * img.get_height())
	if u < 0 or v < 0 or u >= img.get_width() or v >= img.get_height():
		return false
	return img.get_pixel(u, v).r > 0.5


## Какая доля прямоугольника стоит на воде.
func water_share(r: Rect2) -> float:
	var hit := 0
	var total := 0
	var y := r.position.y
	while y <= r.end.y:
		var x := r.position.x
		while x <= r.end.x:
			total += 1
			if water_at(Vector2(x, y)):
				hit += 1
			x += 6.0
		y += 6.0
	return float(hit) / maxf(total, 1)


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
	return (Color.WHITE.lerp(def.color_grade, 0.12) * season_mod()).lerp(Art.NIGHT_TINT, n)


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
	_draw_contact_shadow(ci, p + Vector2(0, -3), w * 0.72, 18.0, 0.18)
	_cast_shadow(ci, tex, Rect2(p.x - w * 0.5, p.y - h, w, h), flip, p, n)
	_blit(ci, tex, Rect2(p.x - w * 0.5, p.y - h, w, h), flip, _night_mod(n).darkened(0.06))


## Реквизит: низ по центру в точке p, ширина w.
func _prop(ci: CanvasItem, tex: Texture2D, p: Vector2, w: float, n: float, baked_shadow: bool = false) -> void:
	var h := w * tex.get_height() / tex.get_width()
	if not baked_shadow:
		_draw_contact_shadow(ci, p + Vector2(0, -3), w * 0.72, 18.0, 0.18)
		_cast_shadow(ci, tex, Rect2(p.x - w * 0.5, p.y - h, w, h), false, p, n)
	_blit(ci, tex, Rect2(p.x - w * 0.5, p.y - h, w, h), false, _night_mod(n))


const SHADOW_KX := 0.4                    ## на сколько вправо уходит точка предмета на единицу её высоты
const SHADOW_KY := 0.17                   ## и вниз: тень ложится на землю косо и плоско


## Сила тени: днём заметная, ночью слабая лунная, под облаками и в тумане мягче. На упрощённой графике тени нет.
func shadow_alpha(n: float) -> float:
	if simplified_graphics:
		return 0.0
	var a := lerpf(0.3, 0.08, clampf(n, 0.0, 1.0))
	if bool(weather_state.get("active", false)):
		var gloom := float(weather_state.get("power", 0.0)) * 0.6 + float(weather_state.get("fog", 0.0)) * 0.5
		a *= 1.0 - 0.6 * clampf(gloom, 0.0, 0.85)
	return a


## Падающая тень: та же картинка, перевёрнутая вокруг линии основания и сдвинутая вправо и вниз,
## чёрная с прозрачностью. Три копии с разным наклоном дают мягкий край. Рисует движок, без полигонов.
## base — точка на земле у основания предмета, reach — длина тени относительно обычной.
func _cast_shadow(ci: CanvasItem, tex: Texture2D, r: Rect2, flip: bool, base: Vector2, n: float, reach: float = 1.0) -> void:
	var alpha := shadow_alpha(n)
	if alpha <= 0.01 or tex == null:
		return
	var off := Vector2.ZERO if ci == self else -(ci as Node2D).position
	var local := Transform2D(Vector2(-1.0 if flip else 1.0, 0.0), Vector2(0.0, 1.0),
		Vector2(r.end.x if flip else r.position.x, r.position.y))
	var to_base := Transform2D(Vector2.RIGHT, Vector2.DOWN, base)
	var from_base := Transform2D(Vector2.RIGHT, Vector2.DOWN, -base)
	var shift := Transform2D(Vector2.RIGHT, Vector2.DOWN, off)
	for spread: float in [0.86, 1.0, 1.16]:
		var proj := Transform2D(Vector2(1.0, 0.0), Vector2(-SHADOW_KX * reach * spread, -SHADOW_KY * reach), Vector2.ZERO)
		ci.draw_set_transform_matrix(shift * to_base * proj * from_base * local)
		ci.draw_texture_rect(tex, Rect2(Vector2.ZERO, r.size), false, Color(0.02, 0.02, 0.03, alpha * 0.4))
	ci.draw_set_transform(off)


func _draw_contact_shadow(ci: CanvasItem, p: Vector2, w: float, h: float, alpha: float) -> void:
	if _contact_shadow_texture == null:
		_contact_shadow_texture = _soft_texture()
	var offset := Vector2.ZERO if ci == self else -(ci as Node2D).position
	ci.draw_texture_rect(_contact_shadow_texture, Rect2(p.x - w * 0.5 + offset.x,
		p.y - h * 0.5 + offset.y, w, h), false, Color(0.025, 0.02, 0.03, alpha))


## Дом: дневная картинка, к ночи темнеет; когда в доме загорается свет, поверх ложится
## ночная картинка с горящими окнами. state: 0 — фон, 1 — открытое убежище, 2 — заколоченное.
func _draw_house(ci: CanvasItem, h: HouseDef, state: int, n: float, lit: float, tal: int) -> void:
	var a := _art(h)
	var r := house_rect(h)
	var flip := _flip(h)
	# Опора в центре основания картинки, а не в точке двери у её края.
	var foundation := Vector2(r.get_center().x, lerpf(h.pos.y, r.end.y, 0.45))
	_draw_contact_shadow(ci, foundation, r.size.x * 0.88, clampf(r.size.y * 0.16, 18.0, 30.0),
		lerpf(0.22, 0.28, n))
	var mod := _night_mod(n)
	if state == 2:
		mod = mod.darkened(0.32)
	elif state == 0:
		mod = mod.darkened(0.08)
	var night_tex: Texture2D = _tex.get(a[0] + "_night")
	if night_tex == null and state != 2:
		# у картинки нет ночной пары: жилой дом ночью теплеет, будто внутри горит свет
		mod = mod.lerp(Color(1.0, 0.82, 0.6), 0.42 * lit)
	_cast_shadow(ci, _tex[a[0] + "_day"], r, flip, foundation, n)
	_blit(ci, _tex[a[0] + "_day"], r, flip, mod)
	if state != 2 and lit > 0.0 and night_tex != null:
		_blit(ci, night_tex, r, flip, Color(1, 1, 1, lit * (1.0 if state == 1 else 0.85)))
	if h.kind == HouseDef.Kind.BARN:
		_draw_barn_shutter(ci, r, flip, n)
	var dr := door_rect(h)
	if state == 1:
		_draw_talisman(ci, dr, flip, n, tal)
	elif state == 2:
		_draw_boards(ci, dr, flip, n)


## Дверь, оставленная открытой после изгнания: створка покачивается, от порыва ветра распахивается шире.
## Положен файл door_ajar.png (realistic/ или village/) — рисуем его, иначе тёмный проём и кромка створки.
func _draw_ajar(ci: CanvasItem, door: Rect2, flip: bool, n: float) -> void:
	var k := ajar_open()
	var tex: Texture2D = _tex.get("door_ajar")
	if tex != null:
		var grow := 0.88 + 0.24 * k
		var w := door.size.x * grow
		var x := door.position.x if not flip else door.end.x - w
		_blit(ci, tex, Rect2(x, door.position.y, w, door.size.y), flip, _night_mod(n))
		return
	var edge := door.position.x if not flip else door.end.x
	var dir := 1.0 if not flip else -1.0
	var leaf := edge + dir * door.size.x * k
	var back := edge + dir * door.size.x * (k - 0.1)
	var dark := PackedVector2Array([Vector2(edge, door.position.y), Vector2(leaf, door.position.y + 3.0), Vector2(back, door.end.y), Vector2(edge, door.end.y)])
	if flip:
		dark.reverse()
	ci.draw_colored_polygon(dark, Color("100e13"))
	ci.draw_line(Vector2(leaf, door.position.y + 3.0), Vector2(back, door.end.y), Color("856849") * _night_mod(n), 2.0)


## Насколько открыта дверь изгнанного (доля ширины двери, 0,2–0,85): ветер качает, порыв распахивает.
func ajar_open() -> float:
	return clampf(0.46 + 0.07 * sin(_t * 0.8) + 0.05 * sin(_t * 1.9 + 1.3) + 0.28 * _gust * sin(_t * 6.0), 0.2, 0.85)


## Раз в 6–11 с порыв: дверь скрипит и распахивается. Дверь перерисовывается ~15 раз в секунду.
func _ajar_step(delta: float) -> void:
	_gust = maxf(0.0, _gust - delta * 0.6)
	var ajar := ajar_houses()
	if ajar.is_empty():
		return
	_creak_in -= delta
	if _creak_in <= 0.0:
		creak_now()
	_ajar_acc += delta
	if _ajar_acc >= 0.066:
		_ajar_acc = 0.0
		for i in ajar:
			if i < _props.size():
				_props[i].queue_redraw()


func creak_now() -> void:
	_creak_in = randf_range(6.0, 11.0)
	_gust = 1.0
	if modulate.a > 0.3 and is_visible_in_tree() and Sfx.has_sound(&"creak"):
		Sfx.play(&"creak", randf_range(0.8, 0.95), -24.0)


## Закрытая створка на чердаке сарая: убирает чёрный проём, похожий на пропавшую текстуру.
func _draw_barn_shutter(ci: CanvasItem, house: Rect2, flip: bool, n: float) -> void:
	var nx0 := 0.29 if not flip else 0.52
	var nx1 := 0.48 if not flip else 0.71
	var panel := Rect2(house.position.x + house.size.x * nx0, house.position.y + house.size.y * 0.29,
		house.size.x * (nx1 - nx0), house.size.y * 0.20)
	var off := Vector2.ZERO if ci == self else -(ci as Node2D).position
	var r := Rect2(panel.position + off, panel.size)
	var wood := _night_mod(n)
	var fill := Color("594331") * wood
	ci.draw_rect(r, Color("211a19") * wood)
	var inset := r.grow(-2.0)
	ci.draw_rect(inset, fill)
	for i in range(1, 4):
		var x := lerpf(inset.position.x, inset.end.x, float(i) / 4.0)
		ci.draw_line(Vector2(x, inset.position.y + 1.0), Vector2(x, inset.end.y - 1.0), Color("34271f") * wood, 1.6)
	ci.draw_line(Vector2(inset.position.x + 1.0, inset.position.y + inset.size.y * 0.72),
		Vector2(inset.end.x - 1.0, inset.position.y + inset.size.y * 0.72), Color("816348") * wood, 2.4)
	ci.draw_line(inset.position + Vector2(2, 2), inset.end - Vector2(2, 2), Color("34271f") * wood, 1.3)
	ci.draw_circle(inset.position + Vector2(3, 3), 1.2, Color("b28a5c") * wood)
	ci.draw_circle(Vector2(inset.end.x - 3, inset.position.y + 3), 1.2, Color("b28a5c") * wood)


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
func _draw_hatches(n: float, _k: Color) -> void:
	var tex: Texture2D = _tex.get("hatch")
	if tex == null:
		return
	for i: int in [tunnel.x, tunnel.y]:
		if i < 0 or i >= open_count or i >= def.shelters.size():
			continue
		var c := hatch_pos(i)
		var w := 62.0
		var h := w * tex.get_height() / tex.get_width()
		_blit(self, tex, Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), false, _night_mod(n))


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
	_draw_contact_shadow(ci, p + Vector2(0, 1), 24.0, 12.0, 0.22)
	_cast_shadow(ci, _tex.lamp_day, r, true, p, n, 0.7)
	_blit(ci, _tex.lamp_day, r, true, _night_mod(n))
	if on > 0.0:
		_blit(ci, _tex.lamp_night, r, true, Color(1, 1, 1, on))


const FENCE_W := 112.0                    ## ширина секции забора, единиц посёлка


## Где забор на поле: секция стоит у края и смотрит внутрь посёлка.
func fence_rect(row: Vector2) -> Rect2:
	var tex: Texture2D = _tex.get("fence")
	var h := FENCE_W * (float(tex.get_height()) / float(tex.get_width()) if tex != null else 0.667)
	var x := row.x - 8.0 if row.x < def.square_center.x else row.x - FENCE_W + 8.0
	return Rect2(x, row.y - h, FENCE_W, h)


## Забор стоит в слое предметов: кто дальше от зрителя, тот за ним, а дом позади не «прорастает» сквозь доски.
func _paint_fence(ci: CanvasItem, row: Vector2) -> void:
	var tex: Texture2D = _tex.get("fence")
	if tex == null:
		return
	var r := fence_rect(row)
	var n := _nq()
	var flip := row.x >= def.square_center.x
	_cast_shadow(ci, tex, r, flip, Vector2(row.x, row.y - r.size.y * 0.1), n, 0.8)
	_blit(ci, tex, r, flip, _night_mod(n))


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
	var tex := LightHalo.point_light_texture()
	for i in range(def.lamps.size()):
		var l := PointLight2D.new()
		l.texture = tex
		l.position = def.lamps[i] + Vector2(12, -61)
		l.texture_scale = 1.2
		l.color = def.lamp_color
		l.energy = 0.0
		l.visible = false
		l.shadow_enabled = true
		l.shadow_color = Color(0.01, 0.012, 0.02, 0.3)
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = 7.0
		add_child(l)
		_lamp_lights.append(l)
	for h: HouseDef in def.shelters + def.decor:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		var hr := house_rect(h)
		var art := _art(h)
		var building: Texture2D = _tex[art[0] + "_day"]
		var outline := _house_shadow_outline(art[0], building)
		if outline.size() >= 3:
			var sx := hr.size.x / building.get_width()
			var sy := hr.size.y / building.get_height()
			var points := PackedVector2Array()
			for point: Vector2 in outline:
				var px := building.get_width() - point.x if _flip(h) else point.x
				points.append(Vector2(px * sx, point.y * sy))
			poly.polygon = points
			occ.position = hr.position
		else:
			var body := hr.grow_individual(-0.15 * hr.size.x, -0.3 * hr.size.y, -0.15 * hr.size.x, 0.0)
			poly.polygon = PackedVector2Array([body.position, Vector2(body.end.x, body.position.y),
				Vector2(body.end.x, h.pos.y - 2), Vector2(body.position.x, h.pos.y - 2)])
		occ.occluder = poly
		add_child(occ)
		_occluders.append(occ)


func _house_shadow_outline(art_id: String, tex: Texture2D) -> PackedVector2Array:
	if _shadow_outline_cache.has(art_id):
		return _shadow_outline_cache[art_id]
	var result := PackedVector2Array()
	if tex == null:
		_shadow_outline_cache[art_id] = result
		return result
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(tex.get_image(), 0.75)
	var bounds := Rect2i(0, 0, tex.get_width(), tex.get_height())
	var contours := bitmap.opaque_to_polygons(bounds, 8.0)
	var largest_area := 0.0
	for contour: PackedVector2Array in contours:
		if contour.size() < 3:
			continue
		var area := 0.0
		for i in range(contour.size()):
			area += contour[i].cross(contour[(i + 1) % contour.size()])
		area = absf(area) * 0.5
		if area > largest_area:
			largest_area = area
			result = contour
	_shadow_outline_cache[art_id] = result
	return result




func _lit(h: HouseDef, n: float) -> float:
	var th: float = _light_th.get(h, 0.5)
	return clampf((n - th) / 0.12, 0.0, 1.0)


func _lamp_on(i: int, n: float) -> float:
	var th: float = _lamp_th[i] if i < _lamp_th.size() else 0.5
	return clampf((n - th) / 0.08, 0.0, 1.0)


func _soft_texture() -> GradientTexture2D:
	# Мягкая альфа-маска для теней и частиц (силу задаёт цвет частицы или тени); PointLight2D использует отдельную серую текстуру.
	# Точки задаются массивами: set_color(1, …) после add_point() попадал в точку 0.3, а конец градиента
	# оставался белым и непрозрачным, из-за чего тени и пылинки рисовались светлыми квадратами.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.17), Color(1, 1, 1, 0.0)])
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
	for p: Vector2 in def.lamps:
		_lamp_glows.append(_add_halo(p + Vector2(12, -61), 34.0, Color("ff9e2c")))
	for i in range(open_count):
		var h: HouseDef = def.shelters[i]
		var hr := house_rect(h)
		var y := hr.position.y + hr.size.y * 0.53
		_house_glows.append(_add_halo(Vector2(hr.position.x + hr.size.x * 0.24, y), 20.0, Color("ff9e2c")))
		_house_glows.append(_add_halo(Vector2(hr.position.x + hr.size.x * 0.76, y), 20.0, Color("ff9e2c")))


func _add_halo(at: Vector2, radius: float, tint: Color) -> LightHalo:
	var halo := LightHalo.new()
	halo.position = at
	halo.radius = radius
	halo.color = tint
	halo.intensity = 0.0
	halo.flicker = 0.14
	halo.z_index = 0
	add_child(halo)
	move_child(halo, crowd.get_index())
	return halo


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
		b.position = Vector2(FOG_X, 196.0 if i == 0 else 470.0)
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




func _ellipse(c: Vector2, r: Vector2, seg: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts





## Редкий взгляд из-за деревьев. Проверяется один раз за ночь, виден только в партии.
class Eyes extends Node2D:
	const SPOTS := [Vector2(160, 158), Vector2(300, 176), Vector2(432, 178), Vector2(640, 162)]
	const CHANCE := 0.30
	var night: float = 0.0: set = set_night
	var enabled := false
	var _rng := RandomNumberGenerator.new()
	var _rolled := false
	var _remaining := 0.0
	var _duration := 0.0
	var _elapsed := 0.0
	var _active_spots := PackedInt32Array()
	var night_rolls := 0

	func _ready() -> void:
		_rng.randomize()

	func alpha() -> float:
		if not enabled or night < 0.75 or _duration <= 0.0:
			return 0.0
		return clampf(minf(_elapsed / 0.35, _remaining / 0.45), 0.0, 1.0)

	## Чистая функция для самотеста и воспроизводимого баланса частоты.
	static func roll_night(rng: RandomNumberGenerator) -> Dictionary:
		if rng.randf() >= CHANCE:
			return {}
		var locations: Array[int] = []
		for i in range(SPOTS.size()):
			locations.append(i)
		for i in range(locations.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap := locations[i]
			locations[i] = locations[j]
			locations[j] = swap
		var count := rng.randi_range(1, 2)
		var chosen := PackedInt32Array()
		for i in range(count):
			chosen.append(locations[i])
		return {"spots": chosen, "duration": rng.randf_range(2.0, 4.0)}

	func set_enabled(value: bool) -> void:
		enabled = value
		if not enabled:
			_remaining = 0.0
			_duration = 0.0
			_active_spots.clear()
			night = 0.0
			queue_redraw()

	func set_night(value: float) -> void:
		var previous := night
		night = clampf(value, 0.0, 1.0)
		if night <= 0.15:
			_rolled = false
			_remaining = 0.0
			_duration = 0.0
			_active_spots.clear()
		elif enabled and previous < 0.75 and night >= 0.75 and not _rolled:
			_rolled = true
			night_rolls += 1
			var result := roll_night(_rng)
			_active_spots = result.get("spots", PackedInt32Array())
			_duration = float(result.get("duration", 0.0))
			_remaining = _duration
			_elapsed = 0.0
			if _duration > 0.0 and Sfx.has_sound(&"creak"):
				Sfx.play(&"creak", _rng.randf_range(0.88, 0.96), -28.0)
		queue_redraw()

	## Сколько пар сейчас видны — для самотеста.
	func visible_pairs() -> int:
		return _active_spots.size() if alpha() >= 0.5 else 0

	func _process(delta: float) -> void:
		if _remaining <= 0.0:
			return
		_elapsed += delta
		_remaining = maxf(0.0, _remaining - delta)
		queue_redraw()

	func _draw() -> void:
		var a := alpha()
		if a <= 0.0:
			return
		for i: int in _active_spots:
			var p: Vector2 = SPOTS[i]
			for dx in [-3.2, 3.2]:
				draw_circle(p + Vector2(dx, 0), 5.2, Color(1.0, 0.18, 0.12, 0.13 * a))
				draw_circle(p + Vector2(dx, 0), 1.8, Color(1.0, 0.28, 0.18, 0.86 * a))



## Небо и дальний лес за посёлком: три неба (день, сумерки, ночь) и две полосы леса.
## Каждая текстура заполняет видимую ширину одним кадром, без повторных картинок по краям.
## Два слоя: part "sky" (три неба) и part "forest" (две полосы леса). У каждого своя скорость относительно камеры,
## так лес и небо выглядят дальше домов. Полоса всегда шире кадра на запас, чтобы край не открылся при самом дальнем уходе камеры.
class Backdrop extends Node2D:
	const ZOOM_LIMIT := 2.5
	const SKY_W := 1150.0
	const TREE_W := 780.0
	const SKY_TOP := {"sky_day": Color8(84, 95, 90), "sky_dusk": Color8(53, 60, 83), "sky_night": Color8(16, 23, 41)}
	const FOREST_DAY := Color8(14, 17, 25)
	const FOREST_NIGHT := Color8(10, 12, 23)
	var view: VillageView
	var part := "sky"
	var speed := 0.65

	func _ready() -> void:
		show_behind_parent = true

	func _draw() -> void:
		if view == null or view.def == null or view._ground_is_composite:
			return
		var n := view._nq()
		var gy := view.def.ground_rect.position.y
		var bottom := gy + 10.0
		# сумерки: день → сумерки к середине, сумерки → ночь ко второй половине
		var realistic := view._tex.has("real_sky_day") and view._tex.has("real_sky_dusk") and view._tex.has("real_sky_night")
		if realistic:
			if part != "sky":
				return
			var realistic_layers := [["real_sky_day", 1.0], ["real_sky_dusk", clampf(n * 2.2, 0.0, 1.0)], ["real_sky_night", clampf((n - 0.5) * 2.2, 0.0, 1.0)]]
			for l: Array in realistic_layers:
				var a: float = l[1]
				if a <= 0.0:
					continue
				var tex: Texture2D = view._tex[l[0]]
				var h := SKY_W * tex.get_height() / tex.get_width()
				_strip(tex, bottom - h, SKY_W, h, Color(1, 1, 1, a))
		elif part == "sky":
			var layers := [["sky_day", 1.0], ["sky_dusk", clampf(n * 2.2, 0.0, 1.0)], ["sky_night", clampf((n - 0.5) * 2.2, 0.0, 1.0)]]
			for l: Array in layers:
				var a: float = l[1]
				if a <= 0.0:
					continue
				var tex: Texture2D = view._tex[l[0]]
				var h := SKY_W * tex.get_height() / tex.get_width()
				draw_rect(Rect2(-3000, bottom - h - 3000, 6720, 3002), Color(SKY_TOP[l[0]], a))
				_strip(tex, bottom - h, SKY_W, h, Color(1, 1, 1, a))
		else:
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

	## Ширина полосы: кадр плюс запас на самый дальний уход камеры от центра, считанный для сильного приближения,
	## чтобы край не открылся, пока посёлок приближают и полоса ещё не перерисована.
	func strip_width(w: float) -> float:
		var half := view._vp_w / maxf(view.scale.x, 0.5) * 0.5
		var half_zoomed := view._vp_w / (2.0 * ZOOM_LIMIT)
		var d_max := maxf(0.0, VillageView.LOGICAL.x * 0.5 + 20.0 - minf(half, half_zoomed))
		return maxf(w, 2.0 * half + maxf(352.0, 2.0 * speed * d_max + 64.0))

	## Полоса картинки по всей ширине, копии через одну отражены — шов не виден.
	func _strip(tex: Texture2D, y: float, w: float, h: float, mod: Color) -> void:
		var target_w := strip_width(w)
		var target_h := h * target_w / w
		var bottom := y + h
		var r := Rect2(VillageView.LOGICAL.x * 0.5 - target_w * 0.5, bottom - target_h, target_w, target_h)
		draw_texture_rect(tex, r, false, mod)


## Еловые ветки по верхним углам поля: рамка кадра, поверх посёлка. Стоят на экране, а не в посёлке:
## камера под ними двигается. Не ловят касания.
class Branches extends Node2D:
	var view: VillageView

	func _ready() -> void:
		top_level = true
		z_index = 1

	## Насколько картинка выступает за край поля: на столько ветки можно сдвигать по экрану, не открывая щель.
	func hang() -> float:
		if view == null or view._field.size.x <= 0.0:
			return 0.0
		return clampf(view._field.size.x * 0.24, 90.0, 260.0) * 0.08

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
