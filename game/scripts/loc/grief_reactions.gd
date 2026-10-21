class_name GriefReactions
extends RefCounted
## Утрата близкого (TASK-010, TASK-014): реплики четырёх реакций и утренняя сцена для каждого из 12 жителей.
## Свой голос и предмет из личной истории: Марина роняет чашку, Тимур вбивает два гвоздя, Лида стоит у доски…
## Русский и английский написаны для каждого жителя; на остальных языках — общие строки react.* и scene.grief.*
## (свои для каждого жителя — в TASK-049).
## Метки: {lost} — погибший, {kin} — тот, кто остался, [был|была] — род говорящего (me = kin).
## Об игроке без родовых окончаний: пол игрока неизвестен.

const KINDS: PackedStringArray = ["accuse", "defend", "withdraw", "revenge"]

## Номер истории -> {accuse, defend, withdraw, scene: [кадр 1, кадр 2], sound: звук предмета во втором кадре}
const RU := [
	{"accuse": "{lost} {lost:стучал|стучала} к тебе. Я ставлю на стол лишнюю чашку, а ставить её больше некому. Засов был в твоих руках.",
	 "defend": "Не вините того, кто держал дверь. Мест было два, я [считал|считала]. Лодка тоже не берёт больше, чем может.",
	 "withdraw": "Я опять [поставил|поставила] лишнюю чашку. Не говорите со мной сегодня.",
	 "scene": ["Утром {kin} ставит на стол три чашки. Третью держит дольше, чем нужно.", "Чашка выскальзывает из пальцев. {kin} не наклоняется за осколками."], "sound": "cup_break"},
	{"accuse": "Я [вбил|вбила] в крышку два гвоздя и [остановился|остановилась]. Третьим должен был стать твой засов. Он был открыт для всех, кроме {lost.gen}.",
	 "defend": "Я двадцать лет хороню людей. Знаю, когда виноват живой. Сегодня не тот случай: мест не было.",
	 "withdraw": "Пойду копать. Земля хотя бы ничего не спрашивает.",
	 "scene": ["{kin} сколачивает ящик у сарая. Два удара молотка, и тишина.", "Третий гвоздь так и остаётся у {kin.gen} в кулаке."], "sound": "hammer"},
	{"accuse": "Сорок лет я [учил|учила] детей стучать в дверь вежливо. {lost} {lost:стучал|стучала} вежливо. Дверь осталась закрытой. Твоя дверь.",
	 "defend": "Мест было два. Я [считал|считала] вслух, пока {lost} {lost:стучал|стучала}. Хозяин двери тут ни при чём.",
	 "withdraw": "На доске теперь на одно имя больше. Я сама его напишу.",
	 "scene": ["У часовни {kin} стоит перед доской с именами. Мел в руке не двигается.", "Последнее имя на доске написано её почерком: {lost}."], "sound": "tick"},
	{"accuse": "Свист у двери слышали все в доме. Засов отодвинуть никто не захотел. Начиная с тебя.",
	 "defend": "Я [видел|видела], сколько людей было в доме. Места не было. Не надо на хозяина двери.",
	 "withdraw": "Деньги из-под моста я [достал|достала] вчера. Теперь их хватит на одного.",
	 "scene": ["{kin} сидит на мостках и тихо свистит в сторону леса.", "Из леса никто не отвечает. Впервые."], "sound": "call_far"},
	{"accuse": "Я однажды [пообещал|пообещала] спасти, зная, что не смогу. У твоей двери не было даже обещания.",
	 "defend": "Я [считал|считала] пульс у тех, кто был в доме. Ещё один бы не поместился. Это не вина хозяина.",
	 "withdraw": "Сумку с бинтами я сегодня не открываю.",
	 "scene": ["{kin} перебирает бинты в сумке. Руки двигаются сами.", "Один бинт {kin} откладывает в сторону и долго на него смотрит."], "sound": "weep"},
	{"accuse": "Я однажды [ушёл|ушла] с поста на знакомый голос. У твоей двери пост стоял крепко. Слишком крепко.",
	 "defend": "Я знаю, каково стоять у двери и выбирать. Мест не было. Я бы [сделал|сделала] то же.",
	 "withdraw": "Пойду к мосту. Там хотя бы привычно ждать.",
	 "scene": ["{kin} стоит у моста, на старом посту. Фонарь не зажжён.", "С того берега никто не зовёт. {kin} всё равно не уходит."], "sound": "creak"},
	{"accuse": "Кольцо на шнурке теперь можно снять. {lost} {lost:стучал|стучала} к тебе. Утром я [слышал|слышала] только тишину.",
	 "defend": "В доме было тесно, я [видел|видела]. Это не вина хозяина. Это ночь.",
	 "withdraw": "Я сегодня не работаю. Кружки посчитает кто-нибудь другой.",
	 "scene": ["{kin} снимает с шеи шнурок с кольцом и кладёт на стол.", "Потом снова надевает. И снова снимает."], "sound": "weep"},
	{"accuse": "Часы встали в ту минуту, когда {lost} {lost:стучал|стучала} к тебе. Я помню, сколько они показывали. Ты тоже запомни.",
	 "defend": "Я [слышал|слышала], как считали места. Два. Время не обманешь, и тесноту тоже.",
	 "withdraw": "Я [остановил|остановила] часы. Пусть стоят, пока я не смогу их слушать.",
	 "scene": ["{kin} открывает дверцу башенных часов и придерживает маятник.", "Часы замолкают. Тиканье остаётся только в голове."], "sound": "tick"},
	{"accuse": "Следы у твоей двери ведут к порогу и обратно. Дверь не открылась ни разу.",
	 "defend": "Я [читал|читала] следы у двери. Внутри было тесно, хозяин метался у порога. Он не виноват.",
	 "withdraw": "Пройду по следам. Без компании.",
	 "scene": ["{kin} сидит на корточках у чужого порога и разглядывает снег.", "Цепочка следов обрывается у дороги. {kin} долго не встаёт."], "sound": "creak"},
	{"accuse": "Ружьё заряжено. Не бойся, не для тебя. Пока.",
	 "defend": "Мест было два. Я [охотник|охотница], я считаю патроны и места. Не на хозяина двери мне злиться.",
	 "withdraw": "Пойду в лес. [Одному|Одной] там тише.",
	 "scene": ["{kin} молча чистит ружьё у окна.", "Щёлкает затвор. {kin} кладёт ружьё на колени и смотрит в лес."], "sound": "latch"},
	{"accuse": "Под яблоней лежит чашка для тех, кто вернётся. {lost} не вернётся. Спасибо твоей двери.",
	 "defend": "Яблоня цветёт только там, где хватает света. В доме света на всех не хватало. Я понимаю.",
	 "withdraw": "Пойду к яблоне. Там с {lost.ins} хоть можно поговорить.",
	 "scene": ["{kin} копает землю под яблоней голыми руками.", "Под корнями чашка. {kin} ставит её на порог."], "sound": "floorboard"},
	{"accuse": "Нож на моём верстаке ждёт хозяина. Теперь их два, а хозяев ни одного. Подумай, чья дверь была закрыта.",
	 "defend": "Засов держит, сколько может. Больше не выдержал бы ни дом, ни хозяин.",
	 "withdraw": "Пойду в кузню. Железо хотя бы гнётся, когда его просят.",
	 "scene": ["{kin} раздувает горн, хотя работы нет.", "На наковальне лежит недоделанный засов. Молот так и не опускается."], "sound": "hammer"},
]

