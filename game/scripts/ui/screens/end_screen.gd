class_name EndScreen
extends Screen


func screen_id() -> String:
	return "end"


func title() -> String:
	return ""


func mood() -> Vector2:
	return Vector2(0.55, 0.85)


var offer: String = ""          ## ступень, которую предложить: проиграл — легче, две победы — сложнее
var difficulty: String = "easy"
var _pages: Array[VBoxContainer] = []
var _page_titles: PackedStringArray = []
var _page := 0
var _steps: Label
var _rewards_played := false
var _cast_played := false
var _reward_page := -1
var _cast_page := -1
var return_page := -1


func result_page() -> int:
	return _page


func build() -> void:
	var you := m.player()
	var people_won := m.winner == Match.Team.PEOPLE
	var won := people_won != you.is_upyr
	_steps = W.label("", &"Speaker")
	_steps.name = "ResultSteps"
	body.add_child(_steps)
	var summary := _add_page("end.step_result")
	summary.add_child(ending_card(people_won, won))
	var result := Game.chapter_result
	if not result.is_empty():
		summary.add_child(chapter_card(result, true))
	summary.add_child(_verdict_card(true))
	var earned := int(Game.progress_result.get("gained", 0))
	if earned > 0:
		summary.add_child(W.label(L.t("end.earned", {"xp": earned}), &"Speaker"))
	if return_page < 0:
		for i in range(summary.get_child_count()):
			Juice.pop_in(summary.get_child(i) as Control, i * 0.19)
	var villagers := _add_page("end.step_cast")
	_cast_page = _pages.size() - 1
	var reveal := reveal_cards()
	if reveal != null:
		villagers.add_child(reveal)
	var cast := HFlowContainer.new()
	for v: Villager in m.villagers:
		if not v.alive and (not v.is_upyr or v.is_player):
			cast.add_child(_resident_fate(v))
	for v: Villager in m.alive():
		cast.add_child(_resident_fate(v))
	if cast.get_child_count() > 0:
		villagers.add_child(cast)
	else:
		cast.free()
	var mem := memory_card(m)
	if mem != null:
		villagers.add_child(mem)
	if not Game.progress_result.is_empty() or not Game.new_items.is_empty():
		var rewards := _add_page("end.step_rewards")
		_reward_page = _pages.size() - 1
		if not Game.progress_result.is_empty():
			rewards.add_child(progress_card(Game.progress_result))
		_add_unlocks(rewards)
	var details := _add_page("end.step_details")
	if not result.is_empty():
		details.add_child(chapter_card(result))
	details.add_child(_verdict_card())
	_add_details(details, won)
	var fit := func() -> void: fit_actions.call_deferred(footer)
	scroll.resized.connect(fit)
	body.minimum_size_changed.connect(fit)
	if return_page >= 0:
		_rewards_played = true
		_cast_played = true
		_show_page(return_page)
	else:
		_show_page(0)
		if _comics_end_due():
			_play_comics_end.call_deferred()
		Juice.haptic(Juice.Haptic.SUCCESS if won else Juice.Haptic.DEATH)
		Sfx.play(&"win" if won else &"lose")


func _add_page(key: String) -> VBoxContainer:
	var page := W.vbox(14)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(page)
	_pages.append(page)
	_page_titles.append(L.t(key))
	return page


func _resident_fate(v: Villager) -> PanelContainer:
	var card := W.panel(&"Card")
	card.name = "Fate_%d" % v.id
	var row := W.vbox(4)
	card.custom_minimum_size.x = 104.0
	var portrait := W.portrait(v, Vector2(46, 67))
	portrait.active = false
	portrait.name = "FatePortrait"
	if not v.alive:
		card.set_meta("lost", true)
		portrait.modulate = Color(0.63, 0.66, 0.69, 0.60)
	row.add_child(portrait)
	var copy := W.vbox(3)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := W.label(v.name, &"Speaker")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(name_label)
	var fate := "end.cast_alive" if v.alive else ("end.cast_exiled" if v.exiled else "end.cast_dead")
	var status := W.label(L.t(fate), &"Small")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(status)
	row.add_child(copy)
	card.add_child(row)
	return card


