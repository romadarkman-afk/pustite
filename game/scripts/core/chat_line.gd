class_name ChatLine
extends RefCounted

enum Kind { SAY, MINE, SYSTEM }

var kind: Kind
var speaker: Villager      ## null для системных строк
var text: String
var about: Villager = null   ## кого обвиняет реплика: толпа поворачивается к нему
var asks_player: bool = false
var question_kind: String = ""
var emotion: String = ""    ## эмоция известна из сцены, а не угадывается по случайной фразе
var npc_id: String = ""     ## строка хозяина места (TASK-021): системная, но с пузырём над ним на карте
var npc_text: String = ""   ## его слова без имени — для пузыря


static func say(who: Villager, t: String) -> ChatLine:
	var l := ChatLine.new()
	l.kind = Kind.MINE if who != null and who.is_player else Kind.SAY
	l.speaker = who
	l.text = t
	return l


static func system(t: String) -> ChatLine:
	var l := ChatLine.new()
	l.kind = Kind.SYSTEM
	l.speaker = null
	l.text = t
	return l
