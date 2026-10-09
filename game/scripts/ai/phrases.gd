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

## Быстрые фразы игрока: одно касание — и сказано. Фразы с домом засчитываются
## как объявление, где вы ночуете.
## Кто-то заметил, что житель стоял у дела, а запасов не прибавилось.
const JOB_FAKE: PackedStringArray = [
	"{who} {стоял|стояла} {place}, а толку ноль.",
	"Я [видел|видела]: {who} {возился|возилась} {place} и ничего не {сделал|сделала}.",
	"Странно. {who} {ходил|ходила} {place}, а запасов не прибавилось.",
	"{who} только делает вид, что работает. {Был|Была} {place} — пусто.",
	"А что {who} {делал|делала} {place}? Вёдра как стояли пустые, так и стоят.",
]

## То же про игрока: его пол неизвестен, поэтому глаголы о нём — без рода.
const JOB_FAKE_AT_PLAYER: PackedStringArray = [
	"Ты {place} только время теряешь. Запасов-то не прибавилось.",
	"Ты делаешь вид, что работаешь {place}. Я [видел|видела].",
	"А толку от тебя {place}? Вёдра как пустые стояли, так и стоят.",
]

## Подражатель у двери: говорит голосом жителя, но чуть не так — повторяет слова.
## Род — по тому, чьим голосом он говорит.
const MIMIC_PLEAS: PackedStringArray = [
	"Пусти. Это я. Это я, {who}. Пусти.",
	"Открой, пожалуйста. Пожалуйста. Тут холодно. Холодно.",
	"Ты же меня знаешь. Открой дверь. Открой дверь.",
	"Я [пришёл|пришла] домой. Пусти домой.",
]

## Саботаж: что видят у испорченного дела. По виду дела.
const SPOIL := {
	JobDef.Kind.WATER: "вёдра опрокинуты",
	JobDef.Kind.WOOD: "дрова раскиданы по грязи",
	JobDef.Kind.LAMP: "масло разлито",
	JobDef.Kind.FISH: "улов выброшен обратно в реку",
}
const SABOTAGE_SEEN: PackedStringArray = [
	"{who} {крутился|крутилась} {place}, а теперь там всё испорчено.",
	"Я [видел|видела], как {who} что-то {делал|делала} {place}. Это {он|она} напакостил{|а}.",
	"Кто портит запасы? {who} {был|была} {place} {последним|последней}.",
]
const SABOTAGE_SEEN_AT_PLAYER: PackedStringArray = [
	"Ты что там {place} делаешь? Я [видел|видела]: после тебя всё испорчено.",
	"Это после тебя {place} всё испорчено. Я [видел|видела].",
]

## Ящик: что рассказывает тот, кто его открыл.
const BOX_NOTE: PackedStringArray = [
	"В ящике записка: «{a} или {b}». Один из них упырь.",
	"Я [открыл|открыла] ящик. Там записка: «{a} или {b}. Один из двоих не человек».",
]
const BOX_OIL: PackedStringArray = [
	"В ящике масло для фонарей. Ночью будет светлее.",
	"Я [открыл|открыла] ящик: там масло. Фонари заправим.",
]
const BOX_CHALK: PackedStringArray = [
	"В ящике мел. Я [подновил|подновила] оберег у «{house_of}».",
]

const PLAYER_QUICK_HOUSE := "Я ночую в «{house_in}». Кто со мной?"
const PLAYER_QUICK := [
	"Я не упырь. Клянусь.",
	"Кто вернулся с улицы — тот и упырь.",
	"Давайте держаться парами.",
	"Кто врёт про ночлег, того и гоним.",
]


static func quick_for(m: Match) -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(m.houses.size()):
		out.append(fill(PLAYER_QUICK_HOUSE, {"house": m.houses[i]}))
	for q: String in PLAYER_QUICK:
		out.append(q)
	return out


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
