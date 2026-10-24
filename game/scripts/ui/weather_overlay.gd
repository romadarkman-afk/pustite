class_name WeatherOverlay
extends Control
## Погода внутри интерфейса: сцены, дверь. Те же атласы и тот же движок частиц, что на поле,
## но по размеру контрола. Состояние берётся у Weather.state(); осадки и туман выбираются по нему.
## Контрол не ловит нажатия и обрезает частицы по своей рамке. Размер задаёт тот, кто его добавляет.

const MAX_PARTICLES := 48

var state: Dictionary = Weather.EMPTY.duplicate()
var night := 1.0                      ## 0 день, 1 ночь: гасит яркость частиц
var _nodes: Dictionary = {}
var _mist: TextureRect
var _hash := -1


func _init() -> void:
	name = "WeatherOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_layout)


## Что идёт сейчас: "rain", "snow" или "" и сила осадков.
static func kind_of(s: Dictionary) -> String:
	if not bool(s.get("active", false)) or float(s.get("power", 0.0)) <= 0.02:
		return ""
	match int(s.get("precip", Weather.Precip.NONE)):
		Weather.Precip.RAIN:
			return "rain"
		Weather.Precip.SNOW:
			return "snow"
	return ""


## Состояние для явной погоды кадра сцены. Туман кадра рисует сама сцена плоской вуалью.
static func state_for_frame(kind: String) -> Dictionary:
	var s := Weather.EMPTY.duplicate()
	if kind == "rain":
		s["active"] = true
		s["precip"] = Weather.Precip.RAIN
		s["power"] = 0.7
		s["wind"] = 0.3
	return s


func apply(s: Dictionary, night_value := 1.0) -> void:
	night = night_value
	var h := [s, night_value].hash()
	if h == _hash:
		return
	_hash = h
	state = s
	for n: Node in _nodes.values():
		remove_child(n)
		n.queue_free()
	_nodes.clear()
	var kind := kind_of(s)
	var p := float(s.get("power", 0.0))
	if kind == "rain":
		_add("rain_far", _rain(300.0, 0.16, 0.45), clampf(p * 1.4, 0.3, 1.0), 40)
		_add("rain_near", _rain(520.0, 0.3, 0.6), clampf(p * 1.2, 0.25, 1.0), 20)
	elif kind == "snow":
		_add("flakes_far", _flakes(40.0, 0.08, 0.8), clampf(p * 1.2, 0.3, 1.0), 40)
		_add("flakes_near", _flakes(80.0, 0.17, 0.95), clampf(p, 0.25, 1.0), 16)
	var fog := float(s.get("fog", 0.0))
	if fog > 0.05:
		if _mist == null:
			_mist = TextureRect.new()
			_mist.name = "Mist"
			_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_mist.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_mist.stretch_mode = TextureRect.STRETCH_SCALE
			var g := Gradient.new()
			g.set_color(0, Color(0.74, 0.8, 0.86, 0.0))
			g.set_color(1, Color(0.74, 0.8, 0.86, 1.0))
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.fill_from = Vector2(0.5, 0.0)
			gt.fill_to = Vector2(0.5, 1.0)
			_mist.texture = gt
			_mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(_mist)
		_mist.visible = true
		_mist.modulate.a = clampf(fog * 0.45, 0.0, 0.5) * (1.0 - 0.4 * night)
	elif _mist != null:
		_mist.visible = false
	_layout()


func emitter_names() -> PackedStringArray:
	var out := PackedStringArray(_nodes.keys())
	out.sort()
	return out


func particle_total() -> int:
	var total := 0
	for n: CPUParticles2D in _nodes.values():
		total += n.amount
	return total


func _add(key: String, p: CPUParticles2D, strength: float, full: int) -> void:
	p.amount = mini(MAX_PARTICLES, maxi(1, roundi(full * strength)))
	var tint := Color.WHITE.lerp(Color(0.6, 0.67, 0.86), night)
	p.modulate = Color(tint, 1.0)
	_nodes[key] = p
	add_child(p)


func _rain(speed: float, sc: float, alpha: float) -> CPUParticles2D:
	var p := WeatherLayer.make_emitter("rain", "rain")
	var wind := float(state.get("wind", 0.2))
	p.direction = Vector2(0.1 + wind * 0.35, 1.0).normalized()
	p.spread = 2.0
	p.initial_velocity_min = speed * 0.92
	p.initial_velocity_max = speed * 1.08
	p.scale_amount_min = sc * 0.9
	p.scale_amount_max = sc * 1.1
	p.particle_flag_align_y = true
	p.color = Color(0.82, 0.89, 0.97, alpha)
	p.set_meta("fall", speed)
	return p


func _flakes(fall: float, sc: float, alpha: float) -> CPUParticles2D:
	var p := WeatherLayer.make_emitter("flakes", "flake")
	var wind := float(state.get("wind", 0.2))
	p.direction = Vector2(wind * 0.5, 1.0)
	p.spread = 18.0
	p.initial_velocity_min = fall * 0.8
	p.initial_velocity_max = fall * 1.2
	p.gravity = Vector2(wind * 30.0, 0.0)
	p.scale_amount_min = sc * 0.7
	p.scale_amount_max = sc * 1.2
	p.angle_max = 360.0
	p.angular_velocity_min = -40.0
	p.angular_velocity_max = 40.0
	p.color = Color(0.94, 0.97, 1.0, alpha)
	p.set_meta("fall", fall)
	return p


## Рамка частиц под размер контрола: падают сверху и заканчивают путь внизу.
func _layout() -> void:
	var sz := size
	if sz.x < 4.0 or sz.y < 4.0:
		return
	for key: String in _nodes.keys():
		var p: CPUParticles2D = _nodes[key]
		var fall := maxf(float(p.get_meta("fall", 100.0)), 10.0)
		p.position = Vector2(sz.x * 0.5, -24.0)
		p.emission_rect_extents = Vector2(sz.x * 0.5 + 30.0, 2.0)
		p.lifetime = (sz.y + 60.0) / fall
		p.preprocess = p.lifetime
		p.restart()
