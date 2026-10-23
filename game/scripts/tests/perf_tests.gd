class_name PerfTests
extends RefCounted
## Бюджет ресурсов (TASK-095): четыре карты ночью в непогоду, главы a1c3, a2c1, a3c1, a4c1.
## Считается то, что не зависит от железа: узлы, объекты, эмиттеры и частицы, звуковые потоки,
## декодированные картинки в памяти, среднее время скриптов за кадр. Кадры на телефоне в docs/budget.md отдельно.
## Замер после правок TASK-095 (меню 135,6; ночь 135,0 / 139,3 / 145,7 / 158,4 МиБ; частиц 138–187; скрипты 1,9–2,3 мс).
## Лимиты на 10–25% выше замера: ловят рост, а не шум.

const CHAPTERS: PackedStringArray = ["a1c3", "a2c1", "a3c1", "a4c1"]
const MAX_NODES := 450
const MAX_OBJECTS := 4600
const MAX_EMITTERS := 14
const MAX_PARTICLES := 220          ## сумма amount у горящих эмиттеров на полной графике; в упрощённой вдвое меньше (проверяет --weather)
const MAX_STREAMS := 8              ## проигрывается одновременно; длинных потоков не больше шести плюс короткие
const MAX_RESIDENT_MIB := 185.0     ## картинки assets/, живые в кэше, в развёрнутом виде (ширина × высота × 4)
const MAX_MENU_MIB := 150.0         ## то же в меню сразу после запуска: посёлок рисуется и там, дневные и ночные дома в памяти вместе
const MAX_PROCESS_MS := 25.0        ## среднее время скриптов за кадр (headless, сервер CI)
const MAX_BOOT_MS := 15000          ## от запуска процесса до начала теста
const MAX_NIGHT_WAIT_FRAMES := 1500


static func _files(root: String, out: PackedStringArray) -> void:
	var da := DirAccess.open(root)
	if da == null:
		return
	for f: String in da.get_files():
		if f.ends_with(".png") or f.ends_with(".jpg") or f.ends_with(".webp"):
			out.append(root + "/" + f)
	for d: String in da.get_directories():
		_files(root + "/" + d, out)


## Развёрнутый размер картинок из assets/, которые сейчас держит кэш ресурсов, в МиБ.
static func resident_mib() -> float:
	var all := PackedStringArray()
	_files("res://assets", all)
	var total := 0
	for path: String in all:
		if ResourceLoader.has_cached(path):
			var t := load(path) as Texture2D
			if t != null:
				total += t.get_width() * t.get_height() * 4
	return float(total) / 1048576.0


## Что занимает память: каталоги и самые тяжёлые файлы. Идёт в журнал, чтобы при превышении было видно виновника.
static func breakdown(label: String) -> void:
	var all := PackedStringArray()
	_files("res://assets", all)
	var rows: Array = []
	var by_dir := {}
	for path: String in all:
		if ResourceLoader.has_cached(path):
			var t := load(path) as Texture2D
			if t != null:
				var b := t.get_width() * t.get_height() * 4
				rows.append([b, path.trim_prefix("res://assets/"), t.get_width(), t.get_height()])
				var d := path.trim_prefix("res://assets/").get_base_dir()
				by_dir[d] = int(by_dir.get(d, 0)) + b
	rows.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var dirs: Array = by_dir.keys()
	dirs.sort_custom(func(x: String, y: String) -> bool: return by_dir[x] > by_dir[y])
	var s := "  %s, каталоги:" % label
	for d: String in dirs.slice(0, 6):
		s += " %s %.1f;" % [d, float(by_dir[d]) / 1048576.0]
	print(s)
	s = "  %s, тяжёлые:" % label
	for r: Array in rows.slice(0, 6):
		s += " %s %dx%d %.1f;" % [r[1], r[2], r[3], float(r[0]) / 1048576.0]
	print(s)


static func _count(n: Node, acc: Dictionary) -> void:
	if n is AudioStreamPlayer or n is AudioStreamPlayer2D:
		if (n as Node).get("playing"):
			acc.streams += 1
	if n is GPUParticles2D or n is CPUParticles2D:
		acc.emitters += 1
		if n.emitting:
			acc.particles += int(n.amount)
	for c: Node in n.get_children():
		_count(c, acc)


