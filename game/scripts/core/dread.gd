class_name Dread
extends RefCounted
## Звуки страха (Task 57): когда и что слышно ночью. Файлы — assets/sfx, их делает tools/make_dread.py,
## любой можно заменить записью с тем же именем.
## Правило: резкий удар (scare) — не чаще одного раза за ночь и не в первую ночь.
## Тихие звуки (царапанье, шёпот, шаги) не подсказывают роль: звучат по случаю, не по тому, кто за дверью.

const SOUNDS: Array[StringName] = [&"scratch", &"whisper", &"roof_steps", &"creak", &"cry_far",
	&"growl", &"gasp", &"call_far", &"scare", &"weep"]
const SCRATCH_P := 0.45      ## у двери хозяина после стука: кто-то ведёт когтями по доскам
const RUN_CRY_P := 0.4       ## пока бежишь на колокол: далёкий крик в лесу
const ALONE_SCARE_P := 0.35  ## один в доме: шаги по крыше, скрип — и иногда удар
const REFUSE_SCARE_P := 0.3  ## не открыл никому: иногда сразу после засова что-то бьёт в дверь

const SHADOW_P := 0.45      ## тень проходит мимо двери: со второй ночи, не чаще раза за ночь (TASK-077)
const BRANCH_P := 0.25      ## у двери сперва стучит ветка: со второй ночи, не чаще раза за главу

static var rng := RandomNumberGenerator.new()
static var _scare_day := -1
static var _shadow_day := -1
static var scares := 0       ## самотесты: сколько ударов прозвучало


static func reset() -> void:
	_scare_day = -1
	_shadow_day = -1
	scares = 0
	rng.randomize()


## Резкий удар. Вернёт false, если в эту ночь удар уже был или ночь первая.
static func scare(day: int, node: Control = null) -> bool:
	if day < 2 or _scare_day == day:
		return false
	_scare_day = day
	scares += 1
	Sfx.play(&"scare", 1.0, -1.0)
	Juice.haptic(Juice.Haptic.DEATH)
	if is_instance_valid(node):
		Juice.shake(node, 18.0, 0.4)
	return true


## Пройдёт ли тень мимо двери этой ночью. Один раз за ночь, не в первую.
static func shadow_due(day: int) -> bool:
	if day < 2 or _shadow_day == day or rng.randf() >= SHADOW_P:
		return false
	_shadow_day = day
	return true


## Постучит ли сперва ветка. Делит счётчик с ложным стуком на бегу: вместе не чаще раза за главу.
static func branch_due(day: int) -> bool:
	if day < 2 or Game.scenes_done.has("false_knock") or rng.randf() >= BRANCH_P:
		return false
	Game.scenes_done["false_knock"] = true
	return true


## Экран двери открыт: что слышно за ней, пока игрок решает.
static func door(screen: DoorScreen) -> void:
	if screen == null or Game.m == null:
		return
	var day := Game.m.day
	match screen.role:
		Match.DoorRole.HOST:
			await Juice.wait(2.4)
			if not _alive(screen):
				return
			if screen.seat != null and screen.seat.mimic != null:
				Sfx.play(&"weep" if rng.randf() < 0.5 else &"whisper", 1.0, -9.0)
			elif rng.randf() < SCRATCH_P:
				Sfx.play(&"scratch", rng.randf_range(0.92, 1.06), -7.0)
			if shadow_due(day):
				screen.shadow_fx.emit()
				Sfx.play(&"roof_steps", rng.randf_range(0.9, 1.05), -10.0)
		Match.DoorRole.ALONE:
			await Juice.wait(1.6)
			if not _alive(screen):
				return
			Sfx.play(&"roof_steps", 1.0, -5.0)
			await Juice.wait(3.4)
			if not _alive(screen):
				return
			Sfx.play(&"creak", rng.randf_range(0.9, 1.1), -6.0)
			if shadow_due(day):
				screen.shadow_fx.emit()
			if rng.randf() < ALONE_SCARE_P:
				await Juice.wait(1.2)
				if _alive(screen):
					scare(day, screen)
		Match.DoorRole.GUEST:
			await Juice.wait(1.8)
			if not _alive(screen):
				return
			Sfx.play(&"growl" if rng.randf() < 0.4 else &"cry_far", 1.0, -13.0)


## Хозяин закрыл дверь перед всеми.
static func refused(screen: Control) -> void:
	if Game.m != null and rng.randf() < REFUSE_SCARE_P:
		await Juice.wait(0.5)
		scare(Game.m.day, screen if _alive(screen) else null)


## Бег на колокол: где-то в лесу кричат.
static func run(screen: Control) -> void:
	if Game.m != null and Game.m.day >= 2 and rng.randf() < 0.2 and not Game.scenes_done.has("false_knock"):
		Game.scenes_done["false_knock"] = true
		_false_knock(screen)
	if rng.randf() >= RUN_CRY_P:
		return
	await Juice.wait(rng.randf_range(2.0, 4.0))
	if _alive(screen):
		Sfx.play(&"cry_far", rng.randf_range(0.85, 1.1), -10.0)


static func _false_knock(screen: Control) -> void:
	await Juice.wait(rng.randf_range(2.0, 3.5))
	if _alive(screen):
		Sfx.play(&"knock", rng.randf_range(0.88, 1.02), -13.0)


## Утро: как погиб — так и звучит. Улица — крик, в доме — хрип, тварь — рык, Подражатель — плач.
static func death_sound(kind: NightReport.Kind) -> StringName:
	match kind:
		NightReport.Kind.KILLED_INSIDE:
			return &"gasp"
		NightReport.Kind.KILLED_CREATURE:
			return &"growl"
		NightReport.Kind.KILLED_MIMIC:
			return &"weep"
		NightReport.Kind.KILLED_ALONE:
			return &"creak"
	return &"cry_far"


static func _alive(n: Variant) -> bool:
	return is_instance_valid(n) and (n as Node).is_inside_tree()   # экран мог закрыться, пока шла пауза
