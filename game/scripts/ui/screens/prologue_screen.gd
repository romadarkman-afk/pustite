class_name PrologueScreen
extends Screen

var revealed := false
var _beat := 0
var _beat_title: Label
var _beat_text: Label
var _beat_card: Control
var _cast: VBoxContainer
var _go: Button
var _reveal_nodes: Array = []


func screen_id() -> String:
	return "prologue"


func is_busy() -> bool:
	return not revealed


func field_ratio() -> float:
	return 0.34


func title() -> String:
	return L.t("prologue.title")


func mood() -> Vector2:
	return Vector2(0.9, 0.9)


func build() -> void:
	_beat = 0
	_beat_card = W.panel(&"Sheet")
	_beat_card.custom_minimum_size.x = 0.0
	_beat_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var beat_box := W.vbox(16)
	beat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_beat_title = W.label("", &"Title")
	_beat_title.add_theme_font_size_override("font_size", ThemeFactory.fs(40))
	_beat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_beat_text = W.label("", &"Tale")
	_beat_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beat_box.add_child(_beat_title)
	beat_box.add_child(_beat_text)
	_beat_card.add_child(beat_box)
	body.add_child(_beat_card)
	_cast = W.vbox(12)
	_cast.visible = false
	body.add_child(_cast)
	_show_beat()
	var you := m.player()
	var pre := W.label(L.t("prologue.pre"), &"Small")
	_cast.add_child(pre)
	var arrival := W.panel(&"Card")
	arrival.name = "ArrivalStory"
	arrival.add_child(W.label(SocialContent.village_intro(m), &"Small"))
	_cast.add_child(arrival)
	var role := W.label(L.t("prologue.upyr" if you.is_upyr else "prologue.human"), &"Title")
	if you.is_upyr:
		role.add_theme_color_override("font_color", ThemeFactory.BLOOD)
	role.modulate.a = 0.0
	_cast.add_child(role)
	var story := W.label(
		L.t("prologue.upyr_text" if you.is_upyr else "prologue.human_text"),
		&"Tale")
	story.modulate.a = 0.0
	_cast.add_child(story)
	var role_l := W.label(_role_text(you), &"Hint")
	role_l.modulate.a = 0.0
	if role_l.text.is_empty():
		role_l.visible = false
	_cast.add_child(role_l)
	var case_card := W.panel(&"Card")
	case_card.name = "CaseFile"
	var case_text := W.vbox(4)
	case_text.add_child(W.label(SocialContent.case_title(m.case_id), &"Body"))
	case_text.add_child(W.label(SocialContent.case_hook(m.case_id), &"Small"))
	case_card.add_child(case_text)
	case_card.modulate.a = 0.0
	_cast.add_child(case_card)
	if m.rule != "":
		var dl := W.icon_line(MorningScreen.event_glyph(Challenge.night_event(m.rule)) if Challenge.night_event(m.rule) != Match.Event.NONE else "bell",
			L.t("daily.title") + ": " + Challenge.title(m.rule) + ". " + Challenge.text(m.rule), &"Hint")
		dl.name = "Daily"
		_cast.add_child(dl)
	var facts := W.label(L.t("prologue.facts", {"p": m.config.players, "u": m.config.monsters,
		"s": m.config.shelters, "c": m.config.capacity, "n": m.config.nights}), &"Small")
	facts.modulate.a = 0.0
	_cast.add_child(facts)
	if not Game.chapter.is_empty():
		_cast.add_child(goals_card(m, Game.chapter, {}))
	_cast.add_child(people_strip())
	_cast.add_child(W.label(SocialContent.narrative_ui("cast"), &"Speaker"))
	for v: Villager in m.villagers:
		if v.is_player:
			continue
		var card := W.panel(&"Card")
		card.name = "Cast_%d" % v.id
		var row := W.hbox(14)
		var portrait := TextureRect.new()
		var figure: VillagerFigure = Nav.village.crowd.figures.get(v.id) if Nav.village != null else null
		if figure != null:
			portrait.texture = VillagerFigure.folk_tex(figure.sprite_id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(76, 140)
		row.add_child(portrait)
		var info := W.vbox(5)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(W.label(v.name, &"Speaker"))
		info.add_child(W.label(SocialContent.person_title(v), &"Small"))
		info.add_child(W.label(SocialContent.story(v.story_id, v), &"Small"))
		var bond := SocialContent.bond_text(v, m)
		if not bond.is_empty():
			info.add_child(W.label(bond, &"Hint"))
		# память кампании (TASK-002): последнее, что было между вами
		if not Game.chapter.is_empty() and v.guest_id.is_empty():
			var mem := Campaign.memory_lines(v.story_id, 1)
			if not mem.is_empty():
				var ml := W.label(mem[0], &"Hint")
				ml.name = "Memory"
				info.add_child(ml)
		row.add_child(info)
		card.add_child(row)
		_cast.add_child(card)

	_go = W.button((String((StoryLoc.get_v("misc") as Array)[2]) if StoryLoc.has("misc") else ("Дальше" if L.code == "ru" else "Continue")))
	_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go.pressed.connect(_advance)
	footer.add_child(_go)
	_reveal_nodes = [role, story, role_l, case_card, facts]


func _show_beat() -> void:
	if not Game.chapter.is_empty() and _beat == 0:
		var tex := Campaign.art(String(Game.chapter.id))
		if tex != null and _beat_card.get_node_or_null("Art") == null:
			var art := TextureRect.new()
			art.name = "Art"
			art.texture = tex
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.custom_minimum_size = Vector2(0, 320)
			(_beat_card.get_child(0) as Control).add_child(art)
			(_beat_card.get_child(0) as Control).move_child(art, 0)
	var art_node := _beat_card.find_child("Art", true, false) as Control
	if art_node != null:
		art_node.visible = _beat < 2          # страницы откровений длиннее: картинка главы уступает место тексту
	_show_narrator()
	var beats := _beats()
	_beat_title.text = String(beats[_beat][0])
	_beat_text.text = String(beats[_beat][1])
	Juice.pop_in(_beat_card, 0.06)


## Рассказчик главы: на второй странице сцены рядом с текстом его портрет и имя.
## Акт III — брат Игнат из монастыря, акт IV — смотритель станции.
const NARRATORS := {2: ["npc.miller.name", ""], 3: ["narr.ignat", "res://assets/folk/npc_abbot.png"], 4: ["narr.keeper", "res://assets/folk/npc_stationmaster.png"]}


func _show_narrator() -> void:
	var old := _beat_card.find_child("Narrator", true, false)
	var act := int(Game.chapter.get("act", 0)) if not Game.chapter.is_empty() else 0
	var on := _beat == 1 and NARRATORS.has(act)
	if old != null:
		(old as Control).visible = on
		return
	if not on:
		return
	var n: Array = NARRATORS[act]
	var row := W.hbox(14)
	row.name = "Narrator"
	var pic := TextureRect.new()
	pic.texture = load(String(n[1]) if not String(n[1]).is_empty() else Npc.sprite_path("miller")) as Texture2D   # мельник: своя картинка или запасная
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(84, 154)
	row.add_child(pic)
	var name_l := W.label(L.t(String(n[0])), &"Speaker")
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var box := _beat_card.get_child(0) as Control
	box.add_child(row)
	box.move_child(row, _beat_title.get_index() + 1)


## Сцена главы: две страницы текста и картинка главы, если она есть.
## После двух страниц — откровения главы (TASK-005): кто их расскажет, зависит от того, кто жив.
static func chapter_beats(id: String, mm: Match = null) -> Array:
	var out := [[L.t("camp.%s.beat1_title" % id), L.t("camp.%s.beat1" % id)],
		[L.t("camp.%s.beat2_title" % id), L.t("camp.%s.beat2" % id)]]
	for rid: String in Revelations.for_chapter(id):
		out.append(Revelations.beat(rid, mm))
	return out


func _beats() -> Array:
	return SocialContent.opening_beats(m) if Game.chapter.is_empty() else chapter_beats(String(Game.chapter.id), m)


## Цели главы: основная и две за звёзды. result — итог (Campaign.finish), до партии пусто.
static func goals_card(mm: Match, ch: Dictionary, result: Dictionary) -> PanelContainer:
	var card := W.panel(&"Card")
	card.name = "Goals"
	var box := W.vbox(6)
	card.add_child(box)
	box.add_child(W.label(L.t("camp.goals"), &"Speaker"))
	var list: Array = result.get("goals", [])
	if list.is_empty():
		var keys: Array = [String(ch.get("goal", ""))]
		keys.append_array(ch.get("extra", []))
		for k: String in keys:
			list.append({"key": k, "done": false})
	var i := 0
	for g: Dictionary in list:
		var mark := ""
		if not result.is_empty():
			mark = ("✓ " if bool(g.done) else "✗ ")
		var line := W.icon_line("street_ok" if i == 0 else "info", mark + L.t("goal." + String(g.key)) + ("" if i == 0 else " ★"),
			&"Body" if i == 0 else &"Small")
		line.name = "Goal_" + String(g.key)
		box.add_child(line)
		i += 1
	return card


func _advance() -> void:
	var last := _beats().size() - 1
	if _beat < last:
		_beat += 1
		if _beat == 1:
			Sfx.play(&"knock")
			Juice.haptic(Juice.Haptic.NIGHT)
		_show_beat()
	elif _beat == last:
		_beat = last + 1
		_beat_card.visible = false
		_cast.visible = true
		var changed := false
		for resident: Villager in m.villagers:
			if not resident.is_player:
				changed = Save.remember_story(Progress.story_key(resident), 0, false) or changed
		if changed:
			Save.flush()
		_go.text = L.t("prologue.go")
		_go.disabled = true
		_reveal(_reveal_nodes)
	elif revealed:
		commit(Intent.CONTINUE)


func _role_text(you: Villager) -> String:
	match you.role:
		Match.Role.ELDER:
			return L.t("prologue.elder")
		Match.Role.HEALER:
			return L.t("prologue.healer")
		Match.Role.HEADMAN:
			return L.t("prologue.headman")
	return ""


func _reveal(nodes: Array) -> void:
	await Juice.wait(0.9)
	Juice.haptic(Juice.Haptic.NIGHT)
	Sfx.play(&"reveal")
	for n: Control in nodes:
		if not is_instance_valid(n):
			return
		if Juice.instant:
			n.modulate.a = 1.0
		else:
			Juice.tween().tween_property(n, "modulate:a", 1.0, 0.45)
		await Juice.wait(0.35)
	revealed = true
	if is_instance_valid(_go):
		_go.disabled = false


func ambience() -> StringName:
	return &"amb_dusk"


func music() -> StringName:
	return &""
