extends RefCounted
## Быстрый регрессионный прогон: музыка меню и панель дня на профилях телефонов и планшетов.

static func run() -> void:
	var tree := Nav.get_tree()
	var problems: PackedStringArray = []
	var checks := 0
	await _check_menu_music(tree, problems)
	checks += _expect(problems, Nav.host.current is MenuScreen, "перед тестом раскладки открылось не меню")
	Nav.start_match()
	await SelfTest._settle(tree)
	if Game.m != null and Game.m.phase == Match.Phase.PROLOGUE:
		Game.proceed()
		await SelfTest._settle(tree)
	checks += _expect(problems, Nav.host.current is DayScreen, "одиночная партия не открыла дневной экран")
	if not (Nav.host.current is DayScreen):
		_report(tree, checks, problems)
		return

	var profiles: Array[Array] = []
	for sz: Vector2i in SelfTest.LAYOUT_SIZES:
		profiles.append([sz, Vector4(-1, -1, -1, -1), SelfTest.csf])
	for cutout: Array in SelfTest.LAYOUT_CUTOUTS:
		profiles.append([cutout[0], cutout[1], SelfTest.csf])
	profiles.append_array(SelfTest.device_profiles())
	for prof: Array in profiles:
		var sz: Vector2i = prof[0]
		var cut: Vector4 = prof[1]
		Nav.frame.debug_insets = cut
		tree.root.size = sz
		tree.root.content_scale_factor = float(prof[2])
		await SelfTest._settle(tree)
		Nav.frame.refresh()
		await SelfTest._settle(tree)
		var tag := "%d×%d" % [sz.x, sz.y]
		if cut.x >= 0.0:
			tag += " вырез %d/%d" % [int(cut.y), int(cut.w)]
		if prof.size() > 3:
			tag = "%s %s" % [String(prof[3]), tag]
		if Nav.host.current is DayScreen:
			var day := Nav.host.current as DayScreen
			checks += _check_day(tag, problems)
			if sz == Vector2i(720, 1280) and cut.x < 0.0 and Save.text_size == 0:
				checks += await _check_compact_day_ui(tree, day, problems)
		else:
			problems.append("%s: после изменения размера сменился экран партии" % tag)
		checks += _check_all_map_bounds(tag, problems)

	tree.root.content_scale_factor = 1.0
	Nav.frame.debug_insets = Vector4(-1, -1, -1, -1)
	_report(tree, checks, problems)


static func _check_compact_day_ui(tree: SceneTree, screen: DayScreen, problems: PackedStringArray) -> int:
	var checks := 0
	var vp := Nav.frame.get_viewport_rect().size
	var rows: Array[FitRow] = []
	for child: Node in screen.footer.get_children():
		if child is FitRow:
			rows.append(child as FitRow)
	checks += _expect(problems, rows.size() >= 2 and rows[1]._mode == FitRow.Mode.ROW,
		"720×1280: действия дня не помещаются в два ряда")
	checks += _expect(problems, screen.field_spacer.size.y >= vp.y * 0.50,
		"720×1280: игровому полю осталось только %.0f%% высоты" % (100.0 * screen.field_spacer.size.y / maxf(vp.y, 1.0)))

	var diary := DiarySheet.open(screen, Game.m, Game.director)
	await SelfTest._settle(tree)
	var panel := diary.find_child("DiaryPanel", true, false) as Control
	var scroll := diary.find_child("DiaryScroll", true, false) as ScrollContainer
	var close_button := diary.find_child("DiaryClose", true, false) as Button
	if panel != null:
		var rect := panel.get_global_rect()
		checks += _expect(problems, rect.position.y >= -1.0 and rect.end.y <= vp.y + 1.0 and rect.size.y <= vp.y * 0.84,
			"720×1280: дневник занимает %.0f%% экрана или выходит за край" % (100.0 * rect.size.y / maxf(vp.y, 1.0)))
	else:
		checks += _expect(problems, false, "720×1280: панель дневника не найдена")
	checks += _expect(problems, scroll != null and scroll.size.y >= vp.y * 0.28,
		"720×1280: область записей дневника слишком мала")
	checks += _expect(problems, panel != null and close_button != null and panel.get_global_rect().encloses(close_button.get_global_rect()),
		"720×1280: кнопка закрытия дневника уехала за панель")
	diary.close()
	await SelfTest._settle(tree)
	return checks


