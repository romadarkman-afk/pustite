class_name GroundFx
extends Node2D
## Эффекты погоды, которые рисует движок шейдерами и MultiMesh.
## kind "ground": снег, сырость и лужи на земле плюс трава. Слой лежит под толпой и домами.
## kind "sky": тени облаков. Слой лежит над толпой, чтобы тень накрывала и дома.
## Картинки берутся из assets/weather: пока там заглушки, настоящие файлы подменяют их по имени.

const SNOW_TEX := "res://assets/weather/snow_ground.jpg"
const CLOUDS_TEX := "res://assets/weather/clouds.png"
const GRASS_GREEN := "res://assets/weather/grass_green_sheet.png"
const GRASS_DRY := "res://assets/weather/grass_dry_sheet.png"
const SH_GROUND := "res://shaders/ground_weather.gdshader"
const SH_CLOUDS := "res://shaders/cloud_shadow.gdshader"
const SH_GRASS := "res://shaders/grass_sway.gdshader"

const MAX_TUFTS := 150
const TUFT_W := 40.0                   ## ширина пучка на переднем плане, пиксели посёлка
const GRASS_FRAMES := 8

static var _mask_tex: ImageTexture

var view: VillageView
var kind := "ground"
var simplified := false
var area_rect := Rect2()
var _rect: ColorRect
var _mat: ShaderMaterial
var _grass: MultiMeshInstance2D
var _grass_mat: ShaderMaterial
var _grass_dry := false
var _grass_key := ""


func setup(v: VillageView, k: String) -> void:
	view = v
	kind = k
	name = "GroundFx_" + k
	area_rect = view.def.ground_rect
	_rect = ColorRect.new()
	_rect.name = "Area"
	_rect.position = area_rect.position
	_rect.size = area_rect.size
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	if kind == "ground":
		_mat.shader = load(SH_GROUND) as Shader
		_mat.set_shader_parameter("snow_tex", load(SNOW_TEX))
		_mat.set_shader_parameter("mask_tex", mask_texture())
		_mat.set_shader_parameter("ground_tex", view.ground_texture())
		_mat.set_shader_parameter("area_size", area_rect.size)
		_set_puddles()
	else:
		_mat.shader = load(SH_CLOUDS) as Shader
		_mat.set_shader_parameter("clouds", load(CLOUDS_TEX))
		_mat.set_shader_parameter("area_size", area_rect.size)
	_rect.material = _mat
	add_child(_rect)
	visible = false


## Бесшовный шум движка: один на запуск, 256×256.
static func mask_texture() -> ImageTexture:
	if _mask_tex == null:
		var noise := FastNoiseLite.new()
		noise.seed = 4417
		noise.frequency = 0.02
		noise.fractal_octaves = 2
		_mask_tex = ImageTexture.create_from_image(noise.get_seamless_image(256, 256, false, false, 0.15, true))
	return _mask_tex


func _set_puddles() -> void:
	var spots := view.def.puddle_spots
	var arr := PackedVector3Array()
	for i in range(8):
		if i < spots.size():
			arr.append(Vector3(spots[i].x - area_rect.position.x, spots[i].y - area_rect.position.y, spots[i].z))
		else:
			arr.append(Vector3.ZERO)
	_mat.set_shader_parameter("puddles", arr)
	_mat.set_shader_parameter("puddle_count", mini(8, spots.size()))


## Состояние погоды и время суток.
func update_state(s: Dictionary, night: float) -> void:
	var active := bool(s.get("active", false))
	if kind == "ground":
		var cover := float(s.get("cover", 0.0)) if active else 0.0
		var wet := 0.0
		if active and int(s.get("precip", Weather.Precip.NONE)) == Weather.Precip.RAIN:
			wet = clampf(float(s.get("power", 0.0)) * 1.6, 0.0, 1.0)
		elif active:
			wet = clampf(float(s.get("fog", 0.0)) * 0.35, 0.0, 0.5) + (0.35 if int(s.get("season", 0)) == Weather.Season.SPRING else 0.0)
		_mat.set_shader_parameter("cover", cover)
		_mat.set_shader_parameter("wet", wet)
		_mat.set_shader_parameter("night", night)
		_rect.visible = cover > 0.01 or wet > 0.01
		_update_grass(s, night, active, cover)
		visible = active
	else:
		var cloudy := 0.3
		var wind := 0.0
		if active:
			cloudy = clampf(0.3 + 0.55 * float(s.get("power", 0.0)) + 0.3 * float(s.get("fog", 0.0)), 0.0, 1.0)
			wind = float(s.get("wind", 0.0))
		_mat.set_shader_parameter("cloudiness", cloudy)
		_mat.set_shader_parameter("strength", 0.2 + 0.25 * cloudy)
		_mat.set_shader_parameter("speed", 7.0 + 26.0 * wind)
		_mat.set_shader_parameter("wind_dir", Vector2(-1.0 if wind < 0.0 else 1.0, 0.1))
		_mat.set_shader_parameter("night", night)
		visible = active and not simplified


