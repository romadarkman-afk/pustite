class_name ScenePlayer
extends Control
## Движок сцен (TASK-012). Сцена — данные (Scenes): кадры с картинкой и медленным наездом, свет и погода,
## реплики с паузами, звуковая карта кадра, выбор в конце. Кадр нельзя пролистнуть раньше чем через секунду.
## Картинки нет — кадр идёт поверх посёлка с затемнением, сцена не ломается.
## «Назад» доводит сцену до выбора (или до конца), сворачивание ставит её на паузу.
## Пока сцена идёт, часы партии стоят.
##
## Использование: var choice: String = await ScenePlayer.play(screen, scene, m)

signal finished(choice: String)

const MIN_FRAME := 1.0          ## раньше этого тап кадр не листает
const LINE_BASE := 1.6          ## сколько держится реплика: основа + по длине
const LINE_PER_CHAR := 0.035

var scene: Dictionary = {}
var m: Match
var frame_i := -1
var line_i := -1
var choice_id := ""
var _t := 0.0                    ## время в кадре
var _line_t := 0.0               ## сколько осталось держать реплику
var _sound_i := 0
var _paused := false
var _done := false
var _in_choice := false
var _art: TextureRect
var _portrait_box: CenterContainer
var _dim: ColorRect
var _fog: ColorRect
var _rain: Control
var _who: Label
var _text: Label
var _sub: PanelContainer
var _choices: VBoxContainer
var _hold_key: StringName
var _music_before: StringName
var _amb_before: StringName


static func play(parent: Control, sc: Dictionary, mm: Match = null) -> String:
	var p := ScenePlayer.new()
	p.scene = sc
	p.m = mm
	parent.add_child.call_deferred(p)
	await p.tree_entered
	await parent.get_tree().process_frame
	if not is_instance_valid(p):
		return ""
	p._build()
	var c: String = await p.finished
	return c


func _build() -> void:
	name = "Scene_" + String(scene.get("id", ""))
	_hold_key = StringName("scene_%d" % get_instance_id())
	Game.hold(_hold_key)
	_music_before = Sfx.music_name
	_amb_before = Sfx.ambience_name
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.04, 0.8)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover(_dim)
	add_child(_dim)
	_art = TextureRect.new()
	_art.name = "Art"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover(_art)
	add_child(_art)
	_portrait_box = CenterContainer.new()
	_portrait_box.name = "Portrait"
	_portrait_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_box.offset_bottom = -260
	_portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_box)
	_fog = ColorRect.new()
	_fog.color = Color(0.7, 0.74, 0.8, 0.0)
	_fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover(_fog)
	add_child(_fog)
	_rain = Control.new()
	_rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain.draw.connect(_draw_rain)
	add_child(_rain)
	var vignette := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.85))
	grad.set_offset(0, 0.45)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.05, 1.05)
	vignette.texture = gt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover(vignette)
	add_child(vignette)
	# субтитры: по одной реплике внизу, в зоне большого пальца
	_sub = W.panel(&"Sheet")
	_sub.name = "Subtitles"
	_sub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub)
	var box := W.vbox(8)
	_sub.add_child(box)
	_who = W.label("", &"Speaker")
	_who.name = "Who"
	box.add_child(_who)
	_text = W.label("", &"Tale")
	_text.name = "Line"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	_choices = W.vbox(10)
	_choices.name = "Choices"
	_choices.visible = false
	box.add_child(_choices)
	var hint := W.label(L.t("scene.tap"), &"Hint")
	hint.name = "TapHint"
	box.add_child(hint)
	gui_input.connect(_on_input)
	_next_frame()


func _cover(c: Control) -> void:
	c.offset_left = -3000 if c != _art else 0
	if c != _art:
		c.offset_top = -3000
		c.offset_right = 3000
		c.offset_bottom = 3000


func frames() -> Array:
	return scene.get("frames", [])


func current_frame() -> Dictionary:
	var fr := frames()
	return fr[frame_i] if frame_i >= 0 and frame_i < fr.size() else {}


func _next_frame() -> void:
	frame_i += 1
	if frame_i >= frames().size():
		_end_frames()
		return
	var f := current_frame()
	_t = 0.0
	_sound_i = 0
	line_i = -1
	# картинка: есть — на весь экран с медленным наездом; нет — посёлок под затемнением
	var tex: Texture2D = null
	var art_path := String(f.get("art", ""))
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		tex = load(art_path) as Texture2D
	_art.texture = tex
	_art.visible = tex != null
	_dim.color.a = 1.0 if tex != null else 0.92        # без картинки: экран под сценой едва виден
	var zoom: Array = f.get("zoom", [1.0, 1.08])
	_art.pivot_offset = get_viewport_rect().size * 0.5
	_art.scale = Vector2.ONE * float(zoom[0])
	_art.modulate = _light(String(f.get("light", "night")))
	var dur := _frame_len(f)
	if not Juice.instant and tex != null:
		var tw := create_tween()
		tw.tween_property(_art, "scale", Vector2.ONE * float(zoom[1]), dur)
	# портрет вместо картинки: житель крупно
	for c: Node in _portrait_box.get_children():
		c.queue_free()
	var who: Variant = f.get("portrait", null)
	if who is Villager:
		var pic := W.portrait(who as Villager, Vector2(150, 270), Color(0.62, 0.62, 0.7))
		_portrait_box.add_child(pic)
	elif who is String and ResourceLoader.exists(String(who)):
		# хозяин места (TASK-021): его фигура вместо портрета жителя
		var tr := TextureRect.new()
		tr.texture = load(String(who)) as Texture2D
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(150, 270)
		_portrait_box.add_child(tr)
	_fog.color.a = 0.22 if String(f.get("weather", "")) == "fog" else 0.0
	_rain.visible = String(f.get("weather", "")) == "rain"
	if not Juice.instant:
		modulate.a = 0.0 if frame_i == 0 else modulate.a
		create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	_next_line()


