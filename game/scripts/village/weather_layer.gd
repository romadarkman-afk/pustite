class_name WeatherLayer
extends Node2D
## Погода на поле (TASK-061, 063–066). Слой лежит внутри VillageView, над толпой и под виньеткой.
## Состояние даёт Weather.state(); слой создаёт эмиттеры под него и удаляет ненужные.
## Все частицы рисует движок (CPUParticles2D) по картинкам из assets/weather: снежинки, капли,
## листья берутся из атласов, а не из кода. Снег и лужи на земле, трава и тени облаков живут
## в GroundFx и шейдерах; слой только передаёт им состояние.
## На каждый эмиттер не больше MAX_PARTICLES частиц, упрощённая графика режет их вдвое.

const MAX_PARTICLES := 60
const AREA := Rect2(-120, 100, 960, 460)            ## где идёт осадок, в координатах посёлка
const FALL_H := 440.0                               ## высота падения осадка
const DIR := "res://assets/weather/"

## Сколько частиц у эмиттера при полной силе. Все числа не больше MAX_PARTICLES.
## У мошкары и ряби число на одну точку (фонарь, лужу), общее число всё равно ограничено.
const FULL := {
	"rain_far": 60, "rain_back": 60, "rain_mid": 60, "rain_near": 40, "splash": 48, "ripples": 6,
	"flakes_far": 60, "flakes_mid": 60, "flakes_near": 40, "drift": 24, "grains": 40,
	"fluff": 40, "ash": 40, "midges": 6, "leaves": 30, "drip": 40, "mist": 16,
}

## Атласы: файл, столбцов, строк. Настоящие картинки ChatGPT ложатся на место заглушек.
const SHEETS := {
	"flake": ["flake_sheet.png", 4, 4], "rain": ["rain_sheet.png", 4, 1],
	"splash": ["splash_sheet.png", 4, 2], "ripple": ["ripple_sheet.png", 4, 2],
	"leaf": ["leaf_sheet.png", 4, 2], "fluff": ["fluff_sheet.png", 4, 2],
	"ember": ["ember_sheet.png", 4, 2], "mist": ["mist_sheet.png", 2, 2],
}

var view: VillageView
var state: Dictionary = Weather.EMPTY.duplicate()
var simplified := false
var _nodes: Dictionary = {}                         ## имя -> CPUParticles2D
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
	set_process(bool(s.get("active", false)))
	refresh_geometry()
	_tick(0.0)


func set_simplified(on: bool) -> void:
	if on == simplified:
		return
	simplified = on
	var want := wanted(state)
	for key: String in _nodes.keys():
		_set_amount(key, float(want.get(key, 0.0)))
	if view != null:
		for fx: GroundFx in [view.ground_fx, view.sky_fx]:
			if fx != null:
				fx.set_simplified(on)
	_tick(0.0)


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
				out["splash"] = clampf(p * 1.2, 0.2, 1.0)
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


## Сколько частиц у эмиттера сейчас.
func amount_of(key: String) -> int:
	var n: Node = _nodes.get(key)
	if n is CPUParticles2D:
		return (n as CPUParticles2D).amount
	return 0


func particle_total() -> int:
	var total := 0
	for key: String in _nodes.keys():
		total += amount_of(key)
	return total


## Сколько частиц у эмиттера при силе strength. У мошкары и ряби число на точку, точек берётся по карте.
func target_count(key: String, strength: float, half := false) -> int:
	var count := maxi(1, roundi(float(FULL[key]) * clampf(strength, 0.0, 1.0)))
	if view != null and view.def != null:
		if key == "midges":
			count *= maxi(1, view.def.lamps.size())
		elif key == "ripples":
			count *= maxi(1, view.def.puddle_spots.size())
	count = mini(count, MAX_PARTICLES)
	return maxi(1, ceili(float(count) * 0.5)) if half else count


func _set_amount(key: String, strength: float) -> void:
	var n: Node = _nodes.get(key)
	var count := target_count(key, strength, simplified)
	if n is CPUParticles2D:
		var pr := n as CPUParticles2D
		if pr.amount != count:
			pr.amount = count
			if pr.is_inside_tree():
				pr.restart()


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
	var midges: CPUParticles2D = _nodes.get("midges")
	if midges != null:
		var spots := PackedVector2Array()
		for lamp: Vector2 in view.def.lamps:
			spots.append(lamp + Vector2(12, -61))
		if spots.is_empty():
			spots.append(Vector2(360, 300))
		midges.emission_points = spots
		_set_amount("midges", float(wanted(state).get("midges", 0.0)))
	var ripples: CPUParticles2D = _nodes.get("ripples")
	if ripples != null:
		var rp := PackedVector2Array()
		var rng := RandomNumberGenerator.new()
		rng.seed = 91
		for s: Vector3 in view.def.puddle_spots:
			for _k in range(8):
				var a := rng.randf() * TAU
				var d := sqrt(rng.randf())
				rp.append(Vector2(s.x + cos(a) * d * s.z * 0.8, s.y + sin(a) * d * s.z * 0.8 * 0.36))
		if rp.is_empty():
			rp.append(Vector2(360, 460))
		ripples.emission_points = rp
		_set_amount("ripples", float(wanted(state).get("ripples", 0.0)))


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
		var p: CPUParticles2D = _nodes[key]
		var vis := vis_for(key, n)
		var tint := Color.WHITE if _emissive(key) else (snowy if _is_snow(key) else cold)
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
	if view != null:
		for fx: GroundFx in [view.ground_fx, view.sky_fx]:
			if fx != null:
				fx.update_state(state, n)


