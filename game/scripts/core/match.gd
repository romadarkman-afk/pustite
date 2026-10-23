class_name Match
extends RefCounted
## Правила игры и машина состояний партии.
## Чистая логика: не знает про экраны, не трогает SceneTree.
## Наружу общается только сигналами. Переходы фаз решает только Match.

enum Phase { IDLE, PROLOGUE, DAY, VOTE, NIGHT, DOOR, MORNING, OVER }
enum Team { NONE, PEOPLE, UPYRI }
enum DoorRole { DEAD, HOST, GUEST, ALONE }
## Роли людей (задача 31). Каждый человек получает одну, пока хватает ролей. Упыри ролей не имеют,
## но могут назваться Старожилом. Старожил и Знахарка срабатывают один раз за партию,
## голос Старосты на изгнании всегда считается за два.
enum Role { NONE, ELDER, HEALER, HEADMAN }

signal phase_changed(phase: Phase)
signal chat_posted(line: ChatLine)

## Имена жителей и названия убежищ — в файле языка (L.names(), L.houses()): у каждой страны свой посёлок.

## Семьи по номерам историй: [старший, младший, вид]. Лида — бабушка Кости, Женя — мать Захара.
const FAMILIES := [[2, 3, "grand"], [4, 6, "parent"]]
## Давние связи (TASK-007): Тихон и Нина были помолвлены, Полина ковала нож для мужа Жени,
## Рита ждёт у моста брата Вадима.
const TIES := [[5, 9, "engaged"], [11, 4, "knife"], [7, 10, "bridge"]]


## Кто к какому убежищу пришёл ночью. Первый добежавший — хозяин двери.
class Seat:
	var house: int
	var host: Villager
	var queue: Array[Villager] = []
	var admitted: Array[Villager] = []
	var decided: bool = false
	## Подражатель: тварь стучит голосом этого жителя (он в другом доме или уже погиб).
	var mimic: Villager = null
	var mimic_at: int = 0          ## каким по счёту он стоит среди стучащих
	var mimic_in: bool = false     ## его впустили

	## Все, кто стучит в дверь: очередь и, если пришёл, Подражатель на своём месте.
	func knockers() -> Array[Villager]:
		var out: Array[Villager] = queue.duplicate()
		if mimic != null:
			out.insert(clampi(mimic_at, 0, out.size()), mimic)
		return out

	func inside() -> Array[Villager]:
		var out: Array[Villager] = [host]
		out.append_array(admitted)
		return out

	func turned_away() -> Array[Villager]:
		var out: Array[Villager] = []
		for v: Villager in queue:
			if not admitted.has(v):
				out.append(v)
		return out


var config: GameConfig
var villagers: Array[Villager] = []
var houses: PackedStringArray = []
var day: int = 0
var case_id: int = 0              ## один из трёх сюжетных эпизодов партии
var phase: Phase = Phase.IDLE
var winner: Team = Team.NONE
var chat: Array[ChatLine] = []
var chronicle: PackedStringArray = []     ## хроника строками: «Ночь 2: …»
var chron: Array[Dictionary] = []         ## та же хроника по частям: {"title": «Ночь 2» или "", "text"}
var seats: Array[Seat] = []
var report: NightReport
var last_exiled: Villager
var last_tally: Dictionary[int, int] = {}
var rng := RandomNumberGenerator.new()

## Дела по посёлку и запасы дня. Запасы снижают шанс погибнуть ночью на улице
## и одному в доме: фонари горят, обереги держатся.
const SUPPLY_BONUS := 0.2           ## полные запасы срезают столько от шанса гибели
const DEFAULT_VILLAGE := "res://config/village_default.tres"
var jobs: Array[JobDef] = []                 ## дела сегодняшнего дня: обычные и починка оберегов
var base_jobs: Array[JobDef] = []            ## обычные дела из карты посёлка
var village: VillageDef

## Обереги убежищ: 2 — целый, 1 — треснул, 0 — расколот.
## Целый бережёт того, кто остался в доме один. Расколотый пускает в дом тварь из леса.
## За ночь оберег слабеет с шансом TALISMAN_DECAY; днём его чинят как дело.
const TALISMAN_MAX := 2
const TALISMAN_DECAY := 0.5
const CREATURE_KILL := 0.7
const CANDLE_TELL_CREATURE: Array[float] = [0.44, 0.58, 0.72]   ## свеча у двери тусклая / обычная / яркая: шанс приметы у упыря (TASK-073)
const CANDLE_TELL_HUMAN: Array[float] = [0.18, 0.23, 0.26]      ## то же у человека
const FLICKER_CREATURE := 0.55             ## свеча мигает перед стуком, если за дверью упырь или Подражатель (TASK-077)
const FLICKER_EMPTY := 0.15                ## и иногда мигает просто так
const CANDLE_PRESS := 0.10                  ## яркая свеча: тварь за дверью давит сильнее на столько, тусклая слабее
const ALONE_SAFE := 0.8                      ## целый оберег: одному в доме безопаснее (шанс гибели × 0.8)
var talisman: PackedInt32Array = PackedInt32Array()
var job_left: PackedInt32Array = PackedInt32Array()
var supply_done: int = 0
var supply_total: int = 0

## Подражатель (со второй ночи): тварь стучит в одну из дверей голосом жителя,
## который сейчас в другом доме или уже погиб. Впустили — забирает одного из тех, кто внутри.
const MIMIC_P := 0.4
const MIMIC_KILL := 0.85

## События ночи (со второй ночи): меняют правила на одну ночь. Объявляются с колоколом.
enum Event { NONE, FOG, MOON, QUIET, RAIN }
const EVENT_P := 0.5
const EVENT_KEY := {Event.FOG: "fog", Event.MOON: "moon", Event.QUIET: "quiet", Event.RAIN: "rain"}
const FOG_RUN := 3              ## туман: на столько секунд короче звон
const FOG_DEATH := 0.1          ## туман: настолько опаснее улица
const QUIET_SAFE := 0.25        ## тихая ночь: настолько безопаснее улица
var night_event: Event = Event.NONE
var force_event: int = -1       ## самотесты: следующее событие ночи будет этим (со второй ночи)
var rule: String = ""           ## испытание дня (Challenge.RULES) или "" — обычная партия. Ставится до start()

## Знахарка: кто из знахарок взял травы этой ночью.
var healer_on: Dictionary[int, bool] = {}
## Что посёлок знает о ролях: кто кем назвался вслух. id -> строка для дневника.
var claims: Dictionary[int, String] = {}
var claim_about: Dictionary[int, int] = {}    ## о ком было заявление: id назвавшегося -> id
var claim_elder: Dictionary[int, bool] = {}   ## кто назвался старожилом

## Экстренный сбор (задача 32): раз за партию любой может днём ударить в колокол — сразу голосование.
var meeting_used: Dictionary[int, bool] = {}
var meeting_by: int = -1           ## кто созвал сбор сегодня; -1 — сегодня сбора не было

## Туннель (задача 33): ход под посёлком между двумя убежищами. Кого не пустили в одно,
## может пролезть в другое, если там есть место. Упыри лезут охотнее.
const TUNNEL_UPYR := 0.8
const TUNNEL_HUMAN := 0.4
var tunnel: Vector2i = Vector2i(-1, -1)
var tunnel_log: Array[Array] = []   ## этой ночью: [житель, откуда, куда]

## Дневник (задача 34): что было каждой ночью. {"day", "where": {id: дом, -1 — улица}, "said": {id: дом}, "dead": [id]}
var history: Array[Dictionary] = []
var candle := 0                          ## свеча у двери игрока этой ночью: -1 тусклая, 0 обычная, 1 яркая
var door_inspections: Array[Dictionary] = [] ## осмотры у двери: день, житель и неоднозначная примета
var question_tokens: int = 0             ## жетоны за проверенные противоречия; один вопрос у двери за ночь
var question_used_day: int = -1
const QUESTION_TOKEN_MAX := 3
var _night_ids: Array[int] = []     ## кто был жив, когда началась ночь
var player_seen: Dictionary[int, int] = {}   ## что игрок-старожил увидел на рисунках: id -> 1 упырь, 0 человек

## Разбор партии (задача 38): решения игрока и голосования — чтобы в конце объяснить, что решило исход.
var player_admits: Array[Dictionary] = []    ## {"day", "who": Villager, "mimic": bool} — кого игрок-хозяин впустил
var player_votes: Array[Dictionary] = []     ## {"day", "who": Villager} — за кого голосовал игрок
var vote_log: Array[Dictionary] = []         ## {"day", "votes": {id: id}, "exiled": Villager}
var player_death: NightReport.Entry = null   ## как погиб игрок (если ночью)
var player_kills: int = 0                    ## игрок-упырь: скольких забрал
## Ночные дилеммы у двери игрока-хозяина (Task 56): не больше двух за партию, одна за ночь.
## {"day", "kind", "who": id, "other": id или -1, "admitted": bool, "fate": "" | "alive" | "street" | "inside" | "other"}
var dilemmas: Array[Dictionary] = []
var today_dilemma: Dictionary = {}
const DILEMMA_MAX := 2
const DILEMMA_OIL_P := 0.3
var refused_player: Array[Dictionary] = []   ## {"day", "by": Villager} — кто не открыл игроку
var accused_player: Dictionary[int, int] = {} ## кто обвинял игрока: id -> день
var owes_player: Dictionary[int, bool] = {}
var player_refused_all: int = 0             ## сколько раз игрок-хозяин не открыл никому (Книга посёлка)
var griefs: int = 0                         ## сколько раз за партию у погибшего остались близкие  ## игрок впустил того, кто ему не открыл: долг платежом красен
var cast: Array[int] = []
var guests: PackedStringArray = []          ## кто приезжает гостем (Guests.IDS); ставится до start()
var guest_roles_fixed := false              ## кампания: роль гостя задана сюжетом                   ## кампания: номера имён жителей (L.names); пусто — обычная жеребьёвка
var forest_call_day: int = -1                ## ночью после изгнания из леса зовут игрока по имени
const FOREST_CALL_HUMAN := 0.8
const FOREST_CALL_UPYR := 0.35               ## упырь тоже умеет звать — по зову роль не понять

## Ящик (со второго дня): днём на краю площади появляется ящик. Кто первым откроет,
## тому достаётся находка: записка (один из двоих — упырь), масло (+2 к запасам) или мел (чинит оберег).
enum Loot { NONE, NOTE, OIL, CHALK }
const BOX_P := 0.6
const BOX_OIL := 2
var box_today: bool = false
var box_pos: Vector2 = Vector2.ZERO
var box_loot: Loot = Loot.NONE
var box_opened_by: int = -1
var box_notes: Array[Dictionary] = [] ## кто нашёл честную записку и какие два имени в ней указаны

