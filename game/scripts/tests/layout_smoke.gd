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
			checks += _check_day(tag, problems)
		else:
			problems.append("%s: после изменения размера сменился экран партии" % tag)
		checks += _check_all_map_bounds(tag, problems)

	tree.root.content_scale_factor = 1.0
	Nav.frame.debug_insets = Vector4(-1, -1, -1, -1)
	_report(tree, checks, problems)


static func _check_menu_music(tree: SceneTree, problems: PackedStringArray) -> void:
	var available: Array[StringName] = []
	var looping: PackedStringArray = PackedStringArray()
	for k: StringName in Sfx.SONGS:
		if not Sfx.has_sound(k):
			continue
		available.append(k)
		var st := Sfx._streams[k] as AudioStream
		var is_loop := st is AudioStreamOggVorbis and (st as AudioStreamOggVorbis).loop
		is_loop = is_loop or (st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED)
		if is_loop:
			looping.append(String(k))
	var missing_story_loops := PackedStringArray()
	for k: StringName in available:
		var story_stream := Sfx._song_loop_streams.get(k) as AudioStream
		var story_loops := story_stream is AudioStreamOggVorbis and (story_stream as AudioStreamOggVorbis).loop
		story_loops = story_loops or (story_stream is AudioStreamWAV and (story_stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
		if not story_loops:
			missing_story_loops.append(String(k))
	_expect(problems, available.size() >= 2, "для смены песни в меню загружено меньше двух треков")
	_expect(problems, missing_story_loops.is_empty(), "песни для финальных сцен потеряли зацикливание: %s" % ", ".join(missing_story_loops))
	_expect(problems, looping.is_empty(), "песни меню зациклены и могут начинаться заново: %s" % ", ".join(looping))
	var first := Sfx.menu_music()
	_expect(problems, available.has(first), "меню не выбрало загруженную песню: %s" % first)
	_expect(problems, Sfx.menu_music() == first, "переход между меню и вкладками меняет песню")
	if available.size() < 2:
		return
	Sfx.set_music(first, 0.0)
	Sfx._music_p.stop()
	Sfx._on_music_finished()
	await SelfTest._frames(tree, 3)
	var next := Sfx.menu_music()
	_expect(problems, next != first and Sfx._music_p.playing, "после окончания песни не включился другой трек")
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
	var bounds: Rect2 = Nav.village.def.ground_rect
	var left_edge := Nav.village.to_global(Vector2(bounds.position.x, 0)).x
	var right_edge := Nav.village.to_global(Vector2(bounds.end.x, 0)).x
	if left_edge > -1.0 or right_edge < vp.x + 1.0:
		problems.append("%s: виден край земли карты (%d…%d из %d)" % [tag, int(left_edge), int(right_edge), int(vp.x)])
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
	var vp_w := Nav.frame.get_viewport_rect().size.x
	var half := vp_w / (2.0 * view.scale.x)
	var count := 0
	for map_id: String in Campaign.SOLO_MAP_IDS:
		var def := load(String(Campaign.MAPS[map_id])) as VillageDef
		if def == null:
			problems.append("%s: карта %s не загружена" % [tag, map_id])
			count += 1
			continue
		view.def = def
		var bounds := def.ground_rect
		var left_camera := view._clamp_cam(-100000.0, view.scale.x)
		var right_camera := view._clamp_cam(100000.0, view.scale.x)
		var visible_left := vp_w * 0.5 + (bounds.position.x - view._clamp_cam(view.cam_x, view.scale.x)) * view.scale.x
		var visible_right := vp_w * 0.5 + (bounds.end.x - view._clamp_cam(view.cam_x, view.scale.x)) * view.scale.x
		if visible_left > -1.0 or visible_right < vp_w + 1.0:
			problems.append("%s: край карты %s виден из текущего положения камеры" % [tag, map_id])
			count += 1
		if left_camera - half < bounds.position.x + VillageView.GROUND_BLEED - 1.0:
			problems.append("%s: карта %s открывает левую подложку" % [tag, map_id])
			count += 1
		if right_camera + half > bounds.end.x - VillageView.GROUND_BLEED + 1.0:
			problems.append("%s: карта %s открывает правую подложку" % [tag, map_id])
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
