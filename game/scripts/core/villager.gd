class_name Villager
extends RefCounted
## Житель посёлка. Типизированная сущность вместо словаря со строковыми ключами.

var id: int
var name: String
var is_player: bool
var is_upyr: bool = false
var alive: bool = true
var exiled: bool = false
var fed: bool = false              ## поел прошлой ночью — этой не убивает
var announced_house: int = -1      ## куда сказал днём, что пойдёт
var night_house: int = -1          ## где реально ночевал последнюю ночь


func _init(p_id: int, p_name: String, p_is_player: bool) -> void:
	id = p_id
	name = p_name
	is_player = p_is_player