## Журнал событий партии (TASK-001) и знание жителей о них (TASK-003).
var world := WorldLog.new()
## Чувства жителей (TASK-006).
var feelings := Feelings.new()
## Отчаяние (TASK-008): кто этой ночью уйдёт к реке на голос, а не к дому. Остановить можно днём разговором.
var wander_plan: Dictionary[int, bool] = {}
## Тетрадь улик (TASK-017).
var clues := Clues.new()
var plant_chapter := ""            ## глава кампании с заложенным противоречием (TASK-018); ставится до start()
## Прощание (TASK-020): кого игрок отправил на лодке, уплывёт на рассвете. -1 — никого.
var send_away_id := -1
var send_used := false
## Акт II (TASK-021–024). Ставятся до start().
var chapter_id := ""                ## глава кампании или ""
var npc_id := ""                    ## хозяин места вне голосования: "miller"
var force_upyr_story := -1          ## «Чужаки»: житель с этим номером истории — упырь, если он в составе
var talisman_whole := false         ## мельник помог (TASK-022): ни один оберег не треснул до вас
var flood_day := -1                 ## «Половодье»: с утра этого дня вода заливает один из низких домов
var flood_choice := -1              ## куда игрок отправил лодку: этот низкий дом остаётся сухим
var flooded_house := -1             ## залитый дом: в нём никто не ночует до конца главы
## Акт III (TASK-026–030). Ставятся до start().
var extra_npcs: PackedStringArray = []   ## ещё хозяева места: Анфиса рядом с Игнатом
var npc_asked: Dictionary = {}      ## хозяин -> день, когда игрок уже спросил
var vouch_on := false               ## «Ворота»: книга поручительств у ворот
var vouches: Array[Dictionary] = [] ## {"by": id, "who": id, "day": n}
var vouch_day := 0                  ## в какой день игрок уже вписал имя
var bell_on := false                ## «Колокол»: колокол бьёт сам, когда упырь в доме
var last_bells: Array[int] = []     ## номера домов (с 1), где этой ночью бил колокол
var trust_on := false               ## доверие группы к игроку (TASK-030)
var trust := TRUST_START
var trust_mute_day := -1            ## в этот день голос игрока не считается
var trust_log: Array[Dictionary] = []   ## {"day", "d", "why"} — для проверок и разбора
var player_on_trial := false        ## «Крипта»: Игнат судит игрока (TASK-029)
## Акт IV (TASK-033, 034): список на поезд. Ставится до start().
var train_on := false
var train_list: Array[Dictionary] = []   ## {"who": id, "by": id, "day": n, "secret": bool}
var train_struck: Array[int] = []        ## кого вычеркнули: в список больше не вернуть
var train_write_day := 0                 ## в какой день игрок уже вписал имя
var train_strike_day := 0                ## в какой день игрок уже вычеркнул
var betrayer_id := -1                    ## «Последний поезд»: кто тайно вписал упыря
const SEND_BACK_HUMAN := 0.3       ## человек тоже иногда передумывает: по возвращению упыря не узнать наверняка

## Обещания (TASK-004). open — «открою тебе, если постучишь»: обещавший держит дверь и пускает.
## come — «приду к тебе ночевать»: обещавший ночует в том же доме. Проверяются ночью.
## {"day", "by": id, "to": id, "kind": "open" | "come", "state": "" | "kept" | "broken" | "void"}
var promises: Array[Dictionary] = []
var story_pages_found: PackedStringArray = [] ## новые личные главы, услышанные игроком в этой партии
const PROMISE_KINDS: PackedStringArray = ["open", "come"]


# =============================================================
# Запросы (только чтение)
# =============================================================
func alive() -> Array[Villager]:
	var out: Array[Villager] = []
	for v: Villager in villagers:
		if v.alive:
			out.append(v)
	return out


func alive_bots() -> Array[Villager]:
	var out: Array[Villager] = []
	for v: Villager in villagers:
		if v.alive and not v.is_player:
			out.append(v)
	return out


func player() -> Villager:
	return villagers[0]


func opening_night_protects(v: Villager) -> bool:
	return chapter_id == "a1c1" and day == 1 and v != null and v.is_player


func get_villager(vid: int) -> Villager:
	for v: Villager in villagers:
		if v.id == vid:
			return v
	return null


func house_name(i: int) -> String:
	return houses[clampi(i, 0, houses.size() - 1)]


## Событие ночи: название и что оно меняет.
static func event_title(e: Event, mid: bool = false) -> String:
	return L.t("event.%s.%s" % [EVENT_KEY.get(e, "fog"), "mid" if mid else "title"])


static func event_text(e: Event) -> String:
	return L.t("event.%s.text" % EVENT_KEY.get(e, "fog"))


## Записать, кто кем назвался вслух: для дневника и решений ботов.
func claim(by: Villager, about: Villager, text: String, elder: bool = false) -> void:
	claims[by.id] = text
	if about != null:
		claim_about[by.id] = about.id
	if elder:
		claim_elder[by.id] = true


func humans_alive() -> int:
	var n := 0
	for v: Villager in villagers:
		if v.alive and not v.is_upyr:
			n += 1
	return n


func upyri_alive() -> int:
	var n := 0
	for v: Villager in villagers:
		if v.alive and v.is_upyr:
			n += 1
	return n


func vote_open() -> bool:
	return day >= config.vote_from_day and alive().size() > 2


func player_seat() -> Seat:
	for s: Seat in seats:
		if s.host == player() or s.queue.has(player()):
			return s
	return null


func player_door_role() -> DoorRole:
	if not player().alive:
		return DoorRole.DEAD
	var s := player_seat()
	if s == null:
		return DoorRole.DEAD
	if s.host != player():
		return DoorRole.GUEST
	return DoorRole.HOST if not s.knockers().is_empty() else DoorRole.ALONE


# =============================================================
# Чат
# =============================================================
func post(line: ChatLine) -> void:
	if line.about != null and line.about.is_player and line.speaker != null and not line.speaker.is_player:
		accused_player[line.speaker.id] = day
	if line.about != null and line.speaker != null and line.about != line.speaker:
		world.add(WorldLog.Kind.ACCUSE, day, line.speaker.id, line.about.id, -1, [], true)
		feelings.on_accused(line.about.id, line.speaker.id)
	chat.append(line)
	chat_posted.emit(line)


