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
const STRIDE_LENGTH := 70.0
var _turn_t: float = 0.0
var _knock_t: float = 0.0
const KNOCK_LEN := 0.24
var door_portrait := false
var door_tell: StringName = &"ordinary"
var _door_rig: Polygon2D
var _door_shadow: Polygon2D
var _door_base := PackedVector2Array()
var _door_weights := PackedFloat32Array()

## Жизнь на площади (задача 44): между репликами житель что-то делает — чешет затылок,
## смотрит на небо, потягивается, скрещивает руки, переминается. Включает толпа, только днём.
## Поза меняется в начале и в конце действия (у «почесать» — ещё раз посередине): две-три перерисовки.
const FIDGETS: PackedStringArray = ["scratch", "sky", "stretch", "arms", "shift"]
var fidgets_on := false
var fidget: String = ""
var fidget_count := 0          ## сколько действий сделал — для самотеста
var _fidget_t := 0.0
var _fidget_len := 0.0
var _fidget_in := 0.0
var _lean := 0.0               ## отшатнулся (обвинили) или наклонился к соседу (шепчет)
var _lean_t := 0.0

var lantern_id := "classic"     ## фонарь игрока (Cosmetics.LANTERNS) — только картинка и цвет света

## Тело — картинка из листов жителей (assets/folk/f1..f16): первый лист — старуха, мужик с бородой,
## девушка в кокошнике, парень, старик с клюкой, девочка, кузнец, охотник; второй — четыре женщины,
## рыбак, крестьянин, мальчик и священник. 0 — рисовать кодом (примерка в гардеробе).
## Двигается кодом: дыхание, шаг, наклон, дрожь; эмоция — знак над головой.
const FOLK_DIR := "res://assets/folk/"
const FOLK_FEMALE: PackedInt32Array = [1, 3, 6, 9, 10, 11, 12]
const FOLK_MALE: PackedInt32Array = [2, 4, 5, 7, 8, 13, 14, 15, 16]
## Герой игрока — с фонарём в руке; варианты шапок лежат рядом как hero_m_<hat> / hero_f_<hat>.
const HERO_M := 101
const HERO_F := 102
const HERO_HAT_IDS: PackedStringArray = ["top_hat", "beret", "straw", "ushanka", "flower", "jester"]
## Где фонарь на картинке героя: доля ширины от середины и доля высоты от земли.
const HERO_LANTERN := {HERO_M: Vector2(0.41, 0.56), HERO_F: Vector2(0.30, 0.52)}
static var _folk_tex: Dictionary = {}
static var _hero_hat_tex: Dictionary = {}
var sprite_id: int = 0
var hero_hat_id: String = "own"
var tag: Node2D               ## слой подписи над всем посёлком

const WALK_SPEED := 145.0   ## единиц посёлка в секунду


func setup(name: String, l: LookDef, player: bool) -> void:
	who = name
	look = l
	is_player = player
	_font = ThemeFactory.font_bold()
	_phase = float(absi(name.hash()) % 628) / 100.0
	_blink_in = 1.0 + fmod(_phase, 3.0)
	body = Node2D.new()
	add_child(body)
	body.draw.connect(_draw_body)
	_door_shadow = Polygon2D.new()
	_door_shadow.show_behind_parent = true
	_door_shadow.modulate = Color(0, 0, 0, 0.2)
	_door_shadow.visible = false
	body.add_child(_door_shadow)
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
		lantern_light.texture = _soft()
		lantern_light.position = _hero_lantern_pos()
		lantern_light.texture_scale = 2.6
		lantern_light.color = Color(1.0, 0.8, 0.5)
		lantern_light.energy = 0.0
		lantern_light.visible = false
		add_child(lantern_light)


func set_identity_color(id: int) -> void:
	identity_id = posmod(id, IDENTITY_COLORS.size())
	identity_color = IDENTITY_COLORS[identity_id]
	if _door_rig != null:
		_door_rig.material = null
	if body != null:
		body.queue_redraw()
	if tag != null:
		tag.queue_redraw()


static func pick_cast_sprite(v: Villager, used: Dictionary) -> int:
	var candidates: PackedInt32Array
	if v.female:
		candidates = PackedInt32Array([9, 3, 10]) if v.age < 28 else (PackedInt32Array([11, 12, 1]) if v.age >= 55 else PackedInt32Array([10, 3, 9]))
	else:
		candidates = PackedInt32Array([4, 14, 8, 7, 2, 13]) if v.age < 28 else (PackedInt32Array([5, 16, 8, 2]) if v.age >= 55 else PackedInt32Array([13, 7, 8, 2, 14]))
	for id: int in candidates:
		if not used.has(id):
			used[id] = true
			return id
	return candidates[posmod(v.story_id, candidates.size())]


