extends Control
## Точка входа. Логотип ровно 1 секунду → меню. Тап — пропустить.
## Для сборки здесь же запускаются самотесты: --sim, --flow, --layout, --lifecycle, --field, --crowd, --bubbles, --marks, --input, --hints, --difficulty, --howto, --night, --sound.

const TEST_FLAGS: PackedStringArray = ["--sim", "--flow", "--layout", "--lifecycle", "--field", "--crowd", "--bubbles", "--marks", "--input", "--hints", "--difficulty", "--howto", "--night", "--sound"]
const TEST_TIMEOUT_SEC := 240.0
const LOGO_SEC := 1.0

var open: float = 0.0          ## насколько приоткрыта щель, 0..1
var _title: Label
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--") and not TEST_FLAGS.has(a):
			print("ИТОГ: неизвестный режим %s. Есть: %s" % [a, ", ".join(TEST_FLAGS)])
			get_tree().quit(1)
			return
	for f: String in TEST_FLAGS:
		if args.has(f):
			_run_test(f)
			return
	_play_logo()


func _run_test(flag: String) -> void:
	get_tree().create_timer(TEST_TIMEOUT_SEC, true, false, true).timeout.connect(func() -> void:
		print("ИТОГ: ТАЙМАУТ — самотест %s не закончился за %d с" % [flag, int(TEST_TIMEOUT_SEC)])
		get_tree().quit(2))
	visible = false
	Save.hints_seen.clear()   # самотесты всегда видят подсказки — и проверяют их раскладку
	Save.howto_seen = true    # «Играть» в самотестах сразу начинает партию; --howto проверяет это отдельно
	match flag:
		"--sim":
			SelfTest.cli_balance()
		"--flow":
			Juice.instant = true
			Nav.start()
			SelfTest.flow()
		"--layout":
			Juice.instant = true
			Nav.start()
			SelfTest.layout()
		"--lifecycle":
			Juice.instant = true
			Nav.start()
			SelfTest.lifecycle()
		"--field":
			Juice.instant = true
			Nav.start()
			SelfTest.field()
		"--crowd":
			Juice.instant = true
			Nav.start()
			SelfTest.crowd()
		"--bubbles":
			Juice.instant = true
			Nav.start()
			SelfTest.bubbles()
		"--marks":
			Juice.instant = true
			Nav.start()
			SelfTest.marks()
		"--input":
			Juice.instant = true
			Nav.start()
			SelfTest.input()
		"--hints":
			Juice.instant = true
			Nav.start()
			SelfTest.hints()
		"--difficulty":
			Juice.instant = true
			Nav.start()
			SelfTest.difficulty()
		"--howto":
			Juice.instant = true
			Nav.start()
			SelfTest.howto()
		"--night":
			Juice.instant = true
			Nav.start()
			SelfTest.night()
		"--sound":
			Juice.instant = true
			Nav.start()
			SelfTest.sound()


# ---------------------------------------------------------------
func _play_logo() -> void:
	_title = Label.new()
	_title.text = "Пустите"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var f := ThemeFactory.font(900)
	_title.add_theme_font_override("font", f)
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", ThemeFactory.BONE)
	_title.modulate.a = 0.0
	add_child(_title)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	resized.connect(_place_title)
	_place_title()

	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "open", 1.0, LOGO_SEC * 0.55)
	t.parallel().tween_callback(func() -> void:
		Juice.haptic(Juice.Haptic.KNOCK)
		Sfx.play(&"knock")).set_delay(LOGO_SEC * 0.15)
	t.parallel().tween_property(_title, "modulate:a", 1.0, LOGO_SEC * 0.4).set_delay(LOGO_SEC * 0.3)
	t.tween_interval(LOGO_SEC * 0.25)
	t.tween_callback(_finish)


func _place_title() -> void:
	if _title == null:
		return
	_title.offset_left = -size.x * 0.5
	_title.offset_right = size.x * 0.5
	_title.offset_top = -size.y * 0.24
	_title.offset_bottom = -size.y * 0.24 + 90


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Diag.step("логотип отыграл")
	Nav.start()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


## Дверь и щель света — всё рисуется кодом.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ThemeFactory.NIGHT)
	var w := minf(size.x * 0.34, 260.0)
	var h := w * 1.7
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	var door := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var flick := 0.92 + 0.08 * sin(Time.get_ticks_msec() * 0.011)

	for i in range(14):
		var k := 1.0 - i / 14.0
		var r := (w * 0.15 + i * w * 0.07) * open
		draw_rect(Rect2(c.x - r, door.position.y, r * 2.0, h),
			Color(ThemeFactory.LAMP, 0.035 * k * open * flick))

	draw_rect(door, ThemeFactory.PANEL)
	var gap := 3.0 + 9.0 * open
	draw_rect(Rect2(c.x - gap * 0.5, door.position.y, gap, h), Color(ThemeFactory.LAMP, open * flick))
	draw_rect(Rect2(c.x - gap * 1.6, door.position.y, gap * 3.2, h), Color(ThemeFactory.LAMP, 0.25 * open * flick))
	draw_rect(door, ThemeFactory.EDGE, false, 3.0)
	draw_circle(Vector2(c.x + w * 0.32, c.y + h * 0.06), w * 0.035, ThemeFactory.LAMP_D)
