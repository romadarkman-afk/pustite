class_name PerfGuard
extends Node
## TASK-070: следит за кадрами.
## Если 5 секунд подряд идёт меньше 25 кадров в секунду, подаёт сигнал degraded:
## Nav включает упрощённую графику сам (один раз за установку).
## В отладочной сборке (на телефоне это APK из CI) в углу виден счётчик: кадры за последнюю
## секунду и худшая секунда с начала экрана. По нему Влади записывает замер в docs/budget.md.

signal degraded

const LOW_FPS := 25.0
const LOW_WINDOWS := 5                ## столько секунд подряд ниже LOW_FPS
const WINDOW := 1.0                   ## окно подсчёта, секунды
const MAX_STEP := 0.5                 ## одиночная пауза (загрузка, сворачивание) весит не больше полусекунды

var fps := 0.0                        ## кадров в секунду за последнее окно
var worst := 0.0                      ## худшее окно с последнего сброса; 0 — окон ещё не было
var low_streak := 0                   ## сколько окон подряд были ниже LOW_FPS
var triggered := false                ## сигнал уже подан на этом запуске
var simplified := false               ## показывать в счётчике пометку упрощённой графики
var _frames := 0
var _time := 0.0
var _label: Label
var _layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_label = Label.new()
	_label.name = "FpsCounter"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	_label.position = Vector2(10, 6)
	_label.visible = counter_wanted()
	_layer.add_child(_label)


## Счётчик нужен в отладочной сборке; в релизе и без экрана (самотесты) его нет.
static func counter_wanted() -> bool:
	return OS.is_debug_build() and DisplayServer.get_name() != "headless"


func counter_visible() -> bool:
	return _label != null and _label.visible


func set_counter_visible(on: bool) -> void:
	if _label != null:
		_label.visible = on
		_refresh_label()


func counter_text() -> String:
	if worst <= 0.0:
		return "FPS …"
	return "FPS %d  мин %d%s" % [roundi(fps), roundi(worst), "  упрощ." if simplified else ""]


func _process(delta: float) -> void:
	if Juice.instant or DisplayServer.get_name() == "headless":
		return
	feed(delta)


## Один кадр. Возвращает true в тот кадр, когда подан сигнал упрощения.
func feed(delta: float) -> bool:
	_frames += 1
	_time += minf(delta, MAX_STEP)
	if _time < WINDOW:
		return false
	fps = float(_frames) / _time
	_frames = 0
	_time = 0.0
	worst = fps if worst <= 0.0 else minf(worst, fps)
	low_streak = low_streak + 1 if fps < LOW_FPS else 0
	_refresh_label()
	if low_streak >= LOW_WINDOWS and not triggered:
		triggered = true
		degraded.emit()
		return true
	return false


## Сброс статистики при смене экрана: худшая секунда относится к текущему экрану.
func reset_stats() -> void:
	worst = 0.0
	_refresh_label()


## Свёрнутая игра и потеря фокуса не считаются зависанием.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_frames = 0
		_time = 0.0
		low_streak = 0


func _refresh_label() -> void:
	if _label != null and _label.visible:
		_label.text = counter_text()
