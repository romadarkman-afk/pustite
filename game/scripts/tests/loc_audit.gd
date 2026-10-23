class_name LocAudit
extends RefCounted
## Проверки переводов поверх --loc (TASK-093, TASK-094).
##   1. Каждый ключ, написанный в коде как L.t("…"), L.arr("…"), L.pick("…"), есть в русском словаре (а значит, по
##      проверке комплектности, и в остальных девяти языках). Ключ, к которому дописывают хвост ("goal." + x), не проверяется.
##   2. Строка не языка en/ru не совпадает с английской, если в ней два слова и больше (метки {…} не считаются).
##   3. Каждый знак каждой строки каждого языка есть в шрифте или его запасных (Nunito, иероглифы, деванагари).
##      Строки берутся из словаря языка и из всех констант всех классов проекта, а не только из тех, что видел прогон.
##   4. Отчёт о самых длинных строках: сверху hi и de, по длине и по отношению к русской строке.
## Отчёт в файл: --loc --report=путь.md

const SKIP_DIRS: PackedStringArray = ["res://scripts/loc", "res://scripts/tests"]
const LONG_TOP := 12
const MIN_RU_LEN := 6   ## короче русской строки не сравниваем: «Да» и «Нет» дают случайные отношения


static func run(fails: PackedStringArray, report_path: String) -> int:
	var ok := 0
	var ru_d: Dictionary = L._load("ru").d()
	var en_d: Dictionary = L._load("en").d()

	# 1. ключи из кода
	var re_key := RegEx.create_from_string("\\bL\\.(?:t|arr|pick)\\(\\s*\"([A-Za-z0-9_.]+)\"\\s*[,)]")
	var bad := PackedStringArray()
	var scanned := 0
	var sources := _gd_files("res://scripts")
	for path: String in sources:
		var skip := false
		for d: String in SKIP_DIRS:
			skip = skip or path.begins_with(d + "/")
		if skip:
			continue
		for mm: RegExMatch in re_key.search_all(FileAccess.get_file_as_string(path)):
			scanned += 1
			var k := mm.get_string(1)
			if not ru_d.has(k):
				bad.append("%s: ключа «%s» нет в словаре" % [path.get_file(), k])
	ok += _ex(fails, bad.is_empty(), "ключи из кода (%d): %s" % [scanned, " / ".join(bad.slice(0, 6))])

	# 2. непереведённые строки
	var re_mark := RegEx.create_from_string("\\{[^}]*\\}|\\[[^\\]]*\\]")
	var untranslated_total := 0
	for code: String in L.LANGS:
		if code == "ru" or code == "en":
			continue
		var d: Dictionary = L._load(code).d()
		var same := PackedStringArray()
		for key: String in d:
			if not en_d.has(key) or key.begins_with("intent."):
				continue
			var a: Array = d[key] if d[key] is Array else [d[key]]
			var b: Array = en_d[key] if en_d[key] is Array else [en_d[key]]
			for i in range(mini(a.size(), b.size())):
				if not (a[i] is String) or not (b[i] is String) or a[i] != b[i]:
					continue
				var plain := re_mark.sub(String(a[i]), "", true).strip_edges()
				if plain.count(" ") >= 1 and plain.length() >= 8:
					same.append("%s[%d]" % [key, i])
		untranslated_total += same.size()
		ok += _ex(fails, same.is_empty(), "%s: %d строк совпадают с английскими: %s" % [code, same.size(), ", ".join(same.slice(0, 6))])

	# 3. знаки шрифта по всем строкам
	var chain := _font_chain()
	var strings_total := 0
	for code: String in L.LANGS:
		var strs := PackedStringArray()
		_walk(L._load(code).d(), strs, 0)
		var sl: Variant = StoryLoc.DATA.get(code, null)
		if sl != null:
			_walk(sl, strs, 0)
		strings_total += strs.size()
		var miss := _missing(strs, chain)
		ok += _ex(fails, miss.is_empty(), "%s: шрифт не рисует %d знаков из %d строк: %s" % [code, miss.length(), strs.size(), miss.left(40)])
	var consts := PackedStringArray()
	for cls: Dictionary in ProjectSettings.get_global_class_list():
		var path := String(cls.get("path", ""))
		if path.begins_with("res://scripts/tests/") or not path.ends_with(".gd"):
			continue
		var scr := load(path) as GDScript
		if scr == null:
			continue
		var map := scr.get_script_constant_map()
		for cname: String in map:
			_walk(map[cname], consts, 0)
	var miss_c := _missing(consts, chain)
	ok += _ex(fails, miss_c.is_empty(), "константы кода (%d строк): шрифт не рисует %d знаков: %s" % [consts.size(), miss_c.length(), miss_c.left(40)])
	var lit := PackedStringArray()
	var re_nonascii := RegEx.create_from_string("[^\\x00-\\x7F]")
	for path: String in sources:
		if path.begins_with("res://scripts/tests/"):
			continue
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code_part := _strip_comment(line)
			if re_nonascii.search(code_part) != null:
				lit.append(code_part)
	var miss_l := _missing(lit, chain)
	ok += _ex(fails, miss_l.is_empty(), "знаки в кодовых строках (%d): шрифт не рисует %d: %s" % [lit.size(), miss_l.length(), miss_l.left(40)])

	# 4. самые длинные строки
	var report := _longest_report(ru_d)
	print(report.split("## Подробно")[0].strip_edges())
	if not report_path.is_empty():
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f != null:
			f.store_string(report)
			f.close()
	print("LocAudit: ключей в коде %d, строк на языках %d, непереведённых %d" % [scanned, strings_total, untranslated_total])
	return ok


