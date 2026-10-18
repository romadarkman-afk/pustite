class_name VouchSheet
extends RefCounted
## Книга у ворот монастыря (TASK-026): кто за кого поручился и по какому дню. Игрок вписывает одно имя в день.
## Вписанный ночью входит без вопросов. Если это упырь, доверие группы падает вдвое сильнее.
## Открывается у брата Игната и из меню жителя.


## Книга: записи и, если сегодня ещё можно, список, кого вписать.
static func open(parent: Control, m: Match, d: Director) -> void:
	var lines := PackedStringArray()
	for e: Dictionary in m.vouches:
		lines.append(L.t("vouch.row", {"n": int(e.day), "me": m.get_villager(int(e.by)), "who": m.get_villager(int(e.who))}))
	var head := L.t("vouch.title") + "\n" + L.t("vouch.rule")
	head += "\n\n" + ("\n".join(lines) if not lines.is_empty() else L.t("vouch.empty"))
	var can := m.vouch_on and m.phase == Match.Phase.DAY and m.vouch_day != m.day and m.player().alive
	var opts := PackedStringArray()
	var ids: Array[int] = []
	if can:
		for v: Villager in m.alive_bots():
			opts.append(L.t("vouch.write", {"who": v}))
			ids.append(v.id)
	elif m.vouch_day == m.day:
		head += "\n\n" + L.t("vouch.done_today")
	var i: int = await ActionSheet.ask(parent, head, opts)
	if i >= 0 and i < ids.size() and is_instance_valid(parent):
		write(m, d, m.get_villager(ids[i]))


## Из меню жителя: спросить «точно?» — грех вписанного теперь и твой.
static func confirm(parent: Control, m: Match, d: Director, v: Villager) -> void:
	var yes: int = await ActionSheet.ask(parent, L.t("vouch.ask", {"who": v}), PackedStringArray([L.t("vouch.yes")]))
	if yes == 0 and is_instance_valid(parent):
		write(m, d, v)


static func write(m: Match, _d: Director, v: Villager) -> void:
	if m.vouch(m.player(), v):
		m.post(ChatLine.system(L.t("vouch.sys", {"who": v})))
		m.post(Director.npc_line("ignat", L.t("npc.ignat.vouched", {"who": v})))
