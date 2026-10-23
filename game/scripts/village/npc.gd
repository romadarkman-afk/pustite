class_name Npc
extends Node2D
## Хозяин места вне голосования (TASK-021): мельник в акте II, потом Игнат и начальник станции.
## Стоит на своём месте у дома, в голосовании и ночлеге не участвует. Отличается от жителей
## золотой рамкой имени и фонарём в руке. Раз в день отвечает на один вопрос (DayScreen.npc_actions).

const DEFS := {
	"miller": {"name": "npc.miller.name", "sprite": "res://assets/folk/npc_miller.png",
		"fallback": "res://assets/folk/npc_worker.png", "spot": Vector2(515, 372),
		"topics": ["ford", "before", "night"]},
	## Акт III (TASK-027): брат Игнат ведёт книгу у ворот и не верит никому, сестра Анфиса лечит
	## и тайком показывает вторую книгу, с зачёркнутыми именами.
	"ignat": {"name": "npc.ignat.name", "sprite": "res://assets/folk/npc_abbot.png",
		"fallback": "res://assets/folk/npc_abbot.png", "spot": Vector2(500, 334),
		"topics": ["book", "night", "before"]},
	"anfisa": {"name": "npc.anfisa.name", "sprite": "res://assets/folk/npc_nun.png",
		"fallback": "res://assets/folk/npc_nun.png", "spot": Vector2(296, 288),
		"topics": ["crossed", "heal", "night"]},
	## Акт IV (TASK-032): смотритель станции держит ключ от телеграфа и ведёт список на поезд.
	"keeper": {"name": "npc.keeper.name", "sprite": "res://assets/folk/npc_stationmaster.png",
		"fallback": "res://assets/folk/npc_stationmaster.png", "spot": Vector2(488, 266),
		"topics": ["list", "train", "night"]},
}
const LABEL_SIZE := 15

var npc_id := ""
var who := ""
var _tex: Texture2D
var _font: Font
var _t := 0.0
var _glow := 0.0
var _lantern_halo: LightHalo
var _sprite: Sprite2D               ## сама фигура: на неё ложится шейдер погоды
var _over: _Over                    ## фонарь и рамка имени поверх фигуры
var fx_frost := 0.0
var fx_wet := 0.0


static func has_def(id: String) -> bool:
	return DEFS.has(id)


## Картинка хозяина: своя, если уже нарисована, иначе запасная фигура того же склада.
static func sprite_path(id: String) -> String:
	var d: Dictionary = DEFS.get(id, {})
	var own := String(d.get("sprite", ""))
	var selected := own if ResourceLoader.exists(own) else String(d.get("fallback", ""))
	var realistic := "res://assets/folk/realistic/" + selected.get_file()
	return realistic if ResourceLoader.exists(realistic) else selected


static func display_name(id: String) -> String:
	return L.t(String(DEFS.get(id, {}).get("name", "")))


static func topics(id: String) -> PackedStringArray:
	return PackedStringArray(DEFS.get(id, {}).get("topics", []))


func setup(id: String) -> void:
	npc_id = id
	name = "Npc_" + id
	who = display_name(id)
	_tex = load(sprite_path(id)) as Texture2D
	_font = ThemeFactory.font_bold()
	position = DEFS[id].spot
	_lantern_halo = LightHalo.new()
	_lantern_halo.position = _lantern_position()
	_lantern_halo.radius = 24.0
	_lantern_halo.color = Color("ff9e2c")
	_lantern_halo.flicker = 0.2
	_lantern_halo.intensity = 0.0
	_lantern_halo.z_index = -1
	add_child(_lantern_halo)
	_sprite = Sprite2D.new()
	_sprite.name = "Figure"
	_sprite.texture = _tex
	_sprite.centered = false
	if _tex != null:
		var h := VillagerFigure.FIG_TOP * 1.02
		var w := h * _tex.get_width() / _tex.get_height()
		_sprite.position = Vector2(-w * 0.5, -h)
		_sprite.scale = Vector2(w / _tex.get_width(), h / _tex.get_height())
	add_child(_sprite)
	_over = _Over.new()
	_over.owner_npc = self
	add_child(_over)
	queue_redraw()


