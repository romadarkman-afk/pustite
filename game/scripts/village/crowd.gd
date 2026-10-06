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
	var spots := spots_for(m.villagers.size())
	for i in range(m.villagers.size()):
		var v: Villager = m.villagers[i]
		var f := VillagerFigure.new()
		f.setup(v.name, book.for_name(v.name, v.is_player), v.is_player)
		f.position = spots[i]
		add_child(f)
		figures[v.id] = f
		ring[v.id] = spots[i]


## Места на кольце вокруг колодца. Первое — ближе всех к зрителю (для игрока).
func spots_for(n: int) -> Array[Vector2]:
	var c := view.def.square_center + Vector2(0, 6)
	var r := view.def.square_radii * Vector2(0.74, 0.64)
	var pts: Array[Vector2] = []
	for i in range(n):
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var a := PI * 0.5 + ARC * (t * 2.0 - 1.0)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	pts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y > q.y)
	return pts


func door_spot(house: int, k: int) -> Vector2:
	var h: HouseDef = view.def.shelters[house]
	return h.pos + Vector2(-26.0 + 26.0 * (k % 3), 20.0 + 14.0 * floorf(k / 3.0))


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
				if not v.is_player and v.announced_house >= 0 and v.announced_house < view.open_count:
					var k: int = at_house.get(v.announced_house, 0)
					at_house[v.announced_house] = k + 1
					f.run_to(door_spot(v.announced_house, k), 0.9)
			Match.Phase.DOOR:
				pass
			_:
				if f.position.distance_to(ring[v.id]) > 4.0:
					f.run_to(ring[v.id])
	if phase == Match.Phase.MORNING:
		for v: Villager in m.villagers:
			if v.alive and figures.has(v.id):
				figures[v.id].scare()
