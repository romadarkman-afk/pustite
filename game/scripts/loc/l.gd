class_name L
extends RefCounted
## Переводы. Все тексты игры берутся отсюда по ключу: L.t("door.title").
## Язык выбирается в настройках; при первом запуске — по языку телефона.
## Нет строки в выбранном языке — берётся русская, а ключ попадает в L.missing (самотест --loc).

## Порядок в настройках. Код — имя файла scripts/loc/<код>.gd.
const LANGS: PackedStringArray = ["ru", "en", "de", "fr", "es", "pt", "tr", "hi", "vi", "zh"]
const NATIVE := {
	"ru": "Русский", "en": "English", "de": "Deutsch", "fr": "Français", "es": "Español",
	"pt": "Português (Brasil)", "tr": "Türkçe", "hi": "हिन्दी", "vi": "Tiếng Việt", "zh": "简体中文",
}

static var code: String = ""
static var _cur: Gram
static var _ru: Gram
static var missing: Dictionary = {}       ## ключ -> язык, где его не нашли
static var _re_pick: RegEx
static var _re_num: RegEx
static var _re_var: RegEx


## Включить язык. Неизвестный код — русский.
static func use(c: String) -> void:
	if not LANGS.has(c):
		c = "ru"
	if c == code and _cur != null:
		return
	code = c
	_cur = _load(c)
	if _ru == null:
		_ru = _cur if c == "ru" else _load("ru")


static func _load(c: String) -> Gram:
	var path := "res://scripts/loc/%s.gd" % c
	if not ResourceLoader.exists(path):
		return _load("ru") if c != "ru" else Gram.new()
	return (load(path) as GDScript).new() as Gram


static func gram() -> Gram:
	if _cur == null:
		use("ru")
	return _cur


## Язык телефона -> код игры. pt_BR и pt_PT — один португальский, zh_* — упрощённый китайский.
static func detect(os_locale: String = "") -> String:
	var loc := os_locale if not os_locale.is_empty() else OS.get_locale()
	var lang := loc.split("_")[0].split("-")[0].to_lower()
	if LANGS.has(lang):
		return lang
	return "en" if lang != "" and lang != "be" and lang != "uk" and lang != "kk" else "ru"


static func has(key: String) -> bool:
	return gram().d().has(key)


static func raw(key: String) -> Variant:
	var d := gram().d()
	if d.has(key):
		return d[key]
	missing[key] = code
	if _ru != null and _ru.d().has(key):
		return _ru.d()[key]
	return key


## Строка по ключу, с подстановкой.
static func t(key: String, args: Dictionary = {}) -> String:
	var v: Variant = raw(key)
	if v is Array or v is PackedStringArray:
		v = (v as Array)[0] if not (v as Array).is_empty() else key
	return fill(String(v), args)


## Банк строк (реплики ботов, страницы правил).
static func arr(key: String) -> PackedStringArray:
	var v: Variant = raw(key)
	if v is String:
		return PackedStringArray([v])
	return PackedStringArray(v)


static func pick(key: String, rng: RandomNumberGenerator, args: Dictionary = {}) -> String:
	var a := arr(key)
	return fill(a[rng.randi_range(0, a.size() - 1)], args)


## Убежища партии: названия в именительном.
static func houses() -> PackedStringArray:
	var out := PackedStringArray()
	for h: Variant in raw("houses"):
		out.append(String((h as Dictionary).get("nom", "")))
	return out


## Убежище как слово со всеми падежами языка: {"nom", "in", "of", "to"…}.
static func house(i: int) -> Dictionary:
	var hs: Array = raw("houses")
	return (hs[clampi(i, 0, hs.size() - 1)] as Dictionary) if not hs.is_empty() else {}


## Жители посёлка этого языка: [[имя, женщина?], …].
static func names() -> Array:
	return raw("names")


## Внешности жителей этого посёлка.
static func looks() -> LookBook:
	var path := String(raw("looks"))
	var b := load(path) as LookBook if ResourceLoader.exists(path) else null
	return b if b != null else load("res://config/looks.tres") as LookBook


static func female_names() -> PackedStringArray:
	var out := PackedStringArray()
	for n: Variant in names():
		if bool(n[1]):
			out.append(String(n[0]))
	return out


