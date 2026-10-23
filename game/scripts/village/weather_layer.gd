class_name WeatherLayer
extends Node2D
## Погода на поле (TASK-061, 063–066). Слой лежит внутри VillageView, над толпой и под виньеткой.
## Состояние даёт Weather.state(); слой создаёт эмиттеры под него и удаляет ненужные.
## На каждый эмиттер не больше MAX_PARTICLES частиц, упрощённая графика режет их вдвое.

const MAX_PARTICLES := 60
const AREA := Rect2(-120, 100, 960, 460)            ## где идёт осадок, в координатах посёлка
const FALL_H := 440.0                               ## высота падения осадка

## Сколько частиц у эмиттера при полной силе. Все числа не больше MAX_PARTICLES.
const FULL := {
	"rain_far": 60, "rain_back": 60, "rain_mid": 60, "rain_near": 40, "ripples": 2,
	"flakes_far": 60, "flakes_mid": 60, "flakes_near": 40, "drift": 40, "grains": 40,
	"fluff": 40, "ash": 40, "midges": 6, "leaves": 30, "drip": 40, "mist": 16,
}

static var _dot_tex: ImageTexture
static var _streak_tex: ImageTexture
static var _dash_tex: ImageTexture
static var _leaf_tex: ImageTexture
static var _snow_tex: ImageTexture
static var _mist_tex: ImageTexture

var view: VillageView
var state: Dictionary = Weather.EMPTY.duplicate()
var simplified := false
var _nodes: Dictionary = {}                         ## имя -> CPUParticles2D, Midges или Ripples
var _t := 0.0
var _hash := -1


func _ready() -> void:
	name = "WeatherLayer"
	set_process(false)


## Включить погоду. Тот же набор эмиттеров не пересоздаётся.
func apply(s: Dictionary) -> void:
	var h := s.hash()
	if h == _hash:
		return
	_hash = h
	state = s
	var want := wanted(s)
	for key: String in _nodes.keys():
		if not want.has(key):
			var gone: Node = _nodes[key]
			_nodes.erase(key)
			remove_child(gone)
			gone.queue_free()
	for key: String in want.keys():
		if not _nodes.has(key):
			var made := _make(key)
			if made == null:
				continue
			_nodes[key] = made
			_set_amount(key, float(want[key]))   # число частиц до входа в дерево: предпрогон сразу заполнит поле
			add_child(made)
		else:
			_set_amount(key, float(want[key]))
	set_process(not _nodes.is_empty())
	refresh_geometry()
	_tick(0.0)


func set_simplified(on: bool) -> void:
	if on == simplified:
		return
	simplified = on
	var want := wanted(state)
	for key: String in _nodes.keys():
		_set_amount(key, float(want.get(key, 0.0)))


## Какие эмиттеры нужны и с какой силой (0..1). Правила сезонов — здесь, в одном месте.
static func wanted(s: Dictionary) -> Dictionary:
	var out := {}
	if not bool(s.get("active", false)):
		return out
	var p := float(s.get("power", 0.0))
	var amb := float(s.get("amb", 0.0))
	match int(s.get("precip", Weather.Precip.NONE)):
		Weather.Precip.RAIN:
			if p > 0.02:
				out["rain_far"] = clampf(p * 1.4, 0.3, 1.0)
				out["ripples"] = p
				if p > 0.25:
					out["rain_near"] = clampf(p * 1.3, 0.3, 1.0)
				if p > 0.4:
					out["rain_back"] = clampf(p * 1.3, 0.3, 1.0)
				if p > 0.55:
					out["rain_mid"] = clampf(p * 1.2, 0.3, 1.0)
		Weather.Precip.SNOW:
			if p > 0.02:
				out["flakes_far"] = clampf(p * 1.2, 0.25, 1.0)
				if p > 0.25:
					out["flakes_near"] = p
				if p > 0.55:
					out["flakes_mid"] = p
				if p > 0.3:
					out["drift"] = p
				if p > 0.6:
					out["grains"] = p
	var fog := float(s.get("fog", 0.0))
	if fog > 0.4:
		out["mist"] = clampf((fog - 0.2) * 1.25, 0.2, 1.0)
	if amb > 0.02:
		match int(s.get("season", Weather.Season.SUMMER)):
			Weather.Season.SUMMER:
				if float(s.get("power", 0.0)) < 0.5:
					out["fluff"] = amb
				out["ash"] = amb * (1.0 if String(s.get("id", "")) == "peat_smoke" else 0.5)
				out["midges"] = amb
			Weather.Season.AUTUMN:
				out["leaves"] = amb
			Weather.Season.SPRING:
				out["drip"] = amb
	return out


