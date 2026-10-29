extends Node
## Звук: одиночные эффекты, фоновые слои, музыка и сердцебиение.
## Записанные источники и лицензии перечислены в docs/sound-sources.md.
##
## Каналы громкости: Music, Sfx, Ambience и Voice отдельно в настройках.
## Свёрнута игра — все каналы заглушены, вернулась — звук возвращается.

const SOUNDS := {
	&"knock": "res://assets/sfx/knock.ogg",
	&"door_open": "res://assets/sfx/door_open.ogg",
	&"door_shut": "res://assets/sfx/door_shut.ogg",
	&"tap": "res://assets/sfx/tap.ogg",
	&"blip": "res://assets/sfx/blip.ogg",
	&"bell": "res://assets/sfx/bell.ogg",
	&"tick": "res://assets/sfx/tick.ogg",
	&"death": "res://assets/sfx/death.ogg",
	&"human_cry_m": "res://assets/sfx/human_cry_m.ogg",
	&"human_cry_f": "res://assets/sfx/human_cry_f.ogg",
	&"upyr_cry": "res://assets/sfx/upyr_cry.ogg",
	&"exile": "res://assets/sfx/exile.ogg",
	&"win": "res://assets/sfx/win.ogg",
	&"lose": "res://assets/sfx/lose.ogg",
	&"reveal": "res://assets/sfx/reveal.ogg",
	&"reveal_2": "res://assets/sfx/reveal_2.ogg",
	&"reveal_3": "res://assets/sfx/reveal_3.ogg",
	&"dawn": "res://assets/sfx/dawn.ogg",
	&"job_done": "res://assets/sfx/job_done.ogg",
	&"job_fail": "res://assets/sfx/job_fail.ogg",
	&"scratch": "res://assets/sfx/scratch.ogg",
	&"whisper": "res://assets/sfx/whisper.ogg",
	&"roof_steps": "res://assets/sfx/roof_steps.ogg",
	&"creak": "res://assets/sfx/creak.ogg",
	&"cry_far": "res://assets/sfx/cry_far.ogg",
	&"growl": "res://assets/sfx/growl.ogg",
	&"gasp": "res://assets/sfx/gasp.ogg",
	&"call_far": "res://assets/sfx/call_far.ogg",
	&"scare": "res://assets/sfx/scare.ogg",
	&"weep": "res://assets/sfx/weep.ogg",
	&"breath": "res://assets/sfx/breath.ogg",
	&"breath_2": "res://assets/sfx/breath_2.ogg",
	&"breath_3": "res://assets/sfx/breath_3.ogg",
	&"cup_break": "res://assets/sfx/cup_break.ogg",
	&"hammer": "res://assets/sfx/hammer.ogg",
	&"latch": "res://assets/sfx/latch.ogg",
	&"floorboard": "res://assets/sfx/floorboard.ogg",
	&"life_dog": "res://assets/sfx/life_dog.ogg",
	&"life_hens": "res://assets/sfx/life_hens.ogg",
	&"thunder": "res://assets/sfx/thunder.ogg",
	&"thunder_2": "res://assets/sfx/thunder_2.ogg",
	&"thunder_far": "res://assets/sfx/thunder_far.ogg",
}
const LOOPS := {
	&"amb_day": "res://assets/sfx/amb_day.ogg",
	&"amb_night": "res://assets/sfx/amb_night.ogg",
	&"amb_dusk": "res://assets/sfx/amb_dusk.ogg",
	&"amb_river": "res://assets/sfx/amb_river.ogg",
	&"whistle": "res://assets/sfx/whistle.ogg",
	&"rails": "res://assets/sfx/rails.ogg",
	&"typewriter": "res://assets/sfx/typewriter.ogg",
	&"train": "res://assets/sfx/train.ogg",
	&"heartbeat": "res://assets/sfx/heartbeat.ogg",
	&"menu": "res://assets/music/menu_theme.ogg",
	&"day": "res://assets/music/day.ogg",
	&"night": "res://assets/music/night.ogg",
	&"end_dawn": "res://assets/music/end_dawn.ogg",
	&"end_dark": "res://assets/music/end_dark.ogg",
	&"river_theme": "res://assets/music/river_theme.ogg",
	&"amb_wind": "res://assets/sfx/amb_wind.ogg",
	&"amb_rain": "res://assets/sfx/amb_rain.ogg",
	&"amb_rain_light": "res://assets/sfx/amb_rain_light.ogg",
	&"amb_rain_heavy": "res://assets/sfx/amb_rain_heavy.ogg",
	&"amb_rain_roof": "res://assets/sfx/amb_rain_roof.ogg",
	&"amb_rain_drops": "res://assets/sfx/amb_rain_drops.ogg",
	&"amb_rain_inside": "res://assets/sfx/amb_rain_inside.ogg",
	&"amb_blizzard": "res://assets/sfx/amb_blizzard.ogg",
	&"life_murmur": "res://assets/sfx/life_murmur.ogg",
	&"mill_wheel": "res://assets/sfx/mill_wheel.ogg",
}
## Темы акта, пары и кульминации (TASK-082). Файлов может не быть: тогда тема молчит, и экран играет то, что играл раньше.
## Файлы кладутся в assets/music/ под этими именами; 60–90 с, цикл, −16 LUFS (проверка tools/check_music.py).
const THEMES := {
	&"theme_act1": "res://assets/music/theme_act1.ogg",
	&"theme_act2": "res://assets/music/theme_act2.ogg",
	&"theme_act3": "res://assets/music/theme_act3.ogg",
	&"theme_act4": "res://assets/music/theme_act4.ogg",
	&"theme_pair": "res://assets/music/theme_pair.ogg",       # утром: тот, кто потерял пару
	&"theme_climax": "res://assets/music/theme_climax.ogg",   # у двери в последнюю ночь главы
}
## Темы комиксов (TASK-123, tools/make_comic_themes.py): играют в SlidePlayer по звуковой карте кадра. Нет файла: Slides.MUSIC_FALLBACK.
const COMIC_THEMES := {
	&"theme_sad": "res://assets/music/theme_sad.ogg",
	&"theme_hope": "res://assets/music/theme_hope.ogg",
	&"theme_tense": "res://assets/music/theme_tense.ogg",
	&"theme_grief": "res://assets/music/theme_grief.ogg",
}
## Песни (как в Alan Wake: песня в меню и в конце эпизода). Делаются в Lyria по промптам из «Пульта» (tools/pult), кладутся в assets/music/.
## Нет файла: играет прежняя музыка. Песня идёт петлёй, пока играет экран.
const SONGS := {
	&"song_pustite": "res://assets/music/song_pustite.ogg",    # меню и концовка «упырь»
	&"song_lullaby": "res://assets/music/song_lullaby.ogg",    # итог акта I
	&"song_mill": "res://assets/music/song_mill.ogg",          # итог акта II
	&"song_bell": "res://assets/music/song_bell.ogg",          # итог акта III
	&"song_train": "res://assets/music/song_train.ogg",        # концовки «многие» и «немногие»
	&"song_shore": "res://assets/music/song_shore.ogg",        # концовка «тот берег»
}
## Озвучка: assets/voice/<колода>/<NN>_<строка>.ogg для кадров комикса и assets/voice/bark/<тип>_<настроение>_<k>.ogg для чата.
const VOICE_DIR := "res://assets/voice/"
## Настроение жителя -> набор возгласов. Остальное: calm.
const BARK_MOOD := {"grief": "grief", "despair": "grief", "guilt": "grief", "exhaustion": "grief", "fear": "fear", "rage": "rage"}
const BARKS_PER_SET := 8
## Музыка в момент озвучки тише на столько дБ.
const DUCK_DB := 5.0
## Музыка по главам (TASK-123): day_a1c2 … night_a4c3. У быстрой партии на карте «посёлок» играют общие day и night. С 0.68.0 свои дорожки day_<глава> и night_<глава> есть у всех двенадцати глав.
## Файлов может не быть: тогда играет общая дорожка. Их делает tools/make_stage_music.py.
const STAGE_KEYS: PackedStringArray = ["a1c1", "a1c2", "a1c3", "a2c1", "a2c2", "a2c3", "a3c1", "a3c2", "a3c3", "a4c1", "a4c2", "a4c3"]
## Быстрая партия: карта -> дорожки первой главы этой карты.
const STAGE_BY_GROUND := {"ground_mill": "a2c1", "ground_monastery": "a3c1", "ground_station": "a4c1"}
## Звук с вариантами: каждый раз случайный из списка, в журнал пишется общее имя.
const VARIANTS := {
	&"reveal": [&"reveal", &"reveal_2", &"reveal_3"],
	&"breath": [&"breath", &"breath_2", &"breath_3"],   # за дверью дышат по-разному (TASK-081)
	&"thunder": [&"thunder", &"thunder_2"],
}
const BUSES := [&"Music", &"Sfx", &"Ambience", &"Voice"]
const HORROR_LEFT := &"NightHorrorLeft"
const HORROR_RIGHT := &"NightHorrorRight"
const POOL := 8
const LOG_MAX := 64