func _show_page(index: int) -> void:
	_page = clampi(index, 0, _pages.size() - 1)
	for i in range(_pages.size()):
		_pages[i].visible = i == _page
	_steps.text = L.t("end.steps", {"name": _page_titles[_page], "a": _page + 1, "b": _pages.size()})
	scroll.scroll_vertical = 0
	W.clear(footer)
	if _page + 1 < _pages.size():
		var next := W.button(L.t("end.next_page", {"name": _page_titles[_page + 1]}))
		next.name = "ResultNext"
		next.pressed.connect(func() -> void: _show_page(_page + 1))
		footer.add_child(next)
	else:
		_exit_buttons()
	if _page > 0:
		var back := W.button(L.t("ui.back"), &"Ghost", 46)
		back.pressed.connect(func() -> void: _show_page(_page - 1))
		footer.add_child(back)
	if _page == 0:
		# На первой странице можно перейти к следующей главе или повторить текущую.
		_exit_buttons(true)
	elif _page == _reward_page and not _rewards_played:
		_rewards_played = true
		if bool(Game.chapter_result.get("passed", false)):
			Sfx.set_music(&"end_dawn", 1.3)
		_animate_rewards(_pages[_page])
	elif _page == _cast_page and not _cast_played:
		_cast_played = true
		var reveal := _pages[_page].find_child("Reveal", true, false)
		if reveal != null:
			var delay := 0.0
			for portrait: Node in reveal.find_children("Portrait", "TextureRect", true, false):
				_bleed(portrait as TextureRect, delay)
				delay += 0.18
		var delay := 0.0
		for child: Node in _pages[_page].find_children("Fate_*", "PanelContainer", true, false):
			Juice.pop_in(child as Control, delay)
			delay += 0.10
			if child.has_meta("lost") and not Juice.instant:
				var portrait := child.find_child("FatePortrait", true, false) as TextureRect
				if portrait != null:
					portrait.modulate.a = 1.0
					create_tween().tween_property(portrait, "modulate:a", 0.60, 0.45)
	fit_actions.call_deferred(footer)


func _exit_buttons(quick: bool = false) -> void:
	if not Game.chapter_result.is_empty():
		_chapter_buttons(Game.chapter_result, quick)
	elif not quick:
		var again := W.button(L.t("end.again"))
		again.pressed.connect(func() -> void: commit(Intent.AGAIN))
		footer.add_child(again)
		var opts := W.button(L.t("settings.difficulty"), &"Ghost")
		opts.pressed.connect(func() -> void: commit(Intent.OPEN_SETTINGS))
		footer.add_child(opts)


func _add_unlocks(rewards: Control) -> void:
	if not Game.new_items.is_empty():
		var names := PackedStringArray()
		for key: String in Game.new_items:
			var parts := key.split(":")
			names.append(Cosmetics.title(parts[0], parts[1]))
		var nc := W.panel(&"Card")
		nc.name = "NewItems"
		var nb := W.vbox(8)
		nb.add_child(W.icon_line("street_ok", L.t("cos.new", {"list": L.t("list.sep").join(names)}), &"Body"))
		var wear := W.wrap(W.button(L.t("cos.title"), &"Row"))
		wear.pressed.connect(func() -> void: commit(Intent.OPEN_WARDROBE))
		nb.add_child(wear)
		nc.add_child(nb)
		rewards.add_child(nc)