func emitter_names() -> PackedStringArray:
	var out := PackedStringArray(_nodes.keys())
	out.sort()
	return out


func emitter(key: String) -> Node:
	return _nodes.get(key)


## Сколько частиц у эмиттера сейчас. У мошкары и ряби это число на один фонарь или лужу.
func amount_of(key: String) -> int:
	var n: Node = _nodes.get(key)
	if n is CPUParticles2D:
		return (n as CPUParticles2D).amount
	if n is Midges:
		return (n as Midges).count()
	if n is Ripples:
		return (n as Ripples).count()
	return 0


func particle_total() -> int:
	var total := 0
	for key: String in _nodes.keys():
		total += amount_of(key)
	return total


func _set_amount(key: String, strength: float) -> void:
	var n: Node = _nodes.get(key)
	var count := maxi(1, roundi(float(FULL[key]) * clampf(strength, 0.0, 1.0) * (0.5 if simplified else 1.0)))
	count = mini(count, MAX_PARTICLES)
	if n is CPUParticles2D:
		var pr := n as CPUParticles2D
		if pr.amount != count:
			pr.amount = count
			if pr.is_inside_tree():
				pr.restart()
	elif n is Midges:
		(n as Midges).per_lamp = count
	elif n is Ripples:
		(n as Ripples).per_spot = clampi(count, 1, 2)
		(n as Ripples).strength = strength


## Точки, зависящие от карты: стрехи для капели, фонари для мошкары, лужи для ряби.
func refresh_geometry() -> void:
	if view == null or view.def == null:
		return
	var drip: CPUParticles2D = _nodes.get("drip")
	if drip != null:
		var pts := PackedVector2Array()
		for h: HouseDef in view.def.shelters + view.def.decor:
			var r := view.house_rect(h)
			pts.append(Vector2(r.position.x + r.size.x * 0.16, r.position.y + r.size.y * 0.58))
			pts.append(Vector2(r.position.x + r.size.x * 0.84, r.position.y + r.size.y * 0.58))
		if pts.is_empty():
			pts.append(Vector2(360, 300))
		drip.emission_points = pts
	var midges: Midges = _nodes.get("midges")
	if midges != null:
		var spots := PackedVector2Array()
		for lamp: Vector2 in view.def.lamps:
			spots.append(lamp + Vector2(12, -61))
		midges.spots = spots
	var ripples: Ripples = _nodes.get("ripples")
	if ripples != null:
		ripples.spots = view.def.puddle_spots


func _process(delta: float) -> void:
	_tick(delta)


func _tick(delta: float) -> void:
	_t += delta
	var n := view.night if view != null else 0.0
	var wind := float(state.get("wind", 0.0))
	var gust := 0.5 + 0.5 * sin(_t * 0.7) * sin(_t * 0.23 + 1.3)
	var cold := Color.WHITE.lerp(Color(0.55, 0.62, 0.85), n)
	var snowy := Color.WHITE.lerp(Color(0.8, 0.87, 1.0), n)   # снег ночью остаётся заметным
	for key: String in _nodes.keys():
		var node: Node = _nodes[key]
		var vis := _vis(key, n)
		var tint := Color.WHITE if _emissive(key) else (snowy if _is_snow(key) else cold)
		if node is CPUParticles2D:
			var p := node as CPUParticles2D
			p.modulate = Color(tint, vis)
			var on := vis > 0.02
			if p.emitting != on:
				p.emitting = on
			if _is_snow(key):
				p.gravity.x = wind * (24.0 + 120.0 * gust) * (1.6 if key == "drift" else 1.0)
			elif key.begins_with("rain"):
				p.gravity.x = wind * 60.0 * gust
			elif key == "fluff":
				p.gravity.x = sin(_t * 0.5) * 6.0 + wind * 8.0
			elif key == "leaves":
				p.gravity.x = (sin(_t * 0.8) * 10.0 + 14.0) * (0.4 + absf(wind) * 2.0) * signf(wind if wind != 0.0 else 1.0)
		elif node is CanvasItem:
			var ci := node as CanvasItem
			ci.modulate = Color(tint, vis)
			ci.visible = vis > 0.02
			if ci.visible:
				ci.queue_redraw()


## Видимость эмиттера по времени суток: пух днём, пепел в сумерках, мошкара ночью.
static func vis_for(key: String, n: float) -> float:
	match key:
		"fluff":
			return 1.0 - smoothstep(0.15, 0.5, n)
		"ash":
			return clampf(1.0 - absf(n - 0.5) * 3.2, 0.0, 1.0)
		"midges":
			return smoothstep(0.5, 0.85, n)
		"ripples", "drip":
			return 1.0 - 0.3 * n
	return 1.0


