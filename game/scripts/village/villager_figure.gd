class_name VillagerFigure
extends Node2D
## Исходный рисунок на сетке: шаг двигает ноги и рукава, ступни задают глубину.
## Подписи остаются ровными. Цвет одежды одинаков на поле и у двери.

signal arrived

enum State { IDLE, RUN, SCARED, DEAD, GONE }

var who: String = ""
var look: LookDef
var is_player: bool = false
var state: State = State.IDLE
var body: Node2D

var _t: float = 0.0
var _phase: float = 0.0
var _face: float = 1.0
var _blink_in: float = 2.0
var _eyes_closed := false
var _font: Font
var _tw: Tween
var eye_level: int = 0
var badges: PackedStringArray = []
var pact: bool = false
var _eye_pop: float = 0.0
var highlight: bool = false        ## метка «Вы»: стрелка над головой и кольцо под ногами

const MARK_X := 33.0       ## колонка отметок справа от головы
const S := 0.62            ## масштаб рисунка жителя (Folk) в единицах посёлка
const FIG_TOP := 88.0      ## высота жителя с шапкой, логических единиц

var emotion: String = ""   ## временная эмоция: angry, shocked, happy, suspicious
var mood: String = ""      ## постоянное состояние (Feelings.main): grief, despair, guilt, fear, rage, exhaustion, hope
var night: float = 0.0
var lantern_light: PointLight2D
var _emotion_t: float = 0.0
var _talk_t: float = 0.0
var _point_dir: float = 0.0
var _last_face: String = ""
var working := false        ## занят делом: работает в охотку
var tool: String = ""       ## чем работает: bucket, axe, oar, can, chalk
var cold := false           ## ночью у двери: ёжится и дрожит
var turn: float = 0.0       ## куда повёрнута голова: −1 влево … 1 вправо (к тому, кто говорит)
var _walk: float = 0.0
var _work: float = 0.0
var _walk_weight: float = 0.0
var _last_position := Vector2.INF
var _render_tilt := 0.0
var _tap_glow := 0.0
var identity_id := 0
var identity_color := Color.WHITE
const IDENTITY_COLORS := [Color("bb7440"), Color("a83e59"), Color("4676b0"), Color("3e8b7c"),
	Color("ad913e"), Color("8461a6"), Color("c2b190"), Color("527e49"), Color("ae6048"),
	Color("4c91ab"), Color("936581"), Color("8c984f"), Color("ab8598")]
const STRIDE_LENGTH := 64.0            ## длина двойного шага (левая и правая нога), единиц посёлка
const MAX_CADENCE := 2.3               ## двойных шагов в секунду: быстрее ноги не мелькают, бегущий растягивает шаг
static var _foot_shadow_texture: Texture2D
var _turn_t: float = 0.0
var _knock_t: float = 0.0
const KNOCK_LEN := 0.24
var door_portrait := false
var door_tell: StringName = &"ordinary"
var _door_rig: Polygon2D
var _door_shadow: Polygon2D
var _cast_poly: Polygon2D        ## падающая тень в поле: та же сетка, прижатая к земле и сдвинутая вправо
var cast_alpha := 0.0           ## сила тени; ставит толпа вместе с ночью и погодой, 0 — тени нет
var _door_base := PackedVector2Array()
var _door_weights := PackedFloat32Array()
var _left_wrist_weights := PackedFloat32Array()

## Жизнь на площади (задача 44): между репликами житель что-то делает — чешет затылок,
## смотрит на небо, потягивается, скрещивает руки, переминается. Включает толпа, только днём.
## Поза меняется в начале и в конце действия (у «почесать» — ещё раз посередине): две-три перерисовки.
const FIDGETS: PackedStringArray = ["scratch", "sky", "stretch", "arms", "shift", "listen", "warm"]
var fidgets_on := false
var fidget: String = ""
var fidget_count := 0          ## сколько действий сделал — для самотеста
var fidgets_managed := false   ## дневную очередь задаёт Crowd, чтобы жители не двигались хором
var _fidget_t := 0.0
var _fidget_len := 0.0
var _fidget_in := 0.0
var _fidget_rng := RandomNumberGenerator.new()
var _fidget_history: PackedStringArray = []
var _lean := 0.0               ## отшатнулся (обвинили) или наклонился к соседу (шепчет)
var _lean_t := 0.0

var lantern_id := "classic"     ## фонарь игрока (Cosmetics.LANTERNS) — только картинка и цвет света
var brooch_id := "none"

## Тело — картинка из листов жителей (assets/folk/f1..f16): первый лист — старуха, мужик с бородой,
## девушка в кокошнике, парень, старик с клюкой, девочка, кузнец, охотник; второй — четыре женщины,
## рыбак, крестьянин, мальчик и священник. 0 — рисовать кодом (примерка в гардеробе).
## Двигается кодом: дыхание, шаг, наклон, дрожь; эмоция — знак над головой.
const FOLK_DIR := "res://assets/folk/"
const FOLK_REALISTIC_DIR := "res://assets/folk/realistic/"
const FOLK_FEMALE: PackedInt32Array = [1, 3, 6, 9, 10, 11, 12]
const FOLK_MALE: PackedInt32Array = [2, 4, 5, 7, 8, 13, 14, 15, 16]
## Герой игрока — с фонарём в руке; варианты шапок лежат рядом как hero_m_<hat> / hero_f_<hat>.
const HERO_M := 101
const HERO_F := 102
const HERO_HAT_IDS: PackedStringArray = ["top_hat", "beret", "straw", "ushanka", "flower", "jester"]
## Где фонарь на картинке героя: доля ширины от середины и доля высоты от земли.
## Гости кампании — свои картинки assets/folk/guest_<id>.png.
const GUEST_SPRITES := {"soldier": 201, "widow": 202, "merchant": 203, "worker": 204, "clerk": 205}
const HERO_LANTERN := {HERO_M: Vector2(0.41, 0.66), HERO_F: Vector2(0.40, 0.66)}
static var _folk_tex: Dictionary = {}
static var _hero_hat_tex: Dictionary = {}
var sprite_id: int = 0
var hero_hat_id: String = "own"
var tag: Node2D               ## слой подписи над всем посёлком

const CAST_KX := 0.4        ## те же числа, что у теней домов (VillageView.SHADOW_KX / SHADOW_KY)
const CAST_KY := 0.17
const REAL_STEP_LIFT := 2.4    ## подъём фотографии на шаге, единиц посёлка (рост 88)
const REAL_STEP_SWAY := 1.3    ## сдвиг вбок при переносе веса
const REAL_STEP_ROLL := 0.045  ## качание с боку на бок вокруг стоп, радиан
const REAL_STEP_LEAN := 0.03   ## наклон вперёд на ходу, радиан
const WALK_SPEED := 105.0   ## единиц посёлка в секунду: шаг взрослого, 1 единица около 2 см


func setup(name: String, l: LookDef, player: bool) -> void:
	who = name
	look = l
	is_player = player
	_font = ThemeFactory.font_bold()
	_phase = float(absi(name.hash()) % 628) / 100.0
	_blink_in = 1.0 + fmod(_phase, 3.0)
	set_fidget_seed(absi(name.hash()) + 1)
	body = Node2D.new()
	add_child(body)
	body.draw.connect(_draw_body)
	_door_shadow = Polygon2D.new()
	_door_shadow.show_behind_parent = true
	_door_shadow.modulate = Color(0, 0, 0, 0.2)
	_door_shadow.visible = false
	body.add_child(_door_shadow)
	_cast_poly = Polygon2D.new()
	_cast_poly.show_behind_parent = true
	_cast_poly.visible = false
	body.add_child(_cast_poly)
	_door_rig = Polygon2D.new()
	_door_rig.show_behind_parent = true
	_door_rig.visible = false
	body.add_child(_door_rig)
	set_identity_color(0 if player else absi(name.hash()) % IDENTITY_COLORS.size())
	# имя, отметки и стрелка «Вы» — поверх домов и колодца: житель у угла дома не теряет подпись
	tag = Node2D.new()
	tag.z_index = 2
	add_child(tag)
	tag.draw.connect(_draw_tag)
	sprite_id = hero_for(l) if player else sprite_pref(l)[0]
	if player:
		lantern_light = PointLight2D.new()
		lantern_light.texture = LightHalo.point_light_texture()
		lantern_light.position = _hero_lantern_pos()
		lantern_light.texture_scale = 1.45
		lantern_light.color = Color(1.0, 0.8, 0.5)
		lantern_light.energy = 0.0
		lantern_light.visible = false
		add_child(lantern_light)


