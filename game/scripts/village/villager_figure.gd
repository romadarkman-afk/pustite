class_name VillagerFigure
extends Node2D
## Житель на площади. Тело рисуется кодом в отдельном узле — его сжимает и растягивает
## анимация, а имя под ногами остаётся ровным. Дыхание и подпрыгивания — через трансформ,
## без перерисовки: перерисовка только при смене состояния и на моргании.

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

const MARK_X := 24.0       ## колонка отметок справа от головы


func setup(name: String, l: LookDef, player: bool) -> void:
	who = name
	look = l
	is_player = player
	_font = load("res://fonts/UI.ttf")
	_phase = float(absi(name.hash()) % 628) / 100.0
	_blink_in = 1.0 + fmod(_phase, 3.0)
	body = Node2D.new()
	add_child(body)
	body.draw.connect(_draw_body)
	if player:
		var g := Sprite2D.new()
		g.texture = _soft()
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = add
		g.position = Vector2(12, -15)
		g.scale = Vector2(0.75, 0.75)
		g.modulate = Color(ThemeFactory.LAMP, 0.55)
		body.add_child(g)


const LABEL_SIZE := 13


func body_scale() -> Vector2:
	return body.scale


## Прямоугольники для раскладки и самотестов, в координатах фигурки.
func label_width() -> float:
	return _font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x


func label_rect_local() -> Rect2:
	var w := label_width()
	return Rect2(-w * 0.5, 5, w, 15)


func body_rect_local() -> Rect2:
	var h := look.height if look != null else 1.0
	var extra := 26.0 if highlight else 0.0
	return Rect2(-14, -54 * h - extra, 28 + MARK_X, 56 * h + extra)


func set_highlight(on: bool) -> void:
	highlight = on
	queue_redraw()


## Где стрелка метки «Вы» — для самотестов, в координатах экрана.
func marker_rect_global() -> Rect2:
	var h := look.height if look != null else 1.0
	return _global_rect(Rect2(-9, -54 * h - 26, 18, 16))


## Зона касания в координатах экрана: не меньше 84×108 px (≈ 48 dp), даже если фигурка мелкая.
func hit_rect_global() -> Rect2:
	var c := get_global_transform_with_canvas() * Vector2(4, -26)
	var sc := get_global_transform_with_canvas().get_scale().x
	var half := Vector2(maxf(42.0, 30.0 * sc), maxf(54.0, 40.0 * sc))
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
	return get_global_transform_with_canvas() * Vector2(0, -56.0 * h)


func label_rect_global() -> Rect2:
	return _global_rect(label_rect_local())


func body_rect_global() -> Rect2:
	return _global_rect(body_rect_local())


# =============================================================
# Состояния
# =============================================================
func run_to(target: Vector2, dur: float = 0.75) -> void:
	if state == State.DEAD or state == State.GONE:
		return
	if _tw != null:
		_tw.kill()
	if Juice.instant:
		position = target
		_settle_idle()
		arrived.emit()
		return
	state = State.RUN
	_face = -1.0 if target.x < position.x else 1.0
	_tw = create_tween()
	_tw.tween_property(body, "scale", Vector2(_face * 1.2, 0.8), 0.08)
	_tw.tween_property(body, "scale", Vector2(_face * 0.88, 1.14), 0.1)
	_tw.parallel().tween_property(self, "position", target, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(body, "scale", Vector2(_face * 1.22, 0.78), 0.07)
	_tw.tween_property(body, "scale", Vector2(_face, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(func() -> void:
		_settle_idle()
		arrived.emit())


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
	match state:
		State.IDLE:
			var s := sin(_t * 1.7 + _phase)
			body.scale = Vector2(_face * (1.0 - 0.02 * s), 1.0 + 0.03 * s)
			_blink_in -= delta
			if _blink_in <= 0.0:
				_eyes_closed = not _eyes_closed
				_blink_in = 0.12 if _eyes_closed else 2.2 + fmod(_t * 0.37 + _phase, 2.5)
				body.queue_redraw()
		State.RUN:
			body.position.y = -absf(sin(_t * 15.0)) * 3.5
		State.SCARED:
			body.position.x = sin(_t * 46.0) * 1.5


# =============================================================
# Рисование
# =============================================================
func _draw() -> void:
	if state == State.GONE:
		return
	draw_colored_polygon(_ellipse(Vector2(0, 2), Vector2(12, 4)), Color(0, 0, 0, 0.32))
	if state == State.DEAD:
		var stone := Color("4d585d")
		draw_rect(Rect2(-8, -17, 16, 17), stone)
		draw_circle(Vector2(0, -17), 8.0, stone)
		draw_line(Vector2(0, -22), Vector2(0, -8), Color("2a3236"), 2.0)
		draw_line(Vector2(-4, -17), Vector2(4, -17), Color("2a3236"), 2.0)
	if state != State.DEAD:
		_draw_marks()
	if highlight and state != State.DEAD:
		var p := 0.5 + 0.5 * sin(_t * 4.0)
		var ring := _ellipse(Vector2(0, 2), Vector2(19.0 + 4.0 * p, 7.0 + 1.5 * p), 26)
		ring.append(ring[0])
		draw_polyline(ring, Color(ThemeFactory.LAMP, 0.45 + 0.45 * p), 2.5)
		var hh := look.height if look != null else 1.0
		var y0 := -54.0 * hh - 12.0 + 3.0 * sin(_t * 5.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-9, y0 - 12), Vector2(9, y0 - 12), Vector2(0, y0)]), ThemeFactory.LAMP)
	var col := ThemeFactory.LAMP if is_player else Color(ThemeFactory.BONE, 0.9 if state != State.DEAD else 0.45)
	draw_string(_font, Vector2(-55, 17), who, HORIZONTAL_ALIGNMENT_CENTER, 110, LABEL_SIZE, Color(0, 0, 0, 0.65))
	draw_string(_font, Vector2(-55, 16), who, HORIZONTAL_ALIGNMENT_CENTER, 110, LABEL_SIZE, col)