func _add_details(details: Control, won: bool) -> void:
	var dl := Recap.dilemma_lines(m)
	if not dl.is_empty():
		var dc := W.panel(&"Card")
		dc.name = "Dilemmas"
		var db := W.vbox(6)
		db.add_child(W.label(L.t("end.dilemmas"), &"Speaker"))
		for l: String in dl:
			db.add_child(W.label(l, &"Small"))
		dc.add_child(db)
		details.add_child(dc)
	var case_card := W.panel(&"Card")
	case_card.name = "CaseRecap"
	var case_box := W.vbox(8)
	case_box.add_child(W.label(SocialContent.case_recap(m.case_id, m.door_inspections.size()), &"Small"))
	for record: Dictionary in m.door_inspections:
		var visitor := m.get_villager(int(record.villager))
		var revealed := SocialContent.door_mimic_title() if bool(record.get("mimic", false)) else L.t("end.upyr" if visitor != null and visitor.is_upyr else "end.human")
		case_box.add_child(W.label(L.t("end.chip", {"who": String(record.get("name", "")), "what": revealed})
			+ "\n" + SocialContent.door_record(int(record.day), StringName(record.tell)), &"Small"))
	case_card.add_child(case_box)
	details.add_child(case_card)
	if m.rule != "":
		var card := W.panel(&"Card")
		card.name = "Daily"
		var date := Challenge.today()
		card.add_child(W.icon_line("safe" if won else "skull",
			L.t("daily.won" if won else "daily.lost") + ". " + L.t("daily.streak", {"n": Save.daily_streak_on(Game.daily if Game.daily != "" else date)}) + ". " + L.t("daily.tomorrow"), &"Body"))
		details.add_child(card)
	if offer != "" and m.rule == "" and Game.chapter.is_empty():
		details.add_child(_offer_card())
	var known := W.vbox(8)
	for resident: Villager in m.villagers:
		var ending := SocialContent.epilogue(resident) if not resident.is_player else ""
		if not ending.is_empty():
			known.add_child(W.label(ending, &"Small"))
	var saved_pair := Progress.saved_bond_pair(m)
	if saved_pair.size() == 2:
		known.add_child(W.label(L.t("bond.saved", {"who": saved_pair[0].name, "kin": saved_pair[1].name}), &"Small"))
	if known.get_child_count() > 0:
		var chapter := W.panel(&"Card")
		var chapter_box := W.vbox(8)
		chapter_box.add_child(W.label((String((StoryLoc.get_v("misc") as Array)[0]) if StoryLoc.has("misc") else ("После последней ночи" if L.code == "ru" else "After the last night")), &"Speaker"))
		chapter_box.add_child(known)
		chapter.add_child(chapter_box)
		details.add_child(chapter)
	else:
		known.queue_free()

	details.add_child(W.label(L.t("end.who"), &"Hint"))
	var flow := HFlowContainer.new()
	var i := 0
	for v: Villager in m.villagers:
		var who := L.t("end.upyr" if v.is_upyr else "end.human")
		if v.role != Match.Role.NONE:
			who = L.t("end.with_role", {"a": who, "role": Match.role_name(v, true)})
		var c := W.chip(L.t("end.chip", {"who": v.name, "what": who}),
			&"ChipUpyr" if v.is_upyr else (&"ChipDead" if not v.alive else &"Chip"))
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(c)
		Juice.pop_in(c, 0.4 + 0.12 * i)
		i += 1
	details.add_child(flow)

	details.add_child(W.label(L.t("end.how"), &"Hint"))
	for sec: Dictionary in Recap.timeline(m):
		if String(sec.title) != "":
			details.add_child(W.label(sec.title, &"Speaker"))
		for line: String in sec.lines:
			details.add_child(W.label(line, &"Small"))



func _animate_rewards(page: Control) -> void:
	var bar := page.find_child("LevelBar", true, false)
	if not Juice.instant and bar != null:
		var update_xp: Callable = bar.get_meta("update_xp")
		var data := Game.progress_result
		update_xp.call(int(data.before))
		var fill := create_tween()
		fill.tween_method(update_xp, int(data.before), int(data.after), 0.95).set_trans(Tween.TRANS_LINEAR)
		var rewards: PackedStringArray = data.new_ach
		for i in range(rewards.size()):
			var ach := page.find_child("Ach_" + rewards[i], true, false) as Control
			if ach != null:
				Juice.pop_in(ach, 0.10 + i * 0.11)


