class_name Crowd
extends Node2D
## Жители на поле. Днём стоят кольцом вокруг колодца (вы — ближе всех к зрителю),
## по колоколу бегут к убежищам и встают у двери в порядке прибытия. Погибшие остаются надгробиями там,
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
		widths.append(f.label_rect_local().size.x)        # ширина имени вместе с капсулой
	var spots := layout_day(widths)
	for i in range(figs.size()):
		figs[i].position = spots[i]
		ring[m.villagers[i].id] = spots[i]


## Днём — два ряда. Передний перед колодцем (вы в центре), задний на уровне колодца,
## место у самого колодца свободно. Шаг в ряду — по ширине имени, между рядами 76 px:
## имя заднего не прячется за спиной переднего.
const ROW_FRONT := 70.0
const ROW_BACK := -50.0
const WELL_GAP := 66.0
const GAP := 4.0
const MIN_W := 58.0        ## место под фигурку и колонку отметок справа от головы
## Ночью у двери: шаг шире самого длинного имени, ряды не налезают.
const QUEUE_COL := 72.0
const QUEUE_ROW := 122.0


## Прямоугольник, который занимает житель с именем шириной w: тело и подпись.
## Дневной ряд: прямоугольник по настоящей форме фигурки — справа колонка значков шире.
## Проверяется только против табличек, поэтому места в ряду меньше не становится.
static func fig_rect(p: Vector2, w: float) -> Rect2:
	var ww := maxf(w, MIN_W)
	var left := maxf(ww * 0.5, 19.0)
	var right := maxf(ww * 0.5, VillagerFigure.MARK_X + 14.0)
	return Rect2(p.x - left, p.y - 90.0, left + right, 117.0)


static func slot_rect(p: Vector2, w: float) -> Rect2:
	var ww := maxf(w, MIN_W)
	return Rect2(p.x - ww * 0.5, p.y - 90.0, ww, 117.0)


## Препятствия для расстановки: таблички открытых убежищ (и, если нужно, место игрока).
func obstacles(with_player: bool) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in range(view.open_count):
		out.append(view.shelter_label_rect_local(i).grow(4.0))
	if with_player and figures.has(0):
		# настоящий прямоугольник твоей фигурки: тело, стрелка «ты» над головой, имя
		var f: VillagerFigure = figures[0]
		var p: Vector2 = ring.get(0, f.position)
		var r := f.body_rect_local().merge(f.label_rect_local())
		r.position += p
		out.append(r.grow(4.0))
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


## Дневная расстановка в два захода: сначала строго на площади; если все не поместились
## в два ряда (11–12 человек с длинными именами), ряды расширяются до краёв кадра.
func layout_day(widths: Array[float]) -> Array[Vector2]:
	var strict := _layout_day(widths, false)
	var third_y := view.def.square_center.y + ROW_BACK - QUEUE_ROW
	for p: Vector2 in strict:
		if absf(p.y - third_y) < 0.5:
			return _layout_day(widths, true)
	return strict


func _layout_day(widths: Array[float], wide: bool) -> Array[Vector2]:
	var c := view.def.square_center
	var r := view.def.square_radii
	var a_y := c.y + ROW_FRONT
	var b_y := c.y + ROW_BACK
	var a_half := r.x * sqrt(1.0 - pow(ROW_FRONT / r.y, 2.0)) - 6.0
	var b_half := r.x * sqrt(1.0 - pow(ROW_BACK / r.y, 2.0)) - 6.0
	if wide:
		a_half = minf(c.x - VillageView.SAFE_X.x, VillageView.SAFE_X.y - c.x)   # передний ряд — на всю безопасную ширину
		b_half = c.x - VillageView.SAFE_X.x                                       # задний ряд — тоже
	var b_max := VillageView.SAFE_X.y
	var c_used: Array[Rect2] = []
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
				if _free(fig_rect(Vector2(a_right + w * 0.5, a_y), w - GAP), obs):
					out[i] = Vector2(a_right + w * 0.5, a_y)
					a_right += w
					placed = true
				else:
					a_open[1] = false
			elif sd < 0 and a_open[0] and a_left - w >= c.x - a_half:
				if _free(fig_rect(Vector2(a_left - w * 0.5, a_y), w - GAP), obs):
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
				if sd > 0 and b_open[1] and b_right + w <= minf(c.x + b_half, b_max):
					if _free(fig_rect(Vector2(b_right + w * 0.5, b_y), w - GAP), obs):
						out[i] = Vector2(b_right + w * 0.5, b_y)
						b_right += w
						placed = true
					else:
						b_open[1] = false
				elif sd < 0 and b_open[0] and b_left - w >= c.x - b_half:
					if _free(fig_rect(Vector2(b_left - w * 0.5, b_y), w - GAP), obs):
						out[i] = Vector2(b_left - w * 0.5, b_y)
						b_left -= w
						placed = true
					else:
						b_open[0] = false
				if placed:
					break
		if not placed:
			# запасной третий ряд позади: свободное место от центра в обе стороны, только в кадре
			var y3 := b_y - QUEUE_ROW
			var best := Vector2.INF
			for off in range(0, 320, 10):
				for sgn: float in ([1.0, -1.0] if side > 0 else [-1.0, 1.0]):
					var cx := c.x + sgn * (WELL_GAP + w * 0.5 + off)
					if cx - w * 0.5 < VillageView.SAFE_X.x or cx + w * 0.5 > VillageView.SAFE_X.y:
						continue
					if _free(fig_rect(Vector2(cx, y3), w - GAP), obs + c_used):
						best = Vector2(cx, y3)
						break
				if best != Vector2.INF:
					break
			if best == Vector2.INF:
				best = Vector2(c.x, y3)
			out[i] = best
			c_used.append(fig_rect(best, w - GAP))
		side = -side
	return out


