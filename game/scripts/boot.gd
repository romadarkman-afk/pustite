extends Control
## Точка входа. Логотип ровно 1 секунду → меню. Тап — пропустить.
## Фон логотипа — картинка заставки (assets/splash.png): Android показывает её, пока грузится движок.
## Самотесты запускаются вручную флагами ниже. Текущий android.yml выполняет короткий smoke-запуск, не полный набор тестов.
## --lang=en рядом с любым самотестом гоняет его на другом языке, --text=2 — с самым крупным текстом.

const TEST_FLAGS: PackedStringArray = ["--sim", "--flow", "--layout", "--lifecycle", "--field", "--crowd", "--bubbles", "--marks", "--input", "--hints", "--difficulty", "--howto", "--night", "--eyes", "--lights", "--checkpoint", "--sound", "--village", "--talisman", "--bell", "--events", "--mimic", "--sabotage", "--box", "--roles", "--meeting", "--tunnel", "--diary", "--recap", "--folk", "--loc", "--access", "--daily", "--cosmetics", "--adapt", "--display", "--gestures", "--storage", "--save", "--weather"]
const TEST_TIMEOUT_SEC := 240.0
const LOGO_SEC := 2.2
const SPLASH: Texture2D = preload("res://assets/splash.png")
const MENU_PRELOAD: Array[String] = [
	"res://scripts/ui/screens/menu_screen.gd",
	"res://fonts/Nunito.ttf",
	"res://assets/music/menu_theme.ogg",
]

var open: float = 0.0          ## насколько приоткрыта щель, 0..1
var flash: float = 0.0         ## короткая вспышка фонаря, открывающая силуэт за дверью
var _title: Label
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--text="):
			Save.text_size = clampi(int(a.substr(7)), 0, 2)
			ThemeFactory.text_scale = ThemeFactory.TEXT_SCALES[Save.text_size]
			Nav.ui.theme = ThemeFactory.build()
			continue
		if a.begins_with("--lang="):
			Save.lang = a.substr(7)
			L.use(Save.lang)
			Nav.relocalize()
			continue
		if a.begins_with("--") and not TEST_FLAGS.has(a):
			print("ИТОГ: неизвестный режим %s. Есть: %s" % [a, ", ".join(TEST_FLAGS)])
			get_tree().quit(1)
			return
	for f: String in TEST_FLAGS:
		if args.has(f):
			await _run_test(f)
			return
	_play_logo()


func _run_test(flag: String) -> void:
	get_tree().create_timer(TEST_TIMEOUT_SEC, true, false, true).timeout.connect(func() -> void:
		print("ИТОГ: ТАЙМАУТ — самотест %s не закончился за %d с" % [flag, int(TEST_TIMEOUT_SEC)])
		get_tree().quit(2))
	visible = false
	Save.hints_seen.clear()   # самотесты всегда видят подсказки — и проверяют их раскладку
	Save.howto_seen = true    # «Играть» в самотестах сразу начинает партию; --howto проверяет это отдельно
	Weather.enabled = false   # сезон по дате менял бы кадры от дня к дню; --weather включает погоду сам
	match flag:
		"--sim":
			SelfTest.cli_balance()
		"--loc":
			Juice.instant = true
			Nav.start()
			await SelfTest.loc()
		"--flow":
			Juice.instant = true
			Nav.start()
			await SelfTest.flow()
		"--layout":
			Juice.instant = true
			Nav.start()
			await SelfTest.layout()
		"--lifecycle":
			Juice.instant = true
			Nav.start()
			await SelfTest.lifecycle()
		"--field":
			Juice.instant = true
			Nav.start()
			await SelfTest.field()
		"--crowd":
			Juice.instant = true
			Nav.start()
			await SelfTest.crowd()
		"--bubbles":
			Juice.instant = true
			Nav.start()
			await SelfTest.bubbles()
		"--marks":
			Juice.instant = true
			Nav.start()
			await SelfTest.marks()
		"--input":
			Juice.instant = true
			Nav.start()
			await SelfTest.input()
		"--hints":
			Juice.instant = true
			Nav.start()
			await SelfTest.hints()
		"--difficulty":
			Juice.instant = true
			Nav.start()
			await SelfTest.difficulty()
		"--howto":
			Juice.instant = true
			Nav.start()
			await SelfTest.howto()
		"--night":
			Juice.instant = true
			Nav.start()
			await SelfTest.night()
		"--eyes":
			Juice.instant = true
			Nav.start()
			SelfTest.eyes()
		"--lights":
			Juice.instant = true
			Nav.start()
			SelfTest.lights()
		"--checkpoint":
			Juice.instant = true
			Nav.start()
			await SelfTest.checkpoint()
		"--sound":
			Juice.instant = true
			Nav.start()
			await SelfTest.sound()
		"--village":
			Juice.instant = true
			Nav.start()
			await SelfTest.village()
		"--talisman":
			Juice.instant = true
			Nav.start()
			await SelfTest.talisman()
		"--bell":
			Juice.instant = true
			Nav.start()
			await SelfTest.bell()
		"--events":
			Juice.instant = true
			Nav.start()
			await SelfTest.events()
		"--mimic":
			Juice.instant = true
			Nav.start()
			await SelfTest.mimic()
		"--sabotage":
			Juice.instant = true
			Nav.start()
			await SelfTest.sabotage()
		"--box":
			Juice.instant = true
			Nav.start()
			await SelfTest.box()
		"--roles":
			Juice.instant = true
			Nav.start()
			await SelfTest.roles()
		"--meeting":
			Juice.instant = true
			Nav.start()
			await SelfTest.meeting()
		"--tunnel":
			Juice.instant = true
			Nav.start()
			await SelfTest.tunnel()
		"--diary":
			Juice.instant = true
			Nav.start()
			await SelfTest.diary()
		"--recap":
			Juice.instant = true
			Nav.start()
			await SelfTest.recap()
		"--folk":
			Juice.instant = true
			Nav.start()
			await SelfTest.folk()
		"--access":
			Juice.instant = true
			Nav.start()
			await SelfTest.access()
		"--daily":
			Juice.instant = true
			Nav.start()
			await SelfTest.daily()
		"--cosmetics":
			Juice.instant = true
			Nav.start()
			await SelfTest.cosmetics()
		"--adapt":
			Juice.instant = true
			Nav.start()
			await SelfTest.adapt()
		"--display":
			await SelfTest.display()
		"--gestures":
			Juice.instant = true
			Nav.start()
			await SelfTest.gestures()
		"--storage":
			SelfTest.storage()
		"--save":
			SelfTest.save()
		"--weather":
			Juice.instant = true
			Nav.start()
			await SelfTest.weather()


