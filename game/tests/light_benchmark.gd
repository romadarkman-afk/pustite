extends Control
## Ручной A/B стенд для GL Compatibility: стандартный WorldEnvironment glow и LightHalo.

const VIEW_SIZE := Vector2i(420, 600)

var _panels: Array[Dictionary] = []
var _active := -1
var _elapsed := 0.0
var _fps_sum := 0.0
var _fps_samples := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_top", 10)
	root.add_theme_constant_override("margin_bottom", 10)
	add_child(root)
	var title := Label.new()
	title.text = "Сравнение света · GL Compatibility"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	_add_panel(row, "WorldEnvironment glow", true)
	_add_panel(row, "Аддитивные LightHalo", false)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)
	var bloom_button := Button.new()
	bloom_button.text = "Замерить bloom"
	bloom_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloom_button.pressed.connect(func() -> void: _set_active(0))
	controls.add_child(bloom_button)
	var halo_button := Button.new()
	halo_button.text = "Замерить LightHalo"
	halo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	halo_button.pressed.connect(func() -> void: _set_active(1))
	controls.add_child(halo_button)
	var both_button := Button.new()
	both_button.text = "Оба"
	both_button.pressed.connect(func() -> void: _set_active(-1))
	controls.add_child(both_button)
	_set_active(-1)


func _add_panel(parent: HBoxContainer, title: String, bloom: bool) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var container := SubViewportContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.stretch = true
	column.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	container.add_child(viewport)
	if bloom:
		var world := WorldEnvironment.new()
		var environment := Environment.new()
		environment.background_mode = Environment.BG_CANVAS
		environment.background_canvas_max_layer = 0
		environment.glow_enabled = true
		environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		environment.glow_hdr_threshold = 0.24
		environment.glow_intensity = 0.75
		environment.glow_bloom = 0.05
		world.environment = environment
		viewport.add_child(world)
	var world_view := BenchmarkVillage.new()
	world_view.bloom = bloom
	viewport.add_child(world_view)
	var meter := Label.new()
	meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter.text = "ожидание замера"
	column.add_child(meter)
	_panels.append({"viewport": viewport, "meter": meter, "bloom": bloom})


func _set_active(index: int) -> void:
	_active = index
	_elapsed = 0.0
	_fps_sum = 0.0
	_fps_samples = 0
	for i in range(_panels.size()):
		var panel: Dictionary = _panels[i]
		var viewport := panel.viewport as SubViewport
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if index < 0 or index == i else SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	if _active < 0:
		return
	_elapsed += delta
	_fps_sum += Engine.get_frames_per_second()
	_fps_samples += 1
	if _elapsed >= 1.0:
		var average_fps := _fps_sum / maxf(1.0, float(_fps_samples))
		var panel: Dictionary = _panels[_active]
		(panel.meter as Label).text = "Среднее за %.1f с: %.1f FPS · %.2f мс/frame" % [_elapsed, average_fps, 1000.0 / maxf(1.0, average_fps)]


class BenchmarkVillage extends Node2D:
	const SIZE := Vector2i(420, 600)
	var bloom := false

	func _ready() -> void:
		if not bloom:
			for p: Vector2 in [Vector2(102, 400), Vector2(317, 358)]:
				var halo := LightHalo.new()
				halo.position = p
				halo.radius = 70.0
				halo.flicker = 0.0
				add_child(halo)
				halo.set_intensity(0.8)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), Color("111626"))
		for i in range(18):
			var y := 68.0 + i * 8.0
			var blend := float(i) / 18.0
			draw_rect(Rect2(0, y, SIZE.x, 8), Color("1c263a").lerp(Color("111824"), blend))
		for i in range(13):
			var x := float(i) * 38.0 - 8.0
			var base := 264.0 + float((i * 29) % 31)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 27, base), Vector2(x, base - 96 - float((i * 13) % 42)), Vector2(x + 30, base)]), Color("101923"))
		draw_rect(Rect2(0, 287, SIZE.x, 313), Color("252a2b"))
		draw_rect(Rect2(0, 312, SIZE.x, 4), Color("41403a"))
		_draw_house(Vector2(26, 305), 138.0, 150.0)
		_draw_house(Vector2(254, 278), 137.0, 170.0)
		for p: Vector2 in [Vector2(102, 400), Vector2(317, 358)]:
			draw_line(p + Vector2(0, 10), p + Vector2(0, 105), Color("35333a"), 5.0)
			draw_circle(p, 9.0, Color("f6b653"))
			draw_circle(p, 3.4, Color("fff0bd"))
		for i in range(28):
			var x := float((i * 83) % SIZE.x)
			var y := 425.0 + float((i * 47) % 155)
			draw_flat_ellipse(Vector2(x, y), Vector2(11, 4), Color("373737"))

	func _draw_house(pos: Vector2, width: float, height: float) -> void:
		var body_y := pos.y + height * 0.3
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, height * 0.32), pos + Vector2(width * 0.5, 0), pos + Vector2(width, height * 0.32)]), Color("17191e"))
		draw_rect(Rect2(pos.x + 11, body_y, width - 22, height * 0.68), Color("38302b"))
		draw_rect(Rect2(pos.x + 22, body_y + 21, 20, 30), Color("e8a34b"))
		draw_rect(Rect2(pos.x + width - 42, body_y + 21, 20, 30), Color("e8a34b"))
		draw_rect(Rect2(pos.x + width * 0.43, body_y + height * 0.34, 20, height * 0.34), Color("241f20"))

	func draw_flat_ellipse(center: Vector2, radius: Vector2, tint: Color) -> void:
		var points := PackedVector2Array()
		for i in range(16):
			var a := TAU * float(i) / 16.0
			points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
		draw_colored_polygon(points, tint)
