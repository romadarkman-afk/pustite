class_name Intent
extends RefCounted
## Имена намерений, которые экраны отправляют наверх. Константы вместо строк —
## опечатка в имени ловится при компиляции, а не на устройстве.

const START := &"start"
const OPEN_SETTINGS := &"open_settings"
const BACK := &"back"
const CONTINUE := &"continue"
const SAY := &"say"
const ACCUSE := &"accuse"
const INVITE := &"invite"
const ASK := &"ask"
const PERSONAL_TALK := &"personal_talk"
const DEFEND := &"defend"
const END_DAY := &"end_day"
const VOTE := &"vote"
const CHOOSE_HOUSE := &"choose_house"
const ADMIT := &"admit"
const DOOR_INSPECT := &"door_inspect"    ## осмотр стучащего: {"id"}
const PLEA := &"plea"
const AGAIN := &"again"
const FIELD_TAP := &"field_tap"
const SET_DIFFICULTY := &"set_difficulty"
const OPEN_WARDROBE := &"open_wardrobe"  ## фонарь и шапка
const WEAR := &"wear"                  ## надеть: {"kind": "lantern"|"hat", "id"}
const FIELD_HOLD := &"field_hold"      ## долгое нажатие на поле: {"pos"}
const GESTURE := &"gesture"            ## жест жителю: {"kind": "point"|"trust"|"distrust", "id"}
const DAILY := &"daily"                ## начать испытание дня
const SET_TEXT := &"set_text"          ## размер текста: {"size": 0..2}
const SET_LANG := &"set_lang"          ## сменить язык: {"code"}
const OPEN_HOWTO := &"open_howto"
const SET_PLAYER_NAME := &"set_player_name"
const QUESTION_REPLY := &"question_reply"
const SELECT_HOUSE := &"select_house"
const HOWTO_DONE := &"howto_done"
const ELDER := &"elder"          ## старожил смотрит рисунки: {"id"}
const HEAL := &"heal"            ## знахарь берёт травы на ночь
const MEETING := &"meeting"      ## удар в колокол днём: экстренный сбор
const TUNNEL := &"tunnel"        ## не пустили — лезть туннелем
const OPEN_BOOK := &"open_book"           ## Книга посёлка
const OPEN_CAMPAIGN := &"open_campaign"   ## экран глав кампании
const PLAY_CHAPTER := &"play_chapter"     ## начать главу: {"id"}; пусто — продолжить
const SKIP_TO_END := &"skip_to_end"  ## тебя не стало: доиграть без тебя и сразу к итогу
const CONFRONT := &"confront"    ## спросить при всех о противоречии: {"a", "b"} — id записей тетради (TASK-017)
const SEND_AWAY := &"send_away"  ## отправить на лодке за реку: {"id"} (TASK-020)
const PROMISE := &"promise"      ## обещание жителю: {"id", "kind": "open" | "come"} (TASK-004)
const WORK := &"work"            ## встать к делу: {"ji": индекс, "sab": портить вместо работы}
