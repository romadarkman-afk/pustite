class_name Phrases
extends RefCounted
## Реплики ботов — чистые данные. Новые строки добавляются сюда, логика не трогается.
## Плейсхолдеры: {who} — о ком речь, {house} — убежище, {me} — говорящий.

const ANNOUNCE: PackedStringArray = [
	"Я сегодня в «{house}».",
	"Иду в «{house}». Кто со мной?",
	"Ночую в «{house}», если что.",
	"«{house}». Решено.",
]

const ACCUSE_STRONG: PackedStringArray = [
	"{who}, объясни, как ты дожил до утра.",
	"По мне так всё ясно. {who}.",
	"{who} был рядом, когда всё случилось. Совпадение?",
	"Я голосую за {who}. Без вариантов.",
]

const ACCUSE_STREET: PackedStringArray = [
	"{who} ночевал на улице и вернулся. Люди так не умеют.",
	"{who}, ты всю ночь снаружи. Ничего не хочешь сказать?",
]

const ACCUSE_LIAR: PackedStringArray = [
	"{who} говорил про «{house}», а спал в другом месте. Зачем врать?",
	"{who}, ты же собирался не туда. Что поменялось?",
]

const DEFEND: PackedStringArray = [
	"Да, я был там. И что, мне теперь повеситься?",
	"Я не он. Проверьте меня ночью.",
	"Мне просто не повезло с комнатой.",
	"Вы сейчас выгоните меня, а утром недосчитаетесь ещё двоих.",
]

const UPYR_DEFLECT: PackedStringArray = [
	"Я бы на вашем месте смотрел на {who}.",
	"Вы спорите, а ночь скоро.",
	"Давайте не будем гнать. Ошибёмся — потеряем своего.",
	"{who}, ты чего молчишь всё время?",
	"Я вчера сидел тихо и дожил. Значит, всё делал правильно.",
]

const FILLER: PackedStringArray = [
	"Нас всё меньше. Считайте сами.",
	"Давайте решать быстрее, темнеет.",
	"Я никому не верю. Вообще.",
	"Кто-то из вас врёт прямо сейчас.",
]

const REPLY_TO_ACCUSED_HUMAN: PackedStringArray = [
	"Я? Серьёзно? Посмотри лучше на {who}.",
	"Ты меня с кем-то путаешь.",
	"Хорошо. Выгоняйте. Утром поймёте.",
]

const REPLY_TO_ACCUSED_UPYR: PackedStringArray = [
	"Смешно. А сам-то где ночевал?",
	"Вот так и топят своих. Удобно.",
	"Ты слишком торопишься меня выгнать. Подозрительно.",
]

const AGREE_ACCUSE: PackedStringArray = [
	"Согласен. {who} мне тоже не нравится.",
	"Поддерживаю. {who}.",
]

const DISAGREE_ACCUSE: PackedStringArray = [
	"Не, {who} вроде нормальный. Ты чего?",
	"Слабо. Доказательства где?",
]

const INVITE_YES: PackedStringArray = [
	"Давай. Встречаемся у «{house}».",
	"Ладно, иду с тобой в «{house}».",
	"Хорошо. Только не подведи.",
]

const INVITE_NO: PackedStringArray = [
	"Не, я с тобой не пойду. Без обид.",
	"Тебе я пока не верю.",
	"У меня уже есть с кем.",
]

const ASK_ANSWER_HUMAN: PackedStringArray = [
	"Я в «{house}». Не скрываю.",
	"Сказал же — «{house}».",
]

const ASK_ANSWER_UNSURE: PackedStringArray = [
	"Ещё не решил.",
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
	"Я услышал. Не убедил.",
]

## Мольбы ботов у двери
const PLEA_AFTER_STREET: PackedStringArray = [
	"Меня вчера уже не пустили. Второй раз не переживу.",
	"Я всю ночь на улице просидел. Открой.",
]
const PLEA_SUSPECT: PackedStringArray = [
	"Знаю, как это выглядит. Но я не он.",
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
const PLAYER_PLEAS: Array[Dictionary] = [
	{"id": "shared", "label": "Мы уже ночевали вместе", "text": "Мы же ночевали вместе — я тебя не тронул."},
	{"id": "promise", "label": "Пообещать впустить завтра", "text": "Пусти. Завтра я открою тебе первым."},
	{"id": "name", "label": "Назвать упыря", "text": "Я знаю, кто это. Пусти — расскажу."},
	{"id": "beg", "label": "Просто умолять", "text": "Пожалуйста. Я не выживу там."},
]


static func pick(bank: PackedStringArray, rng: RandomNumberGenerator, vars: Dictionary = {}) -> String:
	var s: String = bank[rng.randi_range(0, bank.size() - 1)]
	for k: String in vars:
		s = s.replace("{%s}" % k, str(vars[k]))
	return s
