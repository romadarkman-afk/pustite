class_name CrashScreen
extends Screen
## Показывается при запуске, если прошлый запуск закрылся аварийно.

var crashed := false


func screen_id() -> String:
	return "crash"


func title() -> String:
	return L.t("crash.saved_title") if Game.has_day_checkpoint() and not crashed else L.t("crash.title")


func mood() -> Vector2:
	return Vector2(0.9, 0.5)


func build() -> void:
	var has_checkpoint := Game.has_day_checkpoint()
	if has_checkpoint and not crashed:
		body.add_child(W.label(L.t("crash.saved_title"), &"Title"))
		body.add_child(W.label(L.t("crash.saved_text"), &"Tale"))
	else:
		body.add_child(W.label(L.t("crash.head"), &"Title"))
		body.add_child(W.label(L.t("crash.text"), &"Tale"))
		body.add_child(W.label(L.t("crash.steps"), &"Hint"))
		for line: String in Diag.last_crumbs.slice(maxi(0, Diag.last_crumbs.size() - 12)):
			body.add_child(W.label(line, &"Small"))
		var copy := W.button(L.t("crash.copy"))
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(Diag.report_text())
			copy.text = L.t("crash.copied"))
		footer.add_child(copy)
	if has_checkpoint:
		var resume := W.button(L.t("crash.resume"))
		resume.pressed.connect(func() -> void:
			if not Game.resume_day_checkpoint():
				resume.disabled = true)
		footer.add_child(resume)
	var go := W.button(L.t("ui.continue"), &"Ghost")
	go.pressed.connect(func() -> void: commit(Intent.BACK))
	footer.add_child(go)