const EN := [
	{"accuse": "{lost} knocked at your door. I still set out an extra cup, and there's no one to set it for. The bolt was in your hands.",
	 "defend": "Don't blame whoever held the door. There were two places, I counted. A boat can't carry more than it holds either.",
	 "withdraw": "I set out an extra cup again. Don't talk to me today.",
	 "scene": ["In the morning {kin} sets three cups on the table. Holds the third one too long.", "The cup slips from her fingers. {kin} doesn't bend to pick up the pieces."], "sound": "cup_break"},
	{"accuse": "I drove two nails into the lid and stopped. Your bolt should have been the third. It was open for everyone except {lost}.",
	 "defend": "I've buried people for twenty years. I know when the living are to blame. Not today: there was no room.",
	 "withdraw": "I'll go and dig. At least the ground doesn't ask questions.",
	 "scene": ["{kin} is nailing a box together by the shed. Two hammer blows, then silence.", "The third nail stays clenched in {kin}'s fist."], "sound": "hammer"},
	{"accuse": "For forty years I taught children to knock politely. {lost} knocked politely. The door stayed shut. Your door.",
	 "defend": "There were two places. I counted out loud while {lost} knocked. It wasn't the host's fault.",
	 "withdraw": "There's one more name on the board now. I'll write it myself.",
	 "scene": ["By the chapel {kin} stands before the board of names. The chalk in her hand doesn't move.", "The last name on the board is in her handwriting: {lost}."], "sound": "tick"},
	{"accuse": "Everyone in that house heard the whistle at the door. Nobody wanted to slide the bolt. You first of all.",
	 "defend": "I saw how many people were in that house. There was no room. Leave the host alone.",
	 "withdraw": "I took the money from under the bridge yesterday. Now it's enough for one.",
	 "scene": ["{kin} sits on the jetty, whistling softly toward the woods.", "Nobody whistles back. For the first time."], "sound": "call_far"},
	{"accuse": "Once I promised to save someone, knowing I couldn't. At your door there wasn't even a promise.",
	 "defend": "I counted pulses in that house. One more wouldn't have fit. It's not the host's fault.",
	 "withdraw": "I'm not opening my bag of bandages today.",
	 "scene": ["{kin} sorts the bandages in the bag. The hands move on their own.", "{kin} sets one bandage aside and stares at it for a long time."], "sound": "weep"},
	{"accuse": "Once I left my post for a familiar voice. At your door the post held firm. Too firm.",
	 "defend": "I know what it's like to stand at a door and choose. There was no room. I'd have done the same.",
	 "withdraw": "I'll go to the bridge. Waiting there is at least familiar.",
	 "scene": ["{kin} stands at the bridge, at the old post. The lantern is not lit.", "Nobody calls from the other bank. {kin} doesn't leave anyway."], "sound": "creak"},
	{"accuse": "I can take the ring off its cord now. {lost} knocked at your door. In the morning all I heard was silence.",
	 "defend": "It was crowded in there, I saw it. It's not the host's fault. It's the night.",
	 "withdraw": "I'm not working today. Someone else can count the mugs.",
	 "scene": ["{kin} takes the cord with the ring from around the neck and lays it on the table.", "Then puts it back on. Then takes it off again."], "sound": "weep"},
	{"accuse": "The clock stopped the minute {lost} knocked at your door. I remember the time it showed. You remember it too.",
	 "defend": "I heard them counting places. Two. You can't cheat time, or a crowded house.",
	 "withdraw": "I stopped the clock. Let it stand until I can bear to listen to it.",
	 "scene": ["{kin} opens the tower clock and holds the pendulum still.", "The clock goes quiet. The ticking stays only in the head."], "sound": "tick"},
	{"accuse": "The tracks at your door go to the step and back. The door didn't open once.",
	 "defend": "I read the tracks at that door. It was crowded inside, the host paced by the step. Not the host's fault.",
	 "withdraw": "I'll follow the tracks. Alone.",
	 "scene": ["{kin} crouches at a stranger's doorstep, studying the snow.", "The line of tracks ends at the road. {kin} doesn't get up for a long time."], "sound": "creak"},
	{"accuse": "The rifle is loaded. Don't worry, it's not for you. Not yet.",
	 "defend": "There were two places. I'm a hunter, I count bullets and places. It's not the host I'm angry with.",
	 "withdraw": "I'm going into the woods. It's quieter alone.",
	 "scene": ["{kin} cleans the rifle by the window without a word.", "The bolt clicks. {kin} lays the rifle across the knees and watches the woods."], "sound": "latch"},
	{"accuse": "There's a cup under the apple tree for those who come back. {lost} won't come back. Thank your door for that.",
	 "defend": "The apple tree blooms only where there's light. There wasn't light for everyone in that house. I understand.",
	 "withdraw": "I'll go to the apple tree. At least I can talk to {lost} there.",
	 "scene": ["{kin} digs under the apple tree with bare hands.", "There's a cup under the roots. {kin} sets it on the doorstep."], "sound": "floorboard"},
	{"accuse": "The knife on my workbench is waiting for its owner. Now there are two knives and no owners. Think about whose door was shut.",
	 "defend": "A bolt holds as much as it can. Neither the house nor the host could have held more.",
	 "withdraw": "I'm going to the forge. At least iron bends when you ask.",
	 "scene": ["{kin} works the bellows though there's no job.", "An unfinished bolt lies on the anvil. The hammer never comes down."], "sound": "hammer"},
]

