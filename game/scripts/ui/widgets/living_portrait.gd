class_name LivingPortrait
extends TextureRect
## TASK-076. Лёгкое движение портрета: дыхание (до 2% по размеру, период 3-4 с), дрожь при страхе
## (до 2 px, сильнее при сильном страхе), наклон при горе и отчаянии, затемнение, когда жителя
## уличили во лжи, моргание по второй картинке с закрытыми глазами. Нет такой картинки у жителя:
## моргания у него нет, остальное работает. Размер виджета остаётся постоянным.

const BREATH_PERIOD := 3.5          ## с, между 3 и 4
const BREATH_X := 0.008             ## глубина вдоха по ширине
const BREATH_Y := 0.012             ## по высоте
const SHAKE_MIN := 0.8              ## px при слабом страхе
const SHAKE_MAX := 2.0              ## px при страхе на полную силу
const TILT := -0.035                ## наклон при горе, рад
const LIE_DARK := Color(0.72, 0.72, 0.78)
const BLINK_GAP := Vector2(3.0, 6.0)  ## между морганиями, с
const BLINK_LEN := 0.12

var state: String = ""
var intensity := 1.0                ## сила чувства 0..1, от неё зависит дрожь
var active := true
var blink_texture: Texture2D        ## тот же портрет с закрытыми глазами; null: не моргает
var lying := false:
	set(v):
		lying = v
		self_modulate = LIE_DARK if v else Color.WHITE
var _time := 0.0
var _rest_x := 0.0
var _last_x := 0.0
var _blink_in := -1.0
var _blink_left := 0.0
var _open_texture: Texture2D
var _dice := RandomNumberGenerator.new()


func _ready() -> void:
	_dice.seed = hash("blink:%s:%s" % [get_instance_id(), Time.get_ticks_msec()])
	_blink_in = _dice.randf_range(BLINK_GAP.x, BLINK_GAP.y)


func _process(delta: float) -> void:
	if not active or texture == null:
		return
	_time += delta
	pose(_time)
	_tick_blink(delta)


## Положение портрета в момент t: зависит только от времени и полей, поэтому его можно мерить в тесте.
func pose(t: float) -> void:
	pivot_offset = size * 0.5
	var phase := sin(t * TAU / BREATH_PERIOD)
	scale = Vector2(1.0 + BREATH_X * phase, 1.0 + BREATH_Y * phase)
	rotation = TILT if state == "grief" or state == "despair" else 0.0
	var shake := 0.0
	if state == "fear":
		shake = sin(t * 13.0) * lerpf(SHAKE_MIN, SHAKE_MAX, clampf(intensity, 0.0, 1.0))
	# контейнер мог сам сдвинуть портрет: тогда за основу берём его положение, а не наше прошлое
	if not is_equal_approx(position.x, _last_x):
		_rest_x = position.x
	position.x = _rest_x + shake
	_last_x = position.x


func _tick_blink(delta: float) -> void:
	if blink_texture == null:
		return
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_open()
		return
	_blink_in -= delta
	if _blink_in <= 0.0:
		blink_now()


## Закрыть глаза на BLINK_LEN секунд. Без картинки ничего не делает.
func blink_now() -> void:
	if blink_texture == null or _blink_left > 0.0:
		return
	_open_texture = texture
	texture = blink_texture
	_blink_left = BLINK_LEN
	_blink_in = _dice.randf_range(BLINK_GAP.x, BLINK_GAP.y)


func is_blinking() -> bool:
	return _blink_left > 0.0


func _open() -> void:
	if _open_texture != null:
		texture = _open_texture
	_blink_left = 0.0
