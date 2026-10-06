class_name Phrases
extends RefCounted
## Реплики ботов — чистые данные. Новые строки добавляются сюда, логика не трогается.
##
## Метки:
##   {who}        — о ком речь, именительный: «Женя»
##   {who_acc}    — о ком речь, винительный: «на Женю», «за Тимура»
##   {был|была}   — по роду того, о ком речь
##   [был|была]   — по роду того, кто говорит
##   {house}      — убежище: «иду в Сарай»
##   {house_in}   — где: «ночую в Сарае»
##   {house_of}   — чего: «встречаемся у Сарая»
## Если речь о самом игроке, вместо банка берётся AT_PLAYER: пол игрока неизвестен,
## поэтому о нём говорят без родовых окончаний.

const ANNOUNCE: PackedStringArray = [
	"Я сегодня в «{house_in}».",
	"Иду в «{house}». Кто со мной?",
	"Ночую в «{house_in}», если что.",
	"«{house}». Решено.",
]

const ACCUSE_STRONG: PackedStringArray = [
	"{who}, объясни, как ты {дожил|дожила} до утра.",
	"По мне так всё ясно. {who}.",
	"{who} {был|была} рядом, когда всё случилось. Совпадение?",
	"Я голосую за {who_acc}. Без вариантов.",
]

const ACCUSE_STREET: PackedStringArray = [
	"{who} {ночевал|ночевала} на улице и {вернулся|вернулась}. Люди так не умеют.",
	"{who}, ты всю ночь снаружи. Ничего не хочешь сказать?",
]

const ACCUSE_LIAR: PackedStringArray = [
	"{who} {говорил|говорила} про «{house}», а {спал|спала} в другом месте. Зачем врать?",
	"{who}, ты же {собирался|собиралась} не туда. Что поменялось?",
]

const DEFEND: PackedStringArray = [
	"Да, я [был|была] там. И что теперь?",
	"Я не упырь. Проверьте меня ночью.",
	"Мне просто не повезло с комнатой.",
	"Вы сейчас выгоните меня, а утром недосчитаетесь ещё двоих.",
]

const UPYR_DEFLECT: PackedStringArray = [
	"Я бы на вашем месте [смотрел|смотрела] на {who_acc}.",
	"Вы спорите, а ночь скоро.",
	"Давайте не будем гнать. Ошибёмся — потеряем своего.",
	"{who}, ты чего молчишь всё время?",
	"Я вчера [сидел|сидела] тихо и [дожил|дожила]. Значит, всё [делал|делала] правильно.",
]

const FILLER: PackedStringArray = [
	"Нас всё меньше. Считайте сами.",
	"Давайте решать быстрее, темнеет.",
	"Я никому не верю. Вообще.",
	"Кто-то из вас врёт прямо сейчас.",
]

const REPLY_TO_ACCUSED_HUMAN: PackedStringArray = [
	"Я? Серьёзно? Посмотри лучше на {who_acc}.",
	"Ты меня с кем-то путаешь.",
	"Хорошо. Выгоняйте. Утром поймёте.",
]

const REPLY_TO_ACCUSED_UPYR: PackedStringArray = [
	"Смешно. Давай лучше про тебя поговорим.",
	"Вот так и топят своих. Удобно.",
	"Ты слишком торопишься меня выгнать. Подозрительно.",
]

const AGREE_ACCUSE: PackedStringArray = [
	"[Согласен|Согласна]. {who} мне тоже не нравится.",
	"Поддерживаю. {who}.",
]

const DISAGREE_ACCUSE: PackedStringArray = [
	"Не, {who} вроде {нормальный|нормальная}. Ты чего?",
	"Слабо. Доказательства где?",
]

const INVITE_YES: PackedStringArray = [
	"Давай. Встречаемся у «{house_of}».",
	"Ладно, иду с тобой в «{house}».",
	"Хорошо. Только не подведи.",
]

const INVITE_NO: PackedStringArray = [
	"Не, я с тобой не пойду. Без обид.",
	"Тебе я пока не верю.",
	"У меня уже есть с кем.",
]

