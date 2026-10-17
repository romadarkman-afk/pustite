class_name Revelations
extends RefCounted
## Откровения кампании (TASK-005): важные факты сюжета и кто о них расскажет.
## У каждого факта главный рассказчик и запасной (номера жителей в L.names), а в конце находка:
## весло, тетрадь, лопата. Рассказывает первый из списка, кто жив и есть в главе.
## Если главного рассказчика нет в живых, сцена говорит об этом: «Раньше об этом рассказала бы Марина».
## Так гибель жителя не обрывает историю, а меняет того, кто её расскажет.
## Тексты: rev.<id>.title, rev.<id>.text (рассказывает {who}), rev.<id>.item (находка), rev.instead.

const LIST := {
	## Лодка вернулась пустой в ночь, когда игрока звали с того берега. Марина — паромщица, Тихон сторожит мост.
	"boat": {"chapter": "a1c2", "sources": [0, 5]},
	## Имя на доске у часовни, вырезанное тридцать лет назад. Лида — учительница, Рита ждёт у моста.
	"board": {"chapter": "a1c3", "sources": [2, 7]},
	## Свежая могила без имени за мельницей. Тимур — могильщик, Миша — следопыт.
	"grave": {"chapter": "a2c1", "sources": [1, 8]},
	## Разгадка «Пустой лодки» в конце акта I (TASK-018): лодку пригнал тот, кто звал игрока с того берега.
	"boat_answer": {"chapter": "", "sources": [0, 5]},
	## «Имя на доске» в главе «Прощание» (TASK-019): на доске имя игрока. Лида, без неё — Рита.
	"board_name": {"chapter": "", "sources": [2, 7]},
}
const ORDER: PackedStringArray = ["boat", "board", "grave"]


## Откровения главы по порядку.
static func for_chapter(chapter_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in ORDER:
		if String(LIST[id].chapter) == chapter_id:
			out.append(id)
	return out


## Кто расскажет: {"who": номер жителя или -1 (находка), "lost": номер погибшего главного рассказчика или -1}.
## present — номера жителей этой главы; пусто — все живые в кампании.
static func source(id: String, present: Array = []) -> Dictionary:
	var srcs: Array = LIST.get(id, {}).get("sources", [])
	var lost := -1
	if not srcs.is_empty() and Save.campaign_dead.has(int(srcs[0])):
		lost = int(srcs[0])
	for s: Variant in srcs:
		var idx := int(s)
		if Save.campaign_dead.has(idx):
			continue
		if not present.is_empty() and not present.has(idx):
			continue
		return {"who": idx, "lost": lost}
	return {"who": -1, "lost": lost}


## Страница сцены: [заголовок, текст]. m — партия главы: рассказчик берётся из её жителей.
static func beat(id: String, m: Match = null) -> Array:
	var present: Array = []
	if m != null:
		for v: Villager in m.villagers:
			if not v.is_player and v.guest_id.is_empty() and v.story_id >= 0:
				present.append(v.story_id)
	var src := source(id, present)
	var text := ""
	if int(src.who) >= 0:
		text = L.t("rev.%s.text" % id, {"who": _person(int(src.who), m), "me": _person(int(src.who), m)})
	else:
		text = L.t("rev.%s.item" % id)
	if int(src.lost) >= 0:
		text = L.t("rev.instead", {"lost": _person(int(src.lost), null)}) + " " + text
	return [L.t("rev.%s.title" % id), text]


## Житель по номеру: из партии, если он там есть, иначе по списку имён языка.
static func _person(idx: int, m: Match) -> Villager:
	if m != null:
		for v: Villager in m.villagers:
			if v.story_id == idx and not v.is_player and v.guest_id.is_empty():
				return v
	var names := L.names()
	var v2 := Villager.new(100 + idx, String(names[clampi(idx, 0, names.size() - 1)][0]), false)
	v2.female = bool(names[clampi(idx, 0, names.size() - 1)][1])
	return v2
