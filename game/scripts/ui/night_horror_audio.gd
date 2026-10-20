class_name NightHorrorAudio
extends Node
## Редкие звуки ночи только в главном меню. Основные дорожки и настройки громкости
## остаются в Sfx; здесь выбираются короткие события и их сторона стереополя.

const EVENTS: Array[Dictionary] = [
	{"id": &"scratch", "pitch": Vector2(0.86, 1.02), "gain": -15.0},
	{"id": &"scratch", "pitch": Vector2(0.93, 1.08), "gain": -18.0},
	{"id": &"roof_steps", "pitch": Vector2(0.88, 1.0), "gain": -18.0},
	{"id": &"creak", "pitch": Vector2(0.9, 1.04), "gain": -18.0},
	{"id": &"whisper", "pitch": Vector2(0.78, 0.94), "gain": -21.0},
	{"id": &"call_far", "pitch": Vector2(0.84, 0.98), "gain": -20.0},
	{"id": &"cry_far", "pitch": Vector2(0.9, 1.02), "gain": -21.0},
	{"id": &"growl", "pitch": Vector2(0.78, 0.92), "gain": -20.0},
]

var _rng := RandomNumberGenerator.new()
var _active := false
var _wait := 0.0
var _last_id: StringName = &""


func _ready() -> void:
	_rng.randomize()


func set_menu_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	if active:
		_wait = _rng.randf_range(3.5, 6.0)
	else:
		_wait = 0.0
		Sfx.stop_panned()


func is_menu_active() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_play_event()
	_wait = _rng.randf_range(8.0, 20.0)


func _play_event() -> void:
	var choices: Array[Dictionary] = []
	for event: Dictionary in EVENTS:
		if StringName(event.id) != _last_id:
			choices.append(event)
	if choices.is_empty():
		return
	var event: Dictionary = choices[_rng.randi_range(0, choices.size() - 1)]
	_last_id = StringName(event.id)
	var pitch_range: Vector2 = event.pitch
	var side := -1 if _rng.randf() < 0.5 else 1
	Sfx.play_panned(_last_id, side, _rng.randf_range(pitch_range.x, pitch_range.y), float(event.gain))