const ASK_ANSWER_HUMAN: PackedStringArray = [
	"Я в «{house_in}». Не скрываю.",
	"Сказано же — «{house}».",
]

const ASK_ANSWER_UNSURE: PackedStringArray = [
	"Ещё не [решил|решила].",
	"Посмотрю, кто куда.",
]

const PLAYER_DEFEND_REACTION: PackedStringArray = [
	"Ну-ну.",
	"Посмотрим.",
	"Все так говорят.",
	"Ладно, верю. Пока.",
]

const GENERIC_REACTION: PackedStringArray = [
	"И что ты этим хочешь сказать?",
	"Складно. Слишком складно.",
	"Ты это себе рассказываешь или нам?",
	"Слышу. Не убеждает.",
]

## Когда речь заходит о самом игроке — без родовых окончаний.
const AT_PLAYER: PackedStringArray = [
	"А к тебе у меня больше всего вопросов.",
	"Ты слишком спокойно себя ведёшь.",
	"Что-то ты темнишь.",
	"Посмотри лучше на себя.",
	"Тебе я не верю. Честно.",
]

## Мольбы ботов у двери
const PLEA_AFTER_STREET: PackedStringArray = [
	"Меня вчера уже не пустили. Второй раз не переживу.",
	"Я всю ночь на улице [просидел|просидела]. Открой.",
]
const PLEA_SUSPECT: PackedStringArray = [
	"Знаю, как это выглядит. Но я не упырь.",
	"Один раз поверь. Потом хоть выгоняй.",
]
const PLEA_NORMAL: PackedStringArray = [
	"Открой, тут холодно.",
	"Это я. Пусти.",
	"Вдвоём дотянем до утра.",
	"Не тяни, там кто-то ходит.",
]
const PLEA_PACT: PackedStringArray = [
	"Это я, мы же договаривались.",
	"Открывай, как условились.",
]

## Мольбы игрока у чужой двери: текст и вес в глазах хозяина
const PLAYER_PLEAS := [
	{"id": "shared", "label": "Мы уже ночевали вместе", "text": "Мы же ночевали вместе — и ничего не случилось."},
	{"id": "promise", "label": "Пообещать впустить завтра", "text": "Пусти. Завтра я открою тебе первым."},
	{"id": "name", "label": "Назвать упыря", "text": "Я знаю, кто это. Пусти — расскажу."},
	{"id": "beg", "label": "Просто умолять", "text": "Пожалуйста. Там не выжить."},
]

static var _re_target: RegEx
static var _re_speaker: RegEx


static func mentions_target(bank: PackedStringArray) -> bool:
	for line: String in bank:
		if line.contains("{who"):
			return true
	return false


static func accusative(name: String) -> String:
	return Ru.accusative(name)


static func pick(bank: PackedStringArray, rng: RandomNumberGenerator, vars: Dictionary = {}) -> String:
	return fill(bank[rng.randi_range(0, bank.size() - 1)], vars)


static func fill(template: String, vars: Dictionary) -> String:
	if _re_target == null:
		_re_target = RegEx.create_from_string("\\{([^{}|]*)\\|([^{}|]*)\\}")
		_re_speaker = RegEx.create_from_string("\\[([^\\[\\]|]*)\\|([^\\[\\]|]*)\\]")
	var s := template
	s = _re_target.sub(s, "$2" if bool(vars.get("who_f", false)) else "$1", true)
	s = _re_speaker.sub(s, "$2" if bool(vars.get("me_f", false)) else "$1", true)
	if vars.has("house"):
		s = s.replace("{house_in}", Ru.house_in(String(vars["house"]))).replace("{house_of}", Ru.house_of(String(vars["house"])))
	if vars.has("who"):
		s = s.replace("{who_acc}", String(vars.get("who_acc", accusative(String(vars["who"])))))
	for k: String in vars:
		s = s.replace("{%s}" % k, str(vars[k]))
	return s
