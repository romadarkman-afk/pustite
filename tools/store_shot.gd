extends Node
## Скриншоты для страницы в магазине. Аргументы: папка, язык, затем спецификации "метка:вид:глава[:день]".
## Виды: day (день главы), door (ночь у двери), menu, camp (карта кампании), scene (кадр сцены act_prologue акта из метки главы).
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	L.use(a[1])
	Save.hints_seen.clear()
	Save.howto_seen = true
	Juice.instant = true
	Nav.start()
	Save.set_difficulty("easy")
	Weather.enabled = true
	Nav.perf.set_counter_visible(false)
	for k in range(2, a.size()):
		var p: PackedStringArray = a[k].split(":")
		var label := p[0]
		var kind := p[1]
		var ch := p[2] if p.size() > 2 else "a1c1"
		Save.campaign_dead.assign([])
		Save.campaign_memory.clear()
		match kind:
			"menu":
				Nav.show_menu()
				await SelfTest._settle(get_tree())
				await _frames(60)
			"camp":
				Save.campaign_stars.clear()
				for id: String in ["a1c1", "a1c2", "a1c3", "a2c1", "a2c2"]:
					Save.campaign_stars[id] = 3
				Nav.show_campaign()
				await SelfTest._settle(get_tree())
				await _frames(10)
				var cs := Nav.host.current as CampaignScreen
				var mp := cs.find_child("CampaignMap", true, false) as Control
				cs.scroll.scroll_vertical = int(mp.global_position.y - cs.scroll.global_position.y) + cs.scroll.scroll_vertical - 4
				await _frames(10)
			"slide":
				# кадр комикса: метка:slide:колода:номер кадра с нуля:прогресс камеры (0..100, по умолчанию 55)
				Nav.show_menu()
				await SelfTest._settle(get_tree())
				var pl := SlidePlayer.new()
				pl.deck_id = ch
				pl.deck = Slides.deck(ch)
				Nav.host.current.add_child(pl)
				pl._build()
				for n in range(int(p[3]) if p.size() > 3 else 0):
					pl.advance()
				pl._paused = true        # кадр стоит: иначе колода в мгновенном режиме домотается до конца за время съёмки
				if p.size() > 4:
					pl._t = pl._dur * float(p[4]) / 100.0
				await _frames(4)
				pl._apply_cam(float(p[4]) / 100.0 if p.size() > 4 else 0.55)
				await _frames(20)
				print("SHOT slide-debug rect=", pl.get_global_rect(), " view=", pl._view.get_global_rect(), " vis=", pl.is_visible_in_tree(), " stage=", pl._stage.get_global_rect() if pl._stage != null else "нет", " parent=", pl.get_parent().name)
			"day", "door":
				Game.start(Campaign.config(ch), "", Campaign.chapter(ch))
				await SelfTest._settle(get_tree())
				for i in range(8):
					if Game.m != null and Game.m.phase == Match.Phase.PROLOGUE:
						Game.proceed()
						await SelfTest._settle(get_tree())
				await _frames(20)
				if kind == "door":
					Juice.instant = false
					Game.end_day()
					if Game.m.phase == Match.Phase.VOTE:
						Game.vote(-1)
						Game.proceed()
					var guard := 0
					while Game.m.phase != Match.Phase.OVER and guard < 60:
						guard += 1
						await SelfTest._settle(get_tree())
						var s: Screen = Nav.host.current
						if Game.m.phase == Match.Phase.DOOR and s is DoorScreen and (s as DoorScreen).role == Match.DoorRole.HOST and not (s as DoorScreen).seat.queue.is_empty():
							break
						await SelfTest._layout_step("x", PackedStringArray())
					Juice.instant = true
				await _frames(100)
		_clean(get_tree().root)
		await _frames(6)
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, label])
		print("SHOT ", label, " ", kind, " ", ch, " phase=", Game.m.phase if Game.m != null else -1)
		Game.abandon()
	print("DONE")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _clean(n: Node) -> void:
	for c in n.get_children():
		if c is TextSheet:
			(c as TextSheet).close("")
		elif c is ActionSheet:
			(c as ActionSheet).close(-1)
		elif c is Hint:
			c.queue_free()
		else:
			_clean(c)
