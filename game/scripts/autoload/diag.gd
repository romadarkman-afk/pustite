extends Node
## Бортовой самописец. После каждого шага игры дописывает его в файл.
## Если игра вылетела, при следующем запуске видно, на каком шаге оборвалось.
## Флаг «игра работает» снимается при нормальном выходе и при сворачивании —
## поэтому выгрузка системой в фоне за вылет не считается.

const TEST_FLAGS: PackedStringArray = ["--sim", "--flow", "--layout", "--lifecycle", "--field", "--crowd",
	"--bubbles", "--marks", "--input", "--hints", "--difficulty", "--howto", "--night", "--eyes", "--lights", "--checkpoint", "--sound",
	"--village", "--talisman", "--bell", "--events", "--mimic", "--sabotage", "--box", "--roles",
	"--meeting", "--tunnel", "--diary", "--recap", "--folk", "--loc", "--access", "--daily",
	"--cosmetics", "--adapt", "--display", "--gestures", "--storage", "--save"]

var test_scope := ""
var CRUMBS := "user://crumbs.txt"
var FLAG := "user://running.flag"
var LOG := "user://logs/godot.log"
const MAX := 40

var enabled := true
var crashed_last_time := false
var last_crumbs: PackedStringArray = []
var _ring: PackedStringArray = []
var _t0 := 0


func _enter_tree() -> void:
	var args := OS.get_cmdline_user_args()
	for arg: String in args:
		var flag := arg.get_slice("=", 0)
		if TEST_FLAGS.has(flag):
			test_scope = flag.trim_prefix("--")
			for option: String in ["--lang=", "--text="]:
				for value: String in args:
					if value.begins_with(option):
						test_scope += "_" + value.get_slice("=", 1)
			_reset_test_directory()
			break
	CRUMBS = test_path("crumbs.txt")
	FLAG = test_path("running.flag")
	LOG = test_path("logs/godot.log")
	if not test_scope.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_path("logs")))


func test_path(relative_path: String) -> String:
	if test_scope.is_empty():
		return "user://" + relative_path
	return "user://test_%s/%s" % [test_scope, relative_path]


func _reset_test_directory() -> void:
	var path := ProjectSettings.globalize_path("user://test_%s" % test_scope)
	_remove_test_tree(path)
	DirAccess.make_dir_recursive_absolute(path)


func _remove_test_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	var files := dir.get_files()
	var folders := dir.get_directories()
	dir = null
	for file: String in files:
		DirAccess.remove_absolute(path.path_join(file))
	for subdir: String in folders:
		_remove_test_tree(path.path_join(subdir))
	DirAccess.remove_absolute(path)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			enabled = false          # самотесты: без флага и без экрана отчёта
	if not enabled:
		return
	check_previous()
	set_running(true)
	step("запуск: %s · Android %s · %s · %s" % [OS.get_model_name(), OS.get_version(),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])


func check_previous() -> void:
	crashed_last_time = FileAccess.file_exists(FLAG)
	last_crumbs = _read(CRUMBS)


func step(t: String) -> void:
	_ring.append("%6.1f с  %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, t])
	if _ring.size() > MAX:
		_ring.remove_at(0)
	if enabled:
		var f := FileAccess.open(CRUMBS, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_ring))
			f.close()


func set_running(on: bool) -> void:
	if on:
		var f := FileAccess.open(FLAG, FileAccess.WRITE)
		if f != null:
			f.store_string("1")
			f.close()
	elif FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))


func clean_exit() -> void:
	step("нормальный выход")
	set_running(false)


func _notification(what: int) -> void:
	if not enabled:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			step("свернули")
			set_running(false)
		NOTIFICATION_APPLICATION_RESUMED:
			set_running(true)
			step("вернулись")
		NOTIFICATION_WM_CLOSE_REQUEST:
			clean_exit()


func report_text() -> String:
	var lines: PackedStringArray = ["«Пустите» %s — отчёт об аварийном закрытии" % ProjectSettings.get_setting("application/config/version", "?"),
		"Телефон: %s, Android %s" % [OS.get_model_name(), OS.get_version()],
		"Видео: %s, %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()],
		"", "Последние шаги перед вылетом:"]
	lines.append_array(last_crumbs)
	var log_tail := _read(LOG)
	if not log_tail.is_empty():
		lines.append("")
		lines.append("Хвост журнала:")
		lines.append_array(log_tail.slice(maxi(0, log_tail.size() - 25)))
	return "\n".join(lines)


func _read(path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return PackedStringArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var s := f.get_as_text()
	f.close()
	return s.split("\n", false)
