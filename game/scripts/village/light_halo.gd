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


static func _soft_texture() -> ImageTexture:
	if _soft_texture_cache == null:
		var image := Image.create(192, 192, false, Image.FORMAT_RGBA8)
		var center := Vector2(95.5, 95.5)
		for y in range(192):
			for x in range(192):
				var distance := Vector2(x, y).distance_to(center) / 95.5
				var falloff := pow(1.0 - smoothstep(0.0, 1.0, distance), 1.35)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.5 * falloff))
		_soft_texture_cache = ImageTexture.create_from_image(image)
	return _soft_texture_cache


## PointLight2D читает яркость из серого RGB, поэтому маска задаётся отдельно от альфа-ореола.
static func point_light_texture() -> ImageTexture:
	if _point_texture_cache == null:
		var image := Image.create(192, 192, false, Image.FORMAT_RGBA8)
		var center := Vector2(95.5, 95.5)
		for y in range(192):
			for x in range(192):
				var distance := Vector2(x, y).distance_to(center) / 95.5
				var falloff := pow(1.0 - smoothstep(0.0, 1.0, distance), 1.7)
				image.set_pixel(x, y, Color(falloff, falloff, falloff, falloff))
		_point_texture_cache = ImageTexture.create_from_image(image)
	return _point_texture_cache