## Опыт за партию, уровень посёлка и новые достижения (Task 62).
static func progress_card(p: Dictionary) -> PanelContainer:
	var card := W.panel(&"Card")
	card.name = "Progress"
	var box := W.vbox(6)
	card.add_child(box)
	var head := W.label(L.t("end.xp", {"n": int(p.gained)}), &"Speaker")
	head.add_theme_color_override("font_color", ThemeFactory.LAMP)
	box.add_child(head)
	var parts := PackedStringArray()
	for l: Array in p.lines:
		parts.append(L.t(String(l[0]), {"n": int(l[2])}) + " +" + str(int(l[1])))
	var lv := int(p.level_after)
	box.add_child(level_bar(int(p.after)))
	if lv > int(p.level_before):
		var up := W.label(L.t("end.level_up", {"n": lv, "title": Progress.title(lv)}), &"Body")
		up.name = "LevelUp"
		up.add_theme_color_override("font_color", ThemeFactory.LAMP)
		box.add_child(up)
	for a: String in p.new_ach:
		var al := W.icon_line("street_ok", L.t("end.new_ach", {"name": L.t("ach.%s.name" % a)}), &"Small", 32, ThemeFactory.LAMP)
		al.name = "Ach_" + a
		box.add_child(al)
	for part: String in parts:
		box.add_child(W.label(part, &"Small"))
	return card


## Уровень посёлка полоской: «Уровень 3 · Сосед» и сколько до следующего.
static func level_bar(xp: int) -> Control:
	var col := W.vbox(5)
	col.name = "LevelBar"
	var title := W.label("", &"Body")
	col.add_child(title)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.y = 10
	var fill := StyleBoxFlat.new()
	fill.bg_color = ThemeFactory.LAMP
	bar.add_theme_stylebox_override("fill", fill)
	col.add_child(bar)
	var update_xp := func(value: int) -> void:
		var lv := Progress.level_of(value)
		var span := Progress.level_span(value)
		title.text = L.t("end.level", {"n": lv, "title": Progress.title(lv), "a": span.x, "b": span.y})
		bar.max_value = span.y
		bar.value = span.x
	col.set_meta("update_xp", update_xp)
	update_xp.call(xp)
	return col


## Итог главы: пройдена или нет, звёзды, цели, концовка акта.
func chapter_card(res: Dictionary, compact: bool = false) -> PanelContainer:
	var card := W.panel(&"Sheet")
	card.name = "ChapterResult"
	var box := W.vbox(8)
	card.add_child(box)
	var id := String(res.id)
	var head := W.label(L.t("camp.passed" if bool(res.passed) else "camp.failed", {"title": L.t("camp.%s.title" % id)}), &"Speaker")
	head.add_theme_color_override("font_color", ThemeFactory.LAMP if bool(res.passed) else ThemeFactory.BLOOD)
	box.add_child(head)
	if bool(res.passed):
		var st := W.label(Campaign.stars_text(int(res.stars)), &"Title")
		st.name = "Stars"
		st.add_theme_color_override("font_color", ThemeFactory.LAMP)
		box.add_child(st)
	if compact:
		var goals: Array = res.get("goals", [])
		var complete := goals.filter(func(goal: Dictionary) -> bool: return bool(goal.done)).size()
		if not goals.is_empty():
			box.add_child(W.label(L.t("end.goals_summary", {"done": complete, "count": goals.size()}), &"Small"))
	else:
		box.add_child(PrologueScreen.goals_card(m, Game.chapter, res))
	var lost: Array = res.get("lost", [])
	if bool(res.passed) and bool(res.get("replay", false)):
		var note := W.label(L.t("camp.replay_note", {"stars": Campaign.stars_text(int(res.get("best", res.stars)))}), &"Hint")
		note.name = "ReplayNote"
		box.add_child(note)
	elif bool(res.passed) and (not lost.is_empty() or not (res.get("lost_guests", PackedStringArray()) as PackedStringArray).is_empty()):
		var names: Array[Villager] = []
		for v: Villager in m.villagers:
			var lg: PackedStringArray = res.get("lost_guests", PackedStringArray())
			if (v.guest_id.is_empty() and lost.has(v.story_id)) or (not v.guest_id.is_empty() and lg.has(v.guest_id)):
				names.append(v)
		box.add_child(W.label(L.t("camp.lost_for_good", {"list": names}), &"Hint"))
	elif not bool(res.passed):
		box.add_child(W.label(L.t("camp.retry_note"), &"Hint"))
	if compact and bool(res.passed) and id == "a4c3":
		var final_button := W.button(L.t("fin.btn"))
		final_button.name = "FinalNight"
		final_button.pressed.connect(func() -> void: _final_night(box, final_button))
		box.add_child(final_button)
	if not compact and bool(res.passed) and Campaign.last_of_act(id):
		var end := W.label(Campaign.act_ending(int(Game.chapter.get("act", 1))), &"Tale")
		end.name = "ActEnd"
		box.add_child(end)
		# разгадка «Пустой лодки» (TASK-018): только если игрок собрал достаточно находок
		if id == "a1c3" and Campaign.boat_clues() >= Campaign.BOAT_SOLVED:
			var b := Revelations.beat("boat_answer", m)
			var bt := W.label(String(b[0]), &"Speaker")
			bt.name = "BoatAnswer"
			box.add_child(bt)
			var bx := W.label(String(b[1]), &"Tale")
			bx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(bx)
	return card


