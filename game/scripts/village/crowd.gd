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
var day_life := false           ## днём жители переминаются, чешут затылок и шепчутся
var _whisper_in := 4.0
var _fidget_clock := 2.0
var _life_rng := RandomNumberGenerator.new()
var place_grade := Color.WHITE
var whispers := 0               ## для самотеста
var flinched := 0               ## сколько жителей вздрогнули на последний колокол
var npc: Npc = null              ## хозяин места вне голосования (TASK-021): мельник, Игнат, начальник станции
var npcs: Dictionary[String, Npc] = {}   ## все хозяева места этой главы; npc — первый из них
var fx_frost := 0.0              ## иней и влага на фигурах (TASK-067), задаёт VillageView по погоде
var fx_wet := 0.0


func _ready() -> void:
	y_sort_enabled = true


func clear() -> void:
	for f: VillagerFigure in figures.values():
		f.queue_free()
	figures.clear()
	ring.clear()
	day_life = false
	_fidget_clock = 2.0
	for n: Npc in npcs.values():
		n.queue_free()
	npcs.clear()
	npc = null


func populate(m: Match) -> void:
	clear()
	_life_rng.seed = absi(m.rng.seed) + 7919
	_fidget_clock = _life_rng.randf_range(1.2, 3.0)
	view.set_open_count(m.config.shelters)   # таблички этой партии — до расстановки
	var figs: Array[VillagerFigure] = []
	var used := {}          # картинки жителей: повтор, только когда подходящие кончились
	for v: Villager in m.villagers:
		var f := VillagerFigure.new()
		var l := book.for_name(v.name, v.is_player).duplicate() as LookDef
		if not v.is_player:
			l.female = v.female
			l.age = 0 if v.age < 28 else (2 if v.age >= 55 else 1)
			l.height = clampf(l.height, 0.96, 1.06)
		f.setup(v.name, Cosmetics.dress(l, Save.hat) if v.is_player else l, v.is_player)
		f.set_fidget_seed(hash("%d:%d" % [v.id, m.rng.seed]))
		f.set_identity_color(v.id)
		if v.is_player:
			f.set_sprite(Cosmetics.avatar_sprite(Save.avatar_id, l))
			f.set_hero_hat(Save.hat if Save.avatar_id == "hero" else "own")
		else:
			var gs := VillagerFigure.guest_sprite(v.guest_id)
			f.sprite_id = gs if gs > 0 else VillagerFigure.pick_cast_sprite(v, used)
		f.modulate = _figure_tint()
		add_child(f)
		if v.is_player:
			f.set_lantern(Save.lantern)
			f.set_brooch(Save.brooch)
		figures[v.id] = f
		f.set_weather_fx(fx_frost, fx_wet)
		f.set_cast_shadow(view.shadow_alpha(view.night) if view != null else 0.0)
		figs.append(f)
	var widths: Array[float] = []
	for f: VillagerFigure in figs:
		widths.append(f.label_rect_local().size.x)        # ширина имени вместе с капсулой
	var spots := layout_day(widths)
	for i in range(figs.size()):
		figs[i].position = spots[i]
		ring[m.villagers[i].id] = spots[i]
	for id: String in m.all_npcs():
		if not Npc.has_def(id):
			continue
		var n := Npc.new()
		n.setup(id)
		n.modulate = _figure_tint()
		add_child(n)
		n.set_weather_fx(fx_frost, fx_wet)
		npcs[id] = n
		if npc == null:
			npc = n


## Тап по хозяину места: его id или "", если палец не на нём.
func npc_at(global_pos: Vector2) -> String:
	for id: String in npcs:
		var n: Npc = npcs[id]
		if n.visible and n.hit_rect_global().has_point(global_pos):
			return id
	return ""


