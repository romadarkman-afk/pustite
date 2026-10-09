class_name PhaseClock
extends Node
## Таймер фазы. Секунды наружу — сигналом, окончание — сигналом.
## Ставится на паузу по причинам («в фоне», «открыт вопрос») и идёт, только когда причин нет.
## Шаг за кадр ограничен: после возврата из фона первый кадр может принести
## дельту в десятки секунд — без ограничения таймер сгорел бы за один кадр.

signal ticked(seconds_left: int)
signal finished

const MAX_STEP := 0.25

var _left: float = 0.0
var _running: bool = false
var _last_int: int = -1
var _holds: Dictionary[StringName, bool] = {}


func start(seconds: float) -> void:
	_left = seconds
	_running = true
	_last_int = -1


func stop() -> void:
	_running = false


func running() -> bool:
	return _running


func time_left() -> float:
	return _left


func hold(reason: StringName) -> void:
	_holds[reason] = true


func release(reason: StringName) -> void:
	_holds.erase(reason)


func held() -> bool:
	return not _holds.is_empty()


func held_by(reason: StringName) -> bool:
	return _holds.has(reason)


func _process(delta: float) -> void:
	if not _running or held():
		return
	_left -= minf(delta, MAX_STEP)
	var s := maxi(0, ceili(_left))
	if s != _last_int:
		_last_int = s
		ticked.emit(s)
	if _left <= 0.0:
		_running = false
		finished.emit()
