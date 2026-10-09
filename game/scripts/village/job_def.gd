class_name JobDef
extends Resource
## Дело по посёлку: натаскать воды, нарубить дров, заправить фонари.
## Сделанные днём дела копятся в запасы посёлка: чем их больше, тем светлее ночью
## и тем больше шансов дожить до утра на улице или одному в доме.
## Координаты — в логическом пространстве посёлка 720×600.

enum Kind { WATER, WOOD, LAMP, TALISMAN, FISH }

@export var id: StringName = &""
@export var title: String = ""             ## «Натаскать воды» — подпись в шторке и подсказке
@export var place: String = ""             ## где это: «у колодца» — для реплик «стоял у колодца»
@export var done_line: String = ""         ## что скажет житель, закончив: «Воды до утра хватит.»
@export var kind: Kind = Kind.WATER
@export var pos: Vector2 = Vector2.ZERO    ## где стоит работник; значок дела висит над ним
@export_range(1, 5) var portions: int = 2  ## сколько раз за день можно сделать это дело
@export_range(1.0, 8.0, 0.5) var work_sec: float = 3.0   ## сколько секунд работает игрок
