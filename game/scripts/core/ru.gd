class_name Ru
extends RefCounted
## Русская грамматика переехала в файл языка scripts/loc/ru.gd (задача 39).
## Здесь остались только обёртки: файл оставлен, чтобы обновление заливалось без удаления файлов.


static func accusative(name: String) -> String:
	return _ru().name_case(name, "acc", false)


static func genitive(name: String) -> String:
	return _ru().name_case(name, "gen", false)


static func _ru() -> Gram:
	return L._load("ru")