## Днём — два ряда. Передний перед колодцем (вы в центре), задний на уровне колодца,
## место у самого колодца свободно. Шаг в ряду — по ширине имени, между рядами 76 px:
## имя заднего не прячется за спиной переднего.
const ROW_FRONT := 98.0
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
	# высота — по самому высокому жителю (рост до 1.07 с шапкой): иначе макушка задевает табличку дома
	var top := VillagerFigure.FIG_TOP * 1.08
	return Rect2(p.x - left, p.y - top, left + right, top + 27.0)


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


## Последний запасной вариант: любое свободное место на площади, где житель виден целиком и не
## задевает уже расставленных, ближе к середине. Нужен, когда дома закрыли концы рядов.
func _any_spot(out: Array[Vector2], widths: Array[float], i: int, w: float, obs: Array[Rect2], walls: Array[Rect2]) -> Vector2:
	var taken: Array[Rect2] = obs.duplicate()
	for k in range(i):
		taken.append(fig_rect(out[k], maxf(widths[k], MIN_W)))
	var c := view.def.square_center
	var r := view.def.square_radii * Vector2(1.1, 1.3)
	var best := Vector2.INF
	var best_d := INF
	var y := c.y - r.y
	while y <= minf(c.y + r.y, VillageView.BAND.end.y - 30.0):
		var x := VillageView.SAFE_X.x + w * 0.5
		while x <= VillageView.SAFE_X.y - w * 0.5:
			var p := Vector2(x, y)
			var d := ((p - c) / r).length()
			if d <= 1.0 and d < best_d and _spot_ok(p, w, taken, walls) and _conflicts(p, w, out, widths, i) == 0:
				best = p
				best_d = d
			x += 8.0
		y += 8.0
	return best


## Прямоугольники имени (w — ширина с капсулой) и тела, как их считает фигурка: имя под ступнями,
## тело выше точки. У игрока над головой стрелка «ты», поэтому тело выше на 26.
static func _label_box(p: Vector2, w: float) -> Rect2:
	return Rect2(p.x - w * 0.5, p.y + 6.0, w, 21.0)


static func _body_box(p: Vector2, tall: bool) -> Rect2:
	var top := VillagerFigure.FIG_TOP * 1.04 + (26.0 if tall else 0.0)
	return Rect2(p.x - 23.0, p.y - top, 46.0, top + 2.0)


## Сколько уже стоящих мешают жителю в точке p: имена налезают друг на друга или имя дальнего
## закрыто телом ближнего. Игрок (индекс 0) выше остальных из-за стрелки «ты».
func _conflicts(p: Vector2, w: float, out: Array[Vector2], widths: Array[float], i: int) -> int:
	var n := 0
	var lp := _label_box(p, w).grow(2.0)
	var bp := _body_box(p, false)
	for k in range(i):
		var q := out[k]
		var lq := _label_box(q, widths[k]).grow(2.0)
		if lp.intersects(lq):
			n += 1
		elif q.y > p.y + 0.5 and lp.intersects(_body_box(q, k == 0)):
			n += 1
		elif p.y > q.y + 0.5 and lq.intersects(bp):
			n += 1
	return n


## Совсем последний вариант: свободное от домов место, где меньше всего помех именам, а среди
## равных самое далёкое от уже стоящих. Житель не прячется за церковью.
func _roomiest_spot(out: Array[Vector2], widths: Array[float], i: int, obs: Array[Rect2], walls: Array[Rect2]) -> Vector2:
	var c := view.def.square_center
	var r := view.def.square_radii * Vector2(1.1, 1.3)
	var best := Vector2.INF
	var best_gap := -1.0
	var best_bad := 1 << 20
	var y := c.y - r.y
	while y <= minf(c.y + r.y, VillageView.BAND.end.y - 30.0):
		var x := VillageView.SAFE_X.x + 30.0
		while x <= VillageView.SAFE_X.y - 30.0:
			var p := Vector2(x, y)
			if ((p - c) / r).length() <= 1.0 and not _hidden(p, true) and not _point_in_walls(p, walls) and _free(fig_rect(p, MIN_W), obs):
				var gap := INF
				for k in range(i):
					gap = minf(gap, Vector2((p.x - out[k].x) * 0.6, p.y - out[k].y).length())
				var bad := _conflicts(p, widths[i], out, widths, i)
				if bad < best_bad or (bad == best_bad and gap > best_gap):
					best_bad = bad
					best_gap = gap
					best = p
			x += 8.0
		y += 8.0
	return best


