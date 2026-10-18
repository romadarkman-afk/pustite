class_name VillageDef
extends Resource
## Карта посёлка. shelters — убежища в том же порядке, что Match.HOUSES:
## первые N из них открыты в партии, остальные стоят заколоченными.
## decor — дома для фона, в них никто не прячется.

@export var shelters: Array[HouseDef] = []
@export var decor: Array[HouseDef] = []
@export var lamps: PackedVector2Array = PackedVector2Array()
@export var well: Vector2 = Vector2(360, 372)
@export var square_center: Vector2 = Vector2(360, 380)
@export var square_radii: Vector2 = Vector2(235, 92)
@export var river: bool = true
## Земля: картинки assets/village/<ground>_day.jpg и _night.jpg и куда они ложатся на поле.
@export var ground: String = "ground"
@export var ground_rect: Rect2 = Rect2(-88.8, 31.6, 816.0, 609.3)
@export var well_sprite: bool = true          ## колодец картинкой поверх земли; false — он уже нарисован на земле
@export var houses_key: String = "houses"     ## названия убежищ в файле языка
@export var fences: PackedVector2Array = PackedVector2Array([Vector2(14, 560), Vector2(604, 560)])
@export var fish_planks: bool = true          ## мостки у дела «рыба»; false — мостки уже на земле
## Дела по посёлку на день. Порядок — порядок значков на поле.
@export var jobs: Array[JobDef] = []
## Реквизит для вида: {"id": "prop_cart", "pos": где стоит на земле, "w": ширина, "flip": зеркально}.
## Картинка — assets/village/<id>.png. Жители за предмет не встают.
@export var props: Array[Dictionary] = []
## Куда ложатся лужи в дождливую ночь (центр, ширина картинки на поле).
@export var puddle_spots: PackedVector3Array = PackedVector3Array([Vector3(250, 452, 150), Vector3(492, 470, 130)])
## Низкие дома (номера убежищ): в половодье их заливает (TASK-024).
@export var low: PackedInt32Array = PackedInt32Array()
## Где может появиться ящик: края площади, в стороне от дел и табличек.
@export var box_spots: PackedVector2Array = PackedVector2Array([Vector2(190, 420), Vector2(530, 432), Vector2(292, 492), Vector2(446, 500)])


func job_index(id: StringName) -> int:
	for i in range(jobs.size()):
		if jobs[i].id == id:
			return i
	return -1


func total_portions() -> int:
	var n := 0
	for j: JobDef in jobs:
		n += j.portions
	return n