# =============================================================
# Машина состояний. Каждый метод — единственный легальный вход в фазу.
# =============================================================
func start(cfg: GameConfig, seed_value: int = 0) -> void:
	config = cfg.sanitized()
	story_pages_found.clear()
	box_notes.clear()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var names: Array = L.names().duplicate()
	var anchors: Array = names.slice(0, mini(3, names.size()))
	var pool: Array = names.slice(anchors.size())
	var fixed_story_cast := not chapter_id.is_empty() or not cast.is_empty()
	var solo_name_pool := SocialContent.solo_name_pool()
	var solo_male_names: Array[String] = []
	var solo_female_names: Array[String] = []
	var solo_motive_deck: Array[int] = []
	for name_data: Array in solo_name_pool:
		var candidate_name := String(name_data[0])
		if not Save.player_name.is_empty() and candidate_name.to_lower() == Save.player_name.to_lower():
			continue
		if bool(name_data[1]):
			solo_female_names.append(candidate_name)
		else:
			solo_male_names.append(candidate_name)
	if not fixed_story_cast:
		for motive_id in range(SocialContent.solo_motive_count()):
			solo_motive_deck.append(motive_id)
		_shuffle(solo_motive_deck)
	_shuffle(solo_male_names)
	_shuffle(solo_female_names)
	var quick_cast: Array[int] = []
	if not fixed_story_cast:
		# Три постоянных жителя сохраняют личные связи между партиями;
		# остальные места каждый раз получают случайный состав.
		var anchor_count := mini(3, names.size())
		for idx in range(anchor_count):
			quick_cast.append(idx)
		var quick_extra: Array[int] = []
		for idx in range(anchor_count, names.size()):
			if Save.player_name.is_empty() or String(names[idx][0]).to_lower() != Save.player_name.to_lower():
				quick_extra.append(idx)
		_shuffle(quick_extra)
		quick_cast.append_array(quick_extra)
		var needed := mini(config.players - 1, quick_cast.size())
		var selected: Array = quick_cast.slice(0, needed)
		if not _quick_cast_has_partner_pair(selected, names):
			var replacements: Array[Array] = []
			for remove_index in range(anchor_count, selected.size()):
				for incoming_index in range(needed, quick_cast.size()):
					var option: Array = selected.duplicate()
					option[remove_index] = quick_cast[incoming_index]
					if _quick_cast_has_partner_pair(option, names):
						replacements.append(option)
			if not replacements.is_empty():
				selected = replacements[rng.randi_range(0, replacements.size() - 1)]
				var reordered: Array[int] = []
				for idx: int in selected:
					reordered.append(idx)
				for idx: int in quick_cast:
					if not reordered.has(idx):
						reordered.append(idx)
				quick_cast = reordered
	# Резервный состав кампании должен учитывать имя игрока.
	if not Save.player_name.is_empty():
		for j in range(pool.size() - 1, -1, -1):
			if String(pool[j][0]).to_lower() == Save.player_name.to_lower():
				pool.remove_at(j)
		for i in range(anchors.size()):
			if String(anchors[i][0]).to_lower() == Save.player_name.to_lower() and not pool.is_empty():
				var replacement: Array = pool.pop_back()
				anchors[i] = replacement
	_shuffle(pool)
	villagers.clear()
	villagers.append(Villager.new(0, Save.player_display_name(), true))
	for i in range(config.players - 1):
		var data: Array = []
		var idx := -1
		if not fixed_story_cast:
			idx = quick_cast[i]
			data = names[idx]
		else:
			data = anchors[i] if i < anchors.size() else pool[i - anchors.size()]
			idx = i if i < anchors.size() else names.find(data)
		if i < cast.size() and cast[i] < names.size():
			idx = cast[i]                  # кампания: те же люди из главы в главу
			data = names[idx]
		var resident_name := String(data[0])
		if not fixed_story_cast and (idx >= 3 or resident_name.to_lower() == Save.player_name.to_lower()):
			var available_names: Array[String] = solo_female_names if bool(data[1]) else solo_male_names
			if not available_names.is_empty():
				resident_name = available_names.pop_back()
		var v := Villager.new(i + 1, resident_name, false)
		v.female = bool(data[1])
		v.anchor_id = idx if idx < 3 else -1
		v.story_id = idx
		v.age = SocialContent.story_age(v.story_id)
		v.relationship = Save.anchor_bond(v.anchor_id)
		if not fixed_story_cast:
			if solo_motive_deck.is_empty():
				for motive_id in range(SocialContent.solo_motive_count()):
					solo_motive_deck.append(motive_id)
				_shuffle(solo_motive_deck)
			v.motive_id = solo_motive_deck.pop_back()
		else:
			v.motive_id = -1
		v.persona = Voices.random_persona(rng) if not fixed_story_cast else Voices.persona_for(v.story_id, v.name)
		villagers.append(v)
	# Связь симметрична, только между взрослыми, без зависимости от скрытой роли.
	var lovers: Array[Villager] = []
	for v: Villager in villagers:
		if not v.is_player and v.age < 55 and v.story_id != 8:
			lovers.append(v)
	lovers.sort_custom(func(a: Villager, b: Villager) -> bool: return a.story_id < b.story_id)
	if not fixed_story_cast:
		var pair_options: Array[Array] = []
		for i in range(lovers.size()):
			for j in range(i + 1, lovers.size()):
				var a: Villager = lovers[i]
				var b: Villager = lovers[j]
				if a.female == b.female:
					continue
				if not _authored_relation_pair(a.story_id, b.story_id):
					pair_options.append([a, b])
		_shuffle(pair_options)
		var couple_limit := rng.randi_range(1, 2) if pair_options.size() > 1 else 1
		var couples := 0
		for pair: Array in pair_options:
			var a: Villager = pair[0]
			var b: Villager = pair[1]
			if a.partner_id >= 0 or b.partner_id >= 0:
				continue
			a.partner_id = b.id
			b.partner_id = a.id
			couples += 1
			if couples >= couple_limit:
				break
	else:
		# В кампании эта пара должна остаться той же между главами.
		for a: Villager in lovers:
			for b: Villager in lovers:
				if a != b and a.female != b.female and a.partner_id < 0 and b.partner_id < 0:
					a.partner_id = b.id
					b.partner_id = a.id
					break
			if a.partner_id >= 0:
				break
	# Семейные связи зависят от биографии, а не от скрытой роли (TASK-007: Лида — бабушка Кости).
	for pair: Array in FAMILIES:
		var parent: Villager = null
		var child: Villager = null
		for resident: Villager in villagers:
			if resident.story_id == pair[0]: parent = resident
			if resident.story_id == pair[1]: child = resident
		if parent != null and child != null:
			parent.family_id = child.id
			child.family_id = parent.id
			parent.family_kind = "grandchild" if pair[2] == "grand" else "child"
			child.family_kind = "grandparent" if pair[2] == "grand" else "parent"
	# давние связи не по крови: о них говорят, их помнят, но траура по ним нет
	for tie: Array in TIES:
		var a: Villager = null
		var b: Villager = null
		for resident: Villager in villagers:
			if resident.story_id == tie[0]: a = resident
			if resident.story_id == tie[1]: b = resident
		if a != null and b != null and a.tie_id < 0 and b.tie_id < 0:
			a.tie_id = b.id
			b.tie_id = a.id
			a.tie_kind = String(tie[2])
			b.tie_kind = String(tie[2])

	# В быстрых партиях жители дополнительно получают одну случайную общую память.
	# Кампания сохраняет авторские связи, а случайные узы не дают траурных бонусов.
	if not fixed_story_cast:
		var bond_options: Array[Array] = []
		var candidates: Array[Villager] = []
		for resident: Villager in villagers:
			if not resident.is_player and resident.tie_id < 0 and resident.family_id < 0 and resident.partner_id < 0:
				candidates.append(resident)
		for i in range(candidates.size()):
			for j in range(i + 1, candidates.size()):
				bond_options.append([candidates[i], candidates[j]])
		_shuffle(bond_options)
		var bond_kind_deck: Array[String] = []
		for kind: String in SocialContent.solo_bond_kinds():
			bond_kind_deck.append(kind)
		_shuffle(bond_kind_deck)
		var bond_count := mini(rng.randi_range(1, 2), bond_options.size())
		for bond_index in range(bond_count):
			var pair: Array = bond_options[bond_index]
			var a: Villager = pair[0]
			var b: Villager = pair[1]
			var kind: String = String(bond_kind_deck.pop_back())
			a.tie_id = b.id
			b.tie_id = a.id
			a.tie_kind = kind
			b.tie_kind = kind
			a.tie_side = 0
			b.tie_side = 1

	var order: Array = range(villagers.size())
	if config.player_always_human:
		order.erase(0)
	_shuffle(order)
	for k in range(mini(config.monsters, order.size())):
		villagers[int(order[k])].is_upyr = true

	_seat_guests()
	_force_upyr()
	feelings.attach(self)
	clues.attach(self)
	wander_plan.clear()
	send_away_id = -1
	send_used = false
	npc_asked.clear()
	flooded_house = -1
	vouches.clear()
	vouch_day = 0
	last_bells.clear()
	trust_mute_day = -1
	trust_log.clear()
	train_list.clear()
	train_struck.clear()
	train_write_day = 0
	train_strike_day = 0
	betrayer_id = -1
	if village == null:
		village = load(DEFAULT_VILLAGE) as VillageDef
	houses = L.houses(village.houses_key).slice(0, config.shelters)
	_deal_roles()
	tunnel = Vector2i(-1, -1)
	if houses.size() >= 2:
		var a := rng.randi_range(0, houses.size() - 1)
		var b := (a + rng.randi_range(1, houses.size() - 1)) % houses.size()
		tunnel = Vector2i(mini(a, b), maxi(a, b))
	if village == null:
		village = load(DEFAULT_VILLAGE) as VillageDef
	base_jobs.clear()
	if village != null:
		for j: JobDef in village.jobs:
			if j.kind != JobDef.Kind.TALISMAN:
				base_jobs.append(job_texts(j.duplicate() as JobDef))
	# обереги: все целы, кроме одного — он треснул ещё до вас
	talisman = PackedInt32Array()
	for i in range(houses.size()):
		talisman.append(TALISMAN_MAX)
	if not houses.is_empty():
		var cracked := rng.randi_range(0, houses.size() - 1)
		if not talisman_whole:
			talisman[cracked] = TALISMAN_MAX - 1
	day = 1
	case_id = posmod(seed_value, 3) if seed_value != 0 else rng.randi_range(0, 2)
	winner = Team.NONE
	claims.clear()
	claim_about.clear()
	claim_elder.clear()
	meeting_used.clear()
	history.clear()
	door_inspections.clear()
	question_tokens = 0
	question_used_day = -1
	player_seen.clear()
	player_admits.clear()
	player_votes.clear()
	vote_log.clear()
	player_death = null
	player_kills = 0
	world.clear()
	promises.clear()
	chat.clear()
	chronicle.clear()
	chron.clear()
	seats.clear()
	report = null
	last_exiled = null
	_set_phase(Phase.PROLOGUE)


func begin_day() -> void:
	assert(phase == Phase.PROLOGUE or phase == Phase.MORNING)
	for v: Villager in villagers:
		v.announced_house = -1
	night_event = Event.NONE
	meeting_by = -1
	if day == flood_day and flood_day > 0:
		_start_flood()
	jobs = base_jobs.duplicate()
	for h in range(houses.size()):
		if talisman[h] < TALISMAN_MAX:
			jobs.append(_talisman_job(h))
	_roll_box()
	job_left = PackedInt32Array()
	supply_total = 0
	for j: JobDef in jobs:
		job_left.append(j.portions)
		supply_total += j.portions
	supply_done = 0
	if plant_chapter != "" and day == 2:
		clues.plant(plant_chapter)
	# «Пустая лодка» (TASK-018): в первый день главы — находка у реки
	if day == 1 and plant_chapter in ["a1c2", "a1c3"]:
		clues.add("find", -1, L.t("clue.boat_oar" if plant_chapter == "a1c2" else "clue.boat_scarf"), {"mystery": "boat"})
	# тайна мельника (TASK-022): в каждой главе акта II одна находка
	if day == 1 and MILLER_CLUES.has(chapter_id):
		clues.add("find", -1, L.t(MILLER_CLUES[chapter_id]), {"mystery": "miller"})
	_set_phase(Phase.DAY)
	post(ChatLine.system(L.t("sys.dawn1") if day == 1 else L.t("sys.dawn", {"d": day, "n": alive().size()})))


## Сделал дело. Засчитывается, если работа настоящая и у дела ещё есть порции.
## Возвращает true, если запасы выросли.
func do_job(_v: Villager, ji: int, real: bool) -> bool:
	if phase != Phase.DAY or ji < 0 or ji >= job_left.size():
		return false
	if not real or job_left[ji] <= 0 or jobs[ji].kind == JobDef.Kind.BOX:
		return false
	job_left[ji] -= 1
	supply_done += 1
	if jobs[ji].house >= 0 and jobs[ji].house < talisman.size():
		talisman[jobs[ji].house] = mini(TALISMAN_MAX, talisman[jobs[ji].house] + 1)
	return true


## Починка оберега убежища h — дело дня. Место работника — у двери дома.
func _talisman_job(h: int) -> JobDef:
	var j := JobDef.new()
	j.id = StringName("talisman_%d" % h)
	j.kind = JobDef.Kind.TALISMAN
	j.house = h
	j.portions = TALISMAN_MAX - talisman[h]
	j.work_sec = 4.0
	job_texts(j)
	var hd: HouseDef = village.shelters[h] if village != null and h < village.shelters.size() else null
	j.pos = (hd.pos + Vector2(-hd.size.x * 0.5 + 14.0, 26.0)) if hd != null else Vector2(360, 392)
	return j


## Подписи дела на языке игры: job.<вид>.title / place / done.
static func job_texts(j: JobDef) -> JobDef:
	var k: String = {JobDef.Kind.WATER: "water", JobDef.Kind.WOOD: "wood", JobDef.Kind.LAMP: "lamp",
		JobDef.Kind.TALISMAN: "talisman", JobDef.Kind.FISH: "fish", JobDef.Kind.BOX: "box"}.get(j.kind, "")
	if k != "":
		j.title = L.t("job.%s.title" % k)
		j.place = L.t("job.%s.place" % k)
		j.done_line = L.t("job.%s.done" % k) if j.kind != JobDef.Kind.BOX else ""
	return j


## Шанс погибнуть одному в доме: целый оберег снижает, расколотый — тварь из леса.
func alone_death_chance(h: int, p_out: float, press: float = 0.0) -> float:
	var p := p_out
	match talisman[h] if h >= 0 and h < talisman.size() else TALISMAN_MAX:
		TALISMAN_MAX:
			p = p_out * ALONE_SAFE
		0:
			p = maxf(p_out, CREATURE_KILL)
	return p if press == 0.0 else clampf(p + press, 0.0, 0.95)


func job_index(id: StringName) -> int:
	for i in range(jobs.size()):
		if jobs[i].id == id:
			return i
	return -1


func job_available(ji: int) -> bool:
	return ji >= 0 and ji < job_left.size() and job_left[ji] > 0


## Запасы дня 0..1.
func supplies() -> float:
	return float(supply_done) / float(supply_total) if supply_total > 0 else 0.0


func outside_death_chance() -> float:
	var p := config.outside_death_chance(day)
	if night_event != Event.RAIN:
		p -= SUPPLY_BONUS * supplies()
	match night_event:
		Event.FOG: p += FOG_DEATH
		Event.QUIET: p -= QUIET_SAFE
	return clampf(p, 0.05, 0.95)


