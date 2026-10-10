class_name GameConfig
extends Resource
## Баланс партии. Data-driven: каждое поле с @export_range автоматически
## становится ползунком в настройках. Добавили поле — получили ползунок.

const MAX_SHELTERS := 5   ## столько убежищ в файле языка (houses)

## Ползунки настроек: подписи в файле языка под ключами cfg.<поле>.
const LABELS := {
	"players": "cfg.players", "monsters": "cfg.monsters", "shelters": "cfg.shelters", "capacity": "cfg.capacity",
	"nights": "cfg.nights", "day_seconds": "cfg.day_seconds", "door_seconds": "cfg.door_seconds",
	"run_seconds": "cfg.run_seconds", "outside_death": "cfg.outside_death",
	"first_night_outside_death": "cfg.first_night_outside_death", "vote_from_day": "cfg.vote_from_day",
}

@export_range(5, 12) var players: int = 7
@export_range(1, 5) var monsters: int = 2
@export_range(1, 5) var shelters: int = 2
@export_range(2, 4) var capacity: int = 2
@export_range(2, 6) var nights: int = 3
@export_range(40, 240, 5) var day_seconds: int = 90
@export_range(10, 40) var door_seconds: int = 20
## Сколько звонит колокол: за это время надо выбрать дом и добежать. Опоздал — бежишь последним.
@export_range(6, 20) var run_seconds: int = 12
@export_range(40, 100, 5) var outside_death: int = 80
@export_range(0, 100, 5) var first_night_outside_death: int = 40
@export_range(1, 4) var vote_from_day: int = 2
## Лёгкая сложность: игрок всегда человек — новичок учится, а не проигрывает за упыря.
@export var player_always_human: bool = false


## Чинит невозможные сочетания, которые можно накрутить ползунками.
func sanitized() -> GameConfig:
	var c: GameConfig = duplicate() as GameConfig
	c.monsters = clampi(c.monsters, 1, maxi(1, (c.players - 1) / 2))
	c.shelters = clampi(c.shelters, 1, MAX_SHELTERS)
	return c


func outside_death_chance(day: int) -> float:
	return float(first_night_outside_death if day == 1 else outside_death) / 100.0