func set_fidget_seed(seed_value: int) -> void:
	_fidget_rng.seed = absi(seed_value) + 1
	_fidget_in = _fidget_rng.randf_range(2.0, 8.0)


func set_identity_color(id: int) -> void:
	identity_id = posmod(id, IDENTITY_COLORS.size())
	identity_color = IDENTITY_COLORS[identity_id]
	if _door_rig != null:
		_door_rig.material = null
		_refresh_fx()
	if body != null:
		body.queue_redraw()
	if tag != null:
		tag.queue_redraw()


## Картинка гостя или 0, если её нет.
static func guest_sprite(guest_id: String) -> int:
	var id: int = GUEST_SPRITES.get(guest_id, 0)
	var file := "guest_" + guest_id + ".png"
	return id if id > 0 and (ResourceLoader.exists(FOLK_REALISTIC_DIR + file) or ResourceLoader.exists(FOLK_DIR + file)) else 0


## Именные жители кампании (TASK-108): лицо закреплено за личной историей, а не берётся из пула по полу и возрасту.
## Так один и тот же человек выглядит одинаково в партии, на двери, в Книге и в комиксах (tools/slides/cast.py).
## Ключ: место в списке имён (Villager.story_id), значение: номер картинки f<N>. Возраст из SocialContent.AGES учтён.
const NAMED_SPRITES := {0: 9, 1: 2, 2: 12, 3: 4, 4: 10, 5: 13, 6: 7, 7: 3, 8: 8, 9: 11, 10: 14, 11: 1}


## Закреплённое лицо жителя или 0: гости и жители вне первых двенадцати историй берут лицо из пула.
static func named_sprite(v: Villager) -> int:
	if v.is_player or not v.guest_id.is_empty() or not NAMED_SPRITES.has(v.story_id):
		return 0
	var id: int = NAMED_SPRITES[v.story_id]
	return id if FOLK_FEMALE.has(id) == v.female else 0


static func pick_cast_sprite(v: Villager, used: Dictionary) -> int:
	var named := named_sprite(v)
	if named > 0:
		used[named] = true
		return named
	var candidates: PackedInt32Array
	if v.female:
		candidates = PackedInt32Array([9, 3, 10]) if v.age < 28 else (PackedInt32Array([11, 12, 1]) if v.age >= 55 else PackedInt32Array([10, 3, 9]))
	else:
		candidates = PackedInt32Array([4, 14, 8, 7, 2, 13]) if v.age < 28 else (PackedInt32Array([5, 16, 8, 2]) if v.age >= 55 else PackedInt32Array([13, 7, 8, 2, 14]))
	for id: int in candidates:
		if not used.has(id):
			used[id] = true
			return id
	# своего возраста картинки кончились: берём любую свободную того же пола, повтор только потом
	for id: int in (FOLK_FEMALE if v.female else FOLK_MALE):
		if not used.has(id):
			used[id] = true
			return id
	return candidates[posmod(v.story_id, candidates.size())]


## Картинка с закрытыми глазами для моргания портрета (TASK-076): рядом с оригиналом, имя с суффиксом
## _blink. Нет файла — null, моргания у этого жителя нет.
static var _blink_tex: Dictionary = {}


static func blink_tex(id: int) -> Texture2D:
	if not _blink_tex.has(id):
		var file := "hero_m" if id == HERO_M else ("hero_f" if id == HERO_F else "f%d" % id)
		if GUEST_SPRITES.values().has(id):
			file = "guest_" + String(GUEST_SPRITES.find_key(id))
		var path := FOLK_REALISTIC_DIR + file + "_blink.png"
		_blink_tex[id] = load(path) if ResourceLoader.exists(path) else null
	return _blink_tex[id]


static func folk_tex(id: int) -> Texture2D:
	if not _folk_tex.has(id):
		var file := "hero_m" if id == HERO_M else ("hero_f" if id == HERO_F else "f%d" % id)
		if GUEST_SPRITES.values().has(id):
			file = "guest_" + String(GUEST_SPRITES.find_key(id))
		var realistic := FOLK_REALISTIC_DIR + file + ".png"
		var original := FOLK_DIR + file + ".png"
		_folk_tex[id] = load(realistic if ResourceLoader.exists(realistic) else original)
	return _folk_tex[id]


## Вариант портрета героя с выбранной шапкой. Пустой ресурс позволит тесту поймать недостающий файл.
static func hero_hat_texture(id: int, hat_id: String) -> Texture2D:
	if id not in [HERO_M, HERO_F] or not HERO_HAT_IDS.has(hat_id):
		return null
	var gender := "hero_m" if id == HERO_M else "hero_f"
	var file := gender + "_" + hat_id + ".png"
	var realistic := FOLK_REALISTIC_DIR + file
	var path := realistic if ResourceLoader.exists(realistic) else FOLK_DIR + file
	if not _hero_hat_tex.has(path):
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			texture = load(path) as Texture2D
		_hero_hat_tex[path] = texture
	return _hero_hat_tex[path] as Texture2D


## Картинка героя игрока по полу.
static func hero_for(l: LookDef) -> int:
	return HERO_F if l != null and l.female else HERO_M


## Какие картинки подходят внешности, лучшие первыми: пол, возраст, борода, рост.
static func sprite_pref(l: LookDef) -> PackedInt32Array:
	if l == null:
		return PackedInt32Array([4])
	if l.female:
		if l.age >= 2:
			return PackedInt32Array([11, 12, 1, 3, 6, 9, 10])
		if l.height < 0.95:
			return PackedInt32Array([6, 9, 3, 10, 1, 11, 12])
		if l.age == 0:
			return PackedInt32Array([9, 3, 10, 6, 11, 12, 1])
		return PackedInt32Array([10, 9, 3, 6, 11, 12, 1])
	if l.age >= 2:
		return PackedInt32Array([5, 16, 13, 2, 7, 8, 14, 4, 15])
	if l.beard == LookDef.Beard.FULL:
		return PackedInt32Array([16, 13, 2, 7, 8, 5, 14, 4, 15])
	if l.age == 0:
		if l.height < 0.95:
			return PackedInt32Array([15, 4, 8, 14, 13, 7, 2, 5, 16])
		return PackedInt32Array([4, 15, 8, 14, 13, 7, 2, 5, 16])
	return PackedInt32Array([13, 14, 7, 8, 2, 4, 5, 16, 15])


## Картинка для жителя в толпе: подходящая и ещё не занятая; когда своего пола не осталось — повтор.
static func pick_sprite(l: LookDef, used: Dictionary) -> int:
	var pref := sprite_pref(l)
	for id: int in pref:
		if not used.has(id):
			used[id] = true
			return id
	var least := pref[0]
	for id: int in pref:
		if int(used.get(id, 0)) < int(used.get(least, 0)):
			least = id
	used[least] = int(used.get(least, 1)) + 1
	return least


func set_sprite(id: int) -> void:
	sprite_id = id
	if lantern_light != null:
		lantern_light.position = _hero_lantern_pos()
	body.queue_redraw()


func set_hero_hat(id: String) -> void:
	hero_hat_id = id if id == "own" or HERO_HAT_IDS.has(id) else "own"
	if lantern_light != null:
		lantern_light.position = _hero_lantern_pos()
	body.queue_redraw()


## Свет фонаря — там, где фонарь у героя на картинке; у жителя, нарисованного кодом, — в правой руке.
func _hero_lantern_pos() -> Vector2:
	if not HERO_LANTERN.has(sprite_id):
		return Vector2(25 * S, -28 * S)
	var tex := _hero_texture()
	var h := FIG_TOP * (look.height if look != null else 1.0) * 0.97
	if tex != folk_tex(sprite_id):
		h *= float(tex.get_height()) / float(folk_tex(sprite_id).get_height())
	var w := h * tex.get_width() / tex.get_height()
	var r := lantern_rect(tex)
	if r.size.x <= 0.0:
		var k: Vector2 = HERO_LANTERN[sprite_id]
		return Vector2(w * k.x, -h * k.y)
	var c := r.get_center()
	return Vector2((c.x - 0.5) * w, (c.y - 1.0) * h)


## Картинка героя, которую сейчас видно: с шапкой или без.
func _hero_texture() -> Texture2D:
	if hero_hat_id != "own":
		var t := hero_hat_texture(sprite_id, hero_hat_id)
		if t != null:
			return t
	return folk_tex(sprite_id)


static var _lantern_rects: Dictionary = {}


