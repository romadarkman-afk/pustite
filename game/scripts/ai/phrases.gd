class_name Phrases
extends RefCounted
## Реплики ботов. Сами строки лежат в файлах языков (scripts/loc/<код>.gd) под ключами ph.<БАНК>,
## здесь только доступ к ним. Метки шаблонов — в scripts/loc/gram.gd:
##   {who}, {who.acc}, {who.gen} — о ком речь;  {был|была} — по роду того, о ком речь;
##   [был|была] — по роду говорящего;  {house}, {house.in}, {house.of} — убежище;  {place} — у какого дела.
## Если речь о самом игроке, вместо банка берётся AT_PLAYER: пол игрока неизвестен,
## поэтому о нём говорят без родовых окончаний.

## Банки, где говорящий кого-то обвиняет: толпа поворачивается к названному.
const ACCUSING: PackedStringArray = ["ACCUSE_STRONG", "ACCUSE_STREET", "ACCUSE_LIAR", "UPYR_DEFLECT",
	"AGREE_ACCUSE", "REPLY_TO_ACCUSED_HUMAN", "AT_PLAYER", "JOB_FAKE", "JOB_FAKE_AT_PLAYER",
	"SABOTAGE_SEEN", "SABOTAGE_SEEN_AT_PLAYER", "ELDER_UPYR", "MEETING_CALL"]

## Мольбы игрока у чужой двери: id и вес в глазах хозяина (Director._plea_weight).
const PLEA_IDS: PackedStringArray = ["shared", "promise", "name", "beg"]


## Банк реплик по имени: Phrases.b("ACCUSE_STRONG").
static func b(bank: String) -> PackedStringArray:
	return L.arr("ph." + bank)


## Мольбы игрока: [{"id", "label", "text"}].
static func player_pleas() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in PLEA_IDS:
		out.append({"id": id, "label": L.t("plea.%s.label" % id), "text": L.t("plea.%s.text" % id)})
	return out


## Что видят у испорченного дела.
static func spoil(kind: JobDef.Kind) -> String:
	var key: String = {JobDef.Kind.WATER: "spoil.water", JobDef.Kind.WOOD: "spoil.wood",
		JobDef.Kind.LAMP: "spoil.lamp", JobDef.Kind.FISH: "spoil.fish"}.get(kind, "spoil.any")
	return L.t(key)


## Быстрые фразы игрока: одно касание — и сказано. Фразы с домом засчитываются
## как объявление, где вы ночуете.
static func quick_for(m: Match) -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(m.houses.size()):
		out.append(L.t("quick.house", {"house": m.houses[i]}))
	out.append_array(L.arr("quick"))
	return out


static func mentions_target(bank: String) -> bool:
	for line: String in b(bank):
		if line.contains("{who"):
			return true
	return false


static func pick(bank: String, rng: RandomNumberGenerator, vars: Dictionary = {}) -> String:
	return L.pick("ph." + bank, rng, vars)


static func fill(template: String, vars: Dictionary) -> String:
	return L.fill(template, vars)
