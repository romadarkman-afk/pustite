class_name DoorCandle
extends Control
## Небольшой огонь у двери. Мерцает одинаково при любом госте.

var _time := 0.0
var _flare := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func flare() -> void:
	_flare = 0.55


func _process(delta: float) -> void:
	_time += delta
	_flare = maxf(0.0, _flare - delta)
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.85, size.y * 0.82)
	var wav := sin(_time * 8.1) * 0.11 + sin(_time * 13.7) * 0.07
	var power := 1.0 + wav + _flare * 0.8
	for i in range(4, 0, -1):
		var radius := (13.0 + float(i) * 13.0) * power
		draw_circle(center, radius, Color(1.0, 0.48, 0.12, 0.012 * float(5 - i)))
	draw_rect(Rect2(center.x - 5.0, center.y + 1.0, 10.0, 26.0), Color(0.16, 0.12, 0.12, 0.95))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-5, 2), center + Vector2(-3, -12 * power),
		center + Vector2(wav * 9, -22 * power), center + Vector2(4, -9 * power),
		center + Vector2(5, 2)]), Color(1.0, 0.55, 0.18, 0.92))
	draw_circle(center + Vector2(0, -3), 2.5, Color(1.0, 0.92, 0.58))