## Последние сыгранные звуки — для самотеста и бортового самописца.
var played: Array[StringName] = []
var music_name: StringName = &""
var ambience_name: StringName = &""
var heart_on := false

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
## Длинных потоков не больше шести: музыка, фон, место, погода, жизнь, сердцебиение — по одному.
## Смена идёт «нырком»: старый звук затихает, потом входит новый. Двух потоков одного слоя нет.
const LONG_LIMIT := 6
var weather_name: StringName = &""                ## какой слой погоды звучит
var weather_db := -80.0                           ## его громкость
var life_ratio := 1.0                             ## доля живых: с каждой смертью посёлок тише
var life_day := false
var tension := 0.0                                ## 0..1: давит на фон фильтром, ускоряет пульс
var _music_p: AudioStreamPlayer
var _music_gen := 0
var _amb_p: AudioStreamPlayer
var _amb_gen := 0
var _weather_p: AudioStreamPlayer
var _weather_gen := 0
var _life_p: AudioStreamPlayer
var _life_clock := 20.0
var _bell_clock := 50.0
var _place: AudioStreamPlayer
var _place_name: StringName = &""
var _place_ground := ""
var _place_generation := 0
var _amb_filter: AudioEffectLowPassFilter
var _pace := 1.0
var _heart: AudioStreamPlayer
var _panned_player: AudioStreamPlayer
var _vo_p: AudioStreamPlayer          ## озвучка кадров комикса
var _vo_gen := 0
var _bark_cache: Dictionary = {}      ## "f_old_calm" -> Array[AudioStream]; пустой массив: файлов нет
var _bark_last: Dictionary = {}       ## id говорящего -> номер последнего возгласа
var _muted_by_os := false
var _tw: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b: StringName in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, &"Master")
	_ensure_panner_bus(HORROR_LEFT, -1.0)
	_ensure_panner_bus(HORROR_RIGHT, 1.0)
	for k: StringName in SOUNDS:
		_streams[k] = load(SOUNDS[k])
	for k: StringName in LOOPS:
		var s := load(LOOPS[k]) as AudioStream
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_streams[k] = s
	for k: StringName in THEMES:
		if ResourceLoader.exists(THEMES[k]):
			var theme_stream := load(THEMES[k]) as AudioStream
			if theme_stream is AudioStreamOggVorbis:
				(theme_stream as AudioStreamOggVorbis).loop = true
			_streams[k] = theme_stream
	for k: StringName in COMIC_THEMES:
		if ResourceLoader.exists(COMIC_THEMES[k]):
			var comic_stream := load(COMIC_THEMES[k]) as AudioStream
			if comic_stream is AudioStreamOggVorbis:
				(comic_stream as AudioStreamOggVorbis).loop = true
			_streams[k] = comic_stream
	for k: StringName in SONGS:
		if ResourceLoader.exists(SONGS[k]):
			var song_stream := load(SONGS[k]) as AudioStream
			if song_stream is AudioStreamOggVorbis:
				(song_stream as AudioStreamOggVorbis).loop = true
			_streams[k] = song_stream
	for kind: String in ["day", "night"]:
		for key: String in STAGE_KEYS:
			var stage_path := "res://assets/music/%s_%s.ogg" % [kind, key]
			if ResourceLoader.exists(stage_path):
				var stage_stream := load(stage_path) as AudioStream
				if stage_stream is AudioStreamOggVorbis:
					(stage_stream as AudioStreamOggVorbis).loop = true
				_streams[StringName("%s_%s" % [kind, key])] = stage_stream
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = &"Sfx"
		add_child(p)
		_pool.append(p)
	_music_p = _player(&"Music")
	_amb_p = _player(&"Ambience")
	_place = _player(&"Ambience")
	_weather_p = _player(&"Ambience")
	_life_p = _player(&"Ambience")
	_amb_filter = AudioEffectLowPassFilter.new()
	_amb_filter.cutoff_hz = 20500.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Ambience"), _amb_filter)
	_heart = _player(&"Sfx")
	_vo_p = _player(&"Voice")
	_panned_player = _player(HORROR_LEFT)
	_heart.stream = _streams[&"heartbeat"]