## Сколько звонит колокол этой ночью: в тумане меньше.
func run_seconds() -> int:
	return maxi(5, config.run_seconds - (FOG_RUN if night_event == Event.FOG else 0))


# =============================================================
# Саботаж: упырь портит уже сделанное
# =============================================================
## Испортить сделанное у дела: запасы −1, порция возвращается делу — её можно сделать заново.
## Портить можно только там, где сегодня уже что-то сделали. Обереги не портятся.
func can_sabotage(ji: int) -> bool:
	return phase == Phase.DAY and ji >= 0 and ji < jobs.size() and supply_done > 0 \
		and jobs[ji].house < 0 and jobs[ji].kind != JobDef.Kind.BOX and job_left[ji] < jobs[ji].portions


func sabotage(ji: int) -> bool:
	if not can_sabotage(ji):
		return false
	job_left[ji] += 1
	supply_done -= 1
	return true


# =============================================================
# Ящик
# =============================================================
func _roll_box() -> void:
	box_today = false
	box_loot = Loot.NONE
	box_opened_by = -1
	if day < 2 or village == null or village.box_spots.is_empty() or rng.randf() >= BOX_P:
		return
	box_today = true
	box_pos = village.box_spots[rng.randi_range(0, village.box_spots.size() - 1)]
	var r := rng.randf()
	box_loot = Loot.NOTE if r < 0.5 else (Loot.OIL if r < 0.75 else Loot.CHALK)


## Ящик появился на площади: становится делом дня «Открыть ящик». Запасов не прибавляет.
func place_box() -> int:
	if not box_today or phase != Phase.DAY or job_index(&"box") >= 0:
		return job_index(&"box")
	var j := JobDef.new()
	j.id = &"box"
	j.kind = JobDef.Kind.BOX
	j.portions = 1
	j.work_sec = 3.0
	j.pos = box_pos
	job_texts(j)
	jobs.append(j)
	job_left.append(1)
	return jobs.size() - 1


## Открыть ящик. Ответ: {"loot": Loot, "a": Villager, "b": Villager, "house": int} или пусто, если уже открыт.
## Записка честная: ровно один из двоих — упырь. Что с ней делать — решает открывший.
func open_box(v: Villager) -> Dictionary:
	var ji := job_index(&"box")
	if ji < 0 or job_left[ji] <= 0 or v == null or not v.alive:
		return {}
	job_left[ji] = 0
	box_opened_by = v.id
	var loot := box_loot
	var out := {"loot": loot}
	if loot == Loot.NOTE:
		var ups: Array[Villager] = []
		var hums: Array[Villager] = []
		for o: Villager in alive():
			if o == v:
				continue
			if o.is_upyr:
				ups.append(o)
			else:
				hums.append(o)
		if ups.is_empty() or hums.is_empty():
			loot = Loot.OIL
		else:
			var pair: Array[Villager] = [ups[rng.randi_range(0, ups.size() - 1)], hums[rng.randi_range(0, hums.size() - 1)]]
			_shuffle(pair)
			out["a"] = pair[0]
			out["b"] = pair[1]
	if loot == Loot.CHALK:
		var worst := -1
		for h in range(talisman.size()):
			if talisman[h] < TALISMAN_MAX and (worst < 0 or talisman[h] < talisman[worst]):
				worst = h
		if worst < 0:
			loot = Loot.OIL
		else:
			talisman[worst] += 1
			out["house"] = worst
			var tj := job_index(StringName("talisman_%d" % worst))
			if tj >= 0:
				job_left[tj] = maxi(0, job_left[tj] - 1)
	if loot == Loot.OIL:
		supply_done = mini(supply_total, supply_done + BOX_OIL)
	out["loot"] = loot
	if loot == Loot.NOTE and out.has("a") and out.has("b"):
		box_notes.append({"owner": v.id, "day": day, "a": (out.a as Villager).id, "b": (out.b as Villager).id})
	return out


func end_day() -> void:
	assert(phase == Phase.DAY)
	clues.record_claims()
	_set_phase(Phase.VOTE if vote_open() else Phase.NIGHT)


## tally: id цели -> число голосов. Ничья решается жребием.
## Голос игрока — для разбора партии. Game зовёт перед apply_vote.
func note_player_vote(target: Villager) -> void:
	player_votes.append({"day": day, "who": target})


func apply_vote(tally: Dictionary[int, int], votes: Dictionary = {}) -> Villager:
	assert(phase == Phase.VOTE)
	last_tally = tally
	var best := -1
	var leaders: Array[int] = []
	for vid: int in tally:
		if tally[vid] > best:
			best = tally[vid]
			leaders = [vid]
		elif tally[vid] == best:
			leaders.append(vid)
	if not votes.is_empty():
		var cast_weight := 0
		for weight: int in tally.values():
			cast_weight += maxi(0, weight)
		var majority := floori(float(cast_weight) * 0.5) + 1
		if best < majority:
			leaders.clear()
	last_exiled = null
	if not leaders.is_empty():
		last_exiled = get_villager(leaders[rng.randi_range(0, leaders.size() - 1)])
		last_exiled.alive = false
		last_exiled.exiled = true
		last_exiled.exiled_day = day
		if not last_exiled.is_player:
			var words := Phrases.b("EXILE_WORDS")
			if not words.is_empty():
				last_exiled.last_words = L.fill(words[rng.randi_range(0, words.size() - 1)], {"me": last_exiled})
		_log("day", "log.exiled", {"who": last_exiled})
		world.add(WorldLog.Kind.EXILED, day, -1, last_exiled.id, -1, [], true)
	for voter: Variant in votes:
		world.add(WorldLog.Kind.VOTE, day, int(voter), int(votes[voter]), -1, [], true)
	vote_log.append({"day": day, "votes": votes.duplicate(), "exiled": last_exiled})
	if last_exiled != null and votes.has(0) and int(votes[0]) == last_exiled.id:
		trust_add(1 if last_exiled.is_upyr else -1, "exiled_upyr" if last_exiled.is_upyr else "wrong_exile")
	return last_exiled


func after_vote() -> void:
	assert(phase == Phase.VOTE)
	if last_exiled != null and not last_exiled.is_player and last_exiled.exiled_day == day \
			and rng.randf() < (FOREST_CALL_UPYR if last_exiled.is_upyr else FOREST_CALL_HUMAN):
		forest_call_day = day
	if _settle_winner():
		_set_phase(Phase.OVER)
	else:
		_set_phase(Phase.NIGHT)


## Рассадка на ночь. arrival — когда кто добежал до двери (секунды от колокола):
## первый добежавший внутри и решает, остальные в очереди в порядке прибытия.
## Кого нет в arrival, тот добегает после всех известных, между собой — в случайном порядке.
func seat_night(choices: Dictionary[int, int], arrival: Dictionary[int, float] = {}) -> void:
	assert(phase == Phase.NIGHT)
	seats.clear()
	healer_on.clear()
	tunnel_log.clear()
	_night_ids.clear()
	for v: Villager in alive():
		_night_ids.append(v.id)
	var buckets: Array = []
	for i in range(houses.size()):
		buckets.append([])
	for v: Villager in alive():
		if wander_plan.has(v.id) and not v.is_player:
			v.night_house = -1             # ушёл к реке на голос: ни к одной двери не пришёл
			continue
		var h: int = dry_house(clampi(choices.get(v.id, 0), 0, houses.size() - 1))
		v.night_house = h
		buckets[h].append(v)
	for i in range(houses.size()):
		var arrivals: Array = buckets[i]
		if arrivals.is_empty():
			continue
		_shuffle(arrivals)
		var key: Dictionary[int, float] = {}
		for k in range(arrivals.size()):
			var v: Villager = arrivals[k]
			key[v.id] = arrival.get(v.id, 1.0e6 + k)
		arrivals.sort_custom(func(a: Villager, b: Villager) -> bool: return key[a.id] < key[b.id])
		var s := Seat.new()
		s.house = i
		s.host = arrivals[0]
		for k in range(1, arrivals.size()):
			s.queue.append(arrivals[k])
		seats.append(s)
	_place_mimic()
	candle = 0
	_set_phase(Phase.DOOR)


const FLOOD_EXTRA := 0           ## половодье: на сколько мест теснее в сухих домах
const MILLER_CLUES := {"a2c1": "clue.miller_book", "a2c2": "clue.miller_sack", "a2c3": "clue.miller_lock"}


## «Чужаки» (TASK-023): тот, кто ходит под именем охотницы, — упырь. Роль меняется местами
## с другим упырём из местных, число упырей то же. Гостей с ролью по сюжету не трогаем.
## Если оба упыря выпали гостям со случайной ролью (одна партия из двенадцати во второй главе), берём роль у гостя.
func _force_upyr() -> void:
	if force_upyr_story < 0:
		return
	var target: Villager = null
	for v: Villager in villagers:
		if v.story_id == force_upyr_story and not v.is_player and v.guest_id.is_empty():
			target = v
	if target == null or target.is_upyr:
		return
	for v: Villager in villagers:
		if v.is_upyr and not v.is_player and v.guest_id.is_empty():
			v.is_upyr = false
			target.is_upyr = true
			return
	if guest_roles_fixed:
		return
	for v: Villager in villagers:
		if v.is_upyr and not v.is_player:
			v.is_upyr = false
			target.is_upyr = true
			return


## Все хозяева места этой главы: первый — главный.
func all_npcs() -> PackedStringArray:
	var out := PackedStringArray()
	if not npc_id.is_empty():
		out.append(npc_id)
	out.append_array(extra_npcs)
	return out


# =============================================================
# Акт III: книга поручительств, колокол, доверие (TASK-026, 028, 030)
# =============================================================
const TRUST_START := 3
const TRUST_MAX := 5


## Вписать имя в книгу у ворот. Игрок — одно имя в день. Ночью вписанный входит без вопросов.
func vouch(by: Villager, target: Villager) -> bool:
	if not vouch_on or phase != Phase.DAY or by == null or target == null or by == target or not target.alive or not by.alive:
		return false
	if by.is_player and vouch_day == day:
		return false
	for e: Dictionary in vouches:
		if int(e.by) == by.id and int(e.who) == target.id:
			return false
	vouches.append({"by": by.id, "who": target.id, "day": day})
	if by.is_player:
		vouch_day = day
	clues.add("vouch", target.id, L.t("clue.vouch", {"me": by, "who": target}), {"source": by.id})
	return true


## Кто поручился за жителя: id или -1. by >= 0 — только этот поручитель.
func voucher_of(target_id: int, by: int = -1) -> int:
	for e: Dictionary in vouches:
		if int(e.who) == target_id and (by < 0 or int(e.by) == by):
			return int(e.by)
	return -1


