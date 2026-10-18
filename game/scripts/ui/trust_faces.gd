class_name TrustFaces
extends Control
## Доверие группы к игроку (TASK-030) лицами на вечернем собрании: пять голов,
## кто верит — смотрит на тебя, кто нет — отвернулся. Цифры нет: драма остаётся в лицах.

var trust := 3:
	set(v):
		trust = clampi(v, 0, Match.TRUST_MAX)
		queue_redraw()


func _ready() -> void:
	name = "TrustFaces"
	custom_minimum_size = Vector2(0, 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var n := Match.TRUST_MAX
	var r := 17.0
	var gap := 12.0
	var w := n * r * 2.0 + (n - 1) * gap
	var x0 := (size.x - w) * 0.5 + r
	for i in range(n):
		var c := Vector2(x0 + i * (r * 2.0 + gap), size.y * 0.5)
		var looking := i < trust
		var skin := Color(0.86, 0.74, 0.62) if looking else Color(0.45, 0.4, 0.38)
		draw_circle(c + Vector2(0, 2), r + 1.5, Color(0, 0, 0, 0.35))
		draw_circle(c, r, skin)
		if looking:
			# смотрит на тебя: глаза и рот
			draw_circle(c + Vector2(-6, -3), 2.6, Art.INK)
			draw_circle(c + Vector2(6, -3), 2.6, Art.INK)
			draw_line(c + Vector2(-5, 7), c + Vector2(5, 7), Art.INK, 2.0, true)
		else:
			# отвернулся: затылок и волосы, лица не видно
			draw_arc(c, r - 1.0, PI * 1.05, PI * 1.95, 14, Color(0.2, 0.16, 0.14), 7.0, true)
			draw_line(c + Vector2(-r * 0.4, r * 0.55), c + Vector2(r * 0.4, r * 0.55), Color(0, 0, 0, 0.25), 2.0, true)
