class_name Progress
extends RefCounted
## Опыт, уровень посёлка, Книга посёлка и достижения (Task 62).
## Опыт даётся за партию: за прожитые ночи, победу, верный голос, открытую своим дверь,
## осмотр у двери, дилеммы и звёзды главы. Уровень — титул игрока в посёлке.
## Книга хранит судьбы жителей, найденные концовки и достижения; пустые страницы подсказывают, что ещё есть.

const LEVELS: Array[int] = [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200, 4000, 5000]
const TITLES := 6             ## lvl.t1 … lvl.t6: чужак → хранитель посёлка

const XP_GAME := 20
const XP_NIGHT := 10
const XP_WIN := 30
const XP_VOTE := 10
const XP_DOOR := 5
const XP_INSPECT := 5
const XP_DILEMMA := 10
const XP_STAR := 15
const XP_STORY := 8
const XP_STORY_MAX := 4
const XP_BOND := 20

const ACHIEVEMENTS: PackedStringArray = ["night1", "open_door", "closed_door", "instinct", "mistake", "mourning",
	"last_one", "debtor", "oil", "forest_call", "guest_secret", "three_stars", "act1", "act2", "dark_side", "whole_family",
	"act3", "act4", "saved_bond"]
const ENDINGS: PackedStringArray = ["people", "upyri", "act1_all", "act1_some", "act1_none", "act2_all", "act2_some", "act2_none",
	"act3_all", "act3_some", "act3_none",
	"act4_all", "act4_some", "act4_none",
	"final_shore", "final_upyr", "final_many", "final_few"]


static func level_of(xp: int) -> int:
	var lv := 1
	for i in range(LEVELS.size()):
		if xp >= LEVELS[i]:
			lv = i + 1
	return lv


## Сколько опыта до следующего уровня: [набрано на этом уровне, нужно на уровень]. Последний уровень — [1, 1].
static func level_span(xp: int) -> Vector2i:
	var lv := level_of(xp)
	if lv >= LEVELS.size():
		return Vector2i(1, 1)
	return Vector2i(xp - LEVELS[lv - 1], LEVELS[lv] - LEVELS[lv - 1])


static func title(lv: int) -> String:
	return L.t("lvl.t%d" % clampi(1 + (lv - 1) / 2, 1, TITLES))


## Опыт за партию: [[ключ, сколько, число раз], …] — то, что показывает итог.
static func xp_lines(m: Match, chapter_res: Dictionary) -> Array:
	var out: Array = [["xp.game", XP_GAME, 1]]
	var you := m.player()
	var nights := m.day if you.alive else _death_day(m)
	if nights > 0:
		out.append(["xp.nights", XP_NIGHT * nights, nights])
	var won := (m.winner == Match.Team.PEOPLE) != you.is_upyr
	if won:
		out.append(["xp.win", XP_WIN, 1])
	var votes := 0
	for rec: Dictionary in m.player_votes:
		var t: Villager = rec.get("who")
		if t != null and t.is_upyr != you.is_upyr:
			votes += 1
	if votes > 0:
		out.append(["xp.vote", XP_VOTE * votes, votes])
	var doors := 0
	for rec: Dictionary in m.player_admits:
		var g: Villager = rec.get("who")
		if g != null and not bool(rec.get("mimic", false)) and not g.is_upyr:
			doors += 1
	if doors > 0 and not you.is_upyr:
		out.append(["xp.door", XP_DOOR * doors, doors])
	if not m.door_inspections.is_empty():
		out.append(["xp.inspect", XP_INSPECT * m.door_inspections.size(), m.door_inspections.size()])
	if not m.dilemmas.is_empty():
		out.append(["xp.dilemma", XP_DILEMMA * m.dilemmas.size(), m.dilemmas.size()])
	if bool(chapter_res.get("passed", false)):
		out.append(["xp.stars", XP_STAR * int(chapter_res.stars), int(chapter_res.stars)])
	var story_pages := mini(m.story_pages_found.size(), XP_STORY_MAX)
	if story_pages > 0:
		out.append(["xp.story", XP_STORY * story_pages, story_pages])
	if not saved_bond_pair(m).is_empty():
		out.append(["xp.bond", XP_BOND, 1])
	return out


## Пара, которую игрок помог сохранить: впущенный человек и его близкий дожили до конца.
static func saved_bond_pair(m: Match) -> Array[Villager]:
	if m.player().is_upyr:
		return []
	for rec: Dictionary in m.player_admits:
		var guest: Villager = rec.get("who")
		if guest == null or bool(rec.get("mimic", false)) or guest.is_upyr or not guest.alive or guest.exiled:
			continue
		for kin: Villager in m.kin_of(guest):
			if not kin.is_player and not kin.is_upyr and not kin.exiled:
				return [guest, kin]
	return []


