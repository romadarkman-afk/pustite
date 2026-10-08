class_name Crowd
extends Node2D
## Жители на поле. Днём стоят кольцом вокруг колодца (вы — ближе всех к зрителю),
## ночью бегут к убежищам, о которых говорили. Погибшие остаются надгробиями там,
## где их застала ночь. Изгнанные уходят в туман.

const ARC := 2.3          ## полудуга кольца, рад: задний сектор за колодцем пустой

var view: VillageView
var book: LookBook
var figures: Dictionary[int, VillagerFigure] = {}
var ring: Dictionary[int, Vector2] = {}


func _ready() -> void:
	y_sort_enabled = true


func clear() -> void:
	for f: VillagerFigure in figures.values():
		f.queue_free()
	figures.clear()
	ring.clear()


func populate(m: Match) -> void:
	clear()
	view.set_open_count(m.config.shelters)   # таблички этой партии — до расстановки
	var figs: Array[VillagerFigure] = []
	for v: Villager in m.villagers:
		var f := VillagerFigure.new()
		f.setup(v.name, book.for_name(v.name, v.is_player), v.is_player)
		add_child(f)
		figures[v.id] = f
		figs.append(f)
	var widths: Array[float] = []
	for f: VillagerFigure in figs:
		widths.append(f.label_width())
	var spots := layout_day(widths)
	for i in range(figs.size()):
		figs[i].position = spots[i]
		ring[m.villagers[i].id] = spots[i]


## Днём — два ряда. Передний перед колодцем (вы в центре), задний на уровне колодца,
## место у самого колодца свободно. Шаг в ряду — по ширине имени, между рядами 76 px:
## имя заднего не прячется за спиной переднего.
const ROW_FRONT := 64.0
const ROW_BACK := -12.0
const WELL_GAP := 50.0
const GAP := 12.0
const MIN_W := 50.0        ## место под фигурку и колонку отметок справа от головы
## Ночью у двери: шаг шире самого длинного имени, ряды не налезают.
const QUEUE_COL := 66.0
const QUEUE_ROW := 78.0


## Прямоугольник, который занимает житель с именем шириной w: тело и подпись.
static func slot_rect(p: Vector2, w: float) -> Rect2:
	var ww := maxf(w, MIN_W)
	return Rect2(p.x - ww * 0.5, p.y - 56.0, ww, 78.0)


## Препятствия для расстановки: таблички открытых убежищ (и, если нужно, место игрока).
func obstacles(with_player: bool) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in range(view.open_count):
		out.append(view.shelter_label_rect_local(i).grow(4.0))
	if with_player and figures.has(0):
		var p: Vector2 = ring.get(0, figures[0].position)
		out.append(slot_rect(p, figures[0].label_width()).grow(4.0))
	return out


func _free(r: Rect2, obs: Array[Rect2]) -> bool:
	for o: Rect2 in obs:
		if r.intersects(o):
			return false
	return true


## Совместимость: места по числу жителей (без учёта ширины имён).
func spots_for(n: int) -> Array[Vector2]:
	var widths: Array[float] = []
	for i in range(n):
		widths.append(48.0)
	return layout_day(widths)


