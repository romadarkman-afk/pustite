class_name SlidePlayer
extends Control
## Плеер комиксов (TASK-101–104). Колода (Slides) — это кадры в стиле моушн-комикса: фото-кадр с цветом акта и зерном,
## медленное движение камеры, подпись на тёмной плашке, которая печатается, и звуковая карта кадра.
## Кадр без файла рисуется заглушкой (SlideStand). Тап дописывает подпись, второй тап листает дальше.
## «Назад» и кнопка «Пропустить» закрывают колоду, сворачивание ставит её на паузу.
## Пока колода идёт, часы партии стоят.
##
## Использование: var shown: bool = await SlidePlayer.play(screen, "a1c1_intro")

signal finished(completed: bool)

const MIN_PANEL := 0.9           ## раньше этого тап кадр не листает
const TYPE_CPS := 34.0           ## знаков подписи в секунду
const HOLD_BASE := 1.9           ## сколько кадр держится после того, как подпись допечаталась
const HOLD_PER_CHAR := 0.05
const SILENT_PANEL := 3.2        ## кадр без подписи
const CARD_SEC := 2.4            ## титульная плашка
const FADE := 0.32
const SHAKE_PX := 10.0
const BREATH := 0.004           ## дыхание кадра: масштаб колеблется на эту долю

## Цвет акта: холодные тени, тёплые света, сила разделения тонов, контраст. Ключ 0 — колоды без акта.
const GRADES := {
	0: {"cold": Color(0.12, 0.17, 0.29), "warm": Color(1.0, 0.74, 0.46), "tone": 0.30, "contrast": 1.16},
	1: {"cold": Color(0.10, 0.18, 0.32), "warm": Color(1.0, 0.76, 0.40), "tone": 0.30, "contrast": 1.14},
	2: {"cold": Color(0.14, 0.17, 0.20), "warm": Color(0.95, 0.58, 0.30), "tone": 0.36, "contrast": 1.18},
	3: {"cold": Color(0.08, 0.15, 0.34), "warm": Color(1.0, 0.62, 0.28), "tone": 0.40, "contrast": 1.20},
	4: {"cold": Color(0.12, 0.20, 0.18), "warm": Color(1.0, 0.82, 0.40), "tone": 0.34, "contrast": 1.16},
}
const GRADE_SHADER := preload("res://shaders/slide_grade.gdshader")
## Деталь по виду колоды: победа теплее и мягче, поворот холоднее и резче.
const KIND_TONE := {"ch_win": 0.06, "act_outro": 0.0, "ch_twist": -0.04, "finale": 0.0}

## Самотесты идут без комиксов: колоды листаются сами и держат часы партии. Тест, которому комиксы нужны, включает флаг.
static var instant_play := false

var deck_id := ""
var deck: Dictionary = {}
var panel_i := -1
var completed := false
var _t := 0.0                    ## время в кадре
var _dur := 3.0                  ## сколько длится кадр: допечатать, подержать
var _typed := 0.0
var _text_len := 0
var _hold := 0.0
var _sound_i := 0
var _paused := false
var _done := false
var _in_card := false
var _card_t := 0.0
var _hold_key: StringName
var _music_before: StringName
var _amb_before: StringName
var _view: Control
var _stage: Control
var _grade: ShaderMaterial
var _plate: PanelContainer
var _who: Label
var _line: Label
var _pips: Pips
var _card: Control
var _card_label: Label
var _skip: Button
var _draft: Label
var _view_size := Vector2(720, 1280)
var _cam_s0 := 1.04
var _cam_s1 := 1.04
var _cam_f0 := Vector2(0.5, 0.5)
var _cam_f1 := Vector2(0.5, 0.5)
var _cam_shake := false
var _flash_tw: Tween


## Показать колоду. Возвращает true, если колода была показана (дочитана или пропущена), false — если показывать нечего:
## такой колоды нет, комиксы выключены или игрок уже видел её и просил не повторять. force=true показывает всегда (Книга посёлка).
static func play(parent: Control, id: String, force: bool = false) -> bool:
	if not Slides.has_deck(id) or Slides.panels(id).is_empty():
		return false
	if not force and (not Save.comics_on or (Save.comics_skip_seen and Slides.seen(id)) or (Juice.instant and not instant_play)):
		return false
	var p := SlidePlayer.new()
	p.deck_id = id
	p.deck = Slides.deck(id)
	parent.add_child.call_deferred(p)
	await p.tree_entered
	await parent.get_tree().process_frame
	if not is_instance_valid(p):
		return false
	p._build()
	await p.finished
	return true


