extends Node
## Звук: одиночные звуки, фон (ветер, сверчки), музыка и сердцебиение.
## Основные фоновые дорожки и голоса взяты из записей CC0 (см. AUDIO_SOURCES.md).
##
## Каналы громкости: Music, Sfx, Ambience — каждый отдельно в настройках.
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
	&"human_cry_m": "res://assets/sfx/human_cry.wav",
	&"human_cry_f": "res://assets/sfx/human_cry_f.ogg",
	&"upyr_cry": "res://assets/sfx/upyr_cry.wav",
	&"exile": "res://assets/sfx/exile.ogg",
	&"win": "res://assets/sfx/win.ogg",
	&"lose": "res://assets/sfx/lose.ogg",
	&"reveal": "res://assets/sfx/reveal.ogg",
	&"reveal_2": "res://assets/sfx/reveal_2.ogg",   # пролог: варианты раскрытия роли (tools/make_prologue_sfx.py)
	&"reveal_3": "res://assets/sfx/reveal_3.ogg",
	&"dawn": "res://assets/sfx/dawn.ogg",
	&"job_done": "res://assets/sfx/job_done.ogg",
	&"job_fail": "res://assets/sfx/job_fail.ogg",
	# звуки страха (Dread, tools/make_dread.py)
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
	# сцены (TASK-012–014, tools/make_scene_sfx.py)
	&"breath": "res://assets/sfx/breath.ogg",
	&"cup_break": "res://assets/sfx/cup_break.ogg",
	&"hammer": "res://assets/sfx/hammer.ogg",
	&"latch": "res://assets/sfx/latch.ogg",
	&"floorboard": "res://assets/sfx/floorboard.ogg",
}
const LOOPS := {
	&"amb_day": "res://assets/sfx/amb_day.ogg",
	&"amb_night": "res://assets/sfx/amb_night.ogg",
	&"amb_dusk": "res://assets/sfx/amb_dusk.ogg",       # пролог: ветер без сверчков
	&"amb_river": "res://assets/sfx/amb_river.ogg",     # сцена у реки (глава «Стук»)
	&"whistle": "res://assets/sfx/whistle.ogg",         # станция (TASK-031): гудок вдали
	&"rails": "res://assets/sfx/rails.ogg",             # лязг рельсов
	&"typewriter": "res://assets/sfx/typewriter.ogg",   # список на поезд (TASK-033)
	&"train": "res://assets/sfx/train.ogg",             # подходящий поезд (TASK-034, 035)
	&"heartbeat": "res://assets/sfx/heartbeat.ogg",
	&"menu": "res://assets/music/menu.ogg",
	&"day": "res://assets/music/day.ogg",
	&"night": "res://assets/music/night.ogg",
	&"end_dawn": "res://assets/music/end_dawn.ogg",     # итог: люди дожили (tools/make_end_music.py)
	&"end_dark": "res://assets/music/end_dark.ogg",     # итог: посёлок пал
	&"river_theme": "res://assets/music/river_theme.wav",
}
## Звук с вариантами: каждый раз случайный из списка, в журнал пишется общее имя.
const VARIANTS := {&"reveal": [&"reveal", &"reveal_2", &"reveal_3"]}
const BUSES := [&"Music", &"Sfx", &"Ambience"]
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
var _music: Array[AudioStreamPlayer] = []
var _music_i := 0
var _amb: Array[AudioStreamPlayer] = []
var _amb_i := 0
var _place: AudioStreamPlayer
var _place_name: StringName = &""
var _place_generation := 0
var _heart: AudioStreamPlayer
var _panned_player: AudioStreamPlayer
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
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = &"Sfx"
		add_child(p)
		_pool.append(p)
	_music = [_player(&"Music"), _player(&"Music")]
	_amb = [_player(&"Ambience"), _player(&"Ambience")]
	_place = _player(&"Ambience")
	_heart = _player(&"Sfx")
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
	p.stream = _streams.get(stream_name, _streams[n])
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = vol_db
	p.play()


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
	_panned_player.stream = _streams.get(stream_name, _streams[n])
	_panned_player.pitch_scale = clampf(pitch, 0.25, 4.0)
	_panned_player.volume_db = vol_db
	_panned_player.play()