func _vis(key: String, n: float) -> float:
	return vis_for(key, n)


func _is_snow(key: String) -> bool:
	return key.begins_with("flakes") or key == "drift" or key == "grains"


func _emissive(key: String) -> bool:
	return key == "ash" or key == "midges"


# =============================================================
# Сборка эмиттеров
# =============================================================
func _make(key: String) -> Node:
	match key:
		"rain_far":
			return _rain(key, 330.0, 0.7, Color(0.78, 0.86, 0.96, 0.4))
		"rain_back":
			return _rain(key, 280.0, 0.55, Color(0.74, 0.82, 0.92, 0.3))
		"rain_mid":
			return _rain(key, 430.0, 1.0, Color(0.82, 0.89, 0.97, 0.52))
		"rain_near":
			return _rain(key, 560.0, 1.4, Color(0.86, 0.92, 0.98, 0.65))
		"flakes_far":
			return _flakes(key, 38.0, 0.28, 0.7)
		"flakes_mid":
			return _flakes(key, 62.0, 0.42, 0.85)
		"flakes_near":
			return _flakes(key, 96.0, 0.68, 0.95)
		"drift":
			return _drift()
		"grains":
			return _grains()
		"fluff":
			return _fluff()
		"ash":
			return _ash()
		"leaves":
			return _leaves()
		"drip":
			return _drip()
		"mist":
			return _mist()
		"midges":
			var m := Midges.new()
			m.name = key
			return m
		"ripples":
			var r := Ripples.new()
			r.name = key
			return r
	return null


func _base(key: String, tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = key
	p.texture = tex
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.gravity = Vector2.ZERO
	p.randomness = 1.0
	return p


func _rain(key: String, speed: float, sc: float, col: Color) -> CPUParticles2D:
	var p := _base(key, streak_texture())
	var wind := float(state.get("wind", 0.0))
	var dir := Vector2(0.1 + wind * 0.4, 1.0).normalized()
	p.lifetime = FALL_H / speed
	p.preprocess = p.lifetime
	p.position = Vector2(360.0 - dir.x / dir.y * FALL_H * 0.5, AREA.position.y)
	p.emission_rect_extents = Vector2(AREA.size.x * 0.5 + 40.0, 4.0)
	p.direction = dir
	p.spread = 2.0
	p.initial_velocity_min = speed * 0.92
	p.initial_velocity_max = speed * 1.08
	p.scale_amount_min = sc * 0.9
	p.scale_amount_max = sc * 1.1
	p.particle_flag_align_y = true
	p.color = col
	return p


func _flakes(key: String, fall: float, sc: float, alpha: float) -> CPUParticles2D:
	var p := _base(key, dot_texture())
	var wind := float(state.get("wind", 0.0))
	p.lifetime = FALL_H / fall
	p.preprocess = p.lifetime
	p.position = Vector2(360.0 - wind * 120.0, AREA.position.y)
	p.emission_rect_extents = Vector2(AREA.size.x * 0.5 + 100.0, 4.0)
	p.direction = Vector2(wind * 0.5, 1.0)
	p.spread = 16.0
	p.initial_velocity_min = fall * 0.8
	p.initial_velocity_max = fall * 1.2
	p.scale_amount_min = sc * 0.7
	p.scale_amount_max = sc * 1.2
	p.color = Color(0.94, 0.97, 1.0, alpha)
	return p


## Позёмка: низкие полосы снега вдоль земли.
func _drift() -> CPUParticles2D:
	var p := _base("drift", dash_texture())
	var wind := float(state.get("wind", 0.0))
	var sgn := -1.0 if wind < 0.0 else 1.0
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.position = Vector2(360.0 - sgn * 360.0, 460.0)
	p.emission_rect_extents = Vector2(40.0, 70.0)
	p.direction = Vector2(sgn, 0.03)
	p.spread = 6.0
	p.initial_velocity_min = 110.0 + 120.0 * absf(wind)
	p.initial_velocity_max = 170.0 + 180.0 * absf(wind)
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.8
	p.color = Color(0.92, 0.96, 1.0, 0.42)
	return p


## Снежная крупа: мелкие быстрые точки.
func _grains() -> CPUParticles2D:
	var p := _base("grains", dot_texture())
	var wind := float(state.get("wind", 0.0))
	p.lifetime = 1.5
	p.preprocess = 1.5
	p.position = Vector2(360.0 - wind * 200.0, AREA.position.y + 20.0)
	p.emission_rect_extents = Vector2(AREA.size.x * 0.5 + 100.0, 30.0)
	p.direction = Vector2(0.3 + wind * 0.5, 1.0)
	p.spread = 8.0
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 320.0
	p.scale_amount_min = 0.14
	p.scale_amount_max = 0.24
	p.color = Color(1, 1, 1, 0.8)
	return p


## Тополиный пух: крупные медленные пушинки днём.
func _fluff() -> CPUParticles2D:
	var p := _base("fluff", dot_texture())
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.position = Vector2(360, 320)
	p.emission_rect_extents = Vector2(480, 190)
	p.direction = Vector2(1, 0.25)
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector2(0, 2.5)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.55
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 0.96, 0.0))
	ramp.add_point(0.2, Color(1, 1, 0.96, 0.8))
	ramp.add_point(0.8, Color(1, 1, 0.96, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 0.96, 0.0))
	p.color_ramp = ramp
	return p