static func _death_day(m: Match) -> int:
	if m.player().exiled:
		return maxi(0, m.player().exiled_day - 1)
	for rec: Dictionary in m.history:
		if (rec.get("dead", []) as Array).has(m.player().id):
			return maxi(0, int(rec.day) - 1)
	return maxi(0, m.day - 1)


## Какие достижения дала эта партия.
static func earned(m: Match, chapter_res: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var you := m.player()
	var won := (m.winner == Match.Team.PEOPLE) != you.is_upyr
	if m.day >= 2 and (you.alive or _death_day(m) >= 1):
		out.append("night1")
	if m.player_admits.size() >= 3:
		out.append("open_door")
	if m.player_refused_all > 0 and you.alive:
		out.append("closed_door")
	for rec: Dictionary in m.player_votes:
		var t: Villager = rec.get("who")
		if t != null and t.exiled and t.exiled_day == int(rec.day):
			out.append("instinct" if t.is_upyr else "mistake")
	if m.griefs > 0:
		out.append("mourning")
	if not saved_bond_pair(m).is_empty():
		out.append("saved_bond")
	if m.winner == Match.Team.PEOPLE and you.alive and not you.is_upyr and m.humans_alive() <= 2:
		out.append("last_one")
	for d: Dictionary in m.dilemmas:
		if bool(d.get("admitted", false)) and String(d.kind) == "refuser":
			out.append("debtor")
		if bool(d.get("admitted", false)) and String(d.kind) == "oil":
			out.append("oil")
	if m.forest_call_day >= 0:
		out.append("forest_call")
	for v: Villager in m.villagers:
		if not v.guest_id.is_empty() and m.day >= Guests.REVEAL_DAY:
			out.append("guest_secret")
			break
	if bool(chapter_res.get("passed", false)) and int(chapter_res.get("stars", 0)) >= 3:
		out.append("three_stars")
	if Save.campaign_stars.has("a1c3"):
		out.append("act1")
	if Save.campaign_stars.has("a2c3"):
		out.append("act2")
	if Save.campaign_stars.has("a3c3"):
		out.append("act3")
	if Save.campaign_stars.has("a4c3"):
		out.append("act4")
	if you.is_upyr and won:
		out.append("dark_side")
	for v: Villager in m.villagers:
		var kin := m.get_villager(v.partner_id if v.partner_id >= 0 else v.family_id)
		if kin != null and not v.is_player and not v.alive and not kin.alive and not v.exiled and not kin.exiled:
			out.append("whole_family")
			break
	var uniq := PackedStringArray()
	for a: String in out:
		if not uniq.has(a):
			uniq.append(a)
	return uniq


## Записать партию: опыт, книга, концовки, достижения. Возвращает то, что показать в итоге.
static func record(m: Match, chapter_res: Dictionary) -> Dictionary:
	var lines := xp_lines(m, chapter_res)
	var gained := 0
	for l: Array in lines:
		gained += int(l[1])
	var before := Save.xp
	var lv_before := level_of(before)
	var fates: Array = []
	for v: Villager in m.villagers:
		if v.is_player:
			continue
		var key := ("g" + v.guest_id) if not v.guest_id.is_empty() else ("n%d" % v.story_id)
		fates.append([key, not v.alive and not v.exiled, v.is_upyr, v.name])
	var ends := PackedStringArray(["people" if m.winner == Match.Team.PEOPLE else "upyri"])
	var cid := String(chapter_res.get("id", ""))
	if bool(chapter_res.get("passed", false)) and Campaign.last_of_act(cid):
		ends.append(Campaign.act_ending_id(int(Campaign.chapter(cid).get("act", 1))))
	var new_ach := PackedStringArray()
	for a: String in earned(m, chapter_res):
		if not Save.achievements.has(a):
			new_ach.append(a)
	Save.record_progress(gained, fates, ends, new_ach)
	return {"lines": lines, "gained": gained, "before": before, "after": Save.xp,
		"level_before": lv_before, "level_after": level_of(Save.xp), "new_ach": new_ach}


## Запись книги о жителе: [встречали, погиб, был упырём]; [0,0,0] — страница пустая.
static func book_entry(key: String) -> PackedInt32Array:
	var parts := String(Save.book.get(key, "0,0,0")).split(",")
	var out := PackedInt32Array([0, 0, 0])
	for i in range(mini(3, parts.size())):
		out[i] = int(parts[i])
	return out


## Все жители, которые могут встретиться: местные этого языка и гости. [ключ, имя]
static func book_people() -> Array:
	var out: Array = []
	var names := L.names()
	for i in range(names.size()):
		var key := "n%d" % i
		var remembered := String(Save.book.get("name:%s:%s" % [key, L.code], ""))
		out.append([key, remembered if not remembered.is_empty() else String(names[i][0])])
	for g: String in Guests.BOOK_IDS:
		out.append(["g" + g, Guests.name_of(g)])
	return out


static func story_key(v: Villager) -> String:
	return "g" + v.guest_id if not v.guest_id.is_empty() else "n%d" % v.story_id
