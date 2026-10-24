extends Node
## Подбирает масштаб по физическому экрану, плотности и выбранному профилю.

signal display_changed(profile: Dictionary, scale_factor: float, render_scale_3d: float)

const DEVICE_DB = preload("res://scripts/autoload/device_display_db.gd")
const BASE_SIZE := Vector2i(720, 1280)
const BASE_DPI := 160.0
const TARGET_DP_PER_UNIT := 0.78
const MIN_UI_SCALE := 0.78
const MAX_UI_SCALE := 1.60

var model_profiles: Dictionary = {}
var active_profile: Dictionary = {}
var simulated := false
var simulated_profile: Dictionary = {}
var _last_scale := -1.0
var _last_3d_scale := -1.0
var _original_window_size := Vector2i.ZERO
var _original_window_position := Vector2i.ZERO
var _original_window_mode := Window.MODE_WINDOWED
var _original_screen := 0
var _saved_window_state := false


func _ready() -> void:
	model_profiles = DEVICE_DB.model_map()
	var root := get_tree().root
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if not root.size_changed.is_connected(_on_size_changed):
		root.size_changed.connect(_on_size_changed)
	# масштаб применяется сразу, до сборки первого экрана: экран, построенный при масштабе 1.0,
	# а затем сжатый до 1.2, остался бы с устаревшими минимальными размерами
	_refresh()
	call_deferred("_refresh")
	if OS.is_debug_build() and not _is_mobile() and DisplayServer.get_name() != "headless":
		var simulator := preload("res://scripts/ui/resolution_simulator.gd").new()
		simulator.name = "ResolutionSimulator"
		simulator.manager = self
		add_child(simulator)


func _on_size_changed() -> void:
	_refresh()


func _refresh() -> void:
	var window := get_tree().root
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var screen_size := DisplayServer.screen_get_size()
	var dpi := DisplayServer.screen_get_dpi()
	var profile: Dictionary = {}
	if simulated:
		profile = simulated_profile.duplicate()
		screen_size = Vector2i(int(profile.width), int(profile.height))
		dpi = int(profile.ppi)
	else:
		if screen_size.x <= 0 or screen_size.y <= 0:
			screen_size = window.size
		if _is_mobile():
			profile = DEVICE_DB.profile_for_resolution(screen_size, dpi)
			if int(profile.get("resolution_match_count", 0)) == 1:
				dpi = int(profile.ppi)
	if dpi <= 0:
		dpi = 160
	if profile.is_empty():
		profile = _runtime_profile(screen_size, dpi)
	var factor := scale_for(screen_size, dpi)
	if not _is_mobile() and not simulated:
		factor = 1.0
	var render_scale := render_scale_for(screen_size)
	active_profile = profile
	if absf(factor - _last_scale) > 0.001:
		window.content_scale_factor = factor
		_last_scale = factor
	if absf(render_scale - _last_3d_scale) > 0.001:
		get_viewport().scaling_3d_scale = render_scale
		_last_3d_scale = render_scale
	display_changed.emit(active_profile.duplicate(), factor, render_scale)


func _runtime_profile(size: Vector2i, dpi: int) -> Dictionary:
	var category: StringName = DEVICE_DB.PHONE_STANDARD
	if size.x >= 1400 and size.y >= 1900:
		category = DEVICE_DB.TABLET_STANDARD
	elif size.x <= 800:
		category = DEVICE_DB.PHONE_COMPACT
	return {
		"model": "Detected device",
		"models": PackedStringArray(),
		"width": size.x,
		"height": size.y,
		"ppi": dpi,
		"category": category,
	}


func _is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


static func scale_for(screen_size: Vector2i, dpi: int, base_size: Vector2i = BASE_SIZE) -> float:
	if screen_size.x <= 0 or screen_size.y <= 0 or base_size.x <= 0 or base_size.y <= 0:
		return 1.0
	var oriented_base := base_size
	if (screen_size.x > screen_size.y) != (base_size.x > base_size.y):
		oriented_base = Vector2i(base_size.y, base_size.x)
	var fit_scale := minf(float(screen_size.x) / float(oriented_base.x), float(screen_size.y) / float(oriented_base.y))
	var density := maxf(float(dpi), 120.0) / BASE_DPI
	var dp_per_design_unit := fit_scale / density
	return clampf(TARGET_DP_PER_UNIT / maxf(dp_per_design_unit, 0.01), MIN_UI_SCALE, MAX_UI_SCALE)


static func render_scale_for(screen_size: Vector2i) -> float:
	var pixels := screen_size.x * screen_size.y
	if pixels >= 6_500_000:
		return 0.75
	if screen_size.x >= 1400 or screen_size.y >= 2700 or pixels >= 4_500_000:
		return 0.85
	return 1.0