## Где на картинке фонарь, в долях текстуры: самое крупное пятно тёплого огня в правой половине,
## с запасом на стекло и корпус. Считается один раз на картинку.
static func lantern_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _lantern_rects.has(key):
		return _lantern_rects[key]
	var r := Rect2()
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var lo := Vector2i(img.get_width(), img.get_height())
		var hi := Vector2i(-1, -1)
		for y in range(int(img.get_height() * 0.25), int(img.get_height() * 0.85), 2):
			for x in range(int(img.get_width() * 0.72), img.get_width(), 2):
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and c.r > 0.85 and c.g > 0.55 and c.b < 0.6 and c.r - c.b > 0.35:
					lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
					hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
		if hi.x >= 0:
			var w := float(img.get_width())
			var h := float(img.get_height())
			r = Rect2(lo.x / w, lo.y / h, (hi.x - lo.x + 1) / w, (hi.y - lo.y + 1) / h).grow(0.035)
	_lantern_rects[key] = r
	return r


const FIGURE_FX := preload("res://shaders/figure_weather.gdshader")
var fx_frost := 0.0                 ## иней на плечах и шапке, 0..1 (TASK-067)
var fx_wet := 0.0                   ## влажный блеск, 0..1
var _lantern_tex: Texture2D


## Погода на фигуре: один шейдер даёт иней, влагу и цвет фонаря. Без погоды и с обычным фонарём материала нет.
func set_weather_fx(frost: float, wet: float) -> void:
	fx_frost = clampf(frost, 0.0, 1.0)
	fx_wet = clampf(wet, 0.0, 1.0)
	_refresh_fx()


func _refresh_fx() -> void:
	if _door_rig == null:
		return
	var tinted := is_player and lantern_id != "classic" and _lantern_tex != null
	if fx_frost <= 0.01 and fx_wet <= 0.01 and not tinted:
		if _door_rig.material != null:
			_door_rig.material = null
		return
	var mat := _door_rig.material as ShaderMaterial
	if mat == null or mat.shader != FIGURE_FX:
		mat = ShaderMaterial.new()
		mat.shader = FIGURE_FX
		_door_rig.material = mat
	if tinted:
		var r := lantern_rect(_lantern_tex)
		mat.set_shader_parameter("lantern_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
		mat.set_shader_parameter("glass", Cosmetics.lantern(lantern_id).glass)
		mat.set_shader_parameter("strength", 0.85 if r.size.x > 0.0 else 0.0)
	else:
		mat.set_shader_parameter("strength", 0.0)
	mat.set_shader_parameter("frost", fx_frost)
	mat.set_shader_parameter("wet", fx_wet)
	mat.set_shader_parameter("night", night)


## Цвет фонаря героя: стекло перекрашивает тот же шейдер. У обычного фонаря картинка как есть.
func _apply_lantern_tint(tex: Texture2D) -> void:
	_lantern_tex = tex
	_refresh_fx()


## Ночью фонарь игрока светит, днём погашен; ночью у всех встревоженные лица.
func set_night(n: float) -> void:
	night = n
	if _door_rig != null and _door_rig.material is ShaderMaterial:
		(_door_rig.material as ShaderMaterial).set_shader_parameter("night", n)
	if lantern_light != null:
		lantern_light.visible = n > 0.05
		lantern_light.energy = 0.62 * n


## Эмоция на время: обвинили — shocked, обвиняет — angry (и показывает пальцем в сторону point_dir).
func set_emotion(e: String, seconds: float, point_dir: float = 0.0) -> void:
	if state == State.DEAD or state == State.GONE:
		return
	emotion = e
	_emotion_t = seconds
	_point_dir = point_dir
	if point_dir != 0.0:
		_face = signf(point_dir)
	body.queue_redraw()


## Говорит — рот открывается и закрывается, пока висит пузырь.
func talk(seconds: float) -> void:
	_talk_t = maxf(_talk_t, seconds)


## Короткий замах у двери: кодовая фигура поднимает руку, спрайт наклоняется к створке.
func knock() -> void:
	if state == State.DEAD or state == State.GONE:
		return
	_knock_t = KNOCK_LEN
	_talk_t = maxf(_talk_t, KNOCK_LEN)
	look_at_x(position.x + 80.0, KNOCK_LEN)
	body.queue_redraw()


func current_face() -> String:
	if state == State.SCARED:
		return "scared"
	if _emotion_t > 0.0 and emotion != "":
		return "suspicious" if emotion == "point" else emotion
	if _talk_t > 0.0:
		return "talk" if fmod(_t * 6.0, 1.0) < 0.5 else "neutral"
	if _eyes_closed:
		return "blink"
	if working:
		return "relieved" if fmod(_t * 0.5 + _phase, 2.0) < 0.4 else "neutral"
	if cold:
		return "cold"
	match mood:
		"grief", "despair", "guilt", "exhaustion":
			return "sad"
		"fear":
			return "cold"         # дрожит и днём
		"rage":
			return "angry"
		"hope":
			return "relieved" if fmod(_t * 0.3 + _phase, 3.0) < 1.0 else "neutral"
	return "neutral"


## Повернуть голову к точке на поле (x в координатах посёлка) на seconds секунд.
## Дальше 160 единиц — до упора.
func look_at_x(x: float, seconds: float = 2.5) -> void:
	var t := clampf((x - position.x) / 160.0, -1.0, 1.0) * 0.8
	_turn_t = seconds
	if absf(t - turn) > 0.05:
		turn = t
		body.queue_redraw()


func look_ahead() -> void:
	if turn != 0.0:
		turn = 0.0
		body.queue_redraw()


## Отшатнуться от того, кто обвиняет: верх тела уходит в сторону dir (−1 / 1).
func recoil(dir: float, seconds: float = 1.4) -> void:
	lean_for(0.16 * signf(dir) if dir != 0.0 else 0.16, seconds)


func lean_for(amount: float, seconds: float) -> void:
	if state == State.DEAD or state == State.GONE:
		return
	_lean = amount
	_lean_t = seconds
	body.queue_redraw()


## Шепнуть соседу, который стоит в стороне x: повернуться, наклониться, пошевелить губами.
func whisper_to(x: float, seconds: float = 1.6) -> bool:
	if state != State.IDLE or working:
		return false
	look_at_x(x, seconds)
	lean_for(0.1 * signf(x - position.x), seconds)
	talk(seconds)
	return _talk_t > 0.0 and _lean != 0.0


## Начать действие сейчас (самотест и толпа). Пустое имя — случайное.
func start_fidget(f: String = "") -> void:
	if state != State.IDLE or working or cold:
		return
	if f == "":
		var choices := PackedStringArray()
		for candidate: String in FIDGETS:
			if not _fidget_history.has(candidate):
				choices.append(candidate)
		if choices.is_empty():
			choices = FIDGETS.duplicate()
		f = choices[_fidget_rng.randi_range(0, choices.size() - 1)]
	fidget = f
	_fidget_len = _fidget_rng.randf_range(1.8, 2.6)
	_fidget_t = _fidget_len
	fidget_count += 1
	_fidget_history.append(f)
	if _fidget_history.size() > 2:
		_fidget_history.remove_at(0)
	body.queue_redraw()


## Стоит без дела: можно шепнуть ему или начать действие.
func is_free() -> bool:
	return state == State.IDLE and not working and not cold and _talk_t <= 0.0 and fidget == "" and (_emotion_t <= 0.0 or emotion == "")


func _next_fidget_in() -> float:
	return _fidget_rng.randf_range(9.0, 16.0)


func set_cold(on: bool) -> void:
	if cold != on:
		cold = on
		body.queue_redraw()


const LABEL_SIZE := 14


func body_scale() -> Vector2:
	return body.scale


## Прямоугольники для раскладки и самотестов, в координатах фигурки.
## Длинное имя (Ebenezer, Keloğlan) пишется мельче, чтобы подпись влезла в место в очереди у двери.
const LABEL_MAX_W := 54.0
const LABEL_MIN := 11


func label_size() -> int:
	var w := _font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	if w <= LABEL_MAX_W:
		return LABEL_SIZE
	return maxi(LABEL_MIN, floori(LABEL_SIZE * LABEL_MAX_W / w))


func label_width() -> float:
	return _font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size()).x


func label_rect_local() -> Rect2:
	var w := label_width()
	return Rect2(-w * 0.5 - 8.0, 6, w + 16.0, 21)


