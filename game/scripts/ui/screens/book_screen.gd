class_name BookScreen
extends Screen
## Книга посёлка (Task 62): уровень, судьбы всех, кого встречал, найденные концовки и достижения.
## Пустые страницы видны: что ещё можно найти.


func screen_id() -> String:
	return "book"


func title() -> String:
	return L.t("book.title")


func field_ratio() -> float:
	return 0.3


func mood() -> Vector2:
	return Vector2(0.8, 0.7)


func build() -> void:
	W.clear(body)
	W.clear(footer)
	body.add_child(W.label(L.t("book.title"), &"Title"))
	body.add_child(EndScreen.level_bar(Save.xp))

	body.add_child(W.label(L.t("book.people"), &"Speaker"))
	for p: Array in Progress.book_people():
		var e := Progress.book_entry(String(p[0]))
		var line: Control
		if e[0] == 0:
			line = W.icon_line("info", L.t("book.unknown"), &"Hint", 32)
		else:
			line = W.icon_line("skull" if e[1] > 0 else "people",
				String(p[1]) + ": " + L.t("book.stats", {"m": e[0], "d": e[1], "u": e[2]}), &"Small", 32)
		line.name = "Person_" + String(p[0])
		body.add_child(line)
		# память кампании (TASK-002): что было между игроком и этим жителем
		if String(p[0]).begins_with("n"):
			var k := 0
			for mem: String in Campaign.memory_lines(int(String(p[0]).substr(1))):
				var ml := W.label(mem, &"Hint")
				ml.name = "Memory_%s_%d" % [String(p[0]), k]
				ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				body.add_child(ml)
				k += 1

	body.add_child(W.label(L.t("book.endings"), &"Speaker"))
	for id: String in Progress.ENDINGS:
		var found := Save.endings.has(id)
		var el := W.icon_line("street_ok" if found else "lock", L.t("ending." + id) if found else L.t("book.ending_hidden"), &"Small" if found else &"Hint", 32)
		el.name = "Ending_" + id
		body.add_child(el)

	body.add_child(W.label(L.t("book.ach", {"n": Save.achievements.size(), "of": Progress.ACHIEVEMENTS.size()}), &"Speaker"))
	for id: String in Progress.ACHIEVEMENTS:
		var got := Save.achievements.has(id)
		var box := W.vbox(2)
		box.name = "Ach_" + id
		box.add_child(W.icon_line("street_ok" if got else "lock", L.t("ach.%s.name" % id), &"Body" if got else &"Hint", 32,
			ThemeFactory.LAMP if got else Color(0, 0, 0, 0)))
		box.add_child(W.label(L.t("ach.%s.desc" % id), &"Small"))
		body.add_child(box)

	var back := W.button(L.t("ui.back"), &"Ghost")
	back.pressed.connect(func() -> void: emit_intent(Intent.BACK))
	footer.add_child(back)
