class_name TrainSheet
extends RefCounted
## Список на поезд (TASK-033): мест меньше, чем людей. Игрок в день вписывает одно имя и может вычеркнуть одно.
## Вычеркнутого обратно не впишут, и он это запомнит. Тайная запись видна, но без подписи.
## Открывается у смотрителя станции и из меню жителя.


static func text(m: Match) -> String:
	var lines := PackedStringArray()
	for e: Dictionary in m.train_list:
		var who := m.get_villager(int(e.who))
		var by := m.get_villager(int(e.by))
		if bool(e.secret):
			lines.append(L.t("list.row_secret", {"who": who}))
		else:
			lines.append(L.t("list.row", {"who": who, "me": by}))
	var head := L.t("list.title", {"n": m.train_cap()}) + "\n" + L.t("list.rule")
	return head + "\n\n" + ("\n".join(lines) if not lines.is_empty() else L.t("list.empty"))


static func open(parent: Control, m: Match, d: Director) -> void:
	var head := text(m)
	var opts := PackedStringArray()
	var acts: Array = []
	var day_ok := m.train_on and m.phase == Match.Phase.DAY and m.player().alive
	if day_ok and m.train_write_day != m.day and m.train_list.size() < m.train_cap():
		for v: Villager in m.alive_bots():
			if not m.on_train(v.id) and not m.train_struck.has(v.id):
				opts.append(L.t("list.write", {"who": v}))
				acts.append(["write", v.id])
	if day_ok and m.train_strike_day != m.day:
		for e: Dictionary in m.train_list:
			var v := m.get_villager(int(e.who))
			if v != null:
				opts.append(L.t("list.strike", {"who": v}))
				acts.append(["strike", v.id])
	var i: int = await ActionSheet.ask(parent, head, opts)
	if i < 0 or i >= acts.size() or not is_instance_valid(parent):
		return
	apply(m, d, String(acts[i][0]), m.get_villager(int(acts[i][1])))


static func apply(m: Match, d: Director, act: String, v: Villager) -> bool:
	if act == "write" and m.train_add(m.player(), v):
		Sfx.play(&"typewriter", 1.0, -6.0)
		m.post(ChatLine.system(L.t("list.sys_write", {"who": v})))
		return true
	if act == "strike" and m.train_strike(m.player(), v):
		Sfx.play(&"typewriter", 0.9, -6.0)
		m.post(ChatLine.system(L.t("list.sys_strike", {"who": v})))
		if d != null:
			var l := d.on_struck(v)
			if l != null:
				m.post(l)
		return true
	return false
