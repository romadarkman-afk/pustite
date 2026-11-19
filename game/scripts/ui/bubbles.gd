class_name Bubbles
extends Control
## Реплики пузырями над головами говорящих — в экранных координатах, чтобы текст
## был одного читаемого размера на любом телефоне. Пузыри не налезают друг на друга:
## новый поднимается над старыми, а если места в поле нет — уходит самый старый.

const FONT_SIZE := 13        ## компактнее, но учитывает настройку масштаба текста
const NAME_SIZE := 10
const PAD := Vector2(9, 6)
const MAX_ON_SCREEN := 2
const PREVIEW_LINES := 2
const BREAK_FLAGS := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
const GAP := 6.0
const MAX_SHARE := 0.15     ## длинная реплика расширяется, чтобы занимать меньше высоты
const WIDE_SHARE := 0.68     ## ограничивает площадь карты под пузырями
const FADE_IN := 0.18
const FADE_OUT := 0.2

class Bubble:
	var who: String
	var text: String          ## короткая видимая часть
	var full_text: String     ## полная реплика для чтения
	var entry: ChatLine       ## исходная строка журнала
	var mine: bool
	var rect: Rect2
	var anchor: Vector2
	var offset: Vector2 ## исходный отступ от головы; ограничение поля не накапливает дрейф
	var tail_x: float
	var age: float = 0.0
	var life: float = 4.0
	var alpha: float = 0.0
	var dying: bool = false
	var order: int = 0
	var text_w: float = 0.0
	var fig: Node2D            ## кто говорит: пузырь едет за ним и за камерой
	var fsize: int = FONT_SIZE ## размер текста на момент реплики
	var nsize: int = NAME_SIZE

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
func say(who: String, text: String, head: Vector2, mine: bool, fig: Node2D = null, entry: ChatLine = null) -> Bubble:
	if field.size.x <= 0.0:
		return null
	for b: Bubble in bubbles:
		if b.who == who and not b.dying:
			_kill(b)
	var fsz := ThemeFactory.fs(FONT_SIZE)
	var nsz := ThemeFactory.fs(NAME_SIZE)
	var maxw := minf(240.0 * ThemeFactory.text_scale, field.size.x * minf(0.52, 0.44 * ThemeFactory.text_scale))
	var inner := maxf(1.0, maxw - PAD.x * 2.0)
	# На карте показываем до двух строк; целая реплика остаётся в журнале и открывается по нажатию.
	var preview := _preview(text, inner, fsz)
	var ts := _font.get_multiline_string_size(preview, HORIZONTAL_ALIGNMENT_LEFT, inner, fsz, -1, BREAK_FLAGS)
	var nw := _font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, nsz).x
	var w := minf(field.size.x - 8.0, ceilf(maxf(ts.x, nw)) + PAD.x * 2.0)
	var h := ceilf(ts.y) + nsz + 4.0 + PAD.y * 2.0
	var x := clampf(head.x - w * 0.5, field.position.x + 4.0, field.end.x - 4.0 - w)
	var top := field.position.y + 2.0
	var bottom := field.end.y - h - 4.0
	var above := head.y - 12.0 - h
	var below := head.y + 16.0
	var y0 := above if above >= top else (below if below <= bottom else clampf(above, top, bottom))
	var r := Rect2(x, clampf(y0, top, bottom), w, h)
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
	b.text = preview
	b.full_text = text
	b.entry = entry
	b.mine = mine
	b.rect = r
	b.anchor = head
	b.offset = r.position - head
	b.tail_x = clampf(head.x, r.position.x + 14.0, r.end.x - 14.0)
	b.life = clampf(1.8 + 0.045 * text.length(), 2.6, 5.2)
	b.text_w = inner
	b.fsize = fsz
	b.nsize = nsz
	b.fig = fig
	_order += 1
	b.order = _order
	bubbles.append(b)
	while alive().size() > MAX_ON_SCREEN:
		_kill(_oldest())
	queue_redraw()
	return b


## Подбирает границу по реальной ширине шрифта, учитывая переносы и крупный текст.
func _preview(text: String, width: float, font_size: int) -> String:
	var full := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, BREAK_FLAGS)
	var two_lines := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, PREVIEW_LINES, BREAK_FLAGS)
	if full.y <= two_lines.y + 0.5 and full.x <= width + 0.5:
		return text
	var low := 0
	var high := text.length()
	while low < high:
		var middle: int = (low + high + 1) >> 1
		var sample := text.substr(0, middle).strip_edges() + "…"
		var measured := _font.get_multiline_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, BREAK_FLAGS)
		if measured.y <= two_lines.y + 0.5 and measured.x <= width + 0.5:
			low = middle
		else:
			high = middle - 1
	var shown := text.substr(0, low).strip_edges()
	var boundary := maxi(shown.rfind(" "), shown.rfind("\n"))
	if boundary > 0 and shown.length() - boundary <= 10:
		shown = shown.left(boundary).strip_edges()
	return shown + "…"


## Экранные координаты совпадают с координатами поля в Nav.
func bubble_at(point: Vector2) -> Bubble:
	for i in range(bubbles.size() - 1, -1, -1):
		var bubble := bubbles[i]
		if not bubble.dying and bubble.rect.has_point(point):
			return bubble
	return null


