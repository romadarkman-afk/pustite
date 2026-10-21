class_name Scenes
extends RefCounted
## Сцены кампании (TASK-011–014) как данные для ScenePlayer. Тексты — ключи sc.* и scene.* во всех языках,
## сцены утраты — GriefReactions. Сценарий главы «Стук» с раскадровкой: docs/scenes/a1c1.md.
##
## Кадр: {"art": путь, "portrait": житель, "zoom": [от, до], "light": night | dusk | dawn | warm | day,
##        "weather": "" | fog | rain, "lines": [{"who", "text", "pause"}], "sound": [{"at", "do", "id", "vol"}]}

const ART := "res://assets/scenes/%s.jpg"


static func art(name: String) -> String:
	var exact := ART % name
	if ResourceLoader.exists(exact):
		return exact
	var missing_art := {
		"a3c1": "res://assets/scenes/a3c1.png",
		"a3c2": "res://assets/scenes/a3c2.png",
		"a3c3": "res://assets/scenes/a3c3.png",
		"a4c1": "res://assets/scenes/a4c1.png",
		"a4c2": "res://assets/scenes/a4c2.png",
		"a4c3": "res://assets/scenes/a4c3.png",
		"final_door": "res://assets/scenes/final_door.png",
		"final_train": "res://assets/scenes/final_train.png",
	}
	if missing_art.has(name):
		return String(missing_art[name])
	if name.begins_with("grief_"):
		return "res://assets/scenes/end_people.jpg"
	return exact


## Сцена 1 главы «Стук»: река, зов с того берега, перевозчица гасит фонарь, стук в дверь.
## В конце выбор: отозваться на зов или промолчать. Отозвался — перевозчица это запомнит.
static func river(m: Match) -> Dictionary:
	var ferry := _anchor(m, 0)
	var ferry_name := ferry.name if ferry != null else String(L.names()[0][0])
	var me := Save.player_display_name()
	return {
		"id": "a1c1_river",
		"frames": [
			{"art": art("a1c1"), "zoom": [1.0, 1.08], "light": "dusk", "weather": "fog",
			 "lines": [{"text": L.t("sc.river.1")}],
			 "sound": [{"at": 0.0, "do": "silence", "fade": 0.4},
				{"at": 0.2, "do": "amb", "id": "amb_river", "fade": 1.0}]},
			{"art": art("river"), "zoom": [1.04, 1.12], "light": "dusk", "weather": "fog",
			 "lines": [{"who": L.t("sc.river.voice"), "text": L.t("sc.river.2", {"name": me}), "pause": 0.6}],
			 "sound": [{"at": 0.8, "do": "play", "id": "call_far", "vol": -6.0}]},
			{"portrait": ferry, "light": "night", "weather": "fog",
			 "lines": [{"who": ferry_name, "text": L.t("sc.river.3", {"me": ferry if ferry != null else m.player()})}]},
		],
		"choice": {"prompt": L.t("sc.river.ask"), "options": [
			{"id": "silent", "text": L.t("sc.river.c_silent")}, {"id": "answer", "text": L.t("sc.river.c_answer")}]},
		"restore_sound": false,
	}


## Сразу после выбора у реки: темнота и стук. Длинный звук тишины перед первым ударом.
static func first_knock(answered: bool) -> Dictionary:
	return {
		"id": "a1c1_knock",
		"frames": [
			{"art": art("door_inside_night"), "zoom": [1.0, 1.06], "light": "night",
			 "lines": [{"text": L.t("sc.river.4" if not answered else "sc.river.4b")}, {"text": L.t("sc.river.5"), "hold": 1.6}],
			 "sound": [{"at": 0.0, "do": "silence", "fade": 0.6}, {"at": 0.4, "do": "amb", "id": "amb_night", "fade": 1.5},
				{"at": 2.4, "do": "play", "id": "knock", "vol": -2.0}]},
		],
	}