## Доверие группы: 0..5. Ноль — на следующем собрании голос игрока не считается.
func trust_add(d: int, why: String) -> void:
	if not trust_on or d == 0:
		return
	var before := trust
	trust = clampi(trust + d, 0, TRUST_MAX)
	trust_log.append({"day": day, "d": trust - before, "why": why})
	if trust == 0 and before > 0:
		trust_mute_day = day + (0 if phase == Phase.DAY else 1)
		_log("day", "log.trust_zero")


## Ночь со своим колоколом: в каждом доме, где упырь, колокол бьёт номер дома.
func _ring_bells() -> void:
	last_bells.clear()
	if not bell_on:
		return
	for s: Seat in seats:
		for v: Villager in s.inside():
			if v.is_upyr:
				last_bells.append(s.house + 1)
				_log("night", "log.bell", {"n": s.house + 1})
				break
	last_bells.sort()


## Доверие по итогам ночи у двери игрока: впустил упыря — падает, вдвойне если вписал его сам;
## впустил людей и все дожили — растёт.
func _night_trust(r: NightReport) -> void:
	if not trust_on:
		return
	var seat := player_seat()
	if seat == null or not seat.host.is_player:
		return
	var upyr_in := false
	var vouched_upyr := false
	var saved := 0
	for v: Villager in seat.admitted:
		if v.is_upyr:
			upyr_in = true
			if voucher_of(v.id, 0) >= 0:
				vouched_upyr = true
		elif v.alive:
			saved += 1
	if vouched_upyr:
		trust_add(-2, "vouched_upyr")
	elif upyr_in and not r.deaths().is_empty():
		trust_add(-1, "upyr_in")
	elif saved > 0 and r.deaths().filter(func(e: NightReport.Entry) -> bool: return e.house == seat.house).is_empty():
		trust_add(1, "saved")


# =============================================================
# Акт IV: список на поезд (TASK-033)
# =============================================================
## Мест в поезде: на четверых меньше, чем было людей в начале главы. Игрок едет всегда.
func train_cap() -> int:
	return maxi(3, config.players - 4)


func on_train(id: int) -> bool:
	for e: Dictionary in train_list:
		if int(e.who) == id:
			return true
	return false


## Вписать в список. Игрок — одно имя в день. Тайная запись не показывает, кто писал.
func train_add(by: Villager, who: Villager, secret: bool = false) -> bool:
	if not train_on or by == null or who == null or who.is_player or not who.alive or on_train(who.id):
		return false
	if train_struck.has(who.id) or train_list.size() >= train_cap():
		return false
	if by.is_player and train_write_day == day:
		return false
	train_list.append({"who": who.id, "by": by.id, "day": day, "secret": secret})
	if by.is_player:
		train_write_day = day
	if not secret:
		clues.add("vouch", who.id, L.t("clue.train", {"me": by, "who": who}), {"source": by.id})
	return true


## Вычеркнуть из списка. Игрок — одного в день; вычеркнутого обратно не впишут.
func train_strike(by: Villager, who: Villager) -> bool:
	if not train_on or by == null or who == null or not on_train(who.id):
		return false
	if by.is_player and train_strike_day == day:
		return false
	for i in range(train_list.size()):
		if int(train_list[i].who) == who.id:
			train_list.remove_at(i)
			break
	train_struck.append(who.id)
	if by.is_player:
		train_strike_day = day
	return true


## Кто из живых упырей в списке: поезд придёт с ними.
func train_upyrs() -> Array[Villager]:
	var out: Array[Villager] = []
	for e: Dictionary in train_list:
		var v := get_villager(int(e.who))
		if v != null and v.alive and v.is_upyr:
			out.append(v)
	return out


## Суд проигран (TASK-029): игрока изгоняют утром, глава идёт без него.
func exile_player() -> void:
	var p := player()
	if not p.alive:
		return
	p.alive = false
	p.exiled = true
	p.exiled_day = day
	world.add(WorldLog.Kind.EXILED, day, -1, p.id, -1, [], true)
	_log("day", "log.trial_exiled")
	_settle_winner()


## Низкие дома этой карты среди открытых убежищ (TASK-024).
func low_houses() -> Array[int]:
	var out: Array[int] = []
	if village != null:
		for h: int in village.low:
			if h >= 0 and h < houses.size():
				out.append(h)
	return out


## Половодье: лодка одна. Низкий дом, куда её отправили, остаётся сухим, другой заливает.
## В остальных домах становится теснее: место на одного больше.
func _start_flood() -> void:
	var low := low_houses()
	if low.size() < 2 or flooded_house >= 0:
		return
	var saved := flood_choice if low.has(flood_choice) else low[posmod(hash("flood:%d" % rng.seed), low.size())]
	flood_choice = saved
	for h: int in low:
		if h != saved:
			flooded_house = h
			break
	config.capacity += FLOOD_EXTRA
	talisman[flooded_house] = TALISMAN_MAX       # залитый дом не чинят
	_log("day", "log.flood", {"house": house_name(flooded_house)})


## Куда идти вместо залитого дома: следующий сухой.
func dry_house(h: int) -> int:
	if flooded_house < 0 or h != flooded_house or houses.size() < 2:
		return h
	return (h + 1) % houses.size()


## Гости занимают места приезжих с конца списка: постоянные жители и игрок остаются собой.
func _seat_guests() -> void:
	var slot := villagers.size() - 1
	for id: String in guests:
		if not Guests.LIST.has(id):
			continue
		while slot > 0 and (villagers[slot].anchor_id >= 0 or not villagers[slot].guest_id.is_empty()):
			slot -= 1
		if slot <= 0:
			return
		var v := villagers[slot]
		Guests.apply(self, v, id)
		if guest_roles_fixed:
			Guests.force_role(self, v, bool(Guests.LIST[id].upyr_in_campaign))
		slot -= 1


## Глава начинается сразу со стука (Task 63): колокола не было, игрок уже в доме, в дверь стучат
## двое людей. Остальные — по другим домам. Дальше партия идёт как обычно.
func cold_open(choices: Dictionary[int, int]) -> void:
	assert(phase == Phase.PROLOGUE)
	phase = Phase.NIGHT                    # без сигнала: экрана колокола не будет
	var arrival: Dictionary[int, float] = {0: 0.0}
	choices[0] = 0
	var knock: Array[Villager] = []
	# через раз один из двоих — упырь (TASK-013): сытый, но рядом с ним ночь будет неспокойной.
	# Свой генератор: ход партии от этого не меняется.
	var pick := RandomNumberGenerator.new()
	pick.seed = hash("cold:%d" % rng.seed)
	if pick.randf() < 0.5:
		for v: Villager in alive_bots():
			if v.is_upyr:
				knock.append(v)
				break
	for v: Villager in alive_bots():
		if not v.is_upyr and knock.size() < 2:
			knock.append(v)
	if pick.randf() < 0.5:
		knock.reverse()
	for v: Villager in alive_bots():
		if v.is_upyr:
			v.fed = true                   # первая ночь новичка: упырь ещё сыт, учиться можно без резни в доме
		if knock.has(v):
			choices[v.id] = 0
			arrival[v.id] = 1.0 + knock.find(v)
		elif int(choices.get(v.id, 0)) == 0:
			choices[v.id] = 1 % maxi(1, houses.size())
		v.announced_house = int(choices[v.id])
	seat_night(choices, arrival)


## Подражатель выбирает дверь и голос: житель не из этого дома — живой в другом месте или погибший.
func _place_mimic() -> void:
	if day < 2 or seats.is_empty() or night_event == Event.QUIET or rng.randf() >= MIMIC_P:
		return
	var s: Seat = seats[rng.randi_range(0, seats.size() - 1)]
	var voices: Array[Villager] = []
	for v: Villager in villagers:
		if v.is_player or v == s.host or s.queue.has(v):
			continue
		voices.append(v)
	if voices.is_empty():
		return
	s.mimic = voices[rng.randi_range(0, voices.size() - 1)]
	s.mimic_at = rng.randi_range(0, s.queue.size())


func admit(seat: Seat, ids: Array[int]) -> void:
	assert(phase == Phase.DOOR)
	seat.admitted.clear()
	seat.mimic_in = false
	var n := 0
	if vouch_on:
		# «Ворота»: за кого поручились, тот входит без вопросов (TASK-026)
		for v: Villager in seat.queue:
			if not ids.has(v.id) and voucher_of(v.id, 0 if seat.host.is_player else -1) >= 0:
				ids = ids.duplicate()
				ids.insert(0, v.id)
	for v: Villager in seat.knockers():
		if ids.has(v.id) and n < config.capacity - 1:
			n += 1
			if v == seat.mimic:
				seat.mimic_in = true
			else:
				seat.admitted.append(v)
			if seat.host.is_player:
				player_admits.append({"day": day, "who": v, "mimic": v == seat.mimic})
	seat.decided = true
	_log_door(seat)
	if seat.host.is_player or seat.queue.has(player()):
		clues.record_door(seat)
	if seat.host.is_player and seat.admitted.is_empty() and not seat.mimic_in and not seat.knockers().is_empty():
		player_refused_all += 1
	if not seat.host.is_player and seat.queue.has(player()) and not seat.admitted.has(player()):
		refused_player.append({"day": day, "by": seat.host})
	if seat.host.is_player and not today_dilemma.is_empty():
		_settle_dilemma(seat)


# =============================================================
# Обещания (TASK-004)
# =============================================================
## by обещает to: kind = open («открою, если постучишь») или come («приду к тебе ночевать»).
## Обещают днём, вслух: слышат все. Одно обещание от by к to за день, новое заменяет старое.
func promise(by: Villager, to: Villager, kind: String) -> bool:
	if phase != Phase.DAY or by == null or to == null or by == to or not by.alive or not to.alive \
			or not PROMISE_KINDS.has(kind):
		return false
	for i in range(promises.size() - 1, -1, -1):
		var p := promises[i]
		if int(p.day) == day and int(p.by) == by.id and int(p.to) == to.id:
			promises.remove_at(i)
	promises.append({"day": day, "by": by.id, "to": to.id, "kind": kind, "state": ""})
	world.add(WorldLog.Kind.PROMISE, day, by.id, to.id, -1, [], true, {"promise": kind})
	return true