## Тлеющий торфяной пепел: оранжевые искры в сумерках, поднимаются и гаснут.
func _ash() -> CPUParticles2D:
	var p := _base("ash", dot_texture())
	p.material = _additive()
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.position = Vector2(360, 430)
	p.emission_rect_extents = Vector2(460, 90)
	p.direction = Vector2(0.3, -1.0)
	p.spread = 35.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector2(4, -2)
	p.scale_amount_min = 0.16
	p.scale_amount_max = 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.62, 0.22, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.62, 0.22, 0.9))
	ramp.add_point(0.6, Color(0.86, 0.36, 0.14, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.4, 0.3, 0.26, 0.0))
	p.color_ramp = ramp
	return p


func _leaves() -> CPUParticles2D:
	var p := _base("leaves", leaf_texture())
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.position = Vector2(360, AREA.position.y + 6.0)
	p.emission_rect_extents = Vector2(AREA.size.x * 0.5, 6.0)
	p.direction = Vector2(0.4, 1.0)
	p.spread = 30.0
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 30.0
	p.gravity = Vector2(14, 20)
	p.angular_velocity_min = -160.0
	p.angular_velocity_max = 160.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var hues := Gradient.new()
	hues.set_color(0, Color(0.78, 0.3, 0.12))
	hues.add_point(0.4, Color(0.86, 0.55, 0.14))
	hues.add_point(0.7, Color(0.62, 0.42, 0.14))
	hues.set_color(hues.get_point_count() - 1, Color(0.5, 0.2, 0.1))
	p.color_initial_ramp = hues
	return p


## Густой ползущий туман: крупные мягкие облака у земли, плывут вдоль ветра.
func _mist() -> CPUParticles2D:
	var p := _base("mist", mist_texture())
	var wind := float(state.get("wind", 0.0))
	var sgn := -1.0 if wind < 0.0 else 1.0
	p.lifetime = 26.0
	p.preprocess = 26.0
	p.position = Vector2(360, 440)
	p.emission_rect_extents = Vector2(520, 70)
	p.direction = Vector2(sgn, 0.0)
	p.spread = 12.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 15.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.82, 0.88, 0.94, 0.0))
	ramp.add_point(0.25, Color(0.82, 0.88, 0.94, 0.3))
	ramp.add_point(0.75, Color(0.82, 0.88, 0.94, 0.3))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.82, 0.88, 0.94, 0.0))
	p.color_ramp = ramp
	return p


## Капель со стрех: короткие падающие капли из точек на крышах.
func _drip() -> CPUParticles2D:
	var p := _base("drip", streak_texture())
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = PackedVector2Array([Vector2(360, 300)])
	p.position = Vector2.ZERO
	p.lifetime = 0.55
	p.preprocess = 0.55
	p.direction = Vector2(0, 1)
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector2(0, 520)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.8
	p.particle_flag_align_y = true
	p.color = Color(0.85, 0.93, 1.0, 0.85)
	return p


static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


# =============================================================
# Текстуры, рисуются кодом: новых картинок погода не требует
# =============================================================
static func dot_texture() -> ImageTexture:
	if _dot_tex == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in range(16):
			for x in range(16):
				var d := Vector2(x + 0.5 - 8.0, y + 0.5 - 8.0).length() / 8.0
				img.set_pixel(x, y, Color(1, 1, 1, smoothstep(1.0, 0.3, d)))
		_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex


