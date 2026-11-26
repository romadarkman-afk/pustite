class_name InfoSheet
extends Control
## «Подробнее»: длинные пояснения, убранные с экранов ночи, двери и утра.
## Пока шторка открыта, часы фазы стоят: прочитать — не значит проиграть по времени.
## Строки — [значок, текст]; пустой значок — просто абзац.

var _done := false


static func open(parent: Control, lines: Array) -> InfoSheet:
	var s := InfoSheet.new()
	s.name = "InfoSheet"
	parent.add_child(s)
	s._build(lines)
	return s


func _build(lines: Array) -> void:
	Game.hold(&"info")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = -3000
	dim.offset_top = -3000
	dim.offset_right = 3000
	dim.offset_bottom = 3000
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			close())
	add_child(dim)
	var sheet := W.panel(&"Sheet")
	sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(sheet)
	var layout := W.vbox(14)
	sheet.add_child(layout)
	var scroll := TouchScroll.new()
	scroll.name = "InfoScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var box := W.vbox(13)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for l: Array in lines:
		var k: String = l[0]
		var t: String = l[1]
		if t == "":
			continue
		box.add_child(W.icon_line(k, t, &"Small") if k != "" else W.label(t, &"Small"))
	var fit := func() -> void:
		scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, maxf(100.0, size.y * 0.65))
	box.minimum_size_changed.connect(fit)
	resized.connect(fit)
	fit.call_deferred()
	var ok := W.button(L.t("ui.close"), &"Ghost")
	ok.pressed.connect(close)
	layout.add_child(ok)


func close() -> void:
	if _done:
		return
	_done = true
	Game.release(&"info")
	queue_free()


func _exit_tree() -> void:
	if not _done:
		_done = true
		Game.release(&"info")