func body_rect_local() -> Rect2:
	var h := look.height if look != null else 1.0
	var extra := 26.0 if highlight else 0.0
	# колонка отметок справа от головы занята, только когда отметки есть
	var right := MARK_X + 12.0 if has_marks() else 23.0
	return Rect2(-23, -FIG_TOP * h - extra, 23 + right, FIG_TOP * h + 2 + extra)


func has_marks() -> bool:
	return eye_level > 0 or not badges.is_empty() or pact


func set_highlight(on: bool) -> void:
	highlight = on
	_redraw()


## Где стрелка метки «Вы» — для самотестов, в координатах экрана.
func marker_rect_global() -> Rect2:
	var h := look.height if look != null else 1.0
	return _global_rect(Rect2(-9, -FIG_TOP * h - 26, 18, 16))


## Зона касания в координатах экрана: не меньше 84×108 px (≈ 48 dp), даже если фигурка мелкая.
func hit_rect_global() -> Rect2:
	var c := get_global_transform_with_canvas() * Vector2(4, -42)
	var sc := get_global_transform_with_canvas().get_scale().x
	var half := Vector2(maxf(42.0, 30.0 * sc), maxf(54.0, 50.0 * sc))
	return Rect2(c - half, half * 2.0)


func set_marks(level: int, b: PackedStringArray, has_pact: bool) -> void:
	var grew := level > eye_level
	eye_level = level
	badges = b
	pact = has_pact
	_redraw()
	if grew and not Juice.instant:
		var t := create_tween()
		t.tween_method(func(v: float) -> void:
			_eye_pop = v
			_redraw(), 1.0, 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Отклик на тап: обводка подписи, тело сохраняет форму.
func poke() -> void:
	if state != State.IDLE or Juice.instant:
		return
	var t := create_tween()
	t.tween_method(func(value: float) -> void:
		_tap_glow = value
		tag.queue_redraw(), 1.0, 0.0, 0.35)


func _global_rect(r: Rect2) -> Rect2:
	var t := get_global_transform_with_canvas()
	var a := t * r.position
	var b := t * r.end
	return Rect2(a, b - a).abs()


## Точка над головой — сюда указывает хвостик пузыря с репликой.
func head_global() -> Vector2:
	var h := look.height if look != null else 1.0
	return get_global_transform_with_canvas() * Vector2(0, -FIG_TOP * h)


## Палец на голове или на значках справа от неё (выше плеч), а не у ног.
func over_marks(global_pos: Vector2) -> bool:
	var h := look.height if look != null else 1.0
	var shoulders := (get_global_transform_with_canvas() * Vector2(0, -FIG_TOP * h * 0.62)).y
	return global_pos.y < shoulders


func label_rect_global() -> Rect2:
	return _global_rect(label_rect_local())


func body_rect_global() -> Rect2:
	return _global_rect(body_rect_local())


## Самый высокий рост среди внешностей (config/looks*.tres); проверяется тестом --crowd.
const LOOK_HEIGHT_MAX := 1.07



# =============================================================
# Состояния
# =============================================================
## delay — сколько секунд постоять, прежде чем сорваться (житель не сразу услышал колокол).
func run_to(target: Vector2, dur: float = 0.75, delay: float = 0.0, door_house: int = -1) -> void:
	if state == State.DEAD or state == State.GONE:
		return
	if _tw != null:
		_tw.kill()
	var path := _path_to(target, door_house)
	if path.is_empty() or path[path.size() - 1].distance_to(target) > 1.0:
		path.append(target)   # маршрут не дошёл (нет пути или последний шаг упёрся в стену): последний отрезок напрямик, чтобы встать на отведённое место, а не посреди чужой очереди
	if Juice.instant:
		position = target if path.is_empty() else path[path.size() - 1]
		_settle_idle()
		arrived.emit()
		return
	if delay > 0.0:
		_settle_idle()
	else:
		state = State.RUN
	var destination: Vector2 = target if path.is_empty() else path[path.size() - 1]
	if absf(destination.x - position.x) > 3.0:
		_face = -1.0 if destination.x < position.x else 1.0
	_tw = create_tween()
	if delay > 0.0:
		_tw.tween_interval(delay)
		_tw.tween_callback(func() -> void: state = State.RUN)
	var total := _path_length(path)
	var move_time := maxf(0.05, dur)
	var from := position
	for point: Vector2 in path:
		var segment := from.distance_to(point)
		if segment > 0.5:
			_tw.tween_property(self, "position", point, maxf(0.03, move_time * segment / maxf(total, 0.001))).set_trans(Tween.TRANS_LINEAR)
		from = point
	_tw.tween_callback(func() -> void:
		_settle_idle()
		arrived.emit())


## Идти шагом с постоянной скоростью — длина пути решает, сколько идти.
func walk_to(target: Vector2) -> void:
	var path := _path_to(target)
	var destination: Vector2 = target if path.is_empty() else path[path.size() - 1]
	var duration := clampf(_path_length(path) / WALK_SPEED, 0.25, 4.0)
	if state == State.DEAD or state == State.GONE:
		return
	if _tw != null:
		_tw.kill()
	if Juice.instant:
		position = destination
		_settle_idle()
		arrived.emit()
		return
	if absf(destination.x - position.x) > 3.0:
		_face = -1.0 if destination.x < position.x else 1.0
	state = State.RUN
	_tw = create_tween()
	var total := _path_length(path)
	var from := position
	for point: Vector2 in path:
		var segment := from.distance_to(point)
		if segment > 0.5:
			_tw.tween_property(self, "position", point, maxf(0.03, duration * segment / maxf(total, 0.001))).set_trans(Tween.TRANS_LINEAR)
		from = point
	_tw.tween_callback(func() -> void:
		_settle_idle()
		arrived.emit())


func _path_to(target: Vector2, door_house: int = -1) -> PackedVector2Array:
	var parent := get_parent()
	if parent is Crowd:
		return (parent as Crowd).walk_route(position, target, door_house)
	return PackedVector2Array([target])


func _path_length(path: PackedVector2Array) -> float:
	var total := 0.0
	var from := position
	for point: Vector2 in path:
		total += from.distance_to(point)
		from = point
	return total


## Встал к делу или отошёл. t — инструмент по виду дела.
func set_working(on: bool, t: String = "") -> void:
	if working != on or (on and t != tool):
		working = on
		tool = t if on else ""
		_work = 0.0
		body.queue_redraw()


## Инструмент для вида дела.
static func tool_for(kind: JobDef.Kind) -> String:
	match kind:
		JobDef.Kind.WATER: return "bucket"
		JobDef.Kind.WOOD: return "axe"
		JobDef.Kind.LAMP: return "can"
		JobDef.Kind.FISH: return "oar"
		JobDef.Kind.TALISMAN: return "chalk"
	return ""


func scare(seconds: float = 1.2) -> void:
	if state != State.IDLE:
		return
	state = State.SCARED
	body.queue_redraw()
	if Juice.instant:
		_settle_idle()
		return
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if state == State.SCARED:
			_settle_idle())


func die() -> void:
	if state == State.DEAD or state == State.GONE:
		return
	if _tw != null:
		_tw.kill()
	state = State.DEAD
	if Juice.instant:
		body.visible = false
		_redraw()
		return
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(body, "scale", Vector2(_face * 1.25, 0.05), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(body, "modulate:a", 0.0, 0.55)
	_tw.chain().tween_callback(func() -> void:
		body.visible = false
		_redraw())


func walk_off(dir: float) -> void:
	if state == State.GONE:
		return
	state = State.GONE
	if Juice.instant:
		visible = false
		return
	if _tw != null:
		_tw.kill()
	_face = signf(dir)
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "position", position + Vector2(dir * 520.0, 30.0), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "modulate:a", 0.0, 2.2)
	_tw.chain().tween_callback(func() -> void: visible = false)