# ----------------------------------------------------------------- построение

func _build() -> void:
	name = "Slides_" + deck_id
	_hold_key = StringName("slides_%d" % get_instance_id())
	Game.hold(_hold_key)
	_music_before = Sfx.music_name
	_amb_before = Sfx.ambience_name
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_view = Control.new()
	_view.name = "View"
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(black)
	_view.add_child(_make_vignette())
	_fit_view()
	get_viewport().size_changed.connect(_on_resized)
	_setup_grade()
	# подпись: тёмная плашка внизу, в зоне большого пальца
	_plate = PanelContainer.new()
	_plate.name = "Plate"
	_plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_plate.offset_left = 8.0
	_plate.offset_right = -8.0
	_plate.offset_bottom = -10.0
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.78)
	sb.border_color = Color(0.96, 0.74, 0.40, 0.9)
	sb.border_width_left = 4
	sb.set_content_margin_all(14)
	sb.content_margin_left = 18
	_plate.add_theme_stylebox_override("panel", sb)
	add_child(_plate)
	var box := W.vbox(4)
	_plate.add_child(box)
	_who = W.label("", &"Speaker")
	_who.name = "Who"
	box.add_child(_who)
	_line = W.label("", &"Tale")
	_line.name = "Line"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING     # плашка не прыгает, пока печатается
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_line)
	# полоски кадров сверху и кнопка «Пропустить»
	_pips = Pips.new()
	_pips.name = "Pips"
	_pips.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_pips.offset_left = 12.0
	_pips.offset_right = -12.0
	_pips.offset_top = 8.0
	_pips.offset_bottom = 12.0
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.count = Slides.panels(deck_id).size()
	add_child(_pips)
	# верхний ряд: «черновик» слева (пока кадр на заглушке), «Пропустить» справа; размеры по тексту
	var top := HBoxContainer.new()
	top.name = "Top"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10.0
	top.offset_right = -10.0
	top.offset_top = 20.0
	top.alignment = BoxContainer.ALIGNMENT_END
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_draft = W.label(L.t("slides.draft"), &"Small")
	_draft.name = "Draft"
	_draft.autowrap_mode = TextServer.AUTOWRAP_OFF
	_draft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draft.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_draft.modulate = Color(1.0, 0.8, 0.4, 0.75)
	_draft.visible = false
	_draft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_draft)
	_skip = W.button(L.t("ui.skip"), &"Quick")
	_skip.name = "Skip"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING      # с обрезкой многоточием кнопка схлопывается в полоску
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	_skip.modulate.a = 0.85
	_skip.pressed.connect(skip)
	top.add_child(_skip)
	_build_card()
	gui_input.connect(_on_input)
	_begin()


func _make_vignette() -> TextureRect:
	var vignette := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.8))
	grad.set_offset(0, 0.5)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.05, 1.05)
	vignette.texture = gt
	vignette.name = "Vignette"
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vignette


func _build_card() -> void:
	_card = ColorRect.new()
	(_card as ColorRect).color = Color.BLACK
	_card.name = "Card"
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(center)
	_card_label = W.label("", &"Title")
	_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_label.custom_minimum_size = Vector2(maxf(240.0, size.x - 80.0), 0.0)
	_card_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_card_label)


## Видимая область занимает весь экран, даже если сам плеер стоит внутри полей безопасной зоны.
func _fit_view() -> void:
	_view_size = get_viewport_rect().size
	_view.size = _view_size
	_view.global_position = Vector2.ZERO


func _on_resized() -> void:
	if _done or _view == null:
		return
	_fit_view()
	if panel_i >= 0 and panel_i < _panels().size():
		_show_stage(panel_i, false)


func _setup_grade() -> void:
	if Save.simplified_graphics:
		_grade = null
		return
	_grade = ShaderMaterial.new()
	_grade.shader = GRADE_SHADER
	var g: Dictionary = GRADES.get(Slides.act_of(deck_id), GRADES[0])
	_grade.set_shader_parameter("cold", g.cold)
	_grade.set_shader_parameter("warm", g.warm)
	_grade.set_shader_parameter("tone", clampf(float(g.tone) + float(KIND_TONE.get(String(deck.get("kind", "")), 0.0)), 0.0, 1.0))
	_grade.set_shader_parameter("contrast", g.contrast)
	_grade.set_shader_parameter("memory", 0.0)
	_grade.set_shader_parameter("flash", 0.0)


