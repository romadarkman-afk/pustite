class_name ScreenHost
extends Control
## Держит текущий экран и меняет экраны с переходом. Не контейнер —
## поэтому экран внутри можно трясти и сдвигать без борьбы с раскладкой.

var current: Screen


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_screen(s: Screen) -> void:
	var old := current
	current = s
	add_child(s)
	if old != null:
		old.lock()
		if Juice.instant:
			old.queue_free()
		else:
			var out := Juice.tween()
			out.tween_property(old, "modulate:a", 0.0, 0.14)
			out.tween_callback(old.queue_free)
	if not Juice.instant:
		s.modulate.a = 0.0
		s.position = Vector2(0, 22)
		var t := Juice.tween().set_parallel(true)
		t.tween_property(s, "modulate:a", 1.0, 0.3).set_delay(0.08)
		t.tween_property(s, "position", Vector2.ZERO, 0.38).set_delay(0.08)
