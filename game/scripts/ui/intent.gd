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
const DEFEND := &"defend"
const END_DAY := &"end_day"
const VOTE := &"vote"
const CHOOSE_HOUSE := &"choose_house"
const ADMIT := &"admit"
const PLEA := &"plea"
const AGAIN := &"again"
const FIELD_TAP := &"field_tap"
const SET_DIFFICULTY := &"set_difficulty"
const OPEN_HOWTO := &"open_howto"
const SELECT_HOUSE := &"select_house"
const HOWTO_DONE := &"howto_done"
const ELDER := &"elder"          ## старожил смотрит рисунки: {"id"}
const HEAL := &"heal"            ## знахарь берёт травы на ночь
const MEETING := &"meeting"      ## удар в колокол днём: экстренный сбор
const TUNNEL := &"tunnel"        ## не пустили — лезть туннелем
const WORK := &"work"            ## встать к делу: {"ji": индекс, "sab": портить вместо работы}
