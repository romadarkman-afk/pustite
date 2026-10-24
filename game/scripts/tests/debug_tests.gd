class_name DebugTests
extends RefCounted
## TASK-096: скрытое отладочное меню. Пять тапов по версии в настройках открывают его, переход к главе
## работает без прохождения предыдущих, прогресс кампании от открытия меню не меняется.


static func _tap(label: Label) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	label.gui_input.emit(ev)


static func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var fails := PackedStringArray()
	var ok := 0

	# 1. счётчик тапов
	var quick := DebugScreen.TapCounter.new()
	for i in range(4):
		ok += SelfTest._expect(fails, not quick.hit(10000 + i * 400), "тап %d открыл меню раньше пятого" % (i + 1))
	ok += SelfTest._expect(fails, quick.hit(11600), "пятый быстрый тап не открыл меню")
	ok += SelfTest._expect(fails, not quick.hit(11700), "после открытия счётчик не сброшен")
	var slow := DebugScreen.TapCounter.new()
	var opened_slow := false
	for i in range(8):
		opened_slow = opened_slow or slow.hit(i * 1000)
	ok += SelfTest._expect(fails, not opened_slow, "тапы раз в секунду открыли меню: окно %d мс" % DebugScreen.TAP_WINDOW_MSEC)

	# 2. настройки → меню
	ok += SelfTest._expect(fails, DebugScreen.available(), "самотест идёт не в отладочной сборке")
	Save.campaign_stars.clear()
	Nav.show_settings()
	await SelfTest._settle(tree)
	ok += SelfTest._expect(fails, Nav.host.current is SettingsScreen, "нет экрана настроек")
	var version := Nav.host.current.find_child("Version", true, false) as Label
	ok += SelfTest._expect(fails, version != null and version.text.begins_with("v"), "в настройках нет строки версии")
	if version == null:
		SelfTest._finish(fails, ok, "ОТЛАДКА", "")
		return
	ok += SelfTest._expect(fails, version.text.begins_with("v%s" % ProjectSettings.get_setting("application/config/version", "?")), "версия в настройках «%s» не совпала с проектом" % version.text)
	# «Об игре»: по нажатию раскрываются авторы звука и шрифты (аудит F-17), повторное нажатие сворачивает
	var about := Nav.host.current.find_child("AboutToggle", true, false) as Button
	ok += SelfTest._expect(fails, about != null and Nav.host.current.find_child("AboutText", true, false) == null, "в настройках нет свёрнутой кнопки «Об игре»")
	if about != null:
		about.pressed.emit()
		await SelfTest._frames(tree, 3)
		var about_text := Nav.host.current.find_child("AboutText", true, false) as Label
		ok += SelfTest._expect(fails, about_text != null and about_text.text.contains("OpenGameArt") and about_text.text.contains("rubberduck")
			and about_text.text.contains("Nunito"), "в «Об игре» нет авторов звука или шрифтов")
		(Nav.host.current.find_child("AboutToggle", true, false) as Button).pressed.emit()
		await SelfTest._frames(tree, 3)
		ok += SelfTest._expect(fails, Nav.host.current.find_child("AboutText", true, false) == null, "«Об игре» не свернулась")
		version = Nav.host.current.find_child("Version", true, false) as Label
	for i in range(4):
		_tap(version)
	await SelfTest._frames(tree, 3)
	ok += SelfTest._expect(fails, Nav.host.current is SettingsScreen, "четыре тапа открыли меню")
	_tap(version)
	await SelfTest._settle(tree)
	ok += SelfTest._expect(fails, Nav.host.current is DebugScreen, "пять тапов не открыли отладочное меню")
	if not (Nav.host.current is DebugScreen):
		SelfTest._finish(fails, ok, "ОТЛАДКА", "")
		return
	var dbg := Nav.host.current as DebugScreen

	# 3. содержимое
	var chapters := 0
	for id: String in Campaign.ORDER:
		if dbg.find_child("Chapter_" + id, true, false) is Button:
			chapters += 1
	ok += SelfTest._expect(fails, chapters == Campaign.ORDER.size(), "кнопок глав %d из %d" % [chapters, Campaign.ORDER.size()])
	var info := DebugScreen.info_text()
	for part: String in ["Версия", "Телефон", "Кадры", "Узлов", "Память"]:
		ok += SelfTest._expect(fails, info.contains(part), "в цифрах нет строки «%s»" % part)
	var toggle := dbg.find_child("CounterToggle", true, false) as Button
	ok += SelfTest._expect(fails, toggle != null, "нет переключателя счётчика кадров")
	if toggle != null:
		var before := Nav.perf.counter_visible()
		toggle.pressed.emit()
		ok += SelfTest._expect(fails, Nav.perf.counter_visible() == not before, "переключатель не менял счётчик кадров")
		toggle.pressed.emit()
		ok += SelfTest._expect(fails, Nav.perf.counter_visible() == before, "второе нажатие не вернуло счётчик")

	# 4. назад в настройки
	(dbg.find_child("DebugBack", true, false) as Button).pressed.emit()
	await SelfTest._settle(tree)
	ok += SelfTest._expect(fails, Nav.host.current is SettingsScreen, "кнопка «Назад» не вернула в настройки")

	# 5. переход к закрытой главе
	for i in range(5):
		_tap(Nav.host.current.find_child("Version", true, false) as Label)
	await SelfTest._settle(tree)
	dbg = Nav.host.current as DebugScreen
	ok += SelfTest._expect(fails, dbg != null, "меню не открылось второй раз")
	if dbg != null:
		ok += SelfTest._expect(fails, not Campaign.unlocked("a3c1"), "до перехода глава a3c1 уже открыта")
		(dbg.find_child("Chapter_a3c1", true, false) as Button).pressed.emit()
		await SelfTest._settle(tree)
		ok += SelfTest._expect(fails, Game.m != null and String(Game.chapter.get("id", "")) == "a3c1", "переход не начал главу a3c1")
		ok += SelfTest._expect(fails, not Campaign.unlocked("a3c1") and Save.campaign_stars.is_empty(), "переход изменил прогресс кампании")
	Game.abandon()
	SelfTest._finish(fails, ok, "ОТЛАДКА", "пять тапов открывают меню, глава открывается без прохождения предыдущих, прогресс не тронут")
