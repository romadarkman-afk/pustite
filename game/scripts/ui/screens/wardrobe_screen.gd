class_name WardrobeScreen
extends Screen
## Фонарь и шапка твоего жителя. Закрытые вещи видны с условием: сколько побед или испытаний дня нужно.
## Только внешний вид: на партию и ботов не влияет.

const AVATAR_COLUMNS := 5
const AVATAR_TILE_H := 112
const TABS: PackedStringArray = ["avatar", "lantern", "hat", "brooch"]
static var _tab := "avatar"     ## какой раздел открыт: остаётся и после надевания вещи, когда экран строится заново

var preview: VillagerFigure
var _art: Control


func screen_id() -> String:
	return "wardrobe"


func title() -> String:
	return L.t("cos.title")


func mood() -> Vector2:
	return Vector2(0.8, 0.6)


func build() -> void:
	W.clear(body)
	W.clear(footer)
	_art = Control.new()
	_art.custom_minimum_size = Vector2(0, 230)
	_art.clip_contents = true
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview = VillagerFigure.new()
	var book := L.looks()
	preview.setup(Save.player_display_name(), Cosmetics.dress(book.for_name(Save.player_display_name(), true), Save.hat), true)
	preview.set_sprite(Cosmetics.avatar_sprite(Save.avatar_id, preview.look))
	preview.set_hero_hat(Save.hat if Save.avatar_id == "hero" else "own")
	preview.set_lantern(Save.lantern)
	preview.set_brooch(Save.brooch)
	preview.scale = Vector2(1.9, 1.9)
	_art.add_child(preview)
	_art.resized.connect(func() -> void: preview.position = Vector2(_art.size.x * 0.5, _art.size.y - 24.0))
	body.add_child(_art)

	# четыре раздела вкладками: на телефоне всё сразу не помещалось, приходилось тянуть вниз
	var tab_buttons: Array[Button] = []
	for t: String in TABS:
		var tb := W.button(_tab_title(t), &"RowOn" if t == _tab else &"Row")
		tb.name = "tab_" + t
		var key := t
		tb.pressed.connect(func() -> void:
			_tab = key
			build())
		tab_buttons.append(tb)
	body.add_child(W.fit_row(tab_buttons))
	var grids: Array[Control] = [_avatar_grid(), _grid("lantern", Cosmetics.LANTERNS, Save.lantern),
		_grid("hat", Cosmetics.HATS, Save.hat), _grid("brooch", Cosmetics.BROOCHES, Save.brooch)]
	for i in range(grids.size()):
		grids[i].visible = TABS[i] == _tab
		body.add_child(grids[i])
	body.add_child(W.label(L.t("cos.note"), &"Small"))

	var back := W.button(L.t("ui.back"), &"Ghost")
	back.pressed.connect(func() -> void: emit_intent(Intent.BACK))
	footer.add_child(back)


func _tab_title(kind: String) -> String:
	match kind:
		"avatar":
			return L.t("cos.appearances")
		"lantern":
			return L.t("cos.lanterns")
		"hat":
			return L.t("cos.hats")
	return String((StoryLoc.get_v("misc") as Array)[1]) if StoryLoc.has("misc") else ("Значок" if L.code == "ru" else "Brooch")


func _grid(kind: String, items: Array[Dictionary], worn: String) -> GridContainer:
	var g := GridContainer.new()
	g.name = "Grid_" + kind
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for it: Dictionary in items:
		var open := Cosmetics.is_open(it)
		var txt := Cosmetics.title(kind, it.id)
		if not open:
			txt += "\n" + Cosmetics.need_text(it)
		var b := W.wrap(W.button(txt, &"RowOn" if it.id == worn else &"Row"))
		b.name = "%s_%s" % [kind, it.id]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not open or (kind == "hat" and Save.avatar_id != "hero")
		var id: String = it.id
		b.pressed.connect(func() -> void: emit_intent(Intent.WEAR, {"kind": kind, "id": id}))
		g.add_child(b)
	return g


func _avatar_grid() -> GridContainer:
	var g := GridContainer.new()
	g.name = "Grid_avatar"
	g.columns = AVATAR_COLUMNS
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for avatar: Dictionary in Cosmetics.AVATARS:
		var id := String(avatar.id)
		# только портрет: подпись «Образ N» ломалась по буквам в узкой кнопке, имя остаётся подсказкой
		var button := W.button("", &"RowOn" if id == Save.avatar_id else &"Row", AVATAR_TILE_H)
		button.name = "avatar_%s" % id
		button.tooltip_text = Cosmetics.title("avatar", id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		var texture := VillagerFigure.folk_tex(Cosmetics.avatar_sprite(id, preview.look))
		if texture != null:
			button.icon = texture
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 64)
		button.pressed.connect(func() -> void:
			emit_intent(Intent.WEAR, {"kind": "avatar", "id": id}))
		g.add_child(button)
	return g