## Стоял бы за домом или колодцем: ступни внутри картинки предмета, выше точки, где тот стоит.
func _hidden(p: Vector2, check_torso: bool = false) -> bool:
	if view == null:
		return false
	if check_torso:
		var body_area := Rect2(p + Vector2(-16, -82), Vector2(32, 70))
		for lamp: Vector2 in view.def.lamps:
			if p.y < lamp.y and body_area.intersects(Rect2(lamp - Vector2(9, 82), Vector2(35, 83))):
				return true
	for z: Rect2 in view.hidden_zones():
		var torso := Rect2(p + Vector2(-16, -VillagerFigure.FIG_TOP * 0.94), Vector2(32, VillagerFigure.FIG_TOP * 0.78))
		if z.has_point(p) or (check_torso and p.y < z.end.y - 3.0 and torso.intersects(z)):
			return true
	return false


func _spot_ok(p: Vector2, w: float, obs: Array[Rect2], walls: Array[Rect2]) -> bool:
	return _free(fig_rect(p, w), obs) and not _hidden(p, true) and not _point_in_walls(p, walls)


## Совместимость: места по числу жителей (без учёта ширины имён).
func spots_for(n: int) -> Array[Vector2]:
	var widths: Array[float] = []
	for i in range(n):
		widths.append(48.0)
	return layout_day(widths)


## Дневная расстановка в два захода: сначала строго на площади; если все не поместились
## в два ряда (11–12 человек с длинными именами), ряды расширяются до краёв кадра.
func layout_day(widths: Array[float]) -> Array[Vector2]:
	var walls := _walk_walls()
	var strict := _layout_day(widths, false, walls)
	var back_y := view.def.square_center.y + ROW_BACK
	for p: Vector2 in strict:
		if p.y < back_y - 0.5:        # кто-то попал в запасной третий ряд — пробуем ряды пошире
			return _layout_day(widths, true, walls)
	return strict