## Пузырь сдвинулся за говорящим и наехал на соседа — встать над ним.
## Если сверху места нет, гаснет более старый пузырь: реплика остаётся над говорящим.
func _unstack(b: Bubble) -> void:
	for _attempt in range(4):
		var hit: Bubble = null
		for other: Bubble in bubbles:
			if other != b and not other.dying and other.rect.grow(GAP * 0.5).intersects(b.rect.grow(GAP * 0.5)):
				hit = other
				break
		if hit == null:
			return
		var up := hit.rect.position.y - GAP - b.rect.size.y
		if up >= field.position.y + 2.0:
			b.rect.position.y = up
			b.offset = b.rect.position - b.anchor
		else:
			_kill(b if b.order < hit.order else hit)
			return
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
		if b.fig != null and is_instance_valid(b.fig) and b.fig.has_method("head_global"):
			var h: Vector2 = b.fig.head_global()
			if h.distance_squared_to(b.anchor) > 0.01:
				b.anchor = h
				# Положение пересчитывается от головы и исходного отступа.
				# Clamp больше не сдвигает пузырь навсегда к краю экрана.
				var anchored := h + b.offset
				anchored.x = clampf(anchored.x, field.position.x + 4.0, field.end.x - 4.0 - b.rect.size.x)
				anchored.y = clampf(anchored.y, field.position.y + 2.0, field.end.y - b.rect.size.y - 4.0)
				if anchored.distance_squared_to(b.rect.position) > 0.01:
					b.rect.position = anchored
					_unstack(b)
				b.tail_x = clampf(h.x, b.rect.position.x + 14.0, b.rect.end.x - 14.0)
				changed = true
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
	for b: Bubble in bubbles:
		if b.alpha <= 0.0:
			continue
		var bg := ThemeFactory.MINE if b.mine else ThemeFactory.PANEL_2
		var edge := ThemeFactory.LAMP_D if b.mine else ThemeFactory.EDGE
		var r := b.rect
		var point := b.anchor
		var on_screen := Vector2(
			clampf(point.x, field.position.x, field.end.x),
			clampf(point.y, field.position.y, field.end.y)
		)
		if not r.has_point(on_screen):
			var dx := r.position.x - on_screen.x if on_screen.x < r.position.x else (on_screen.x - r.end.x if on_screen.x > r.end.x else 0.0)
			var dy := r.position.y - on_screen.y if on_screen.y < r.position.y else (on_screen.y - r.end.y if on_screen.y > r.end.y else 0.0)
			var tip := Vector2.ZERO
			var base_a := Vector2.ZERO
			var base_b := Vector2.ZERO
			if absf(dy) >= absf(dx):
				var tx := clampf(on_screen.x, r.position.x + 14.0, r.end.x - 14.0)
				if on_screen.y >= r.end.y:
					tip = Vector2(tx, r.end.y + 8.0)
					base_a = Vector2(tx - 6.0, r.end.y - 1.0)
					base_b = Vector2(tx + 6.0, r.end.y - 1.0)
				else:
					tip = Vector2(tx, r.position.y - 8.0)
					base_a = Vector2(tx - 6.0, r.position.y + 1.0)
					base_b = Vector2(tx + 6.0, r.position.y + 1.0)
			else:
				var ty := clampf(on_screen.y, r.position.y + 10.0, r.end.y - 10.0)
				if on_screen.x >= r.end.x:
					tip = Vector2(r.end.x + 8.0, ty)
					base_a = Vector2(r.end.x - 1.0, ty - 6.0)
					base_b = Vector2(r.end.x - 1.0, ty + 6.0)
				else:
					tip = Vector2(r.position.x - 8.0, ty)
					base_a = Vector2(r.position.x + 1.0, ty - 6.0)
					base_b = Vector2(r.position.x + 1.0, ty + 6.0)
			var link_end := on_screen if point.distance_squared_to(on_screen) > 0.01 else point
			draw_colored_polygon(PackedVector2Array([base_a, base_b, tip]), Color(bg, 0.72 * b.alpha))
			draw_line(tip, link_end, Color(edge, 0.58 * b.alpha), 1.5)
		if point.x < field.position.x or point.x > field.end.x:
			var left := point.x < field.position.x
			var ax := r.position.x - 2.0 if left else r.end.x + 2.0
			var ay := clampf(on_screen.y, r.position.y + 8.0, r.end.y - 8.0)
			var direction := -1.0 if left else 1.0
			draw_colored_polygon(PackedVector2Array([Vector2(ax, ay - 7.0), Vector2(ax, ay + 7.0), Vector2(ax + direction * 9.0, ay)]), Color(edge, b.alpha))
	for b: Bubble in bubbles:
		var a := b.alpha
		if a <= 0.0:
			continue
		var s := 0.9 + 0.1 * a
		var c := b.rect.get_center()
		draw_set_transform(c - c * s, 0.0, Vector2(s, s))
		var bg := ThemeFactory.MINE if b.mine else ThemeFactory.PANEL_2
		var edge := ThemeFactory.LAMP_D if b.mine else ThemeFactory.EDGE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(bg, 0.72 * a)
		sb.border_color = Color(edge, 0.82 * a)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		draw_style_box(sb, b.rect)
		var x := b.rect.position.x + PAD.x
		var y := b.rect.position.y + PAD.y
		draw_string(_font, Vector2(x, y + _font.get_ascent(b.nsize)), b.who, HORIZONTAL_ALIGNMENT_LEFT, -1, b.nsize,
			Color(ThemeFactory.LAMP if b.mine else ThemeFactory.LAMP_D, a))
		draw_multiline_string(_font, Vector2(x, y + b.nsize + 4.0 + _font.get_ascent(b.fsize)), b.text,
			HORIZONTAL_ALIGNMENT_LEFT, b.text_w, b.fsize, -1, Color(ThemeFactory.BONE, a), BREAK_FLAGS)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