func _ensure_panner_bus(bus_name: StringName, pan: float) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, &"Sfx")
	var effect := AudioEffectPanner.new()
	effect.pan = pan
	AudioServer.add_bus_effect(i, effect)


func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


func has_sound(n: StringName) -> bool:
	return _streams.has(n) and _streams[n] != null


func has_theme(n: StringName) -> bool:
	return THEMES.has(n) and has_sound(n)


## Тема акта (1–4) для пролога и итога; пусто, если акта нет или файла темы нет.
func act_theme(act: int) -> StringName:
	var n := StringName("theme_act%d" % act)
	return n if has_theme(n) else &""


## Дорожка дня или ночи для этой главы или карты. Нет файла: общая day или night.
func stage_music(kind: StringName) -> StringName:
	var key := String(Game.chapter.get("id", ""))
	if key.is_empty() and Game.m != null and Game.m.village != null:
		key = String(STAGE_BY_GROUND.get(Game.m.village.ground, ""))
	var n := StringName("%s_%s" % [kind, key])
	return n if not key.is_empty() and has_sound(n) else kind


## Одиночный звук. pitch — высота (голоса жителей), vol_db — громкость относительно канала.
func play(n: StringName, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not has_sound(n):
		push_warning("нет звука: %s" % n)
		return
	_note(n)
	var stream_name := n
	if VARIANTS.has(n):
		var opts: Array = VARIANTS[n]
		stream_name = opts[randi() % opts.size()]
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.bus = &"Sfx"
	p.stream = _one_shot(stream_name, n)
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = vol_db
	p.play()


var _one_shots: Dictionary = {}


## Разовый звук из набора петель (гудок, поезд, лязг) играет один раз, а не по кругу:
## у петель включён loop, поэтому для разового проигрывания берётся копия без него.
func _one_shot(stream_name: StringName, fallback: StringName) -> AudioStream:
	var s: AudioStream = _streams.get(stream_name, _streams[fallback])
	if s is AudioStreamOggVorbis and (s as AudioStreamOggVorbis).loop:
		if not _one_shots.has(stream_name):
			var c := (s as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
			c.loop = false
			_one_shots[stream_name] = c
		return _one_shots[stream_name]
	if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
		if not _one_shots.has(stream_name):
			var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_DISABLED
			_one_shots[stream_name] = w
		return _one_shots[stream_name]
	return s


## Разовый звук по краю стереополя. Канал проходит через Sfx, поэтому его громкость
## и системное приглушение остаются общими для всех эффектов.
func play_panned(n: StringName, side: int, pitch: float = 1.0, vol_db: float = -14.0) -> void:
	if not has_sound(n) or _panned_player == null:
		return
	_note(n)
	var stream_name := n
	if VARIANTS.has(n):
		var opts: Array = VARIANTS[n]
		stream_name = opts[randi() % opts.size()]
	_panned_player.stop()
	_panned_player.bus = HORROR_LEFT if side < 0 else HORROR_RIGHT
	_panned_player.stream = _one_shot(stream_name, n)
	_panned_player.pitch_scale = clampf(pitch, 0.25, 4.0)
	_panned_player.volume_db = vol_db
	_panned_player.play()


func stop_panned(fade: float = 0.12) -> void:
	if _panned_player != null and _panned_player.playing:
		_fade(_panned_player, -80.0, fade, true)


## Голос жителя: 2–4 слога-писка с высотой, своей у каждого. Слышно, кто говорит.
## mood — состояние говорящего (TASK-009): в горе ниже и медленнее, в страхе выше и чаще.
## Реплика жителя: проигрывается записанный возглас, если для этого голоса есть файл.
## Пока набора записей нет, текст остаётся без звукового писка.
func voice(speaker_id: int, female: bool, _text_len: int, mood: String = "", age: int = 34) -> void:
	bark(speaker_id, female, age, mood)


## Тип голоса по полу и возрасту: f_old, f_mid, f_young, m_old, m_mid, m_young, boy. Совпадает с именами файлов в assets/voice/bark.
static func voice_type(female: bool, age: int) -> String:
	if age < 15:
		return "boy"
	var band := "old" if age >= 58 else ("mid" if age >= 30 else "young")
	return "%s_%s" % ["f" if female else "m", band]


func _barks(vtype: String, mood: String) -> Array:
	var key := "%s_%s" % [vtype, mood]
	if _bark_cache.has(key):
		return _bark_cache[key]
	var arr: Array = []
	for k in range(BARKS_PER_SET):
		var path := "%sbark/%s_%d.ogg" % [VOICE_DIR, key, k]
		if ResourceLoader.exists(path):
			var st := load(path) as AudioStream
			if st != null:
				arr.append(st)
	_bark_cache[key] = arr
	return arr


## Записанный возглас жителя: набор по полу, возрасту и настроению, не повторяет предыдущий. false означает, что файла нет.
func bark(speaker_id: int, female: bool, age: int, mood: String = "") -> bool:
	var vtype := voice_type(female, age)
	var m := String(BARK_MOOD.get(mood, "calm"))
	var set := _barks(vtype, m)
	if set.is_empty() and m != "calm":
		m = "calm"
		set = _barks(vtype, m)
	if set.is_empty():
		return false
	var i := randi() % set.size()
	if set.size() > 1 and i == int(_bark_last.get(speaker_id, -1)):
		i = (i + 1) % set.size()
	_bark_last[speaker_id] = i
	_note(StringName("голос:%s_%s" % [vtype, m]))
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.bus = &"Voice"
	p.stream = set[i]
	p.pitch_scale = 0.95 + 0.012 * float((speaker_id * 37) % 9)
	p.volume_db = -3.0
	p.play()
	return true


## Озвучка кадра комикса. Возвращает длину в секундах или -1.0, если файла нет. Музыка на это время тише.
func play_voice_line(path: String, vol_db: float = 0.0) -> float:
	if path.is_empty() or not ResourceLoader.exists(path):
		return -1.0
	return play_voice_stream(load(path) as AudioStream, vol_db)


func play_voice_stream(stream: AudioStream, vol_db: float = 0.0) -> float:
	if stream == null or _vo_p == null:
		return -1.0
	_vo_gen += 1
	var gen := _vo_gen
	_vo_p.stream = stream
	_vo_p.volume_db = vol_db
	_vo_p.pitch_scale = 1.0
	_vo_p.play()
	_note(&"озвучка")
	var len_s := stream.get_length()
	if music_name != &"":
		if _music_p != null and _music_p.playing:
			_fade(_music_p, _music_target_db(), 0.3, false)
		if not Juice.instant:
			get_tree().create_timer(len_s + 0.2).timeout.connect(func() -> void:
				if gen == _vo_gen and _music_p != null and music_name != &"":
					_fade(_music_p, _music_target_db(), 0.9, false))
	return len_s


func stop_voice_line() -> void:
	_vo_gen += 1
	if _vo_p != null and _vo_p.playing:
		_vo_p.stop()
		if _music_p != null and _music_p.playing and music_name != &"":
			_fade(_music_p, _music_target_db(), 0.4, false)


func voice_line_playing() -> bool:
	return _vo_p != null and _vo_p.playing


## Сколько секунд озвучки осталось.
func voice_line_left() -> float:
	if _vo_p == null or not _vo_p.playing or _vo_p.stream == null:
		return 0.0
	return maxf(0.0, _vo_p.stream.get_length() - _vo_p.get_playback_position())


func pause_voice_line(on: bool) -> void:
	if _vo_p != null:
		_vo_p.stream_paused = on


## Музыка меню: главная песня, если файл есть.
func menu_music() -> StringName:
	return &"song_pustite" if has_sound(&"song_pustite") else &"menu"


## Фон: «amb_day», «amb_night» или "" (тишина). Плавная смена за fade секунд.
func set_ambience(n: StringName, fade: float = 2.8) -> void:
	if n == ambience_name:
		return
	ambience_name = n
	_note(StringName("фон:" + String(n)))
	_amb_gen += 1
	_dip(_amb_p, n, -4.0, fade, _amb_gen, &"amb")


## Смена звука одного слоя «нырком»: старый затихает за половину времени, потом входит новый.
## Если за это время слой попросили сменить снова, устаревшая смена бросается.
func _dip(p: AudioStreamPlayer, n: StringName, level_db: float, fade: float, gen: int, which: StringName) -> void:
	var half := fade * 0.5
	if p.playing:
		_fade(p, -80.0, half, true)
		await get_tree().create_timer(0.001 if Juice.instant else half).timeout
		if gen != _gen_of(which):
			return
	if n == &"" or not has_sound(n):
		return
	p.stop()
	p.stream = _streams[n]
	p.volume_db = -80.0
	p.play()
	_fade(p, level_db, half, false)


func _gen_of(which: StringName) -> int:
	match which:
		&"amb": return _amb_gen
		&"music": return _music_gen
		&"weather": return _weather_gen
	return _place_generation


## Второй тихий слой по месту действия. Вместе с двумя каналами музыки и фона
## и сердцебиением одновременно работают не более шести длинных потоков.
func set_place_layer(ground: String, river: bool, primary: StringName, fade: float = 2.8) -> void:
	var n: StringName = &""
	var level := -20.0
	if primary != &"":
		if ground == "ground_station":
			n = &"rails"
			level = -24.0
		elif ground == "ground_mill":
			n = &"mill_wheel" # запись текущей воды; отдельной записи мельничного колеса нет
			level = -20.0
		elif river:
			n = &"amb_river"
			level = -18.0
		elif ground == "ground_monastery":
			n = &"amb_dusk"
			level = -23.0
	if n == primary:
		n = &""
	_place_ground = ground if primary != &"" else ""
	if n == _place_name:
		return
	_place_name = n
	_place_generation += 1
	var generation := _place_generation
	_note(StringName("слой:" + String(n)))
	if _place.playing:
		_fade(_place, -80.0, fade * 0.5, true)
		await get_tree().create_timer(0.001 if Juice.instant else fade * 0.5).timeout
		if generation != _place_generation:
			return
	if n == &"" or not has_sound(n):
		return
	_place.stream = _streams[n]
	_place.volume_db = -80.0
	_place.play()
	_fade(_place, level, fade * 0.5, false)


## Какой слой дождя звучит при такой силе и ветре. В доме (у двери ночью) дождь слышен через стену или по крыше.
## Громкость каждого слоя подобрана так, чтобы на слух смена слоя на границе силы не прыгала больше чем на 3 дБ.
static func rain_pick(power: float, wind: float, indoors: bool = false) -> Dictionary:
	if indoors:
		if power < 0.5:
			return {"name": &"amb_rain_inside", "db": -19.5 + 5.0 * power}
		return {"name": &"amb_rain_roof", "db": -19.0 + 5.0 * power}
	if power < 0.4:
		return {"name": &"amb_rain_light", "db": -21.0 + 8.0 * power}
	if power >= 0.7:
		return {"name": &"amb_rain_heavy", "db": -24.0 + 10.0 * power}
	if wind < 0.2:
		return {"name": &"amb_rain_drops", "db": -18.0 + 6.0 * power}
	return {"name": &"amb_rain", "db": -22.5 + 10.0 * power}


## Какой слой погоды и с какой громкостью звучит при таком состоянии погоды.
static func weather_pick(s: Dictionary, indoors: bool = false) -> Dictionary:
	var none := {"name": &"", "db": -80.0}
	if not bool(s.get("active", false)):
		return none
	var power := float(s.get("power", 0.0))
	var wind := absf(float(s.get("wind", 0.0)))
	match int(s.get("precip", Weather.Precip.NONE)):
		Weather.Precip.RAIN:
			if power > 0.05:
				return rain_pick(power, wind, indoors)
		Weather.Precip.SNOW:
			if power > 0.05:
				if wind >= 0.6 or power >= 0.8:
					return {"name": &"amb_blizzard", "db": -28.0 + 12.0 * power}
				return {"name": &"amb_wind", "db": -34.0 + 10.0 * power + 8.0 * wind}
	if wind >= 0.3:
		return {"name": &"amb_wind", "db": -36.0 + 14.0 * wind}
	return none


## Слой погоды: ветер, дождь или метель по состоянию погоды. Тот же слой только меняет громкость.
## indoors: игрок за дверью дома, дождь слышен через стену.
func set_weather_layer(s: Dictionary, fade: float = 3.0, indoors: bool = false) -> void:
	var pick := weather_pick(s, indoors)
	var n: StringName = pick["name"]
	weather_db = float(pick["db"])
	_wx_power = float(s.get("power", 0.0)) if bool(s.get("active", false)) and int(s.get("precip", Weather.Precip.NONE)) == Weather.Precip.RAIN else 0.0
	_wx_indoors = indoors
	if n == weather_name:
		if n != &"" and _weather_p.playing:
			_fade(_weather_p, weather_db, fade * 0.5, false)
		return
	if _wx_power >= THUNDER_MIN_POWER and weather_name == &"":
		_thunder_clock = randf_range(10.0, 22.0)   # первый раскат не сразу и не через минуту
	weather_name = n
	_note(StringName("погода:" + String(n)))
	_weather_gen += 1
	_dip(_weather_p, n, weather_db, fade, _weather_gen, &"weather")


## Жизнь посёлка: днём говор и редкие собака с курами. Чем меньше живых, тем тише; при трети живых говор гаснет.
func set_life(alive_ratio: float, day: bool, fade: float = 3.0) -> void:
	life_ratio = clampf(alive_ratio, 0.0, 1.0)
	life_day = day
	var target := life_db()
	if target <= -60.0 or not has_sound(&"life_murmur"):
		if _life_p.playing:
			_fade(_life_p, -80.0, fade * 0.5, true)
		return
	if not _life_p.playing:
		_life_p.stream = _streams[&"life_murmur"]
		_life_p.volume_db = -80.0
		_life_p.play()
	_fade(_life_p, target, fade * 0.5, false)


## Громкость говора по доле живых; ночью и при малом числе живых его нет.
func life_db() -> float:
	if not life_day or life_ratio < 0.34:
		return -80.0
	return lerpf(-46.0, -27.0, (life_ratio - 0.34) / 0.66)


## Напряжение 0..1: глушит фон фильтром (слух сжимается) и ускоряет пульс.
func set_tension(t: float, fade: float = 1.5) -> void:
	tension = clampf(t, 0.0, 1.0)
	var cutoff := lerpf(20500.0, 2600.0, tension)
	if _amb_filter != null:
		if Juice.instant or fade <= 0.0:
			_amb_filter.cutoff_hz = cutoff
		else:
			create_tween().tween_property(_amb_filter, "cutoff_hz", cutoff, fade)
	_apply_pace()


## Сколько длинных потоков звучит сейчас. Не больше LONG_LIMIT.
func long_streams() -> int:
	var n := 0
	for p: AudioStreamPlayer in [_music_p, _amb_p, _place, _weather_p, _life_p, _heart]:
		if p != null and p.playing:
			n += 1
	return n


## Сила дождя для грома и признак «в доме». Нулевая сила: дождя нет, грома нет.
var _wx_power := 0.0
var _wx_indoors := false
var _thunder_clock := 25.0
const THUNDER_MIN_POWER := 0.6


## Через сколько секунд следующий раскат. Меньше 0: при такой силе дождя грома нет. roll 0..1 разбрасывает интервал.
static func thunder_gap(power: float, roll: float) -> float:
	if power < THUNDER_MIN_POWER:
		return -1.0
	var base := lerpf(80.0, 28.0, clampf((power - THUNDER_MIN_POWER) / 0.4, 0.0, 1.0))
	return base * lerpf(0.7, 1.3, clampf(roll, 0.0, 1.0))


## Раскат в сильный дождь. Возвращает true, если раскат сыграл. Вне дома громче и ближе, в доме глухой.
func _tick_thunder(delta: float) -> bool:
	if thunder_gap(_wx_power, 0.5) < 0.0 or weather_name == &"":
		return false
	_thunder_clock -= delta
	if _thunder_clock > 0.0:
		return false
	_thunder_clock = thunder_gap(_wx_power, randf())
	if _wx_indoors:
		play(&"thunder_far", randf_range(0.92, 1.02), -7.0)
	else:
		play(&"thunder", randf_range(0.9, 1.0), -4.0 - 4.0 * randf())
	return true


func _process(delta: float) -> void:
	_tick_thunder(delta)
	if not life_day and _place_ground != "ground_monastery":
		return
	_life_clock -= delta
	_bell_clock -= delta
	if _life_clock <= 0.0:
		_life_clock = randf_range(14.0, 30.0) / (0.5 + life_ratio)
		if life_day and life_ratio >= 0.34:
			play(&"life_hens" if randf() < 0.6 else &"life_dog", randf_range(0.92, 1.08), -22.0 + 8.0 * life_ratio)
	if _bell_clock <= 0.0:
		_bell_clock = randf_range(45.0, 80.0)
		if _place_ground == "ground_monastery":
			for k in range(3):
				await get_tree().create_timer(0.001 if Juice.instant else 2.4 * float(k)).timeout
				play(&"bell", 1.0, -26.0)


## Музыка: «menu», «day», «night» или "" (тишина).
func set_music(n: StringName, fade: float = 2.8) -> void:
	if n == music_name:
		return
	music_name = n
	_note(StringName("музыка:" + String(n)))
	_music_gen += 1
	_dip(_music_p, n, _music_target_db(), fade, _music_gen, &"music")


## Сердцебиение: у двери и в последние секунды.
func heartbeat(on: bool) -> void:
	if on == heart_on:
		if not on:
			set_heartbeat_pace(1.0)
		return
	heart_on = on
	_note(&"сердце:вкл" if on else &"сердце:выкл")
	if on:
		if not _heart.playing:
			_heart.volume_db = -80.0
			_heart.play()
		_fade(_heart, -3.0, 0.8, false)
		if _music_p.playing:
			_fade(_music_p, _music_target_db(), 0.8, false)
	else:
		_fade(_heart, -80.0, 0.8, true)
		set_heartbeat_pace(1.0)
		if _music_p.playing:
			_fade(_music_p, _music_target_db(), 0.8, false)


## Несколько ударов подряд немного ускоряют пульс; скорость не зависит от того, кого стучит.
func set_heartbeat_pace(pace: float) -> void:
	_pace = pace
	_apply_pace()


## Пульс = темп двери (число стучащих) плюс до 10 % от напряжения.
func _apply_pace() -> void:
	if _heart != null:
		_heart.pitch_scale = clampf(_pace * (1.0 + 0.1 * tension), 0.85, 1.2)


## Уровень каждой темы относительно канала: днём музыка тише, чтобы не перекрывать реплики и фон.
const MUSIC_LEVEL := {&"day": -11.0, &"night": -9.0, &"song": -4.0}   # песни (song_*) нормированы тише старых тем, поэтому громче на 4 дБ


func _music_target_db() -> float:
	var base: float = MUSIC_LEVEL.get(music_name, MUSIC_LEVEL.get(StringName(String(music_name).get_slice("_", 0)), -8.0))
	if heart_on:
		base -= 5.0
	if voice_line_playing():
		base -= DUCK_DB
	return base


## Громкость канала, 0..1. 0 — канал заглушён полностью.
func set_volume(bus: StringName, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	v = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001 or _muted_by_os)


func volume(bus: StringName) -> float:
	var i := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(i)) if i >= 0 else 0.0


func is_bus_muted(bus: StringName) -> bool:
	var i := AudioServer.get_bus_index(bus)
	return i >= 0 and AudioServer.is_bus_mute(i)


## Свёрнуто или потерян фокус: заглушить всё. Вернулись: вернуть каналам их громкость.
func os_mute(on: bool) -> void:
	_muted_by_os = on
	for b: StringName in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_mute(i, on or volume(b) <= 0.001)


func _fade(p: AudioStreamPlayer, to_db: float, dur: float, stop_after: bool) -> Tween:
	if _tw.has(p) and (_tw[p] as Tween).is_valid():
		(_tw[p] as Tween).kill()
	var t := create_tween()
	_tw[p] = t
	if Juice.instant or dur <= 0.0:
		t.tween_property(p, "volume_db", to_db, 0.001)
	else:
		t.tween_property(p, "volume_db", to_db, dur)
	if stop_after:
		t.tween_callback(p.stop)
	return t


func _note(n: StringName) -> void:
	played.append(n)
	if played.size() > LOG_MAX:
		played = played.slice(played.size() - LOG_MAX)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			os_mute(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			os_mute(false)
