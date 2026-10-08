class_name DoorScreen
extends Screen
## Дверь. Три режима:
##  HOST  — ты добежал первым, в дверь стучат, решаешь ты;
##  GUEST — ты у чужой двери и умоляешь впустить (в v0.1 этого не было вообще);
##  ALONE — ты внутри, а больше никто не пришёл.
## Атмосферой управляет Nav по сигналам этого экрана — экран лишь просит.

signal knock_fx
signal open_fx(amount: float)

var role: Match.DoorRole
var seat: Match.Seat
var pleas: Dictionary[int, String] = {}
var result_shown := false
var _selected: Array[int] = []
var _rows: Dictionary[int, Button] = {}
var _go: Button


func screen_id() -> String:
	match role:
		Match.DoorRole.HOST: return "door_host"
		Match.DoorRole.GUEST: return "door_guest"
	return "door_alone"


func title() -> String:
	return "У двери"


func hint_id() -> String:
	return "door"


func hint_text() -> String:
	match role:
		Match.DoorRole.HOST:
			return "Впусти того, кому веришь. Не откроешь никому, останешься один, а одному не выжить."
		Match.DoorRole.GUEST:
			return "Выбери, что сказать через дверь. Хозяин помнит, ночевали ли вы уже вместе."
	return "Одному здесь не выжить. В следующий раз днём позови кого-нибудь с собой."


func hint_target() -> Rect2:
	return Rect2(Vector2(size.x * 0.5, footer.position.y - 10.0), Vector2.ZERO)


func hint_below() -> bool:
	return false


func door_open() -> float:
	return 0.05 if role != Match.DoorRole.GUEST else 0.012


func build() -> void:
	match role:
		Match.DoorRole.HOST: _build_host()
		Match.DoorRole.GUEST: _build_guest()
		_: _build_alone()


# ---------------------------------------------------------------
func _build_host() -> void:
	body.add_child(W.gap(10))
	body.add_child(W.label("Ты первым добежал до «%s». В дверь стучат." % Ru.house_of(m.house_name(seat.house)), &"Tale"))
	var cap := m.config.capacity - 1
	body.add_child(W.label("Впустить можно: %d" % cap, &"Hint"))

	for g: Villager in seat.queue:
		var card := W.panel(&"Card")
		var row := W.hbox(14)
		var texts := W.vbox(4)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(W.label(g.name, &"Body"))
		texts.add_child(W.label("«%s»" % pleas.get(g.id, "…"), &"Small"))
		row.add_child(texts)
		var b := W.button("Впустить", &"Row")
		b.custom_minimum_size = Vector2(200, ThemeFactory.TOUCH)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var gid := g.id
		b.pressed.connect(func() -> void: _toggle(gid, cap))
		_rows[gid] = b
		row.add_child(b)
		card.add_child(row)
		body.add_child(card)

	body.add_child(W.label(
		"Тот, кого впустишь, до утра не доживёт." if m.player().is_upyr
		else "Не откроешь никому — останешься один, и оберег погаснет.", &"Hint"))

	_go = W.button("Открыть дверь")
	_go.disabled = true
	_go.pressed.connect(func() -> void: _finish_host(_selected))
	footer.add_child(_go)
	var refuse := W.button("Не открывать никому", &"Danger")
	refuse.pressed.connect(func() -> void: _finish_host([]))
	footer.add_child(refuse)
	_knock_sequence(seat.queue.size())


func _toggle(gid: int, cap: int) -> void:
	if _selected.has(gid):
		_selected.erase(gid)
	else:
		if _selected.size() >= cap:
			_selected.pop_front()
		_selected.append(gid)
	for k: int in _rows:
		_rows[k].theme_type_variation = &"RowOn" if _selected.has(k) else &"Row"
		_rows[k].text = "Впускаю" if _selected.has(k) else "Впустить"
	_go.disabled = _selected.is_empty()


