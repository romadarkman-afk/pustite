class_name NightScreen
extends Screen
## Колокол: пока звенит, надо выбрать дом и добежать. Тап по дому на поле — фигурка
## бежит к его двери, боты бегут к своим. Кто первым у двери, тот внутри и решает.
## Список ниже — запасной, там видно, кто куда собирался и цел ли оберег.

var picked: int = -1
var _rows: Array[Button] = []
var _status: Label
var heal_button: Button       ## у знахаря: взять травы на эту ночь


func screen_id() -> String:
	return "night"


func field_ratio() -> float:
	return 0.5


func min_content_ratio() -> float:
	return 0.2


## Сумерки длинные: окна загораются по одному, в конце в лесу появляются глаза.
func mood_duration() -> float:
	return 1.8


func title() -> String:
	return L.t("when.night", {"n": m.day})


func mood() -> Vector2:
	return Vector2(1.0, 0.7)


func build() -> void:
	Juice.haptic(Juice.Haptic.NIGHT)
	Sfx.play(&"bell")
	enable_field_taps()
	if not m.player().alive:
		body.add_child(W.label(L.t("night.dusk"), &"Tale"))
		_event_label()
		body.add_child(W.label(L.t("night.dead"), &"Small"))
		var go_dead := W.button(L.t("ui.next"))
		go_dead.pressed.connect(func() -> void: commit(Intent.CHOOSE_HOUSE, {"house": -1}))
		footer.add_child(go_dead)
		return

	_status = W.label(L.t("night.bell"), &"Tale")
	body.add_child(_status)
	_event_label()
	var me := m.player()
	var list := W.vbox(10)
	for i in range(m.houses.size()):
		var who := PackedStringArray()
		var pact: Villager = null
		for v: Villager in m.alive_bots():
			if v.announced_house == i:
				who.append(v.name)
				if director.brains[v.id].pact_id == me.id:
					pact = v
		var text := m.houses[i]
		if not who.is_empty():
			text += "\n" + L.t("night.going", {"list": L.t("list.sep").join(who)})
		if pact != null:
			text += "\n" + L.t("night.pact", {"who": pact})
		if m.tunnel_to(i) >= 0:
			text += "\n" + L.t("night.tunnel", {"house": m.house_name(m.tunnel_to(i))})
		if i < m.talisman.size() and m.talisman[i] < Match.TALISMAN_MAX:
			text += "\n" + L.t("night.tal_broken" if m.talisman[i] <= 0 else "night.tal_cracked")
		var b := W.button(text, &"Row", 108)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func() -> void: select_house(idx))
		_rows.append(b)
		list.add_child(b)
	body.add_child(list)
	body.add_child(W.label(L.t("night.rule"), &"Small"))
	if me.role == Match.Role.HEALER and not me.role_used:
		heal_button = W.button(L.t("night.heal"), &"Row")
		heal_button.pressed.connect(func() -> void: emit_intent(Intent.HEAL))
		body.add_child(heal_button)


## Событие ночи — строкой под призывом бежать.
func _event_label() -> void:
	if m.night_event != Match.Event.NONE:
		var l := W.label(Match.event_text(m.night_event), &"Hint")
		l.name = "Event"
		body.add_child(l)


func hint_id() -> String:
	return "night" if m.player().alive else ""


func hint_text() -> String:
	return L.t("night.hint")


func hint_target() -> Rect2:
	if _rows.is_empty():
		return super.hint_target()
	var r := _rows[0].get_global_rect()
	r.position -= get_global_rect().position
	return r


func hint_below() -> bool:
	return false


## Выбор дома — с поля или из списка. Наверх уходит SELECT_HOUSE: Nav обводит дом
## на поле, Game считает, когда ты добежишь, и фигурка бежит к двери.
func select_house(i: int) -> void:
	if i < 0 or i >= _rows.size():
		return
	_select(i, _rows[i])
	emit_intent(Intent.SELECT_HOUSE, {"house": i})


## Nav: травы взяты.
func show_healed() -> void:
	if is_instance_valid(heal_button):
		heal_button.text = L.t("night.heal_on")
		heal_button.disabled = true


## Сколько жителей собирается в каждый дом — для табличек на поле.
func going_counts() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(m.houses.size())
	for v: Villager in m.alive_bots():
		if v.announced_house >= 0 and v.announced_house < out.size():
			out[v.announced_house] += 1
	return out


func _select(i: int, b: Button) -> void:
	picked = i
	for r: Button in _rows:
		r.theme_type_variation = &"RowOn" if r == b else &"Row"


## Nav сообщает, куда бежит игрок и кто добежит раньше (колокол отзвонил — дом выбран за него).
func show_run(house: int, ahead: PackedStringArray = PackedStringArray()) -> void:
	if house < 0 or house >= _rows.size() or _status == null:
		return
	if picked != house:
		_select(house, _rows[house])
	var who := L.t("night.first") if ahead.is_empty() \
		else L.t("night.ahead", {"list": L.t("list.sep").join(ahead), "who": ahead[0]})
	_status.text = L.t("night.run", {"house": m.houses[house], "rest": who})


func ambience() -> StringName:
	return &"amb_night"


func music() -> StringName:
	return &""
