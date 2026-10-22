class_name Villager
extends RefCounted
## Житель посёлка. Типизированная сущность вместо словаря со строковыми ключами.

var id: int
var name: String
var is_player: bool
var story_id: int = -1             ## постоянная личная история NPC в пределах партии
var anchor_id: int = -1            ## постоянный житель: один из трёх лиц, которые возвращаются между партиями
var relationship: int = 0          ## память о прошлых партиях с игроком, от -3 до +3
var is_upyr: bool = false
var female: bool = false            ## для согласования реплик: «был» / «была»
var age: int = 34                  ## возраст связан с биографией и выбранным портретом
var partner_id: int = -1           ## отношения существуют до приезда игрока; роли их не определяют
var family_id: int = -1            ## родитель или ребёнок из постоянного состава
var family_kind: String = ""       ## кем приходится family_id ему: parent, child, grandparent, grandchild (TASK-007)
var tie_id: int = -1               ## давняя связь не по крови (TASK-007): бывшая помолвка, нож, встреча у моста
var tie_kind: String = ""          ## engaged, knife, bridge
var tie_side: int = -1           ## сторона случайной общей истории
var motive_id: int = -1          ## случайная мотивация жителя в быстрой партии
var guest_id: String = ""         ## гость (Guests.LIST): своя история и тайна; пусто — местный
var persona: int = -1              ## характер речи (Voices.Persona); у игрока нет
var grief_for: int = -1            ## по кому траур: близкий погиб этой ночью
var grief_days: int = 0            ## сколько дней ещё горюет: не работает, говорит о погибшем
var grief_comforted: bool = false  ## игрок уже поддержал жителя в этой утрате
var blame_id: int = -1             ## кого винит в гибели близкого: хозяин двери, что не открыл
var blame_via: int = -1            ## откуда знает об отказе: свой id — видел сам, чужой — рассказал этот житель
var last_words: String = ""        ## последние слова, если погиб ночью
var reaction: String = ""          ## TASK-010: как принял гибель близкого у двери игрока: accuse, defend, withdraw, revenge
var story_step: int = 0
var personal_day: int = 0
var alive: bool = true
var exiled: bool = false
var departed: bool = false         ## TASK-020: уплыл на лодке за реку — жив, но в деревне его нет
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
