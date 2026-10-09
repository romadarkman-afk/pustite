class_name PrologueScreen
extends Screen

var revealed := false


func screen_id() -> String:
	return "prologue"


func is_busy() -> bool:
	return not revealed


func field_ratio() -> float:
	return 0.34


func title() -> String:
	return "Перед первой ночью"


func mood() -> Vector2:
	return Vector2(0.9, 0.9)


func build() -> void:
	var you := m.player()
	var pre := W.label("Твоя роль…", &"Small")
	body.add_child(pre)
	var role := W.label("Ты — упырь" if you.is_upyr else "Ты — человек", &"Title")
	if you.is_upyr:
		role.add_theme_color_override("font_color", ThemeFactory.BLOOD)
	role.modulate.a = 0.0
	body.add_child(role)
	var story := W.label(
		"Ты не знаешь, кто ещё из них такой же. Улица тебе не страшна, а тот, кто окажется с тобой за одной дверью, до утра не доживёт. Днём говори как человек."
		if you.is_upyr else
		"Ночью на улице ты почти наверняка погибнешь. В убежище нельзя остаться одному — оберег гаснет. Тебе нужен второй, и ты не знаешь, кто из них человек.",
		&"Tale")
	story.modulate.a = 0.0
	body.add_child(story)
	var role_l := W.label(_role_text(you), &"Hint")
	role_l.modulate.a = 0.0
	if role_l.text.is_empty():
		role_l.visible = false
	body.add_child(role_l)
	var facts := W.label("Жителей %d, упырей %d. Убежищ %d по %d места. Дожить нужно до %d-го рассвета." % [
		m.config.players, m.config.monsters, m.config.shelters, m.config.capacity, m.config.nights], &"Small")
	facts.modulate.a = 0.0
	body.add_child(facts)
	body.add_child(people_strip())

	var go := W.button("Выйти к людям")
	go.modulate.a = 0.0
	go.pressed.connect(func() -> void: commit(Intent.CONTINUE))
	footer.add_child(go)
	_reveal([role, story, role_l, facts, go])


func _role_text(you: Villager) -> String:
	match you.role:
		Match.Role.ELDER:
			return "Ты старожил. Один раз за партию днём нажми на жителя и посмотри рисунки: узнаешь, упырь ли он. Узнаешь только ты."
		Match.Role.HEALER:
			return "Ты знахарь. Один раз за партию перед ночью возьми травы: если рядом с тобой в доме на кого-то нападут, ты его выходишь."
		Match.Role.HEADMAN:
			return "Ты староста. На изгнании твой голос считается за двоих."
	return ""


func _reveal(nodes: Array) -> void:
	await Juice.wait(0.9)
	Juice.haptic(Juice.Haptic.NIGHT)
	Sfx.play(&"reveal")
	for n: Control in nodes:
		if not is_instance_valid(n):
			return
		if Juice.instant:
			n.modulate.a = 1.0
		else:
			Juice.tween().tween_property(n, "modulate:a", 1.0, 0.45)
		await Juice.wait(0.35)
	revealed = true


func ambience() -> StringName:
	return &"amb_night"


func music() -> StringName:
	return &""
