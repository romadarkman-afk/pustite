class_name CandleToggle
extends Button
## TASK-073: свеча в шапке двери. Тап меняет огонь по кругу: обычный, выше, ниже.
## Огонь на кнопке той же высоты, что и в комнате, поэтому состояние видно без текста.

const LEVEL_SCALE: Array[float] = [0.65, 1.0, 1.4]

var level := 0:
	set(v):
		level = clampi(v, -1, 1)
		queue_redraw()
var _time := 0.0


func _init() -> void:
	theme_type_variation = &"Ghost"
	custom_minimum_size = Vector2(ThemeFactory.TOUCH, ThemeFactory.TOUCH)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	draw.connect(_paint)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _paint() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.58)
	var k: float = LEVEL_SCALE[level + 1]
	var wav := sin(_time * 8.1) * 0.10 + sin(_time * 13.7) * 0.06
	var h := 15.0 * k * (1.0 + wav)
	draw_rect(Rect2(c.x - 4.0, c.y, 8.0, 20.0), Color(0.62, 0.52, 0.42))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-5, 1), c + Vector2(-3, -h * 0.55), c + Vector2(wav * 6.0, -h),
		c + Vector2(3, -h * 0.5), c + Vector2(5, 1)]), Color(1.0, 0.55, 0.18, 0.95))
	draw_circle(c + Vector2(0, -2), 2.2, Color(1.0, 0.92, 0.58))
