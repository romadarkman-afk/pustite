class_name ChatLine
extends RefCounted

enum Kind { SAY, MINE, SYSTEM }

var kind: Kind
var speaker: Villager      ## null для системных строк
var text: String
var about: Villager = null   ## кого обвиняет реплика: толпа поворачивается к нему


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