func set_simplified(on: bool) -> void:
	simplified = on
	if kind == "sky":
		visible = visible and not on


# =============================================================
# Трава: пучки по зелёным местам земли, качает шейдер
# =============================================================
func _update_grass(s: Dictionary, night: float, active: bool, cover: float) -> void:
	if not active:
		if _grass != null:
			_grass.visible = false
		return
	var season := int(s.get("season", Weather.Season.SUMMER))
	var dry := season == Weather.Season.AUTUMN or season == Weather.Season.WINTER
	if _grass == null or dry != _grass_dry:
		_build_grass(dry)
	if _grass == null:
		return
	_grass.visible = cover < 0.97
	_grass_mat.set_shader_parameter("wind", 0.0 if simplified else float(s.get("wind", 0.0)))
	_grass_mat.set_shader_parameter("snow", cover)
	_grass_mat.set_shader_parameter("night", night)


func _build_grass(dry: bool) -> void:
	if _grass != null:
		remove_child(_grass)
		_grass.queue_free()
		_grass = null
	_grass_dry = dry
	var tex := load(GRASS_DRY if dry else GRASS_GREEN) as Texture2D
	var spots := grass_spots(view.ground_image(), area_rect, absi(view.def.ground.hash()) + 17, MAX_TUFTS)
	if tex == null or spots.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = spots.size()
	for i in range(spots.size()):
		var sp: Vector3 = spots[i]                      # x, y — основание пучка, z — случайное число 0..1
		var k := 0.55 + 0.75 * clampf((sp.y - area_rect.position.y) / area_rect.size.y, 0.0, 1.0)   # дальше меньше
		var w := TUFT_W * k * (0.8 + 0.4 * fposmod(sp.z * 7.0, 1.0))
		var xf := Transform2D(Vector2(w, 0.0), Vector2(0.0, w), Vector2(sp.x, sp.y - w * 0.5))
		mm.set_instance_transform_2d(i, xf)
		mm.set_instance_custom_data(i, Color(float(int(sp.z * 1000.0) % GRASS_FRAMES), sp.z, 0.0, 0.0))
	_grass = MultiMeshInstance2D.new()
	_grass.name = "Grass"
	_grass.multimesh = mm
	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = load(SH_GRASS) as Shader
	_grass_mat.set_shader_parameter("sheet", tex)
	_grass.material = _grass_mat
	add_child(_grass)


func tuft_count() -> int:
	return _grass.multimesh.instance_count if _grass != null else 0


## Где ставить траву: берём картинку земли и ищем зелёно-жёлтые пиксели вне дорожек и камня.
## Детерминированно: один и тот же посёлок всегда получает те же пучки.
static func grass_spots(img: Image, rect: Rect2, seed_value: int, limit: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	if img == null or img.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tries := limit * 40
	var iw := img.get_width()
	var ih := img.get_height()
	for _i in range(tries):
		if out.size() >= limit:
			break
		var u := rng.randf()
		var v := rng.randf()
		var c := img.get_pixel(clampi(int(u * iw), 0, iw - 1), clampi(int(v * ih), 0, ih - 1))
		var greenish := c.h > 0.14 and c.h < 0.42 and c.s > 0.22 and c.v > 0.1 and c.v < 0.8
		if not greenish:
			continue
		out.append(Vector3(rect.position.x + u * rect.size.x, rect.position.y + v * rect.size.y, rng.randf()))
	return out