# ----------------------------------------------------------------- ход колоды

func _panels() -> Array:
	return Slides.panels(deck_id)


func panel() -> Dictionary:
	var ps := _panels()
	return ps[panel_i] if panel_i >= 0 and panel_i < ps.size() else {}


func _begin() -> void:
	var card_text := Slides.card(deck_id)
	if not card_text.is_empty() and not Juice.instant:
		_in_card = true
		_card_t = 0.0
		_card_label.text = card_text
		_card.visible = true
		_card.modulate.a = 1.0
		_card_label.modulate.a = 0.0
		create_tween().tween_property(_card_label, "modulate:a", 1.0, 0.6)
		# звук первого кадра начинается под плашкой
		for ev: Variant in (_panels()[0] as Dictionary).get("sound", []):
			if ev is Dictionary and String((ev as Dictionary).get("do", "")) == "start" and float((ev as Dictionary).get("at", 0.0)) <= 0.01:
				run_sound_event(ev as Dictionary)
		return
	_next_panel()


func _end_card() -> void:
	_in_card = false
	if Juice.instant:
		_card.visible = false
	else:
		var tw := create_tween()
		tw.tween_property(_card, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func() -> void: _card.visible = false)
	_next_panel()


func _next_panel() -> void:
	panel_i += 1
	if panel_i >= _panels().size():
		_finish(true)
		return
	var p := panel()
	_t = 0.0
	_sound_i = 0
	_typed = 0.0
	_pips.at = panel_i
	_pips.queue_redraw()
	var lines: Array = p.get("lines", [])
	var parts := PackedStringArray()
	var who_id := ""
	for l: Variant in lines:
		if l is Dictionary:
			var tx := Slides.text(String((l as Dictionary).get("key", "")))
			if not tx.is_empty():
				parts.append(tx)
				if who_id.is_empty():
					who_id = String((l as Dictionary).get("who", ""))
	_line.text = "\n".join(parts)
	_text_len = _line.text.length()
	_who.text = Slides.who_name(who_id)
	_who.visible = not _who.text.is_empty()
	_plate.visible = _text_len > 0
	if Juice.instant:
		_line.visible_characters = -1
		_typed = float(_text_len)
		_hold = 0.05
		_dur = 0.1
	else:
		_line.visible_characters = 0
		_hold = HOLD_BASE + HOLD_PER_CHAR * float(_text_len) if _text_len > 0 else SILENT_PANEL
		_dur = maxf(2.4, float(_text_len) / TYPE_CPS + _hold + 0.2)
	_set_cam(String(p.get("cam", "hold")))
	_show_stage(panel_i, true)
	_run_sound()


## Заглушка или настоящая картинка кадра. fresh=true: плавно появляется поверх прежнего кадра.
func _show_stage(i: int, fresh: bool) -> void:
	var p := _panels()[i] as Dictionary
	var old := _stage
	var mat: Material = _grade
	var flash_to := int(deck.get("flash_to", 0))
	if _grade != null:
		_grade.set_shader_parameter("memory", 1.0 if i < flash_to else 0.0)
	var path := Slides.art_path(p)
	var stage: Control
	_draft.visible = path.is_empty() and OS.is_debug_build()
	if path.is_empty():
		stage = SlideStand.build(deck_id, i, p, _view_size, mat)
	else:
		var tex := load(path) as Texture2D
		stage = Control.new()
		stage.name = "Art"
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ts := tex.get_size() if tex != null else _view_size
		var k := maxf(_view_size.x / ts.x, _view_size.y / ts.y)
		stage.size = ts * k
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if mat != null:
			rect.material = mat
		stage.add_child(rect)
	stage.pivot_offset = Vector2.ZERO
	_view.add_child(stage)
	_view.move_child(stage, _view.get_child_count() - 2)        # под виньетку
	_stage = stage
	_apply_cam(clampf(_t / _dur, 0.0, 1.0))
	if old != null and is_instance_valid(old):
		if fresh and not Juice.instant:
			stage.modulate.a = 0.0
			var tw := create_tween().set_parallel(true)
			tw.tween_property(stage, "modulate:a", 1.0, FADE)
			tw.tween_property(old, "modulate:a", 0.0, FADE)
			tw.chain().tween_callback(old.queue_free)
		else:
			old.queue_free()
	elif fresh and not Juice.instant:
		stage.modulate.a = 0.0
		create_tween().tween_property(stage, "modulate:a", 1.0, FADE)
	if fresh and _cam_shake and _grade != null and not Juice.instant:
		if _flash_tw != null:
			_flash_tw.kill()
		_grade.set_shader_parameter("flash", 0.5)
		_flash_tw = create_tween()
		_flash_tw.tween_method(func(v: float) -> void: _grade.set_shader_parameter("flash", v), 0.5, 0.0, 0.4)


