class_name Scrim
extends Control
## Затемнение под игровым полем: текст и кнопки внизу читаются поверх земли посёлка.
## Верхний край — мягкий градиент, чтобы поле не обрезалось жёсткой линией.

const FADE := 80.0

var top: float = 0.0: set = _set_top
var strength: float = 0.0: set = _set_strength


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_top(v: float) -> void:
	top = v
	queue_redraw()


func _set_strength(v: float) -> void:
	strength = v
	queue_redraw()


func _draw() -> void:
	if strength <= 0.01:
		return
	var c := Color(ThemeFactory.NIGHT, 0.94 * strength)
	var clear := Color(c, 0.0)
	var y0 := top - FADE
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, top), Vector2(0, top)]),
		PackedColorArray([clear, clear, c, c]))
	draw_rect(Rect2(0, top, size.x, maxf(0.0, size.y - top)), c)