static func folk_tex(id: int) -> Texture2D:
	if not _folk_tex.has(id):
		var file := "hero_m" if id == HERO_M else ("hero_f" if id == HERO_F else "f%d" % id)
		_folk_tex[id] = load(FOLK_DIR + file + ".png")
	return _folk_tex[id]


## Вариант портрета героя с выбранной шапкой. Пустой ресурс позволит тесту поймать недостающий файл.
static func hero_hat_texture(id: int, hat_id: String) -> Texture2D:
	if id not in [HERO_M, HERO_F] or not HERO_HAT_IDS.has(hat_id):
		return null
	var gender := "hero_m" if id == HERO_M else "hero_f"
	var path := FOLK_DIR + gender + "_" + hat_id + ".png"
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
	body.queue_redraw()


## Свет фонаря — там, где фонарь у героя на картинке; у жителя, нарисованного кодом, — в правой руке.
func _hero_lantern_pos() -> Vector2:
	if not HERO_LANTERN.has(sprite_id):
		return Vector2(25 * S, -28 * S)
	var tex := folk_tex(sprite_id)
	var h := FIG_TOP * (look.height if look != null else 1.0) * 0.97
	var w := h * tex.get_width() / tex.get_height()
	var k: Vector2 = HERO_LANTERN[sprite_id]
	return Vector2(w * k.x, -h * k.y)


## Ночью фонарь игрока светит, днём погашен; ночью у всех встревоженные лица.
func set_night(n: float) -> void:
	night = n
	if lantern_light != null:
		lantern_light.visible = n > 0.05
		lantern_light.energy = 0.85 * n


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
		f = FIDGETS[(fidget_count * 3 + int(_phase * 10.0)) % FIDGETS.size()]
	fidget = f
	_fidget_len = 1.4 + fmod(_phase * 7.0 + fidget_count * 0.61, 1.1)
	_fidget_t = _fidget_len
	fidget_count += 1
	body.queue_redraw()


## Стоит без дела: можно шепнуть ему или начать действие.
func is_free() -> bool:
	return state == State.IDLE and not working and not cold and _talk_t <= 0.0 and fidget == "" and (_emotion_t <= 0.0 or emotion == "")


func _next_fidget_in() -> float:
	return 5.0 + fmod(_phase * 13.0 + fidget_count * 2.3, 7.0)


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


func label_rect_global() -> Rect2:
	return _global_rect(label_rect_local())


func body_rect_global() -> Rect2:
	return _global_rect(body_rect_local())


# =============================================================
# Состояния
# =============================================================
## delay — сколько секунд постоять, прежде чем сорваться (житель не сразу услышал колокол).
func run_to(target: Vector2, dur: float = 0.75, delay: float = 0.0) -> void:
	if state == State.DEAD or state == State.GONE:
		return
	if _tw != null:
		_tw.kill()
	if Juice.instant:
		position = target
		_settle_idle()
		arrived.emit()
		return
	if delay > 0.0:
		_settle_idle()
	else:
		state = State.RUN
	if absf(target.x - position.x) > 3.0:
		_face = -1.0 if target.x < position.x else 1.0
	_tw = create_tween()
	if delay > 0.0:
		_tw.tween_interval(delay)
		_tw.tween_callback(func() -> void: state = State.RUN)
	_tw.tween_property(self, "position", target, maxf(0.05, dur)).set_trans(Tween.TRANS_LINEAR)
	_tw.tween_callback(func() -> void:
		_settle_idle()
		arrived.emit())


## Идти шагом с постоянной скоростью — длина пути решает, сколько идти.
func walk_to(target: Vector2) -> void:
	run_to(target, clampf(position.distance_to(target) / WALK_SPEED, 0.25, 4.0))


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
	if state == State.RUN and travelled < 80.0 and not Juice.instant:
		_walk = fmod(_walk + travelled / STRIDE_LENGTH, 1.0)
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
			var s := sin(_t * 1.7 + _phase)
			var breath_size := 0.004
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
	if not fidgets_on or state != State.IDLE or working or cold or _talk_t > 0.0:
		return
	if _fidget_in <= 0.0:
		_fidget_in = 1.5 + fmod(_phase * 3.0, 6.0)    # первые действия в разное время, без хора
	_fidget_in -= delta
	if _fidget_in <= 0.0:
		start_fidget()


## Поза действия поверх обычной.
func _fidget_pose(pose: Dictionary) -> String:
	match fidget:
		"scratch":
			var up := _fidget_t > _fidget_len * 0.5
			pose["arm_r"] = 2.75 if up else 2.55
			pose["tilt"] = 0.12
			return "confused"
		"sky":
			pose["look"] = Vector2(0.2, -1.0)
			pose["tilt"] = -0.14
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
			pose["walk"] = 0.2
			pose["amp"] = 0.45
			pose["lean"] = 0.05
			return ""
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