## Последняя ночь (TASK-035): сцена у двери, выбор, концовка в книгу концовок и эпилог по всем жителям.
func _final_night(box: Control, btn: Button) -> void:
	btn.disabled = true
	var choice: String = await ScenePlayer.play(self, Scenes.final_door(), m)
	if not is_instance_valid(box):
		return
	var shown_final := false
	if Save.comics_on and (not Juice.instant or SlidePlayer.instant_play):
		var ending := Campaign.final_ending("open" if choice == "open" else "train", m)
		shown_final = Slides.has_deck(Slides.final_deck(ending))
		await SlidePlayer.play(self, Slides.final_deck(ending), true)      # финал показывается всегда: он конец кампании
		if not is_instance_valid(box):
			return
	if not shown_final:
		await ScenePlayer.play(self, Scenes.final_shore() if choice == "open" else Scenes.final_train(), m)
	if not is_instance_valid(box):
		return
	box.add_child(final_card(m, choice))


static func final_card(mm: Match, choice: String) -> PanelContainer:
	var ending := Campaign.final_ending("open" if choice == "open" else "train", mm)
	if not Save.endings.has(ending):
		Save.record_progress(0, [], PackedStringArray([ending]), PackedStringArray())
	var card := W.panel(&"Sheet")
	card.name = "FinalEnding"
	var b := W.vbox(8)
	card.add_child(b)
	b.add_child(W.label(L.t("ending." + ending), &"Speaker"))
	var t := W.label(L.t("fin." + ending), &"Tale")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(t)
	for line: String in Campaign.epilogue_lines(mm, ending):
		var l := W.label(line, &"Small")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(l)
	return card


## «Их память» (TASK-015): 2–4 строки о том, что жители запомнили из этой главы. По одной на человека,
## самые важные первыми. Ничего не запомнили — карточки нет.
static func memory_lines(mm: Match, limit: int = 4) -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary = {}
	for rec: Dictionary in mm.world.campaign_records(mm):
		var idx := int(rec.who)
		if seen.has(idx):
			continue
		var who: Villager = null
		for v: Villager in mm.villagers:
			if v.story_id == idx and not v.is_player and v.guest_id.is_empty():
				who = v
		var key := "memo." + String(rec.kind)
		if who == null or not L.has(key):
			continue
		seen[idx] = true
		out.append(L.t(key, {"who": who}))
		if out.size() >= limit:
			break
	return out


static func memory_card(mm: Match) -> PanelContainer:
	var lines := memory_lines(mm)
	if lines.is_empty():
		return null
	var card := W.panel(&"Page")
	card.name = "TheirMemory"
	var box := W.vbox(6)
	card.add_child(box)
	box.add_child(W.label(L.t("memo.title"), &"Speaker"))
	for l: String in lines:
		var lab := W.label(l, &"Small")
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(lab)
	return card


func _chapter_buttons(res: Dictionary, quick: bool = false) -> void:
	var id := String(res.id)
	var next := Campaign.next_of(id)
	var main: Button
	if bool(res.passed) and not next.is_empty():
		main = W.button(L.t("camp.next", {"title": L.t("camp.%s.title" % next)}))
		main.pressed.connect(func() -> void: commit(Intent.PLAY_CHAPTER, {"id": next}))
	elif bool(res.passed):
		main = W.button(L.t("camp.to_chapters"))
		main.pressed.connect(func() -> void: commit(Intent.OPEN_CAMPAIGN))
	else:
		main = W.button(L.t("camp.retry"))
		main.pressed.connect(func() -> void: commit(Intent.PLAY_CHAPTER, {"id": id}))
	main.name = "ChapterNext"
	footer.add_child(main)
	if quick:
		main.theme_type_variation = &"Ghost"
		if bool(res.passed) and not next.is_empty():
			main.text = L.t("end.quick_next", {"title": L.t("camp.%s.title" % next)})
		return
	var chapters := W.button(L.t("camp.chapters"), &"Ghost")
	chapters.pressed.connect(func() -> void: commit(Intent.OPEN_CAMPAIGN))
	footer.add_child(chapters)