static func _ex(fails: PackedStringArray, cond: bool, msg: String) -> int:
	if cond:
		return 1
	fails.append(msg)
	return 0


static func _gd_files(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(root)
	if da == null:
		return out
	for f: String in da.get_files():
		if f.ends_with(".gd"):
			out.append(root + "/" + f)
	for sub: String in da.get_directories():
		out.append_array(_gd_files(root + "/" + sub))
	return out


static func _font_chain() -> Array[Font]:
	var base := ThemeFactory.font(650).base_font as FontFile
	var chain: Array[Font] = [base]
	for f: Font in base.fallbacks:
		chain.append(f)
	return chain


static func _missing(texts: PackedStringArray, chain: Array[Font]) -> String:
	var seen := {}
	var out := ""
	for t: String in texts:
		for i in range(t.length()):
			var ch := t.unicode_at(i)
			if seen.has(ch) or ch < 32 or ch == 0x200d or ch == 0x200c:
				continue
			seen[ch] = true
			var hit := false
			for f: Font in chain:
				if f.has_char(ch):
					hit = true
					break
			if not hit:
				out += char(ch)
	return out


## Все строки дерева словарей и массивов.
static func _walk(v: Variant, out: PackedStringArray, depth: int) -> void:
	if depth > 8:
		return
	if v is String or v is StringName:
		out.append(String(v))
	elif v is Array or v is PackedStringArray:
		for x: Variant in v:
			_walk(x, out, depth + 1)
	elif v is Dictionary:
		for k: Variant in v:
			if k is String:
				out.append(k)
			_walk(v[k], out, depth + 1)


## Строка кода без комментария: «#» после пробела или в начале; решётка внутри кавычек остаётся.
static func _strip_comment(line: String) -> String:
	var in_str := false
	var quote := ""
	var skip := false
	for i in range(line.length()):
		var ch := line[i]
		if skip:
			skip = false
		elif in_str:
			if ch == "\\":
				skip = true
			elif ch == quote:
				in_str = false
		elif ch == "\"" or ch == "'":
			in_str = true
			quote = ch
		elif ch == "#":
			return line.left(i)
	return line


static func _longest_report(ru_d: Dictionary) -> String:
	var out := "# Самые длинные строки\n\nСгенерировано `--loc --report=…`. Длина в знаках без меток. Для hi и de: топ по длине и по отношению к русской строке (русская не короче %d знаков).\n\n" % MIN_RU_LEN
	var detail := "\n## Подробно\n\n"
	var re_mark := RegEx.create_from_string("\\{[^}]*\\}")
	for code: String in ["hi", "de", "fr", "es", "pt", "tr", "vi", "en", "zh"]:
		var d: Dictionary = L._load(code).d()
		var rows: Array = []
		for key: String in d:
			if key in ["houses", "houses_mill", "houses_monastery", "houses_station", "names", "looks", "you", "someone"] or key.begins_with("intent."):
				continue
			if not ru_d.has(key) or d[key] is Dictionary:
				continue
			var a: Array = d[key] if d[key] is Array else [d[key]]
			var r: Array = ru_d[key] if ru_d[key] is Array else [ru_d[key]]
			for i in range(mini(a.size(), r.size())):
				var s := re_mark.sub(String(a[i]), "", true)
				var rs := re_mark.sub(String(r[i]), "", true)
				rows.append({"key": "%s[%d]" % [key, i] if a.size() > 1 else key, "n": s.length(), "ru": rs.length(), "text": String(a[i])})
		rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.n > y.n)
		var top_len := rows.slice(0, LONG_TOP)
		var ratio_rows: Array = rows.filter(func(x: Dictionary) -> bool: return x.ru >= MIN_RU_LEN and x.n >= 12)
		ratio_rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.n) / x.ru > float(y.n) / y.ru)
		var top_ratio := ratio_rows.slice(0, LONG_TOP)
		var longest: int = int(top_len[0].n) if not top_len.is_empty() else 0
		var worst: float = float(top_ratio[0].n) / float(top_ratio[0].ru) if not top_ratio.is_empty() else 0.0
		out += "- %s: самая длинная %d знаков, худшее отношение к русскому %.2f\n" % [code, longest, worst]
		if code != "hi" and code != "de":
			continue
		detail += "### %s, по длине\n\n| ключ | знаков | строка |\n|---|---|---|\n" % code
		for x: Dictionary in top_len:
			detail += "| %s | %d | %s |\n" % [x.key, x.n, String(x.text).replace("|", "/").left(90)]
		detail += "\n### %s, по отношению к русской\n\n| ключ | знаков | ru | отношение | строка |\n|---|---|---|---|---|\n" % code
		for x: Dictionary in top_ratio:
			detail += "| %s | %d | %d | %.2f | %s |\n" % [x.key, x.n, x.ru, float(x.n) / x.ru, String(x.text).replace("|", "/").left(60)]
		detail += "\n"
	return out + detail