static func _gender(v: Variant) -> int:
	if v is Villager:
		var vv := v as Villager
		return 2 if vv.is_player else (1 if vv.female else 0)
	if v is Array:
		var a := v as Array
		return _gender(a[0]) if a.size() == 1 else 2
	if v is Dictionary:
		return 1 if bool((v as Dictionary).get("f", false)) else 0
	if v is bool:
		return 1 if v else 0
	if v is String:
		# название убежища: род берётся из таблицы домов ("f": true — женский)
		for h: Variant in raw("houses"):
			if String((h as Dictionary).get("nom", "")) == v:
				return 1 if bool((h as Dictionary).get("f", false)) else 0
	return 0


## Значение в нужном падеже. case "" — именительный.
static func render(v: Variant, case: String) -> String:
	var g := gram()
	if v is Villager:
		var vv := v as Villager
		if vv.is_player:
			return g.you(case if case != "" else "nom")
		return g.name_case(vv.name, case, vv.female) if case != "" else vv.name
	if v is Array:
		var parts := PackedStringArray()
		for x: Variant in v:
			parts.append(render(x, case))
		return g.join(parts)
	if v is Dictionary:
		var dd := v as Dictionary
		return String(dd.get(case, dd.get("nom", ""))) if case != "" else String(dd.get("nom", ""))
	if v is String and case != "":
		# название убежища строкой: ищем в таблице домов
		for h: Variant in raw("houses"):
			if String((h as Dictionary).get("nom", "")) == v:
				return String((h as Dictionary).get(case, v))
		return String(v)
	return str(v)


static func fill(template: String, args: Dictionary = {}) -> String:
	if _re_pick == null:
		_re_pick = RegEx.create_from_string("\\{(?:(\\w+):)?([^{}]*\\|[^{}]*)\\}|\\[([^\\[\\]]*\\|[^\\[\\]]*)\\]")
		_re_num = RegEx.create_from_string("\\{(\\w+)#([^{}]*)\\}")
		_re_var = RegEx.create_from_string("\\{(\\w+)((?:\\.\\w+)*)\\}")
	var s := template
	if s.contains("#"):
		var out2 := ""
		var pos2 := 0
		for mm: RegExMatch in _re_num.search_all(s):
			out2 += s.substr(pos2, mm.get_start() - pos2)
			var forms2 := mm.get_string(2).split("|")
			var n := int(args.get(mm.get_string(1), 0))
			out2 += forms2[clampi(gram().plural_index(n), 0, forms2.size() - 1)]
			pos2 = mm.get_end()
		s = out2 + s.substr(pos2)
	if s.contains("|"):
		var out := ""
		var pos := 0
		for mm: RegExMatch in _re_pick.search_all(s):
			out += s.substr(pos, mm.get_start() - pos)
			var who: String
			var forms: PackedStringArray
			if mm.get_start(3) >= 0:
				who = "me"
				forms = mm.get_string(3).split("|")
			else:
				who = mm.get_string(1) if mm.get_string(1) != "" else "who"
				forms = mm.get_string(2).split("|")
			var gi := 0
			if args.has(who):
				gi = _gender(args[who])
			elif args.has(who + "_f"):
				gi = 1 if bool(args[who + "_f"]) else 0
			if gi == 2 and forms.size() < 3:
				gi = 0
			out += forms[clampi(gi, 0, forms.size() - 1)]
			pos = mm.get_end()
		s = out + s.substr(pos)
	if s.contains("{"):
		var out3 := ""
		var pos3 := 0
		for mm: RegExMatch in _re_var.search_all(s):
			var key := mm.get_string(1)
			out3 += s.substr(pos3, mm.get_start() - pos3)
			pos3 = mm.get_end()
			if not args.has(key):
				out3 += mm.get_string()       # метка без значения остаётся видна самотесту
				continue
			var mods := mm.get_string(2).split(".", false)
			var case := ""
			var up := 0
			for md: String in mods:
				if md == "cap":
					up = 1
				elif md == "low":
					up = -1
				else:
					case = md
			var r := render(args[key], case)
			if up > 0:
				r = gram().cap(r)
			elif up < 0 and not r.is_empty():
				r = r.left(1).to_lower() + r.substr(1)
			out3 += r
		s = out3 + s.substr(pos3)
	return s