## Сцена 3 главы «Стук»: первое утро. Три исхода первой ночи — три разных утра (TASK-013).
## admit — впустил человека: союзник; close — впустил того, кто ночью вставал (упырь или человек);
## refuse — не открыл: следы на снегу и тот, кому не открыли.
static func first_morning(m: Match) -> Dictionary:
	var kind := first_night_outcome(m)
	var who := m.get_villager(int(kind.who))
	var frames: Array = []
	match String(kind.kind):
		"admit":
			frames = [
				{"portrait": who, "light": "dawn", "lines": [{"text": L.t("sc.m1.admit.1", {"who": who})}],
				 "sound": [{"at": 0.0, "do": "amb", "id": "amb_dusk"}]},
				{"portrait": who, "light": "warm", "lines": [{"who": who.name, "text": L.t("sc.m1.admit.2", {"me": who})}]},
			]
		"close":
			frames = [
				{"art": art("door_inside_night"), "light": "night", "lines": [{"text": L.t("sc.m1.close.1")}],
				 "sound": [{"at": 0.0, "do": "silence"}, {"at": 0.3, "do": "play", "id": "floorboard", "vol": -3.0}]},
				{"art": art("door_inside_night"), "light": "night", "lines": [{"text": L.t("sc.m1.close.2")}],
				 "sound": [{"at": 0.4, "do": "play", "id": "gasp", "vol": -10.0}, {"at": 1.4, "do": "play", "id": "floorboard", "vol": -8.0}]},
				{"portrait": who, "light": "dawn", "lines": [{"text": L.t("sc.m1.close.3", {"who": who})}]},
			]
		_:
			var lines: Array = [{"text": L.t("sc.m1.refuse.1")}]
			frames = [{"light": "dawn", "lines": lines, "sound": [{"at": 0.0, "do": "silence"}, {"at": 0.5, "do": "play", "id": "creak", "vol": -8.0}]}]
			if who != null:
				if who.alive:
					frames.append({"portrait": who, "light": "dawn", "lines": [{"who": who.name, "text": L.t("sc.m1.refuse.2", {"me": who})}]})
				else:
					frames.append({"light": "dawn", "lines": [{"text": L.t("sc.m1.refuse.3", {"who": who})}]})
	return {"id": "a1c1_morning_" + String(kind.kind), "frames": frames}


## Чем кончилась первая ночь у двери игрока: {"kind": admit | close | refuse, "who": id}.
## close бывает, когда впустили упыря, и изредка с человеком: по одной ночи упыря не узнать.
static func first_night_outcome(m: Match) -> Dictionary:
	var admitted := m.world.last(WorldLog.Kind.ADMIT, 0, -1, 1)
	if admitted != null and not bool(admitted.info.get("mimic", false)):
		var g := m.get_villager(admitted.target)
		var noise := RandomNumberGenerator.new()
		noise.seed = hash("close:%d:%d" % [g.id, m.case_id])
		var close := g.is_upyr or noise.randf() < 0.25
		return {"kind": "close" if close else "admit", "who": g.id}
	var refused := m.world.last(WorldLog.Kind.REFUSE, 0, -1, 1)
	return {"kind": "refuse", "who": refused.target if refused != null else -1}


## «Имя на доске» (TASK-019): глава «Прощание», утро второго дня. Рассказчик — Лида, без неё Рита,
## без обеих игрок находит доску сам. В конце три ответа: признаться, отрицать, промолчать.
static func board(m: Match) -> Dictionary:
	var present: Array = []
	for v: Villager in m.alive_bots():
		if v.guest_id.is_empty():
			present.append(v.story_id)
	var src := Revelations.source("board_name", present)
	var teller := _anchor(m, int(src.who)) if int(src.who) >= 0 else null
	var lines: Array = []
	if int(src.lost) >= 0:
		lines.append({"text": L.t("rev.instead", {"lost": Revelations._person(int(src.lost), null)})})
	var name := Save.player_name
	var carved := L.t("sc.board.2", {"name": name}) if not name.is_empty() else L.t("sc.board.2_noname")
	var frames: Array = []
	if teller != null:
		lines.append({"who": teller.name, "text": L.t("sc.board.1", {"me": teller})})
		frames.append({"portrait": teller, "light": "dawn", "lines": lines, "sound": [{"at": 0.0, "do": "silence"}]})
		frames.append({"art": art("a1c3"), "light": "dawn", "lines": [{"text": carved}], "sound": [{"at": 0.4, "do": "play", "id": "creak", "vol": -6.0}]})
		frames.append({"portrait": teller, "light": "night", "lines": [{"who": teller.name, "text": L.t("sc.board.3", {"me": teller})}]})
	else:
		lines.append({"text": L.t("sc.board.alone")})
		frames.append({"art": art("a1c3"), "light": "dawn", "lines": lines})
		frames.append({"art": art("a1c3"), "light": "dawn", "lines": [{"text": carved}], "sound": [{"at": 0.4, "do": "play", "id": "creak", "vol": -6.0}]})
	return {"id": "a1c3_board", "teller": teller.id if teller != null else -1, "frames": frames,
		"choice": {"prompt": L.t("sc.board.ask"), "options": [
			{"id": "confess", "text": L.t("sc.board.c_confess")}, {"id": "deny", "text": L.t("sc.board.c_deny")},
			{"id": "silent", "text": L.t("sc.board.c_silent")}]}}