## Очередь у двери: ряды по 3+ человек, от двери к площади. Ряд целиком сдвигается
## внутрь экрана. У домов перед площадью очередь стоит сбоку — иначе ушла бы за нижний край.
## avoid — точки, где уже кто-то стоит (например, вы): там очередь не встаёт.
func door_spots(house: int, n: int, avoid: Array[Rect2] = []) -> Array[Vector2]:
	var best: Array[Vector2] = []
	# самый широкий ряд: крайние фигуры вместе со своей шириной должны остаться в кадре
	var max_row := int((VillageView.SAFE_X.y - VillageView.SAFE_X.x - QUEUE_COL) / QUEUE_COL) + 1
	for per_row in range(mini(maxi(3, ceili(n / 2.0)), max_row), max_row + 1):
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
		# все очереди стоят на общей сетке уровней: люди из соседних очередей — ровно в линию
		# и не задевают друг друга именами и головами
		var k0 := ceili((h.pos.y + 20.0 - c.y - 66.0) / QUEUE_ROW)
		var base_y := c.y + 66.0 + (k0 + row) * QUEUE_ROW
		if front:
			var shift := signf(c.x - h.pos.x) * (h.size.x * 0.5 + QUEUE_COL * (per_row * 0.5 + 0.2))
			for k in range(xs.size()):
				xs[k] += shift
			var k1 := floori((h.pos.y - 4.0 - c.y - 66.0) / QUEUE_ROW)
			base_y = c.y + 66.0 + (k1 - row) * QUEUE_ROW
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
			var r := slot_rect(p, QUEUE_COL - 2.0)
			var inside := r.position.y >= band.position.y and r.end.y <= band.end.y - 2.0
			if inside and _free(r, avoid):
				out.append(p)
		row += 1
	return out


## Места очереди по порядку: первое — ближе всех к двери (там стоит хозяин), дальше — дальше.
func queue_spots(house: int, n: int, avoid: Array[Rect2] = []) -> Array[Vector2]:
	var spots := door_spots(house, n, avoid)
	var door: Vector2 = view.def.shelters[house].pos
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(door) < b.distance_squared_to(door))
	return spots


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


# =============================================================
# Ходьба и дела
# =============================================================
var at_job: Dictionary[int, int] = {}      ## кто сейчас у какого дела
var day_jobs: Array[JobDef] = []           ## дела сегодняшнего дня — Nav ставит в начале дня


## Куда можно ходить: площадь с небольшим запасом по краям. Точку за её пределами
## притягивает к краю — так фигурка не уходит в дома и за реку.
func walk_clamp(p: Vector2) -> Vector2:
	var c := view.def.square_center
	var r := view.def.square_radii * Vector2(1.12, 1.22)
	var d := (p - c) / r
	if d.length() > 1.0:
		d = d.normalized()
		p = c + d * r
	p.x = clampf(p.x, VillageView.SAFE_X.x, VillageView.SAFE_X.y)
	return p


## Место у дела: первый работник встаёт на само место, следующие — по бокам.
func job_spot(ji: int, vid: int) -> Vector2:
	var base := (day_jobs[ji] if ji < day_jobs.size() else view.def.jobs[ji]).pos
	var k := 0
	for other: int in at_job:
		if other != vid and at_job[other] == ji:
			k += 1
	var offs := [0.0, -50.0, 50.0, -100.0]
	return walk_clamp(base + Vector2(offs[k % offs.size()], 0))


## Бот идёт к делу и, дойдя, работает.
func send_to_job(vid: int, ji: int) -> void:
	if not figures.has(vid):
		return
	var f: VillagerFigure = figures[vid]
	var spot := job_spot(ji, vid)
	at_job[vid] = ji
	f.set_working(false)
	f.arrived.connect(func() -> void:
		if at_job.get(vid, -1) == ji and f.position.distance_to(spot) < 2.0:
			f.set_working(true), CONNECT_ONE_SHOT)
	f.walk_to(spot)


