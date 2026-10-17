class_name Scenes
extends RefCounted
## Сцены кампании (TASK-011–014) как данные для ScenePlayer. Тексты — ключи sc.* и scene.* во всех языках,
## сцены утраты — GriefReactions. Сценарий главы «Стук» с раскадровкой: docs/scenes/a1c1.md.
##
## Кадр: {"art": путь, "portrait": житель, "zoom": [от, до], "light": night | dusk | dawn | warm | day,
##        "weather": "" | fog | rain, "lines": [{"who", "text", "pause"}], "sound": [{"at", "do", "id", "vol"}]}

const ART := "res://assets/scenes/%s.jpg"


static func art(name: String) -> String:
	return ART % name


## Сцена 1 главы «Стук»: река, зов с того берега, перевозчица гасит фонарь, стук в дверь.
## В конце выбор: отозваться на зов или промолчать. Отозвался — перевозчица это запомнит.
static func river(m: Match) -> Dictionary:
	var ferry := _anchor(m, 0)
	var ferry_name := ferry.name if ferry != null else String(L.names()[0][0])
	var me := Save.player_display_name()
	return {
		"id": "a1c1_river",
		"frames": [
			{"art": art("river"), "zoom": [1.0, 1.1], "light": "dusk", "weather": "fog",
			 "lines": [{"text": L.t("sc.river.1")}, {"who": L.t("sc.river.voice"), "text": L.t("sc.river.2", {"name": me}), "pause": 0.6}],
			 "sound": [{"at": 0.0, "do": "silence", "fade": 0.4}, {"at": 0.2, "do": "amb", "id": "amb_river", "fade": 1.0},
				{"at": 1.6, "do": "play", "id": "call_far", "vol": -6.0}]},
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