const EYE_COLORS := [Color(0, 0, 0, 0), Color("8fa3ab"), Color("d9a24e"), Color("d0683a"), Color("c23a33")]


func _draw_marks() -> void:
	if pact:
		var ring := _ellipse(Vector2(0, 2), Vector2(17, 6.5), 22)
		ring.append(ring[0])
		draw_polyline(ring, Color(ThemeFactory.LAMP, 0.85), 2.0)
	var bg := Color(ThemeFactory.NIGHT, 0.8)
	if eye_level > 0:
		var c := Vector2(MARK_X, -44)
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
	var y := -25.0
	for b: String in badges.slice(0, 2):
		var accent := ThemeFactory.LAMP
		match b:
			"liar": accent = Color("e0533f")
			"death": accent = Color("e0533f")
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
		y += 19.0


func _draw_body() -> void:
	var h := look.height
	var dark := Color("1b2125")
	var coat := look.coat
	# ноги
	body.draw_rect(Rect2(-6, -10 * h, 4, 10 * h), dark)
	body.draw_rect(Rect2(2, -10 * h, 4, 10 * h), dark)
	# руки
	body.draw_line(Vector2(-8, -27 * h), Vector2(-12, -14 * h), coat.darkened(0.25), 4.0)
	body.draw_line(Vector2(8, -27 * h), Vector2(12, -14 * h), coat.darkened(0.25), 4.0)
	# пальто
	body.draw_colored_polygon(PackedVector2Array([Vector2(-11, -8 * h), Vector2(11, -8 * h), Vector2(9, -28 * h),
		Vector2(5, -32 * h), Vector2(-5, -32 * h), Vector2(-9, -28 * h)]), coat)
	body.draw_line(Vector2(0, -30 * h), Vector2(0, -9 * h), coat.darkened(0.3), 1.5)
	# шарф
	body.draw_rect(Rect2(-6, -32 * h, 12, 4), look.accent)
	var hy := -39.0 * h
	if look.head == LookDef.Head.HOOD:
		body.draw_circle(Vector2(0, hy - 1), 9.5, coat.darkened(0.15))
	# голова
	body.draw_circle(Vector2(0, hy), 7.0, look.skin)
	match look.head:
		LookDef.Head.BARE:
			body.draw_colored_polygon(_arc(Vector2(0, hy - 1), 7.4), look.hair)
		LookDef.Head.CAP:
			body.draw_colored_polygon(_arc(Vector2(0, hy - 1), 7.4), look.hair)
			body.draw_rect(Rect2(-8, hy - 9, 16, 5), look.accent.darkened(0.35))
			body.draw_rect(Rect2(-2, hy - 5, 11, 2), look.accent.darkened(0.5))
		LookDef.Head.SCARF:
			body.draw_colored_polygon(PackedVector2Array([Vector2(-8.5, hy + 3), Vector2(-7, hy - 6), Vector2(0, hy - 10),
				Vector2(7, hy - 6), Vector2(8.5, hy + 3), Vector2(6, hy - 2), Vector2(-6, hy - 2)]), look.accent)
		LookDef.Head.HAT:
			body.draw_rect(Rect2(-10, hy - 6, 20, 3), dark)
			body.draw_rect(Rect2(-6, hy - 14, 12, 9), dark)
			body.draw_rect(Rect2(-6, hy - 8, 12, 2), look.accent)
		LookDef.Head.HOOD:
			pass
	# глаза
	var eye := Color("161a1c")
	if state == State.SCARED:
		body.draw_circle(Vector2(-2.6, hy), 1.7, eye)
		body.draw_circle(Vector2(2.6, hy), 1.7, eye)
		body.draw_circle(Vector2(0, hy + 3.5), 1.2, eye)
	elif _eyes_closed:
		body.draw_line(Vector2(-3.8, hy), Vector2(-1.4, hy), eye, 1.2)
		body.draw_line(Vector2(1.4, hy), Vector2(3.8, hy), eye, 1.2)
	else:
		body.draw_circle(Vector2(-2.6, hy), 1.1, eye)
		body.draw_circle(Vector2(2.6, hy), 1.1, eye)
	# фонарь у игрока
	if is_player:
		body.draw_line(Vector2(12, -14 * h), Vector2(12, -19), dark, 1.5)
		body.draw_rect(Rect2(9, -19, 6, 8), dark)
		body.draw_rect(Rect2(10, -18, 4, 6), ThemeFactory.LAMP)


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
