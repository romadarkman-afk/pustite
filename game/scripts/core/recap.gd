class_name Recap
extends RefCounted
## Разбор партии (задача 38): почему ты погиб, что решило исход, как шла партия по ночам.
## Чистые функции над Match: экраны только показывают строки, самотест их проверяет.
## Игрок здесь — «ты»: так он говорит о себе сам, а пол игрока игре неизвестен.


## Почему погиб игрок: 2–4 строки. e — запись о его смерти из утренней сводки.
static func death_lines(m: Match, e: NightReport.Entry, r: NightReport = null) -> PackedStringArray:
	var out := PackedStringArray()
	if e == null:
		return out
	var house := m.house_name(e.house) if e.house >= 0 else ""
	var host := e.host
	match e.kind:
		NightReport.Kind.KILLED_STREET:
			if host != null and not host.is_player:
				out.append("Тебя не пустили в «%s»: хозяином там %s %s." % [house, Ru.g(host, "был", "была", "были"), host.name])
			out.append("Ночь ты провёл на улице. Там гибнут почти все.")
			if r != null:
				out.append("Шанс погибнуть на улице этой ночью: %d%%." % roundi(r.p_out * 100.0))
		NightReport.Kind.KILLED_INSIDE:
			var k := e.killer
			if k != null:
				out.append("Тебя убил %s. %s был упырём." % [k.name, "Он" if not k.female else "Она"])
				if host != null and host.is_player:
					out.append("Ты сам открыл %s дверь." % _dat(k))
				elif host == k:
					out.append("Дверь тебе %s сам%s %s." % [Ru.g(k, "открыл", "открыла", "открыли"), "" if not k.female else "а", k.name])
			var rest: Array[Villager] = []
			for o: Villager in e.others:
				if o != k:
					rest.append(o)
			if not rest.is_empty():
				out.append("Рядом %s: %s." % [Ru.were(rest, "был", "была", "были"), Ru.join(rest)])
		NightReport.Kind.KILLED_ALONE:
			out.append("Ты остался в «%s» один. Одному оберега до утра не хватает." % Ru.house_in(house))
			if r != null and r.p_alone.has(e.house):
				out.append("Шанс погибнуть одному в этом доме: %d%%. Днём позови кого-нибудь с собой." % roundi(float(r.p_alone[e.house]) * 100.0))
		NightReport.Kind.KILLED_CREATURE:
			out.append("Оберег у «%s» был расколот, и в дом вошла тварь из леса." % Ru.house_of(house))
			out.append("Днём оберег можно было подправить: это дело на площади.")
		NightReport.Kind.KILLED_MIMIC:
			var voice := e.voice
			if host != null and host.is_player:
				out.append("Ты открыл дверь голосу %s. Это был Подражатель." % Ru.gen(voice))
			elif host != null:
				out.append("%s %s голос %s. Это был Подражатель." % [host.name, Ru.g(host, "впустил", "впустила", "впустили"), Ru.gen(voice)])
			if voice != null:
				if not voice.alive and voice.exiled_day < 0 and voice.night_house < 0:
					out.append("%s к тому времени уже не было в живых." % Ru.gen(voice).left(1).to_upper() + Ru.gen(voice).substr(1))
				elif voice.night_house >= 0 and voice.night_house != e.house:
					out.append("А %s в это время %s в «%s»." % [voice.name, Ru.g(voice, "был", "была", "были"), Ru.house_in(m.house_name(voice.night_house))])
	return out


## Почему изгнали игрока: кто голосовал против и какие улики видел посёлок.
static func exile_lines(m: Match, d: Director) -> PackedStringArray:
	var out := PackedStringArray()
	var me := m.player()
	if not me.exiled:
		return out
	for rec: Dictionary in m.vote_log:
		if rec.exiled == me:
			var against := PackedStringArray()
			var votes: Dictionary = rec.votes
			for vid: Variant in votes:
				if int(votes[vid]) == me.id:
					against.append(m.get_villager(int(vid)).name)
			out.append("Тебя изгнали в день %d. Против тебя: %s." % [int(rec.day), ", ".join(against) if not against.is_empty() else "большинство"])
	var ev := d.evidence_text(me) if d != null else ""
	if not ev.is_empty():
		out.append("Посёлок видел: %s." % ev)
	return out


## Одна строка: что решило твою партию. Ошибка, удача или итог.
static func verdict(m: Match, d: Director) -> String:
	var me := m.player()
	if me.exiled:
		var ex := exile_lines(m, d)
		return ex[0] if not ex.is_empty() else "Тебя изгнали."
	if m.player_death != null:
		var night := 0
		for rec: Dictionary in m.history:
			if (rec.dead as Array).has(me.id):
				night = int(rec.day)
		var why := death_lines(m, m.player_death)
		return ("Ты погиб в ночь %d. " % night) + (why[0] if not why.is_empty() else "")
	if not me.is_upyr:
		for a: Dictionary in m.player_admits:
			if bool(a.mimic):
				return "В ночь %d ты открыл дверь Подражателю, голосу %s." % [int(a.day), Ru.gen(a.who)]
			var w: Villager = a.who
			if w.is_upyr:
				return "В ночь %d ты впустил %s, а %s %s упырём." % [int(a.day), Ru.acc(w), "он" if not w.female else "она", Ru.g(w, "был", "была", "были")]
		for pv: Dictionary in m.player_votes:
			var t: Villager = pv.who
			if t != null and t.exiled and t.exiled_day == int(pv.day):
				if t.is_upyr:
					return "В день %d твой голос помог изгнать упыря: %s." % [int(pv.day), t.name]
				return "В день %d ты голосовал против %s, а %s %s человеком." % [int(pv.day), Ru.gen(t), "он" if not t.female else "она", Ru.g(t, "был", "была", "были")]
		return "Ты ни разу не открыл дверь упырю и дожил до рассвета." if me.alive else "Ты не дожил до рассвета."
	# игрок-упырь
	var tally := " На твоём счету: %d." % m.player_kills if m.player_kills > 0 else ""
	if m.winner == Match.Team.UPYRI:
		return "Посёлок так и не понял, что упырь — ты." + tally
	return "Ты дожил до рассвета, но посёлок выстоял." + tally


## Лента партии: разделы «Ночь 1», «День 2»… со строками хроники без приставки.
static func timeline(m: Match) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var re := RegEx.create_from_string("^(Ночь|День) (\\d+): (.*)$")
	for line: String in m.chronicle:
		var title := ""
		var text := line
		var mm := re.search(line)
		if mm != null:
			title = "%s %s" % [mm.get_string(1), mm.get_string(2)]
			text = mm.get_string(3)
		elif line.begins_with("Утром: "):
			text = line.substr(7)
		if title == "" and not out.is_empty():
			title = out[out.size() - 1].title
		if out.is_empty() or out[out.size() - 1].title != title:
			out.append({"title": title, "lines": PackedStringArray()})
		var t2: String = text.left(1).to_upper() + text.substr(1)
		var sec: Dictionary = out[out.size() - 1]
		var lines: PackedStringArray = sec.lines
		lines.append(t2)
		sec.lines = lines      # PackedStringArray копируется по значению — кладём обратно
	return out


## «к Рите», «к Тимуру»: кому открыли дверь.
static func _dat(v: Villager) -> String:
	var n := v.name
	var stem := n.substr(0, n.length() - 1)
	match n.right(1):
		"а", "я": return stem + "е"
		"й", "ь": return stem + "ю"
	return n + "у"
