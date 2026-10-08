class_name Ru
extends RefCounted
## Русский язык в текстах игры: падежи имён и согласование по роду.
## Игрок в третьем лице — «Вы»: пол игрока игра не знает, вежливое «вы» снимает вопрос.


## Падежи убежищ. Именительный и винительный совпадают («иду в Сарай»).
## Записаны прямо в коде: константа-словарь с массивами внутри в Godot 4.6
## молча теряла значения (чтение давало пустую строку) — такие конструкции не используем.

## Где: «в Сарае». Неизвестное название остаётся как есть.
static func house_in(house: String) -> String:
	match house:
		"Дом у реки": return "Доме у реки"
		"Сарай": return "Сарае"
		"Церковь": return "Церкви"
		"Погреб": return "Погребе"
		"Гараж": return "Гараже"
	return house


## Чего: «до Сарая», «у Сарая», «дверь Сарая».
static func house_of(house: String) -> String:
	match house:
		"Дом у реки": return "Дома у реки"
		"Сарай": return "Сарая"
		"Церковь": return "Церкви"
		"Погреб": return "Погреба"
		"Гараж": return "Гаража"
	return house


## Числительные: 1 житель, 2 жителя, 5 жителей, 21 житель.
static func plural(n: int, one: String, few: String, many: String) -> String:
	var n10 := absi(n) % 10
	var n100 := absi(n) % 100
	if n10 == 1 and n100 != 11:
		return one
	if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14):
		return few
	return many


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
