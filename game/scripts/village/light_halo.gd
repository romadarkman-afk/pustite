class_name LightHalo
extends Node2D
## Небольшой аддитивный ореол у источника света. Рисуется спрайтом, не освещает землю.

static var _soft_texture_cache: GradientTexture2D

var radius: float = 28.0
var color: Color = Color("ff9e2c")
var intensity: float = 0.0
var flicker: float = 0.12
var _phase := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	name = "LightHalo"
	_phase = randf_range(0.0, TAU)
	_sprite = Sprite2D.new()
	_sprite.texture = _soft_texture()
	_sprite.centered = true
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sprite.material = additive
	add_child(_sprite)
	_sync_sprite()
	_sync_alpha()


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	_sync_alpha()


func _process(delta: float) -> void:
	if intensity <= 0.005:
		return
	_phase += delta * 2.4
	_sync_alpha()


func _sync_alpha() -> void:
	if _sprite == null:
		return
	_sprite.visible = intensity > 0.005
	var wave := 1.0 - flicker * 0.5 + flicker * 0.5 * sin(_phase)
	_sprite.modulate = Color(color, intensity * wave)


func _sync_sprite() -> void:
	if _sprite != null:
		_sprite.scale = Vector2.ONE * (radius * 2.0 / 128.0)


static func _soft_texture() -> GradientTexture2D:
	if _soft_texture_cache == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 0.25))
		gradient.add_point(0.3, Color(1, 1, 1, 0.16))
		gradient.add_point(0.65, Color(1, 1, 1, 0.045))
		gradient.add_point(1.0, Color(1, 1, 1, 0.0))
		_soft_texture_cache = GradientTexture2D.new()
		_soft_texture_cache.gradient = gradient
		_soft_texture_cache.fill = GradientTexture2D.FILL_RADIAL
		_soft_texture_cache.fill_from = Vector2(0.5, 0.5)
		_soft_texture_cache.fill_to = Vector2(0.5, 0.0)
		_soft_texture_cache.width = 128
		_soft_texture_cache.height = 128
	return _soft_texture_cache