## Персональные предметы в сценах утраты для локалей, где нет отдельных литературных реплик.
## Индексы совпадают с PEOPLE_RU: каждая деталь отсылает к уже рассказанной истории жителя.
const PERSONAL_MEMORY := {
	"de": [
		"Am Tisch steht noch immer ein zweiter Teller; daneben liegt das rote Band.",
		"Der dritte Nagel liegt unbenutzt neben dem Sargdeckel.",
		"Auf der ersten Schulbank liegt noch das Heft mit dem rückwärts geschriebenen Ich.",
		"Unter der Brücke liegt noch das Geld, das für zwei reichen sollte.",
		"Ein sauberer Verband liegt neben der offenen Tasche.",
		"Die Laterne am Brückenpfosten ist erloschen.",
		"Zwei Becher stehen auf dem Tresen; einer bleibt unberührt.",
		"Die Turmuhr steht noch immer auf derselben Minute.",
		"Im Schnee endet die zweite Spur am Waldrand.",
		"Das Gewehr liegt ungeladen am Fenster.",
		"Unter dem Apfelbaum wartet noch immer eine Tasse.",
		"Auf der Werkbank liegt der unfertige Riegel."
	],
	"fr": [
		"Une deuxième assiette reste sur la table, avec le ruban rouge à côté.",
		"Le troisième clou attend toujours près du couvercle du cercueil.",
		"Sur le premier pupitre, le cahier garde son « je » écrit à l'envers.",
		"Sous le pont, l'argent prévu pour deux n'a pas bougé.",
		"Un bandage propre reste près du sac ouvert.",
		"La lanterne du poste près du pont s'est éteinte.",
		"Deux chopes restent sur le comptoir; l'une ne sera plus touchée.",
		"L'horloge de la tour indique toujours la même minute.",
		"Dans la neige, la seconde piste s'arrête à la lisière.",
		"Le fusil repose près de la fenêtre, déchargé.",
		"Une tasse attend encore sous le pommier.",
		"Le verrou inachevé repose sur l'établi."
	],
	"es": [
		"En la mesa sigue puesto un segundo plato; la cinta roja está al lado.",
		"El tercer clavo sigue junto a la tapa del ataúd, sin usar.",
		"En el primer pupitre queda el cuaderno con la «yo» escrita al revés.",
		"Bajo el puente sigue el dinero que debía alcanzar para dos.",
		"Junto a la bolsa abierta queda una venda limpia.",
		"La lámpara del puesto junto al puente se ha apagado.",
		"Quedan dos jarras en la barra; una ya nadie la toca.",
		"El reloj de la torre sigue parado en el mismo minuto.",
		"En la nieve, el segundo rastro termina al borde del bosque.",
		"El rifle descansa junto a la ventana, descargado.",
		"Bajo el manzano todavía espera una taza.",
		"El cerrojo sin terminar sigue sobre el banco de trabajo."
	],
	"pt": [
		"Ainda há um segundo prato na mesa; a fita vermelha ficou ao lado.",
		"O terceiro prego continua sem uso junto à tampa do caixão.",
		"Na primeira carteira, o caderno ainda guarda o «eu» escrito ao contrário.",
		"Debaixo da ponte continua o dinheiro que devia dar para dois.",
		"Uma atadura limpa ficou ao lado da bolsa aberta.",
		"A lanterna do posto junto à ponte se apagou.",
		"Duas canecas continuam no balcão; uma delas ninguém toca.",
		"O relógio da torre continua parado no mesmo minuto.",
		"Na neve, a segunda trilha termina na beira da floresta.",
		"O rifle está junto à janela, descarregado.",
		"Ainda há uma xícara esperando sob a macieira.",
		"O ferrolho inacabado continua na bancada."
	],
	"tr": [
		"Masada ikinci tabak hâlâ duruyor; kırmızı kurdele hemen yanında.",
		"Üçüncü çivi, tabut kapağının yanında hâlâ kullanılmadan bekliyor.",
		"İlk sıradaki defterde ters yazılmış bir «ben» hâlâ duruyor.",
		"Köprünün altında, iki kişiye yetecek para hâlâ yerinde.",
		"Açık çantanın yanında temiz bir sargı bezi duruyor.",
		"Köprü başındaki nöbet feneri söndü.",
		"Tezgahta iki kupa var; birine artık kimse dokunmuyor.",
		"Kule saati hâlâ aynı dakikada durmuş durumda.",
		"Kardaki ikinci iz, ormanın kıyısında bitiyor.",
		"Tüfek pencerenin yanında, boş hâlde duruyor.",
		"Elma ağacının altında hâlâ bir fincan bekliyor.",
		"Yarım kalmış sürgü tezgâhta duruyor."
	],
	"hi": [
		"मेज़ पर दूसरी थाली अब भी रखी है; लाल फीता उसके पास पड़ा है।",
		"तीसरी कील ताबूत के ढक्कन के पास अब भी बिना इस्तेमाल पड़ी है।",
		"पहली बेंच पर उल्टा लिखा «मैं» वाली कॉपी अब भी रखी है।",
		"पुल के नीचे दो लोगों के लिए बचाकर रखे पैसे अब भी पड़े हैं।",
		"खुले थैले के पास साफ़ पट्टी रखी है।",
		"पुल की चौकी पर लालटेन बुझ गई है।",
		"काउंटर पर दो प्याले हैं; उनमें से एक को अब कोई नहीं छूता।",
		"मीनार की घड़ी अब भी उसी मिनट पर रुकी है।",
		"बर्फ़ में दूसरा पदचिह्न जंगल के किनारे पर रुक जाता है।",
		"खिड़की के पास बंदूक खाली पड़ी है।",
		"सेब के पेड़ के नीचे एक प्याला अब भी रखा है।",
		"अधूरी कुंडी अब भी लोहार की मेज़ पर पड़ी है।"
	],
	"vi": [
		"Trên bàn vẫn còn một chiếc đĩa thứ hai; dải ruy băng đỏ nằm bên cạnh.",
		"Chiếc đinh thứ ba vẫn chưa dùng, nằm cạnh nắp quan tài.",
		"Trên bàn đầu lớp vẫn còn quyển vở có chữ «tôi» viết ngược.",
		"Số tiền dành cho hai người vẫn nằm dưới cây cầu.",
		"Một cuộn băng sạch nằm cạnh chiếc túi đang mở.",
		"Ngọn đèn ở chốt gác bên cầu đã tắt.",
		"Hai chiếc cốc vẫn ở trên quầy; một chiếc không ai chạm tới nữa.",
		"Đồng hồ tháp vẫn dừng ở đúng phút ấy.",
		"Dấu chân thứ hai trên tuyết dừng lại ở bìa rừng.",
		"Khẩu súng trường đã tháo đạn nằm cạnh cửa sổ.",
		"Một chiếc cốc vẫn chờ dưới gốc táo.",
		"Then cửa còn dang dở vẫn nằm trên bàn thợ."
	],
	"zh": [
		"桌上还摆着第二只盘子，红丝带就在旁边。",
		"第三枚钉子仍放在棺盖旁，没有用上。",
		"第一张课桌上还留着那本把“我”字写反的练习册。",
		"桥下还放着原本够两个人离开的钱。",
		"打开的医药包旁，还留着一卷干净的绷带。",
		"桥头岗亭的提灯已经熄了。",
		"柜台上还放着两只杯子，其中一只再也没人碰。",
		"钟楼的钟仍停在那一分钟。",
		"雪地里的第二串脚印停在林边。",
		"步枪空着，靠在窗边。",
		"苹果树下还留着一只杯子。",
		"工作台上还放着没做完的门闩。"
	]
}