## Хозяин места в сцене: портрет-картинка вместо жителя.
static func npc_frame(id: String, text: String, light: String = "dawn") -> Dictionary:
	return {"portrait": Npc.sprite_path(id), "light": light, "lines": [{"who": Npc.display_name(id), "text": text}]}


## «Чужаки» (TASK-023): утро после первой ночи. Свежую могилу находит Тимур, без него Миша, без обоих
## любой местный. В могиле нож охотницы, если она в составе (по деревне ходит то, что заняло её место),
## иначе чужой путник. Деревня сразу винит гостей.
static func grave(m: Match) -> Dictionary:
	var finder: Villager = null
	for idx: int in [1, 8]:
		var v := _anchor(m, idx)
		if v != null and v.alive:
			finder = v
			break
	if finder == null:
		for v: Villager in m.alive_bots():
			if v.guest_id.is_empty():
				finder = v
				break
	var hunter := _anchor(m, 9)
	var frames: Array = []
	var first := "sc.grave.1" if finder != null and finder.story_id == 1 else "sc.grave.1_other"
	if finder != null:
		frames.append({"portrait": finder, "light": "dawn", "weather": "rain",
			"lines": [{"who": finder.name, "text": L.t(first, {"me": finder})}],
			"sound": [{"at": 0.0, "do": "silence"}, {"at": 0.5, "do": "play", "id": "hammer", "vol": -10.0}]})
	var found := L.t("sc.grave.knife", {"who": hunter}) if hunter != null and hunter.alive else L.t("sc.grave.stranger")
	frames.append({"art": art("a2c2"), "light": "dawn", "weather": "rain", "lines": [{"text": found}]})
	return {"id": "a2c2_grave", "finder": finder.id if finder != null else -1,
		"hunter": hunter.id if hunter != null and hunter.alive else -1, "frames": frames}


## «Половодье» (TASK-024): утро после первой ночи. Мельник: вода к вечеру будет у порога, лодка одна.
## Игрок выбирает, какой из низких домов она спасёт; другой заливает до конца главы.
static func flood(m: Match) -> Dictionary:
	var opts: Array = []
	for h: int in m.low_houses():
		opts.append({"id": "h%d" % h, "text": L.t("sc.flood.c_house", {"house": m.house_name(h)})})
	return {"id": "a2c3_flood", "frames": [
		{"art": art("a2c3"), "light": "dawn", "weather": "rain", "lines": [{"text": L.t("sc.flood.1")}],
		 "sound": [{"at": 0.0, "do": "amb", "id": "amb_river"}]},
		npc_frame("miller", L.t("sc.flood.2"))],
		"choice": {"prompt": L.t("sc.flood.ask"), "options": opts}}


## Тайна мельника (TASK-022): глава «Половодье», утро после второй ночи. Нашёл достаточно — спрашиваешь сам,
## нет — мельник рассказывает сам. Решение: рассказать беженцам или промолчать за его помощь.
static func miller_secret(m: Match) -> Dictionary:
	var known := Campaign.miller_clues() + Campaign.miller_records(m).size() >= Campaign.MILLER_KNOWN
	var frames: Array = [
		{"art": art("a2c3"), "light": "night", "lines": [{"text": L.t("sc.miller.1_known" if known else "sc.miller.1")}],
		 "sound": [{"at": 0.0, "do": "silence"}, {"at": 0.6, "do": "play", "id": "latch", "vol": -6.0}]},
		npc_frame("miller", L.t("sc.miller.2"), "night"),
		npc_frame("miller", L.t("sc.miller.3"), "night"),
	]
	return {"id": "a2c3_miller", "frames": frames, "choice": {"prompt": L.t("sc.miller.ask"), "options": [
		{"id": "tell", "text": L.t("sc.miller.c_tell")}, {"id": "keep", "text": L.t("sc.miller.c_keep")}]}}


