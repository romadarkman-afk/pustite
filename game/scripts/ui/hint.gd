class_name Hint
extends Control
## Подсказка новичку: карточка со стрелкой к месту действия. Касания не перехватывает —
## игрок делает то, о чём она говорит, и она исчезает.
## Без контейнеров и без Label: фон и текст рисуются сами, тем же способом, каким
## считается их размер. Контейнер и Label с переносом считали высоту при нулевой
## ширине и раздувались на два экрана.

const PAD := Vector2(18, 14)
const ARROW := 14.0

const FONT_SIZE := 22

var text: String = ""
var card_rect: Rect2 = Rect2()
var _font: Font
var _text_size := Vector2.ZERO
var _arrow_up := true
var _arrow_x := 0.0
var _t := 0.0


func setup(t: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = t
	_font = ThemeFactory.font(700)
	if not Juice.instant:
		modulate.a = 0.0
		Juice.tween().tween_property(self, "modulate:a", 1.0, 0.35)


## Встать над прямоугольником target (координаты родителя) или под ним, стрелкой к нему.
func place(target: Rect2, width: float, below: bool) -> void:
	var inner := width - PAD.x * 2.0
	_text_size = _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, FONT_SIZE)
	var h := ceilf(_text_size.y) + PAD.y * 2.0
	var parent_w := (get_parent() as Control).size.x
	var x := clampf(target.get_center().x - width * 0.5, 0.0, maxf(0.0, parent_w - width))
	var y := (target.end.y + ARROW) if below else (target.position.y - ARROW - h)
	position = Vector2(x, y - (ARROW if below else 0.0))
	size = Vector2(width, h + ARROW)
	card_rect = Rect2(Vector2(0, ARROW if below else 0.0), Vector2(width, h))
	_arrow_up = below
	_arrow_x = clampf(target.get_center().x - x, 24.0, width - 24.0)
	queue_redraw()


func card_rect_global() -> Rect2:
	return Rect2(global_position + card_rect.position, card_rect.size)


func text_rect_global() -> Rect2:
	return Rect2(global_position + card_rect.position + PAD, _text_size)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if card_rect.size.x <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0f171b")
	sb.border_color = ThemeFactory.LAMP
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, card_rect)
	draw_multiline_string(_font, card_rect.position + PAD + Vector2(0, _font.get_ascent(FONT_SIZE)), text,
		HORIZONTAL_ALIGNMENT_LEFT, card_rect.size.x - PAD.x * 2.0, FONT_SIZE, -1, ThemeFactory.BONE)
	var bob := sin(_t * 4.0) * 2.5
	var c := ThemeFactory.LAMP
	if _arrow_up:
		var top := card_rect.position.y
		draw_colored_polygon(PackedVector2Array([Vector2(_arrow_x - 10, top + 1), Vector2(_arrow_x + 10, top + 1), Vector2(_arrow_x, top - ARROW + 1 + bob)]), c)
	else:
		var bot := card_rect.end.y
		draw_colored_polygon(PackedVector2Array([Vector2(_arrow_x - 10, bot - 1), Vector2(_arrow_x + 10, bot - 1), Vector2(_arrow_x, bot + ARROW - 1 + bob)]), c)
