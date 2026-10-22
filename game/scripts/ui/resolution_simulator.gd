extends CanvasLayer
## ПК-симулятор: F8 показывает панель, список меняет размер окна и профиль масштаба.

var manager: Node
var _picker: OptionButton
var _info: Label
var _panel: PanelContainer


func _ready() -> void:
	layer = 90
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 16)
	_panel.custom_minimum_size = Vector2(320, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "Симулятор экрана · F8"
	column.add_child(title)
	_picker = OptionButton.new()
	_picker.custom_minimum_size.y = 48
	_picker.add_item("Текущий экран")
	_picker.set_item_metadata(0, "")
	var profiles: Dictionary = manager.get("model_profiles")
	var names: Array = profiles.keys()
	names.sort()
	for model_variant: Variant in names:
		var model := String(model_variant)
		var profile: Dictionary = profiles[model]
		_picker.add_item("%s · %d×%d · %d PPI" % [model, profile.width, profile.height, profile.ppi])
		_picker.set_item_metadata(_picker.item_count - 1, model)
	_picker.item_selected.connect(_on_profile_selected)
	column.add_child(_picker)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_info)
	var hide := Button.new()
	hide.text = "Скрыть · F8"
	hide.custom_minimum_size.y = 44
	hide.pressed.connect(func() -> void: _panel.visible = false)
	column.add_child(hide)
	_panel.visible = false
	if manager.has_signal("display_changed"):
		manager.connect("display_changed", _on_display_changed)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func _on_profile_selected(index: int) -> void:
	var model := String(_picker.get_item_metadata(index))
	if model.is_empty():
		manager.call("clear_simulation")
	else:
		manager.call("simulate_device", model)


func _on_display_changed(profile: Dictionary, factor: float, scale_3d: float) -> void:
	if _info == null:
		return
	var model := String(profile.get("model", "Detected device"))
	_info.text = "%s\n%d×%d · %d PPI · %s\nUI ×%.2f · 3D ×%.2f" % [
		model, int(profile.get("width", 0)), int(profile.get("height", 0)),
		int(profile.get("ppi", 0)), String(profile.get("category", "")), factor, scale_3d,
	]