func _finish_host(ids: Array[int]) -> void:
	if is_locked():
		return
	if ids.is_empty():
		open_fx.emit(0.0)
		Juice.haptic(Juice.Haptic.REFUSE)
		Juice.shake(self, 10.0)
	else:
		open_fx.emit(0.38)
		Juice.haptic(Juice.Haptic.SUCCESS)
	commit(Intent.ADMIT, {"ids": ids.duplicate()})


## Время вышло: не решил — дверь осталась закрытой.
func on_clock_expired() -> void:
	match role:
		Match.DoorRole.HOST: _finish_host([])
		Match.DoorRole.GUEST: _send_plea("")
		_: commit(Intent.ADMIT, {"ids": [] as Array[int]})


# ---------------------------------------------------------------
func _build_guest() -> void:
	body.add_child(W.gap(10))
	body.add_child(W.label("«%s» уже заперт изнутри. Там — %s." % [m.house_name(seat.house), seat.host.name], &"Tale"))
	var rivals := PackedStringArray()
	for g: Villager in seat.queue:
		if not g.is_player:
			rivals.append(g.name)
	if not rivals.is_empty():
		body.add_child(W.label("Рядом с тобой у двери: %s. Мест на всех не хватит." % ", ".join(rivals), &"Hint"))
	body.add_child(W.label("Что скажешь через дверь?", &"Small"))

	for p: Dictionary in Phrases.PLAYER_PLEAS:
		var b := W.button(p.label, &"Row")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pid: String = p.id
		b.pressed.connect(func() -> void: _send_plea(pid))
		body.add_child(b)
	_knock_sequence(1)


func _send_plea(plea_id: String) -> void:
	commit(Intent.PLEA, {"plea": plea_id})


## Nav вызывает, когда хозяин решил. Пауза, стук, засов — или шаги прочь.
func show_guest_result(admitted: bool) -> void:
	W.clear(body)
	body.add_child(W.gap(60))
	var t := W.label("Ты стучишь в дверь «%s»…" % Ru.house_of(m.house_name(seat.house)), &"Tale")
	body.add_child(t)
	for i in range(3):
		knock_fx.emit()
		Juice.haptic(Juice.Haptic.KNOCK)
		Juice.shake(self, 6.0, 0.2)
		await Juice.wait(0.55)
	await Juice.wait(0.6)
	if admitted:
		open_fx.emit(0.4)
		Juice.haptic(Juice.Haptic.SUCCESS)
		t.text = "Щёлкает засов. %s впускает тебя." % seat.host.name
	else:
		open_fx.emit(0.0)
		Juice.haptic(Juice.Haptic.REFUSE)
		Juice.shake(self, 14.0, 0.4)
		t.text = "Шаги удаляются от двери. Ты остаёшься снаружи."
	Juice.pop_in(t)
	var next := W.button("Ждать рассвета")
	next.pressed.connect(func() -> void: commit(Intent.CONTINUE))
	footer.add_child(next)
	_locked = false
	result_shown = true


# ---------------------------------------------------------------
func _build_alone() -> void:
	body.add_child(W.gap(60))
	body.add_child(W.label("Ты первым добежал до «%s». Больше никто не пришёл." % Ru.house_of(m.house_name(seat.house)), &"Tale"))
	body.add_child(W.label(
		"Одному упырю улица не страшна." if m.player().is_upyr
		else "Оберег мерцает. Одному его до утра не удержать.", &"Hint"))
	var next := W.button("Ждать рассвета")
	next.pressed.connect(func() -> void: commit(Intent.ADMIT, {"ids": [] as Array[int]}))
	footer.add_child(next)


func _knock_sequence(n: int) -> void:
	await Juice.wait(0.5)
	for i in range(clampi(n, 1, 3)):
		if not is_instance_valid(self) or is_locked():
			return
		knock_fx.emit()
		Juice.haptic(Juice.Haptic.KNOCK)
		Juice.shake(self, 7.0, 0.22)
		await Juice.wait(0.45)
