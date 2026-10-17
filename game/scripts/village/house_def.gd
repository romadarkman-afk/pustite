class_name HouseDef
extends Resource
## Один дом на карте посёлка. Координаты — в логическом пространстве посёлка 720×600,
## pos — середина основания дома (точка, где стены касаются земли).

enum Kind { HOME, BARN, CHURCH, CELLAR, GARAGE, SHED }

@export var title: String = ""
@export var kind: Kind = Kind.HOME
@export var pos: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2(110, 90)
## Своя картинка дома (карты мельницы, монастыря, станции): assets/village/maps/<art>_day.png
## и, если есть, <art>_night.png с горящими окнами. Пусто — картинка по виду дома.
@export var art: String = ""
@export var art_w: float = 1.4                ## ширина картинки в долях size.x
@export var art_door: Rect2 = Rect2(0.2, 0.6, 0.12, 0.3)   ## дверь на картинке в долях
@export var art_chimney: Vector2 = Vector2(-1, -1)        ## труба в долях картинки; x < 0 — без трубы