static func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var fails := PackedStringArray()
	var ok := 0
	var boot_ms := Time.get_ticks_msec()
	ok += SelfTest._expect(fails, boot_ms < MAX_BOOT_MS, "до начала теста %d мс, предел %d" % [boot_ms, MAX_BOOT_MS])
	Save.hints_seen.clear()
	Save.howto_seen = true
	Save.set_difficulty("easy")
	Weather.enabled = true
	Weather.forced_season = -1
	Nav.village.set_simplified_graphics(false)
	Nav.show_menu()
	await SelfTest._settle(tree)
	for i in range(30):
		await tree.process_frame
	var menu_mib := resident_mib()
	breakdown("меню")
	print("меню: картинок в памяти %.1f МиБ (предел %.0f), старт %d мс" % [menu_mib, MAX_MENU_MIB, boot_ms])
	ok += SelfTest._expect(fails, menu_mib <= MAX_MENU_MIB, "меню держит %.1f МиБ картинок, предел %.0f" % [menu_mib, MAX_MENU_MIB])

	for id: String in CHAPTERS:
		Juice.instant = true
		Save.campaign_dead.assign([])
		Save.campaign_memory.clear()
		Game.start(Campaign.config(id), "", Campaign.chapter(id))
		await SelfTest._settle(tree)
		for i in range(8):
			if Game.m != null and Game.m.phase == Match.Phase.PROLOGUE:
				Game.proceed()
				await SelfTest._settle(tree)
		for i in range(20):
			await tree.process_frame
		Juice.instant = false
		Game.end_day()
		if Game.m.phase == Match.Phase.VOTE:
			Game.vote(-1)
			Game.proceed()
		var waited := 0
		while waited < MAX_NIGHT_WAIT_FRAMES and not (Game.m.phase == Match.Phase.NIGHT and Nav.village.night > 0.99):
			await tree.process_frame
			waited += 1
		for i in range(60):
			await tree.process_frame
		var proc := 0.0
		var frames := 120
		for i in range(frames):
			await tree.process_frame
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
		var acc := {"streams": 0, "emitters": 0, "particles": 0}
		_count(tree.root, acc)
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var mib := resident_mib()
		var avg_ms := 1000.0 * proc / float(frames)
		print("%s: ночь %.2f, узлов %d, объектов %d, эмиттеров %d, частиц %d, потоков %d, картинок %.1f МиБ, скрипты %.2f мс за кадр, погода %s" % [
			id, Nav.village.night, nodes, objects, acc.emitters, acc.particles, acc.streams, mib, avg_ms, str(Nav.village.weather.emitter_names())])
		ok += SelfTest._expect(fails, Nav.village.ground_fx.bound_ground() == Nav.village.ground_texture(), "%s: слой погоды держит землю другой карты" % id)
		ok += SelfTest._expect(fails, Game.m.phase == Match.Phase.NIGHT and Nav.village.night > 0.99, "%s: ночь не наступила за %d кадров" % [id, waited])
		ok += SelfTest._expect(fails, nodes <= MAX_NODES, "%s: узлов %d, предел %d" % [id, nodes, MAX_NODES])
		ok += SelfTest._expect(fails, objects <= MAX_OBJECTS, "%s: объектов %d, предел %d" % [id, objects, MAX_OBJECTS])
		ok += SelfTest._expect(fails, acc.emitters <= MAX_EMITTERS, "%s: эмиттеров %d, предел %d" % [id, acc.emitters, MAX_EMITTERS])
		ok += SelfTest._expect(fails, acc.particles <= MAX_PARTICLES, "%s: частиц %d, предел %d" % [id, acc.particles, MAX_PARTICLES])
		ok += SelfTest._expect(fails, acc.streams <= MAX_STREAMS, "%s: звуков одновременно %d, предел %d" % [id, acc.streams, MAX_STREAMS])
		ok += SelfTest._expect(fails, mib <= MAX_RESIDENT_MIB, "%s: картинок в памяти %.1f МиБ, предел %.0f" % [id, mib, MAX_RESIDENT_MIB])
		ok += SelfTest._expect(fails, avg_ms <= MAX_PROCESS_MS, "%s: скрипты %.1f мс за кадр, предел %.0f" % [id, avg_ms, MAX_PROCESS_MS])
		breakdown(id)
		Game.abandon()
	Juice.instant = true
	SelfTest._finish(fails, ok, "РЕСУРСЫ", "4 карты ночью в непогоду: узлы, частицы, звуки, картинки в памяти и время скриптов в пределах")
