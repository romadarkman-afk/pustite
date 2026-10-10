class_name VoteScreen
extends Screen

var picked: int = -1
var result_shown := false
var _rows: Array[Button] = []


func screen_id() -> String:
	return "vote"


func field_ratio() -> float:
	return 0.3


func title() -> String:
	return L.t("vote.title")


func mood() -> Vector2:
	return Vector2(0.35, 0.5)


func build() -> void:
	if m.meeting_by >= 0:
		var caller := m.get_villager(m.meeting_by)
		body.add_child(W.label(L.t("vote.bell_you") if caller.is_player else L.t("vote.bell", {"who": caller}), &"Hint"))
	body.add_child(W.label(L.t("vote.ask"), &"Tale"))
	var diary := W.button(L.t("day.diary"), &"Quick")
	diary.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	diary.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	diary.pressed.connect(func() -> void: DiarySheet.open(self, m, director))
	body.add_child(diary)
	if m.player().alive and m.player().role == Match.Role.HEADMAN:
		body.add_child(W.label(L.t("vote.headman"), &"Small"))
	if not m.player().alive:
		body.add_child(W.label(L.t("vote.dead"), &"Small"))
		var watch := W.button(L.t("vote.watch"))
		watch.pressed.connect(func() -> void: commit(Intent.VOTE, {"id": -1}))
		footer.add_child(watch)
		return

	var list := W.vbox(10)
	for v: Villager in m.alive_bots():
		var b := W.button(v.name, &"Row")
		var vid := v.id
		b.pressed.connect(func() -> void: _select(vid, b))
		_rows.append(b)
		list.add_child(b)
	body.add_child(list)

	var go := W.button(L.t("vote.go"))
	go.disabled = true
	go.pressed.connect(func() -> void: commit(Intent.VOTE, {"id": picked}))
	footer.add_child(go)
	set_meta("go", go)


func _select(vid: int, b: Button) -> void:
	picked = vid
	for r: Button in _rows:
		r.theme_type_variation = &"RowOn" if r == b else &"Row"
	(get_meta("go") as Button).disabled = false


## Nav вызывает с итогом голосования.
func show_result(tally: Dictionary[int, int], exiled: Villager) -> void:
	W.clear(body)
	W.clear(footer)
	var head_text := L.t("vote.none")
	if exiled != null:
		head_text = L.t("vote.gone_you") if exiled.is_player else L.t("vote.gone", {"who": exiled})
	var head := W.label(head_text, &"Title")
	head.add_theme_font_size_override("font_size", 44)
	body.add_child(head)
	Juice.haptic(Juice.Haptic.DEATH)
	Sfx.play(&"exile")

	var total := 0
	for k: int in tally:
		total += tally[k]
	var order: Array[int] = []
	order.assign(tally.keys())
	order.sort_custom(func(a: int, b: int) -> bool: return tally[a] > tally[b])
	for vid: int in order:
		var v := m.get_villager(vid)
		var row := W.vbox(4)
		row.add_child(W.label(L.t("vote.row", {"who": v.name, "n": tally[vid]}), &"Body"))
		var bar := ColorRect.new()
		bar.color = ThemeFactory.BLOOD if v == exiled else ThemeFactory.EDGE
		bar.custom_minimum_size = Vector2(0, 8)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(bar)
		body.add_child(row)
		var target_w := 560.0 * tally[vid] / maxf(1.0, float(total))
		if Juice.instant:
			bar.custom_minimum_size.x = target_w
		else:
			Juice.tween().tween_property(bar, "custom_minimum_size:x", target_w, 0.5)
		await Juice.wait(0.12)

	body.add_child(people_strip())
	var next := W.button(L.t("vote.night"))
	next.pressed.connect(func() -> void: commit(Intent.CONTINUE))
	footer.add_child(next)
	_locked = false
	result_shown = true


func ambience() -> StringName:
	return &"amb_day"


func music() -> StringName:
	return &""
