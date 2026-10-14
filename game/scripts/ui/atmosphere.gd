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
	_door_closed = _door_layer(load(DOOR_CLOSED_PATH) as Texture2D, "Closed")
	_door_open = _door_layer(load(DOOR_OPEN_PATH) as Texture2D, "Open")
	_door_art.add_child(_door_closed)
	_door_art.add_child(_door_open)
	_door_open.modulate.a = 0.0

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
	var entering := not _door_art.visible or _door_art.modulate.a <= 0.02
	_door_art.visible = true
	_to("door_mix", 1.0, dur)
	_set_door_pose(open_amount, 0.0 if entering else minf(dur, 0.18))
	_fade_door_art(1.0, dur)


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
		return
	_art_tween = Juice.tween()
	_art_tween.tween_property(_door_art, "modulate:a", alpha, dur)
	if alpha <= 0.01:
		_art_tween.tween_callback(func() -> void:
			if _door_art.modulate.a <= 0.01:
				_door_art.visible = false)


func knock() -> void:
	mat.set_shader_parameter("knock", 1.0)
	_to("knock", 0.0, 0.28)


func blood_flash() -> void:
	mat.set_shader_parameter("flash", 1.0)
	_to("flash", 0.0, 0.7)
