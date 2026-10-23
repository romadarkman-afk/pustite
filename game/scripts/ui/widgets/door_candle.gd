class_name DoorCandle
extends Control
## Небольшой огонь у двери. Мерцает одинаково при любом госте.

var _time := 0.0
var _flare := 0.0
var _halo: LightHalo
var _level := 0              ## -1 тусклая, 0 обычная, 1 яркая (TASK-073)
var _shown := 1.0            ## плавный множитель огня: 0.62 / 1.0 / 1.38
const LEVEL_SCALE: Array[float] = [0.62, 1.0, 1.38]
const FLICKER_LEN := 1.0     ## мигание перед стуком (TASK-077)
var _flicker := 0.0
var place := Vector2(0.86, 0.66)       ## где стоит свеча, доли экрана; задаёт стиль двери (TASK-078)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo = LightHalo.new()
	_halo.radius = 44.0
	_halo.color = Color("ff9e2c")
	_halo.intensity = 0.42
	_halo.flicker = 0.18
	_halo.z_index = -1
	add_child(_halo)


func flare() -> void:
	_flare = 0.55


## Огонь дёргается и почти гаснет несколько раз подряд, потом выравнивается.
func flicker() -> void:
	_flicker = FLICKER_LEN


func flicker_factor() -> float:
	if _flicker <= 0.0:
		return 1.0
	var k := _flicker / FLICKER_LEN
	return lerpf(1.0, 0.18 + 0.82 * absf(sin(_flicker * 21.0)), minf(1.0, k * 3.0))


func set_level(level: int, instant: bool = false) -> void:
	_level = clampi(level, -1, 1)
	if instant:
		_shown = LEVEL_SCALE[_level + 1]


func _process(delta: float) -> void:
	_time += delta
	_flare = maxf(0.0, _flare - delta)
	_flicker = maxf(0.0, _flicker - delta)
	_shown = move_toward(_shown, LEVEL_SCALE[_level + 1], delta * 1.6)
	if _halo != null:
		_halo.position = Vector2(size.x * place.x, size.y * place.y)
		_halo.radius = 44.0 * _shown
		_halo.set_intensity((0.42 + _flare * 0.16 + sin(_time * 5.0) * 0.035) * _shown * flicker_factor())
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * place.x, size.y * place.y)
	var wav := sin(_time * 8.1) * 0.11 + sin(_time * 13.7) * 0.07
	var power := (1.0 + wav + _flare * 0.8) * _shown * flicker_factor()
	draw_rect(Rect2(center.x - 5.0, center.y + 1.0, 10.0, 26.0), Color(0.16, 0.12, 0.12, 0.95))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-5, 2), center + Vector2(-3, -12 * power),
		center + Vector2(wav * 9, -22 * power), center + Vector2(4, -9 * power),
		center + Vector2(5, 2)]), Color(1.0, 0.55, 0.18, 0.92))
	draw_circle(center + Vector2(0, -3), 2.5, Color(1.0, 0.92, 0.58))