## Видимость эмиттера по времени суток: пух днём, пепел в сумерках, мошкара ночью.
static func vis_for(key: String, n: float) -> float:
	match key:
		"fluff":
			return 1.0 - smoothstep(0.15, 0.5, n)
		"ash":
			return clampf(1.0 - absf(n - 0.5) * 3.2, 0.0, 1.0)
		"midges":
			return smoothstep(0.5, 0.85, n)
		"ripples", "drip", "splash":
			return 1.0 - 0.3 * n
	return 1.0


func _is_snow(key: String) -> bool:
	return key.begins_with("flakes") or key == "drift" or key == "grains"


func _emissive(key: String) -> bool:
	return key == "ash" or key == "midges"


# =============================================================
# Сборка эмиттеров: картинки из атласов, анимация кадров делает движок
# =============================================================
func _make(key: String) -> CPUParticles2D:
	match key:
		"rain_far":
			return _rain(key, 330.0, 0.24, Color(0.78, 0.86, 0.96, 0.45))
		"rain_back":
			return _rain(key, 280.0, 0.19, Color(0.74, 0.82, 0.92, 0.34))
		"rain_mid":
			return _rain(key, 430.0, 0.34, Color(0.82, 0.89, 0.97, 0.55))
		"rain_near":
			return _rain(key, 560.0, 0.48, Color(0.86, 0.92, 0.98, 0.68))
		"splash":
			return _splash()
		"ripples":
			return _ripples()
		"flakes_far":
			return _flakes(key, 38.0, 0.045, 0.7)
		"flakes_mid":
			return _flakes(key, 62.0, 0.075, 0.85)
		"flakes_near":
			return _flakes(key, 96.0, 0.125, 0.95)
		"drift":
			return _drift()
		"grains":
			return _grains()
		"fluff":
			return _fluff()
		"ash":
			return _ash()
		"midges":
			return _midges()
		"leaves":
			return _leaves()
		"drip":
			return _drip()
		"mist":
			return _mist()
	return null


## Эмиттер с атласом: материал включает анимацию кадров по сетке h×v.
func _base(key: String, sheet: String, additive := false) -> CPUParticles2D:
	var def: Array = SHEETS[sheet]
	var p := CPUParticles2D.new()
	p.name = key
	p.texture = load(DIR + String(def[0])) as Texture2D
	var m := CanvasItemMaterial.new()
	m.particles_animation = true
	m.particles_anim_h_frames = int(def[1])
	m.particles_anim_v_frames = int(def[2])
	m.particles_anim_loop = false
	if additive:
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.gravity = Vector2.ZERO
	p.randomness = 1.0
	# каждая частица берёт случайный кадр атласа и держит его
	p.anim_speed_min = 0.0
	p.anim_speed_max = 0.0
	p.anim_offset_min = 0.0
	p.anim_offset_max = 0.999
	return p


## Анимация по кадрам за жизнь частицы: брызги и круги на воде.
func _play_frames(p: CPUParticles2D) -> void:
	p.anim_speed_min = 1.0
	p.anim_speed_max = 1.0
	p.anim_offset_min = 0.0
	p.anim_offset_max = 0.0


func _rain(key: String, speed: float, sc: float, col: Color) -> CPUParticles2D:
	var p := _base(key, "rain")
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


## Брызги от капель по всей земле: покадровая анимация из splash_sheet.
func _splash() -> CPUParticles2D:
	var p := _base("splash", "splash")
	_play_frames(p)
	p.lifetime = 0.5
	p.preprocess = 0.5
	p.position = Vector2(360, 400)
	p.emission_rect_extents = Vector2(430, 150)
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.scale_amount_min = 0.22
	p.scale_amount_max = 0.36
	p.color = Color(0.9, 0.95, 1.0, 0.75)
	return p


## Круги на лужах: покадровая анимация из ripple_sheet, точки по лужам карты.
func _ripples() -> CPUParticles2D:
	var p := _base("ripples", "ripple")
	_play_frames(p)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = PackedVector2Array([Vector2(360, 460)])
	p.position = Vector2.ZERO
	p.lifetime = 1.1
	p.preprocess = 1.1
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.5
	p.color = Color(0.85, 0.92, 1.0, 0.85)
	return p