func _layout_day(widths: Array[float], wide: bool, walls: Array[Rect2]) -> Array[Vector2]:
	var c := view.def.square_center
	var r := view.def.square_radii
	var a_y := c.y + ROW_FRONT
	var b_y := c.y + ROW_BACK
	# Передний ряд расположен перед нижними домами, иначе крыши закрывают плечи.
	var a_half := maxf(190.0, r.x * sqrt(maxf(0.0, 1.0 - pow(ROW_FRONT / r.y, 2.0))) - 6.0)
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
				if _spot_ok(Vector2(a_right + w * 0.5, a_y), w - GAP, obs, walls):
					out[i] = Vector2(a_right + w * 0.5, a_y)
					a_right += w
					placed = true
				else:
					a_open[1] = false
			elif sd < 0 and a_open[0] and a_left - w >= c.x - a_half:
				if _spot_ok(Vector2(a_left - w * 0.5, a_y), w - GAP, obs, walls):
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
					if _spot_ok(Vector2(b_right + w * 0.5, b_y), w - GAP, obs, walls):
						out[i] = Vector2(b_right + w * 0.5, b_y)
						b_right += w
						placed = true
					else:
						b_open[1] = false
				elif sd < 0 and b_open[0] and b_left - w >= c.x - b_half:
					if _spot_ok(Vector2(b_left - w * 0.5, b_y), w - GAP, obs, walls):
						out[i] = Vector2(b_left - w * 0.5, b_y)
						b_left -= w
						placed = true
					else:
						b_open[0] = false
				if placed:
					break
		if not placed:
			# запасной третий ряд позади: свободное место от центра в обе стороны, только в кадре.
			# Нет места на линии ряда — пробуем чуть ближе к колодцу (за ним, под табличкой дома)
			var y3 := b_y - QUEUE_ROW
			var best := Vector2.INF
			for dy: float in [0.0, 15.0, 30.0, 45.0]:
				for off in range(0, 320, 10):
					var xs3: Array[float] = []
					if off == 0 and dy > 0.0:
						xs3.append(c.x)       # ближе к колодцу середина ряда тоже годится
					for sgn: float in ([1.0, -1.0] if side > 0 else [-1.0, 1.0]):
						xs3.append(c.x + sgn * (WELL_GAP + w * 0.5 + off))
					for cx: float in xs3:
						if cx - w * 0.5 < VillageView.SAFE_X.x or cx + w * 0.5 > VillageView.SAFE_X.y:
							continue
						if _spot_ok(Vector2(cx, y3 + dy), w - GAP, obs + c_used, walls):
							best = Vector2(cx, y3 + dy)
							break
					if best != Vector2.INF:
						break
				if best != Vector2.INF:
					break
			if best == Vector2.INF:
				best = _any_spot(out, widths, i, w - GAP, obs + c_used, walls)
			if best == Vector2.INF:
				# мест без наложения нет: встаём туда, где просторнее всего, но не за дом и не в стену
				best = _roomiest_spot(out, widths, i, obs, walls)
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
	var walls := _walk_walls(house)
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
			if inside and _free(r, avoid) and not _hidden(p) and not _point_in_walls(p, walls):
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
	var walls := _walk_walls()
	if _point_in_walls(p, walls):
		var found := false
		for radius in range(1, 33):
			for step in range(16):
				var a := TAU * float(step) / 16.0
				var candidate := p + Vector2(cos(a), sin(a)) * float(radius * 6)
				if candidate.x < VillageView.SAFE_X.x or candidate.x > VillageView.SAFE_X.y:
					continue
				if ((candidate - c) / r).length() > 1.0 or _point_in_walls(candidate, walls):
					continue
				p = candidate
				found = true
				break
			if found:
				break
	return p


func _point_in_walls(p: Vector2, walls: Array[Rect2]) -> bool:
	for wall: Rect2 in walls:
		if wall.has_point(p):
			return true
	return false


## Проложить путь по площади: фасады домов непроходимы, у нужной двери остаётся проход.
func walk_route(from: Vector2, destination: Vector2, door_house: int = -1) -> PackedVector2Array:
	var target := destination
	var direct := PackedVector2Array([target])
	var walls := _walk_walls(door_house)
	if _segment_clear(from, target, walls):
		return direct

	const CELL := 16.0
	const GRID := Vector2i(45, 38)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, GRID)
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for wall: Rect2 in walls:
		var lo := Vector2i(maxi(0, floori(wall.position.x / CELL)), maxi(0, floori(wall.position.y / CELL)))
		var hi := Vector2i(mini(GRID.x, ceili(wall.end.x / CELL)), mini(GRID.y, ceili(wall.end.y / CELL)))
		for y in range(lo.y, hi.y):
			for x in range(lo.x, hi.x):
				var id := Vector2i(x, y)
				if wall.has_point(grid.get_point_position(id)):
					grid.set_point_solid(id, true)
	var start_id := _free_cell(grid, from, CELL, GRID)
	var end_id := _free_cell(grid, target, CELL, GRID)
	if grid.is_point_solid(start_id) or grid.is_point_solid(end_id):
		return PackedVector2Array([from])
	var cells: Array[Vector2i] = grid.get_id_path(start_id, end_id, true)
	if cells.is_empty():
		return PackedVector2Array([from])
	var raw: Array[Vector2] = []
	for i in range(1, cells.size()):
		raw.append(grid.get_point_position(cells[i]))
	raw.append(target)
	var smooth := PackedVector2Array()
	var anchor := from
	while not raw.is_empty():
		var far := -1
		for i in range(raw.size() - 1, -1, -1):
			if _segment_clear(anchor, raw[i], walls):
				far = i
				break
		if far < 0:
			return smooth if not smooth.is_empty() else PackedVector2Array([from])
		var next: Vector2 = raw[far]
		smooth.append(next)
		anchor = next
		raw = raw.slice(far + 1)
	return smooth if not smooth.is_empty() else PackedVector2Array([from])


