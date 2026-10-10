class_name VillagerFigure
extends Node2D
## Житель на площади. Тело рисует Folk в отдельном узле — его сжимает и растягивает
## анимация, а имя под ногами остаётся ровным. Дыхание, дрожь и подпрыгивания — через трансформ,
## без перерисовки. Перерисовка — при смене лица, моргании, повороте головы, а на бегу
## и за работой — каждый кадр: там двигаются ноги, руки и инструмент.

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
var _anim_acc: float = 0.0
var _turn_t: float = 0.0

const WALK_SPEED := 190.0   ## единиц посёлка в секунду


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
	if player:
		lantern_light = PointLight2D.new()
		lantern_light.texture = _soft()
		lantern_light.position = Vector2(25 * S, -28 * S)
		lantern_light.texture_scale = 2.6
		lantern_light.color = Color(1.0, 0.8, 0.5)
		lantern_light.energy = 0.0
		lantern_light.visible = false
		add_child(lantern_light)


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


func current_face() -> String:
	if state == State.SCARED:
		return "scared"
	if _emotion_t > 0.0 and emotion != "":
		return emotion
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


func set_cold(on: bool) -> void:
	if cold != on:
		cold = on
		body.queue_redraw()


const LABEL_SIZE := 14


func body_scale() -> Vector2:
	return body.scale


## Прямоугольники для раскладки и самотестов, в координатах фигурки.
func label_width() -> float:
	return _font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x


func label_rect_local() -> Rect2:
	var w := label_width()
	return Rect2(-w * 0.5 - 8.0, 6, w + 16.0, 21)


func body_rect_local() -> Rect2:
	var h := look.height if look != null else 1.0
	var extra := 26.0 if highlight else 0.0
	return Rect2(-23, -FIG_TOP * h - extra, 23 + MARK_X + 12, FIG_TOP * h + 2 + extra)