func _flakes(key: String, fall: float, sc: float, alpha: float) -> CPUParticles2D:
	var p := _base(key, "flake")
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
	p.angle_max = 360.0
	p.angular_velocity_min = -40.0
	p.angular_velocity_max = 40.0
	p.color = Color(0.94, 0.97, 1.0, alpha)
	return p


## Позёмка: низкие облачка снежной пыли вдоль земли (мягкие кадры из mist_sheet).
func _drift() -> CPUParticles2D:
	var p := _base("drift", "mist")
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
	p.scale_amount_min = 0.14
	p.scale_amount_max = 0.3
	p.color = Color(0.94, 0.97, 1.0, 0.34)
	return p


## Снежная крупа: мелкие быстрые зёрна.
func _grains() -> CPUParticles2D:
	var p := _base("grains", "flake")
	var wind := float(state.get("wind", 0.0))
	p.lifetime = 1.5
	p.preprocess = 1.5
	p.position = Vector2(360.0 - wind * 200.0, AREA.position.y + 20.0)
	p.emission_rect_extents = Vector2(AREA.size.x * 0.5 + 100.0, 30.0)
	p.direction = Vector2(0.3 + wind * 0.5, 1.0)
	p.spread = 8.0
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 320.0
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.035
	p.color = Color(1, 1, 1, 0.8)
	return p


## Тополиный пух: крупные медленные пушинки днём.
func _fluff() -> CPUParticles2D:
	var p := _base("fluff", "fluff")
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.position = Vector2(360, 320)
	p.emission_rect_extents = Vector2(480, 190)
	p.direction = Vector2(1, 0.25)
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector2(0, 2.5)
	p.scale_amount_min = 0.14
	p.scale_amount_max = 0.26
	p.angle_max = 360.0
	p.angular_velocity_min = -30.0
	p.angular_velocity_max = 30.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 0.96, 0.0))
	ramp.add_point(0.2, Color(1, 1, 0.96, 0.85))
	ramp.add_point(0.8, Color(1, 1, 0.96, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 0.96, 0.0))
	p.color_ramp = ramp
	return p


## Тлеющий торфяной пепел: оранжевые искры в сумерках, поднимаются и гаснут.
func _ash() -> CPUParticles2D:
	var p := _base("ash", "ember", true)
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.position = Vector2(360, 430)
	p.emission_rect_extents = Vector2(460, 90)
	p.direction = Vector2(0.3, -1.0)
	p.spread = 35.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector2(4, -2)
	p.scale_amount_min = 0.09
	p.scale_amount_max = 0.18
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.7, 0.35, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.75, 0.4, 0.9))
	ramp.add_point(0.6, Color(0.9, 0.5, 0.25, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.5, 0.35, 0.3, 0.0))
	p.color_ramp = ramp
	return p


## Мошкара у фонарей: светлые точки кружат возле каждого фонаря (орбита считается движком).
func _midges() -> CPUParticles2D:
	var p := _base("midges", "ember", true)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = PackedVector2Array([Vector2(360, 300)])
	p.position = Vector2.ZERO
	p.lifetime = 2.6
	p.preprocess = 2.6
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 14.0
	p.damping_min = 2.0
	p.damping_max = 5.0
	p.orbit_velocity_min = -0.7
	p.orbit_velocity_max = 0.7
	p.radial_accel_min = -18.0
	p.radial_accel_max = 6.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.1
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.62, 0.0))
	ramp.add_point(0.2, Color(1.0, 0.95, 0.7, 1.0))
	ramp.add_point(0.8, Color(1.0, 0.95, 0.7, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.92, 0.62, 0.0))
	p.color_ramp = ramp
	return p


func _leaves() -> CPUParticles2D:
	var p := _base("leaves", "leaf")
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
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.2
	return p


## Густой ползущий туман: крупные мягкие облака у земли, плывут вдоль ветра.
func _mist() -> CPUParticles2D:
	var p := _base("mist", "mist")
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
	p.scale_amount_min = 0.55
	p.scale_amount_max = 0.95
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.82, 0.88, 0.94, 0.0))
	ramp.add_point(0.25, Color(0.82, 0.88, 0.94, 0.3))
	ramp.add_point(0.75, Color(0.82, 0.88, 0.94, 0.3))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.82, 0.88, 0.94, 0.0))
	p.color_ramp = ramp
	return p


## Капель со стрех: короткие падающие капли из точек на крышах.
func _drip() -> CPUParticles2D:
	var p := _base("drip", "rain")
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
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.2
	p.particle_flag_align_y = true
	p.color = Color(0.85, 0.93, 1.0, 0.85)
	return p
