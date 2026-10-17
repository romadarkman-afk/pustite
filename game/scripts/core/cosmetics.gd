class_name Cosmetics
extends RefCounted
## Фонари и шапки для твоего жителя. Открываются победами, испытаниями и отношениями.
## На партию не влияют: Match и боты о них не знают, меняется только картинка.

## need: {"wins": n} — побед всего, {"daily": n} — пройденных испытаний дня, {"streak": n} — серия дней подряд.
const LANTERNS: Array[Dictionary] = [
	{"id": "classic", "need": {}, "glass": Color("ffcf6b"), "flame": Color(1, 0.95, 0.7), "light": Color(1.0, 0.8, 0.5), "shape": "box"},
	{"id": "copper", "need": {"wins": 1}, "glass": Color("f0a25e"), "flame": Color(1, 0.9, 0.6), "light": Color(1.0, 0.7, 0.4), "shape": "round"},
	{"id": "green", "need": {"wins": 3}, "glass": Color("9fe8a0"), "flame": Color(0.85, 1, 0.8), "light": Color(0.6, 1.0, 0.6), "shape": "box"},
	{"id": "paper", "need": {"daily": 1}, "glass": Color("ee6a55"), "flame": Color(1, 0.9, 0.7), "light": Color(1.0, 0.55, 0.45), "shape": "paper"},
	{"id": "frost", "need": {"wins": 10}, "glass": Color("a9d8ff"), "flame": Color(0.9, 0.97, 1), "light": Color(0.6, 0.8, 1.0), "shape": "round"},
	{"id": "ghost", "need": {"streak": 3}, "glass": Color("c9a8ff"), "flame": Color(0.95, 0.9, 1), "light": Color(0.75, 0.6, 1.0), "shape": "paper"},
]
const HATS: Array[Dictionary] = [
	{"id": "own", "need": {}, "head": -1},
	{"id": "top_hat", "need": {"wins": 2}, "head": LookDef.Head.TOP_HAT},
	{"id": "beret", "need": {"daily": 2}, "head": LookDef.Head.BERET},
	{"id": "straw", "need": {"wins": 5}, "head": LookDef.Head.STRAW},
	{"id": "ushanka", "need": {"wins": 7}, "head": LookDef.Head.USHANKA},
	{"id": "flower", "need": {"bond": 6}, "head": LookDef.Head.FLOWER_CROWN},
	{"id": "jester", "need": {"wins": 15}, "head": LookDef.Head.JESTER},
]
const BROOCHES: Array[Dictionary] = [
	{"id": "none", "need": {}},
	{"id": "sun", "need": {}},
	{"id": "bone", "need": {}},
	{"id": "seal", "need": {}},
]


static func item(kind: String, id: String) -> Dictionary:
	var items: Array[Dictionary] = LANTERNS if kind == "lantern" else (HATS if kind == "hat" else BROOCHES)
	for it: Dictionary in items:
		if it.id == id:
			return it
	return items[0]


## Сколько у игрока того, чем открываются вещи.
static func progress() -> Dictionary:
	return {"wins": int(Save.stats.get("wins", 0)), "daily": Save.daily_wins, "streak": Save.daily_best,
		"bond": Save.total_anchor_bond()}


static func is_open(it: Dictionary, prog: Dictionary = {}) -> bool:
	if prog.is_empty():
		prog = progress()
	# Венок, открытый по прежнему условию серии из пяти дней, остаётся доступен.
	if String(it.id) == "flower" and int(prog.get("streak", 0)) >= 5:
		return true
	for k: String in it.need:
		if int(prog.get(k, 0)) < int(it.need[k]):
			return false
	return true


## Что нужно, чтобы открыть: «3 победы».
static func need_text(it: Dictionary) -> String:
	for k: String in it.need:
		return L.t("cos.need_" + k, {"n": int(it.need[k])})
	return ""


static func title(kind: String, id: String) -> String:
	if kind == "brooch":
		var titles := {"none": ["Без значка", "No brooch"], "sun": ["Солнце", "Sun"],
			"bone": ["Кость", "Bone"], "seal": ["Печать", "Seal"]}
		var pair: Array = titles.get(id, titles.none)
		if StoryLoc.has("brooch"):
			return String((StoryLoc.get_v("brooch") as Array)[["none", "sun", "bone", "seal"].find(id) if titles.has(id) else 0])
		return pair[0] if L.code == "ru" else pair[1]
	return L.t("%s.%s" % [kind, id])


## Все открытые сейчас вещи: «lantern:copper».
static func open_ids(prog: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	for it: Dictionary in LANTERNS:
		if is_open(it, prog):
			out.append("lantern:" + String(it.id))
	for it: Dictionary in HATS:
		if is_open(it, prog):
			out.append("hat:" + String(it.id))
	for it: Dictionary in BROOCHES:
		if is_open(it, prog):
			out.append("brooch:" + String(it.id))
	return out


## Внешность игрока в выбранной шапке. Своя — как в книге внешностей.
static func dress(l: LookDef, hat_id: String) -> LookDef:
	var h: int = int(item("hat", hat_id).head)
	if h < 0 or l == null:
		return l
	var d := l.duplicate() as LookDef
	d.head = h as LookDef.Head
	return d


static func lantern(id: String) -> Dictionary:
	return item("lantern", id)