## Дело закончено: бот возвращается на своё место у колодца.
func leave_job(vid: int) -> void:
	at_job.erase(vid)
	if not figures.has(vid):
		return
	var f: VillagerFigure = figures[vid]
	f.set_working(false)
	if vid != 0 and ring.has(vid):
		f.walk_to(ring[vid])


func stop_all_work() -> void:
	at_job.clear()
	for f: VillagerFigure in figures.values():
		f.set_working(false)


func set_night(n: float) -> void:
	for f: VillagerFigure in figures.values():
		f.set_night(n)


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
	_place_groups(m, groups, me_goes, func(_vid: int) -> Vector2: return Vector2(0.9, 0.0))


## Бег по колоколу: у каждой двери встают в порядке прибытия, первый — у самой двери.
## react и arrive — секунды от колокола: когда житель сорвался с места и когда он у двери.
## now — сколько уже прошло. Кто ещё не услышал колокол, стоит до своей секунды.
## Вызывается заново, когда игрок выбирает или меняет дом: очередь пересобирается на бегу.
func arrange_run(m: Match, choices: Dictionary[int, int], react: Dictionary[int, float], arrive: Dictionary[int, float], player_house: int, now: float) -> void:
	var groups: Dictionary[int, Array] = {}
	var me := m.player()
	var me_goes := me.alive and player_house >= 0 and player_house < view.open_count
	var who: Dictionary[int, int] = choices.duplicate()
	if me_goes:
		who[me.id] = player_house
	for vid: int in who:
		var h: int = who[vid]
		var v := m.get_villager(vid)
		if v == null or not v.alive or not figures.has(vid) or h < 0 or h >= view.open_count:
			continue
		if not groups.has(h):
			groups[h] = []
		groups[h].append(vid)
	for h: int in groups:
		(groups[h] as Array).sort_custom(func(a: int, b: int) -> bool: return arrive.get(a, 1.0e5) < arrive.get(b, 1.0e5))
	_place_groups(m, groups, me_goes, func(vid: int) -> Vector2:
		var start := maxf(now, react.get(vid, now))
		return Vector2(maxf(0.25, arrive.get(vid, now + 1.0) - start), start - now))


## Расставить группы у дверей. timing(vid) → (секунды бега, секунды ожидания перед стартом).
func _place_groups(m: Match, groups: Dictionary[int, Array], me_goes: bool, timing: Callable) -> void:
	var me := m.player()
	var avoid: Array[Rect2] = []
	if not me_goes:
		avoid = _avoid()
		if figures.has(me.id) and figures[me.id].position.distance_to(ring.get(me.id, figures[me.id].position)) > 4.0:
			figures[me.id].run_to(ring[me.id])
	var leftovers: Array = []
	for h: int in groups:
		var ids: Array = groups[h]
		var spots := queue_spots(h, ids.size(), avoid)
		for k in range(ids.size()):
			if k < spots.size():
				_run_to_spot(int(ids[k]), spots[k], timing)
				avoid.append(slot_rect(spots[k], QUEUE_COL - 2.0))   # очередь у соседней двери обойдёт этих
			else:
				leftovers.append(int(ids[k]))
	# не поместился у своей двери — встаёт в ближайшее свободное место у другого дома
	for vid: int in leftovers:
		var order: Array = range(view.open_count)
		order.sort_custom(func(x: int, y: int) -> bool: return (groups.get(x, []) as Array).size() < (groups.get(y, []) as Array).size())
		for h2: int in order:
			var one := door_spots(h2, 1, avoid)
			if not one.is_empty():
				_run_to_spot(vid, one[0], timing)
				avoid.append(slot_rect(one[0], QUEUE_COL - 2.0))
				break


func _run_to_spot(vid: int, spot: Vector2, timing: Callable) -> void:
	var f: VillagerFigure = figures[vid]
	if f.position.distance_to(spot) <= 2.0 and f.state == VillagerFigure.State.IDLE:
		return
	var tm: Vector2 = timing.call(vid)
	f.run_to(spot, tm.x, tm.y)


func sync(m: Match, phase: Match.Phase) -> void:
	stop_all_work()
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
	# живой игрок: бег начнётся по колоколу (Nav вызовет arrange_run). Без игрока — все к своим домам.
	if phase == Match.Phase.NIGHT and not m.player().alive:
		arrange_night(m, -1)
	if phase == Match.Phase.MORNING:
		for v: Villager in m.villagers:
			if v.alive and figures.has(v.id):
				figures[v.id].scare()
