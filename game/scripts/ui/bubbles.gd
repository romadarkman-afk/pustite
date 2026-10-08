class_name Bubbles
extends Control
## Реплики пузырями над головами говорящих — в экранных координатах, чтобы текст
## был одного читаемого размера на любом телефоне. Пузыри не налезают друг на друга:
## новый поднимается над старыми, а если места в поле нет — уходит самый старый.

const FONT_SIZE := 19
const NAME_SIZE := 15
const PAD := Vector2(12, 8)
const MAX_ON_SCREEN := 3
const GAP := 6.0
const FADE_IN := 0.18
const FADE_OUT := 0.2

class Bubble:
	var who: String
	var text: String
	var mine: bool
	var rect: Rect2
	var anchor: Vector2
	var tail_x: float
	var age: float = 0.0
	var life: float = 4.0
	var alpha: float = 0.0
	var dying: bool = false
	var order: int = 0
	var text_w: float = 0.0

var field: Rect2 = Rect2()
var bubbles: Array[Bubble] = []
var _font: Font
var _order := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeFactory.font_bold()


func clear() -> void:
	bubbles.clear()
	queue_redraw()


func alive() -> Array[Bubble]:
	var out: Array[Bubble] = []
	for b: Bubble in bubbles:
		if not b.dying:
			out.append(b)
	return out


## Новая реплика. head — точка над головой говорящего в координатах экрана.
func say(who: String, text: String, head: Vector2, mine: bool) -> Bubble:
	if field.size.x <= 0.0:
		return null
	for b: Bubble in bubbles:
		if b.who == who and not b.dying:
			_kill(b)
	var maxw := minf(330.0, field.size.x * 0.56)
	var inner := maxw - PAD.x * 2.0
	var ts := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, FONT_SIZE)
	var nw := _font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	var w := ceilf(maxf(ts.x, nw)) + PAD.x * 2.0
	var h := ceilf(ts.y) + NAME_SIZE + 4.0 + PAD.y * 2.0
	var x := clampf(head.x - w * 0.5, field.position.x + 4.0, field.end.x - 4.0 - w)
	var y0 := minf(head.y - 12.0 - h, field.end.y - h - 4.0)
	var r := Rect2(x, maxf(y0, field.position.y + 2.0), w, h)
	for attempt in range(8):
		var hit := _first_overlap(r)
		if hit == null:
			break
		r.position.y = hit.rect.position.y - GAP - h
		if r.position.y < field.position.y + 2.0:
			_kill(_oldest())
			r.position.y = maxf(y0, field.position.y + 2.0)
	var hit2 := _first_overlap(r)
	while hit2 != null:
		_kill(hit2)
		hit2 = _first_overlap(r)
	var b := Bubble.new()
	b.who = who
	b.text = text
	b.mine = mine
	b.rect = r
	b.anchor = head
	b.tail_x = clampf(head.x, r.position.x + 14.0, r.end.x - 14.0)
	b.life = clampf(2.2 + 0.055 * text.length(), 3.0, 7.0)
	b.text_w = inner
	_order += 1
	b.order = _order
	bubbles.append(b)
	while alive().size() > MAX_ON_SCREEN:
		_kill(_oldest())
	queue_redraw()
	return b


func _first_overlap(r: Rect2) -> Bubble:
	for b: Bubble in bubbles:
		if not b.dying and b.rect.grow(GAP * 0.5).intersects(r.grow(GAP * 0.5)):
			return b
	return null


func _oldest() -> Bubble:
	var best: Bubble = null
	for b: Bubble in bubbles:
		if not b.dying and (best == null or b.order < best.order):
			best = b
	return best


func _kill(b: Bubble) -> void:
	if b != null:
		b.dying = true
		queue_redraw()


## Время идёт — пузыри появляются, живут и гаснут. Самотесты зовут напрямую.
func tick(delta: float) -> void:
	if bubbles.is_empty():
		return
	var changed := false
	for b: Bubble in bubbles:
		b.age += delta
		if not b.dying and b.age >= b.life:
			b.dying = true
		var target := 0.0 if b.dying else 1.0
		var step := delta / (FADE_OUT if b.dying else FADE_IN)
		var na := move_toward(b.alpha, target, step)
		if na != b.alpha:
			b.alpha = na
			changed = true
	var before := bubbles.size()
	bubbles = bubbles.filter(func(b: Bubble) -> bool: return not (b.dying and b.alpha <= 0.0))
	if changed or bubbles.size() != before:
		queue_redraw()


func _process(delta: float) -> void:
	tick(delta)


func _draw() -> void:
	# сначала все указатели — чтобы ни один не перечёркивал чужой пузырь
	for b: Bubble in bubbles:
		var tip0 := Vector2(b.tail_x, b.rect.end.y + 9.0)
		if b.alpha > 0.0 and b.anchor.y - tip0.y > 10.0:
			var edge0 := ThemeFactory.LAMP_D if b.mine else ThemeFactory.EDGE
			draw_line(tip0, Vector2(b.tail_x + (b.anchor.x - b.tail_x) * 0.2, b.anchor.y - 4.0), Color(edge0, 0.7 * b.alpha), 1.5)
	for b: Bubble in bubbles:
		var a := b.alpha
		if a <= 0.0:
			continue
		var s := 0.9 + 0.1 * a
		var c := b.rect.get_center()
		draw_set_transform(c - c * s, 0.0, Vector2(s, s))
		var bg := Color("20302a") if b.mine else ThemeFactory.PANEL_2
		var edge := ThemeFactory.LAMP_D if b.mine else ThemeFactory.EDGE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(bg, 0.96 * a)
		sb.border_color = Color(edge, a)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		var tip := Vector2(b.tail_x, b.rect.end.y + 9.0)
		draw_colored_polygon(PackedVector2Array([Vector2(b.tail_x - 7, b.rect.end.y - 1), Vector2(b.tail_x + 7, b.rect.end.y - 1), tip]), Color(bg, 0.96 * a))
		draw_style_box(sb, b.rect)
		var x := b.rect.position.x + PAD.x
		var y := b.rect.position.y + PAD.y
		draw_string(_font, Vector2(x, y + _font.get_ascent(NAME_SIZE)), b.who, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE,
			Color(ThemeFactory.LAMP if b.mine else ThemeFactory.LAMP_D, a))
		draw_multiline_string(_font, Vector2(x, y + NAME_SIZE + 4.0 + _font.get_ascent(FONT_SIZE)), b.text,
			HORIZONTAL_ALIGNMENT_LEFT, b.text_w, FONT_SIZE, -1, Color(ThemeFactory.BONE, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
