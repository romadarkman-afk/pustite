class_name VillageProp
extends Node2D
## Предмет посёлка, который может закрыть жителя: дом, колодец, фонарь, поленница, бочка.
## Живёт в слое толпы с сортировкой по глубине: position — точка, где предмет стоит на земле,
## поэтому тот, кто стоит дальше этой точки, оказывается за предметом.
## Рисует VillageView в координатах посёлка (paint получает этот узел как холст).

var paint: Callable


func _draw() -> void:
	draw_set_transform(-position)
	paint.call(self)
	draw_set_transform(Vector2.ZERO)
