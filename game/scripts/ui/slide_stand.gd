class_name SlideStand
extends RefCounted
## Заглушка кадра комикса (TASK-105). Пока нет настоящей картинки из ChatGPT, кадр собирается из того, что есть в игре:
## кусок старой картинки главы, портреты лиц из кадра (те же, что на поле) и тёмный низ под подпись.
## Кадры одной колоды берут разные куски фона и разную расстановку, чтобы листание было заметно.
## Когда файл assets/slides/<колода>/<NN>.* появляется, SlidePlayer сам берёт его вместо заглушки.

const SCENE_DIR := "res://assets/scenes/"
const FOLK_DIR := "res://assets/folk/realistic/"
const EXTS: PackedStringArray = ["jpg", "png", "webp"]
const SPRITE_RATIO := 278.0 / 640.0        ## ширина к высоте у портретов assets/folk/realistic
const WIDE_STAGE := 1.6                    ## широкий кадр шире экрана: камера едет вбок

## Колоды вне глав и актов: какой фон им дать.
const FIXED := {
	"prologue": "river", "final_shore": "river", "final_upyr": "end_upyri", "final_many": "end_people", "final_few": "end_people",
	"npc_melnik": "a2c1", "npc_ignat": "a3c1", "npc_anfisa": "a3c1", "npc_smotritel": "a4c1",
}

static var _gradient: GradientTexture2D


## Имя фона для колоды (без пути и расширения).
static func background_name(deck_id: String) -> String:
	if FIXED.has(deck_id):
		return String(FIXED[deck_id])
	var rx := RegEx.new()
	rx.compile("^a(\\d)c(\\d)_")
	var r := rx.search(deck_id)
	if r != null:
		return "a%sc%s" % [r.get_string(1), r.get_string(2)]
	rx.compile("^act(\\d)_(intro|out)")
	r = rx.search(deck_id)
	if r != null:
		return "a%sc%s" % [r.get_string(1), "1" if r.get_string(2) == "intro" else "3"]
	return "door_inside_night"


static func background_path(deck_id: String) -> String:
	var base := SCENE_DIR + background_name(deck_id)
	for ext: String in EXTS:
		if ResourceLoader.exists(base + "." + ext):
			return base + "." + ext
	return ""


static func sprite_path(cast_id: String) -> String:
	var sp := Slides.cast_sprite(cast_id)
	if sp.is_empty():
		return ""
	var p := FOLK_DIR + sp + ".png"
	return p if ResourceLoader.exists(p) else ""


static func _hash(s: String) -> int:
	return absi(s.hash())


## Размер сцены кадра: высокий занимает экран, широкий в полтора раза шире.
static func stage_size(panel: Dictionary, view: Vector2) -> Vector2:
	return Vector2(view.x * (WIDE_STAGE if String(panel.get("size", "t")) == "w" else 1.0), view.y)


## Сцена-заглушка для кадра i колоды. Размер stage_size; материал (шейдер) кладётся на каждую картинку.
static func build(deck_id: String, i: int, panel: Dictionary, view: Vector2, mat: Material = null) -> Control:
	var stage := Control.new()
	stage.name = "Stand"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = stage_size(panel, view)
	var h := _hash(deck_id)
	var bg_path := background_path(deck_id)
	if not bg_path.is_empty():
		var bg := TextureRect.new()
		bg.texture = load(bg_path) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var z := 1.25 + 0.3 * fposmod(float(i) * 0.37 + float(h % 100) * 0.01, 1.0)
		bg.size = stage.size * z
		var fx := 0.5 + 0.45 * sin(float(i) * 1.7 + float(h % 13))
		var fy := 0.5 + 0.45 * cos(float(i) * 1.3 + float(h % 7))
		bg.position = -(bg.size - stage.size) * Vector2(clampf(fx, 0.0, 1.0), clampf(fy, 0.0, 1.0))
		bg.modulate = Color(1.0, 1.0, 1.0)
		if mat != null:
			bg.material = mat
		stage.add_child(bg)
	else:
		var flat := ColorRect.new()
		flat.color = Color(0.05, 0.06, 0.09)
		flat.size = stage.size
		flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(flat)
	# лица кадра: игровые портреты, крупно, внизу
	var cast: Array = panel.get("cast", [])
	var paths: Array[String] = []
	for c: Variant in cast:
		var sp := sprite_path(String(c))
		if not sp.is_empty():
			paths.append(sp)
	var n := paths.size()
	for k in range(n):
		var spr := TextureRect.new()
		spr.texture = load(paths[k]) as Texture2D
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_SCALE
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hh := view.y * (0.66 if n == 1 else 0.56)
		spr.size = Vector2(hh * SPRITE_RATIO, hh)
		var center_x := stage.size.x * 0.5 + (float(k) - float(n - 1) * 0.5) * view.x * 0.34
		if n == 1:
			center_x += view.x * 0.12 * (1.0 if (h + i) % 2 == 0 else -1.0)
		spr.position = Vector2(center_x - spr.size.x * 0.5, view.y - hh * 0.86)
		spr.modulate = Color(0.88, 0.9, 0.98)
		if mat != null:
			spr.material = mat
		stage.add_child(spr)
	# тёмный низ: сюда ляжет подпись
	var shade := TextureRect.new()
	shade.texture = _shade_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = Vector2(0, view.y * 0.45)
	shade.size = Vector2(stage.size.x, view.y * 0.55)
	stage.add_child(shade)
	return stage


static func _shade_texture() -> GradientTexture2D:
	if _gradient != null:
		return _gradient
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.8))
	_gradient = GradientTexture2D.new()
	_gradient.gradient = g
	_gradient.fill_from = Vector2(0.5, 0.0)
	_gradient.fill_to = Vector2(0.5, 1.0)
	return _gradient