func _free_cell(grid: AStarGrid2D, p: Vector2, cell: float, dimensions: Vector2i) -> Vector2i:
	var center := Vector2i(clampi(floori(p.x / cell), 0, dimensions.x - 1), clampi(floori(p.y / cell), 0, dimensions.y - 1))
	if not grid.is_point_solid(center):
		return center
	for radius in range(1, 8):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := center + Vector2i(x, y)
				if candidate.x >= 0 and candidate.y >= 0 and candidate.x < dimensions.x and candidate.y < dimensions.y and not grid.is_point_solid(candidate):
					return candidate
	return center


const DOOR_GAP_DEPTH := 40.0    ## глубина прохода к двери: от порога вглубь, не сквозь дом


func _walk_walls(door_house: int = -1) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var houses: Array[HouseDef] = []
	houses.append_array(view.def.shelters)
	houses.append_array(view.def.decor)
	for i in range(houses.size()):
		var h: HouseDef = houses[i]
		var r := view.house_rect(h)
		# Коллизия совпадает с областью, за которой дом закрывает фигуру.
		# Дорожка и очередь перед основанием остаются свободны.
		var footprint := Rect2(r.position.x + r.size.x * 0.08, r.position.y,
			r.size.x * 0.84, h.pos.y - r.position.y)
		if i != door_house:
			out.append(footprint)
			continue
		# Только выбранный вход получает проход, и только спереди: через весь дом от задней стены не пройти.
		var door := view.door_rect(h)
		var gap_width := maxf(door.size.x + 34.0, 48.0)
		var gap_depth := minf(DOOR_GAP_DEPTH, footprint.size.y)
		var gap := Rect2(door.get_center().x - gap_width * 0.5, footprint.end.y - gap_depth,
			gap_width, gap_depth)
		gap = gap.intersection(footprint)
		if gap.size.x <= 0.0 or gap.size.y <= 0.0:
			out.append(footprint)
			continue
		# Над проходом стена сплошная, по бокам от прохода тоже.
		out.append(Rect2(footprint.position, Vector2(footprint.size.x, footprint.size.y - gap.size.y)))
		if gap.position.x > footprint.position.x:
			out.append(Rect2(Vector2(footprint.position.x, gap.position.y), Vector2(gap.position.x - footprint.position.x, gap.size.y)))
		if gap.end.x < footprint.end.x:
			out.append(Rect2(Vector2(gap.end.x, gap.position.y), Vector2(footprint.end.x - gap.end.x, gap.size.y)))
	return out


func _segment_clear(a: Vector2, b: Vector2, walls: Array[Rect2]) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / 6.0))
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		for wall: Rect2 in walls:
			if wall.has_point(p):
				return false
	return true


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
	var t := VillagerFigure.tool_for(day_jobs[ji].kind) if ji >= 0 and ji < day_jobs.size() else ""
	f.arrived.connect(func() -> void:
		if at_job.get(vid, -1) == ji and f.position.distance_to(spot) < 2.0:
			f.set_working(true, t), CONNECT_ONE_SHOT)
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


## Все, кто рядом, поворачиваются к точке x: к говорящему, к обвинённому, к изгнанному.
func turn_to(x: float, except: Array[int] = [], radius: float = 320.0, seconds: float = 2.5) -> void:
	for vid: int in figures:
		var f: VillagerFigure = figures[vid]
		if except.has(vid) or f.state == VillagerFigure.State.DEAD or f.state == VillagerFigure.State.GONE:
			continue
		if absf(f.position.x - x) <= radius:
			f.look_at_x(x, seconds)


