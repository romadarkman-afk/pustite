class_name DebugScreen
extends Screen
## Скрытое отладочное меню (TASK-096). Открывается пятью быстрыми тапами по строке версии внизу настроек,
## только в отладочной сборке (APK из CI). В релизной сборке для магазина меню не существует.
## Содержимое: счётчик кадров, живые цифры устройства и движка, переход в любую главу.
## Текст на русском без перевода: меню для разработчика, игрок его не видит.

const TAPS := 5                  ## столько тапов
const TAP_WINDOW_MSEC := 3000    ## за столько миллисекунд
const REFRESH_SEC := 0.5

var _info: Label
var _acc := 0.0
var _counter_button: Button


## Меню есть только в отладочной сборке.
static func available() -> bool:
	return OS.is_debug_build()


func screen_id() -> String:
	return "debug"


func title() -> String:
	return "Отладка"


func mood() -> Vector2:
	return Vector2(0.8, 0.6)


func build() -> void:
	W.clear(body)
	W.clear(footer)
	body.add_child(W.label("Только отладочная сборка. Главы, начатые отсюда, сохраняют результат как в обычной игре.", &"Small"))
	_counter_button = W.button(_counter_text(), &"RowOn" if _counter_on() else &"Row")
	_counter_button.name = "CounterToggle"
	_counter_button.pressed.connect(func() -> void:
		Nav.perf.set_counter_visible(not _counter_on())
		_counter_button.text = _counter_text()
		_counter_button.theme_type_variation = &"RowOn" if _counter_on() else &"Row")
	body.add_child(_counter_button)
	_info = W.label(info_text(), &"Small")
	_info.name = "Info"
	body.add_child(_info)
	body.add_child(W.label("Перейти к главе", &"Hint"))
	for id: String in Campaign.ORDER:
		var key := id
		var open := Campaign.unlocked(id)
		var b := W.button("%s  %s%s" % [id, L.t("camp.%s.title" % id), "" if open else "  (закрыта)"], &"Row")
		b.name = "Chapter_" + id
		b.pressed.connect(func() -> void: emit_intent(Intent.DEBUG_CHAPTER, {"id": key}))
		body.add_child(b)
	var back := W.button(L.t("ui.back"), &"Ghost")
	back.name = "DebugBack"
	back.pressed.connect(func() -> void: emit_intent(Intent.DEBUG_CLOSE, {}))
	footer.add_child(back)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < REFRESH_SEC:
		return
	_acc = 0.0
	if _info != null:
		_info.text = info_text()


static func _counter_on() -> bool:
	return Nav.perf != null and Nav.perf.counter_visible()


static func _counter_text() -> String:
	return "Счётчик кадров: " + ("включён" if _counter_on() else "выключен")


## Живые цифры: кадры, узлы, объекты, память картинок и всего, устройство.
static func info_text() -> String:
	var lines := PackedStringArray()
	lines.append("Версия %s, %s" % [ProjectSettings.get_setting("application/config/version", "?"), "отладочная" if OS.is_debug_build() else "релизная"])
	lines.append("Телефон: %s, Android %s" % [OS.get_model_name(), OS.get_version()])
	lines.append("Видео: %s" % RenderingServer.get_video_adapter_name())
	lines.append("Кадры: %d сейчас, худшая секунда %d" % [roundi(Nav.perf.fps), roundi(Nav.perf.worst)] if Nav.perf != null else "Кадры: нет данных")
	lines.append("Узлов %d, объектов %d, вызовов отрисовки %d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	lines.append("Память: картинки %.0f МиБ, видео %.0f МиБ, статическая %.0f МиБ" % [
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	lines.append("Упрощённая графика: %s" % ("да" if Save.simplified_graphics else "нет"))
	return "\n".join(lines)


## Счётчик быстрых тапов по версии. Чистая логика без узлов, чтобы проверять без экрана.
class TapCounter:
	extends RefCounted
	var times: Array[int] = []

	## Тап в момент now_msec. Истина, когда набралось TAPS тапов за TAP_WINDOW_MSEC; счётчик после этого сбрасывается.
	func hit(now_msec: int) -> bool:
		times.append(now_msec)
		while not times.is_empty() and now_msec - times[0] > DebugScreen.TAP_WINDOW_MSEC:
			times.pop_front()
		if times.size() >= DebugScreen.TAPS:
			times.clear()
			return true
		return false