static func _check_menu_music(tree: SceneTree, problems: PackedStringArray) -> void:
	Nav.show_menu()
	await SelfTest._settle(tree)
	var available: Array[StringName] = []
	var invalid_menu_streams: PackedStringArray = PackedStringArray()
	for k: StringName in Sfx.SONGS:
		if not Sfx.has_sound(k):
			continue
		available.append(k)
		var st := Sfx._streams[k] as AudioStream
		if st.get_length() <= 0.0:
			invalid_menu_streams.append("%s: неверная длительность %.1f с" % [k, st.get_length()])
		var is_loop := st is AudioStreamOggVorbis and (st as AudioStreamOggVorbis).loop
		is_loop = is_loop or (st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED)
		if is_loop:
			invalid_menu_streams.append("%s: поток зациклен" % k)
	var missing_story_loops := PackedStringArray()
	for k: StringName in available:
		var story_stream := Sfx._song_loop_streams.get(k) as AudioStream
		var story_loops := story_stream is AudioStreamOggVorbis and (story_stream as AudioStreamOggVorbis).loop
		story_loops = story_loops or (story_stream is AudioStreamWAV and (story_stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
		if not story_loops:
			missing_story_loops.append(String(k))
	_expect(problems, available.size() >= 2, "для смены песни в меню загружено меньше двух треков")
	_expect(problems, missing_story_loops.is_empty(), "песни для финальных сцен потеряли зацикливание: %s" % ", ".join(missing_story_loops))
	_expect(problems, invalid_menu_streams.is_empty(), "ошибка потоков песен меню: %s" % ", ".join(invalid_menu_streams))
	var first := Sfx.menu_music()
	_expect(problems, available.has(first), "меню не выбрало загруженную песню: %s" % first)
	_expect(problems, Sfx.menu_music() == first, "переход между меню и вкладками меняет песню")
	var saved_bag: Array[StringName] = []
	saved_bag.append_array(Sfx._menu_song_bag)
	var saved_last := Sfx._last_menu_song
	Sfx._menu_song_bag.clear()
	Sfx._last_menu_song = &""
	var cycle: Array[StringName] = []
	for i in range(available.size()):
		cycle.append(Sfx._pick_menu_song())
	var unique_songs: Dictionary = {}
	var cycle_names := PackedStringArray()
	for song: StringName in cycle:
		unique_songs[song] = true
		cycle_names.append(String(song))
	Sfx._menu_song_bag.clear()
	Sfx._menu_song_bag.append_array(saved_bag)
	Sfx._last_menu_song = saved_last
	_expect(problems, cycle.size() == available.size() and unique_songs.size() == available.size(),
		"плейлист меню повторяет песню до конца очереди: %s" % ", ".join(cycle_names))
	if available.size() < 2:
		return
	Sfx.set_music(first, 0.0)
	await SelfTest._frames(tree, 3)
	_expect(problems, Sfx.music_name == first and Sfx._music_p.playing and Sfx._music_p.stream == Sfx._streams[first], "меню не запустило полный, незацикленный трек")
	Sfx._music_p.stop()
	Sfx._on_music_finished()
	await SelfTest._frames(tree, 3)
	var next := Sfx.menu_music()
	_expect(problems, next != first and Sfx._music_p.playing and Sfx._music_p.stream == Sfx._streams[next], "после окончания песни не включился другой, незацикленный трек")
	Nav.show_settings()
	await SelfTest._settle(tree)
	_expect(problems, Sfx.music_name == next, "песня прерывается при открытии настроек")
	Nav.show_menu()
	await SelfTest._settle(tree)
	_expect(problems, Sfx.music_name == next, "песня прерывается при возвращении в главное меню")


static func _check_day(tag: String, problems: PackedStringArray) -> int:
	var screen := Nav.host.current as DayScreen
	if screen == null:
		problems.append("%s: дневной экран не открыт" % tag)
		return 1
	var vp := Nav.frame.get_viewport_rect().size
	var footer := screen.footer.get_global_rect()
	if footer.end.y > vp.y + 1.0:
		problems.append("%s: нижняя панель выходит за экран (%d > %d)" % [tag, int(footer.end.y), int(vp.y)])
	var last_button_bottom := 0.0
	for control: Control in SelfTest._controls(screen):
		if control is BaseButton and control.is_visible_in_tree():
			last_button_bottom = maxf(last_button_bottom, control.get_global_rect().end.y)
	if last_button_bottom > vp.y - 12.0:
		problems.append("%s: нижние кнопки слишком близко к краю экрана (%d из %d)" % [tag, int(last_button_bottom), int(vp.y)])
	var bounds := Nav.village._ground_draw_rect()
	var left_edge := Nav.village.position.x + bounds.position.x * Nav.village.scale.x
	var right_edge := Nav.village.position.x + bounds.end.x * Nav.village.scale.x
	var field_width := Nav.village._vp_w
	if left_edge > -1.0 or right_edge < field_width + 1.0:
		problems.append("%s: виден край земли карты (%d…%d из %d; масштаб %.3f, камера %.1f)" % [tag, int(left_edge), int(right_edge), int(field_width), Nav.village.scale.x, Nav.village.cam_x])
	for c: Control in SelfTest._controls(screen):
		if not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		if c is BaseButton:
			if r.position.x < -1.0 or r.end.x > vp.x + 1.0:
				problems.append("%s: кнопка вылезает за экран: %s" % [tag, SelfTest._label_of(c)])
			if r.size.y < SelfTest.MIN_TOUCH - 0.5:
				problems.append("%s: слишком маленькая зона нажатия: %s (%d px)" % [tag, SelfTest._label_of(c), int(r.size.y)])
		if c is Button and not (c as Button).text.is_empty():
			var b := c as Button
			var font := b.get_theme_font("font")
			var font_size := b.get_theme_font_size("font_size")
			var style := b.get_theme_stylebox("normal")
			var pad := style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
			if b.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var need := font.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + pad
				if r.size.x + 1.0 < need:
					problems.append("%s: подпись обрезана: %s" % [tag, b.text.left(30)])
			else:
				for word: String in b.text.replace("\n", " ").split(" ", false):
					var need := SelfTest._unbreakable_width(word, font, font_size) + pad
					if r.size.x + 1.0 < need:
						problems.append("%s: слово обрезано в кнопке: %s" % [tag, word])
						break
				var text_height := font.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad, font_size).y
				if r.size.y + 1.0 < text_height:
					problems.append("%s: подпись не помещается по высоте: %s" % [tag, b.text.left(30)])
	return 1


static func _check_all_map_bounds(tag: String, problems: PackedStringArray) -> int:
	var view: VillageView = Nav.village
	if view == null or view.scale.x <= 0.0:
		problems.append("%s: поле посёлка не готово для проверки границ карты" % tag)
		return 1
	var saved_def := view.def
	var vp_w := view._vp_w
	var half := vp_w / (2.0 * view.scale.x)
	var count := 0
	for map_id: String in Campaign.SOLO_MAP_IDS:
		var def := load(String(Campaign.MAPS[map_id])) as VillageDef
		if def == null:
			problems.append("%s: карта %s не загружена" % [tag, map_id])
			count += 1
			continue
		view.def = def
		var bounds := view._ground_draw_rect()
		var left_camera := view._clamp_cam(-100000.0, view.scale.x)
		var right_camera := view._clamp_cam(100000.0, view.scale.x)
		var camera := view._clamp_cam(view.cam_x, view.scale.x)
		var visible_left := vp_w * 0.5 + (bounds.position.x - camera) * view.scale.x
		var visible_right := vp_w * 0.5 + (bounds.end.x - camera) * view.scale.x
		if visible_left > -1.0 or visible_right < vp_w + 1.0:
			problems.append("%s: край карты %s виден (земля %.1f…%.1f, полуширина %.1f, масштаб %.3f, камера %.1f)" % [tag, map_id, bounds.position.x, bounds.end.x, half, view.scale.x, camera])
			count += 1
		if left_camera - half < bounds.position.x - 1.0:
			problems.append("%s: карта %s открывает левую подложку (камера %.1f, полуширина %.1f, край %.1f)" % [tag, map_id, left_camera, half, bounds.position.x])
			count += 1
		if right_camera + half > bounds.end.x + 1.0:
			problems.append("%s: карта %s открывает правую подложку (камера %.1f, полуширина %.1f, край %.1f)" % [tag, map_id, right_camera, half, bounds.end.x])
			count += 1
	view.def = saved_def
	return count


static func _expect(problems: PackedStringArray, ok: bool, message: String) -> int:
	if ok:
		return 1
	problems.append(message)
	return 0


static func _report(tree: SceneTree, checks: int, problems: PackedStringArray) -> void:
	print("=== быстрая проверка музыки и раскладки: %d проверок на экранах телефонов, вырезах, складных устройств и планшетов ===" % checks)
	if problems.is_empty():
		print("ИТОГ: OK — песни меню не обрываются, карта и кнопки остаются в границах экрана")
		tree.quit(0)
	else:
		for problem: String in problems.slice(0, 40):
			print("  ✗ " + problem)
		print("ИТОГ: ОШИБОК: %d" % problems.size())
		tree.quit(1)