func _settle_idle() -> void:
	state = State.IDLE
	body.position = Vector2.ZERO
	body.scale = Vector2(_face, 1.0)
	body.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var travelled := position.distance_to(_last_position) if _last_position != Vector2.INF else 0.0
	_last_position = position
	if _knock_t > 0.0:
		_knock_t = maxf(0.0, _knock_t - delta)
		_anim_step(delta)
	var walk_target := clampf(travelled / maxf(delta, 0.001) / WALK_SPEED, 0.0, 1.0) if state == State.RUN and not Juice.instant else 0.0
	_walk_weight = lerpf(_walk_weight, walk_target, 1.0 - exp(-12.0 * delta))
	if state == State.RUN and travelled > 0.0 and not Juice.instant:
		var speed := travelled / maxf(delta, 0.001)
		_walk = fmod(_walk + travelled / maxf(STRIDE_LENGTH, speed / MAX_CADENCE), 1.0)
	var pose: Dictionary = pose_now()[1]
	var tilt_target := float(pose.get("lean", 0.0)) * 0.45 + float(pose.get("tilt", 0.0)) * 0.25
	var tilt_before := _render_tilt
	_render_tilt = lerpf(_render_tilt, tilt_target, 1.0 - exp(-9.0 * delta))
	if absf(_render_tilt - tilt_before) > 0.0001:
		body.queue_redraw()
	if highlight:
		_redraw()
	if _emotion_t > 0.0:
		_emotion_t -= delta
		if _emotion_t <= 0.0:
			emotion = ""
			_point_dir = 0.0
	if _talk_t > 0.0:
		_talk_t -= delta
	if _turn_t > 0.0:
		_turn_t -= delta
		if _turn_t <= 0.0:
			look_ahead()
	if _lean_t > 0.0:
		_lean_t -= delta
		if _lean_t <= 0.0:
			_lean = 0.0
			body.queue_redraw()
	_fidget_step(delta)
	var f := current_face()
	if f != _last_face:
		_last_face = f
		body.queue_redraw()
	match state:
		State.IDLE:
			_blink_in -= delta
			if _blink_in <= 0.0:
				_eyes_closed = not _eyes_closed
				_blink_in = 0.12 if _eyes_closed else 2.2 + fmod(_t * 0.37 + _phase, 2.5)
				body.queue_redraw()
			if working:
				# Запросы перерисовки объединяются движком до игрового кадра.
				_work = fmod(_work + delta * 0.9, 1.0)
				_anim_step(delta)
				body.scale = Vector2(_face, 1.0)
				body.position = Vector2.ZERO
				return
			if _walk_weight > 0.01:
				_anim_step(delta)
			elif fidget != "":
				_anim_step(delta)
			var s := sin(_t * 1.7 + _phase)
			var breath_size := 0.0055
			body.scale = Vector2(_face, 1.0 + breath_size * s)
			var chill_speed := 2.4
			var chill_size := 0.12
			body.position = Vector2(sin(_t * chill_speed + _phase) * chill_size if cold else 0.0, 0.0)
			if door_portrait:
				body.queue_redraw()
		State.RUN:
			body.scale = Vector2(_face, 1.0)
			body.position = Vector2.ZERO
			_anim_step(delta)
		State.SCARED:
			body.position.x = sin(_t * 3.5 + _phase) * 0.25


func _fidget_step(delta: float) -> void:
	if fidget != "":
		var half_before := _fidget_t > _fidget_len * 0.5
		_fidget_t -= delta
		var busy := state != State.IDLE or working or cold or (_emotion_t > 0.0 and emotion != "")
		if _fidget_t <= 0.0 or busy:
			fidget = ""
			_fidget_in = _next_fidget_in()
			body.queue_redraw()
		elif fidget == "scratch" and half_before and _fidget_t <= _fidget_len * 0.5:
			body.queue_redraw()      # рука переходит на другое место затылка
		return
	if not fidgets_on or fidgets_managed or state != State.IDLE or working or cold or _talk_t > 0.0:
		return
	if _fidget_in <= 0.0:
		_fidget_in = _fidget_rng.randf_range(2.0, 8.0)
	_fidget_in -= delta
	if _fidget_in <= 0.0:
		start_fidget()


## Поза действия поверх обычной.
func _fidget_pose(pose: Dictionary) -> String:
	match fidget:
		"scratch":
			var progress := 1.0 - _fidget_t / maxf(_fidget_len, 0.01)
			var reach := smoothstep(0.04, 0.3, progress) * (1.0 - smoothstep(0.68, 0.96, progress))
			pose["arm_r"] = lerpf(0.12, 2.75, reach)
			pose["tilt"] = 0.12 * reach
			return "confused"
		"sky":
			pose["look"] = Vector2(sin(_t * 1.2 + _phase) * 0.3, -1.0)
			pose["tilt"] = -0.14 + sin(_t * 0.9 + _phase) * 0.025
			return ""
		"stretch":
			pose["arm_l"] = 2.85
			pose["arm_r"] = 2.85
			pose["breath"] = 1.0
			return "relieved"
		"arms":
			pose["arm_l"] = 1.15
			pose["arm_r"] = 1.15
			return ""
		"shift":
			pose["walk"] = fmod((1.0 - _fidget_t / maxf(_fidget_len, 0.01)) * 0.5, 1.0)
			pose["amp"] = 0.45
			pose["lean"] = 0.05
			return ""
		"listen":
			pose["look"] = Vector2(0.7 * _face, -0.15)
			pose["tilt"] = 0.08 + sin(_t * 2.0 + _phase) * 0.02
			return "suspicious"
		"warm":
			pose["arm_l"] = 1.15 + sin(_t * 5.0 + _phase) * 0.07
			pose["arm_r"] = 1.15 - sin(_t * 5.0 + _phase) * 0.07
			pose["shiver"] = true
			return "cold"
	return ""


## Движение обновляется каждый игровой кадр. CanvasItem объединяет запросы до отрисовки,
## поэтому отдельный предел 24 Гц давал заметные рывки при лимите игры 60 кадров.
func _anim_step(_delta: float) -> void:
	body.queue_redraw()
	queue_redraw()


# =============================================================
# Рисование
# =============================================================
func _redraw() -> void:
	queue_redraw()
	if tag != null:
		tag.queue_redraw()