## «Колокол» (TASK-028): утро после первой ночи. Анфиса показывает вторую книгу — зачёркнутые имена.
## Среди них дочь мельника и имя игрока: лодка, мельник и доска — одна история. Если загадки актов I–II
## не разгаданы, Анфиса договаривает ответ сама.
static func crossed_book(m: Match) -> Dictionary:
	var name := Save.player_name
	var frames: Array = [
		npc_frame("anfisa", L.t("sc.crossed.1"), "night"),
		{"art": art("a3c2"), "light": "night", "lines": [{"text": L.t("sc.crossed.2", {"name": name}) if not name.is_empty() else L.t("sc.crossed.2_noname")}],
		 "sound": [{"at": 0.0, "do": "silence"}, {"at": 0.5, "do": "play", "id": "creak", "vol": -8.0}]},
		npc_frame("anfisa", L.t("sc.crossed.3"), "night"),
	]
	var told: Array = []
	if Campaign.boat_clues() < Campaign.BOAT_SOLVED:
		told.append({"who": Npc.display_name("anfisa"), "text": L.t("sc.crossed.boat")})
	if Campaign.miller_choice().is_empty():
		told.append({"who": Npc.display_name("anfisa"), "text": L.t("sc.crossed.miller")})
	if Campaign.board_choice().is_empty():
		told.append({"who": Npc.display_name("anfisa"), "text": L.t("sc.crossed.board")})
	if not told.is_empty():
		frames.append({"portrait": Npc.sprite_path("anfisa"), "light": "night", "lines": told})
	return {"id": "a3c2_crossed", "told": told.size(), "frames": frames}


## «Крипта» (TASK-029): утро после первой ночи. Ответ на главный вопрос: упыри приходят к тем,
## кто их помнит и оплакивает, и просятся их голосом. Игрока звали с того берега — его тоже оплакивали.
static func crypt(m: Match) -> Dictionary:
	return {"id": "a3c3_crypt", "frames": [
		{"art": art("a3c3"), "light": "night", "lines": [{"text": L.t("sc.crypt.1"), "hold": 1.2}],
		 "sound": [{"at": 0.0, "do": "silence", "fade": 0.6}, {"at": 0.8, "do": "play", "id": "breath", "vol": -12.0}]},
		{"art": art("a3c3"), "light": "night", "lines": [{"text": L.t("sc.crypt.2")}, {"text": L.t("sc.crypt.3")}]},
		npc_frame("ignat", L.t("sc.crypt.ignat"), "night"),
	]}


## Суд Игната (TASK-029): утро после второй ночи. Исход только по журналу кампании и главы:
## кто помнит добро игрока, защищает, кто помнит зло — обвиняет. Пришедших слышно голосом, остальных — через других.
const TRIAL_SHOWN := 2


static func trial(m: Match) -> Dictionary:
	var t := Campaign.trial(m)
	var frames: Array = [npc_frame("ignat", L.t("sc.trial.open"), "warm")]
	for side: String in ["def", "acc"]:
		var shown := 0
		for rec: Dictionary in t[side]:
			if shown >= TRIAL_SHOWN:
				break
			var v := _anchor(m, int(rec.who))
			var key := "trial.%s.%s" % [side, String(rec.kind)]
			if v != null and v.alive:
				frames.append({"portrait": v, "light": "warm", "lines": [{"who": v.name, "text": L.t(key, {"me": v})}]})
			else:
				var p := Revelations._person(int(rec.who), m)
				frames.append({"light": "warm", "lines": [{"text": L.t("sc.trial.relay", {"who": p, "text": L.t(key, {"me": p})})}]})
			shown += 1
	if t.def.is_empty() and t.acc.is_empty():
		frames.append({"light": "warm", "lines": [{"text": L.t("sc.trial.nobody")}]})
	frames.append(npc_frame("ignat", L.t("sc.trial.acquit" if bool(t.acquit) else "sc.trial.convict"), "warm"))
	return {"id": "a3c3_trial", "acquit": bool(t.acquit), "defenders": t.def.size(), "accusers": t.acc.size(), "frames": frames}


