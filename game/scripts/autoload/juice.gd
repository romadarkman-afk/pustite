extends Node
## Game feel: вибро, тряска, всплытие, нажатия и регулятор частоты кадров.
## Регулятор: 30 fps в покое (батарея, нагрев), 60 fps при касании и анимациях.

enum Haptic { TAP, KNOCK, REFUSE, DEATH, NIGHT, SUCCESS }

const FPS_IDLE := 30
const FPS_ACTIVE := 60
const HAPTIC_SPEC := {
	Haptic.TAP: Vector2(9, 0.25),
	Haptic.KNOCK: Vector2(38, 0.65),
	Haptic.REFUSE: Vector2(110, 0.9),
	Haptic.DEATH: Vector2(70, 0.8),
	Haptic.NIGHT: Vector2(160, 0.45),
	Haptic.SUCCESS: Vector2(24, 0.5),
}

var haptics_enabled: bool = true
var instant: bool = false            ## самотесты: без задержек и анимаций
var _boost_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = FPS_IDLE


func _process(delta: float) -> void:
	if _boost_left > 0.0:
		_boost_left -= delta
		if _boost_left <= 0.0:
			Engine.max_fps = FPS_IDLE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		boost(1.5)


func boost(seconds: float) -> void:
	_boost_left = maxf(_boost_left, seconds)
	Engine.max_fps = FPS_ACTIVE


func haptic(kind: Haptic) -> void:
	if not haptics_enabled or instant or not OS.has_feature("mobile"):
		return
	var spec: Vector2 = HAPTIC_SPEC[kind]
	Diag.step("вибро: %s" % Haptic.keys()[kind])
	Input.vibrate_handheld(int(spec.x), spec.y)


func wait(seconds: float) -> void:
	if instant:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout


func tween() -> Tween:
	boost(1.2)
	return create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Тряска. Работает только на узлах вне контейнеров (экраны внутри ScreenHost).
func shake(node: Control, strength: float = 12.0, duration: float = 0.32) -> void:
	if instant or not is_instance_valid(node):
		return
	var t := tween()
	var steps := 6
	for i in range(steps):
		var k := 1.0 - float(i) / steps
		t.tween_property(node, "position",
			Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * strength * k, duration / steps)
	t.tween_property(node, "position", Vector2.ZERO, duration / steps)


## Появление элемента: прозрачность + лёгкое масштабирование от левого края.
func pop_in(node: Control, delay: float = 0.0) -> void:
	if instant:
		return
	node.modulate.a = 0.0
	node.scale = Vector2(0.97, 0.97)
	node.resized.connect(func() -> void: node.pivot_offset = Vector2(0, node.size.y * 0.5), CONNECT_ONE_SHOT)
	var t := tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(node, "modulate:a", 1.0, 0.28)
	t.tween_property(node, "scale", Vector2.ONE, 0.32)


## Отклик кнопки на палец: сжатие + микровибро.
func press_feedback(b: BaseButton) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func() -> void:
		haptic(Haptic.TAP)
		if not instant:
			tween().tween_property(b, "scale", Vector2(0.965, 0.965), 0.07))
	b.button_up.connect(func() -> void:
		if not instant:
			tween().tween_property(b, "scale", Vector2.ONE, 0.12))
