class_name TalismanReveal
extends PanelContainer
## TASK-074: оберег у двери. Проведи по карточке пальцем (или коснись), и она покажет состояние
## оберега своего дома: целый, треснувший, расколотый. Состояние берётся из правил Match в момент
## касания, поэтому совпадает с матчем. Подсказка и ответ внутри карточки: у двери до первого
## действия не больше двух строк текста вне карточек.

signal revealed(level: int)

const SWIPE_PX := 28.0              ## сдвиг, с которого касание становится протяжкой
const TAP_PX := 14.0                ## меньше этого: обычный тап

var level_of: Callable              ## -> int: состояние оберега дома хозяина по правилам матча
var level := -1                     ## что показано сейчас: -1 ещё не проверяли, 0 расколот, 1 треснул, 2 цел
var hint := ""
var _glyph: Glyph
var _text: Label
var _down := false
var _origin := Vector2.ZERO
var _done := false                  ## протяжка уже сработала, отпускание не считается тапом


func _init() -> void:
	theme_type_variation = &"Card"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, ThemeFactory.TOUCH)
	set_meta("action", true)


func _ready() -> void:
	var row := W.hbox(14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph = Glyph.make("talisman", 48.0, Color(ThemeFactory.BONE, 0.45))
	row.add_child(_glyph)
	_text = W.label(hint, &"Hint")
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_text)
	add_child(row)


static func kind_for(lvl: int) -> String:
	return "talisman" if lvl >= Match.TALISMAN_MAX else ("talisman_cracked" if lvl == Match.TALISMAN_MAX - 1 else "talisman_broken")


static func text_key(lvl: int) -> String:
	return "door.tal_ok" if lvl >= Match.TALISMAN_MAX else ("door.tal_cracked" if lvl == Match.TALISMAN_MAX - 1 else "door.tal_broken")


func reveal() -> void:
	if not level_of.is_valid():
		return
	level = clampi(int(level_of.call()), 0, Match.TALISMAN_MAX)
	var kind := kind_for(level)
	_glyph.col = Glyph.tint(kind)
	_glyph.set_kind(kind)
	_glyph.queue_redraw()
	_text.text = L.t(text_key(level))
	if level >= Match.TALISMAN_MAX:
		Juice.haptic(Juice.Haptic.TAP)
	elif level == Match.TALISMAN_MAX - 1:
		Juice.haptic(Juice.Haptic.REFUSE)          # трещина: резкий короткий удар
		Sfx.play(&"scratch", randf_range(0.9, 1.0), -6.0)
	else:
		Juice.haptic(Juice.Haptic.DEATH)
		Sfx.play(&"scratch", randf_range(0.7, 0.8), -4.0)
	revealed.emit(level)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var b := event as InputEventMouseButton
		if b.pressed:
			_down = true
			_done = false
			_origin = b.position
			accept_event()
		elif _down:
			_down = false
			if not _done and b.position.distance_to(_origin) <= TAP_PX:
				reveal()
			_done = false
			accept_event()
	elif event is InputEventMouseMotion and _down and not _done:
		if (event as InputEventMouseMotion).position.distance_to(_origin) >= SWIPE_PX:
			_done = true
			reveal()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		reveal()
		accept_event()