static func _row(kin: Villager) -> Dictionary:
	if kin == null or kin.story_id < 0 or not kin.guest_id.is_empty():
		return {}
	var table: Array = RU if L.code == "ru" else (EN if L.code == "en" else [])
	return table[posmod(kin.story_id, table.size())] if not table.is_empty() else {}


static func memory_line(story_id: int) -> String:
	var bank: Array = PERSONAL_MEMORY.get(L.code, [])
	return String(bank[posmod(story_id, bank.size())]) if story_id >= 0 and not bank.is_empty() else ""


## Реплика реакции: kin говорит о погибшем lost. Пусто для revenge — месть молчит.
static func line(kin: Villager, lost: Villager, kind: String) -> String:
	if kind == "revenge":
		return ""
	var row := _row(kin)
	var tpl := String(row.get(kind, "")) if not row.is_empty() else L.t("react." + kind)
	var rendered := L.fill(tpl, {"me": kin, "kin": kin, "lost": lost})
	if row.is_empty():
		var memory := memory_line(kin.story_id)
		if not memory.is_empty():
			rendered += " " + memory
	return rendered


## Утренняя сцена утраты: два кадра текста и звук предмета.
static func scene_frames(kin: Villager, lost: Villager) -> Dictionary:
	var row := _row(kin)
	var frames := PackedStringArray()
	if not row.is_empty():
		for f: String in row.scene:
			frames.append(L.fill(f, {"me": kin, "kin": kin, "lost": lost}))
		return {"frames": frames, "sound": String(row.sound)}
	for k: String in ["scene.grief.1", "scene.grief.2"]:
		frames.append(L.t(k, {"me": kin, "kin": kin, "lost": lost}))
	var memory := memory_line(kin.story_id)
	if not memory.is_empty():
		frames.append(memory)
	return {"frames": frames, "sound": "weep"}