# ----------------------------------------------------------------- камера

## Движение камеры по имени из данных: масштаб от и до, точка обзора от и до (0..1 по краям картинки).
## Масштаб никогда не меньше 1.03, поэтому по краям не видно пустоты ни при дыхании, ни при тряске.
func _set_cam(cam: String) -> void:
	_cam_shake = false
	match cam:
		"zoom_in":
			_cam_s0 = 1.04
			_cam_s1 = 1.16
			_cam_f0 = Vector2(0.5, 0.5)
			_cam_f1 = Vector2(0.5, 0.40)
		"zoom_out":
			_cam_s0 = 1.16
			_cam_s1 = 1.04
			_cam_f0 = Vector2(0.5, 0.40)
			_cam_f1 = Vector2(0.5, 0.5)
		"pan_r":
			_cam_s0 = 1.06
			_cam_s1 = 1.06
			_cam_f0 = Vector2(0.0, 0.5)
			_cam_f1 = Vector2(1.0, 0.5)
		"pan_l":
			_cam_s0 = 1.06
			_cam_s1 = 1.06
			_cam_f0 = Vector2(1.0, 0.5)
			_cam_f1 = Vector2(0.0, 0.5)
		"pan_u":
			_cam_s0 = 1.08
			_cam_s1 = 1.08
			_cam_f0 = Vector2(0.5, 1.0)
			_cam_f1 = Vector2(0.5, 0.0)
		"pan_d":
			_cam_s0 = 1.08
			_cam_s1 = 1.08
			_cam_f0 = Vector2(0.5, 0.0)
			_cam_f1 = Vector2(0.5, 1.0)
		"shake":
			_cam_s0 = 1.1
			_cam_s1 = 1.06
			_cam_f0 = Vector2(0.5, 0.5)
			_cam_f1 = Vector2(0.5, 0.5)
			_cam_shake = true
		_:
			_cam_s0 = 1.04
			_cam_s1 = 1.04
			_cam_f0 = Vector2(0.5, 0.5)
			_cam_f1 = Vector2(0.5, 0.5)


## Прямоугольник сцены в экране при прогрессе кадра p (0..1), без дыхания и тряски. Для самотеста: должен накрывать экран.
func stage_rect_at(p: float) -> Rect2:
	if _stage == null:
		return Rect2()
	var e := p * p * (3.0 - 2.0 * p)
	var s := lerpf(_cam_s0, _cam_s1, e)
	var f := _cam_f0.lerp(_cam_f1, e)
	var sz := _stage.size * s
	return Rect2(-(sz - _view_size) * f, sz)


func _apply_cam(p: float) -> void:
	if _stage == null:
		return
	var e := p * p * (3.0 - 2.0 * p)
	var s := lerpf(_cam_s0, _cam_s1, e)
	if not Juice.instant:
		s *= 1.0 + BREATH * sin(_t * 1.4)
	var f := _cam_f0.lerp(_cam_f1, e)
	var sz := _stage.size * s
	var pos := -(sz - _view_size) * f
	if _cam_shake and not Juice.instant:
		var k := (1.0 - e) * (1.0 - e)
		pos += Vector2(sin(_t * 61.0), cos(_t * 53.0)) * SHAKE_PX * k
	_stage.scale = Vector2(s, s)
	_stage.position = pos


# ----------------------------------------------------------------- ввод и время