func layout_day(widths: Array[float]) -> Array[Vector2]:
	var c := view.def.square_center
	var r := view.def.square_radii
	var a_y := c.y + ROW_FRONT
	var b_y := c.y + ROW_BACK
	var a_half := r.x * sqrt(1.0 - pow(ROW_FRONT / r.y, 2.0)) - 6.0
	var b_half := r.x * sqrt(1.0 - pow(ROW_BACK / r.y, 2.0)) - 6.0
	var out: Array[Vector2] = []
	out.resize(widths.size())
	if widths.is_empty():
		return out
	var w0 := maxf(widths[0], MIN_W) + GAP
	out[0] = Vector2(c.x, a_y)
	var a_left := c.x - w0 * 0.5
	var a_right := c.x + w0 * 0.5
	var b_left := c.x - WELL_GAP
	var b_right := c.x + WELL_GAP
	var c_left := c.x - WELL_GAP
	var c_right := c.x + WELL_GAP
	var obs := obstacles(false)
	var a_open := [true, true]
	var b_open := [true, true]
	var side := 1
	for i in range(1, widths.size()):
		var w := maxf(widths[i], MIN_W) + GAP
		var placed := false
		for attempt in range(2):
			var sd := side if attempt == 0 else -side
			if sd > 0 and a_open[1] and a_right + w <= c.x + a_half:
				if _free(slot_rect(Vector2(a_right + w * 0.5, a_y), w - GAP), obs):
					out[i] = Vector2(a_right + w * 0.5, a_y)
					a_right += w
					placed = true
				else:
					a_open[1] = false
			elif sd < 0 and a_open[0] and a_left - w >= c.x - a_half:
				if _free(slot_rect(Vector2(a_left - w * 0.5, a_y), w - GAP), obs):
					out[i] = Vector2(a_left - w * 0.5, a_y)
					a_left -= w
					placed = true
				else:
					a_open[0] = false
			if placed:
				break
		if not placed:
			for attempt in range(2):
				var sd := side if attempt == 0 else -side
				if sd > 0 and b_open[1] and b_right + w <= c.x + b_half:
					if _free(slot_rect(Vector2(b_right + w * 0.5, b_y), w - GAP), obs):
						out[i] = Vector2(b_right + w * 0.5, b_y)
						b_right += w
						placed = true
					else:
						b_open[1] = false
				elif sd < 0 and b_open[0] and b_left - w >= c.x - b_half:
					if _free(slot_rect(Vector2(b_left - w * 0.5, b_y), w - GAP), obs):
						out[i] = Vector2(b_left - w * 0.5, b_y)
						b_left -= w
						placed = true
					else:
						b_open[0] = false
				if placed:
					break
		if not placed:
			# запасной третий ряд позади — на случай очень длинных имён
			var y3 := b_y - QUEUE_ROW
			if side > 0:
				out[i] = Vector2(c_right + w * 0.5, y3)
				c_right += w
			else:
				out[i] = Vector2(c_left - w * 0.5, y3)
				c_left -= w
		side = -side
	return out


## Очередь у двери: ряды по 3+ человек, от двери к площади. Ряд целиком сдвигается
## внутрь экрана. У домов перед площадью очередь стоит сбоку — иначе ушла бы за нижний край.
## avoid — точки, где уже кто-то стоит (например, вы): там очередь не встаёт.
func door_spots(house: int, n: int, avoid: Array[Rect2] = []) -> Array[Vector2]:
	var best: Array[Vector2] = []
	for per_row in range(maxi(3, ceili(n / 2.0)), 11):
		var got := _door_rows(house, n, per_row, avoid)
		if got.size() >= n:
			return got
		if got.size() > best.size():
			best = got
	return best


func _door_rows(house: int, n: int, per_row: int, avoid: Array[Rect2]) -> Array[Vector2]:
	var h: HouseDef = view.def.shelters[house]
	var c := view.def.square_center
	var front := h.pos.y > c.y
	var out: Array[Vector2] = []
	var row := 0
	var band := VillageView.BAND
	while out.size() < n and row < 8:
		var xs: Array[float] = []
		for col in range(per_row):
			xs.append(h.pos.x + (col - (per_row - 1) * 0.5) * QUEUE_COL)
		var base_y := h.pos.y + 24.0 + row * QUEUE_ROW
		if front:
			var shift := signf(c.x - h.pos.x) * (h.size.x * 0.5 + QUEUE_COL * (per_row * 0.5 + 0.2))
			for k in range(xs.size()):
				xs[k] += shift
			base_y = h.pos.y - 4.0 - row * QUEUE_ROW
		var lo: float = xs.min()
		var hi: float = xs.max()
		var delta := 0.0
		if lo < VillageView.SAFE_X.x:
			delta = VillageView.SAFE_X.x - lo
		elif hi > VillageView.SAFE_X.y:
			delta = VillageView.SAFE_X.y - hi
		for x: float in xs:
			if out.size() >= n:
				break
			var p := Vector2(x + delta, base_y)
			var r := slot_rect(p, QUEUE_COL - 6.0)
			var inside := r.position.y >= band.position.y and r.end.y <= band.end.y - 2.0
			if inside and _free(r, avoid):
				out.append(p)
		row += 1
	return out


