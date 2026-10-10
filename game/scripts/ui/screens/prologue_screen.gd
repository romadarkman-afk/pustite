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
	return L.t("prologue.title")


func mood() -> Vector2:
	return Vector2(0.9, 0.9)


func build() -> void:
	var you := m.player()
	var pre := W.label(L.t("prologue.pre"), &"Small")
	body.add_child(pre)
	var role := W.label(L.t("prologue.upyr" if you.is_upyr else "prologue.human"), &"Title")
	if you.is_upyr:
		role.add_theme_color_override("font_color", ThemeFactory.BLOOD)
	role.modulate.a = 0.0
	body.add_child(role)
	var story := W.label(
		L.t("prologue.upyr_text" if you.is_upyr else "prologue.human_text"),
		&"Tale")
	story.modulate.a = 0.0
	body.add_child(story)
	var role_l := W.label(_role_text(you), &"Hint")
	role_l.modulate.a = 0.0
	if role_l.text.is_empty():
		role_l.visible = false
	body.add_child(role_l)
	var facts := W.label(L.t("prologue.facts", {"p": m.config.players, "u": m.config.monsters,
		"s": m.config.shelters, "c": m.config.capacity, "n": m.config.nights}), &"Small")
	facts.modulate.a = 0.0
	body.add_child(facts)
	body.add_child(people_strip())

	var go := W.button(L.t("prologue.go"))
	go.modulate.a = 0.0
	go.pressed.connect(func() -> void: commit(Intent.CONTINUE))
	footer.add_child(go)
	_reveal([role, story, role_l, facts, go])


func _role_text(you: Villager) -> String:
	match you.role:
		Match.Role.ELDER:
			return L.t("prologue.elder")
		Match.Role.HEALER:
			return L.t("prologue.healer")
		Match.Role.HEADMAN:
			return L.t("prologue.headman")
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