## Тап: подпись допечатывается сразу; если уже допечатана, кадр листается.
func tap() -> bool:
	if _done or _paused:
		return false
	if _in_card:
		if _card_t >= 0.6 or Juice.instant:
			_end_card()
			return true
		return false
	if _t < MIN_PANEL and not Juice.instant:
		return false
	if _typed < float(_text_len):
		finish_typing()
		return true
	_next_panel()
	return true


## Допечатать подпись кадра сразу.
func finish_typing() -> void:
	_typed = float(_text_len)
	_line.visible_characters = -1
	_hold = minf(_hold, 1.4)


## Следующий кадр без ожидания. Открыто для самотеста.
func advance() -> void:
	if _done:
		return
	if _in_card:
		_end_card()
		return
	_next_panel()


func _on_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
		tap()


func _input(e: InputEvent) -> void:
	if _done or not (e is InputEventKey):
		return
	var k := e as InputEventKey
	if k.pressed and not k.echo and (k.keycode == KEY_SPACE or k.keycode == KEY_ENTER):
		tap()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _done or _paused:
		return
	if _in_card:
		_card_t += delta
		if _card_t >= CARD_SEC:
			_end_card()
		return
	if panel_i < 0 or panel_i >= _panels().size():
		return
	_t += delta
	_apply_cam(clampf(_t / _dur, 0.0, 1.0))
	_run_sound()
	if _typed < float(_text_len):
		_typed = minf(float(_text_len), _typed + delta * TYPE_CPS)
		_line.visible_characters = int(_typed) if _typed < float(_text_len) else -1
		return
	_hold -= delta
	if _hold <= 0.0:
		_next_panel()


## «Назад» и кнопка: колода закрывается, как будто её досмотрели.
func skip() -> void:
	if _done:
		return
	_finish(false)


func _finish(done_all: bool) -> void:
	if _done:
		return
	_done = true
	completed = done_all
	Game.release(_hold_key)
	Slides.mark_seen(deck_id)
	if _flash_tw != null:
		_flash_tw.kill()
	Sfx.set_ambience(_amb_before, 0.8)
	Sfx.set_music(_music_before, 0.8)
	finished.emit(done_all)
	if Juice.instant:
		queue_free()
	else:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)


# ----------------------------------------------------------------- звук

func _run_sound() -> void:
	var events: Array = panel().get("sound", [])
	while _sound_i < events.size() and _t >= float((events[_sound_i] as Dictionary).get("at", 0.0)):
		var ev: Dictionary = events[_sound_i]
		_sound_i += 1
		run_sound_event(ev)


## Одно событие звуковой карты: start и stop на слоях amb и music, play, silence, keep.
## Музыки и фона, которых ещё нет в игре, заменяют ближайшие (Slides.MUSIC_FALLBACK); разового звука нет — тишина.
func run_sound_event(ev: Dictionary) -> void:
	var id := StringName(ev.get("id", ""))
	var op := String(ev.get("do", "play"))
	var layer := String(ev.get("layer", ""))
	var fade := float(ev.get("fade", 1.2))
	match op:
		"play":
			if Sfx.has_sound(id):
				Sfx.play(id, float(ev.get("pitch", 1.0)), float(ev.get("vol", -4.0)))
		"start":
			if layer == "music":
				var mid := Slides.music_for(id)
				if mid != &"":
					Sfx.set_music(mid, fade)
			else:
				var aid := Slides.amb_for(id)
				if aid != &"":
					Sfx.set_ambience(aid, fade)
		"stop":
			if layer == "music":
				Sfx.set_music(&"", fade)
			else:
				Sfx.set_ambience(&"", fade)
		"silence":
			var f := float(ev.get("fade", 0.8))
			Sfx.set_ambience(&"", f)
			Sfx.set_music(&"", f)
		"keep":
			pass


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
		finished.emit(false)


## Полоски кадров колоды сверху: пройденные яркие, текущая золотая, будущие тусклые.
class Pips extends Control:
	var count := 0
	var at := 0

	func _draw() -> void:
		if count <= 0:
			return
		var gap := 5.0
		var w := (size.x - gap * float(count - 1)) / float(count)
		for i in range(count):
			var c := Color(1, 1, 1, 0.28)
			if i < at:
				c = Color(1, 1, 1, 0.8)
			elif i == at:
				c = Color(0.96, 0.74, 0.40, 1.0)
			draw_rect(Rect2(float(i) * (w + gap), 0.0, maxf(w, 1.0), 4.0), c)
