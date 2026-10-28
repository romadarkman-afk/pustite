class_name SlideTests
extends RefCounted
## Комиксы (TASK-101–109): данные колод, подписи, звуковые карты, камера, заглушки, плеер, раскладка, бюджет картинок.
## Колоды читаются из config/slides.json, их собирает tools/slides/build.py. Картинок может не быть: тогда кадры идут на заглушках.

const DECKS_MIN := 86
const PANELS_MIN := 309
const IMAGE_BUDGET := 160 * 1024 * 1024         ## все картинки комикса вместе: 309 кадров по 0,5 МиБ (TASK-143, фотореализм)
const MAX_PLATE_SHARE := 0.62                   ## подпись не выше этой доли экрана
## Звуки, которых игре ещё не хватает (TASK-124): кадры о них знают, плеер их пропускает.
const SOUNDS_NOT_YET: PackedStringArray = ["wolf", "crow", "fire_crackle", "water_drip", "steps_snow", "chain", "match", "page", "glass", "wind_gust"]
const BANNED: PackedStringArray = ["каша", "каши", "хаос", "жвачк", "методичк", "истерик", "дедлайн", "стероид", "минимал", "честно",
	"нормальн", "большинств", "каждый", "каждая", "каждое", "важно понимать", "стоит отметить", "таким образом"]