func _light(kind: String) -> Color:
	match kind:
		"dusk": return Color(0.95, 0.82, 0.78)
		"dawn": return Color(0.9, 0.9, 1.0)
		"day": return Color.WHITE
		"warm": return Color(1.0, 0.86, 0.66)
	return Color(0.62, 0.68, 0.88)        # ночь


func _frame_len(f: Dictionary) -> float:
	var n := 0.0
	for l: Dictionary in f.get("lines", []):
		n += _line_len(l)
	return maxf(MIN_FRAME + 0.5, n)


func _line_len(l: Dictionary) -> float:
	if l.has("hold"):
		return float(l.hold)
	return LINE_BASE + LINE_PER_CHAR * String(l.get("text", "")).length() + float(l.get("pause", 0.0))


func _next_line() -> void:
	var lines: Array = current_frame().get("lines", [])
	line_i += 1
	if line_i >= lines.size():
		_next_frame()
		return
	var l: Dictionary = lines[line_i]
	_who.text = String(l.get("who", ""))
	_who.visible = not _who.text.is_empty()
	_text.text = String(l.get("text", ""))
	_line_t = _line_len(l) if not Juice.instant else 0.05
	if not Juice.instant:
		_text.modulate.a = 0.0
		create_tween().tween_property(_text, "modulate:a", 1.0, 0.3)


func _end_frames() -> void:
	frame_i = frames().size()
	var ch: Dictionary = scene.get("choice", {})
	var opts: Array = ch.get("options", [])
	if opts.is_empty():
		_finish("")
		return
	_in_choice = true
	_who.visible = false
	_text.text = String(ch.get("prompt", ""))
	for c: Node in _choices.get_children():
		c.queue_free()
	for o: Dictionary in opts:
		var b := W.button(String(o.text), &"Row")
		b.name = "Choice_" + String(o.id)
		var oid := String(o.id)
		b.pressed.connect(func() -> void: choose(oid))
		_choices.add_child(b)
	_choices.visible = true
	_sub.mouse_filter = Control.MOUSE_FILTER_STOP
	(find_child("TapHint", true, false) as Control).visible = false


## Выбор игрока: пишется в журнал партии (TASK-012) и возвращается тому, кто показал сцену.
func choose(id: String) -> void:
	if _done or not _in_choice:
		return
	choice_id = id
	if m != null:
		m.world.add(WorldLog.Kind.CHOICE, m.day, 0, -1, -1, [0], false, {"scene": String(scene.get("id", "")), "choice": id})
	_finish(id)


func _finish(c: String) -> void:
	if _done:
		return
	_done = true
	Game.release(_hold_key)
	if bool(scene.get("restore_sound", true)):
		Sfx.set_ambience(_amb_before, 0.8)
		Sfx.set_music(_music_before, 0.8)
	finished.emit(c)
	if Juice.instant:
		queue_free()
	else:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)


## «Назад»: сцена сразу доходит до выбора, а если выбора нет — заканчивается.
func skip() -> void:
	if _done or _in_choice:
		return
	_end_frames()


## Тап: следующая реплика. Первую секунду кадра тапы не считаются: кадр должен успеть появиться.
func tap() -> bool:
	if _done or _in_choice or _paused:
		return false
	if _t < MIN_FRAME and not Juice.instant:
		return false
	_next_line()
	return true


func _on_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
		tap()


func _process(delta: float) -> void:
	if _done or _in_choice or _paused or frame_i < 0 or frame_i >= frames().size():
		return
	_t += delta
	_run_sound()
	_line_t -= delta
	if _line_t <= 0.0:
		_next_line()
	if _rain.visible:
		_rain.queue_redraw()


## Звуковая карта кадра: [{"at": секунда, "do": play | amb | music | silence, "id", "vol"}].
func _run_sound() -> void:
	var events: Array = current_frame().get("sound", [])
	while _sound_i < events.size() and _t >= float((events[_sound_i] as Dictionary).get("at", 0.0)):
		var ev: Dictionary = events[_sound_i]
		_sound_i += 1
		var id := StringName(ev.get("id", ""))
		match String(ev.get("do", "play")):
			"play":
				if Sfx.has_sound(id):
					Sfx.play(id, float(ev.get("pitch", 1.0)), float(ev.get("vol", -4.0)))
			"amb":
				Sfx.set_ambience(id, float(ev.get("fade", 1.2)))
			"music":
				Sfx.set_music(id, float(ev.get("fade", 1.2)))
			"silence":
				Sfx.set_ambience(&"", float(ev.get("fade", 0.8)))
				Sfx.set_music(&"", float(ev.get("fade", 0.8)))


func _draw_rain() -> void:
	var sz := _rain.size
	var k := Time.get_ticks_msec() / 1000.0
	for i in range(60):
		var x := fmod(float(i) * 97.3 + k * 40.0, sz.x)
		var y := fmod(float(i) * 53.1 + k * 900.0, sz.y + 40.0) - 40.0
		_rain.draw_line(Vector2(x, y), Vector2(x - 6, y + 28), Color(0.75, 0.8, 0.9, 0.25), 1.5)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_paused = true
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_paused = false


func _exit_tree() -> void:
	if not _done:
		_done = true
		Game.release(_hold_key)
		finished.emit(choice_id)
