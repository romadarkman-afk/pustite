class_name BoltSwipe
extends Control
## TASK-071: засов. Лежит поверх кнопки «Впустить» и открывает дверь жестом: тянешь вбок.
## На середине пути лёгкая вибрация, в конце удар и вибрация сильнее. Отпустил раньше, засов
## возвращается. Тап без движения нажимает кнопку, как раньше, поэтому кнопка и жест дают
## один и тот же результат, а доступность (читалки экрана, клавиатура) остаётся на кнопке.

signal half_way
signal drawn                       ## засов дотянут до конца

const START_PX := 12.0             ## сдвиг, с которого касание становится протяжкой
const DONE_AT := 0.96
const HALF_AT := 0.5
const KNOB := 60.0
const PAD := 6.0

var target: Button
var progress := 0.0                ## 0..1
var dragging := false
var fired := false
var _down := false
var _origin := Vector2.ZERO
var _half_done := false
var _tw: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func travel() -> float:
	return maxf(size.x - KNOB - PAD * 2.0, 1.0)


func _gui_input(event: InputEvent) -> void:
	if target == null or target.disabled or fired:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			_down = true
			dragging = false
			_origin = button.position
			_half_done = false
			if _tw != null and _tw.is_valid():
				_tw.kill()
			accept_event()
		elif _down:
			_down = false
			accept_event()
			if dragging:
				dragging = false
				if not fired:
					_return_back()
			else:
				target.pressed.emit()     # тап: то же, что нажатие кнопки
	elif event is InputEventMouseMotion and _down:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - _origin
		if not dragging and delta.x > START_PX and delta.x > absf(delta.y):
			dragging = true
		if dragging:
			_set_progress(clampf(delta.x / travel(), 0.0, 1.0))
		accept_event()


func _set_progress(value: float) -> void:
	progress = value
	if progress >= HALF_AT and not _half_done:
		_half_done = true
		Juice.haptic(Juice.Haptic.TAP)
		Sfx.play(&"tap", 0.8, -6.0)
		half_way.emit()
	if progress < HALF_AT * 0.8:
		_half_done = false
	if progress >= DONE_AT:
		_fire()
	queue_redraw()


func _fire() -> void:
	if fired:
		return
	fired = true
	dragging = false
	_down = false
	progress = 1.0
	Juice.haptic(Juice.Haptic.KNOCK)
	Sfx.play(&"latch", 1.0, -2.0)
	drawn.emit()
	queue_redraw()
	if is_instance_valid(target):
		target.pressed.emit()


func _return_back() -> void:
	if Juice.instant:
		progress = 0.0
		queue_redraw()
		return
	_tw = create_tween()
	_tw.tween_method(func(v: float) -> void:
		progress = v
		queue_redraw(), progress, 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Сброс после нового построения экрана.
func reset() -> void:
	fired = false
	dragging = false
	_down = false
	progress = 0.0
	queue_redraw()


func _draw() -> void:
	if target == null or target.disabled:
		return
	var h := size.y
	var knob_h := minf(h - PAD * 2.0, KNOB)
	var x := PAD + travel() * progress
	var y := (h - knob_h) * 0.5
	if progress > 0.01:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(ThemeFactory.LAMP.r, ThemeFactory.LAMP.g, ThemeFactory.LAMP.b, 0.28)
		fill.set_corner_radius_all(int(knob_h * 0.5))
		draw_style_box(fill, Rect2(PAD, y, x - PAD + KNOB, knob_h))
	var knob := StyleBoxFlat.new()
	knob.bg_color = Color("3a2f24")
	knob.border_color = ThemeFactory.LAMP
	knob.set_border_width_all(2)
	knob.set_corner_radius_all(int(knob_h * 0.5))
	draw_style_box(knob, Rect2(x, y, KNOB, knob_h))
	# засов: перекладина с двумя скобами и стрелка вправо
	var c := Vector2(x + KNOB * 0.5, h * 0.5)
	draw_line(c + Vector2(-14, 0), c + Vector2(14, 0), ThemeFactory.LAMP, 4.0)
	draw_line(c + Vector2(6, -8), c + Vector2(14, 0), ThemeFactory.LAMP, 3.0)
	draw_line(c + Vector2(6, 8), c + Vector2(14, 0), ThemeFactory.LAMP, 3.0)
