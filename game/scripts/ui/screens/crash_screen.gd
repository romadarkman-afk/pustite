class_name CrashScreen
extends Screen
## Показывается при запуске, если прошлый запуск закрылся аварийно.


func screen_id() -> String:
	return "crash"


func title() -> String:
	return "Отчёт"


func mood() -> Vector2:
	return Vector2(0.9, 0.5)


func build() -> void:
	body.add_child(W.label("Прошлый запуск закрылся аварийно", &"Title"))
	body.add_child(W.label("Это ошибка игры, не ваша. Нажмите «Скопировать отчёт» и пришлите его — по нему видно, на каком шаге всё оборвалось.", &"Tale"))
	body.add_child(W.label("Последние шаги:", &"Hint"))
	for line: String in Diag.last_crumbs.slice(maxi(0, Diag.last_crumbs.size() - 12)):
		body.add_child(W.label(line, &"Small"))
	var copy := W.button("Скопировать отчёт")
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(Diag.report_text())
		copy.text = "Скопировано — вставьте в чат")
	footer.add_child(copy)
	var go := W.button("Продолжить", &"Ghost")
	go.pressed.connect(func() -> void: commit(Intent.BACK))
	footer.add_child(go)
