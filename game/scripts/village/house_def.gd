class_name HouseDef
extends Resource
## Один дом на карте посёлка. Координаты — в логическом пространстве посёлка 720×600,
## pos — середина основания дома (точка, где стены касаются земли).

enum Kind { HOME, BARN, CHURCH, CELLAR, GARAGE, SHED }

@export var title: String = ""
@export var kind: Kind = Kind.HOME
@export var pos: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2(110, 90)
