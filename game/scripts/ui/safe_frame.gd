class_name SafeFrame
extends MarginContainer
## Поля экрана с учётом выреза камеры, жестовой панели, клавиатуры и планшетов.
## Контент не шире MAX_WIDTH — на планшете он не размазывается на всю ширину.

const BASE := Vector4(32, 36, 32, 28)   ## лево, верх, право, низ
const SIDE_MIN := 16.0                  ## боковое поле на самом узком телефоне
const SIDE_NARROW_VP := 450.0           ## ширина экрана в единицах, с которой поле минимальное
const SIDE_WIDE_VP := 600.0             ## и с которой оно полное (BASE.x)
const MAX_WIDTH := 760.0

var _kb_was_open := false
var _last_kb := 0.0
var _last_geometry := ""
## Текущие поля безопасной зоны в пикселях вьюпорта: лево, верх, право, низ.
var insets := Vector4.ZERO
## Для самотестов: имитация выреза камеры и жестовой панели. -1 — брать с устройства.
var debug_insets := Vector4(-1, -1, -1, -1)
## Для самотестов: высота экранной клавиатуры в px вьюпорта. -1 — брать с устройства.
var debug_keyboard := -1.0


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

	if OS.has_feature("android") or OS.has_feature("ios"):
		inset = ResolutionManager.safe_insets(vp, win)

	if debug_insets.x >= 0.0:
		inset = debug_insets
	insets = inset

	var keyboard := 0.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		keyboard = float(DisplayServer.virtual_keyboard_get_height()) * k
		if absf(keyboard - _last_kb) > 1.0:
			_last_kb = keyboard
			Diag.step("клавиатура: %d px" % int(keyboard))
	if debug_keyboard >= 0.0:
		keyboard = debug_keyboard
	var side := maxf(0.0, (vp.x - MAX_WIDTH) * 0.5)

	var edge := side_margin(vp.x)
	var margins := Vector4(edge + maxf(inset.x, side), BASE.y + inset.y,
		edge + maxf(inset.z, side), BASE.w + maxf(inset.w, keyboard))
	ResolutionManager.apply_safe_area(self, margins)
	var geometry := "%s/%s/%s" % [vp, win, margins]
	if geometry != _last_geometry:
		_last_geometry = geometry
		Diag.step("экран %s, окно %s, поля %s" % [vp, win, margins])


## Боковое поле: на узком экране (450 ед.) 16, с 600 ед. и шире полные 32. Так три кнопки в ряд помещаются на iPhone SE и Pixel 3a.
static func side_margin(viewport_w: float) -> float:
	return lerpf(SIDE_MIN, BASE.x, clampf((viewport_w - SIDE_NARROW_VP) / (SIDE_WIDE_VP - SIDE_NARROW_VP), 0.0, 1.0))


static func cutout_insets(viewport: Vector2, window: Vector2, cutouts: Array[Rect2]) -> Vector4:
	var out := Vector4.ZERO
	if window.x <= 0.0 or window.y <= 0.0:
		return out
	var ratio := viewport / window
	for cut: Rect2 in cutouts:
		if cut.position.y <= 3.0 and cut.size.y < window.y * 0.16:
			out.y = maxf(out.y, maxf(0.0, cut.end.y) * ratio.y)
		if cut.end.y >= window.y - 3.0 and cut.size.y < window.y * 0.16:
			out.w = maxf(out.w, maxf(0.0, window.y - cut.position.y) * ratio.y)
		if cut.position.x <= 3.0 and cut.size.x < window.x * 0.16:
			out.x = maxf(out.x, maxf(0.0, cut.end.x) * ratio.x)
		if cut.end.x >= window.x - 3.0 and cut.size.x < window.x * 0.16:
			out.z = maxf(out.z, maxf(0.0, window.x - cut.position.x) * ratio.x)
	return out