static func _foot_shadow() -> Texture2D:
	if _foot_shadow_texture != null:
		return _foot_shadow_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.015, 0.012, 0.02, 0.38), Color(0.015, 0.012, 0.02, 0.12), Color(0.015, 0.012, 0.02, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 96
	texture.height = 40
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	_foot_shadow_texture = texture
	return _foot_shadow_texture


## Тень, кольцо «Вы» и надгробие — на земле, в общем порядке по глубине.
func _draw() -> void:
	if state == State.GONE:
		return
	var shadow_alpha := lerpf(0.15, 0.25, night)
	draw_texture_rect(_foot_shadow(), Rect2(-23, -5, 46, 15), false, Color(1, 1, 1, shadow_alpha))
	if state == State.DEAD:
		# надгробие: пухлый камень с крестом и травой
		var k := Art.INK
		Art.shape(self, Art.rrect(Rect2(-13, -30, 26, 30), 12), Color("9a9aa8"), k, 2.6)
		draw_line(Vector2(0, -24), Vector2(0, -8), Color(k, 0.7), 2.6, true)
		draw_line(Vector2(-6, -18), Vector2(6, -18), Color(k, 0.7), 2.6, true)
		for gx in [-12.0, -6.0, 7.0, 12.0]:
			draw_line(Vector2(gx, 0), Vector2(gx - 2, -6), Color("6aa04e"), 1.8, true)
	if highlight and state != State.DEAD:
		var p := 0.5 + 0.5 * sin(_t * 4.0)
		var ring := _ellipse(Vector2(0, 2), Vector2(24.0 + 4.0 * p, 8.0 + 1.5 * p), 26)
		ring.append(ring[0])
		draw_polyline(ring, Color(ThemeFactory.LAMP, 0.5 + 0.45 * p), 3.0, true)


## Отметки, стрелка «Вы» и имя в тёмной капсуле.
func _draw_tag() -> void:
	if state == State.GONE:
		return
	if state != State.DEAD:
		_draw_marks()
	if highlight and state != State.DEAD:
		var hh := look.height if look != null else 1.0
		var y0 := -FIG_TOP * hh - 10.0 + 3.0 * sin(_t * 5.0)
		tag.draw_colored_polygon(PackedVector2Array([Vector2(-9, y0 - 12), Vector2(9, y0 - 12), Vector2(0, y0)]), ThemeFactory.LAMP)
	var lr := label_rect_local()
	var col := ThemeFactory.LAMP if is_player else Color(1, 1, 1, 0.95 if state != State.DEAD else 0.45)
	Art.shape(tag, Art.rrect(lr, lr.size.y * 0.5), Color(0.08, 0.06, 0.12, 0.72 if state != State.DEAD else 0.4), Color(col, 0.35), 1.2)
	if state != State.DEAD:
		tag.draw_line(Vector2(lr.position.x + 9, lr.end.y - 1.5), Vector2(lr.end.x - 9, lr.end.y - 1.5), Color(identity_color, 0.85 + 0.15 * _tap_glow), 2.2 + _tap_glow)
	tag.draw_string(_font, Vector2(lr.position.x + 8.0, lr.end.y - 5.0), who, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size(), col)


const EYE_COLORS := [Color(0, 0, 0, 0), Color("8fa3ab"), Color("d9a24e"), Color("d0683a"), Color("c23a33")]


## Штрихи над глазом подозрения: по одному на уровень, веером.
static func eye_strokes(level: int, c: Vector2, s: float = 1.0) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var n := clampi(level, 0, 4)
	for i in range(n):
		var a := -PI * 0.5 + (float(i) - (n - 1) * 0.5) * 0.42
		var d := Vector2(cos(a), sin(a))
		out.append(PackedVector2Array([c + d * 12.0 * s, c + d * 17.0 * s]))
	return out


const BADGE_SHAPES := {"street": "circle", "liar": "square", "death": "diamond", "fake": "hex", "tunnel": "pill", "sabotage": "triangle"}


## Рамка значка улики: силуэт по виду улики, радиус ~9.
static func badge_outline(b: String, c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match BADGE_SHAPES.get(b, "square"):
		"circle":
			for i in range(16):
				var a := TAU * i / 16.0
				pts.append(c + Vector2(cos(a), sin(a)) * 9.5)
		"diamond":
			pts = PackedVector2Array([c + Vector2(0, -11), c + Vector2(11, 0), c + Vector2(0, 11), c + Vector2(-11, 0)])
		"hex":
			for i in range(6):
				var a := TAU * i / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * 10.0)
		"pill":
			for i in range(8):
				var a := -PI * 0.5 + PI * i / 7.0
				pts.append(c + Vector2(4, 0) + Vector2(cos(a), sin(a)) * 7.5)
			for i in range(8):
				var a := PI * 0.5 + PI * i / 7.0
				pts.append(c + Vector2(-4, 0) + Vector2(cos(a), sin(a)) * 7.5)
		"triangle":
			pts = PackedVector2Array([c + Vector2(0, -11), c + Vector2(11, 8.5), c + Vector2(-11, 8.5)])
		_:
			pts = PackedVector2Array([c + Vector2(-9, -9), c + Vector2(9, -9), c + Vector2(9, 9), c + Vector2(-9, 9)])
	return pts


var drawn_strokes := 0                 ## для самотеста: сколько штрихов у глаза нарисовано
var drawn_frames: PackedInt32Array = [] ## для самотеста: вершины рамок значков


func _draw_marks() -> void:
	drawn_frames.clear()
	drawn_strokes = 0
	if pact:
		paint_pact(tag, Vector2(0, 2))
	if eye_level > 0:
		drawn_strokes = paint_eye(tag, Vector2(MARK_X, -66), eye_level, 1.0 + 0.5 * _eye_pop)
	var y := -46.0
	for b: String in badges.slice(0, 2):
		drawn_frames.append(paint_badge(tag, b, Vector2(MARK_X, y)))
		y += 19.0


## Отметки рисуются одними и теми же функциями на поле и в пояснении «что значат значки».
static func paint_pact(ci: CanvasItem, c: Vector2) -> void:
	var ring := PackedVector2Array()
	for i in range(23):
		var a := TAU * i / 22.0
		ring.append(c + Vector2(cos(a) * 17.0, sin(a) * 6.5))
	ci.draw_polyline(ring, Color(ThemeFactory.LAMP, 0.85), 2.0)


## Глаз подозрения; возвращает число штрихов над ним.
static func paint_eye(ci: CanvasItem, c: Vector2, level: int, s: float = 1.0) -> int:
	var bg := Color(ThemeFactory.NIGHT, 0.8)
	var col: Color = EYE_COLORS[clampi(level, 0, 4)]
	ci.draw_circle(c, 11.0 * s, bg)
	var open := (2.5 + level * 1.1) * s
	var pts := PackedVector2Array()
	for i in range(9):
		var t := float(i) / 8.0
		pts.append(c + Vector2((t - 0.5) * 18.0 * s, -sin(t * PI) * open))
	for i in range(7, 0, -1):
		var t := float(i) / 8.0
		pts.append(c + Vector2((t - 0.5) * 18.0 * s, sin(t * PI) * open))
	ci.draw_colored_polygon(pts, Color(col, 0.25))
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, col, 1.6)
	ci.draw_circle(c, minf(open, 2.2 + level * 0.6), col)
	ci.draw_circle(c, 1.2 * s, Color("0d1214"))
	# штрихи над глазом: сколько штрихов, столько уровней подозрения — различимо без цвета
	var n := 0
	for seg: PackedVector2Array in eye_strokes(level, c, s):
		ci.draw_line(seg[0], seg[1], col, 2.0)
		n += 1
	return n


## Значок улики в своей рамке; возвращает число вершин рамки (для самотеста силуэтов).
static func paint_badge(ci: CanvasItem, b: String, c: Vector2) -> int:
	var x := c.x
	var y := c.y
	var accent := ThemeFactory.LAMP
	match b:
		"liar", "death", "sabotage": accent = Color("e0533f")
	# у каждой улики свой силуэт рамки: круг, ромб, щит… — различимы без цвета
	var frame := badge_outline(b, c)
	ci.draw_colored_polygon(frame, Color(ThemeFactory.NIGHT, 0.9))
	var fo := frame.duplicate()
	fo.append(frame[0])
	ci.draw_polyline(fo, Color(accent, 0.9), 1.6)
	match b:
		"street":
			ci.draw_colored_polygon(_oval(Vector2(x - 3.2, y + 2.5), Vector2(2.6, 4.2)), ThemeFactory.LAMP)
			ci.draw_colored_polygon(_oval(Vector2(x + 3.2, y - 3.0), Vector2(2.6, 4.2)), ThemeFactory.LAMP)
		"liar":
			ci.draw_polyline(PackedVector2Array([Vector2(x - 5.5, y + 5.5), Vector2(x - 5.5, y - 1), Vector2(x, y - 6.5),
				Vector2(x + 5.5, y - 1), Vector2(x + 5.5, y + 5.5), Vector2(x - 5.5, y + 5.5)]), ThemeFactory.BONE, 1.6)
			ci.draw_line(Vector2(x - 7, y + 7), Vector2(x + 7, y - 7), accent, 2.2)
		"death":
			ci.draw_circle(Vector2(x, y + 2.5), 4.6, accent)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 4.2, y + 1), Vector2(x + 4.2, y + 1), Vector2(x, y - 7)]), accent)
		"fake":   # пустое ведро
			ci.draw_polyline(PackedVector2Array([Vector2(x - 5, y - 4), Vector2(x - 3.6, y + 5.5), Vector2(x + 3.6, y + 5.5), Vector2(x + 5, y - 4)]), ThemeFactory.BONE, 1.6)
			ci.draw_arc(Vector2(x, y - 4), 5.0, PI, TAU, 8, ThemeFactory.BONE, 1.2)
		"tunnel":   # люк
			ci.draw_rect(Rect2(x - 6, y - 3, 12, 8), Color("8a5a3a"))
			ci.draw_rect(Rect2(x - 6, y - 3, 12, 8), ThemeFactory.BONE, false, 1.2)
			ci.draw_circle(Vector2(x + 3, y + 1), 1.4, ThemeFactory.BONE)
		"sabotage":   # трещина
			ci.draw_polyline(PackedVector2Array([Vector2(x - 1, y - 7), Vector2(x + 3, y - 2), Vector2(x - 2.5, y + 1.5), Vector2(x + 2, y + 7)]), accent, 2.0)
	return frame.size()


static func _oval(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := TAU * i / 10.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts




func _bright(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.3 + 0.08), minf(1.0, c.v * 1.45 + 0.08), c.a)


func _draw_body() -> void:
	var fp := pose_now()
	# Если PNG выбранной шапки недоступен, используем запасное рисование героя кодом.
	# Так шапка остаётся видна на поле; загруженный PNG-вариант сохранит исходный стиль.
	var missing_hero_hat := is_player and hero_hat_id != "own" and hero_hat_texture(sprite_id, hero_hat_id) == null
	if sprite_id <= 0 or missing_hero_hat:
		Folk.figure(body, Vector2.ZERO, S, look, fp[0], fp[1], Folk.palette(look))
		if is_player:
			_draw_brooch(Vector2(-4, -FIG_TOP * 0.63))
		return
	_draw_sprite(fp[0], fp[1])


