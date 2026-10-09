class_name SuppliesBadge
extends Control
## Капсула запасов на поле днём: фонарик, «Запасы 3 из 10» и полоска.
## Чем больше запасов, тем больше фонарей горит ночью и тем легче выжить на улице.
## Касаний не перехватывает — под ней поле.

var done: int = 0
var total: int = 0
var _font: Font
var _bump := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeFactory.font_bold()
	custom_minimum_size = Vector2(250, 58)
	size = custom_minimum_size


func set_value(d: int, t: int) -> void:
	var grew := d > done
	done = d
	total = t
	if grew and not Juice.instant:
		_bump = 1.0
	queue_redraw()


func text() -> String:
	return "Запасы %d из %d" % [done, total]


func _process(delta: float) -> void:
	if _bump > 0.0:
		_bump = maxf(0.0, _bump - delta * 2.5)
		queue_redraw()


func _draw() -> void:
	var s := 1.0 + 0.08 * _bump
	var r := Rect2(Vector2.ZERO, size)
	draw_set_transform(r.get_center() * (1.0 - s), 0.0, Vector2(s, s))
	Art.shape(self, Art.rrect(r, r.size.y * 0.5), Color(0.06, 0.05, 0.1, 0.62), Color(1, 1, 1, 0.18), 1.5)
	# фонарик: горит ярче, когда запасы полнее
	var c := Vector2(30, r.size.y * 0.5)
	var f := float(done) / float(total) if total > 0 else 0.0
	Art.glow(self, c, 26, Color(1.0, 0.8, 0.4, 0.3 + 0.6 * f))
	Art.shape(self, Art.rrect(Rect2(c.x - 9, c.y - 12, 18, 22), 4), Color(1.0, 0.81, 0.42).lerp(Color(0.5, 0.48, 0.55), 1.0 - f), Art.INK, 2.0)
	draw_line(c + Vector2(-9, -5), c + Vector2(9, -5), Art.INK, 1.6)
	draw_line(c + Vector2(0, -17), c + Vector2(0, -12), Art.INK, 2.0)
	draw_string(_font, Vector2(54, 26), text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1))
	var bar := Rect2(54, 35, r.size.x - 72, 9)
	Art.shape(self, Art.rrect(bar, 4.5), Color(1, 1, 1, 0.14), Color(0, 0, 0, 0), 0.0)
	if f > 0.0:
		Art.shape(self, Art.rrect(Rect2(bar.position, Vector2(maxf(9.0, bar.size.x * f), bar.size.y)), 4.5), ThemeFactory.LAMP, Color(0, 0, 0, 0), 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
