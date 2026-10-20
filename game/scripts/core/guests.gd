class_name Guests
extends RefCounted
## Гости (Task 60): приезжие со своей историей и тайной. Тайна открывается за три утра:
## первая и вторая улика двусмысленны, на третье утро — разгадка. Разгадка своя для человека
## и для упыря, поэтому в быстрой партии по гостю роль заранее не угадать.
## В кампании роль гостя задана сюжетом (upyr_in_campaign).
## Тексты: guest.<id>.name/title/story/clue1/clue2/reveal_h/reveal_u на всех языках.

const LIST := {
	"soldier": {"f": false, "age": 34, "persona": Voices.Persona.GRUFF, "upyr_in_campaign": false},
	"widow": {"f": true, "age": 41, "persona": Voices.Persona.PIOUS, "upyr_in_campaign": false},
	"merchant": {"f": false, "age": 52, "persona": Voices.Persona.CYNIC, "upyr_in_campaign": true},
	## Люди станции (TASK-032), только в кампании: рабочий депо чинит паровоз, писарь пишет список на поезд
	## и берёт за место деньги — это его тайна.
	"worker": {"f": false, "age": 46, "persona": Voices.Persona.GRUFF, "upyr_in_campaign": false},
	"clerk": {"f": false, "age": 38, "persona": Voices.Persona.CYNIC, "upyr_in_campaign": false},
}
const IDS: PackedStringArray = ["soldier", "widow", "merchant"]
const BOOK_IDS: PackedStringArray = ["soldier", "widow", "merchant", "worker", "clerk"]
const QUICK_P := 0.3          ## в быстрой партии с такой вероятностью приезжает один гость
const REVEAL_DAY := 3         ## на какое утро тайна раскрывается целиком
const W_REVEAL_UPYR := 1.6    ## разгадка упыря: подозрение посёлка растёт
const W_REVEAL_HUMAN := -1.0  ## разгадка человека: подозрение уходит


static func name_of(id: String) -> String:
	return L.t("guest.%s.name" % id)


## Превратить жителя в гостя: имя, пол, возраст, характер. Связи с роднёй гость не наследует.
static func apply(m: Match, v: Villager, id: String) -> void:
	var d: Dictionary = LIST[id]
	v.guest_id = id
	v.name = name_of(id)
	v.female = bool(d.f)
	v.age = int(d.age)
	v.persona = int(d.persona)
	v.anchor_id = -1
	for o: Villager in m.villagers:
		if o.partner_id == v.id:
			o.partner_id = -1
		if o.family_id == v.id:
			o.family_id = -1
		if o.tie_id == v.id:
			o.tie_id = -1
			o.tie_kind = ""
	v.partner_id = -1
	v.family_id = -1
	v.tie_id = -1
	v.tie_kind = ""


## Роль гостя по сюжету: число упырей не меняется — с кем-то другим меняемся ролью.
static func force_role(m: Match, v: Villager, upyr: bool) -> void:
	if v.is_upyr == upyr:
		return
	for o: Villager in m.villagers:
		if o != v and not o.is_player and o.guest_id.is_empty() and o.is_upyr == upyr:
			o.is_upyr = not upyr
			v.is_upyr = upyr
			return


## Что посёлок узнаёт о гостях этим утром: [{who, text, reveal}].
static func morning_clues(m: Match) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Villager in m.villagers:
		if v.guest_id.is_empty() or v.is_player:
			continue
		var step := m.day                  # утро после ночи 1 — первая улика, после ночи 3 — разгадка
		if step < 1 or step > REVEAL_DAY:
			continue
		out.append({"who": v, "text": clue(v, step), "reveal": step == REVEAL_DAY})
	return out


static func clue(v: Villager, step: int) -> String:
	var key := "clue%d" % step
	if step >= REVEAL_DAY:
		key = "reveal_u" if v.is_upyr else "reveal_h"
	return L.t("guest.%s.%s" % [v.guest_id, key], {"who": v})


static func title(v: Villager) -> String:
	return L.t("guest.%s.title" % v.guest_id, {"n": v.age})


static func story(v: Villager) -> String:
	return L.t("guest.%s.story" % v.guest_id, {"me": v})