## Тень, кольцо «Вы» и надгробие — на земле, в общем порядке по глубине.
func _draw() -> void:
	if state == State.GONE:
		return
	draw_colored_polygon(_ellipse(Vector2(0, 2), Vector2(18, 5.5)), Color(0, 0, 0, 0.26))
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
		var ring := _ellipse(Vector2(0, 2), Vector2(17, 6.5), 22)
		ring.append(ring[0])
		tag.draw_polyline(ring, Color(ThemeFactory.LAMP, 0.85), 2.0)
	var bg := Color(ThemeFactory.NIGHT, 0.8)
	if eye_level > 0:
		var c := Vector2(MARK_X, -66)
		var s := 1.0 + 0.5 * _eye_pop
		var col: Color = EYE_COLORS[clampi(eye_level, 0, 4)]
		tag.draw_circle(c, 11.0 * s, bg)
		var open := (2.5 + eye_level * 1.1) * s
		var pts := PackedVector2Array()
		for i in range(9):
			var t := float(i) / 8.0
			pts.append(c + Vector2((t - 0.5) * 18.0 * s, -sin(t * PI) * open))
		for i in range(7, 0, -1):
			var t := float(i) / 8.0
			pts.append(c + Vector2((t - 0.5) * 18.0 * s, sin(t * PI) * open))
		tag.draw_colored_polygon(pts, Color(col, 0.25))
		var outline := pts.duplicate()
		outline.append(pts[0])
		tag.draw_polyline(outline, col, 1.6)
		tag.draw_circle(c, minf(open, 2.2 + eye_level * 0.6), col)
		tag.draw_circle(c, 1.2 * s, Color("0d1214"))
		# штрихи над глазом: сколько штрихов, столько уровней подозрения — различимо без цвета
		drawn_strokes = 0
		for seg: PackedVector2Array in eye_strokes(eye_level, c, s):
			tag.draw_line(seg[0], seg[1], col, 2.0)
			drawn_strokes += 1
	var y := -46.0
	for b: String in badges.slice(0, 2):
		var accent := ThemeFactory.LAMP
		match b:
			"liar": accent = Color("e0533f")
			"death": accent = Color("e0533f")
			"sabotage": accent = Color("e0533f")
		# у каждой улики свой силуэт рамки: круг, ромб, щит… — различимы без цвета
		var frame := badge_outline(b, Vector2(MARK_X, y))
		drawn_frames.append(frame.size())
		tag.draw_colored_polygon(frame, Color(ThemeFactory.NIGHT, 0.9))
		var fo := frame.duplicate()
		fo.append(frame[0])
		tag.draw_polyline(fo, Color(accent, 0.9), 1.6)
		match b:
			"street":
				tag.draw_colored_polygon(_ellipse(Vector2(MARK_X - 3.2, y + 2.5), Vector2(2.6, 4.2), 10), ThemeFactory.LAMP)
				tag.draw_colored_polygon(_ellipse(Vector2(MARK_X + 3.2, y - 3.0), Vector2(2.6, 4.2), 10), ThemeFactory.LAMP)
			"liar":
				var hc := ThemeFactory.BONE
				tag.draw_polyline(PackedVector2Array([Vector2(MARK_X - 5.5, y + 5.5), Vector2(MARK_X - 5.5, y - 1), Vector2(MARK_X, y - 6.5),
					Vector2(MARK_X + 5.5, y - 1), Vector2(MARK_X + 5.5, y + 5.5), Vector2(MARK_X - 5.5, y + 5.5)]), hc, 1.6)
				tag.draw_line(Vector2(MARK_X - 7, y + 7), Vector2(MARK_X + 7, y - 7), accent, 2.2)
			"death":
				tag.draw_circle(Vector2(MARK_X, y + 2.5), 4.6, accent)
				tag.draw_colored_polygon(PackedVector2Array([Vector2(MARK_X - 4.2, y + 1), Vector2(MARK_X + 4.2, y + 1), Vector2(MARK_X, y - 7)]), accent)
			"fake":   # пустое ведро
				tag.draw_polyline(PackedVector2Array([Vector2(MARK_X - 5, y - 4), Vector2(MARK_X - 3.6, y + 5.5), Vector2(MARK_X + 3.6, y + 5.5), Vector2(MARK_X + 5, y - 4)]), ThemeFactory.BONE, 1.6)
				tag.draw_arc(Vector2(MARK_X, y - 4), 5.0, PI, TAU, 8, ThemeFactory.BONE, 1.2)
			"tunnel":   # люк
				tag.draw_rect(Rect2(MARK_X - 6, y - 3, 12, 8), Color("8a5a3a"))
				tag.draw_rect(Rect2(MARK_X - 6, y - 3, 12, 8), ThemeFactory.BONE, false, 1.2)
				tag.draw_circle(Vector2(MARK_X + 3, y + 1), 1.4, ThemeFactory.BONE)
			"sabotage":   # трещина
				tag.draw_polyline(PackedVector2Array([Vector2(MARK_X - 1, y - 7), Vector2(MARK_X + 3, y - 2), Vector2(MARK_X - 2.5, y + 1.5), Vector2(MARK_X + 2, y + 7)]), accent, 2.0)
		y += 19.0