## Сетка исходного рисунка сохраняет лицо, одежду и обводку.
func _draw_sprite(face: String, pose: Dictionary) -> void:
	var tex := folk_tex(sprite_id)
	if is_player and hero_hat_id != "own":
		var hat_tex := hero_hat_texture(sprite_id, hero_hat_id)
		if hat_tex != null:
			tex = hat_tex
	var h := FIG_TOP * (look.height if look != null else 1.0) * 0.97
	if tex != folk_tex(sprite_id):
		# картинки героя в шапке нарезаны в одном масштабе с героем без шапки:
		# рост тела тот же, выше становится только шапка
		h *= float(tex.get_height()) / float(folk_tex(sprite_id).get_height())
	var w := h * tex.get_width() / tex.get_height()
	var bob := 0.0
	var rot := _render_tilt
	var knock_motion: float = pose.get("knock", 0.0)
	var dx := 0.0
	var sway := 0.0
	var sprite_scale := Vector2.ONE
	body.draw_colored_polygon(_ellipse(Vector2(0, 1.5), Vector2(w * 0.42, 4.5)), Color(0, 0, 0, 0.28))
	body.draw_set_transform(Vector2(dx + sway, bob), rot, sprite_scale)
	if door_portrait:
		_draw_door_rig(tex, h, w, Vector2(dx + sway, bob), rot, sprite_scale, knock_motion)
		var exhale := pow(maxf(0.0, sin(_t * 1.9 + _phase)), 3.0)
		var mist := 0.025 if door_tell == &"breath" else 0.13
		for puff in range(3):
			body.draw_circle(Vector2(w * 0.15 + 4.0 + puff * 2.0, -h * 0.81 - puff * 1.1),
				2.2 + puff * 1.0, Color(0.71, 0.79, 0.85, mist * exhale / (puff + 1.0)))
	else:
		if _is_realistic_sprite(tex):
			_draw_realistic_sprite(tex, h, w, pose)
		else:
			_draw_field_rig(tex, h, w, pose)
	if is_player:
		_draw_brooch(Vector2(-w * 0.13, -h * 0.68))
	if pose.get("lantern", false) and not pose.has("tool"):
		if HERO_LANTERN.has(sprite_id):
			_apply_lantern_tint(tex)    # фонарь нарисован на картинке героя: меняем цвет его стекла
		else:
			Folk._lantern(body, Vector2(w * 0.4, -h * 0.46), S, Art.INK, 2.8 * S, pose.get("lantern_style", {}))
	if pose.get("point", false):
		# рука-указатель: от плеча вперёд, в сторону взгляда
		var a := Vector2(w * 0.28, -h * 0.68)
		var b := a + Vector2(26, -3)
		body.draw_line(a, b, Art.INK, 6.0, true)
		body.draw_line(a, b, Color("d8b090"), 3.6, true)
		body.draw_colored_polygon(PackedVector2Array([b + Vector2(0, -5), b + Vector2(9, 0), b + Vector2(0, 5)]), ThemeFactory.LAMP)
	body.draw_set_transform(Vector2.ZERO)
	if pose.get("emote", false):
		_emote_mark(face, Vector2(-w * 0.32, -h + 2.0))


static func _is_realistic_sprite(tex: Texture2D) -> bool:
	return tex != null and tex.resource_path.begins_with(FOLK_REALISTIC_DIR)


## Детализированный спрайт идёт через ту же сетку: ноги шагают, а фонарь получает локальную окраску.
func _draw_realistic_sprite(tex: Texture2D, h: float, w: float, pose: Dictionary) -> void:
	var walk_phase := sin(_walk * TAU) * _walk_weight
	var idle_weight := 1.0 - _walk_weight
	var breath := sin(_t * 1.7 + _phase) * idle_weight
	var work := sin(float(pose.get("work", 0.0)) * TAU) if pose.has("work") else 0.0
	# Фотография целая, поэтому сетка не гнётся: ноги на ней не отделены, и любой сдвиг низа растягивал одежду.
	# Шаг показан движением корпуса целиком: на каждый шаг он приподнимается (на стопе вес, в середине шага выше всего),
	# качается с боку на бок вокруг стоп и наклоняется вперёд, пока идёт.
	var lift := absf(walk_phase) * REAL_STEP_LIFT
	var bob := -lift + breath * 0.16
	var sway := walk_phase * REAL_STEP_SWAY + sin(_t * 0.53 + _phase) * 0.2 * idle_weight
	var turn := _render_tilt + walk_phase * REAL_STEP_ROLL + _walk_weight * REAL_STEP_LEAN + breath * 0.003 + work * 0.004
	if pose.has("shiver"):
		sway += sin(_t * 18.0 + _phase) * 0.28
	_draw_field_rig(tex, h, w, pose, 0.0, true)
	_door_rig.position = Vector2(sway, bob)
	_door_rig.rotation = turn
	if _cast_poly.visible:
		_cast_poly.position = Vector2(sway, 1.0)


## Значок на груди героя — маленький, потёртый металл, как всё в посёлке:
## тёмный край, приглушённый цвет, блик сверху. Яркий кружок на рисованной одежде смотрелся наклейкой.
func _draw_brooch(at: Vector2) -> void:
	if brooch_id == "none":
		return
	var k := 0.72            # мельче: значок, а не медаль
	var fill := Color("b08a4a")
	if brooch_id == "bone": fill = Color("bdb7a0")
	if brooch_id == "seal": fill = Color("8c4446")
	var edge := Color(0.1, 0.07, 0.06, 0.85)
	body.draw_circle(at + Vector2(0.4, 0.6) * k, 3.3 * k, Color(0, 0, 0, 0.3))
	body.draw_circle(at, 3.2 * k, edge)
	body.draw_circle(at, 2.5 * k, fill.darkened(0.15))
	body.draw_circle(at + Vector2(-0.3, -0.4) * k, 1.7 * k, fill)
	match brooch_id:
		"sun":
			for i in range(8):
				var d := Vector2.from_angle(TAU * float(i) / 8.0)
				body.draw_line(at + d * 3.3 * k, at + d * 4.3 * k, fill.darkened(0.1), 0.8, true)
		"bone":
			body.draw_line(at + Vector2(-1.3, -1.3) * k, at + Vector2(1.3, 1.3) * k, edge, 0.8, true)
			body.draw_line(at + Vector2(-1.3, 1.3) * k, at + Vector2(1.3, -1.3) * k, edge, 0.8, true)
		_:
			body.draw_circle(at, 0.8 * k, edge)
	body.draw_circle(at + Vector2(-0.9, -1.1) * k, 0.6 * k, Color(1, 0.95, 0.85, 0.55))

func _build_sprite_rig(tex: Texture2D, h: float, w: float) -> void:
	if _door_rig.texture != tex or _door_base.is_empty():
		var uv := PackedVector2Array()
		var faces: Array = []
		_door_base.clear()
		_door_weights.clear()
		_left_wrist_weights.clear()
		var hands := {1: Vector2(0.71, 0.47), 2: Vector2(0.87, 0.48), 3: Vector2(0.76, 0.47),
			4: Vector2(0.9, 0.49), 5: Vector2(0.84, 0.53), 6: Vector2(0.78, 0.5),
			7: Vector2(0.88, 0.51), 8: Vector2(0.91, 0.5), 9: Vector2(0.7, 0.47),
			10: Vector2(0.94, 0.49), 11: Vector2(0.7, 0.48), 12: Vector2(0.74, 0.44),
			13: Vector2(0.9, 0.54), 14: Vector2(0.92, 0.54), 15: Vector2(0.92, 0.54), 16: Vector2(0.9, 0.56)}
		var wrist: Vector2 = hands.get(sprite_id, Vector2(0.88, 0.5))
		for row in range(14):
			for column in range(10):
				var x := float(column) / 9.0
				var y := float(row) / 13.0
				_door_base.append(Vector2((x - 0.5) * w, (y - 1.0) * h))
				uv.append(Vector2(x * tex.get_width(), y * tex.get_height()))
				var distance := Vector2((x - wrist.x) / 0.18, (y - wrist.y) / 0.15)
				_door_weights.append(exp(-distance.length_squared() * 2.0))
				var left_distance := Vector2((x - 0.16) / 0.18, (y - 0.49) / 0.15)
				_left_wrist_weights.append(exp(-left_distance.length_squared() * 2.0))
		for row in range(13):
			for column in range(9):
				var corner := row * 10 + column
				faces.append(PackedInt32Array([corner, corner + 1, corner + 10]))
				faces.append(PackedInt32Array([corner + 1, corner + 11, corner + 10]))
		for rig: Polygon2D in [_door_rig, _door_shadow, _cast_poly]:
			rig.texture = tex
			rig.uv = uv
			rig.polygons = faces


