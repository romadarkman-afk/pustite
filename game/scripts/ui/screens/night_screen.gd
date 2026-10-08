class_name NightScreen
extends Screen
## Выбор убежища. Видно, кто куда собирался днём, и с кем у тебя уговор.

var picked: int = -1
var _rows: Array[Button] = []


func screen_id() -> String:
	return "night"


func field_ratio() -> float:
	return 0.4


func title() -> String:
	return "Ночь %d" % m.day


func mood() -> Vector2:
	return Vector2(1.0, 0.7)


func build() -> void:
	Juice.haptic(Juice.Haptic.NIGHT)
	body.add_child(W.label("Темнеет. Куда идёшь?", &"Tale"))
	if not m.player().alive:
		body.add_child(W.label("Тебя больше нет. Ночь идёт без тебя.", &"Small"))
		var go_dead := W.button("Дальше")
		go_dead.pressed.connect(func() -> void: commit(Intent.CHOOSE_HOUSE, {"house": -1}))
		footer.add_child(go_dead)
		return

	var me := m.player()
	var list := W.vbox(10)
	for i in range(m.houses.size()):
		var who := PackedStringArray()
		var pact := ""
		for v: Villager in m.alive_bots():
			if v.announced_house == i:
				who.append(v.name)
				if director.brains[v.id].pact_id == me.id:
					pact = v.name
		var text := m.houses[i]
		if not who.is_empty():
			text += "\nсобирались: " + ", ".join(who)
		if pact != "":
			text += "\nуговор с %s" % pact
		var b := W.button(text, &"Row", 108)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func() -> void: _select(idx, b))
		_rows.append(b)
		list.add_child(b)
	body.add_child(list)
	body.add_child(W.label("Кто добежит первым — тот внутри и решает, кого впустить. Порядок прихода случаен.", &"Small"))

	var go := W.button("Идти")
	go.disabled = true
	go.pressed.connect(func() -> void: commit(Intent.CHOOSE_HOUSE, {"house": picked}))
	footer.add_child(go)
	set_meta("go", go)
	if me.announced_house >= 0:
		_select(me.announced_house, _rows[me.announced_house])


func hint_id() -> String:
	return "night" if m.player().alive else ""


func hint_text() -> String:
	return "Выбери дом. Порядок прихода случаен: кто добежит первым, тот и решает, кого впустить."


func hint_target() -> Rect2:
	if _rows.is_empty():
		return super.hint_target()
	var r := _rows[0].get_global_rect()
	r.position -= get_global_rect().position
	return r


func hint_below() -> bool:
	return false


func _select(i: int, b: Button) -> void:
	picked = i
	for r: Button in _rows:
		r.theme_type_variation = &"RowOn" if r == b else &"Row"
	(get_meta("go") as Button).disabled = false
