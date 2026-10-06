class_name PhaseClock
extends Node
## Таймер фазы. Секунды наружу — сигналом, окончание — сигналом.

signal ticked(seconds_left: int)
signal finished

var _left: float = 0.0
var _running: bool = false
var _last_int: int = -1


func start(seconds: float) -> void:
	_left = seconds
	_running = true
	_last_int = -1


func stop() -> void:
	_running = false


func running() -> bool:
	return _running


func _process(delta: float) -> void:
	if not _running:
		return
	_left -= delta
	var s := maxi(0, ceili(_left))
	if s != _last_int:
		_last_int = s
		ticked.emit(s)
	if _left <= 0.0:
		_running = false
		finished.emit()
