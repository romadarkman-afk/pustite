class_name SuppliesBadge
extends Control
## Капсула дневных запасов: выполненные дела с водой, дровами, маслом и рыбой.
## Кнопка рядом показывает, как каждый припас влияет на ночь и настроение жителей.
## Кнопка справа отвечает за пояснение, сама шкала показывает ход работы.

var done: int = 0
var total: int = 0
var _font: Font
var _bump := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeFactory.font_bold()
	custom_minimum_size = Vector2(220, 50)
	size = custom_minimum_size


func set_value(d: int, t: int) -> void:
	var grew := d > done
	done = d
	total = t
	if grew and not Juice.instant:
		_bump = 1.0
	queue_redraw()


func text() -> String:
	return L.t("supplies", {"a": done, "b": total})


func _process(delta: float) -> void:
	if _bump > 0.0:
		_bump = maxf(0.0, _bump - delta * 2.5)
		queue_redraw()


func _draw() -> void:
	var s := 1.0 + 0.06 * _bump
	var r := Rect2(Vector2.ZERO, size)
	draw_set_transform(r.get_center() * (1.0 - s), 0.0, Vector2(s, s))
	Art.shape(self, Art.rrect(r, r.size.y * 0.5), Color(0.06, 0.05, 0.1, 0.62), Color(1, 1, 1, 0.18), 1.5)
	# Значок и подпись сохраняют пропорции на узком экране.
	var c := Vector2(25, r.size.y * 0.5)
	var f := float(done) / float(total) if total > 0 else 0.0
	Art.glow(self, c, 21, Color(1.0, 0.8, 0.4, 0.25 + 0.55 * f))
	Art.shape(self, Art.rrect(Rect2(c.x - 8, c.y - 10, 16, 19), 4), Color(1.0, 0.81, 0.42).lerp(Color(0.5, 0.48, 0.55), 1.0 - f), Art.INK, 1.8)
	draw_line(c + Vector2(-8, -4), c + Vector2(8, -4), Art.INK, 1.4)
	draw_line(c + Vector2(0, -14), c + Vector2(0, -10), Art.INK, 1.8)
	var fs := maxi(12, roundi(16.0 * ThemeFactory.text_scale))
	var label := text()
	var max_text_width := r.size.x - 64.0
	while fs > 12 and _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_text_width:
		fs -= 1
	draw_string(_font, Vector2(46, 23), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
	var bar := Rect2(46, 30, r.size.x - 60, 7)
	Art.shape(self, Art.rrect(bar, 3.5), Color(1, 1, 1, 0.14), Color(0, 0, 0, 0), 0.0)
	if f > 0.0:
		Art.shape(self, Art.rrect(Rect2(bar.position, Vector2(maxf(7.0, bar.size.x * f), bar.size.y)), 3.5), ThemeFactory.LAMP, Color(0, 0, 0, 0), 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
