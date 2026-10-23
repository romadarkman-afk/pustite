class_name Weather
extends RefCounted
## Погода и сезон (TASK-061, 062). У каждой главы в config/campaign_chapters.json есть
## world.season и world.weather_profile. Здесь описано, что значит каждый профиль.
## Менеджер ничего не рисует: он отдаёт словарь состояния, а рисует WeatherLayer
## внутри VillageView. Вне кампании погоду задаёт сезон по дате.

enum Season { SUMMER, AUTUMN, WINTER, SPRING }
enum Precip { NONE, RAIN, SNOW }

const SEASON_IDS: PackedStringArray = ["summer", "autumn", "winter", "spring"]

## false в самотестах: сезон по дате менял бы кадры от дня ко дню. Тест --weather включает погоду сам.
static var enabled := true
## Принудительный сезон для проверок и скриншотов; -1 — по дате.
static var forced_season := -1

## Профиль главы.
##   season — сезон (Season); precip — осадки (Precip); power 0..1 — их сила;
##   fog 0..1 — густота тумана; wind -1..1 — ветер (знак — направление);
##   cover 0..1 — снег на земле; amb 0..1 — сила сезонных частиц (пух, пепел, листья, капель);
##   days — множитель силы и снега по дням главы (день 1 — первый элемент, дальше последний).
const PROFILES := {
	"summer_riverbank": {"season": Season.SUMMER, "precip": Precip.NONE, "power": 0.0, "fog": 0.15, "wind": 0.2, "cover": 0.0, "amb": 1.0},
	"peat_smoke": {"season": Season.SUMMER, "precip": Precip.NONE, "power": 0.0, "fog": 0.55, "wind": 0.1, "cover": 0.0, "amb": 1.0},
	"river_storm": {"season": Season.SUMMER, "precip": Precip.RAIN, "power": 0.85, "fog": 0.2, "wind": 0.6, "cover": 0.0, "amb": 0.4, "days": [0.4, 0.7, 1.0]},
	"rain_swollen_river": {"season": Season.AUTUMN, "precip": Precip.RAIN, "power": 0.7, "fog": 0.25, "wind": 0.3, "cover": 0.0, "amb": 0.8, "days": [0.6, 0.8, 1.0]},
	"flood_water": {"season": Season.AUTUMN, "precip": Precip.RAIN, "power": 0.5, "fog": 0.3, "wind": 0.15, "cover": 0.0, "amb": 0.7},
	"frozen_bog": {"season": Season.AUTUMN, "precip": Precip.NONE, "power": 0.0, "fog": 0.5, "wind": 0.2, "cover": 0.15, "amb": 0.5},
	"blizzard": {"season": Season.WINTER, "precip": Precip.SNOW, "power": 1.0, "fog": 0.3, "wind": 0.85, "cover": 0.85, "amb": 1.0, "days": [0.6, 0.8, 1.0]},
	"snowbound_courtyard": {"season": Season.WINTER, "precip": Precip.SNOW, "power": 0.35, "fog": 0.1, "wind": 0.1, "cover": 1.0, "amb": 1.0},
	"fire_and_snow": {"season": Season.WINTER, "precip": Precip.SNOW, "power": 0.6, "fog": 0.2, "wind": 0.4, "cover": 0.9, "amb": 1.0},
	"thaw_rail_fog": {"season": Season.SPRING, "precip": Precip.RAIN, "power": 0.3, "fog": 0.8, "wind": 0.1, "cover": 0.3, "amb": 1.0, "days": [1.0, 0.8, 0.6]},
	"coal_yard_mist": {"season": Season.SPRING, "precip": Precip.NONE, "power": 0.0, "fog": 1.0, "wind": 0.05, "cover": 0.1, "amb": 0.7},
	"last_freeze_train": {"season": Season.SPRING, "precip": Precip.SNOW, "power": 0.25, "fog": 0.7, "wind": 0.3, "cover": 0.25, "amb": 0.6},
}

## Лёгкая сезонная тонировка земли, домов и фигур. Множитель, поэтому каналы не выше 1.
const TINTS: Array[Color] = [
	Color(1.0, 1.0, 0.95),
	Color(1.0, 0.92, 0.82),
	Color(0.86, 0.93, 1.0),
	Color(0.93, 1.0, 0.95),
]

const EMPTY := {"active": false, "season": Season.SUMMER, "precip": Precip.NONE, "power": 0.0,
	"fog": 0.0, "wind": 0.0, "cover": 0.0, "amb": 0.0, "id": ""}