static func run() -> void:
	var t0 := Time.get_ticks_msec()
	var fails := PackedStringArray()
	var ok := 0
	ok += data(fails)
	ok += texts(fails)
	ok += sounds(fails)
	ok += await voice(fails)
	ok += await voice_flow(fails)
	ok += images(fails)
	ok += routing(fails)
	ok += await player(fails)
	ok += await hooks(fails)
	ok += await book(fails)
	ok += await geometry(fails)
	print("время %.1f с" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	SelfTest._finish(fails, ok, "Комиксы", "86 колод, подписи на всех кадрах, звуковые карты, камера без пустых краёв, плеер листает и закрывается, подпись помещается на всех экранах")


# ----------------------------------------------------------------- озвучка и песни

## Озвучка кадров, живые возгласы и песни. Файлов может не быть: тогда всё идёт как раньше. Недостающее подставляем в памяти.
static func voice(fails: PackedStringArray) -> int:
	var ok := 0
	# тип голоса по полу и возрасту
	ok += SelfTest._expect(fails, Sfx.voice_type(false, 70) == "m_old" and Sfx.voice_type(true, 61) == "f_old", "тип голоса: старики")
	ok += SelfTest._expect(fails, Sfx.voice_type(true, 34) == "f_mid" and Sfx.voice_type(false, 30) == "m_mid", "тип голоса: средний возраст")
	ok += SelfTest._expect(fails, Sfx.voice_type(true, 19) == "f_young" and Sfx.voice_type(false, 25) == "m_young", "тип голоса: молодые")
	ok += SelfTest._expect(fails, Sfx.voice_type(true, 9) == "boy" and Sfx.voice_type(false, 12) == "boy", "тип голоса: дети")
	# все возрасты и оба пола дают один из восьми типов
	var types := {}
	for age in range(5, 95):
		for f in [false, true]:
			types[Sfx.voice_type(f, age)] = true
	ok += SelfTest._expect(fails, types.size() == 7, "типов голоса %d, ждали 7" % types.size())
	# возглас: без файлов false, а писк играет; с файлами true и не повторяется подряд
	var keep_cache: Dictionary = Sfx._bark_cache.duplicate()
	Sfx._bark_cache.clear()
	Sfx._bark_cache["f_old_calm"] = []
	ok += SelfTest._expect(fails, not Sfx.bark(7, true, 70, ""), "возглас без файлов вернул true")
	Sfx.voice(7, true, 24, "", 70)
	Sfx._bark_cache["f_old_calm"] = [AudioStreamWAV.new(), AudioStreamWAV.new(), AudioStreamWAV.new()]
	Sfx._bark_cache["f_old_fear"] = []
	var last := -1
	var repeats := 0
	for k in range(40):
		ok += SelfTest._expect(fails, Sfx.bark(7, true, 70, "fear"), "возглас при наличии файлов не сыграл (запасной набор calm)")
		var cur := int(Sfx._bark_last.get(7, -1))
		if cur == last:
			repeats += 1
		last = cur
	ok += SelfTest._expect(fails, repeats == 0, "один и тот же возглас подряд %d раз" % repeats)
	Sfx._bark_cache = keep_cache
	Sfx._bark_last.erase(7)
	# файл озвучки: ключ -> путь
	ok += SelfTest._expect(fails, Slides.voice_file("act1_intro.01.0").is_empty() and Slides.voice_file("sl.x").is_empty(), "путь озвучки из чужого ключа")
	var voice_samples: Array[Array] = [
		["sl.prologue.01.0", "res://assets/voice/prologue/01_0.ogg"],
		["sl.act1_intro.03.0", "res://assets/voice/act1_intro/03_0.ogg"],
		["sl.a1c1_intro.03.0", "res://assets/voice/a1c1_intro/03_0.ogg"],
	]
	for sample: Array in voice_samples:
		var voice_key := String(sample[0])
		var expected_path := String(sample[1])
		var voice_path := Slides.voice_file(voice_key)
		ok += SelfTest._expect(fails, voice_path == expected_path, "%s: файл голоса %s, ожидался %s" % [voice_key, voice_path, expected_path])
		var stream: AudioStream = null
		if not voice_path.is_empty():
			stream = load(voice_path) as AudioStream
		ok += SelfTest._expect(fails, stream != null and stream.get_length() > 0.2, "%s: OGG не загружается" % expected_path)
	var old_save := ConfigFile.new()
	old_save.set_value("progress", "slides_seen", "prologue,act1_intro,a1c1_intro,a1c2_intro")
	Save._migrate_3_to_4(old_save)
	var remaining_seen := String(old_save.get_value("progress", "slides_seen", "")).split(",", false)
	ok += SelfTest._expect(fails, not remaining_seen.has("prologue") and not remaining_seen.has("act1_intro") and not remaining_seen.has("a1c1_intro"), "миграция не открыла озвученные вступления")
	ok += SelfTest._expect(fails, remaining_seen.has("a1c2_intro"), "миграция изменила отметки других глав")
	for id: String in Slides.deck_ids():
		for p: Variant in Slides.panels(id):
			var path := Slides.panel_voice(p as Dictionary)
			ok += SelfTest._expect(fails, path.is_empty() or path.begins_with(Sfx.VOICE_DIR + id + "/"), "%s: озвучка лежит не в своей папке: %s" % [id, path])
	# голос из памяти: играет, музыка тише, потом возвращается
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var pcm := PackedByteArray()
	pcm.resize(22050 * 2)
	wav.data = pcm
	var len_s := Sfx.play_voice_stream(wav)
	ok += SelfTest._expect(fails, absf(len_s - 1.0) < 0.05, "длина озвучки %.2f с, ждали 1" % len_s)
	ok += SelfTest._expect(fails, Sfx.voice_line_playing() and Sfx.voice_line_left() > 0.0, "озвучка не играет")
	Sfx.pause_voice_line(true)
	Sfx.pause_voice_line(false)
	Sfx.stop_voice_line()
	ok += SelfTest._expect(fails, not Sfx.voice_line_playing() and Sfx.voice_line_left() == 0.0, "озвучка не остановилась")
	ok += SelfTest._expect(fails, Sfx.play_voice_line("res://assets/voice/нет/нет.ogg") < 0.0, "несуществующий файл озвучки вернул длину")
	# скорость печати под голос
	ok += SelfTest._expect(fails, absf(SlidePlayer.voice_cps(100, 5.0) - 100.0 / 4.65) < 0.01, "скорость печати под голос")
	ok += SelfTest._expect(fails, SlidePlayer.voice_cps(10, 30.0) == 14.0 and SlidePlayer.voice_cps(400, 3.0) == 90.0, "границы скорости печати")
	# песни: колоды существуют, кадр песни внутри колоды, без файла песни играет музыка колоды
	for deck_id: String in Slides.DECK_SONGS:
		var e: Array = Slides.DECK_SONGS[deck_id]
		ok += SelfTest._expect(fails, Slides.deck_ids().has(deck_id), "песня у несуществующей колоды %s" % deck_id)
		ok += SelfTest._expect(fails, Sfx.SONGS.has(StringName(String(e[0]))), "%s: песни %s нет в Sfx.SONGS" % [deck_id, e[0]])
		ok += SelfTest._expect(fails, int(e[1]) >= 0 and int(e[1]) < Slides.panels(deck_id).size(), "%s: кадр песни %d вне колоды" % [deck_id, e[1]])
	var keep_songs := {}
	for sn: StringName in [&"song_mill", &"song_train", &"song_pustite"]:
		keep_songs[sn] = Sfx._streams.get(sn)
		Sfx._streams.erase(sn)
	ok += SelfTest._expect(fails, Slides.song_for("act2_out_all", 0) == &"", "песня без файла должна быть пустой")
	ok += SelfTest._expect(fails, Sfx.menu_music() == &"menu", "без песни меню играет не прежнюю музыку")
	for sn: StringName in keep_songs:
		Sfx._streams[sn] = AudioStreamWAV.new()
	ok += SelfTest._expect(fails, Slides.song_for("act2_out_all", 0) == &"song_mill", "песня акта II на первом кадре итога")
	ok += SelfTest._expect(fails, Slides.song_for("final_many", 1) == &"" and Slides.song_for("final_many", 2) == &"song_train", "песня финала со второго кадра")
	ok += SelfTest._expect(fails, Slides.song_for("a1c1_win", 0) == &"" and Slides.song_for("нет", 0) == &"", "песня у колоды без песни")
	ok += SelfTest._expect(fails, Sfx.menu_music() == &"song_pustite", "меню не играет главную песню")
	# плеер: на кадре песни музыка колоды не перебивает песню
	var host := Nav.host.current
	var pl := SlidePlayer.new()
	pl.deck_id = "act2_out_some"
	pl.deck = Slides.deck("act2_out_some")
	host.add_child(pl)
	pl._build()
	ok += SelfTest._expect(fails, Sfx.music_name == &"song_mill", "в итоге акта II играет «%s», ждали песню" % Sfx.music_name)
	pl.run_sound_event({"do": "start", "layer": "music", "id": "theme_sad", "fade": 0.1})
	ok += SelfTest._expect(fails, Sfx.music_name == &"song_mill", "музыка колоды перебила песню: «%s»" % Sfx.music_name)
	pl.skip()
	await Nav.get_tree().process_frame
	# вернуть, как было
	for sn: StringName in keep_songs:
		if keep_songs[sn] == null:
			Sfx._streams.erase(sn)
		else:
			Sfx._streams[sn] = keep_songs[sn]
	Sfx.set_music(&"", 0.0)
	return ok


## Озвучка в плеере при реальном времени: подпись печатается в такт голосу, кадр ждёт голос и листается после него.
static func voice_flow(fails: PackedStringArray) -> int:
	var ok := 0
	var keep_lang := L.code
	L.use("ru")
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var pcm := PackedByteArray()
	pcm.resize(22050 * 2 * 2)                       # 2 секунды тишины
	wav.data = pcm
	var tmp := "user://vo_selftest.tres"
	ResourceSaver.save(wav, tmp)
	var id := "act1_intro"
	var p0 := Slides.panels(id)[0] as Dictionary
	var key := String(((p0.get("lines", []) as Array)[0] as Dictionary).get("key", ""))
	Slides.voice_test = {key: tmp}
	ok += SelfTest._expect(fails, Slides.panel_voice(p0) == tmp, "озвучка кадра не нашлась через подмену")
	L.use("de")
	ok += SelfTest._expect(fails, Slides.panel_voice(p0).is_empty() or Slides.text(key) == "", "озвучка играет под немецкой подписью")
	L.use("ru")
	Juice.instant = false
	var host := Nav.host.current
	var pl := SlidePlayer.new()
	pl.deck_id = id
	pl.deck = Slides.deck(id)
	host.add_child(pl)
	pl._build()
	if pl._in_card:
		pl.advance()
	ok += SelfTest._expect(fails, pl.panel_i == 0 and absf(pl._vo_len - 2.0) < 0.1, "озвучка кадра не началась: длина %.2f" % pl._vo_len)
	ok += SelfTest._expect(fails, Sfx.voice_line_playing(), "голос кадра не играет")
	var want_cps := SlidePlayer.voice_cps(pl._text_len, pl._vo_len)
	ok += SelfTest._expect(fails, absf(pl._cps - want_cps) < 0.01 and pl._dur >= 2.0 + SlidePlayer.VO_TAIL, "печать не под голос: %.1f знаков/с" % pl._cps)
	# подпись допечатывается чуть раньше конца голоса
	pl._process(0.1)
	ok += SelfTest._expect(fails, pl._typed < float(pl._text_len), "подпись напечаталась за 0,1 с")
	pl._process(1.0)
	ok += SelfTest._expect(fails, pl._typed < float(pl._text_len), "подпись напечаталась за 1,1 с из 2")
	pl._process(0.7)
	ok += SelfTest._expect(fails, pl._typed >= float(pl._text_len), "подпись не допечаталась к 1,8 с голоса")
	# пока голос говорит, кадр не листается и пауза после него не тратится
	pl._process(0.1)
	ok += SelfTest._expect(fails, pl.panel_i == 0 and absf(pl._hold - SlidePlayer.VO_TAIL) < 0.001, "кадр держится не по голосу: кадр %d, пауза %.2f" % [pl.panel_i, pl._hold])
	pl._process(0.2)
	ok += SelfTest._expect(fails, pl.panel_i == 0 and pl._hold < SlidePlayer.VO_TAIL, "после голоса пауза не пошла")
	pl._process(SlidePlayer.VO_TAIL)
	ok += SelfTest._expect(fails, pl.panel_i == 1, "кадр не перелистнулся после голоса: %d" % pl.panel_i)
	# тап по кадру с голосом: подпись сразу, второй тап листает и глушит голос
	Sfx.play_voice_stream(wav)
	pl._vo_len = 2.0
	pl._typed = 0.0
	pl._t = 5.0
	ok += SelfTest._expect(fails, pl.tap() and pl._typed >= float(pl._text_len), "первый тап не допечатал подпись")
	ok += SelfTest._expect(fails, pl.tap() and pl.panel_i == 2 and not Sfx.voice_line_playing(), "второй тап не пролистал и не заглушил голос")
	pl.skip()
	await Nav.get_tree().process_frame
	ok += SelfTest._expect(fails, not Sfx.voice_line_playing(), "голос остался после закрытия колоды")
	Slides.voice_test = {}
	Juice.instant = true
	L.use(keep_lang)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	return ok


# ----------------------------------------------------------------- данные

static func data(fails: PackedStringArray) -> int:
	var ok := 0
	var ids := Slides.deck_ids()
	ok += SelfTest._expect(fails, ids.size() >= DECKS_MIN, "колод %d, ждали не меньше %d" % [ids.size(), DECKS_MIN])
	var panels := 0
	var kinds: Dictionary = {}
	for id: String in ids:
		var d := Slides.deck(id)
		kinds[String(d.get("kind", ""))] = true
		var ps := Slides.panels(id)
		panels += ps.size()
		ok += SelfTest._expect(fails, not ps.is_empty(), "%s: нет кадров" % id)
		ok += SelfTest._expect(fails, not String(d.get("title_key", "")).is_empty(), "%s: нет названия" % id)
		ok += SelfTest._expect(fails, int(d.get("act", -1)) >= 0 and int(d.get("act", -1)) <= 4, "%s: акт вне 0–4" % id)
		ok += SelfTest._expect(fails, int(d.get("flash_to", -1)) >= 0 and int(d.get("flash_to", 0)) <= ps.size(), "%s: flash_to вне колоды" % id)
		var files: Dictionary = {}
		for i in range(ps.size()):
			var p := ps[i] as Dictionary
			var file := String(p.get("file", ""))
			ok += SelfTest._expect(fails, file == "%s/%02d" % [id, i + 1], "%s: кадр %d называется %s" % [id, i + 1, file])
			ok += SelfTest._expect(fails, not files.has(file), "%s: имя %s повторяется" % [id, file])
			files[file] = true
			ok += SelfTest._expect(fails, ["t", "w"].has(String(p.get("size", ""))), "%s/%d: размер %s" % [id, i + 1, p.get("size", "")])
			ok += SelfTest._expect(fails, ["zoom_in", "zoom_out", "pan_l", "pan_r", "pan_u", "pan_d", "shake", "hold"].has(String(p.get("cam", ""))), "%s/%d: камера %s" % [id, i + 1, p.get("cam", "")])
			for c: Variant in p.get("cast", []):
				ok += SelfTest._expect(fails, not Slides.cast_sprite(String(c)).is_empty(), "%s/%d: у лица %s нет спрайта" % [id, i + 1, c])
				ok += SelfTest._expect(fails, not SlideStand.sprite_path(String(c)).is_empty(), "%s/%d: файла спрайта лица %s нет" % [id, i + 1, c])
	ok += SelfTest._expect(fails, panels >= PANELS_MIN, "кадров %d, ждали не меньше %d" % [panels, PANELS_MIN])
	for k: String in ["prologue", "act_intro", "act_outro", "ch_intro", "ch_win", "ch_twist", "bio", "guest", "npc", "finale"]:
		ok += SelfTest._expect(fails, kinds.has(k), "нет колод вида %s" % k)
	# обязательные места кампании
	for a in range(1, 5):
		ok += SelfTest._expect(fails, Slides.has_deck("act%d_intro" % a), "нет входа в акт %d" % a)
		var chs := ["a%dc1" % a, "a%dc2" % a, "a%dc3" % a]
		for ch: String in chs:
			for part: String in ["intro", "win", "twist"]:
				ok += SelfTest._expect(fails, Slides.has_deck("%s_%s" % [ch, part]), "нет колоды %s_%s" % [ch, part])
	for a in range(1, 4):
		for o: String in ["all", "some", "none"]:
			ok += SelfTest._expect(fails, Slides.has_deck("act%d_out_%s" % [a, o]), "нет выхода акта %d: %s" % [a, o])
	ok += SelfTest._expect(fails, Slides.has_deck("act3_out_trial"), "нет выхода акта III после суда")
	for e: String in ["shore", "upyr", "many", "few"]:
		ok += SelfTest._expect(fails, Slides.final_deck(e) == "final_" + e, "нет финала %s" % e)
	for v: String in Slides.VILLAGER_SLOT:
		ok += SelfTest._expect(fails, Slides.has_deck("bio_" + v), "нет предыстории жителя %s" % v)
		# TASK-108: лицо жителя в комиксе то же, что закреплено за ним в игре (VillagerFigure.NAMED_SPRITES)
		var slot := int(Slides.VILLAGER_SLOT[v])
		ok += SelfTest._expect(fails, VillagerFigure.NAMED_SPRITES.has(slot) and Slides.cast_sprite(v) == "f%d" % int(VillagerFigure.NAMED_SPRITES.get(slot, 0)),
			"%s: в комиксе %s, в игре f%s" % [v, Slides.cast_sprite(v), VillagerFigure.NAMED_SPRITES.get(slot, "?")])
		var game_age := SocialContent.story_age(slot)
		ok += SelfTest._expect(fails, game_age >= 18, "%s: в игре %d лет, жителям нужно не меньше 18" % [v, game_age])
	var seen_faces: Dictionary = {}
	for slot: Variant in VillagerFigure.NAMED_SPRITES:
		var face := int(VillagerFigure.NAMED_SPRITES[slot])
		ok += SelfTest._expect(fails, not seen_faces.has(face) and face != 6 and face != 15, "лицо f%d повторяется или детское" % face)
		seen_faces[face] = true
	for g: String in Slides.GUEST_KEY:
		ok += SelfTest._expect(fails, Slides.has_deck("guest_" + g) and Slides.has_deck("guest_%s_human" % g) and Slides.has_deck("guest_%s_upyr" % g), "у гостя %s нет трёх колод" % g)
	return ok


# ----------------------------------------------------------------- подписи

static func texts(fails: PackedStringArray) -> int:
	var ok := 0
	var longest := 0
	for id: String in Slides.deck_ids():
		var d := Slides.deck(id)
		ok += SelfTest._expect(fails, not Slides.title(id).is_empty(), "%s: название не переведено" % id)
		var kind := String(d.get("kind", ""))
		if ["prologue", "act_intro", "ch_intro", "finale"].has(kind):
			ok += SelfTest._expect(fails, not Slides.card(id).is_empty(), "%s: нет титульной плашки" % id)
		var ps := Slides.panels(id)
		for i in range(ps.size()):
			var lines: Array = (ps[i] as Dictionary).get("lines", [])
			ok += SelfTest._expect(fails, not lines.is_empty(), "%s/%d: нет подписи" % [id, i + 1])
			for l: Variant in lines:
				var tx := Slides.text(String((l as Dictionary).get("key", "")))
				var tag := "%s/%d" % [id, i + 1]
				ok += SelfTest._expect(fails, not tx.is_empty(), "%s: подпись не найдена по ключу" % tag)
				longest = maxi(longest, tx.length())
				var who := String((l as Dictionary).get("who", ""))
				if not who.is_empty():
					ok += SelfTest._expect(fails, not Slides.who_name(who).is_empty(), "%s: у говорящего %s нет имени" % [tag, who])
				ok += SelfTest._expect(fails, not tx.contains("—"), "%s: длинное тире" % tag)
				var low := tx.to_lower()
				for w: String in BANNED:
					ok += SelfTest._expect(fails, not low.contains(w), "%s: слово «%s» из запретных" % [tag, w])
				var rx := RegEx.new()
				rx.compile("(?i)\\bне [^,.!?]{1,40}, а ")
				ok += SelfTest._expect(fails, rx.search(tx) == null, "%s: оборот «не X, а Y»" % tag)
				ok += SelfTest._expect(fails, tx.length() <= 120, "%s: подпись %d знаков, не больше 120" % [tag, tx.length()])
	print("самая длинная подпись: %d знаков" % longest)
	# запасной язык: нет перевода — берём русский, не пустую строку
	var keep := L.code
	L.use("de")
	var any_id := Slides.deck_ids()[0]
	var key := String(((Slides.panels(any_id)[0] as Dictionary).lines[0] as Dictionary).key)
	ok += SelfTest._expect(fails, not Slides.text(key).is_empty(), "без перевода подпись пропала вместо русской")
	L.use(keep)
	ok += SelfTest._expect(fails, Slides.who_name("marina") == String((L.names()[0] as Array)[0]), "имя Марины не взято из списка имён языка")
	return ok


# ----------------------------------------------------------------- звук

static func sounds(fails: PackedStringArray) -> int:
	var ok := 0
	var missing: Dictionary = {}
	var unknown_fx: Dictionary = {}
	for id: String in Slides.deck_ids():
		var ps := Slides.panels(id)
		for i in range(ps.size()):
			var p := ps[i] as Dictionary
			var problems := Slides.sound_problems(p)
			ok += SelfTest._expect(fails, problems.is_empty(), "%s/%d: %s" % [id, i + 1, "; ".join(problems)])
			for ev: Variant in p.get("sound", []):
				var e := ev as Dictionary
				var sid := StringName(e.get("id", ""))
				var op := String(e.get("do", ""))
				if op == "play":
					if not Sfx.has_sound(sid):
						missing[String(sid)] = true
						ok += SelfTest._expect(fails, SOUNDS_NOT_YET.has(String(sid)), "%s/%d: звука %s нет и в списке «ещё не записан»" % [id, i + 1, sid])
				elif op == "start":
					if String(e.get("layer", "")) == "music":
						ok += SelfTest._expect(fails, Slides.music_for(sid) != &"", "%s/%d: у музыки %s нет замены" % [id, i + 1, sid])
					else:
						ok += SelfTest._expect(fails, Slides.amb_for(sid) != &"", "%s/%d: у фона %s нет замены" % [id, i + 1, sid])
	print("разовых звуков, которых ещё нет: %d (%s)" % [missing.size(), ", ".join(missing.keys())])
	# плеер исполняет события, неизвестное пропускает без ошибки
	var pl := SlidePlayer.new()
	Sfx.set_music(&"", 0.0)
	Sfx.set_ambience(&"", 0.0)
	pl.run_sound_event({"at": 0.0, "do": "start", "layer": "music", "id": "theme_sad", "fade": 0.0})
	var sad_want: StringName = &"theme_sad" if Sfx.has_sound(&"theme_sad") else &"night"
	ok += SelfTest._expect(fails, Sfx.music_name == sad_want, "тема theme_sad должна играть «%s», играет «%s»" % [sad_want, Sfx.music_name])
	pl.run_sound_event({"at": 0.0, "do": "start", "layer": "music", "id": "theme_hope", "fade": 0.0})
	var hope_want: StringName = &"theme_hope" if Sfx.has_sound(&"theme_hope") else &"day"
	ok += SelfTest._expect(fails, Sfx.music_name == hope_want, "theme_hope должна играть «%s», играет «%s»" % [hope_want, Sfx.music_name])
	# музыка по главам: есть файл главы, играет он; нет файла или первая глава, играет общая дорожка
	var keep_chapter := Game.chapter
	for cid: String in ["a1c1", "a1c2", "a2c3", "a4c3"]:
		Game.chapter = {"id": cid}
		for kind: StringName in [&"day", &"night"]:
			var own := StringName("%s_%s" % [kind, cid])
			var stage_want: StringName = own if Sfx.has_sound(own) else kind
			ok += SelfTest._expect(fails, Sfx.stage_music(kind) == stage_want, "глава %s, %s: дорожка «%s», ждали «%s»" % [cid, kind, Sfx.stage_music(kind), stage_want])
	Game.chapter = keep_chapter
	pl.run_sound_event({"at": 0.0, "do": "start", "layer": "amb", "id": "amb_wind", "fade": 0.0})
	ok += SelfTest._expect(fails, Sfx.ambience_name == &"amb_wind", "фон ветра не включился")
	pl.run_sound_event({"at": 0.0, "do": "start", "layer": "amb", "id": "amb_church", "fade": 0.0})
	ok += SelfTest._expect(fails, Sfx.ambience_name == &"amb_night", "фон церкви без файла должен играть ночным, играет «%s»" % Sfx.ambience_name)
	pl.run_sound_event({"at": 0.0, "do": "start", "layer": "amb", "id": "нет_такого", "fade": 0.0})
	ok += SelfTest._expect(fails, Sfx.ambience_name == &"amb_night", "неизвестный фон сбил текущий")
	Sfx.played.clear()
	pl.run_sound_event({"at": 0.0, "do": "play", "id": "wolf", "vol": -6.0})
	ok += SelfTest._expect(fails, Sfx.played.is_empty(), "звук, которого нет, что-то сыграл")
	pl.run_sound_event({"at": 0.0, "do": "play", "id": "knock", "vol": -6.0})
	ok += SelfTest._expect(fails, Sfx.played.has(&"knock"), "knock не сыгран")
	pl.run_sound_event({"at": 0.0, "do": "silence", "fade": 0.0})
	ok += SelfTest._expect(fails, Sfx.music_name == &"" and Sfx.ambience_name == &"", "silence не погасил звук")
	pl.free()
	# проверяющий ловит плохие карты
	var bad := {"sound": [{"at": 1.0, "do": "play", "id": "knock"}, {"at": 0.5, "do": "dance", "id": "x"}, {"at": 2.0, "do": "start", "id": "amb_night"}, {"at": 3.0, "do": "play"}]}
	var bp := Slides.sound_problems(bad)
	ok += SelfTest._expect(fails, bp.size() == 4, "проверка карты нашла %d проблем из 4: %s" % [bp.size(), "; ".join(bp)])
	return ok


# ----------------------------------------------------------------- картинки и бюджет

static func images(fails: PackedStringArray) -> int:
	var ok := 0
	var bytes := 0
	var found := 0
	var dir := "res://assets/slides/"
	for id: String in Slides.deck_ids():
		var ps := Slides.panels(id)
		for i in range(ps.size()):
			var p := ps[i] as Dictionary
			var path := Slides.art_path(p)
			if path.is_empty():
				continue
			found += 1
			var tex := load(path) as Texture2D
			ok += SelfTest._expect(fails, tex != null, "%s: картинка не читается" % path)
			# без файла .import со сжатием «с потерями» (compress/mode=1) кадр уходит в APK без сжатия: 1,5 МиБ вместо 0,2
			var imp := FileAccess.get_file_as_string(path + ".import")
			ok += SelfTest._expect(fails, imp.contains("compress/mode=1"), "%s: нет .import со сжатием с потерями (git add -f ...webp.import)" % path)
			if tex != null:
				var tall := tex.get_height() > tex.get_width()
				var want_tall := String(p.get("size", "")) == "t"
				ok += SelfTest._expect(fails, tall == want_tall, "%s: %d×%d, а кадр %s" % [path, tex.get_width(), tex.get_height(), "высокий" if want_tall else "широкий"])
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				bytes += int(f.get_length())
	ok += SelfTest._expect(fails, bytes <= IMAGE_BUDGET, "картинки комикса весят %.1f МиБ, бюджет %.0f МиБ" % [float(bytes) / 1048576.0, float(IMAGE_BUDGET) / 1048576.0])
	print("настоящих картинок: %d из %d, %.1f МиБ (папка %s)" % [found, panel_total(), float(bytes) / 1048576.0, dir])
	# заглушки собираются для каждого кадра
	var view := Vector2(720, 1280)
	for id2: String in Slides.deck_ids():
		var ps2 := Slides.panels(id2)
		for i2 in range(ps2.size()):
			var p2 := ps2[i2] as Dictionary
			var stage := SlideStand.build(id2, i2, p2, view, null)
			var want := SlideStand.stage_size(p2, view)
			ok += SelfTest._expect(fails, stage.size.is_equal_approx(want), "%s/%d: заглушка %s, ждали %s" % [id2, i2 + 1, stage.size, want])
			ok += SelfTest._expect(fails, stage.get_child_count() >= 2, "%s/%d: заглушка пустая" % [id2, i2 + 1])
			stage.free()
		ok += SelfTest._expect(fails, not SlideStand.background_path(id2).is_empty(), "%s: нет фона для заглушки" % id2)
	return ok


static func panel_total() -> int:
	var n := 0
	for id: String in Slides.deck_ids():
		n += Slides.panels(id).size()
	return n


# ----------------------------------------------------------------- какая колода в какое место

static func routing(fails: PackedStringArray) -> int:
	var ok := 0
	ok += SelfTest._expect(fails, Slides.chapter_deck("a2c3", "win") == "a2c3_win", "колода победы главы не найдена")
	ok += SelfTest._expect(fails, Slides.chapter_deck("a9c9", "win") == "", "несуществующая глава вернула колоду")
	ok += SelfTest._expect(fails, Slides.act_intro_deck(3) == "act3_intro" and Slides.act_intro_deck(5) == "", "вход в акт")
	ok += SelfTest._expect(fails, Slides.act_outro_deck(3, "trial") == "act3_out_trial" and Slides.act_outro_deck(4, "all") == "", "выход из акта")
	ok += SelfTest._expect(fails, Slides.bio_deck("bio", "rita") == "bio_rita" and Slides.bio_deck("npc", "ignat") == "npc_ignat", "предыстории")
	ok += SelfTest._expect(fails, Slides.final_deck("shore") == "final_shore" and Slides.final_deck("final_few") == "final_few", "финалы")
	ok += SelfTest._expect(fails, Slides.act_of("a3c2_win") == 3 and Slides.act_of("prologue") == 0 and Slides.act_of("act4_intro") == 4, "акт колоды")
	# просмотренное
	var keep: Dictionary = Save.slides_seen.duplicate()
	Save.slides_seen.clear()
	ok += SelfTest._expect(fails, not Slides.seen("prologue"), "колода просмотрена без просмотра")
	Slides.mark_seen("prologue")
	ok += SelfTest._expect(fails, Slides.seen("prologue") and Slides.seen_ids() == PackedStringArray(["prologue"]), "просмотр не записался")
	Save.slides_seen = keep
	return ok


# ----------------------------------------------------------------- плеер

static func player(fails: PackedStringArray) -> int:
	var ok := 0
	var tree := Nav.get_tree()
	Juice.instant = true
	await SelfTest._settle(tree)
	var host := Nav.host.current
	var keep_seen: Dictionary = Save.slides_seen.duplicate()
	var keep_on := Save.comics_on
	var keep_skip := Save.comics_skip_seen
	Save.slides_seen.clear()
	Save.comics_on = true
	Save.comics_skip_seen = false
	# 1. ход колоды: каждый кадр накрывает экран на всём пути камеры
	var cams: Dictionary = {}
	for id: String in Slides.deck_ids():
		var pl := SlidePlayer.new()
		pl.deck_id = id
		pl.deck = Slides.deck(id)
		host.add_child(pl)
		pl._build()
		var n := Slides.panels(id).size()
		var seen_panels := 0
		var guard := 0
		while not pl._done and guard < n + 4:
			guard += 1
			if pl.panel_i >= 0:
				seen_panels += 1
				var cam := String(pl.panel().get("cam", ""))
				cams[cam] = true
				var view := pl._win.size        # окно сцены: весь экран у заглушки, прямоугольник картинки у настоящего кадра
				for pr in [0.0, 0.25, 0.5, 0.75, 1.0]:
					var r := pl.stage_rect_at(float(pr))
					var covers := r.position.x <= 0.01 and r.position.y <= 0.01 and r.end.x >= view.x - 0.01 and r.end.y >= view.y - 0.01
					if not covers:
						ok += SelfTest._expect(fails, false, "%s/%d (%s, %.2f): сцена %s не накрывает экран %s" % [id, pl.panel_i + 1, cam, pr, r, view])
					else:
						ok += 1
			pl.advance()
		ok += SelfTest._expect(fails, seen_panels == n, "%s: показано %d кадров из %d" % [id, seen_panels, n])
		ok += SelfTest._expect(fails, pl._done and pl.completed, "%s: колода не закончилась" % id)
		await tree.process_frame
	for c: String in ["zoom_in", "zoom_out", "pan_l", "pan_r", "pan_u", "pan_d", "shake", "hold"]:
		print("камера %s: %s" % [c, "в данных" if cams.has(c) else "нет в данных"])
	ok += SelfTest._expect(fails, cams.size() >= 5, "в колодах только %d видов камеры" % cams.size())
	ok += SelfTest._expect(fails, Slides.seen("prologue") and Slides.seen("final_few"), "просмотренные колоды не записались")
	# 2. настройки: выключено, уже видел
	Save.comics_on = false
	SlidePlayer.instant_play = true
	var shown_off: bool = await SlidePlayer.play(host, "a1c1_intro")
	ok += SelfTest._expect(fails, not shown_off, "комиксы выключены, а колода показана")
	Save.comics_on = true
	Save.comics_skip_seen = true
	Slides.mark_seen("a1c1_intro")
	var shown_seen: bool = await SlidePlayer.play(host, "a1c1_intro")
	ok += SelfTest._expect(fails, not shown_seen, "«не повторять просмотренное» не сработало")
	Save.comics_skip_seen = false
	var shown_none: bool = await SlidePlayer.play(host, "нет_такой")
	ok += SelfTest._expect(fails, not shown_none, "несуществующая колода показана")
	# 3. «Назад» закрывает колоду, часы партии отпускаются
	Save.slides_seen.erase("a1c2_intro")
	var done_flag := [false]
	var runner := func() -> void:
		await SlidePlayer.play(host, "a1c2_intro")
		done_flag[0] = true
	runner.call()
	await SelfTest._frames(tree, 4)
	var live: SlidePlayer = null
	for c: Node in host.get_children():
		if c is SlidePlayer:
			live = c as SlidePlayer
	ok += SelfTest._expect(fails, live != null, "плеер не появился на экране")
	if live != null:
		ok += SelfTest._expect(fails, Game.held_by(live._hold_key), "плеер не остановил часы партии")
		ok += SelfTest._expect(fails, host.handle_back(), "«Назад» не закрыл колоду")
		await SelfTest._frames(tree, 3)
		ok += SelfTest._expect(fails, bool(done_flag[0]), "после «Назад» play не вернулся")
		ok += SelfTest._expect(fails, not Game.held_by(live._hold_key) if is_instance_valid(live) else true, "часы партии остались остановленными")
		ok += SelfTest._expect(fails, Slides.seen("a1c2_intro"), "пропущенная колода не записана как просмотренная")
	# 3б. в самотестах без разрешения колоды не показываются
	SlidePlayer.instant_play = false
	var shown_test: bool = await SlidePlayer.play(host, "a1c1_win")
	ok += SelfTest._expect(fails, not shown_test, "в самотесте колода показалась без разрешения")
	SlidePlayer.instant_play = true
	# 4. печать подписи по времени (не мгновенный режим): берём колоду победы с длинной первой подписью
	var typing_id := ""
	for id3: String in Slides.deck_ids():
		if String(Slides.deck(id3).get("kind", "")) != "ch_win":
			continue
		var first_key := String(((Slides.panels(id3)[0] as Dictionary).lines[0] as Dictionary).key)
		if Slides.text(first_key).length() >= 40:
			typing_id = id3
			break
	ok += SelfTest._expect(fails, not typing_id.is_empty(), "нет колоды победы с подписью от 40 знаков для проверки печати")
	Juice.instant = false
	var tp := SlidePlayer.new()
	tp.deck_id = typing_id
	tp.deck = Slides.deck(typing_id)
	host.add_child(tp)
	tp._build()
	ok += SelfTest._expect(fails, tp.panel_i == 0, "колода без плашки должна начаться с первого кадра, кадр %d" % tp.panel_i)
	ok += SelfTest._expect(fails, tp._line.visible_characters == 0, "подпись должна начинаться пустой")
	tp._process(0.5)
	ok += SelfTest._expect(fails, tp._line.visible_characters > 5 and tp._line.visible_characters < tp._text_len, "через 0.5 с напечатано %d из %d" % [tp._line.visible_characters, tp._text_len])
	ok += SelfTest._expect(fails, not tp.tap(), "тап раньше %.1f с не должен листать" % SlidePlayer.MIN_PANEL)
	tp._t = 1.0
	ok += SelfTest._expect(fails, tp.tap() and tp._line.visible_characters == -1 and tp.panel_i == 0, "первый тап допечатывает подпись")
	ok += SelfTest._expect(fails, tp.tap() and tp.panel_i == 1, "второй тап листает кадр")
	tp.skip()
	ok += SelfTest._expect(fails, tp._done and not tp.completed, "skip не закрыл колоду")
	Juice.instant = true
	await tree.process_frame
	# 5. титульная плашка у входа в главу
	Juice.instant = false
	var cp := SlidePlayer.new()
	cp.deck_id = "a1c1_intro"
	cp.deck = Slides.deck("a1c1_intro")
	host.add_child(cp)
	cp._build()
	ok += SelfTest._expect(fails, cp._in_card and cp._card.visible and cp._card_label.text.contains("Стук") or L.code != "ru", "у входа в главу нет плашки с названием")
	cp._process(SlidePlayer.CARD_SEC + 0.1)
	ok += SelfTest._expect(fails, not cp._in_card and cp.panel_i == 0, "плашка не сменилась первым кадром")
	cp.skip()
	Juice.instant = true
	await tree.process_frame
	SlidePlayer.instant_play = false
	Save.slides_seen = keep_seen
	Save.comics_on = keep_on
	Save.comics_skip_seen = keep_skip
	Sfx.set_music(&"", 0.0)
	Sfx.set_ambience(&"", 0.0)
	return ok


# ----------------------------------------------------------------- места запуска в кампании

static func hooks(fails: PackedStringArray) -> int:
	var ok := 0
	var tree := Nav.get_tree()
	Juice.instant = true
	await SelfTest._settle(tree)
	var host := Nav.host.current
	var keep_seen: Dictionary = Save.slides_seen.duplicate()
	var keep_dead: Array[int] = Save.campaign_dead.duplicate()
	var keep_mem: Array[Dictionary] = Save.campaign_memory.duplicate()
	var keep_chapter := Game.chapter
	var keep_result := Game.chapter_result
	var keep_done := Game.scenes_done.duplicate()
	var keep_on := Save.comics_on
	var keep_skip := Save.comics_skip_seen
	Save.comics_on = true
	Save.comics_skip_seen = true
	# 1. условия запуска перед главой
	var ps := PrologueScreen.new()
	Game.chapter = Campaign.chapter("a2c1")
	Game.scenes_done.clear()
	SlidePlayer.instant_play = false
	ok += SelfTest._expect(fails, not ps._comics_due(), "в самотесте комиксы перед главой запускаются без разрешения")
	SlidePlayer.instant_play = true
	ok += SelfTest._expect(fails, ps._comics_due() and ps._act_comics_cover(), "комиксы перед главой не запускаются")
	Save.comics_on = false
	ok += SelfTest._expect(fails, not ps._comics_due() and not ps._act_comics_cover(), "комиксы выключены, а запуск идёт")
	Save.comics_on = true
	Game.scenes_done["comics_intro"] = true
	ok += SelfTest._expect(fails, not ps._comics_due(), "комиксы перед главой повторяются в той же партии")
	ps.free()
	# 2. партия главы: вход в акт и вход в главу сыграны, старая сцена акта не сыграна
	Save.slides_seen.clear()
	Game.start(Campaign.config("a2c1"), "", Campaign.chapter("a2c1"))
	for i in range(240):
		await tree.process_frame
		if Slides.seen("a2c1_intro"):
			break
	ok += SelfTest._expect(fails, Slides.seen("act2_intro") and Slides.seen("a2c1_intro"), "перед главой не сыграны вход в акт и вход в главу: %s" % str(Slides.seen_ids()))
	ok += SelfTest._expect(fails, not Slides.seen("prologue"), "предыстория сыграна не в первой главе кампании")
	ok += SelfTest._expect(fails, not Game.scenes_done.has("act_prologue"), "старая сцена акта сыграна вместе с комиксом")
	Game.abandon()
	await SelfTest._settle(tree)
	Save.comics_on = false
	Save.slides_seen.clear()
	Game.start(Campaign.config("a2c1"), "", Campaign.chapter("a2c1"))
	for i in range(240):
		await tree.process_frame
		if Game.scenes_done.has("act_prologue"):
			break
	ok += SelfTest._expect(fails, Game.scenes_done.has("act_prologue") and Slides.seen_ids().is_empty(), "комиксы выключены: должна играть прежняя сцена акта без колод")
	Game.abandon()
	await SelfTest._settle(tree)
	Save.comics_on = true
	# 3. после главы: победа или поворот, итог акта
	host = Nav.host.current
	var es := EndScreen.new()
	host.add_child(es)
	ok += SelfTest._expect(fails, es._comics_end_due() == false, "после главы без результата комиксы запускаются")
	var cases: Array[Array] = [
		# глава, прошла ли, погибшие, суд проигран, что должно быть просмотрено
		["a1c2", true, [], false, ["a1c2_win"]],
		["a1c2", false, [], false, ["a1c2_twist"]],
		["a1c3", true, [], false, ["a1c3_win", "act1_out_all"]],
		["a1c3", true, [0], false, ["a1c3_win", "act1_out_some"]],
		["a1c3", true, [0, 1, 2], false, ["a1c3_win", "act1_out_none"]],
		["a2c3", true, [0], false, ["a2c3_win", "act2_out_some"]],
		["a3c3", true, [], false, ["a3c3_win", "act3_out_all"]],
		["a3c3", true, [], true, ["a3c3_win", "act3_out_trial"]],
		["a4c3", true, [], false, ["a4c3_win"]],
		["a3c3", false, [], false, ["a3c3_twist"]],
	]
	for c: Array in cases:
		Save.slides_seen.clear()
		Save.campaign_dead.assign(c[2])
		Save.campaign_memory.clear()
		if bool(c[3]):
			Save.campaign_memory.append({"ch": "a3c3", "kind": "trial_lost", "who": 0, "day": 1, "knew": []})
		Game.chapter = Campaign.chapter(String(c[0]))
		Game.chapter_result = {"passed": bool(c[1])}
		Game.scenes_done.clear()
		ok += SelfTest._expect(fails, es._comics_end_due(), "%s: комиксы после главы не запускаются" % c[0])
		await es._play_comics_end()
		var want: PackedStringArray = PackedStringArray(c[4])
		var got := Slides.seen_ids()
		var same := got.size() == want.size()
		for w: String in want:
			same = same and got.has(w)
		ok += SelfTest._expect(fails, same, "%s (прошла: %s, погибшие %s, суд проигран: %s): просмотрено %s, ждали %s" % [c[0], c[1], c[2], c[3], str(got), str(want)])
		if want.size() > 1:
			ok += SelfTest._expect(fails, Game.scenes_done.has("act_end"), "%s: после итога акта комиксом старая сцена конца акта не заблокирована" % c[0])
	es.queue_free()
	# 4. утро разгадки гостя
	await tree.process_frame
	for gid: String in Slides.GUEST_BY_GAME:
		ok += SelfTest._expect(fails, Guests.LIST.has(gid) and Slides.has_deck("guest_%s_human" % Slides.GUEST_BY_GAME[gid]), "гость %s не связан с колодой" % gid)
	# возврат состояния
	SlidePlayer.instant_play = false
	Game.chapter = keep_chapter
	Game.chapter_result = keep_result
	Game.scenes_done = keep_done
	Save.slides_seen = keep_seen
	Save.campaign_dead.assign(keep_dead)
	Save.campaign_memory.assign(keep_mem)
	Save.comics_on = keep_on
	Save.comics_skip_seen = keep_skip
	Sfx.set_music(&"", 0.0)
	Sfx.set_ambience(&"", 0.0)
	return ok


# ----------------------------------------------------------------- Книга посёлка

static func book(fails: PackedStringArray) -> int:
	var ok := 0
	var tree := Nav.get_tree()
	Juice.instant = true
	ok += SelfTest._expect(fails, Slides.bio_for_story_key("n0") == "bio_marina" and Slides.bio_for_story_key("n11") == "bio_polina", "предыстория жителя по ключу истории")
	ok += SelfTest._expect(fails, Slides.bio_for_story_key("gsoldier") == "guest_gordey" and Slides.bio_for_story_key("gclerk") == "guest_pisar", "предыстория гостя по ключу истории")
	ok += SelfTest._expect(fails, Slides.bio_for_story_key("x9") == "" and Slides.bio_for_story_key("gnobody") == "", "лишний ключ истории дал колоду")
	var groups := Slides.gallery()
	var counted := 0
	for g: Array in groups:
		counted += (g[1] as Array).size()
	ok += SelfTest._expect(fails, counted == Slides.deck_ids().size(), "в галерее %d колод из %d" % [counted, Slides.deck_ids().size()])
	var keep_seen: Dictionary = Save.slides_seen.duplicate()
	var keep_story: Dictionary[String, int] = Save.storybook.duplicate()
	Save.slides_seen.clear()
	for id: String in ["prologue", "a1c1_win", "final_few"]:
		Save.slides_seen[id] = 1
	Save.storybook["n0"] = 2
	Save.storybook["n1"] = 0
	Nav.show_book()
	await SelfTest._settle(tree)
	var scr := Nav.host.current
	for id2: String in ["prologue", "a1c1_win", "final_few"]:
		ok += SelfTest._expect(fails, scr.find_child("Comic_" + id2, true, false) != null, "в Книге нет кнопки просмотренного комикса %s" % id2)
	ok += SelfTest._expect(fails, scr.find_child("Comic_a1c2_win", true, false) == null, "в Книге есть кнопка комикса, которого игрок не видел")
	ok += SelfTest._expect(fails, scr.find_child("ComicsClosed", true, false) != null, "в Книге нет счётчика закрытых комиксов")
	ok += SelfTest._expect(fails, scr.find_child("Comic_n0", true, false) != null, "услышанная до конца история не даёт комикс")
	ok += SelfTest._expect(fails, scr.find_child("Comic_n1", true, false) == null, "комикс открыт после первой страницы истории")
	var btn := scr.find_child("Comic_prologue", true, false) as Button
	if btn != null:
		btn.pressed.emit()
		await SelfTest._frames(tree, 4)
		var live := false
		for c: Node in scr.get_children():
			if c is SlidePlayer:
				live = true
		ok += SelfTest._expect(fails, live, "кнопка комикса в Книге не запустила колоду")
		ok += SelfTest._expect(fails, scr.handle_back(), "«Назад» не закрыл комикс из Книги")
		await SelfTest._frames(tree, 3)
	Save.slides_seen = keep_seen
	Save.storybook = keep_story
	Sfx.set_music(&"", 0.0)
	Sfx.set_ambience(&"", 0.0)
	Nav.show_menu()
	await SelfTest._settle(tree)
	return ok


# ----------------------------------------------------------------- раскладка

## Подпись помещается и не уходит за экран на всех размерах экрана и при трёх размерах текста.
static func geometry(fails: PackedStringArray) -> int:
	var ok := 0
	var tree := Nav.get_tree()
	var host_keep_text := Save.text_size
	var profiles: Array[Array] = []
	for sz: Vector2i in SelfTest.LAYOUT_SIZES:
		profiles.append([sz, SelfTest.csf, "%d×%d" % [sz.x, sz.y]])
	for dev: Array in SelfTest.device_profiles():
		profiles.append([dev[0], float(dev[2]), String(dev[3])])
	# самая длинная подпись колоды
	var longest_id := ""
	var longest_i := 0
	var longest_len := 0
	for id: String in Slides.deck_ids():
		var ps := Slides.panels(id)
		for i in range(ps.size()):
			var tx := Slides.text(String((((ps[i] as Dictionary).lines as Array)[0] as Dictionary).key))
			if tx.length() > longest_len:
				longest_len = tx.length()
				longest_id = id
				longest_i = i
	# самая длинная подпись среди кадров с настоящей картинкой
	var art_id := ""
	var art_i := 0
	var art_len := 0
	for id: String in Slides.deck_ids():
		var ps := Slides.panels(id)
		for i in range(ps.size()):
			if Slides.art_path(ps[i] as Dictionary).is_empty():
				continue
			var tx := Slides.text(String((((ps[i] as Dictionary).lines as Array)[0] as Dictionary).key))
			if tx.length() > art_len:
				art_len = tx.length()
				art_id = id
				art_i = i
	for prof: Array in profiles:
		var sz: Vector2i = prof[0]
		tree.root.size = sz
		tree.root.content_scale_factor = float(prof[1])
		await SelfTest._settle(tree)
		Nav.frame.refresh()
		await SelfTest._frames(tree, 2)
		for ts in range(3):
			Save.text_size = ts
			ThemeFactory.text_scale = ThemeFactory.TEXT_SCALES[ts]
			Nav.ui.theme = ThemeFactory.build()
			var host := Nav.host.current
			var pl := SlidePlayer.new()
			pl.deck_id = longest_id
			pl.deck = Slides.deck(longest_id)
			host.add_child(pl)
			pl._build()
			for k in range(longest_i):
				pl.advance()
			await SelfTest._frames(tree, 2)
			var tag := "%s, текст %d, %s/%d" % [prof[2], ts, longest_id, longest_i + 1]
			var view := pl._view_size
			var extra := 0
			while pl._plate.size.y > view.y * MAX_PLATE_SHARE and extra < 8:
				await tree.process_frame
				extra += 1
			if extra > 0:
				print("ДИАГНОСТИКА %s: подпись %.0f px при экране %.0f, дополнительных кадров %d" % [tag, pl._plate.size.y, view.y, extra])
			var plate := pl._plate.get_global_rect()
			ok += SelfTest._expect(fails, plate.position.x >= -0.5 and plate.end.x <= view.x + 0.5 and plate.end.y <= view.y + 0.5, "%s: подпись %s вне экрана %s" % [tag, plate, view])
			ok += SelfTest._expect(fails, plate.size.y <= view.y * MAX_PLATE_SHARE, "%s: подпись занимает %.0f%% высоты" % [tag, plate.size.y / view.y * 100.0])
			var skip_rect := pl._skip.get_global_rect()
			ok += SelfTest._expect(fails, skip_rect.end.x <= view.x + 0.5 and skip_rect.position.y >= -0.5 and skip_rect.size.y >= SelfTest.MIN_TOUCH * 0.5, "%s: кнопка «Пропустить» %s вне экрана %s" % [tag, skip_rect, view])
			ok += SelfTest._expect(fails, not plate.intersects(skip_rect), "%s: подпись налезает на «Пропустить»" % tag)
			ok += SelfTest._expect(fails, pl._view.get_global_rect().size.is_equal_approx(view), "%s: область кадра %s не во весь экран %s" % [tag, pl._view.get_global_rect().size, view])
			pl.skip()
			await tree.process_frame
			# настоящая картинка: видна целиком без искажения, подпись не лежит на ней
			if not art_id.is_empty():
				var pa := SlidePlayer.new()
				pa.deck_id = art_id
				pa.deck = Slides.deck(art_id)
				host.add_child(pa)
				pa._build()
				for k in range(art_i):
					pa.advance()
				await SelfTest._frames(tree, 2)
				var atag := "%s, текст %d, картинка %s/%d" % [prof[2], ts, art_id, art_i + 1]
				var win := pa._win
				var tex := load(Slides.art_path(pa.panel())) as Texture2D
				var av := pa._view_size
				ok += SelfTest._expect(fails, pa._art_on and win.position.x >= -0.5 and win.end.x <= av.x + 0.5 and win.position.y >= 0.0 and win.end.y <= av.y + 0.5,
					"%s: окно картинки %s вне экрана %s" % [atag, win, av])
				ok += SelfTest._expect(fails, absf(win.size.x / win.size.y - tex.get_size().x / tex.get_size().y) < 0.01,
					"%s: картинка искажена, окно %s при исходнике %s" % [atag, win.size, tex.get_size()])
				var aplate := pa._plate.get_global_rect()
				ok += SelfTest._expect(fails, pa._plate.visible and win.end.y <= aplate.position.y + 0.5,
					"%s: подпись %s налезает на картинку %s" % [atag, aplate, win])
				ok += SelfTest._expect(fails, aplate.end.y <= av.y + 0.5 and aplate.position.x >= -0.5 and aplate.end.x <= av.x + 0.5,
					"%s: подпись %s вне экрана %s" % [atag, aplate, av])
				ok += SelfTest._expect(fails, pa._stage_root.find_child("Backdrop", true, false) != null, "%s: нет размытой подложки" % atag)
				pa.skip()
				await tree.process_frame
	Save.text_size = host_keep_text
	ThemeFactory.text_scale = ThemeFactory.TEXT_SCALES[host_keep_text]
	Nav.ui.theme = ThemeFactory.build()
	tree.root.size = Vector2i(720, 1280)
	tree.root.content_scale_factor = 1.0
	return ok