## Капля дождя: длинная, хвост бледнее головы.
static func streak_texture() -> ImageTexture:
	if _streak_tex == null:
		var img := Image.create(2, 48, false, Image.FORMAT_RGBA8)
		for y in range(48):
			var along := pow(float(y) / 47.0, 1.4)
			for x in range(2):
				img.set_pixel(x, y, Color(1, 1, 1, along))
		_streak_tex = ImageTexture.create_from_image(img)
	return _streak_tex


## Полоска позёмки: горизонтальная, мягкая по краям.
static func dash_texture() -> ImageTexture:
	if _dash_tex == null:
		var img := Image.create(32, 3, false, Image.FORMAT_RGBA8)
		for x in range(32):
			var along := sin(PI * (float(x) + 0.5) / 32.0)
			for y in range(3):
				img.set_pixel(x, y, Color(1, 1, 1, along * (1.0 if y == 1 else 0.4)))
		_dash_tex = ImageTexture.create_from_image(img)
	return _dash_tex


static func leaf_texture() -> ImageTexture:
	if _leaf_tex == null:
		var img := Image.create(14, 8, false, Image.FORMAT_RGBA8)
		for y in range(8):
			for x in range(14):
				var u := (float(x) + 0.5) / 14.0 * 2.0 - 1.0
				var v := (float(y) + 0.5) / 8.0 * 2.0 - 1.0
				var width := 1.0 - u * u
				var inside := absf(v) < width * 0.95
				img.set_pixel(x, y, Color(1, 1, 1, 0.92 if inside else 0.0))
		_leaf_tex = ImageTexture.create_from_image(img)
	return _leaf_tex


## Мягкое облако для тумана.
static func mist_texture() -> ImageTexture:
	if _mist_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var d := Vector2(x + 0.5 - 32.0, y + 0.5 - 32.0).length() / 32.0
				img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.6)))
		_mist_tex = ImageTexture.create_from_image(img)
	return _mist_tex


## Снег на земле: тонкий налёт везде и плотные пятна в углублениях. Один раз на запуск, 192×144.
static func snow_texture() -> ImageTexture:
	if _snow_tex == null:
		var big := FastNoiseLite.new()
		big.seed = 7121
		big.frequency = 0.03
		big.fractal_octaves = 2
		var fine := FastNoiseLite.new()
		fine.seed = 331
		fine.frequency = 0.11
		fine.fractal_octaves = 3
		var w := 192
		var h := 144
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in range(h):
			for x in range(w):
				var lo := big.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
				var hi := fine.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
				var a := 0.18 + 0.5 * smoothstep(0.3, 0.7, lo * 0.55 + hi * 0.45)
				img.set_pixel(x, y, Color(0.93, 0.96, 1.0, a))
		_snow_tex = ImageTexture.create_from_image(img)
	return _snow_tex


# =============================================================
# Мошкара у фонарей и рябь на лужах: рисуются кодом, а не частицами
# =============================================================
class Midges extends Node2D:
	var spots := PackedVector2Array()
	var per_lamp := 6
	var _t := 0.0

	func count() -> int:
		return per_lamp

	func _process(delta: float) -> void:
		_t += delta

	func _draw() -> void:
		for i in range(spots.size()):
			for j in range(per_lamp):
				var a := _t * (1.4 + 0.35 * j) + j * 1.9 + i * 0.7
				var r := 9.0 + 7.0 * sin(_t * 0.6 + j * 2.3 + i)
				var p := spots[i] + Vector2(cos(a) * r, sin(a * 1.3) * r * 0.6)
				draw_circle(p, 3.0, Color(1.0, 0.9, 0.6, 0.16))
				draw_circle(p, 1.3, Color(1.0, 0.97, 0.85, 0.95))


class Ripples extends Node2D:
	var spots := PackedVector3Array()
	var per_spot := 2
	var strength := 1.0
	var _t := 0.0

	func count() -> int:
		return per_spot

	func _process(delta: float) -> void:
		_t += delta

	func _draw() -> void:
		for i in range(spots.size()):
			var s := spots[i]
			for j in range(per_spot):
				var ph := fposmod(_t * 0.8 + i * 0.37 + j * 0.5, 1.0)
				var c := Vector2(s.x + sin(float(i * 7 + j * 3) + floorf(_t * 0.8 + i * 0.37 + j * 0.5) * 2.1) * s.z * 0.3, s.y + 6.0 * (j - 0.5))
				draw_set_transform(c, 0.0, Vector2(1.0, 0.35))
				draw_arc(Vector2.ZERO, 3.0 + ph * 13.0, 0.0, TAU, 20, Color(0.82, 0.9, 1.0, (1.0 - ph) * 0.5 * strength), 1.0)
		draw_set_transform(Vector2.ZERO)
