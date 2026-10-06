class_name BotBrain
extends RefCounted
## Личный взгляд одного бота. Публичные улики общие, а это — его опыт:
## с кем ночевал без происшествий, кто не пустил его за порог, с кем договорился.

var me: Villager
var private_delta: Dictionary[int, float] = {}   ## личная поправка к подозрению
var shared_clean: Dictionary[int, int] = {}      ## сколько тихих ночей провёл с кем-то
var grudge: Dictionary[int, float] = {}          ## кто оставил его за дверью
var pact_id: int = -1                            ## договорился ночевать с этим id
var pact_house: int = -1


func _init(v: Villager) -> void:
	me = v


func view(vid: int, public: float) -> float:
	return public + private_delta.get(vid, 0.0) + grudge.get(vid, 0.0) * 0.5


func remember_clean_night(other: Villager) -> void:
	shared_clean[other.id] = shared_clean.get(other.id, 0) + 1
	private_delta[other.id] = private_delta.get(other.id, 0.0) - 0.9


func remember_refusal(host: Villager) -> void:
	grudge[host.id] = grudge.get(host.id, 0.0) + 1.0


func clear_pact() -> void:
	pact_id = -1
	pact_house = -1