## Палитра из внешности: цвета насыщеннее прежних приглушённых, шапка по типу головы.
func _pal() -> Dictionary:
	var coat := _bright(look.coat)
	var tops := {LookDef.Head.BARE: "hair", LookDef.Head.CAP: "cap", LookDef.Head.SCARF: "kerchief", LookDef.Head.HAT: "hat", LookDef.Head.HOOD: "beanie"}
	var hat := Color("3b3b58")
	match look.head:
		LookDef.Head.CAP: hat = coat.darkened(0.4)
		LookDef.Head.SCARF: hat = _bright(look.accent)
		LookDef.Head.HOOD: hat = _bright(look.accent).darkened(0.1)
	return {"coat": coat, "coat_d": coat.darkened(0.2), "skin": look.skin.lightened(0.08), "skin_d": look.skin.darkened(0.08),
		"hair": look.hair, "scarf": _bright(look.accent), "hat": hat, "top": tops.get(look.head, "hair")}


func _bright(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.3 + 0.08), minf(1.0, c.v * 1.45 + 0.08), c.a)


func _draw_body() -> void:
	var fp := pose_now()
	# Если PNG выбранной шапки недоступен, используем запасное рисование героя кодом.
	# Так шапка остаётся видна на поле; загруженный PNG-вариант сохранит исходный стиль.
	var missing_hero_hat := is_player and hero_hat_id != "own" and hero_hat_texture(sprite_id, hero_hat_id) == null
	if sprite_id <= 0 or missing_hero_hat:
		Folk.figure(body, Vector2.ZERO, S, look, fp[0], fp[1], Folk.palette(look))
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
		_draw_field_rig(tex, h, w, pose)
	if pose.get("lantern", false) and not pose.has("tool") and not HERO_LANTERN.has(sprite_id):
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


func _build_sprite_rig(tex: Texture2D, h: float, w: float) -> void:
	if _door_rig.texture != tex or _door_base.is_empty():
		var uv := PackedVector2Array()
		var faces: Array = []
		_door_base.clear()
		_door_weights.clear()
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
		for row in range(13):
			for column in range(9):
				var corner := row * 10 + column
				faces.append(PackedInt32Array([corner, corner + 1, corner + 10]))
				faces.append(PackedInt32Array([corner + 1, corner + 11, corner + 10]))
		for rig: Polygon2D in [_door_rig, _door_shadow]:
			rig.texture = tex
			rig.uv = uv
			rig.polygons = faces


## Шаг привязан к пройденному расстоянию. Ноги и рукава двигаются раздельно;
## корпус и голова сохраняют высоту, при остановке движение мягко затухает.
func _draw_field_rig(tex: Texture2D, h: float, w: float, pose: Dictionary) -> void:
	_build_sprite_rig(tex, h, w)
	var points := _door_base.duplicate()
	var stride := sin(_walk * TAU) * _walk_weight
	var work_motion := sin(float(pose.get("work", 0.0)) * TAU) if pose.has("work") else 0.0
	for i in range(points.size()):
		var base := _door_base[i]
		var y := 1.0 + base.y / h
		var x := base.x / w
		var side := tanh(x * 16.0)
		var leg := smoothstep(0.58, 0.98, y)
		points[i].x += stride * side * leg * 3.4
		points[i].y -= maxf(0.0, stride * side) * leg * 1.35
		var sleeve := exp(-pow((y - 0.49) / 0.16, 2.0)) * smoothstep(0.12, 0.38, absf(x))
		points[i].x -= stride * side * sleeve * 1.4
		points[i].y += work_motion * sleeve * 1.8
	_door_rig.polygon = points
	_door_rig.position = Vector2.ZERO
	_door_rig.rotation = _render_tilt
	_door_rig.scale = Vector2.ONE
	_door_rig.visible = true
	_door_shadow.visible = false


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


func _ellipse(c: Vector2, r: Vector2, seg: int = 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _arc(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(13):
		var a := PI + PI * i / 12.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r))
	return pts


func _soft() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t