## Шаг привязан к пройденному расстоянию. Ноги и рукава двигаются раздельно;
## корпус и голова сохраняют высоту, при остановке движение мягко затухает.
func _draw_field_rig(tex: Texture2D, h: float, w: float, pose: Dictionary, motion_scale: float = 1.0, rigid: bool = false) -> void:
	_build_sprite_rig(tex, h, w)
	var points := _door_base.duplicate()
	if rigid:
		# фотография без деформации: сетка остаётся ровной, двигается только целый спрайт
		_door_rig.polygon = points
		_door_rig.position = Vector2.ZERO
		_door_rig.rotation = _render_tilt
		_door_rig.scale = Vector2.ONE
		_door_rig.visible = true
		_door_shadow.visible = false
		_place_cast_shadow(points, 0.0)
		return
	var stride := sin(_walk * TAU) * _walk_weight * motion_scale
	var body_bob := absf(stride) * 0.05
	var work_motion := sin(float(pose.get("work", 0.0)) * TAU) if pose.has("work") else 0.0
	for i in range(points.size()):
		var base := _door_base[i]
		var y := 1.0 + base.y / h
		var x := base.x / w
		var side := tanh(x * 16.0)
		var leg := smoothstep(0.56, 0.94, y)
		var lifted_foot := maxf(0.0, stride * side)
		points[i].x += stride * side * leg * 9.0
		points[i].y -= lifted_foot * leg * 4.5
		var upper_body := 1.0 - smoothstep(0.56, 0.88, y)
		points[i].y -= body_bob * upper_body
		var sleeve := exp(-pow((y - 0.49) / 0.16, 2.0)) * smoothstep(0.12, 0.38, absf(x))
		points[i].x -= stride * side * sleeve * 4.0
		points[i].y += work_motion * sleeve * 1.8
		var arm_len := h * 0.19
		var right_angle := float(pose.get("arm_r", 0.12 - stride * 0.48))
		var left_angle := float(pose.get("arm_l", 0.12 + stride * 0.48))
		var right_shift := Vector2(sin(right_angle) - sin(0.12), cos(right_angle) - cos(0.12)) * arm_len
		var left_shift := Vector2(sin(left_angle) - sin(0.12), cos(left_angle) - cos(0.12)) * arm_len
		points[i] += right_shift * _door_weights[i] + left_shift * _left_wrist_weights[i]
	_door_rig.polygon = points
	_door_rig.position = Vector2.ZERO
	_door_rig.rotation = _render_tilt
	_door_rig.scale = Vector2.ONE
	_door_rig.visible = true
	_door_shadow.visible = false
	_place_cast_shadow(points, 0.0)


## Падающая тень стоит на земле: точка на высоте H уходит на SHADOW_KX*H вправо и SHADOW_KY*H вниз.
## Тело отражается, когда житель смотрит влево, поэтому наклон умножаем на сторону: на экране тень всегда вправо.
func _place_cast_shadow(points: PackedVector2Array, sway: float) -> void:
	var on := cast_alpha > 0.01 and not door_portrait
	_cast_poly.visible = on
	if not on:
		return
	_cast_poly.polygon = points
	_cast_poly.modulate = Color(0, 0, 0, cast_alpha)
	_cast_poly.transform = Transform2D(Vector2(1.0, 0.0), Vector2(-CAST_KX * _face, -CAST_KY), Vector2(sway, 1.0))


## Сила падающей тени (день сильнее, ночь и непогода слабее). Включает и гасит копию тела.
func set_cast_shadow(a: float) -> void:
	cast_alpha = a
	if _cast_poly != null and a <= 0.01:
		_cast_poly.visible = false


## У двери та же сетка и палитра; отдельно двигаются кисть и тень.
func _draw_door_rig(tex: Texture2D, h: float, w: float, at: Vector2, rot: float, stretch: Vector2, motion: float) -> void:
	_build_sprite_rig(tex, h, w)
	var points := _door_base.duplicate()
	var shadow_points := _door_base.duplicate()
	var progress := 1.0 - _knock_t / KNOCK_LEN
	var delay := 0.035 if door_tell == &"shadow" else 0.005
	var shadow_motion := sin(maxf(0.0, progress - delay / KNOCK_LEN) * PI) if _knock_t > 0.0 else 0.0
	for i in range(points.size()):
		points[i] += Vector2(5.0, -2.3) * motion * _door_weights[i]
		shadow_points[i] += Vector2(5.0, -2.3) * shadow_motion * _door_weights[i]
	_door_rig.polygon = points
	_door_shadow.polygon = shadow_points
	_door_rig.position = at
	_door_shadow.position = at + Vector2(4.0, 2.0)
	for rig: Polygon2D in [_door_rig, _door_shadow]:
		rig.rotation = rot
		rig.scale = stretch
		rig.visible = true


## Знак эмоции над плечом. Только симметричные знаки: фигурка отражается, когда смотрит влево.
func _emote_mark(face: String, at: Vector2) -> void:
	var k := Color(0.08, 0.06, 0.1, 0.9)
	match face:
		"shocked", "scared":
			var c := ThemeFactory.BONE if face == "shocked" else Color("9fd8f0")
			body.draw_rect(Rect2(at.x - 3.5, at.y - 22, 7, 14), k)
			body.draw_rect(Rect2(at.x - 2, at.y - 20.5, 4, 11), c)
			body.draw_circle(at + Vector2(0, -3), 3.6, k)
			body.draw_circle(at + Vector2(0, -3), 2.2, c)
		"angry":
			for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var c2 := at + Vector2(0, -12) + q * 4.0
				body.draw_arc(c2, 3.4, q.angle() + PI * 0.5, q.angle() + PI * 1.5, 6, k, 3.4, true)
				body.draw_arc(c2, 3.4, q.angle() + PI * 0.5, q.angle() + PI * 1.5, 6, ThemeFactory.BLOOD, 2.0, true)
		"suspicious", "confused", "sad", "cold":
			for i in range(3):
				var p := at + Vector2((i - 1) * 6.0, -9)
				body.draw_circle(p, 2.8, k)
				body.draw_circle(p, 1.8, ThemeFactory.BONE)


## Лицо и поза, которыми житель нарисуется сейчас: [лицо, поза].
func pose_now() -> Array:
	var f := current_face()
	var pose := {"lantern": is_player, "turn": turn * _face, "look": Vector2(turn * _face, 0.0),
		"emote": state == State.SCARED or (_emotion_t > 0.0 and emotion != "" and emotion != "sly")}
	if (f == "angry" or emotion == "point") and _point_dir != 0.0 and _emotion_t > 0.0:
		pose["point"] = true
		pose["dir"] = 1.0
	if state == State.RUN or _walk_weight > 0.01:
		pose["walk"] = _walk
		pose["amp"] = _walk_weight
	if working and tool != "":
		pose["tool"] = tool
		pose["work"] = _work
		pose["hop"] = 0.0
	if cold and f == "cold":
		pose["shiver"] = true
	if fidget != "" and state == State.IDLE and not working:
		var ff := _fidget_pose(pose)
		if ff != "" and f == "neutral":
			f = ff
	if _lean != 0.0:
		pose["lean"] = _lean * _face
	if f == "sad":
		pose["lean"] = float(pose.get("lean", 0.0)) + 0.07
		if mood == "grief" or mood == "despair":
			pose["lean"] = float(pose.get("lean", 0.0)) + 0.08     # горе сутулит
			pose["droop"] = 1.0
	if f == "cold" and mood == "fear":
		pose["shiver"] = true
	if f == "angry" and mood == "rage" and not bool(pose.get("emote", false)):
		pose["fists"] = true
	elif f == "happy" or f == "relieved":
		pose["tilt"] = -0.03
	if _knock_t > 0.0:
		var hit := sin((1.0 - _knock_t / KNOCK_LEN) * PI)
		pose["knock"] = hit
		pose["lean"] = float(pose.get("lean", 0.0)) + 0.12 * hit
		if sprite_id <= 0:
			pose["arm_r"] = lerpf(float(pose.get("arm_r", 0.12)), 1.85, hit)
	if is_player:
		pose["lantern_style"] = Cosmetics.lantern(lantern_id)
	return [f, pose]


## Надеть фонарь: стекло, огонь и цвет света вокруг.
func set_lantern(id: String) -> void:
	lantern_id = id
	if lantern_light != null:
		lantern_light.color = Cosmetics.lantern(id).light
	body.queue_redraw()


func set_brooch(id: String) -> void:
	brooch_id = id
	body.queue_redraw()


func _ellipse(c: Vector2, r: Vector2, seg: int = 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


