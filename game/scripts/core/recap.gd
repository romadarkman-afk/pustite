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
				out.append(L.t("recap.street_host", {"house": house, "who": host}))
			out.append(L.t("recap.street"))
			if r != null:
				out.append(L.t("recap.street_p", {"p": roundi(r.p_out * 100.0)}))
		NightReport.Kind.KILLED_INSIDE:
			var k := e.killer
			if k != null:
				out.append(L.t("recap.killer", {"who": k}))
				if host != null and host.is_player:
					out.append(L.t("recap.you_opened", {"who": k}))
				elif host == k:
					out.append(L.t("recap.killer_opened", {"who": k}))
			var rest: Array[Villager] = []
			for o: Villager in e.others:
				if o != k:
					rest.append(o)
			if not rest.is_empty():
				out.append(L.t("recap.near", {"others": rest}))
		NightReport.Kind.KILLED_ALONE:
			out.append(L.t("recap.alone", {"house": house}))
			if r != null and r.p_alone.has(e.house):
				out.append(L.t("recap.alone_p", {"p": roundi(float(r.p_alone[e.house]) * 100.0)}))
		NightReport.Kind.KILLED_CREATURE:
			out.append(L.t("recap.creature", {"house": house}))
			out.append(L.t("recap.creature_tip"))
		NightReport.Kind.KILLED_MIMIC:
			var voice := e.voice
			if host != null and host.is_player:
				out.append(L.t("recap.mimic_you", {"voice": voice}))
			elif host != null:
				out.append(L.t("recap.mimic_host", {"who": host, "voice": voice}))
			if voice != null:
				if not voice.alive and voice.exiled_day < 0 and voice.night_house < 0:
					out.append(L.t("recap.voice_dead", {"voice": voice}))
				elif voice.night_house >= 0 and voice.night_house != e.house:
					out.append(L.t("recap.voice_away", {"voice": voice, "house": m.house_name(voice.night_house)}))
	return out


## Почему изгнали игрока: кто голосовал против и какие улики видел посёлок.
static func exile_lines(m: Match, d: Director) -> PackedStringArray:
	var out := PackedStringArray()
	var me := m.player()
	if not me.exiled:
		return out
	for rec: Dictionary in m.vote_log:
		if rec.exiled == me:
			var against: Array[Villager] = []
			var votes: Dictionary = rec.votes
			for vid: Variant in votes:
				if int(votes[vid]) == me.id:
					against.append(m.get_villager(int(vid)))
			out.append(L.t("recap.exiled", {"d": int(rec.day), "list": against}) if not against.is_empty() else L.t("recap.exiled_many", {"d": int(rec.day)}))
	var ev := d.evidence_text(me) if d != null else ""
	if not ev.is_empty():
		out.append(L.t("recap.seen", {"ev": ev}))
	return out


## Одна строка: что решило твою партию. Ошибка, удача или итог.
static func verdict(m: Match, d: Director) -> String:
	var me := m.player()
	if me.exiled:
		var ex := exile_lines(m, d)
		return ex[0] if not ex.is_empty() else L.t("recap.exiled0")
	if m.player_death != null:
		var night := 0
		for rec: Dictionary in m.history:
			if (rec.dead as Array).has(me.id):
				night = int(rec.day)
		var why := death_lines(m, m.player_death)
		return L.t("recap.died", {"n": night, "why": why[0] if not why.is_empty() else ""}).strip_edges()
	if not me.is_upyr:
		for a: Dictionary in m.player_admits:
			if bool(a.mimic):
				return L.t("verdict.mimic", {"n": int(a.day), "voice": a.who})
			var w: Villager = a.who
			if w.is_upyr:
				return L.t("verdict.let_upyr", {"n": int(a.day), "who": w})
		for pv: Dictionary in m.player_votes:
			var t: Villager = pv.who
			if t != null and t.exiled and t.exiled_day == int(pv.day):
				if t.is_upyr:
					return L.t("verdict.vote_upyr", {"n": int(pv.day), "who": t})
				return L.t("verdict.vote_human", {"n": int(pv.day), "who": t})
		return L.t("verdict.clean") if me.alive else L.t("verdict.dead")
	# игрок-упырь
	var tally := L.t("verdict.kills", {"n": m.player_kills}) if m.player_kills > 0 else ""
	if m.winner == Match.Team.UPYRI:
		return L.t("verdict.upyr_won") + tally
	return L.t("verdict.upyr_lost") + tally


## Лента партии: разделы «Ночь 1», «День 2»… со строками хроники без приставки.
## Утренние строки («Утром: …») идут в раздел прошлой ночи.
static func timeline(m: Match) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for part: Dictionary in m.chron:
		var title := String(part.title)
		if title == "" and not out.is_empty():
			title = out[out.size() - 1].title
		if out.is_empty() or out[out.size() - 1].title != title:
			out.append({"title": title, "lines": PackedStringArray()})
		var sec: Dictionary = out[out.size() - 1]
		var lines: PackedStringArray = sec.lines
		lines.append(L.gram().cap(String(part.text)))
		sec.lines = lines      # PackedStringArray копируется по значению — кладём обратно
	return out