func safe_insets(viewport_size: Vector2, window_size: Vector2) -> Vector4:
	if simulated:
		return Vector4.ZERO
	var platform: StringName = &"android" if OS.has_feature("android") else (&"ios" if OS.has_feature("ios") else &"")
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := DisplayServer.get_display_safe_area()
	var cutouts: Array[Rect2] = DisplayServer.get_display_cutouts()
	return safe_insets_for(platform, viewport_size, window_size, screen, Rect2(safe), cutouts)


static func safe_insets_for(platform: StringName, viewport_size: Vector2, window_size: Vector2,
		screen_size: Vector2, safe_rect: Rect2, cutouts: Array[Rect2] = []) -> Vector4:
	var out := Vector4.ZERO
	if safe_rect.size.x > 0.0 and safe_rect.size.y > 0.0 and screen_size.x > 0.0 and screen_size.y > 0.0:
		var ratio := viewport_size / screen_size
		out = Vector4(
			safe_rect.position.x * ratio.x,
			safe_rect.position.y * ratio.y,
			(screen_size.x - safe_rect.end.x) * ratio.x,
			(screen_size.y - safe_rect.end.y) * ratio.y
		)
	if platform == &"android":
		var cutout_insets := _cutout_insets(viewport_size, window_size, cutouts)
		out.x = maxf(out.x, cutout_insets.x)
		out.y = maxf(out.y, cutout_insets.y)
		out.z = maxf(out.z, cutout_insets.z)
		out.w = maxf(out.w, cutout_insets.w)
		return out
	if platform == &"ios":
		return out
	return Vector4.ZERO


static func _cutout_insets(viewport_size: Vector2, window_size: Vector2, cutouts: Array[Rect2]) -> Vector4:
	var out := Vector4.ZERO
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return out
	var ratio := viewport_size / window_size
	for cut: Rect2 in cutouts:
		if cut.position.y <= 3.0 and cut.size.y < window_size.y * 0.16:
			out.y = maxf(out.y, maxf(0.0, cut.end.y) * ratio.y)
		if cut.end.y >= window_size.y - 3.0 and cut.size.y < window_size.y * 0.16:
			out.w = maxf(out.w, maxf(0.0, window_size.y - cut.position.y) * ratio.y)
		if cut.position.x <= 3.0 and cut.size.x < window_size.x * 0.16:
			out.x = maxf(out.x, maxf(0.0, cut.end.x) * ratio.x)
		if cut.end.x >= window_size.x - 3.0 and cut.size.x < window_size.x * 0.16:
			out.z = maxf(out.z, maxf(0.0, window_size.x - cut.position.x) * ratio.x)
	return out


func apply_safe_area(container: MarginContainer, margins: Vector4) -> void:
	if not is_instance_valid(container):
		return
	var names := ["margin_left", "margin_top", "margin_right", "margin_bottom"]
	for i in range(names.size()):
		var value := roundi(margins[i])
		if not container.has_theme_constant_override(names[i]) or container.get_theme_constant(names[i]) != value:
			container.add_theme_constant_override(names[i], value)


func simulate_device(model: String) -> bool:
	var profile: Dictionary = DEVICE_DB.profile_for_model(model)
	if profile.is_empty():
		return false
	var window := get_tree().root
	if not _saved_window_state:
		_original_window_size = window.size
		_original_window_position = window.position
		_original_window_mode = window.mode
		_original_screen = window.current_screen
		_saved_window_state = true
	window.mode = Window.MODE_WINDOWED
	var available := DisplayServer.get_display_safe_area()
	var screen_size := available.size if available.size.x > 0 and available.size.y > 0 else DisplayServer.screen_get_size()
	window.size = preview_window_size(Vector2i(int(profile.width), int(profile.height)), screen_size)
	window.current_screen = _original_screen
	var usable := DisplayServer.screen_get_usable_rect(_original_screen)
	window.position = usable.position + (usable.size - window.size) / 2
	simulated_profile = profile
	simulated = true
	_refresh()
	return true


func clear_simulation() -> void:
	if not _saved_window_state:
		simulated = false
		simulated_profile.clear()
		_refresh()
		return
	var window := get_tree().root
	simulated = false
	simulated_profile.clear()
	window.mode = Window.MODE_WINDOWED
	window.current_screen = _original_screen
	window.size = _original_window_size
	window.position = _original_window_position
	if _original_window_mode != Window.MODE_WINDOWED:
		window.mode = _original_window_mode
	_saved_window_state = false
	_refresh()


static func preview_window_size(device_size: Vector2i, available_size: Vector2i) -> Vector2i:
	if device_size.x <= 0 or device_size.y <= 0:
		return Vector2i(480, 800)
	var cap := Vector2(
		maxf(320.0, minf(760.0, float(available_size.x) * 0.76)),
		maxf(480.0, minf(960.0, float(available_size.y) * 0.84))
	)
	var fit := minf(cap.x / float(device_size.x), cap.y / float(device_size.y))
	return Vector2i(maxi(1, roundi(device_size.x * fit)), maxi(1, roundi(device_size.y * fit)))
