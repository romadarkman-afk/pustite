class_name GameConfig
extends Resource
## Баланс партии. Data-driven: каждое поле с @export_range автоматически
## становится ползунком в настройках. Добавили поле — получили ползунок.

const MAX_SHELTERS := 5   ## столько названий убежищ есть в Match.HOUSES

const LABELS := {
	"players": "Игроков",
	"monsters": "Упырей",
	"shelters": "Убежищ",
	"capacity": "Мест в убежище",
	"nights": "Ночей до рассвета",
	"day_seconds": "День, секунд",
	"door_seconds": "Решение у двери, секунд",
	"outside_death": "Смерть на улице, %",
	"first_night_outside_death": "То же в первую ночь, %",
	"vote_from_day": "Изгнание с дня",
}

@export_range(5, 12) var players: int = 7
@export_range(1, 5) var monsters: int = 2
@export_range(1, 5) var shelters: int = 2
@export_range(2, 4) var capacity: int = 2
@export_range(2, 6) var nights: int = 3
@export_range(40, 240, 5) var day_seconds: int = 90
@export_range(10, 40) var door_seconds: int = 20
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
