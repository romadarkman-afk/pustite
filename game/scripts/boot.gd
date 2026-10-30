extends Control

const LayoutSmoke = preload("res://scripts/tests/layout_smoke.gd")
## Точка входа. Логотип ровно 1 секунду → меню. Тап — пропустить.
## Фон логотипа — картинка заставки (assets/splash.png): Android показывает её, пока грузится движок.
## Самотесты запускаются вручную флагами ниже. Текущий android.yml выполняет короткий smoke-запуск, не полный набор тестов.
## --lang=en рядом с любым самотестом гоняет его на другом языке, --text=2 — с самым крупным текстом.

const TEST_FLAGS: PackedStringArray = ["--sim", "--simchapters", "--chapters", "--story", "--flow", "--layout", "--layout-smoke", "--lifecycle", "--field", "--crowd", "--bubbles", "--marks", "--input", "--hints", "--difficulty", "--howto", "--night", "--eyes", "--lights", "--checkpoint", "--sound", "--village", "--talisman", "--bell", "--events", "--mimic", "--sabotage", "--box", "--roles", "--meeting", "--tunnel", "--diary", "--recap", "--folk", "--loc", "--access", "--daily", "--cosmetics", "--adapt", "--display", "--gestures", "--doors", "--emptying", "--pairs", "--themes", "--soundmaps", "--actscenes", "--campmap", "--achicons", "--parallax", "--traces", "--tension", "--portraits", "--haptics", "--candle", "--storage", "--save", "--weather", "--perf", "--debugmenu", "--release", "--slides", "--voice-assets"]
const TEST_TIMEOUT_SEC := 240.0
const LONG_TEST_TIMEOUT_SEC := 3600.0      ## полная таблица баланса глав
const LAYOUT_TEST_TIMEOUT_SEC := 720.0     ## раскладка: 23 типа экранов и 11 устройств из списка проекта
const LOGO_SEC := 2.4
const SPLASH: Texture2D = preload("res://assets/splash.png")
const MENU_PRELOAD: Array[String] = [
	"res://scripts/ui/screens/menu_screen.gd",
	"res://fonts/Nunito.ttf",
	"res://assets/music/menu_theme.ogg",
]

var _title: Label
var _subtitle: Label
var _shade: GradientTexture2D
var _done := falsevar _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--text="):
			Save.text_size = clampi(int(a.substr(7)), 0, 2)
			ThemeFactory.text_scale = ThemeFactory.TEXT_SCALES[Save.text_size]
			Nav.ui.theme = ThemeFactory.build()
			continue
		if a.begins_with("--csf="):
			SelfTest.csf = clampf(float(a.substr(6)), 0.5, 3.0)    # масштаб интерфейса по плотности экрана: как на телефоне
			continue
		if a.begins_with("--lang="):
			Save.lang = a.substr(7)
			L.use(Save.lang)
			Nav.relocalize()
			continue
		if a.begins_with("--runs=") or a.begins_with("--only=") or a.begins_with("--out=") or a.begins_with("--add=") or a.begins_with("--tune=") or a.begins_with("--diff=") or a == "--grid" or a == "--checks" or a == "--campaign" or a.begins_with("--report="):
			continue                                   # параметры --simchapters
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
	var limit := TEST_TIMEOUT_SEC
	if flag == "--simchapters":
		limit = LONG_TEST_TIMEOUT_SEC
	elif flag == "--layout":
		limit = LAYOUT_TEST_TIMEOUT_SEC
	get_tree().create_timer(limit, true, false, true).timeout.connect(func() -> void:
		print("ИТОГ: ТАЙМАУТ — самотест %s не закончился за %d с" % [flag, int(limit)])
		get_tree().quit(2))
	visible = false
	Save.hints_seen.clear()   # самотесты всегда видят подсказки — и проверяют их раскладку
	Save.howto_seen = true    # «Играть» в самотестах сразу начинает партию; --howto проверяет это отдельно
	Weather.enabled = false   # сезон по дате менял бы кадры от дня к дню; --weather включает погоду сам
	match flag:
		"--sim":
			SelfTest.cli_balance()
		"--simchapters":
			SimChapters.cli()
		"--chapters":
			SimChapters.selftest()
		"--story":
			StoryTests.run()
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
		"--layout-smoke":
			Juice.instant = true
			Nav.start()
			await LayoutSmoke.run()
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
		"--doors":
			Juice.instant = true
			Nav.start()
			await SelfTest.door_styles()
		"--emptying":
			Juice.instant = true
			Nav.start()
			await SelfTest.emptying()
		"--pairs":
			Juice.instant = true
			Nav.start()
			await SelfTest.pairs()
		"--themes":
			Juice.instant = true
			Nav.start()
			await SelfTest.themes()
		"--slides":
			Juice.instant = true
			Nav.start()
			await SlideTests.run()
		"--voice-assets":
			Juice.instant = true
			Nav.start()
			SlideTests.voice_smoke()
		"--soundmaps":
			Juice.instant = true
			Nav.start()
			await SelfTest.soundmaps()
		"--actscenes":
			Juice.instant = true
			Nav.start()
			await SelfTest.actscenes()
		"--campmap":
			Juice.instant = true
			Nav.start()
			await SelfTest.campmap()
		"--achicons":
			Juice.instant = true
			Nav.start()
			await SelfTest.achicons()
		"--parallax":
			Juice.instant = true
			Nav.start()
			await SelfTest.parallax()
		"--traces":
			Juice.instant = true
			Nav.start()
			await SelfTest.traces()
		"--tension":
			Juice.instant = true
			Nav.start()
			await SelfTest.tension()
		"--portraits":
			Juice.instant = true
			Nav.start()
			await SelfTest.portraits()
		"--haptics":
			Juice.instant = true
			Nav.start()
			await SelfTest.haptics()
		"--candle":
			Juice.instant = true
			Nav.start()
			await SelfTest.candle()
		"--storage":
			SelfTest.storage()
		"--save":
			SelfTest.save()
		"--weather":
			Juice.instant = true
			Nav.start()
			await SelfTest.weather()
		"--perf":
			Juice.instant = true
			Nav.start()
			await PerfTests.run()
		"--debugmenu":
			Juice.instant = true
			Nav.start()
			await DebugTests.run()
		"--release":
			ReleaseTests.run()