## Иней и влага на фигуре хозяина места, тот же шейдер, что у жителей.
func set_weather_fx(frost: float, wet: float) -> void:
	fx_frost = clampf(frost, 0.0, 1.0)
	fx_wet = clampf(wet, 0.0, 1.0)
	if _sprite == null:
		return
	if fx_frost <= 0.01 and fx_wet <= 0.01:
		_sprite.material = null
		return
	var mat := _sprite.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = VillagerFigure.FIGURE_FX
		_sprite.material = mat
	mat.set_shader_parameter("frost", fx_frost)
	mat.set_shader_parameter("wet", fx_wet)
	mat.set_shader_parameter("night", Nav.village.night if Nav.village != null else 0.0)


func poke() -> void:
	_glow = 1.0


func _process(delta: float) -> void:
	_t += delta
	_glow = maxf(0.0, _glow - delta * 2.0)
	if _sprite != null and _sprite.material is ShaderMaterial and Nav.village != null:
		(_sprite.material as ShaderMaterial).set_shader_parameter("night", Nav.village.night)
	if _lantern_halo != null:
		_lantern_halo.position = _lantern_position()
		var night := Nav.village.night if Nav.village != null else 0.0
		_lantern_halo.set_intensity(night * (0.3 + _glow * 0.12))
	queue_redraw()
	if _over != null:
		_over.queue_redraw()


## Тень под ногами. Фигура лежит отдельным спрайтом, фонарь и имя рисует _Over поверх неё.
func _draw() -> void:
	if _tex == null:
		return
	var h := VillagerFigure.FIG_TOP * 1.02
	var w := h * _tex.get_width() / _tex.get_height()
	draw_colored_polygon(_ellipse(Vector2(0, 1.5), Vector2(w * 0.42, 4.5)), Color(0, 0, 0, 0.28))


class _Over extends Node2D:
	var owner_npc: Npc

	func _draw() -> void:
		owner_npc._draw_over(self)


func _draw_over(ci: CanvasItem) -> void:
	if _tex == null:
		return
	var h := VillagerFigure.FIG_TOP * 1.02
	var w := h * _tex.get_width() / _tex.get_height()
	# У мельника фонарь уже в руке на реалистичном спрайте. Для остальных хозяев места
	# оставляем компактный игровой фонарь, чтобы не рисовать второй поверх изображения.
	var lamp := Vector2(-w * 0.35, -h * 0.40) if npc_id == "miller" else Vector2(w * 0.42, -h * 0.42 + sin(_t * 1.7) * 1.2)
	if npc_id != "miller":
		ci.draw_rect(Rect2(lamp - Vector2(3.5, 5), Vector2(7, 10)), Color(1.0, 0.82, 0.45, 0.95))
		ci.draw_rect(Rect2(lamp - Vector2(3.5, 5), Vector2(7, 10)), Art.INK, false, 1.4)
	# имя в золотой рамке: хозяин места, не житель
	var lr := label_rect_local()
	var gold := ThemeFactory.LAMP
	Art.shape(ci, Art.rrect(lr, lr.size.y * 0.5), Color(0.1, 0.07, 0.04, 0.82), Color(gold, 0.9 + 0.1 * _glow), 2.2 + _glow)
	ci.draw_string(_font, Vector2(lr.position.x + 9.0, lr.end.y - 5.0), who, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, gold)


func _lantern_position() -> Vector2:
	if _tex == null:
		return Vector2.ZERO
	var h := VillagerFigure.FIG_TOP * 1.02
	var w := h * _tex.get_width() / _tex.get_height()
	return Vector2(-w * 0.35, -h * 0.40) if npc_id == "miller" else Vector2(w * 0.42, -h * 0.42 + sin(_t * 1.7) * 1.2)


func label_rect_local() -> Rect2:
	var tw := _font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x if _font != null else 60.0
	return Rect2(-tw * 0.5 - 9.0, 6, tw + 18.0, 22)


func hit_rect_global() -> Rect2:
	var c := get_global_transform_with_canvas() * Vector2(0, -40)
	var sc := get_global_transform_with_canvas().get_scale().x
	var half := Vector2(maxf(40.0, 30.0 * sc), maxf(54.0, 50.0 * sc))
	return Rect2(c - half, half * 2.0)


static func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(18):
		var a := TAU * i / 18.0
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out
