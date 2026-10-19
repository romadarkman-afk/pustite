class_name LivingPortrait
extends TextureRect
## Очень лёгкое движение портрета. Размер виджета остаётся постоянным.

var state: String = ""
var active := true
var _time := 0.0


func _process(delta: float) -> void:
	if not active or texture == null:
		return
	_time += delta
	pivot_offset = size * 0.5
	var breath := 1.0 + 0.008 * sin(_time * 1.8)
	scale = Vector2(breath, 1.0 + 0.012 * sin(_time * 1.8))
	rotation = -0.035 if state == "grief" or state == "despair" else 0.0
	if state == "fear":
		position.x = sin(_time * 13.0) * 1.2
	else:
		position.x = 0.0