## Обещания этого дня от by (или кому угодно, by = -1) к to.
func promises_today(by: int = -1, to: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in promises:
		if int(p.day) == day and (by < 0 or int(p.by) == by) and (to < 0 or int(p.to) == to):
			out.append(p)
	return out


## Где житель был этой ночью: дом, где ночевал, а если не пустили — у какой двери стоял.
func _night_spot(v: Villager) -> int:
	if v.night_house >= 0:
		return v.night_house
	var e := world.last(WorldLog.Kind.REFUSE, -1, v.id, day)
	return e.house if e != null else -1


## Ночь прошла: каждое обещание этого дня сдержано, нарушено или не пригодилось (void).
func _settle_promises() -> void:
	for p: Dictionary in promises:
		if int(p.day) != day or String(p.state) != "":
			continue
		var by := get_villager(int(p.by))
		var to := get_villager(int(p.to))
		p.state = "void"
		if by == null or to == null or not _night_ids.has(by.id) or not _night_ids.has(to.id):
			continue
		match String(p.kind):
			"open":
				if world.last(WorldLog.Kind.ADMIT, by.id, to.id, day) != null:
					p.state = "kept"
				elif world.last(WorldLog.Kind.REFUSE, by.id, to.id, day) != null:
					p.state = "broken"
			"come":
				var a := _night_spot(by)
				p.state = "kept" if a >= 0 and a == _night_spot(to) else "broken"
		if String(p.state) != "void":
			world.add(WorldLog.Kind.PROMISE_KEPT if p.state == "kept" else WorldLog.Kind.PROMISE_BROKEN,
				day, by.id, to.id, -1, [by.id, to.id], false, {"promise": String(p.kind)})


## Журнал: кого у этой двери впустили и кому отказали. Видели все, кто был в доме и стучал.
func _log_door(seat: Seat) -> void:
	world.drop_door(day, seat.house)        # решение у этой двери переиграли: прежняя запись не в счёт
	var witnesses: Array[int] = []
	for v: Villager in seat.inside():
		witnesses.append(v.id)
	for v: Villager in seat.queue:
		if not witnesses.has(v.id):
			witnesses.append(v.id)
	for v: Villager in seat.admitted:
		world.add(WorldLog.Kind.ADMIT, day, seat.host.id, v.id, seat.house, witnesses)
	if seat.mimic_in:
		world.add(WorldLog.Kind.ADMIT, day, seat.host.id, seat.mimic.id, seat.house, witnesses, false, {"mimic": true})
	# мест не осталось: впущено столько, сколько вмещает дом — отказ вынужденный (TASK-010)
	var full := seat.admitted.size() + (1 if seat.mimic_in else 0) >= config.capacity - 1
	for v: Villager in seat.turned_away():
		world.add(WorldLog.Kind.REFUSE, day, seat.host.id, v.id, seat.house, witnesses, false, {"full": full})


func record_door_inspection(v: Villager, tell: StringName, house: int = -1, mimic: bool = false) -> void:
	if v == null or tell == &"" or v == get_villager(0):
		return
	for record: Dictionary in door_inspections:
		if int(record.get("day", -1)) == day and int(record.get("villager", -1)) == v.id:
			return
	door_inspections.append({"day": day, "villager": v.id, "name": v.name, "tell": String(tell), "house": house, "mimic": mimic})


## Записка считается уликой только у того жителя, который действительно нашёл её в ящике.
## Подражатель может носить чужое лицо, но не получает чужие предметы.
func door_note_for(visitor: Villager) -> Dictionary:
	if visitor == null or get_villager(visitor.id) != visitor:
		return {}
	for i in range(box_notes.size() - 1, -1, -1):
		var note := box_notes[i]
		if int(note.get("owner", -1)) == visitor.id:
			return note.duplicate()
	return {}


func earn_question_token() -> bool:
	if question_tokens >= QUESTION_TOKEN_MAX:
		return false
	question_tokens += 1
	return true


func spend_question_token() -> bool:
	if question_tokens <= 0 or question_used_day == day:
		return false
	question_tokens -= 1
	question_used_day = day
	return true


## Мигнёт ли свеча перед стуком (TASK-077): у упыря или Подражателя за дверью часто, у людей редко.
## Это только картинка и звук: очередь и исход ночи от неё не зависят.
func door_flicker(seat: Seat) -> bool:
	if seat == null:
		return false
	var creature := seat.mimic != null
	for v: Villager in seat.knockers():
		if v.is_upyr:
			creature = true
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("flicker:%d:%d:%d" % [day, seat.house, case_id])
	return dice.randf() < (FLICKER_CREATURE if creature else FLICKER_EMPTY)


## Свеча видна только у двери, где хозяин игрок. Боты свечой не пользуются.
func candle_for(seat: Seat) -> int:
	return candle if seat != null and seat.host != null and seat.host.is_player else 0


func set_candle(level: int) -> void:
	if phase == Phase.DOOR:
		candle = clampi(level, -1, 1)


## Тварь за дверью (упырь, которому отказали, или голос Подражателя) давит на дом: яркая свеча усиливает, тусклая ослабляет.
func candle_press(seat: Seat) -> float:
	var level := candle_for(seat)
	if level == 0:
		return 0.0
	var outside := seat.mimic != null and not seat.mimic_in
	for v: Villager in seat.turned_away():
		if v.is_upyr:
			outside = true
	return CANDLE_PRESS * float(level) if outside else 0.0


func door_sign_for(visitor: Villager, seat: Seat) -> StringName:
	if visitor == null or seat == null:
		return &"ordinary"
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("door-sign:%d:%d:%d:%d" % [day, visitor.id, seat.house, case_id])
	var is_creature := visitor == seat.mimic or visitor.is_upyr
	var lamp := candle_for(seat) + 1
	if dice.randf() >= (CANDLE_TELL_CREATURE[lamp] if is_creature else CANDLE_TELL_HUMAN[lamp]):
		return &"ordinary"
	var preferred: StringName = [&"breath", &"shadow", &"rhythm"][posmod(case_id, 3)]
	if dice.randf() < 0.55:
		return preferred
	var signs: Array[StringName] = [&"breath", &"rhythm", &"shadow"]
	signs.erase(preferred)
	return signs[dice.randi_range(0, signs.size() - 1)]


## Личные наблюдения хозяина. Два осмотра за ночь; повтор не тратит второй осмотр.
func inspect_visitor(seat: Seat, vid: int, limit: int = 2) -> StringName:
	if phase != Phase.DOOR or seat == null or seat.host == null or seat.decided or not seat.host.is_player:
		return &""
	var used := 0
	for record: Dictionary in door_inspections:
		if int(record.day) != day:
			continue
		used += 1
		if int(record.villager) == vid:
			return &""
	if used >= limit:
		return &""
	for visitor: Villager in seat.knockers():
		if visitor.id == vid:
			var tell := door_sign_for(visitor, seat)
			record_door_inspection(visitor, tell, seat.house, visitor == seat.mimic)
			return tell
	return &""


func resolve_night() -> NightReport:
	assert(phase == Phase.DOOR)
	var r := NightReport.new()
	var p_out := outside_death_chance()
	r.p_out = p_out
	for s0: Seat in seats:
		r.p_alone[s0.house] = alone_death_chance(s0.house, p_out, candle_press(s0))
	if supply_total > 0:
		_log("night", "log.supplies", {"p": roundi(100.0 * supplies())})

	var was_fed: Dictionary[int, bool] = {}
	for v: Villager in villagers:
		if v.fed:
			was_fed[v.id] = true
		v.fed = false

	# 0. Кто пролез туннелем — утром это знают все
	for t: Array in tunnel_log:
		var et := r.add(NightReport.Kind.TUNNEL, t[0], t[2])
		et.said_house = t[1]
		_log("night", "log.tunnel", {"who": t[0], "from": house_name(t[1]), "house": house_name(t[2])})

	# 1. Кого не пустили — улица
	for s: Seat in seats:
		for v: Villager in s.turned_away():
			v.night_house = -1
			if opening_night_protects(v):
				r.add(NightReport.Kind.SURVIVED_STREET, v, s.house)
				_log("night", "log.street_ok", {"who": v})
			elif v.is_upyr:
				r.add(NightReport.Kind.SURVIVED_STREET, v, s.house)
				_log("night", "log.street_upyr", {"who": v, "house": house_name(s.house)})
			elif rng.randf() < p_out:
				v.alive = false
				r.add(NightReport.Kind.KILLED_STREET, v, s.house)
				_log("night", "log.street_dead", {"who": v, "house": house_name(s.house)})
			else:
				r.add(NightReport.Kind.SURVIVED_STREET, v, s.house)
				_log("night", "log.street_ok", {"who": v})

	# 1а. Отчаяние: ушёл ночью к реке на голос (TASK-008). Упырю река не страшна.
	for vid: int in wander_plan:
		var w := get_villager(vid)
		if w == null or not w.alive:
			continue
		var ew: NightReport.Entry
		if not opening_night_protects(w) and not w.is_upyr and rng.randf() < p_out:
			w.alive = false
			ew = r.add(NightReport.Kind.KILLED_STREET, w, -1)
			_log("night", "log.river_dead", {"who": w})
		else:
			ew = r.add(NightReport.Kind.SURVIVED_STREET, w, -1)
			_log("night", "log.river_ok", {"who": w})
		ew.cause = "river"
	wander_plan.clear()

	# 1б. Подражатель: впустили — забирает одного из тех, кто внутри. Не впустили — стук слышали все.
	for s: Seat in seats:
		if s.mimic == null:
			continue
		if not s.mimic_in:
			var ek := r.add(NightReport.Kind.MIMIC_KNOCK, null, s.house)
			ek.voice = s.mimic
			_log("night", "log.mimic_knock", {"house": house_name(s.house), "voice": s.mimic})
			continue
		var inside3: Array[Villager] = []
		for v: Villager in s.inside():
			if v.alive and not opening_night_protects(v):
				inside3.append(v)
		if inside3.is_empty() or rng.randf() >= MIMIC_KILL:
			var es := r.add(NightReport.Kind.MIMIC_SPARED, null, s.house)
			es.voice = s.mimic
			_log("night", "log.mimic_spared", {"house": house_name(s.house), "voice": s.mimic})
			continue
		var gone: Villager = inside3[rng.randi_range(0, inside3.size() - 1)]
		if _healed(s, gone, r, "mimic"):
			continue
		gone.alive = false
		var left: Array[Villager] = []
		for v: Villager in inside3:
			if v != gone:
				left.append(v)
		var em := r.add(NightReport.Kind.KILLED_MIMIC, gone, s.house, left)
		em.voice = s.mimic
		_log("night", "log.mimic_kill", {"house": house_name(s.house), "voice": s.mimic, "who": gone})

	# 2. Что было за дверьми. Кто остался один после визита Подражателя, до утра в безопасности:
	# тварь насытилась или ушла, второй раз за ночь в этот дом никто не придёт.
	for s: Seat in seats:
		var inside: Array[Villager] = s.inside().filter(func(v: Villager) -> bool: return v.alive)
		if inside.is_empty():
			continue
		if s.mimic_in and inside.size() == 1:
			continue
		if inside.size() == 1:
			var lone: Villager = inside[0]
			if opening_night_protects(lone):
				r.add(NightReport.Kind.SURVIVED_ALONE, lone, s.house)
			elif lone.is_upyr:
				r.add(NightReport.Kind.SURVIVED_ALONE, lone, s.house)
			elif rng.randf() < alone_death_chance(s.house, p_out, candle_press(s)):
				lone.alive = false
				r.add(NightReport.Kind.KILLED_ALONE, lone, s.house)
				_log("night", "log.alone_dead", {"who": lone, "house": house_name(s.house)})
			else:
				r.add(NightReport.Kind.SURVIVED_ALONE, lone, s.house)
			continue

		var hungry: Array[Villager] = []
		var humans: Array[Villager] = []
		for v: Villager in inside:
			if v.is_upyr and not was_fed.has(v.id):
				hungry.append(v)
			elif not v.is_upyr and not opening_night_protects(v):
				humans.append(v)

		if not hungry.is_empty() and not humans.is_empty():
			var killer: Villager = hungry[rng.randi_range(0, hungry.size() - 1)]
			var victim: Villager = humans[rng.randi_range(0, humans.size() - 1)]
			killer.fed = true
			if _healed(s, victim, r, "upyr"):
				continue
			victim.alive = false
			var others: Array[Villager] = []
			for v: Villager in inside:
				if v != victim:
					others.append(v)
			var ek := r.add(NightReport.Kind.KILLED_INSIDE, victim, s.house, others)
			ek.killer = killer
			if killer.is_player:
				player_kills += 1
			_log("night", "log.killed", {"who": victim, "house": house_name(s.house), "others": others})
		else:
			# все люди — или упырь сытый. Снаружи не отличить, и в этом весь смысл.
			r.add(NightReport.Kind.CLEAN_ROOM, s.host, s.house, inside.duplicate())
			_log("night", "log.clean", {"house": house_name(s.house), "list": inside})

	# 2б. Расколотый оберег: в дом, где ночевали несколько, входит тварь из леса
	for s: Seat in seats:
		var inside2 := s.inside()
		if inside2.size() < 2 or s.house >= talisman.size() or talisman[s.house] > 0:
			continue
		var prey: Array[Villager] = []
		for v: Villager in inside2:
			if v.alive and not v.is_upyr and not opening_night_protects(v):
				prey.append(v)
		if prey.is_empty() or rng.randf() >= CREATURE_KILL + candle_press(s):
			continue
		var taken: Villager = prey[rng.randi_range(0, prey.size() - 1)]
		if _healed(s, taken, r, "creature"):
			continue
		taken.alive = false
		var rest: Array[Villager] = []
		for v: Villager in inside2:
			if v != taken:
				rest.append(v)
		r.add(NightReport.Kind.KILLED_CREATURE, taken, s.house, rest)
		_log("night", "log.creature", {"house": house_name(s.house), "who": taken})

	# 3. Сказал одно — ночевал в другом месте
	for v: Villager in villagers:
		if v.announced_house >= 0 and v.night_house >= 0 and v.night_house != v.announced_house:
			var e := r.add(NightReport.Kind.LIAR, v, v.night_house)
			e.said_house = v.announced_house
			_log("night", "log.liar", {"who": v, "said": house_name(v.announced_house), "house": house_name(v.night_house)})

	# 4. За ночь обереги слабеют
	for h in range(talisman.size()):
		if talisman[h] > 0 and (night_event == Event.MOON or rng.randf() < TALISMAN_DECAY):
			talisman[h] -= 1
			r.add(NightReport.Kind.TALISMAN_WORN, null, h)
			_log("morning", "log.talisman_cracked" if talisman[h] == 1 else "log.talisman_broken", {"house": house_name(h)})

	# кто был хозяином двери у каждого события — для разбора «почему ты погиб»
	for e: NightReport.Entry in r.entries:
		var st := _seat_of_house(e.house)
		if st != null:
			e.host = st.host
		if e.is_death() and e.who != null and e.who.is_player:
			player_death = e

	# журнал: кто погиб (утром это знают все), чем кончились обещания, кто кому что рассказал
	_settle_promises()
	for e: NightReport.Entry in r.deaths():
		if e.who == null:
			continue
		var info := {"cause": String(NightReport.Kind.keys()[e.kind]).to_lower()}
		if e.kind == NightReport.Kind.KILLED_STREET and e.host != null:
			info["refused_by"] = e.host.id
		world.add(WorldLog.Kind.DIED, day, -1, e.who.id, e.house, [], true, info)
	_spread_news()

	# дневник: кто где был этой ночью и кого не стало
	var rec := {"day": day, "where": {}, "said": {}, "dead": []}
	for vid: int in _night_ids:
		var v := get_villager(vid)
		rec.where[vid] = v.night_house
		rec.said[vid] = v.announced_house
	for e: NightReport.Entry in r.deaths():
		rec.dead.append(e.who.id)
	history.append(rec)

	_dilemma_fate(r)
	_apply_grief(r)
	feelings.morning(r)
	_sail(r)
	_ring_bells()
	_night_trust(r)
	report = r
	_settle_winner()
	_set_phase(Phase.MORNING)
	return r


## Дилемма у двери игрока: кто стучит и чем грозит выбор. Пусто — обычная ночь.
## Виды: пара на одно место, тот, кто не открыл тебе, тот, против кого ты голосовал,
## тот, кто тебя обвинял, горюющий, толпа на одно место, принёсший масло. Из подходящих — случайный вид.
func door_dilemma(seat: Seat) -> Dictionary:
	today_dilemma = {}
	if seat == null or not seat.host.is_player or dilemmas.size() >= DILEMMA_MAX:
		return today_dilemma
	for d: Dictionary in dilemmas:
		if int(d.day) == day:
			return today_dilemma
	var knock := seat.queue
	if knock.is_empty():
		return today_dilemma
	var cap := config.capacity - 1
	var options: Array[Dictionary] = []
	if knock.size() > cap:
		for a: Villager in knock:
			for b: Villager in knock:
				if a.id < b.id and (a.partner_id == b.id or a.family_id == b.id):
					options.append({"kind": "couple", "who": a.id, "other": b.id})
	for rec: Dictionary in refused_player:
		var by: Villager = rec.by
		if int(rec.day) < day and knock.has(by):
			options.append({"kind": "refuser", "who": by.id, "other": -1})
	for rec: Dictionary in player_votes:
		var target: Villager = rec.who
		if int(rec.day) == day and target != null and knock.has(target):
			options.append({"kind": "voted", "who": target.id, "other": -1})
	for v: Villager in knock:
		if accused_player.get(v.id, -1) == day:
			options.append({"kind": "accuser", "who": v.id, "other": -1})
		if v.grief_days > 0 and v.grief_for >= 0:
			options.append({"kind": "grieving", "who": v.id, "other": v.grief_for})
	if knock.size() >= cap + 2:
		options.append({"kind": "crowd", "who": knock[0].id, "other": -1})
	if seat.house < talisman.size() and talisman[seat.house] < TALISMAN_MAX and rng.randf() < DILEMMA_OIL_P:
		options.append({"kind": "oil", "who": knock[rng.randi_range(0, knock.size() - 1)].id, "other": -1})
	# одинаковые виды не должны вытеснять редкие: сначала вид, потом случай этого вида
	var by_kind: Dictionary = {}
	for o: Dictionary in options:
		if not by_kind.has(o.kind):
			by_kind[o.kind] = []
		(by_kind[o.kind] as Array).append(o)
	var found := {}
	if not by_kind.is_empty():
		var ks: Array = by_kind.keys()
		var pool: Array = by_kind[ks[rng.randi_range(0, ks.size() - 1)]]
		found = (pool[rng.randi_range(0, pool.size() - 1)] as Dictionary).duplicate()
	if not found.is_empty():
		found["day"] = day
		found["house"] = seat.house
		today_dilemma = found
	return today_dilemma


## Игрок решил: запомнить выбор и сразу применить цену, которая видна до утра.
func _settle_dilemma(seat: Seat) -> void:
	var d := today_dilemma
	today_dilemma = {}
	var who := get_villager(int(d.who))
	if who == null:
		return
	d["admitted"] = seat.admitted.has(who)
	d["other_admitted"] = int(d.other) >= 0 and seat.admitted.has(get_villager(int(d.other)))
	d["fate"] = ""
	match String(d.kind):
		"oil":
			if bool(d.admitted):
				talisman[seat.house] = mini(TALISMAN_MAX, talisman[seat.house] + 1)
				_log("night", "log.oil", {"who": who, "house": house_name(seat.house)})
		"refuser":
			if bool(d.admitted):
				owes_player[who.id] = true
	var seen: Array[int] = []
	for v: Villager in seat.inside():
		seen.append(v.id)
	world.add(WorldLog.Kind.DILEMMA, day, seat.host.id, who.id, seat.house, seen, false,
		{"dilemma": String(d.kind), "admitted": bool(d.admitted)})
	dilemmas.append(d)


## Утро после дилеммы: что стало с тем, из-за кого был выбор.
func _dilemma_fate(r: NightReport) -> void:
	for d: Dictionary in dilemmas:
		if int(d.day) != day or String(d.get("fate", "x")) != "":
			continue
		d.fate = "alive"
		for e: NightReport.Entry in r.deaths():
			if e.who != null and e.who.id == int(d.who):
				d.fate = "street" if e.kind == NightReport.Kind.KILLED_STREET else ("inside" if e.house == int(d.house) else "other")


## Траур: у погибшего ночью остаются близкие (муж, жена, мать, сын). Они два дня горюют:
## не работают, говорят о погибшем и винят хозяина двери, если того не пустили.
## Последние слова погибшего достаются утренней сцене. Скрытые роли на это не влияют.
const GRIEF_DAYS := 2


## Прощание (TASK-020): игрок днём выбрал, кого отправить на лодке. Только в главе «Прощание», раз за главу.
func send_away(v: Villager) -> bool:
	if phase != Phase.DAY or send_used or v == null or v.is_player or not v.alive or plant_chapter != "a1c3":
		return false
	send_away_id = v.id
	send_used = true
	return true


## Рассвет: лодка уходит. Человек уплывает (иногда передумывает), упырь возвращается: река его не берёт.
## Уплывший жив и придёт в следующих главах, но в этой деревне на одного человека меньше.
func _sail(r: NightReport) -> void:
	var v := get_villager(send_away_id)
	send_away_id = -1
	if v == null or not v.alive:
		return
	var back := v.is_upyr
	if not back:
		var pr := RandomNumberGenerator.new()
		pr.seed = hash("sail:%d:%d" % [v.id, rng.seed])
		back = pr.randf() < SEND_BACK_HUMAN
	var e := r.add(NightReport.Kind.SURVIVED_ALONE, v, -1)
	if back:
		e.cause = "boat_back"
		_log("morning", "log.sent_back", {"who": v})
	else:
		e.cause = "boat"
		v.alive = false
		v.departed = true
		_log("morning", "log.sent", {"who": v})
	_settle_winner()


## Утром новости расходятся (TASK-003). Кого не пустили и кто дожил до утра, рассказывает своим.
## Кто не дожил, за того рассказывают те, кто был рядом с дверью: был в доме или стоял в очереди.
## Хозяин двери о своём отказе молчит. Если рядом не было никого, отказ остаётся тайной.
func _spread_news() -> void:
	for e: WorldLog.Event in world.of(WorldLog.Kind.REFUSE, day):
		var refused := get_villager(e.target)
		if refused == null:
			continue
		var teller: Villager = null
		if refused.alive:
			teller = refused
		else:
			var ids: Array = e.known.keys()
			ids.sort()
			for wid: Variant in ids:
				var w := get_villager(int(wid))
				if w != null and w.alive and w.id != e.actor and w.id != refused.id and not w.is_player:
					teller = w
					break
		if teller == null:
			continue
		for kin: Villager in kin_of(refused):
			world.tell(e, kin.id, teller.id)


## Близкие жителя: пара и семья. Только живые.
func kin_of(v: Villager) -> Array[Villager]:
	var out: Array[Villager] = []
	for k: Villager in villagers:
		if k != v and k.alive and (k.partner_id == v.id or k.family_id == v.id or v.partner_id == k.id or v.family_id == k.id):
			out.append(k)
	return out


func _apply_grief(r: NightReport) -> void:
	for v: Villager in villagers:
		if v.grief_days > 0:
			v.grief_days -= 1
			if v.grief_days == 0:
				v.grief_for = -1
				v.blame_id = -1
				v.blame_via = -1
	for e: NightReport.Entry in r.deaths():
		var lost := e.who
		if lost == null or lost.is_player:
			continue
		var words := Phrases.b("LAST_WORDS")
		var own := Voices.lines(lost.persona, "LAST_WORDS")
		var pool_w := own if not own.is_empty() else words
		if not pool_w.is_empty():
			lost.last_words = L.fill(pool_w[rng.randi_range(0, pool_w.size() - 1)], {"me": lost})
		for kin: Villager in villagers:
			if kin == lost or not kin.alive or kin.is_player:
				continue
			if kin.partner_id != lost.id and kin.family_id != lost.id:
				continue
			kin.grief_for = lost.id
			kin.grief_days = GRIEF_DAYS
			kin.grief_comforted = false
			griefs += 1
			kin.blame_id = -1
			kin.blame_via = -1
			# не пустили — виноват тот, кто держал дверь. Но только если близкий об этом знает (TASK-003)
			if e.kind == NightReport.Kind.KILLED_STREET and e.host != null and e.host != kin and e.host.alive:
				var refusal := world.last(WorldLog.Kind.REFUSE, e.host.id, lost.id, day)
				var src := world.source(kin.id, refusal)
				if not src.is_empty():
					kin.blame_id = e.host.id
					kin.blame_via = int(src.via)


## Близкие, которые сейчас в трауре по lost.
func mourners(lost: Villager) -> Array[Villager]:
	var out: Array[Villager] = []
	for v: Villager in villagers:
		if v.alive and v.grief_for == lost.id:
			out.append(v)
	return out


func end_morning() -> void:
	assert(phase == Phase.MORNING)
	if winner == Team.NONE and day >= config.nights:
		winner = Team.PEOPLE
	if winner != Team.NONE:
		_set_phase(Phase.OVER)
		return
	day += 1
	begin_day()


# =============================================================
# Роли
# =============================================================
func _deal_roles() -> void:
	var hums: Array = []
	for v: Villager in villagers:
		v.role = Role.NONE
		v.role_used = false
		if not v.is_upyr:
			hums.append(v)
	_shuffle(hums)
	var roles := [Role.ELDER, Role.HEALER, Role.HEADMAN]
	if rule == "no_elder":
		roles.erase(Role.ELDER)
	for k in range(mini(roles.size(), hums.size() - 1)):
		(hums[k] as Villager).role = roles[k]


## Название роли. mid — как пишется внутри фразы («знахарка Рита»; в немецком остаётся с заглавной).
static func role_name(v: Villager, mid: bool = false) -> String:
	var k: String = {Role.ELDER: "elder", Role.HEALER: "healer", Role.HEADMAN: "headman"}.get(v.role, "")
	if k == "":
		return ""
	return L.t("role.%s%s" % [k, ".mid" if mid else ""], {"who": v})


func role_holder(r: int) -> Villager:
	for v: Villager in villagers:
		if v.role == r:
			return v
	return null


## Старожил смотрит рисунки: упырь ли target. Один раз за партию, только днём.
## Ответ: 1 — упырь, 0 — человек, -1 — нельзя (не Старожил, уже смотрел, не день).
func elder_check(by: Villager, target: Villager) -> int:
	if phase != Phase.DAY or by == null or target == null or by.role != Role.ELDER or by.role_used or not by.alive or target == by:
		return -1
	by.role_used = true
	if by.is_player:
		player_seen[target.id] = 1 if target.is_upyr else 0
	return 1 if target.is_upyr else 0


## Знахарка берёт травы на эту ночь: если рядом с ней в доме кого-то убьют, она его выходит.
func heal_tonight(v: Villager) -> bool:
	if v == null or not v.alive or v.role != Role.HEALER or v.role_used or not (phase == Phase.NIGHT or phase == Phase.DOOR):
		return false
	healer_on[v.id] = true
	return true


## Выходит ли Знахарка того, на кого напали в доме seat. Тратит способность.
func _healed(s: Seat, victim: Villager, r: NightReport, cause: String) -> bool:
	for h: Villager in s.inside():
		if h != victim and h.alive and healer_on.get(h.id, false) and not h.role_used:
			h.role_used = true
			healer_on.erase(h.id)
			claim(h, victim, L.t("claim.healer", {"role": role_name(h), "me": h, "who": victim, "n": day}))
			var e := r.add(NightReport.Kind.SAVED, victim, s.house, [h] as Array[Villager])
			e.cause = cause
			_log("night", "log.saved", {"house": house_name(s.house), "who": victim, "h": h, "healer": healer_named(h)})
			return true
	return false


## «знахарка Рита» или «вы» — кто выходил раненого.
static func healer_named(h: Villager) -> String:
	if h.is_player:
		return L.render(h, "")
	return L.t("role.named", {"role": role_name(h, true), "who": h})


## Сколько весит голос на изгнании: у Старосты — два.
func vote_weight(vid: int) -> int:
	if vid == 0 and trust_on and trust_mute_day == day:
		return 0                                  # деревня не слушает игрока (TASK-030)
	var v := get_villager(vid)
	return 2 if v != null and v.alive and v.role == Role.HEADMAN else 1


# =============================================================
# Экстренный сбор
# =============================================================
func can_meeting(v: Villager) -> bool:
	return phase == Phase.DAY and v != null and v.alive and not meeting_used.has(v.id)


func call_meeting(v: Villager) -> bool:
	if not can_meeting(v):
		return false
	meeting_used[v.id] = true
	meeting_by = v.id
	_log("day", "log.meeting", {"who": v})
	_set_phase(Phase.VOTE)
	return true


# =============================================================
# Туннель
# =============================================================
## Куда ведёт туннель из дома h. -1 — из этого дома хода нет.
func tunnel_to(h: int) -> int:
	if tunnel.x < 0 or (flooded_house >= 0 and (tunnel.x == flooded_house or tunnel.y == flooded_house)):
		return -1                 # ход в залитый дом затоплен (TASK-024)
	if h == tunnel.x:
		return tunnel.y
	if h == tunnel.y:
		return tunnel.x
	return -1


func _seat_of_house(h: int) -> Seat:
	for s: Seat in seats:
		if s.house == h:
			return s
	return null


## Есть ли место на том конце туннеля из дома h.
func tunnel_room(h: int) -> bool:
	var to := tunnel_to(h)
	if to < 0:
		return false
	var s := _seat_of_house(to)
	return s == null or s.inside().size() < config.capacity


## После дверей, до ночи: кого не пустили у дома с туннелем, тот может пролезть на другой конец.
## Игрок лезет, если выбрал это сам (player_goes). Хозяин того дома пролезшего не выбирает.
func tunnel_pass(player_goes: bool) -> void:
	assert(phase == Phase.DOOR)
	tunnel_log.clear()
	if tunnel.x < 0:
		return
	var order: Array[Villager] = []
	for s: Seat in seats:
		if tunnel_to(s.house) >= 0:
			for v: Villager in s.turned_away():
				if v.is_player:
					order.push_front(v)    # игрок решил первым
				else:
					order.append(v)
	for v: Villager in order:
		var from := v.night_house
		var wants := player_goes if v.is_player else rng.randf() < (TUNNEL_UPYR if v.is_upyr else TUNNEL_HUMAN)
		if not wants or not tunnel_room(from):
			continue
		var to := tunnel_to(from)
		var src := _seat_of_house(from)
		src.queue.erase(v)
		var dst := _seat_of_house(to)
		if dst == null:
			dst = Seat.new()
			dst.house = to
			dst.host = v
			dst.decided = true
			seats.append(dst)
		else:
			dst.admitted.append(v)
		v.night_house = to
		tunnel_log.append([v, from, to])


# =============================================================
func _settle_winner() -> bool:
	if humans_alive() == 0:
		winner = Team.UPYRI
	elif upyri_alive() == 0:
		winner = Team.PEOPLE
	return winner != Team.NONE


func _set_phase(p: Phase) -> void:
	phase = p
	if p == Phase.NIGHT:
		_roll_event()
	phase_changed.emit(p)


func _roll_event() -> void:
	night_event = Event.NONE
	var always := Challenge.night_event(rule)
	if always != Event.NONE:
		night_event = always            # испытание дня: одно событие все ночи, с первой
	elif day < 2:
		return
	elif force_event >= 0:
		night_event = force_event as Event
	elif rng.randf() < EVENT_P:
		night_event = (rng.randi_range(1, Event.size() - 1)) as Event
	if night_event != Event.NONE:
		_log("night", "log.event", {"e": event_title(night_event, true)})


## Строка хроники. when: night, day или morning («Утром: …» идёт в раздел прошлой ночи).
func _log(when: String, key: String, args: Dictionary = {}) -> void:
	var text := L.t(key, args)
	var title := ""
	if when == "night" or when == "day":
		title = L.t("when." + when, {"n": day})
	chronicle.append(L.t("chron.line", {"title": title, "text": text}) if title != "" else L.t("chron.morning", {"text": text}))
	chron.append({"title": title, "text": text})




func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t

func _quick_cast_has_partner_pair(indices: Array, names: Array) -> bool:
	for i in range(indices.size()):
		var first_id := int(indices[i])
		if first_id == 8 or SocialContent.story_age(first_id) >= 55:
			continue
		var first_data: Array = names[first_id]
		for j in range(i + 1, indices.size()):
			var second_id := int(indices[j])
			if second_id == 8 or SocialContent.story_age(second_id) >= 55:
				continue
			var second_data: Array = names[second_id]
			if bool(first_data[1]) == bool(second_data[1]) or _authored_relation_pair(first_id, second_id):
				continue
			return true
	return false


func _authored_relation_pair(first_id: int, second_id: int) -> bool:
	for relation: Array in FAMILIES + TIES:
		if (first_id == int(relation[0]) and second_id == int(relation[1])) or (first_id == int(relation[1]) and second_id == int(relation[0])):
			return true
	return false
