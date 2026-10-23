class_name Atmosphere
extends ColorRect
## Фон: туман, лампа, дверь. Экраны управляют им через вызовы, а не напрямую через шейдер.

const SHADER := preload("res://shaders/atmos.gdshader")
const DOOR_CLOSED_PATH := "res://assets/ui/door_closed.png"
const DOOR_OPEN_PATH := "res://assets/ui/door_open.png"

var mat: ShaderMaterial
var _door_art: Control
var _door_closed: TextureRect
var _door_open: TextureRect
var _candle: DoorCandle
var _tension: TextureRect              ## виньетка ночного напряжения (TASK-077)
var _tension_grad: Gradient
var _shadow: TextureRect               ## тень мимо двери (TASK-077)
var _shadow_tween: Tween
const SHADOW_PATH := "res://assets/ui/window_shadow.png"   ## картинка от Влади; нет файла: тёмное пятно
## Четыре двери (TASK-078): изба, мельница, келья, вагон. Картинки door_<id>_closed.png и _open.png;
## нет файла: общая дверь с оттенком карты. candle — где стоит свеча (доли экрана), shadow_y — где идёт тень,
## peep — светлая щель, у которой осмотр через глазок (доля ширины).
const DOOR_STYLES := {
	"": {"id": "izba", "candle": Vector2(0.86, 0.66), "shadow_y": 0.50, "peep": 0.50, "tint": Color(1, 1, 1)},
	"ground_mill": {"id": "mill", "candle": Vector2(0.84, 0.64), "shadow_y": 0.50, "peep": 0.50, "tint": Color(0.82, 0.91, 1.0)},
	"ground_monastery": {"id": "cell", "candle": Vector2(0.14, 0.64), "shadow_y": 0.48, "peep": 0.50, "tint": Color(0.98, 0.88, 0.76)},
	"ground_station": {"id": "wagon", "candle": Vector2(0.86, 0.60), "shadow_y": 0.46, "peep": 0.50, "tint": Color(0.78, 0.84, 0.91)},
}
const DOOR_DEFAULT := {"closed": "res://assets/ui/door_closed.png", "open": "res://assets/ui/door_open.png"}
var door_style: Dictionary = DOOR_STYLES[""]
var _door_paths: Dictionary = {}
var _art_tween: Tween
var _pose_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	_door_art = Control.new()
	_door_art.name = "DoorArt"
	_door_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_art.visible = false
	_door_art.modulate.a = 0.0
	_door_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_door_art)
	_door_closed = _door_layer(null, "Closed")     # картинки по 8,5 МиБ в видеопамяти: грузятся при входе к двери, уходят вместе с ней
	_door_open = _door_layer(null, "Open")
	_door_art.add_child(_door_closed)
	_door_art.add_child(_door_open)
	_candle = DoorCandle.new()
	_door_art.add_child(_candle)
	_door_open.modulate.a = 0.0
	_tension_grad = Gradient.new()
	_tension_grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_tension_grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.9)])
	var vtex := GradientTexture2D.new()
	vtex.gradient = _tension_grad
	vtex.fill = GradientTexture2D.FILL_RADIAL
	vtex.fill_from = Vector2(0.5, 0.5)
	vtex.fill_to = Vector2(1.0, 0.5)
	vtex.width = 128
	vtex.height = 128
	_tension = TextureRect.new()
	_tension.name = "Tension"
	_tension.texture = vtex
	_tension.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tension.stretch_mode = TextureRect.STRETCH_SCALE
	_tension.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tension.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tension.modulate.a = 0.0
	add_child(_tension)

	var fnl := FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fnl.frequency = 0.012
	fnl.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = fnl
	mat.set_shader_parameter("noise_tex", tex)
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	if size.x > 0.0:
		mat.set_shader_parameter("aspect", size.y / size.x)


func _door_layer(tex: Texture2D, node_name: String) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = node_name
	layer.texture = tex
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.use_parent_material = false
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return layer


func _param(name: String) -> float:
	var v: Variant = mat.get_shader_parameter(name)
	return float(v) if v != null else 0.0


func _to(name: String, value: float, dur: float) -> void:
	if Juice.instant or dur <= 0.0:
		mat.set_shader_parameter(name, value)
		return
	Juice.tween().tween_method(func(v: float) -> void: mat.set_shader_parameter(name, v),
		_param(name), value, dur)


func mood(night: float, lamp: float, dur: float = 0.9) -> void:
	_to("night", night, dur)
	_to("lamp_power", lamp, dur)
	_to("door_mix", 0.0, dur * 0.6)
	_fade_door_art(0.0, dur * 0.6)


func door(open_amount: float, dur: float = 0.7) -> void:
	_ensure_door_textures()
	var entering := not _door_art.visible or _door_art.modulate.a <= 0.02
	_door_art.visible = true
	_to("door_mix", 1.0, dur)
	_set_door_pose(open_amount, 0.0 if entering else minf(dur, 0.18))
	_fade_door_art(1.0, dur)


## Картинки двери этой карты: свои, если лежат в assets/ui, иначе общая.
static func door_paths(ground: String) -> Dictionary:
	var st: Dictionary = DOOR_STYLES.get(ground, DOOR_STYLES[""])
	var own_closed := "res://assets/ui/door_%s_closed.png" % st.id
	var own_open := "res://assets/ui/door_%s_open.png" % st.id
	if ResourceLoader.exists(own_closed) and ResourceLoader.exists(own_open):
		return {"closed": own_closed, "open": own_open, "own": true}
	return {"closed": DOOR_DEFAULT.closed, "open": DOOR_DEFAULT.open, "own": false}


