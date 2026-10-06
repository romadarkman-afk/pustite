class_name LookBook
extends Resource
## Внешности всех жителей. Нет своей — берётся по кругу из списка.

@export var looks: Array[LookDef] = []
@export var player: LookDef


func for_name(name: String, is_player: bool) -> LookDef:
	if is_player and player != null:
		return player
	for l: LookDef in looks:
		if l.who == name:
			return l
	return looks[absi(name.hash()) % looks.size()] if not looks.is_empty() else LookDef.new()
