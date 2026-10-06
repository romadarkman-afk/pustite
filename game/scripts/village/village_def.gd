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