## Ночью жители синеют вместе с посёлком. Красится каждая фигура: дома и колодец в этом же слое
## окрашивает сам посёлок, общий цвет слоя затемнил бы их дважды.
var night_tint := Color(1, 1, 1)


## Иней и влага на всех фигурах. Нули снимают шейдер совсем.
func set_weather_fx(frost: float, wet: float) -> void:
	fx_frost = frost
	fx_wet = wet
	for f: VillagerFigure in figures.values():
		f.set_weather_fx(frost, wet)
	for hn: Npc in npcs.values():
		hn.set_weather_fx(frost, wet)


func set_color_grade(grade: Color) -> void:
	place_grade = grade
	set_night(view.night if view != null else 0.0)


func set_night(n: float) -> void:
	night_tint = Color.WHITE.lerp(place_grade, 0.14).lerp(Color(0.76, 0.79, 0.91), n)
	var cast := view.shadow_alpha(n) if view != null else 0.0
	for f: VillagerFigure in figures.values():
		f.set_night(n)
		f.set_cast_shadow(cast)
		f.modulate = night_tint
	for hn: Npc in npcs.values():
		hn.modulate = night_tint


func _figure_tint() -> Color:
	return Color.WHITE.lerp(place_grade, 0.14).lerp(Color(0.76, 0.79, 0.91), view.night if view != null else 0.0)


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
	var avoid := obstacles(false)
	var assigned: Dictionary[int, bool] = {}
	for h: int in groups:
		for vid: int in groups[h]:
			assigned[vid] = true
	for v: Villager in m.villagers:
		if not v.alive or assigned.has(v.id) or not figures.has(v.id):
			continue
		var f: VillagerFigure = figures[v.id]
		var p: Vector2 = ring.get(v.id, f.position) if v.is_player else f.position
		var occupied := f.body_rect_local().merge(f.label_rect_local())
		occupied.position += p
		avoid.append(occupied.grow(4.0))
	if not me_goes and figures.has(me.id) and figures[me.id].position.distance_to(ring.get(me.id, figures[me.id].position)) > 4.0:
		figures[me.id].run_to(ring[me.id])
	var leftovers: Array = []
	for h: int in groups:
		var ids: Array = groups[h]
		var spots := queue_spots(h, ids.size(), avoid)
		for k in range(ids.size()):
			if k < spots.size():
				_run_to_spot(int(ids[k]), spots[k], timing, h)
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
				_run_to_spot(vid, one[0], timing, h2)
				avoid.append(slot_rect(one[0], QUEUE_COL - 2.0))
				break


func _run_to_spot(vid: int, spot: Vector2, timing: Callable, door_house: int) -> void:
	var f: VillagerFigure = figures[vid]
	if f.position.distance_to(spot) <= 2.0 and f.state == VillagerFigure.State.IDLE:
		return
	var tm: Vector2 = timing.call(vid)
	f.run_to(spot, tm.x, tm.y, door_house)


func sync(m: Match, phase: Match.Phase) -> void:
	stop_all_work()
	for n: Npc in npcs.values():
		n.visible = phase in [Match.Phase.DAY, Match.Phase.VOTE, Match.Phase.MORNING, Match.Phase.PROLOGUE]   # ночью хозяин у себя
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
		f.fidgets_on = phase == Match.Phase.DAY
		f.fidgets_managed = f.fidgets_on
		if not f.fidgets_on:
			f.fidget = ""
		match phase:
			Match.Phase.NIGHT:
				pass
			Match.Phase.DOOR:
				pass
			_:
				if f.position.distance_to(ring[v.id]) > 4.0:
					f.run_to(ring[v.id])
	day_life = phase == Match.Phase.DAY
	apply_moods(m)
	if phase == Match.Phase.NIGHT:
		flinch_all()
	# живой игрок: бег начнётся по колоколу (Nav вызовет arrange_run). Без игрока — все к своим домам.
	if phase == Match.Phase.NIGHT and not m.player().alive:
		arrange_night(m, -1)
	# ночью у двери все ёжатся от холода, днём отпускает
	var cold := phase == Match.Phase.NIGHT or phase == Match.Phase.DOOR
	for v: Villager in m.villagers:
		if figures.has(v.id):
			figures[v.id].set_cold(cold and v.alive)
	if phase == Match.Phase.MORNING:
		for v: Villager in m.villagers:
			if v.alive and figures.has(v.id):
				figures[v.id].scare()


