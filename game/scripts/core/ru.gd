class_name Ru
extends RefCounted
## Русский язык в текстах игры: падежи имён и согласование по роду.
## Игрок в третьем лице — «Вы»: пол игрока игра не знает, вежливое «вы» снимает вопрос.


## Падежи убежищ. Именительный и винительный совпадают («иду в Сарай»).
const HOUSE_CASES: Dictionary[String, PackedStringArray] = {
	"Дом у реки": ["Доме у реки", "Дома у реки"],
	"Сарай": ["Сарае", "Сарая"],
	"Церковь": ["Церкви", "Церкви"],
	"Погреб": ["Погребе", "Погреба"],
	"Гараж": ["Гараже", "Гаража"],
}


## Где: «в Сарае». Неизвестное название остаётся как есть.
static func house_in(house: String) -> String:
	return HOUSE_CASES[house][0] if HOUSE_CASES.has(house) else house


## Чего: «до Сарая», «у Сарая», «дверь Сарая».
static func house_of(house: String) -> String:
	return HOUSE_CASES[house][1] if HOUSE_CASES.has(house) else house


## Винительный падеж: Марина → Марину, Женя → Женю, Тимур → Тимура.
static func accusative(name: String) -> String:
	if name.is_empty():
		return name
	var stem := name.substr(0, name.length() - 1)
	match name.right(1):
		"а": return stem + "у"
		"я": return stem + "ю"
		"й", "ь": return stem + "я"
	return name + "а"


## Форма по роду: мужская, женская или «вы» для игрока.
static func g(v: Villager, male: String, female: String, you: String) -> String:
	if v.is_player:
		return you
	return female if v.female else male


static func nom(v: Villager) -> String:
	return "Вы" if v.is_player else v.name


static func acc(v: Villager) -> String:
	return "Вас" if v.is_player else accusative(v.name)


## «Тимур и вы», «Рита, Костя и Нина».
static func join(list: Array[Villager]) -> String:
	var names := PackedStringArray()
	for v: Villager in list:
		names.append("вы" if v.is_player else v.name)
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " и " + names[names.size() - 1]


## «был / была / были» для перечня тех, кто был рядом.
static func were(list: Array[Villager], male: String, female: String, plural: String) -> String:
	if list.size() != 1 or list[0].is_player:
		return plural
	return female if list[0].female else male