func stop_panned(fade: float = 0.12) -> void:
	if _panned_player != null and _panned_player.playing:
		_fade(_panned_player, -80.0, fade, true)


## Голос жителя: 2–4 слога-писка с высотой, своей у каждого. Слышно, кто говорит.
## mood — состояние говорящего (TASK-009): в горе ниже и медленнее, в страхе выше и чаще.
func voice(speaker_id: int, female: bool, text_len: int, mood: String = "") -> void:
	var base := (1.35 if female else 0.95) + 0.06 * float((speaker_id * 37) % 7)
	var gap := 0.085
	match mood:
		"grief", "despair", "guilt", "exhaustion":
			base *= 0.86
			gap = 0.13
		"fear":
			base *= 1.12
			gap = 0.06
		"rage":
			base *= 0.95
			gap = 0.07
	var n := clampi(text_len / 12, 2, 4)
	for i in range(n):
		if i > 0:
			await get_tree().create_timer(gap).timeout
		play(&"blip", base * (1.0 + 0.09 * sin(float(i) * 2.3 + speaker_id)), -15.0)


## Фон: «amb_day», «amb_night» или "" (тишина). Плавная смена за fade секунд.
func set_ambience(n: StringName, fade: float = 2.8) -> void:
	if n == ambience_name:
		return
	ambience_name = n
	_note(StringName("фон:" + String(n)))
	var old := _amb[_amb_i]
	_amb_i = 1 - _amb_i
	var cur := _amb[_amb_i]
	_fade(old, -80.0, fade, true)
	if n != &"" and has_sound(n):
		cur.stop()
		cur.stream = _streams[n]
		cur.volume_db = -80.0
		cur.play()
		_fade(cur, -4.0, fade, false)


## Второй тихий слой по месту действия. Вместе с двумя каналами музыки и фона
## и сердцебиением одновременно работают не более шести длинных потоков.
func set_place_layer(ground: String, river: bool, primary: StringName, fade: float = 2.8) -> void:
	var n: StringName = &""
	var level := -20.0
	if primary != &"":
		if ground == "ground_station":
			n = &"rails"
			level = -24.0
		elif river:
			n = &"amb_river"
			level = -18.0
		elif ground == "ground_monastery":
			n = &"amb_dusk"
			level = -23.0
	if n == primary:
		n = &""
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


## Музыка: «menu», «day», «night» или "" (тишина).
func set_music(n: StringName, fade: float = 2.8) -> void:
	if n == music_name:
		return
	music_name = n
	_note(StringName("музыка:" + String(n)))
	var old := _music[_music_i]
	_music_i = 1 - _music_i
	var cur := _music[_music_i]
	_fade(old, -80.0, fade, true)
	if n == &"" or not has_sound(n):
		return
	cur.stop()
	cur.stream = _streams[n]
	cur.volume_db = -80.0
	cur.play()
	_fade(cur, _music_target_db(), fade, false)


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
		for p: AudioStreamPlayer in _music:
			if p.playing:
				_fade(p, _music_target_db(), 0.8, false)
	else:
		_fade(_heart, -80.0, 0.8, true)
		set_heartbeat_pace(1.0)
		for p: AudioStreamPlayer in _music:
			if p.playing:
				_fade(p, _music_target_db(), 0.8, false)


## Несколько ударов подряд немного ускоряют пульс; скорость не зависит от того, кого стучит.
func set_heartbeat_pace(pace: float) -> void:
	if _heart != null:
		_heart.pitch_scale = clampf(pace, 0.85, 1.2)


func _music_target_db() -> float:
	return -13.0 if heart_on else -8.0


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