static func season_id(season: int) -> String:
	return SEASON_IDS[clampi(season, 0, SEASON_IDS.size() - 1)]


static func season_from_id(id: String) -> int:
	var i := SEASON_IDS.find(id)
	return i if i >= 0 else Season.SUMMER


static func tint(season: int) -> Color:
	return TINTS[clampi(season, 0, TINTS.size() - 1)]


## Сезон по календарю: март–май весна, июнь–август лето, сентябрь–ноябрь осень, остальное зима.
static func season_by_date(month: int) -> int:
	if month >= 3 and month <= 5:
		return Season.SPRING
	if month >= 6 and month <= 8:
		return Season.SUMMER
	if month >= 9 and month <= 11:
		return Season.AUTUMN
	return Season.WINTER


static func current_season() -> int:
	if forced_season >= 0:
		return forced_season
	return season_by_date(int(Time.get_date_dict_from_system().get("month", 6)))


## Погода вне кампании: мягкая, чтобы поле оставалось читаемым.
static func _season_default(season: int) -> Dictionary:
	match season:
		Season.AUTUMN:
			return {"season": season, "precip": Precip.RAIN, "power": 0.35, "fog": 0.25, "wind": 0.2, "cover": 0.0, "amb": 0.8}
		Season.WINTER:
			return {"season": season, "precip": Precip.SNOW, "power": 0.4, "fog": 0.1, "wind": 0.2, "cover": 0.9, "amb": 1.0}
		Season.SPRING:
			return {"season": season, "precip": Precip.NONE, "power": 0.0, "fog": 0.5, "wind": 0.1, "cover": 0.15, "amb": 1.0}
	return {"season": season, "precip": Precip.NONE, "power": 0.0, "fog": 0.15, "wind": 0.15, "cover": 0.0, "amb": 1.0}


## Профиль главы или "" если его нет.
static func profile_id(chapter_id: String) -> String:
	if chapter_id.is_empty():
		return ""
	var world: Dictionary = Campaign.chapter(chapter_id).get("world", {})
	return String(world.get("weather_profile", ""))


## Погода главы на день day (с 1) при ночном событии event (Match.Event).
## Пустая глава: быстрая партия, сезон по дате. Событие играет только ночью, днём передавать NONE.
static func state(chapter_id: String, day: int, event: int = Match.Event.NONE) -> Dictionary:
	if not enabled:
		return EMPTY.duplicate()
	var id := profile_id(chapter_id)
	var base: Dictionary
	if PROFILES.has(id):
		base = (PROFILES[id] as Dictionary).duplicate()
	else:
		base = _season_default(current_season())
		id = ""
	var out := EMPTY.duplicate()
	out.merge(base, true)
	out["active"] = true
	out["id"] = id
	var curve: Array = base.get("days", [])
	if not curve.is_empty():
		var k := float(curve[clampi(day - 1, 0, curve.size() - 1)])
		out["power"] = float(out["power"]) * k
		out["cover"] = clampf(float(out["cover"]) * k, 0.0, 1.0)
	match event:
		Match.Event.RAIN:
			out["precip"] = Precip.SNOW if int(out["season"]) == Season.WINTER else Precip.RAIN
			out["power"] = maxf(float(out["power"]), 0.85)
			out["wind"] = maxf(float(out["wind"]), 0.3)
		Match.Event.FOG:
			out["fog"] = maxf(float(out["fog"]), 0.9)
		Match.Event.QUIET:
			out["power"] = float(out["power"]) * 0.4
			out["wind"] = 0.0
	return out


## Погода текущей партии: событие ночи учитывается только в фазах ночи и стука.
static func for_match(m: Match, phase: int) -> Dictionary:
	if m == null or phase == Match.Phase.IDLE:
		return state("", 1)
	var event: int = Match.Event.NONE
	if phase == Match.Phase.NIGHT or phase == Match.Phase.DOOR:
		event = m.night_event
	return state(m.chapter_id, maxi(m.day, 1), event)


## Меню: сезон по дате без осадков, только лёгкие частицы.
static func for_menu() -> Dictionary:
	var s := state("", 1)
	if bool(s["active"]):
		s["precip"] = Precip.NONE
		s["power"] = 0.0
		s["cover"] = float(s["cover"]) * 0.5
		s["amb"] = float(s["amb"]) * 0.6
	return s