## Чувства на поле (TASK-009): горе сутулится и смотрит в сторону, страх дрожит, ярость смотрит на обидчика.
func apply_moods(m: Match) -> void:
	for v: Villager in m.villagers:
		var f: VillagerFigure = figures.get(v.id)
		if f == null or v.is_player:
			continue
		f.mood = m.feelings.main(v.id) if v.alive else ""
		match f.mood:
			"rage":
				var foe: VillagerFigure = figures.get(int(m.feelings.rage_at.get(v.id, -1)))
				if foe != null:
					f.look_at_x(foe.position.x, 6.0)
			"grief", "despair":
				var cx: float = view.def.square_center.x if view != null else 0.0
				f.look_at_x(f.position.x + (200.0 if f.position.x >= cx else -200.0), 6.0)   # отвернулся от людей


## Колокол: все живые вздрагивают и отшатываются от колодца.
func flinch_all() -> void:
	var cx: float = view.def.square_center.x if view != null else 0.0
	flinched = 0
	for f: VillagerFigure in figures.values():
		if f.state == VillagerFigure.State.DEAD or f.state == VillagerFigure.State.GONE:
			continue
		f.set_emotion("shocked", 0.8)
		flinched += 1
		f.lean_for(-0.1 if f.position.x < cx else 0.1, 0.6)


func _process(delta: float) -> void:
	life_step(delta)


## Раз в 6–12 секунд двое соседей по ряду шепчутся: один наклоняется к другому, второй поворачивает голову.
func life_step(delta: float) -> void:
	if not day_life:
		return
	_schedule_fidget(delta)
	_whisper_in -= delta
	if _whisper_in > 0.0:
		return
	_whisper_in = randf_range(6.0, 12.0)
	var free: Array[VillagerFigure] = []
	for vid: int in figures:
		var f: VillagerFigure = figures[vid]
		if vid != 0 and f.is_free() and f.mood != "grief" and f.mood != "despair":
			free.append(f)                   # кто в горе, ни с кем не шепчется
	free.shuffle()
	for a: VillagerFigure in free:
		for b: VillagerFigure in free:
			if a != b and absf(a.position.y - b.position.y) < 30.0 and absf(a.position.x - b.position.x) < 150.0:
				if a.whisper_to(b.position.x):
					whispers += 1
				b.look_at_x(a.position.x, 1.6)
				return


func _schedule_fidget(delta: float) -> void:
	_fidget_clock -= delta
	if _fidget_clock > 0.0:
		return
	var active := false
	var least_used := 2147483647
	var candidates: Array[VillagerFigure] = []
	for f: VillagerFigure in figures.values():
		if f.fidget != "":
			active = true
			break
		if not f.is_free() or f.mood in ["grief", "despair"]:
			continue
		if f.fidget_count < least_used:
			least_used = f.fidget_count
			candidates.clear()
		if f.fidget_count == least_used:
			candidates.append(f)
	if active:
		_fidget_clock = 0.25
		return
	if candidates.is_empty():
		_fidget_clock = _life_rng.randf_range(1.0, 2.5)
		return
	candidates[_life_rng.randi_range(0, candidates.size() - 1)].start_fidget()
	_fidget_clock = _life_rng.randf_range(1.6, 2.8)
