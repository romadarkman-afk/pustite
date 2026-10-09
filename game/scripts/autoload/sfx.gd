extends Node
## Звук: одиночные звуки, фон (ветер, сверчки), музыка и сердцебиение.
## Все звуки синтезированы из формул (tools/make_sfx.py), лицензий не требуют.
## Музыку можно заменить своими треками: положить файлы с теми же именами в assets/music/.
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
	&"exile": "res://assets/sfx/exile.ogg",
	&"win": "res://assets/sfx/win.ogg",
	&"lose": "res://assets/sfx/lose.ogg",
	&"reveal": "res://assets/sfx/reveal.ogg",
	&"dawn": "res://assets/sfx/dawn.ogg",
}
const LOOPS := {
	&"amb_day": "res://assets/sfx/amb_day.ogg",
	&"amb_night": "res://assets/sfx/amb_night.ogg",
	&"heartbeat": "res://assets/sfx/heartbeat.ogg",
	&"menu": "res://assets/music/menu.ogg",
	&"day": "res://assets/music/day.ogg",
}
const BUSES := [&"Music", &"Sfx", &"Ambience"]
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
var _music: AudioStreamPlayer
var _amb: Array[AudioStreamPlayer] = []
var _amb_i := 0
var _heart: AudioStreamPlayer
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
	for k: StringName in SOUNDS:
		_streams[k] = load(SOUNDS[k])
	for k: StringName in LOOPS:
		var s := load(LOOPS[k]) as AudioStreamOggVorbis
		if s != null:
			s.loop = true
		_streams[k] = s
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = &"Sfx"
		add_child(p)
		_pool.append(p)
	_music = _player(&"Music")
	_amb = [_player(&"Ambience"), _player(&"Ambience")]
	_heart = _player(&"Sfx")
	_heart.stream = _streams[&"heartbeat"]


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
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[n]
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = vol_db
	p.play()


## Голос жителя: 2–4 слога-писка с высотой, своей у каждого. Слышно, кто говорит.
func voice(speaker_id: int, female: bool, text_len: int) -> void:
	var base := (1.35 if female else 0.95) + 0.06 * float((speaker_id * 37) % 7)
	var n := clampi(text_len / 12, 2, 4)
	for i in range(n):
		if i > 0:
			await get_tree().create_timer(0.085).timeout
		play(&"blip", base * (1.0 + 0.09 * sin(float(i) * 2.3 + speaker_id)), -6.0)


## Фон: «amb_day», «amb_night» или "" (тишина). Плавная смена за fade секунд.
func set_ambience(n: StringName, fade: float = 1.5) -> void:
	if n == ambience_name:
		return
	ambience_name = n
	_note(StringName("фон:" + String(n)))
	var old := _amb[_amb_i]
	_amb_i = 1 - _amb_i
	var cur := _amb[_amb_i]
	_fade(old, -80.0, fade, true)
	if n != &"" and has_sound(n):
		cur.stream = _streams[n]
		cur.volume_db = -80.0
		cur.play()
		_fade(cur, -4.0, fade, false)


## Музыка: «menu», «day» или "" (тишина).
func set_music(n: StringName, fade: float = 1.2) -> void:
	if n == music_name:
		return
	music_name = n
	_note(StringName("музыка:" + String(n)))
	if n == &"" or not has_sound(n):
		_fade(_music, -80.0, fade, true)
		return
	if _music.playing and _music.stream != _streams[n]:
		var t := _fade(_music, -80.0, fade * 0.5, true)
		await t.finished
		if music_name != n:
			return
	_music.stream = _streams[n]
	if not _music.playing:
		_music.volume_db = -80.0
		_music.play()
	_fade(_music, -8.0, fade, false)


## Сердцебиение: у двери и в последние секунды.
func heartbeat(on: bool) -> void:
	if on == heart_on:
		return
	heart_on = on
	_note(&"сердце:вкл" if on else &"сердце:выкл")
	if on:
		if not _heart.playing:
			_heart.volume_db = -80.0
			_heart.play()
		_fade(_heart, -3.0, 0.8, false)
	else:
		_fade(_heart, -80.0, 0.8, true)


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
