class_name Villager
extends RefCounted
## Житель посёлка. Типизированная сущность вместо словаря со строковыми ключами.

var id: int
var name: String
var is_player: bool
var is_upyr: bool = false
var female: bool = false            ## для согласования реплик: «был» / «была»
var alive: bool = true
var exiled: bool = false
var fed: bool = false              ## поел прошлой ночью — этой не убивает
var announced_house: int = -1      ## куда сказал днём, что пойдёт
var night_house: int = -1          ## где реально ночевал последнюю ночь
var role: int = 0                  ## Match.Role: роль человека (Старожил, Знахарка, Староста)
var role_used: bool = false        ## способность уже потрачена (у Старосты — постоянная)
var exiled_day: int = -1           ## в какой день изгнан


func _init(p_id: int, p_name: String, p_is_player: bool) -> void:
	id = p_id
	name = p_name
	is_player = p_is_player
