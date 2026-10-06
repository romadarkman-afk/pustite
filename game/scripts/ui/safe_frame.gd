class_name SafeFrame
extends MarginContainer
## Поля экрана с учётом выреза камеры, жестовой панели, клавиатуры и планшетов.
## Контент не шире MAX_WIDTH — на планшете он не размазывается на всю ширину.

const BASE := Vector4(32, 36, 32, 28)   ## лево, верх, право, низ
const MAX_WIDTH := 760.0

var _kb_was_open := false
var _last_kb := 0.0
## Текущие поля безопасной зоны в пикселях вьюпорта: лево, верх, право, низ.
var insets := Vector4.ZERO
## Для самотестов: имитация выреза камеры и жестовой панели. -1 — брать с устройства.
var debug_insets := Vector4(-1, -1, -1, -1)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var focus := get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit
	if typing or _kb_was_open:
		refresh()
		_kb_was_open = typing


func refresh() -> void:
	var vp := get_viewport_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var k := vp.y / win.y if win.y > 0.0 else 1.0
	var inset := Vector4.ZERO

	var safe := DisplayServer.get_display_safe_area()
	var screen := Vector2(DisplayServer.screen_get_size())
	if safe.size.x > 0 and safe.size.y > 0 and screen.y > 0.0:
		inset.x = safe.position.x * k
		inset.y = safe.position.y * k
		inset.z = (screen.x - safe.end.x) * k
		inset.w = (screen.y - safe.end.y) * k

	if debug_insets.x >= 0.0:
		inset = debug_insets
	insets = inset

	var keyboard := 0.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		keyboard = float(DisplayServer.virtual_keyboard_get_height()) * k
		if absf(keyboard - _last_kb) > 1.0:
			_last_kb = keyboard
			Diag.step("клавиатура: %d px" % int(keyboard))
	var side := maxf(0.0, (vp.x - MAX_WIDTH) * 0.5)

	add_theme_constant_override("margin_left", int(BASE.x + maxf(inset.x, side)))
	add_theme_constant_override("margin_top", int(BASE.y + inset.y))
	add_theme_constant_override("margin_right", int(BASE.z + maxf(inset.z, side)))
	add_theme_constant_override("margin_bottom", int(BASE.w + maxf(inset.w, keyboard)))
