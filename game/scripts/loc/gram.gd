class_name Gram
extends RefCounted
## Язык игры: тексты и грамматика. Файл языка (scripts/loc/<код>.gd) наследует Gram,
## отдаёт словарь текстов в data() и переопределяет то, чем его грамматика отличается:
## падежи имён, числительные, перечисления.
##
## Шаблоны (L.fill):
##   {who}            — значение как есть; житель — имя, игрок — you.nom
##   {who.acc}        — в падеже: acc, gen, dat у жителей; in, of, to у домов (что есть в языке)
##   {who.cap}        — с заглавной буквы; можно вместе: {who.acc.cap}
##   {who:был|была|были}  — по роду: мужской | женский | игрок или несколько
##   {был|была}       — то же для who; [был|была] — для me, того, кто говорит
##   {n#житель|жителя|жителей} — форма по числу n


var _d: Dictionary = {}


## Код языка: ru, en, de…
func code() -> String:
	return ""


## Словарь: ключ -> строка или массив строк (банк реплик).
func data() -> Dictionary:
	return {}


func d() -> Dictionary:
	if _d.is_empty():
		_d = data()
	return _d


## Какую форму из {n#одна|много} взять для числа n.
func plural_index(n: int) -> int:
	return 0 if absi(n) == 1 else 1


## Имя жителя в падеже. Где падежей нет, имя не меняется.
func name_case(name: String, _case: String, _female: bool) -> String:
	return name


## Игрок в третьем лице: «Вы», «you». Формы по падежам — в data()["you"].
func you(case: String) -> String:
	var y: Variant = d().get("you", {})
	if y is Dictionary:
		return String((y as Dictionary).get(case, (y as Dictionary).get("nom", "")))
	return String(y)


## «Рита, Костя и Нина».
func join(parts: PackedStringArray) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + String(d().get("and", " & ")) + parts[parts.size() - 1]


## Первая буква заглавная. Для письменностей без регистра ничего не меняет.
func cap(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1) if not s.is_empty() else s