# ---------------------------------------------------------------
func _play_logo() -> void:
	Sfx.set_ambience(&"amb_dusk", 0.35)
	Sfx.play(&"scratch", randf_range(0.86, 0.98), -16.0)
	for path: String in MENU_PRELOAD:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)
	_title = Label.new()
	_title.text = L.t("game.title")
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
	t.parallel().tween_property(self, "flash", 1.0, 0.06).set_delay(LOGO_SEC * 0.36)
	t.parallel().tween_property(self, "flash", 0.0, 0.46).set_delay(LOGO_SEC * 0.39)
	t.parallel().tween_callback(func() -> void: Sfx.play(&"breath", 0.82, -17.0)).set_delay(LOGO_SEC * 0.56)
	t.parallel().tween_property(_title, "modulate:a", 1.0, LOGO_SEC * 0.4).set_delay(LOGO_SEC * 0.3)
	t.tween_interval(LOGO_SEC * 0.25)
	t.tween_callback(_finish)


func _place_title() -> void:
	if _title == null:
		return
	_title.offset_left = -size.x * 0.5
	_title.offset_right = size.x * 0.5
	_title.offset_top = -size.y * 0.17
	_title.offset_bottom = -size.y * 0.17 + 90


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_finish()
	elif event is InputEventJoypadButton and event.pressed:
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


## Фон — та же ночная деревня, что на заставке при запуске; дверь и щель света рисуются кодом.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ThemeFactory.NIGHT)
	var sk := maxf(size.x / SPLASH.get_width(), size.y / SPLASH.get_height())
	var ss := SPLASH.get_size() * sk
	draw_texture_rect(SPLASH, Rect2((size - ss) * 0.5, ss), false)
	var tick := Time.get_ticks_msec() * 0.001
	var sx := size.x * 0.78
	var sy := size.y * 0.58
	var fw := minf(size.x * 0.12, 92.0)
	var fh := minf(size.y * 0.36, 270.0)
	var shadow_alpha := (0.04 + 0.7 * flash) * open
	# На вспышке в просвете леса на секунду проступает неподвижная фигура.
	draw_colored_polygon(PackedVector2Array([
		Vector2(sx - fw * 0.31, sy - fh * 0.2), Vector2(sx - fw * 0.52, sy + fh * 0.02),
		Vector2(sx - fw * 0.42, sy + fh * 0.48), Vector2(sx - fw * 0.62, sy + fh * 0.5),
		Vector2(sx - fw * 0.48, sy + fh * 0.55), Vector2(sx + fw * 0.5, sy + fh * 0.55),
		Vector2(sx + fw * 0.65, sy + fh * 0.5), Vector2(sx + fw * 0.4, sy + fh * 0.44),
		Vector2(sx + fw * 0.47, sy + fh * 0.02), Vector2(sx + fw * 0.24, sy - fh * 0.2),
	]), Color(0.015, 0.018, 0.03, shadow_alpha))
	draw_circle(Vector2(sx, sy - fh * 0.23), fw * 0.28, Color(0.015, 0.018, 0.03, shadow_alpha))
	draw_circle(Vector2(sx - fw * 0.09, sy - fh * 0.23), maxf(1.5, fw * 0.035), Color(ThemeFactory.BLOOD, flash * 0.9))
	draw_circle(Vector2(sx + fw * 0.09, sy - fh * 0.23), maxf(1.5, fw * 0.035), Color(ThemeFactory.BLOOD, flash * 0.9))
	if flash > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), Color(ThemeFactory.LAMP, flash * 0.045))
	var w := minf(size.x * 0.3, 230.0)
	var h := w * 1.7
	var c := Vector2(size.x * 0.5, size.y * 0.6)
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
	for i in range(18):
		var phase := tick * (0.18 + float(i % 5) * 0.025) + float(i) * 1.71
		var px := c.x + sin(phase) * w * (0.08 + float(i % 4) * 0.045)
		var py := door.position.y + fposmod(float(i) * h / 18.0 - tick * 10.0, h)
		var alpha := (0.12 + 0.18 * (0.5 + 0.5 * sin(phase * 1.6))) * open
		draw_circle(Vector2(px, py), 1.2 + float(i % 3) * 0.35, Color(ThemeFactory.LAMP, alpha))