func set_door_place(ground: String) -> void:
	door_style = DOOR_STYLES.get(ground, DOOR_STYLES[""])
	var paths := door_paths(ground)
	_door_paths = paths
	_load_door_textures()
	# своя картинка уже в цвете места; общая красится оттенком карты
	var tint: Color = Color.WHITE if bool(paths.own) else door_style.tint
	_door_closed.modulate = Color(tint.r, tint.g, tint.b, _door_closed.modulate.a)
	_door_open.modulate = Color(tint.r, tint.g, tint.b, _door_open.modulate.a)
	_candle.place = door_style.candle


func _load_door_textures() -> void:
	_door_closed.texture = load(String(_door_paths.closed)) as Texture2D
	_door_open.texture = load(String(_door_paths.open)) as Texture2D


func _ensure_door_textures() -> void:
	if _door_closed.texture == null or _door_open.texture == null:
		if _door_paths.is_empty():
			_door_paths = door_paths("")
		_load_door_textures()


## Дверь погасла: картинки отпускаются, видеопамять свободна до следующей двери.
func _release_door_textures() -> void:
	_door_closed.texture = null
	_door_open.texture = null


func _set_door_pose(open_amount: float, dur: float) -> void:
	var mix_open: float = clampf((open_amount - 0.07) / 0.28, 0.0, 1.0)
	if _pose_tween != null and _pose_tween.is_running():
		_pose_tween.kill()
	if Juice.instant or dur <= 0.0:
		_door_closed.modulate.a = 1.0 - mix_open
		_door_open.modulate.a = mix_open
		return
	_pose_tween = Juice.tween().set_parallel(true)
	_pose_tween.tween_property(_door_closed, "modulate:a", 1.0 - mix_open, dur)
	_pose_tween.tween_property(_door_open, "modulate:a", mix_open, dur)


func _fade_door_art(alpha: float, dur: float) -> void:
	if _art_tween != null and _art_tween.is_running():
		_art_tween.kill()
	if alpha > 0.01:
		_door_art.visible = true
	if Juice.instant or dur <= 0.0:
		_door_art.modulate.a = alpha
		if alpha <= 0.01:
			_door_art.visible = false
			_release_door_textures()
		return
	_art_tween = Juice.tween()
	_art_tween.tween_property(_door_art, "modulate:a", alpha, dur)
	if alpha <= 0.01:
		_art_tween.tween_callback(func() -> void:
			if _door_art.modulate.a <= 0.01:
				_door_art.visible = false
				_release_door_textures())


## Виньетка сужается с каждой ночью (TASK-077): первая почти не заметна, седьмая подступает к середине.
## Яркость и край считаются от номера ночи, поэтому одна и та же ночь выглядит одинаково.
func set_tension(day: int) -> void:
	if day <= 0:
		_tension.modulate.a = 0.0
		return
	var n := clampi(day - 1, 0, 6)
	_tension_grad.offsets = PackedFloat32Array([0.0, lerpf(0.5, 0.22, float(n) / 6.0), 1.0])
	_tension.modulate.a = lerpf(0.1, 0.55, float(n) / 6.0)


func tension_alpha() -> float:
	return _tension.modulate.a


## Тень идёт мимо двери слева направо (TASK-077). Картинка силуэта от Влади или тёмное пятно.
func pass_shadow() -> void:
	if Juice.instant or size.x <= 0.0:
		return
	if _shadow == null:
		_shadow = TextureRect.new()
		_shadow.name = "WindowShadow"
		_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(SHADOW_PATH):
			_shadow.texture = load(SHADOW_PATH) as Texture2D
		else:
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
			g.colors = PackedColorArray([Color(0, 0, 0, 0.9), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
			var t := GradientTexture2D.new()
			t.gradient = g
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(1.0, 0.5)
			t.width = 64
			t.height = 192
			_shadow.texture = t
		_shadow.size = Vector2(150.0, 420.0)
		add_child(_shadow)
		move_child(_shadow, _tension.get_index())
	if _shadow_tween != null and _shadow_tween.is_running():
		return
	var y := size.y * float(door_style.shadow_y) - _shadow.size.y * 0.5
	_shadow.position = Vector2(-_shadow.size.x, y)
	_shadow.modulate.a = 0.0
	_shadow_tween = create_tween().set_parallel(true)
	_shadow_tween.tween_property(_shadow, "position:x", size.x, 3.4).set_trans(Tween.TRANS_SINE)
	_shadow_tween.tween_property(_shadow, "modulate:a", 0.6, 1.0)
	_shadow_tween.chain().tween_property(_shadow, "modulate:a", 0.0, 1.0).set_delay(1.2)


func flicker() -> void:
	_candle.flicker()


func set_candle(level: int, instant: bool) -> void:
	_candle.set_level(level, instant)


func knock() -> void:
	_candle.flare()
	mat.set_shader_parameter("knock", 1.0)
	_to("knock", 0.0, 0.28)


func blood_flash() -> void:
	mat.set_shader_parameter("flash", 1.0)
	_to("flash", 0.0, 0.7)
