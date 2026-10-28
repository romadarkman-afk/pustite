class_name CampaignMap
extends Control
## Карта реки кампании (TASK-087): четыре места на картинке assets/ui/campaign_map.png.
## У каждого места пин и подпись: название, сезон, сколько глав пройдено. Пройденное отмечено, закрытое тусклое.
## Нажатие на подпись сообщает акт: экран глав прокручивается к нему.

signal act_picked(act: int)

const MAP_PATH := "res://assets/ui/campaign_map.png"
const RATIO := 1.5                  ## высота к ширине картинки (1024×1536)
const PIN := 44.0
const EDGE := 6.0
## Где на картинке стоит место (доли ширины и высоты) и где центр подписи (те же доли).
const PLACES: Array[Dictionary] = [
	{"act": 1, "at": Vector2(0.37, 0.845), "label": Vector2(0.64, 0.90)},
	{"act": 2, "at": Vector2(0.49, 0.575), "label": Vector2(0.76, 0.50)},
	{"act": 3, "at": Vector2(0.28, 0.215), "label": Vector2(0.58, 0.31)},
	{"act": 4, "at": Vector2(0.80, 0.055), "label": Vector2(0.55, 0.14)},
]
const SEASON_COLORS := {"summer": Color("c8d98a"), "autumn": Color("f0b060"), "winter": Color("b5d3f0"), "spring": Color("a8dcb0")}
const LINE := Color(1.0, 0.78, 0.4, 0.6)

var _art: TextureRect
var _lines: Control
var _items: Array[Dictionary] = []


func _init() -> void:
	name = "CampaignMap"
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func build() -> void:
	for c: Node in get_children():
		c.queue_free()
	_items.clear()
	_art = TextureRect.new()
	_art.name = "MapArt"
	_art.texture = load(MAP_PATH) as Texture2D if ResourceLoader.exists(MAP_PATH) else null
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_lines = Control.new()
	_lines.name = "MapLines"
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	add_child(_lines)
	for p: Dictionary in PLACES:
		_items.append(_place(int(p.act), p))
	resized.connect(_layout)
	_layout.call_deferred()


func _place(act: int, p: Dictionary) -> Dictionary:
	var st := Campaign.act_state(act)
	var state := String(st.state)
	var season_col: Color = SEASON_COLORS.get(String(st.season), Color.WHITE)
	var kind := "lock" if state == "locked" else ("safe" if state == "done" else "door")
	var col := ThemeFactory.LAMP if state == "current" else (ThemeFactory.BONE if state != "locked" else Color(0.6, 0.6, 0.66))
	var pin := Glyph.make(kind, PIN, col)
	pin.name = "Pin_%d" % act
	add_child(pin)
	var tag := W.panel(&"Sheet")
	tag.name = "Place_%d" % act
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := W.vbox(2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := W.label(L.t("camp.place%d" % act), &"Speaker")
	head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var sub := W.label("%s  %d/%d" % [L.t("camp.season.%s" % String(st.season)), int(st.done), int(st.total)], &"Small")
	sub.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.add_theme_color_override("font_color", season_col)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sub)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(box)
	# невидимая кнопка поверх подписи: PanelContainer растягивает каждого ребёнка на всю подпись
	var hit := Button.new()
	hit.name = "Pick_%d" % act
	hit.flat = true
	hit.custom_minimum_size = Vector2(0, ThemeFactory.TOUCH)
	hit.focus_mode = Control.FOCUS_NONE
	for sb: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		hit.add_theme_stylebox_override(sb, StyleBoxEmpty.new())
	hit.pressed.connect(func() -> void:
		Sfx.play(&"tap", randf_range(0.95, 1.08), -4.0)
		act_picked.emit(act))
	tag.add_child(hit)
	if state == "locked":
		tag.modulate = Color(1, 1, 1, 0.78)
	add_child(tag)
	return {"act": act, "at": p.at, "label": p.label, "pin": pin, "tag": tag, "state": state}


func map_height() -> float:
	return size.x * RATIO


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var h := map_height()
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size.y = h


## Пины ставятся на места картинки, подписи рядом и целиком внутри карты.
func _layout() -> void:
	var w := size.x
	var h := map_height()
	if w <= 0.0:
		return
	for it: Dictionary in _items:
		var pin: Control = it.pin
		var tag: Control = it.tag
		var at: Vector2 = it.at
		var lab: Vector2 = it.label
		pin.size = Vector2(PIN, PIN)
		pin.position = Vector2(at.x * w, at.y * h) - pin.size * 0.5
		var tsz := tag.get_combined_minimum_size()
		tag.size = tsz
		var pos := Vector2(lab.x * w, lab.y * h) - tsz * 0.5
		pos.x = clampf(pos.x, EDGE, maxf(EDGE, w - tsz.x - EDGE))
		pos.y = clampf(pos.y, EDGE, maxf(EDGE, h - tsz.y - EDGE))
		tag.position = pos
	_lines.queue_redraw()


func _draw_lines() -> void:
	for it: Dictionary in _items:
		var pin: Control = it.pin
		var tag: Control = it.tag
		var a := pin.position + pin.size * 0.5
		var b := tag.position + tag.size * 0.5
		_lines.draw_line(a, b, LINE, 2.0, true)


func item(act: int) -> Dictionary:
	for it: Dictionary in _items:
		if int(it.act) == act:
			return it
	return {}
