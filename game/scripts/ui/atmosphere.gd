class_name Atmosphere
extends ColorRect
## Фон: туман, лампа, дверь. Экраны управляют им через вызовы, а не напрямую через шейдер.

const SHADER := preload("res://shaders/atmos.gdshader")

var mat: ShaderMaterial


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	material = mat

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


func door(open_amount: float, dur: float = 0.7) -> void:
	_to("door_mix", 1.0, dur)
	_to("door_open", open_amount, dur)


func knock() -> void:
	mat.set_shader_parameter("knock", 1.0)
	_to("knock", 0.0, 0.28)


func blood_flash() -> void:
	mat.set_shader_parameter("flash", 1.0)
	_to("flash", 0.0, 0.7)