## Конец главы (Task 55): картинка исхода, если она есть, заголовок и кто дожил до утра.
## Картинки: assets/scenes/end_people.png (люди выстояли), assets/scenes/end_upyri.png (посёлок пал).
const END_ART := {true: "res://assets/scenes/end_people.jpg", false: "res://assets/scenes/end_upyri.jpg"}
const SLIDE_SEC := 6.0          ## сколько держится каждый слайд финала
var slides: Control             ## заставка финала поверх экрана; null — закрыта


func ending_card(people_won: bool, won: bool) -> PanelContainer:
	var card := W.panel(&"Sheet")
	card.name = "Ending"
	card.set_meta("people_won", people_won)
	var box := W.vbox(10)
	card.add_child(box)
	var title := W.label(L.t("end.people" if people_won else "end.upyri"), &"Title")
	title.add_theme_font_size_override("font_size", ThemeFactory.fs(29))
	title.add_theme_color_override("font_color", ThemeFactory.LAMP if people_won else ThemeFactory.BLOOD)
	box.add_child(title)
	box.add_child(W.label(L.t("end.won" if won else "end.lost"), &"Tale"))
	var art_path: String = END_ART[people_won]
	if ResourceLoader.exists(art_path):
		var art := TextureRect.new()
		art.name = "EndArt"
		art.texture = load(art_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var fit_art := func() -> void:
			art.custom_minimum_size.y = clampf(size.y * 0.22, 112.0, 260.0)
		resized.connect(fit_art)
		fit_art.call()
		box.add_child(art)
	var alive: Array[Villager] = m.alive()
	var survivors := W.label(L.t("end.survivors", {"list": alive}) if not alive.is_empty() else L.t("end.nobody"), &"Small")
	survivors.name = "Survivors"
	box.add_child(survivors)
	return card


## Заставка финала: картинка исхода медленно проплывает, два слайда с текстом и звуком сцены.
## Тап — пропустить. Через два слайда закрывается сама.
func open_slides() -> Control:
	var people_won := m.winner == Match.Team.PEOPLE
	var path: String = END_ART[people_won]
	if slides != null or not ResourceLoader.exists(path) or not is_inside_tree():
		return slides
	var vp := get_viewport_rect().size
	slides = Control.new()
	slides.name = "Slides"
	slides.top_level = true
	slides.z_index = 100
	slides.position = Vector2.ZERO
	slides.size = vp
	slides.mouse_filter = Control.MOUSE_FILTER_STOP
	slides.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			close_slides())
	add_child(slides)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.035)
	bg.size = vp
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slides.add_child(bg)
	# картинка: по высоте 62% экрана, по ширине шире экрана — её проводит слева направо
	var frame := Control.new()
	frame.name = "Frame"
	frame.clip_contents = true
	frame.size = Vector2(vp.x, vp.y * 0.62)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slides.add_child(frame)
	var tex: Texture2D = load(path)
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	var h := frame.size.y * 1.06
	var w := maxf(h * tex.get_width() / float(tex.get_height()), vp.x * 1.2)
	art.size = Vector2(w, h)
	art.position = Vector2(0.0, -frame.size.y * 0.03)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	var fade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.025, 0.035, 0.0))
	g.set_color(1, Color(0.02, 0.025, 0.035, 1.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	fade.texture = gt
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.position = Vector2(0, frame.size.y * 0.7)
	fade.size = Vector2(vp.x, frame.size.y * 0.3 + 2)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slides.add_child(fade)
	var col := VBoxContainer.new()
	col.name = "Captions"
	col.position = Vector2(vp.x * 0.08, vp.y * 0.6)
	col.size = Vector2(vp.x * 0.84, vp.y * 0.32)
	col.add_theme_constant_override("separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slides.add_child(col)
	var title := W.label(L.t("end.people" if people_won else "end.upyri"), &"Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ThemeFactory.LAMP if people_won else ThemeFactory.BLOOD)
	col.add_child(title)
	var cap := W.label(slide_text(0), &"Tale")
	cap.name = "Caption"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	var skip := W.label(L.t("end.slide_skip"), &"Hint")
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip.position = Vector2(0, vp.y * 0.93)
	skip.size = Vector2(vp.x, 40)
	slides.add_child(skip)
	Sfx.set_music(music(), 0.4)
	_run_slides(art, cap, w - vp.x)
	return slides


## Текст слайда: 0 — что стало с посёлком, 1 — кто дожил (или кто смотрит из леса).
func slide_text(i: int) -> String:
	var people_won := m.winner == Match.Team.PEOPLE
	if i == 0:
		return L.t("end.slide_people_1" if people_won else "end.slide_upyri_1")
	if people_won:
		var alive: Array[Villager] = m.alive()
		return L.t("end.slide_people_2", {"list": alive}) if not alive.is_empty() else L.t("end.nobody")
	var upyri: Array[Villager] = []
	for v: Villager in m.villagers:
		if v.is_upyr:
			upyri.append(v)
	return L.t("end.slide_upyri_2", {"list": upyri})


func _run_slides(art: TextureRect, cap: Label, travel: float) -> void:
	slides.modulate.a = 0.0
	var tw := Juice.tween()
	tw.tween_property(slides, "modulate:a", 1.0, 0.8)
	var pan := Juice.tween()
	pan.tween_property(art, "position:x", -travel, SLIDE_SEC * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await Juice.wait(SLIDE_SEC)
	if slides == null or not is_instance_valid(cap):
		return
	var out := Juice.tween()
	out.tween_property(cap, "modulate:a", 0.0, 0.5)
	await out.finished
	if slides == null or not is_instance_valid(cap):
		return
	cap.text = slide_text(1)
	Juice.tween().tween_property(cap, "modulate:a", 1.0, 0.6)
	await Juice.wait(SLIDE_SEC)
	close_slides()


func close_slides() -> void:
	if slides == null:
		return
	var s := slides
	slides = null
	if not is_instance_valid(s):
		return
	if Juice.instant:
		s.queue_free()
		return
	var tw := Juice.tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.6)
	tw.tween_callback(s.queue_free)
	if _act_end_due():
		_play_act_end.call_deferred()


## Комиксы после главы (TASK-106): победа или поворот, у последней главы акта ещё и итог акта.
## Вместо двухслайдовой заставки итога. Нет колод или они уже просмотрены: идёт прежняя заставка.
func _comics_end_due() -> bool:
	return not Game.chapter.is_empty() and not Game.chapter_result.is_empty() and Save.comics_on \
		and (not Juice.instant or SlidePlayer.instant_play)


func _play_comics_end() -> void:
	var ch := String(Game.chapter.get("id", ""))
	var passed := bool(Game.chapter_result.get("passed", false))
	var shown := await SlidePlayer.play(self, "%s_%s" % [ch, "win" if passed else "twist"])
	if not is_inside_tree():
		return
	var act := int(Game.chapter.get("act", 0))
	var act_deck := ""
	if passed and Campaign.last_of_act(ch) and act >= 1 and act <= 3:
		act_deck = Slides.act_outro_deck(act, Campaign.act_ending_id(act).get_slice("_", 1))
		if act == 3 and Campaign.trial_lost():
			act_deck = Slides.act_outro_deck(3, "trial")
		if not act_deck.is_empty() and await SlidePlayer.play(self, act_deck):
			shown = true
			if not is_inside_tree():
				return
	if not shown and not Juice.instant:
		open_slides()
	if _act_end_due() and not Game.scenes_done.has("act_end") and act_deck.is_empty():
		_play_act_end.call_deferred()
	elif not act_deck.is_empty():
		Game.scenes_done["act_end"] = true


## После слайдов итога главы, которой кончается акт II или III, идёт сцена конца акта. Раз за партию.
func _act_end_due() -> bool:
	if Game.chapter.is_empty() or Game.chapter_result.is_empty() or not bool(Game.chapter_result.get("passed", false)):
		return false
	var act := int(Game.chapter.get("act", 0))
	return (act == 2 or act == 3) and Campaign.last_of_act(String(Game.chapter.id)) and not Game.scenes_done.has("act_end")


func _play_act_end() -> void:
	if not is_inside_tree():
		return
	Game.scenes_done["act_end"] = true
	await ScenePlayer.play(self, Scenes.act_end(int(Game.chapter.get("act", 0)), m), m)


func music() -> StringName:
	if m != null and m.winner == Match.Team.PEOPLE and not Game.chapter.is_empty():
		var theme := Sfx.act_theme(int(Game.chapter.get("act", 1)))
		return theme if theme != &"" else &"theme_sad"
	return &""


## Разоблачение упырей: портрет наливается кровью, упырь говорит последнее слово.
func reveal_cards() -> Control:
	var upyri: Array[Villager] = []
	for v: Villager in m.villagers:
		if v.is_upyr and not v.is_player:
			upyri.append(v)
	if upyri.is_empty():
		return null
	var col := W.vbox(10)
	col.name = "Reveal"
	col.add_child(W.label(L.t("end.reveal"), &"Speaker"))
	var words := Phrases.b("UPYR_REVEAL")
	var k := 0
	for v: Villager in upyri:
		var card := W.panel(&"Card")
		card.name = "Reveal_%d" % v.id
		var row := W.hbox(14)
		var p := W.portrait(v, Vector2(64, 116))
		if not v.alive:
			p.modulate.a = 0.72
		row.add_child(p)
		var box := W.vbox(4)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := W.label(L.t("end.was_upyr", {"who": v}), &"Body")
		nm.add_theme_color_override("font_color", ThemeFactory.BLOOD)
		box.add_child(nm)
		var fate := "end.fate_exiled" if v.exiled else ("end.fate_dead" if not v.alive else "end.fate_alive")
		box.add_child(W.label(L.t(fate, {"who": v}), &"Small"))
		if not words.is_empty():
			box.add_child(W.label("«%s»" % L.fill(words[(v.id + k) % words.size()], {"me": v, "player_name": m.player().name}), &"Tale"))
		row.add_child(box)
		card.add_child(row)
		col.add_child(card)
		k += 1
	return col


## Лицо медленно наливается красным: был человеком — оказался упырём.
func _bleed(p: TextureRect, delay: float) -> void:
	var shade := Color(1.0, 0.45, 0.42, p.modulate.a)
	if Juice.instant:
		p.modulate = shade
		return
	await Juice.wait(delay)
	if is_instance_valid(p):
		Juice.tween().tween_property(p, "modulate", shade, 0.55)


## Главное в разборе: что решило твою партию — и, если тебя не стало, почему.
func _verdict_card(compact: bool = false) -> Control:
	var card := W.panel(&"Sheet")
	card.name = "Verdict"
	var box := W.vbox(8)
	card.add_child(box)
	box.add_child(W.label(L.t("end.verdict"), &"Speaker"))
	box.add_child(W.label(Recap.verdict(m, director), &"Body"))
	if compact:
		return card
	var more := PackedStringArray()
	if m.player().exiled:
		more = Recap.exile_lines(m, director).slice(1)
	elif m.player_death != null:
		more = Recap.death_lines(m, m.player_death).slice(1)
	for l: String in more:
		box.add_child(W.label(l, &"Small"))
	return card


func _offer_card() -> Control:
	var lower := Difficulty.LADDER.find(offer) < Difficulty.LADDER.find(difficulty)
	var card := W.panel(&"Sheet")
	var box := W.vbox(10)
	card.add_child(box)
	box.add_child(W.label(L.t("end.offer_easier" if lower else "end.offer_harder"), &"Speaker"))
	box.add_child(W.label(L.t("diff.note", {"d": Difficulty.title(offer), "text": Difficulty.describe(offer, Difficulty.preset(offer))}), &"Small"))
	var b := W.button(L.t("end.easier" if lower else "end.harder"))
	var target := offer
	b.pressed.connect(func() -> void: commit(Intent.AGAIN, {"difficulty": target}))
	box.add_child(b)
	return card