func set_highlight(on: bool) -> void:
	highlight = on
	queue_redraw()


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
	queue_redraw()
	if grew and not Juice.instant:
		var t := create_tween()
		t.tween_method(func(v: float) -> void:
			_eye_pop = v
			queue_redraw(), 1.0, 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Отклик на тап: короткий подскок.
func poke() -> void:
	if state != State.IDLE or Juice.instant:
		return
	var t := create_tween()
	t.tween_property(body, "scale", Vector2(_face * 1.16, 0.84), 0.06)
	t.tween_property(body, "scale", Vector2(_face, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	_face = -1.0 if target.x < position.x else 1.0
	_tw = create_tween()
	if delay > 0.0:
		_tw.tween_interval(delay)
		_tw.tween_callback(func() -> void: state = State.RUN)
	_tw.tween_property(body, "scale", Vector2(_face * 1.2, 0.8), 0.08)
	_tw.tween_property(body, "scale", Vector2(_face * 0.88, 1.14), 0.1)
	_tw.parallel().tween_property(self, "position", target, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(body, "scale", Vector2(_face * 1.22, 0.78), 0.07)
	_tw.tween_property(body, "scale", Vector2(_face, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
		queue_redraw()
		return
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(body, "scale", Vector2(_face * 1.25, 0.05), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(body, "modulate:a", 0.0, 0.55)
	_tw.chain().tween_callback(func() -> void:
		body.visible = false
		queue_redraw())


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
	if highlight:
		queue_redraw()
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
				# работа: руки с инструментом ходят — перерисовка ~20 раз в секунду
				_work = fmod(_work + delta * 0.9, 1.0)
				_anim_step(delta)
				body.scale = Vector2(_face, 1.0)
				body.position = Vector2.ZERO
				return
			var s := sin(_t * 1.7 + _phase)
			body.scale = Vector2(_face * (1.0 - 0.015 * s), 1.0 + 0.025 * s)   # дыхание
			body.position = Vector2(sin(_t * 38.0 + _phase) * 0.9 if cold else 0.0, 0.0)   # дрожь на холоде
		State.RUN:
			_walk = fmod(_walk + delta * 2.6, 1.0)
			_anim_step(delta)
		State.SCARED:
			body.position.x = sin(_t * 46.0) * 1.5


## Ноги и руки двигаются только на бегу и за работой: перерисовка не чаще 24 раз в секунду.
func _anim_step(delta: float) -> void:
	_anim_acc += delta
	if _anim_acc >= 1.0 / 24.0:
		_anim_acc = 0.0
		body.queue_redraw()


# =============================================================
# Рисование
# =============================================================
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
	if state != State.DEAD:
		_draw_marks()
	if highlight and state != State.DEAD:
		var p := 0.5 + 0.5 * sin(_t * 4.0)
		var ring := _ellipse(Vector2(0, 2), Vector2(24.0 + 4.0 * p, 8.0 + 1.5 * p), 26)
		ring.append(ring[0])
		draw_polyline(ring, Color(ThemeFactory.LAMP, 0.5 + 0.45 * p), 3.0, true)
		var hh := look.height if look != null else 1.0
		var y0 := -FIG_TOP * hh - 10.0 + 3.0 * sin(_t * 5.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-9, y0 - 12), Vector2(9, y0 - 12), Vector2(0, y0)]), ThemeFactory.LAMP)
	# имя — в тёмной капсуле
	var lr := label_rect_local()
	var col := ThemeFactory.LAMP if is_player else Color(1, 1, 1, 0.95 if state != State.DEAD else 0.45)
	Art.shape(self, Art.rrect(lr, lr.size.y * 0.5), Color(0.08, 0.06, 0.12, 0.72 if state != State.DEAD else 0.4), Color(col, 0.35), 1.2)
	draw_string(_font, Vector2(lr.position.x + 8.0, lr.end.y - 5.0), who, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, col)


const EYE_COLORS := [Color(0, 0, 0, 0), Color("8fa3ab"), Color("d9a24e"), Color("d0683a"), Color("c23a33")]


func _draw_marks() -> void:
	if pact:
		var ring := _ellipse(Vector2(0, 2), Vector2(17, 6.5), 22)
		ring.append(ring[0])
		draw_polyline(ring, Color(ThemeFactory.LAMP, 0.85), 2.0)
	var bg := Color(ThemeFactory.NIGHT, 0.8)
	if eye_level > 0:
		var c := Vector2(MARK_X, -66)
		var s := 1.0 + 0.5 * _eye_pop
		var col: Color = EYE_COLORS[clampi(eye_level, 0, 4)]
		draw_circle(c, 11.0 * s, bg)
		var open := (2.5 + eye_level * 1.1) * s
		var pts := PackedVector2Array()
		for i in range(9):
			var t := float(i) / 8.0
			pts.append(c + Vector2((t - 0.5) * 18.0 * s, -sin(t * PI) * open))
		for i in range(7, 0, -1):
			var t := float(i) / 8.0
			pts.append(c + Vector2((t - 0.5) * 18.0 * s, sin(t * PI) * open))
		draw_colored_polygon(pts, Color(col, 0.25))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, col, 1.6)
		draw_circle(c, minf(open, 2.2 + eye_level * 0.6), col)
		draw_circle(c, 1.2 * s, Color("0d1214"))
	var y := -46.0
	for b: String in badges.slice(0, 2):
		var accent := ThemeFactory.LAMP
		match b:
			"liar": accent = Color("e0533f")
			"death": accent = Color("e0533f")
			"sabotage": accent = Color("e0533f")
		var r := Rect2(MARK_X - 9.0, y - 9.0, 18.0, 18.0)
		draw_rect(r, Color(ThemeFactory.NIGHT, 0.9))
		draw_rect(r, Color(accent, 0.9), false, 1.2)
		match b:
			"street":
				draw_colored_polygon(_ellipse(Vector2(MARK_X - 3.2, y + 2.5), Vector2(2.6, 4.2), 10), ThemeFactory.LAMP)
				draw_colored_polygon(_ellipse(Vector2(MARK_X + 3.2, y - 3.0), Vector2(2.6, 4.2), 10), ThemeFactory.LAMP)
			"liar":
				var hc := ThemeFactory.BONE
				draw_polyline(PackedVector2Array([Vector2(MARK_X - 5.5, y + 5.5), Vector2(MARK_X - 5.5, y - 1), Vector2(MARK_X, y - 6.5),
					Vector2(MARK_X + 5.5, y - 1), Vector2(MARK_X + 5.5, y + 5.5), Vector2(MARK_X - 5.5, y + 5.5)]), hc, 1.6)
				draw_line(Vector2(MARK_X - 7, y + 7), Vector2(MARK_X + 7, y - 7), accent, 2.2)
			"death":
				draw_circle(Vector2(MARK_X, y + 2.5), 4.6, accent)
				draw_colored_polygon(PackedVector2Array([Vector2(MARK_X - 4.2, y + 1), Vector2(MARK_X + 4.2, y + 1), Vector2(MARK_X, y - 7)]), accent)
			"fake":   # пустое ведро
				draw_polyline(PackedVector2Array([Vector2(MARK_X - 5, y - 4), Vector2(MARK_X - 3.6, y + 5.5), Vector2(MARK_X + 3.6, y + 5.5), Vector2(MARK_X + 5, y - 4)]), ThemeFactory.BONE, 1.6)
				draw_arc(Vector2(MARK_X, y - 4), 5.0, PI, TAU, 8, ThemeFactory.BONE, 1.2)
			"tunnel":   # люк
				draw_rect(Rect2(MARK_X - 6, y - 3, 12, 8), Color("8a5a3a"))
				draw_rect(Rect2(MARK_X - 6, y - 3, 12, 8), ThemeFactory.BONE, false, 1.2)
				draw_circle(Vector2(MARK_X + 3, y + 1), 1.4, ThemeFactory.BONE)
			"sabotage":   # трещина
				draw_polyline(PackedVector2Array([Vector2(MARK_X - 1, y - 7), Vector2(MARK_X + 3, y - 2), Vector2(MARK_X - 2.5, y + 1.5), Vector2(MARK_X + 2, y + 7)]), accent, 2.0)
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
	var f := current_face()
	var pose := {"lantern": is_player, "turn": turn * _face, "look": Vector2(turn * _face, 0.0),
		"emote": state == State.SCARED or (_emotion_t > 0.0 and emotion != "" and emotion != "sly")}
	if f == "angry" and _point_dir != 0.0:
		pose["point"] = true
		pose["dir"] = 1.0
	if state == State.RUN:
		pose["walk"] = _walk
		pose["amp"] = 1.0
	if working and tool != "":
		pose["tool"] = tool
		pose["work"] = _work
		pose["hop"] = 0.0
	if cold and f == "cold":
		pose["shiver"] = true
	Folk.figure(body, Vector2.ZERO, S, look, f, pose, Folk.palette(look))


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
