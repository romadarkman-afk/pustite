class_name TouchScroll
extends ScrollContainer
## Список, который тянется пальцем с любого места, в том числе с кнопок и карточек.
## Обычный ScrollContainer не видит касание, если его забрала кнопка. Здесь на каждый
## кликабельный элемент внутри повешено наблюдение: сдвиг больше порога превращает касание
## в протяжку, кнопка при этом не нажимается. Короткое касание без сдвига нажимает как раньше.
## Встроенная прокрутка касанием выключена (scroll_deadzone), колесо мыши работает как обычно.

const DRAG_START := 14.0           ## сдвиг в пикселях вьюпорта, с которого касание считается протяжкой
const FRICTION := 3.2              ## торможение после броска, 1/с
const MIN_FLING := 40.0            ## ниже этой скорости (px/с) бросок не начинается

var _tracking := false
var _dragging := false
var _origin := Vector2.ZERO
var _origin_scroll := 0.0
var _pos := 0.0                    ## прокрутка дробным числом, чтобы бросок шёл плавно
var _last_y := 0.0
var _last_msec := 0
var _fling := 0.0                  ## скорость прокрутки, px/с


func _ready() -> void:
	scroll_deadzone = 100000
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	_hook_subtree(self)
	set_process(false)


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Control and node != self and is_ancestor_of(node):
		_hook(node as Control)


func _hook_subtree(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			_hook(child as Control)
		_hook_subtree(child)


func _hook(c: Control) -> void:
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	var callback := _on_child_input.bind(c)
	for connection: Dictionary in c.gui_input.get_connections():
		if (connection["callable"] as Callable).get_object() == self:
			return
	c.gui_input.connect(callback)


## Касание пустого места внутри списка.
func _gui_input(event: InputEvent) -> void:
	_handle(event, self)


func _on_child_input(event: InputEvent, source: Control) -> void:
	if is_instance_valid(source):
		_handle(event, source)


func _handle(event: InputEvent, source: Control) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_begin(button.global_position)
		else:
			_finish(source)
	elif event is InputEventMouseMotion and _tracking:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_tracking = false
			_dragging = false
			return
		var shift := motion.global_position - _origin
		# поле посёлка тянется вбок (камера): горизонтальный протяг по нему список не прокручивает
		var field_pan := source.has_meta("pan_field") and absf(shift.x) >= absf(shift.y)
		if not _dragging and absf(shift.y) > DRAG_START and not field_pan:
			_dragging = true
			_cancel_press(source)
		if _dragging:
			_track_speed(motion.global_position.y)
			_pos = _origin_scroll - shift.y
			_apply_scroll()
			source.accept_event()


func _begin(at: Vector2) -> void:
	_tracking = true
	_dragging = false
	_fling = 0.0
	set_process(false)
	_origin = at
	_pos = float(scroll_vertical)
	_origin_scroll = _pos
	_last_y = at.y
	_last_msec = Time.get_ticks_msec()


func _finish(source: Control) -> void:
	if _dragging:
		source.accept_event()           # отпускание после протяжки не нажимает кнопку
		_cancel_press(source)
		if absf(_fling) >= MIN_FLING:
			set_process(true)
		else:
			_fling = 0.0
	_tracking = false
	_dragging = false


## Скорость прокрутки по последним движениям пальца, со сглаживанием.
func _track_speed(y: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := float(now - _last_msec) / 1000.0
	if dt > 0.004:
		var v := -(y - _last_y) / dt
		_fling = lerpf(_fling, v, 0.4)
		_last_y = y
		_last_msec = now


func _apply_scroll() -> void:
	var bar := get_v_scroll_bar()
	var limit := maxf(0.0, bar.max_value - bar.page)
	_pos = clampf(_pos, 0.0, limit)
	scroll_vertical = roundi(_pos)


func _process(delta: float) -> void:
	if _tracking or absf(_fling) < MIN_FLING * 0.5:
		_fling = 0.0
		set_process(false)
		return
	Juice.boost(0.2)
	var before := _pos
	_pos += _fling * delta
	_apply_scroll()
	if is_equal_approx(before, _pos):
		_fling = 0.0
	_fling *= exp(-FRICTION * delta)


## Кнопка, на которой началась протяжка, не должна остаться «нажатой».
## Выключение и включение сбрасывает её внутреннее нажатие без сигнала pressed.
func _cancel_press(source: Control) -> void:
	var node: Node = source
	while node != null and node != self:
		if node is BaseButton:
			var button := node as BaseButton
			if not button.disabled:
				button.disabled = true
				button.disabled = false
				button.button_up.emit()
			return
		node = node.get_parent()