## «Последний поезд» (TASK-034): утро после второй ночи. Смотритель показывает список: одна подпись — рука союзника.
## Человек вписал упыря из страха, упырь вписал себя: весь акт он только играл друга. Выдать или прикрыть.
static func betrayal(m: Match, ally: Villager) -> Dictionary:
	var frames: Array = [
		{"art": art("a4c3"), "light": "dawn", "weather": "fog", "lines": [{"text": L.t("sc.betray.1")}],
		 "sound": [{"at": 0.0, "do": "silence"}, {"at": 0.4, "do": "play", "id": "typewriter", "vol": -8.0}]},
		npc_frame("keeper", L.t("sc.betray.2", {"who": ally}), "dawn"),
	]
	var key := "sc.betray.upyr" if ally.is_upyr else ("sc.betray.clerk" if ally.guest_id == "clerk" else "sc.betray.human")
	frames.append({"portrait": ally, "light": "dawn", "weather": "fog", "lines": [{"who": ally.name, "text": L.t(key, {"me": ally})}],
		"sound": [{"at": 1.0, "do": "play", "id": "whistle", "vol": -14.0}]})
	return {"id": "a4c3_betray", "ally": ally.id, "frames": frames, "choice": {"prompt": L.t("sc.betray.ask", {"who": ally}),
		"options": [{"id": "expose", "text": L.t("sc.betray.c_expose")}, {"id": "cover", "text": L.t("sc.betray.c_cover")}]}}


## Финал кампании (TASK-035): последняя ночь. Зовут с того берега голосом того, кого игрок потерял раньше всех.
## Никого не потерял — своим собственным голосом, как на доске у часовни. Открыть и уйти или сесть на поезд.
static func final_door() -> Dictionary:
	var lost := Campaign.first_lost()
	var voice := Revelations._person(lost, null).name if lost >= 0 else ""
	var call := L.t("sc.final.voice", {"who": Revelations._person(lost, null), "me": Revelations._person(lost, null)}) if lost >= 0 else L.t("sc.final.voice_self")
	return {"id": "final_door", "voice": voice, "frames": [
		{"art": art("final_door"), "light": "night", "weather": "fog", "lines": [{"text": L.t("sc.final.1")}],
		 "sound": [{"at": 0.0, "do": "silence", "fade": 1.0}, {"at": 1.5, "do": "play", "id": "knock", "vol": -4.0}]},
		{"art": art("final_door"), "light": "night", "lines": [{"who": voice if not voice.is_empty() else L.t("sc.river.voice"), "text": call}]},
		{"art": art("final_train"), "light": "dawn", "lines": [{"text": L.t("sc.final.2")}],
		 "sound": [{"at": 0.2, "do": "play", "id": "train", "vol": -8.0}]},
	], "choice": {"prompt": L.t("sc.final.ask"), "options": [
		{"id": "open", "text": L.t("sc.final.c_open")}, {"id": "train", "text": L.t("sc.final.c_train")}]}, "restore_sound": false}


## Утро после утраты (TASK-014): кадры по предмету из истории того, кто остался, затем реплика реакции днём.
static func grief(kin: Villager, lost: Villager) -> Dictionary:
	var g := GriefReactions.scene_frames(kin, lost)
	var fr: PackedStringArray = g.frames
	var out: Array = []
	for i in range(fr.size()):
		var f := {"portrait": kin, "art": art("grief_%d" % kin.story_id), "light": "dawn" if i == 0 else "night",
			"lines": [{"text": fr[i]}]}
		if i == 0:
			f["sound"] = [{"at": 0.0, "do": "silence", "fade": 0.5}]
		else:
			f["sound"] = [{"at": 0.8, "do": "play", "id": String(g.sound), "vol": -4.0}]
		out.append(f)
	return {"id": "grief_%d" % kin.story_id, "frames": out}


static func _anchor(m: Match, idx: int) -> Villager:
	for v: Villager in m.villagers:
		if v.story_id == idx and not v.is_player and v.guest_id.is_empty():
			return v
	return null