# ---------------------------------------------------------------
func _play_logo() -> void:
	# Музыка запускается вместе с заставкой. Меню продолжит тот же трек без нового старта.
	Sfx.set_ambience(&"amb_night", 0.25, -32.0)
	for path: String in MENU_PRELOAD:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)
	Sfx.set_music(Sfx.menu_music(), 0.0)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.035, 0.045, 0.085, 0.0),
		Color(0.035, 0.03, 0.075, 0.42),
		Color(0.035, 0.025, 0.065, 0.94),
	])
	_shade = GradientTexture2D.new()
	_shade.gradient = gradient
	_shade.fill_from = Vector2(0.0, 0.0)
	_shade.fill_to = Vector2(0.0, 1.0)

	_title = Label.new()
	_title.text = L.t("game.title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", ThemeFactory.font(900))
	_title.add_theme_font_size_override("font_size", ThemeFactory.fs(48))
	_title.add_theme_color_override("font_color", ThemeFactory.BONE)
	_title.modulate.a = 0.0
	add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = L.t("menu.case_file")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_override("font", ThemeFactory.font(700))
	_subtitle.add_theme_font_size_override("font_size", ThemeFactory.fs(15))
	_subtitle.add_theme_color_override("font_color", ThemeFactory.LAMP)
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)

	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	resized.connect(_place_title)
	_place_title()

	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_title, "modulate:a", 1.0, 0.6)
	t.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.55).set_delay(0.18)
	t.tween_interval(maxf(0.0, LOGO_SEC - 0.75))
	t.tween_callback(_finish)


func _place_title() -> void:
	if _title == null or _subtitle == null:
		return
	var top := -size.y * 0.20
	for label: Label in [_title, _subtitle]:
		label.offset_left = -size.x * 0.46
		label.offset_right = size.x * 0.46
	_title.offset_top = top
	_title.offset_bottom = top + ThemeFactory.fs(60)
	_subtitle.offset_top = top + ThemeFactory.fs(62)
	_subtitle.offset_bottom = top + ThemeFactory.fs(86)


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


## Полноэкранная зимняя сцена. Дверь, люди и силуэты упырей уже в иллюстрации.
func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), ThemeFactory.NIGHT)
	var scale_factor := maxf(size.x / SPLASH.get_width(), size.y / SPLASH.get_height())
	var image_size := SPLASH.get_size() * scale_factor
	draw_texture_rect(SPLASH, Rect2((size - image_size) * 0.5, image_size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.055, 0.10, 0.10))
	if _shade != null:
		draw_texture_rect(_shade, Rect2(0.0, size.y * 0.58, size.x, size.y * 0.42), false)
	var tick := Time.get_ticks_msec() * 0.001
	for i in range(22):
		var x := fposmod(float(i * 131) + tick * float(5 + i % 4), size.x)
		var y := fposmod(float(i * 83) + tick * float(8 + i % 5), size.y)
		draw_circle(Vector2(x, y), 1.0 + float(i % 3) * 0.35, Color(0.88, 0.93, 1.0, 0.18))