func door_spot(house: int, k: int) -> Vector2:
	var spots := door_spots(house, k + 1, _avoid())
	return spots[k] if k < spots.size() else view.def.shelters[house].pos


func _avoid() -> Array[Rect2]:
	return obstacles(true)


## Кто под пальцем: ближайший к точке касания житель, в чью зону касания она попала. -1 — никто.
func figure_at(global_pos: Vector2) -> int:
	var best := -1
	var best_d := INF
	for vid: int in figures:
		var f: VillagerFigure = figures[vid]
		if not f.visible or f.state == VillagerFigure.State.DEAD or f.state == VillagerFigure.State.GONE:
			continue
		var r := f.hit_rect_global()
		if r.has_point(global_pos):
			var d := r.get_center().distance_to(global_pos)
			if d < best_d:
				best_d = d
				best = vid
	return best


func set_player_highlight(on: bool) -> void:
	if figures.has(0):
		figures[0].set_highlight(on)


func update_marks(d: Director, m: Match) -> void:
	if d == null or m == null:
		return
	for v: Villager in m.villagers:
		if not figures.has(v.id):
			continue
		var has_pact := not v.is_player and d.brains.has(v.id) and d.brains[v.id].pact_id == m.player().id
		figures[v.id].set_marks(d.eye_level(v.id) if v.alive else 0, d.badges(v.id) if v.alive else PackedStringArray(), has_pact and v.alive)


## Ночь: все бегут к домам, о которых говорили. player_house — куда идёшь ты
## (днём объявил или ночью выбрал тапом); ты первым в очереди к той двери.
func arrange_night(m: Match, player_house: int) -> void:
	var groups: Dictionary[int, Array] = {}
	var me := m.player()
	var me_goes := me.alive and player_house >= 0 and player_house < view.open_count
	if me_goes:
		groups[player_house] = [me.id]
	for v: Villager in m.alive_bots():
		if v.announced_house >= 0 and v.announced_house < view.open_count and figures.has(v.id):
			if not groups.has(v.announced_house):
				groups[v.announced_house] = []
			groups[v.announced_house].append(v.id)
	var avoid: Array[Rect2] = []
	if not me_goes:
		avoid = _avoid()
		if figures.has(me.id) and figures[me.id].position.distance_to(ring.get(me.id, figures[me.id].position)) > 4.0:
			figures[me.id].run_to(ring[me.id])
	for h: int in groups:
		var ids: Array = groups[h]
		var spots := door_spots(h, ids.size(), avoid)
		for k in range(mini(ids.size(), spots.size())):
			figures[int(ids[k])].run_to(spots[k], 0.9)


func sync(m: Match, phase: Match.Phase) -> void:
	var at_house: Dictionary[int, int] = {}
	for v: Villager in m.villagers:
		var f: VillagerFigure = figures.get(v.id)
		if f == null:
			continue
		if not v.alive:
			if v.exiled:
				f.walk_off(-1.0 if f.position.x < view.def.square_center.x else 1.0)
			else:
				f.die()
			continue
		match phase:
			Match.Phase.NIGHT:
				pass
			Match.Phase.DOOR:
				pass
			_:
				if f.position.distance_to(ring[v.id]) > 4.0:
					f.run_to(ring[v.id])
	if phase == Match.Phase.NIGHT:
		arrange_night(m, m.player().announced_house)
	if phase == Match.Phase.MORNING:
		for v: Villager in m.villagers:
			if v.alive and figures.has(v.id):
				figures[v.id].scare()
