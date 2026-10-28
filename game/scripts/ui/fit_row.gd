class_name FitRow
extends Container
## Ряд кнопок, который сам выбирает раскладку по текущей ширине: строка, если все влезают;
## два столбца, если влезают две самые широкие; иначе столбик. Пересчитывается при каждом
## изменении ширины (смена масштаба интерфейса, поворот, складной экран), а не один раз при сборке.
## Минимальная ширина равна самой широкой кнопке, поэтому ряд никогда не распирает экран.

enum Mode { ROW, GRID, COLUMN }

var sep := 8
var _mode := Mode.ROW
var _min_mode := Mode.ROW


## До первой раскладки ширины ещё нет: берём ширину области экранов, как и при сборке.
func _width_hint() -> float:
	if size.x > 0.0:
		return size.x
	return Nav.host.size.x if Nav.host != null and Nav.host.size.x > 100.0 else 672.0


func _items() -> Array[Control]:
	var out: Array[Control] = []
	for c: Node in get_children():
		if c is Control and (c as Control).visible:
			out.append(c)
	return out


func _mode_for(width: float, items: Array[Control]) -> int:
	if items.size() <= 1:
		return Mode.ROW
	var total := float(sep) * (items.size() - 1)
	var widest := 0.0
	for c in items:
		var w := c.get_combined_minimum_size().x
		total += w
		widest = maxf(widest, w)
	if width <= 0.0 or total <= width:
		return Mode.ROW
	if widest * 2.0 + sep <= width:
		return Mode.GRID
	return Mode.COLUMN


func _get_minimum_size() -> Vector2:
	var items := _items()
	var widest := 0.0
	for c in items:
		widest = maxf(widest, c.get_combined_minimum_size().x)
	_min_mode = _mode_for(_width_hint(), items) as Mode
	return Vector2(widest, _stack_height(items, _min_mode))


func _stack_height(items: Array[Control], mode: int) -> float:
	if items.is_empty():
		return 0.0
	match mode:
		Mode.ROW:
			var h := 0.0
			for c in items:
				h = maxf(h, c.get_combined_minimum_size().y)
			return h
		Mode.GRID:
			var total := 0.0
			var rows := 0
			for i in range(0, items.size(), 2):
				var h := items[i].get_combined_minimum_size().y
				if i + 1 < items.size():
					h = maxf(h, items[i + 1].get_combined_minimum_size().y)
				total += h
				rows += 1
			return total + sep * (rows - 1)
		_:
			var total := 0.0
			for c in items:
				total += c.get_combined_minimum_size().y
			return total + sep * (items.size() - 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_arrange()


func _arrange() -> void:
	var items := _items()
	if items.is_empty():
		return
	var width := size.x
	_mode = _mode_for(width, items) as Mode
	match _mode:
		Mode.ROW:
			_arrange_row(items, width)
		Mode.GRID:
			_arrange_grid(items, width)
		_:
			_arrange_column(items, width)
	if _mode != _min_mode:
		update_minimum_size()


func _arrange_row(items: Array[Control], width: float) -> void:
	var h := _stack_height(items, Mode.ROW)
	var used := float(sep) * (items.size() - 1)
	var growers := 0
	for c in items:
		used += c.get_combined_minimum_size().x
		if c.size_flags_horizontal & Control.SIZE_EXPAND:
			growers += 1
	var extra := maxf(0.0, width - used)
	var x := 0.0
	for c in items:
		var w := c.get_combined_minimum_size().x
		if growers > 0 and (c.size_flags_horizontal & Control.SIZE_EXPAND):
			w += extra / growers
		fit_child_in_rect(c, Rect2(x, 0.0, w, h))
		x += w + sep


func _arrange_grid(items: Array[Control], width: float) -> void:
	var cell := (width - sep) * 0.5
	var y := 0.0
	for i in range(0, items.size(), 2):
		var h := items[i].get_combined_minimum_size().y
		if i + 1 < items.size():
			h = maxf(h, items[i + 1].get_combined_minimum_size().y)
		_place(items[i], Rect2(0.0, y, cell, h))
		if i + 1 < items.size():
			_place(items[i + 1], Rect2(cell + sep, y, cell, h))
		y += h + sep


func _arrange_column(items: Array[Control], width: float) -> void:
	var y := 0.0
	for c in items:
		var h := c.get_combined_minimum_size().y
		_place(c, Rect2(0.0, y, width, h))
		y += h + sep


## В сетке и столбике кнопка занимает всю ячейку, даже если в строке она была узкой.
func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size
