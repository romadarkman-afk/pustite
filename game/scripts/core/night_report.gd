class_name NightReport
extends RefCounted
## Итог ночи. Всё, что утром узнаёт посёлок, — и ничего сверх того.

enum Kind {
	KILLED_STREET,     ## не пустили, погиб снаружи
	KILLED_INSIDE,     ## погиб в убежище, рядом были others
	KILLED_ALONE,      ## остался один, оберег погас
	SURVIVED_STREET,   ## ночевал снаружи и вернулся — сильная улика
	SURVIVED_ALONE,    ## остался один, но цел
	CLEAN_ROOM,        ## в убежище все целы
	LIAR,              ## говорил одно, ночевал в другом месте
	KILLED_CREATURE,   ## оберег был расколот — в дом вошла тварь из леса
	TALISMAN_WORN,     ## за ночь оберег ослаб: треснул или раскололся (who = null)
	KILLED_MIMIC,      ## впустили Подражателя — он забрал who; voice — чьим голосом он говорил
	MIMIC_SPARED,      ## впустили Подражателя, но до утра все целы (who = null)
	MIMIC_KNOCK,       ## Подражатель стучал, не открыли (who = null)
	SAVED,             ## на who напали, но Знахарка (others[0]) выходила; cause — кто нападал
	TUNNEL,            ## who не пустили в said_house, и он пролез туннелем в house
}

class Entry:
	var kind: Kind
	var who: Villager
	var house: int = -1
	var said_house: int = -1
	var others: Array[Villager] = []
	var voice: Villager = null      ## Подражатель: чьим голосом стучал
	var cause: String = ""          ## SAVED: "upyr", "creature" или "mimic"
	var killer: Villager = null     ## KILLED_INSIDE: кто из упырей убил
	var host: Villager = null       ## кто был хозяином двери этого дома

	func is_death() -> bool:
		return kind == Kind.KILLED_STREET or kind == Kind.KILLED_INSIDE or kind == Kind.KILLED_ALONE \
			or kind == Kind.KILLED_CREATURE or kind == Kind.KILLED_MIMIC

var entries: Array[Entry] = []
var p_out: float = 0.0              ## шанс погибнуть на улице этой ночью
var p_alone: Dictionary = {}        ## дом -> шанс погибнуть одному в нём этой ночью


func add(kind: Kind, who: Villager, house: int = -1, others: Array[Villager] = []) -> Entry:
	var e := Entry.new()
	e.kind = kind
	e.who = who
	e.house = house
	e.others = others
	entries.append(e)
	return e


func deaths() -> Array[Entry]:
	var out: Array[Entry] = []
	for e: Entry in entries:
		if e.is_death():
			out.append(e)
	return out
