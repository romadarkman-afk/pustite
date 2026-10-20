class_name SocialContent
extends RefCounted
## Short personal histories and NPC-initiated questions, localized with the rest of the game.

const DATA := {
	"ru": {
		"name_label": "Имя игрока: {name}", "name_missing": "не задано", "name_prompt": "Как тебя зовут?", "question_title": "{who} спрашивает тебя",
		"answers": ["Я расскажу, что знаю. Спрашивай конкретно.", "Сначала расскажи ты. Потом решу, чем делиться.", "Я надеялся пережить только ночь. У вас тут планы шире."],
		"opening": "{story} А что привело тебя сюда{player_clause}?",
		"stories": [
			"Я [переправлял|переправляла] людей через реку. Однажды лодка вернулась без пассажиров.",
			"Я [копал|копала] могилы после первой зимы. Земля у нас оттаивает быстрее, чем память.",
			"Я [держал|держала] деревенскую школу. Теперь записываю имена тех, кто перестал приходить.",
			"Моя сестра ушла в лес за дровами. С тех пор я каждый вечер оставляю ей место у печи.",
			"Я [лечил|лечила] семью мельника. Дом заперт, а счёт за лечение так и висит.",
			"Я [дежурил|дежурила] у моста в ту ночь, когда исчез человек. Объяснение репетирую до сих пор.",
			"Я [подметал|подметала] трактир. В ночь исчезновения троих в книге осталось шесть кружек.",
			"Я [чинил|чинила] часы на башне. Однажды они остановились раньше полуночи.",
			"Моя жена умела читать следы. Она ушла в лес одна, оставив обувь у порога.",
			"Я [охотился|охотилась] на волков. Теперь соседи платят, чтобы я не [называл|называла] их волками.",
			"Я [выращивал|выращивала] яблоки за часовней. Каждую осень кто-то стучит в запертую кладовую.",
			"Мои ножи считались лучшими в деревне. Последний заказчик пропал сразу после покупки."
		],
		"questions": {
			"arrival": ["{address}что привело тебя в нашу деревню? Сюда редко приходят случайно."],
			"night": ["{address}как прошла твоя ночь? Утром тебя видели совсем не там, где ждали."],
			"alibi": ["{address}сначала ты назвал одно убежище, потом оказался в другом. Почему?"],
			"work": ["{address}тебя видели рядом с пропавшими припасами. Что там произошло?"],
			"sabotage": ["{address}кто испортил припасы? Ты что-нибудь заметил?"],
			"death": ["{address}той ночью кого-то не досчитались. Что ты видел?"],
			"tunnel": ["{address}ты оказался в другом убежище слишком быстро. Как прошёл?"],
			"trust": ["{address}кому из жителей ты доверишь свою жизнь этой ночью?"],
			"rumor": ["{address}какой слух о деревне кажется тебе правдой?"]
		},
		"question_reply": {
			"open": ["Такой ответ я запомню. Кажется, ты говоришь прямо.", "Спасибо. Тут ценят тех, кто отвечает без уловок."],
			"guarded": ["Справедливо. Тогда сначала моя история: {story}", "Хорошо, начну я. {story}"],
			"wry": ["Шутка мрачная. Значит, ты уже понял, где оказался.", "Вот и я [думал|думала], что пережить ночь будет главным делом."],
			"written": ["Спасибо за ответ. Постараюсь запомнить именно это.", "Я тебя [услышал|услышала]. Потом сравню с тем, что скажут другие."]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}, тебя видели рядом с домом, откуда утром не вышел жилец.", "Слишком часто беда случается рядом с {who}."],
			"ACCUSE_FAKE": ["{who}, тебя видели у припасов, а их больше не стало.", "После твоей работы вёдра остались пустыми. Объяснишь, {who}?"],
			"ACCUSE_SABOTAGE": ["{who}, кто-то испортил припасы. Последним там видели тебя.", "Запасы испорчены, а {who} опять рядом. Совпадение?"],
			"ACCUSE_TUNNEL": ["{who}, зачем тебе понадобился туннель? Почему остальные узнали об этом лишь утром?", "Как тебе удалось добраться в то убежище, {who}? Дорога туда не короткая."]
		}
	},
	"en": {
		"name_label": "Player name: {name}", "name_missing": "not set", "name_prompt": "What should we call you?", "question_title": "{who} asks you",
		"answers": ["I'll tell you what I know. Ask me something specific.", "Tell me your story first. Then I'll decide what to share.", "I came hoping to survive one night. You have bigger plans here."],
		"opening": "{story} What brought you here{player_clause}?",
		"stories": [
			"I ferried people across the river. One night, my boat came back empty.",
			"I dug graves after the first winter. The ground thaws faster than people's memories.",
			"I kept the village school. Now I write down the names of those who stopped coming. My granddaughter was the last.",
			"My sister went into the woods for firewood. I still leave her a place by the stove each night.",
			"I treated the miller's family. Their house is locked, and the bill is still unpaid.",
			"I guarded the bridge the night someone vanished. I've been rehearsing my explanation ever since.",
			"I swept the inn. The night three people vanished, the ledger showed six mugs.",
			"I repaired the tower clock. Once, it stopped before midnight.",
			"My wife could read tracks. She went into the woods alone and left her shoes at the door.",
			"I hunted wolves. Now the neighbors pay me not to call them wolves.",
			"I grew apples behind the chapel. Each autumn, someone knocks on the locked cellar.",
			"They called me the best smith in the village. A customer took his knife and never returned."
		],
		"questions": {
			"arrival": ["{address}what brought you to our village? People rarely come here by accident."],
			"night": ["{address}how did you survive last night? At dawn, you were seen somewhere unexpected."],
			"alibi": ["{address}you named one shelter, then turned up at another. Why?"],
			"work": ["{address}people saw you near the missing supplies. What happened there?"],
			"sabotage": ["{address}who spoiled the supplies? Did you see anything?"],
			"death": ["{address}someone was missing by morning. What did you see that night?"],
			"tunnel": ["{address}you reached the other shelter awfully fast. How did you get there?"],
			"trust": ["{address}whose life would you trust with yours tonight?"],
			"rumor": ["{address}which rumor about this village do you believe?"]
		},
		"question_reply": {
			"open": ["I'll remember that. You sound like you're being straight with me.", "Thanks. People here value a plain answer."],
			"guarded": ["Fair enough. Here's my story first: {story}", "I'll start, then. {story}"],
			"wry": ["Dark joke. So you understand the place we've landed in.", "I thought surviving the night would be the hard part too."],
			"written": ["Thanks for telling me. I'll remember the details.", "I heard you. I'll see how that matches what others say."]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}, you were near the house whose resident never came out this morning.", "Trouble keeps happening near {who}. Too often."],
			"ACCUSE_FAKE": ["{who}, you were by the supplies, but nothing was added.", "The buckets were still empty after your shift. Care to explain, {who}?"],
			"ACCUSE_SABOTAGE": ["{who}, someone spoiled the supplies. You were seen there last.", "The supplies are ruined, and {who} was nearby again. A coincidence?"],
			"ACCUSE_TUNNEL": ["{who}, you used the tunnel to reach another house. Why keep quiet?", "How did you get to that shelter so fast, {who}?"]
		}
	},
	"de": {
		"name_label": "Spielername: {name}", "name_missing": "nicht festgelegt", "name_prompt": "Wie heißt du?", "question_title": "{who} fragt dich",
		"answers": ["Ich sage, was ich weiß. Frag konkret.", "Erzähl du zuerst deine Geschichte. Dann entscheide ich, was ich sage.", "Ich wollte nur eine Nacht überleben. Ihr habt hier größere Pläne."],
		"opening": "{story} Was führt dich hierher{player_clause}?",
		"stories": [
			"Ich brachte Leute mit dem Boot über den Fluss. Eines Nachts kam das Boot leer zurück.",
			"Nach dem ersten Winter habe ich Gräber ausgehoben. Der Boden taut schneller auf als die Erinnerung.",
			"Ich leitete die Dorfschule. Jetzt notiere ich, wer plötzlich nicht mehr kommt.",
			"Mein Bruder ging in den Wald, um Holz zu holen. Ich lasse ihm noch immer einen Platz am Ofen frei.",
			"Ich behandelte die Familie des Müllers. Ihr Haus ist verschlossen, die Rechnung noch offen.",
			"In der Nacht, in der jemand verschwand, bewachte ich die Brücke. Meine Erklärung übe ich bis heute.",
			"Ich fegte die Schenke. Als drei verschwanden, standen sechs Krüge im Buch.",
			"Ich reparierte die Turmuhr. Einmal blieb sie vor Mitternacht stehen.",
			"Meine Frau konnte Spuren lesen. Sie ging allein in den Wald und ließ ihre Schuhe vor der Tür.",
			"Ich jagte Wölfe. Jetzt bezahlen mich die Nachbarn dafür, sie nicht Wölfe zu nennen.",
			"Hinter der Kapelle zog ich Äpfel. Jeden Herbst klopft jemand an den Keller.",
			"Man hielt mich für den besten Schmied. Ein Kunde nahm sein Messer und kam nie zurück."
		],
		"questions": {
			"arrival": ["{address}was führt dich in unser Dorf? Hierher verirrt man sich selten."],
			"night": ["{address}wie hast du die letzte Nacht überstanden? Bei Tagesanbruch warst du ganz woanders."],
			"alibi": ["{address}erst nanntest du ein Haus, dann warst du in einem anderen. Warum?"],
			"work": ["{address}man sah dich bei den fehlenden Vorräten. Was ist dort passiert?"],
			"sabotage": ["{address}wer hat die Vorräte verdorben? Hast du etwas gesehen?"],
			"death": ["{address}am Morgen fehlte jemand. Was hast du in der Nacht gesehen?"],
			"tunnel": ["{address}du warst erstaunlich schnell im anderen Haus. Wie bist du hingekommen?"],
			"trust": ["{address}wem würdest du heute Nacht dein Leben anvertrauen?"],
			"rumor": ["{address}welches Gerücht über das Dorf hältst du für wahr?"]
		},
		"question_reply": {
			"open": ["Das merke ich mir. Du klingst, als würdest du offen reden.", "Danke. Hier schätzt man eine klare Antwort."],
			"guarded": ["Verständlich. Dann erzähle ich zuerst meine Geschichte: {story}", "Gut, ich fange an. {story}"],
			"wry": ["Schwarzer Humor. Du hast wohl verstanden, wo du gelandet bist.", "Ich dachte auch, die Nacht zu überstehen wäre das Schwerste."],
			"written": ["Danke, dass du mir das erzählt hast. Ich merke mir die Einzelheiten.", "Ich habe dich gehört. Mal sehen, ob die anderen dasselbe sagen."]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}, du warst bei dem Haus, aus dem heute Morgen niemand kam.", "Bei {who} geschieht auffällig oft etwas Schlimmes."],
			"ACCUSE_FAKE": ["{who}, du warst bei den Vorräten, doch es kam nichts dazu.", "Nach deiner Arbeit waren die Eimer noch leer. Erklärst du das, {who}?"],
			"ACCUSE_SABOTAGE": ["{who}, jemand hat die Vorräte verdorben. Zuletzt sah man dich dort.", "Die Vorräte sind hin, und {who} war wieder in der Nähe."],
			"ACCUSE_TUNNEL": ["{who}, du bist durch den Tunnel in ein anderes Haus gelangt. Warum hast du geschwiegen?", "Wie bist du so schnell zu diesem Haus gekommen, {who}?"]
		}
	},
	"fr": {
		"name_label": "Nom du joueur : {name}", "name_missing": "non défini", "name_prompt": "Comment t’appelles-tu ?", "question_title": "{who} te pose une question",
		"answers": ["Je te dirai ce que je sais. Pose une question précise.", "Raconte d’abord ton histoire. Je déciderai ensuite quoi partager.", "Je voulais survivre une nuit. Vous avez de plus grands projets ici."],
		"opening": "{story} Qu’est-ce qui t’amène ici{player_clause} ?",
		"stories": [
			"Je faisais traverser les gens en barque. Une nuit, le bateau est revenu vide.",
			"J’ai creusé des tombes après le premier hiver. La terre dégèle plus vite que les souvenirs.",
			"Je tenais l’école du village. Maintenant, je note les noms de ceux qui ne viennent plus.",
			"Mon frère est parti chercher du bois. Je lui garde encore une place près du poêle.",
			"J’ai soigné la famille du meunier. Leur maison est fermée et l’ardoise reste impayée.",
			"Je gardais le pont la nuit où quelqu’un a disparu. Je répète encore mon explication.",
			"Je balayais l’auberge. La nuit de trois disparitions, le registre comptait six chopes.",
			"Je réparais l’horloge du clocher. Un jour, elle s’est arrêtée avant minuit.",
			"Ma femme savait lire les traces. Elle est partie seule dans les bois, laissant ses chaussures au seuil.",
			"Je chassais les loups. Maintenant, les voisins me paient pour ne pas les appeler ainsi.",
			"Je cultivais des pommes derrière la chapelle. Chaque automne, on frappe à la cave fermée.",
			"On me disait meilleur forgeron du village. Un client a pris son couteau et n’est jamais revenu."
		],
		"questions": {
			"arrival": ["{address}qu’est-ce qui t’amène dans notre village ? On ne vient pas ici par hasard."],
			"night": ["{address}comment as-tu survécu à la nuit dernière ? À l’aube, on t’a vu ailleurs."],
			"alibi": ["{address}tu as d’abord nommé un refuge, puis tu étais dans un autre. Pourquoi ?"],
			"work": ["{address}on t’a vu près des provisions manquantes. Que s’est-il passé ?"],
			"sabotage": ["{address}qui a abîmé les provisions ? As-tu vu quelque chose ?"],
			"death": ["{address}quelqu’un manquait à l’appel au matin. Qu’as-tu vu cette nuit-là ?"],
			"tunnel": ["{address}tu as rejoint l’autre refuge bien vite. Comment as-tu fait ?"],
			"trust": ["{address}à qui confierais-tu ta vie cette nuit ?"],
			"rumor": ["{address}quelle rumeur sur le village te semble vraie ?"]
		},
		"question_reply": {
			"open": ["Je retiendrai ça. Tu as l’air de me répondre franchement.", "Merci. Ici, on apprécie les réponses directes."],
			"guarded": ["C’est juste. Alors, voici d’abord mon histoire : {story}", "D’accord, je commence. {story}"],
			"wry": ["Humour noir. Tu as compris où tu as atterri.", "Je croyais aussi que survivre à la nuit serait le plus difficile."],
			"written": ["Merci de me l’avoir raconté. Je retiendrai les détails.", "J’ai entendu. Je verrai si les autres racontent la même chose."]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}, tu étais près de la maison dont personne n’est sorti ce matin.", "Le malheur arrive souvent près de {who}."],
			"ACCUSE_FAKE": ["{who}, tu étais près des provisions, mais rien n’a été ajouté.", "Après ton travail, les seaux étaient encore vides. Une explication, {who} ?"],
			"ACCUSE_SABOTAGE": ["{who}, quelqu’un a abîmé les provisions. On t’a vu là en dernier.", "Les réserves sont gâchées et {who} était encore dans les parages."],
			"ACCUSE_TUNNEL": ["{who}, tu as pris le tunnel pour rejoindre une autre maison. Pourquoi te taire ?", "Comment es-tu arrivé si vite là-bas, {who} ?"]
		}
	},
	"es": {
		"name_label": "Nombre del jugador: {name}", "name_missing": "sin definir", "name_prompt": "¿Cómo te llamas?", "question_title": "{who} te pregunta",
		"answers": ["Te contaré lo que sé. Pregunta algo concreto.", "Cuéntame primero tu historia. Después decidiré qué compartir.", "Solo quería sobrevivir una noche. Aquí tienen planes más ambiciosos."],
		"opening": "{story} ¿Qué te trae aquí{player_clause}?",
		"stories": [
			"Llevaba gente en barca por el río. Una noche, la barca regresó vacía.",
			"Cavé tumbas después del primer invierno. La tierra se deshiela antes que los recuerdos.",
			"Llevaba la escuela del pueblo. Ahora apunto quién dejó de venir.",
			"Mi hermano fue al bosque por leña. Todavía le guardo un sitio junto a la estufa.",
			"Atendí a la familia del molinero. Su casa está cerrada y la cuenta sigue pendiente.",
			"Vigilaba el puente la noche que alguien desapareció. Aún ensayo mi explicación.",
			"Barría la posada. La noche que desaparecieron tres, el libro registró seis jarras.",
			"Reparaba el reloj de la torre. Una vez se detuvo antes de medianoche.",
			"Mi mujer sabía leer huellas. Entró sola al bosque y dejó sus zapatos en la puerta.",
			"Cazaba lobos. Ahora los vecinos me pagan para que no los llame así.",
			"Cultivaba manzanas detrás de la capilla. Cada otoño alguien llama a la bodega cerrada.",
			"Decían que era el mejor herrero. Un cliente se llevó su cuchillo y nunca volvió."
		],
		"questions": {
			"arrival": ["{address}¿qué te trajo a nuestro pueblo? Aquí casi nadie llega por casualidad."],
			"night": ["{address}¿cómo sobreviviste a la última noche? Al amanecer te vieron en otro sitio."],
			"alibi": ["{address}dijiste que irías a un refugio y apareciste en otro. ¿Por qué?"],
			"work": ["{address}te vieron cerca de las provisiones que faltan. ¿Qué pasó allí?"],
			"sabotage": ["{address}¿quién estropeó las provisiones? ¿Viste algo?"],
			"death": ["{address}por la mañana faltaba alguien. ¿Qué viste esa noche?"],
			"tunnel": ["{address}llegaste demasiado rápido al otro refugio. ¿Cómo lo hiciste?"],
			"trust": ["{address}¿a quién le confiarías tu vida esta noche?"],
			"rumor": ["{address}¿qué rumor del pueblo te parece cierto?"]
		},
		"question_reply": {
			"open": ["Lo recordaré. Parece que me hablas con franqueza.", "Gracias. Aquí se valora una respuesta clara."],
			"guarded": ["Es justo. Primero te cuento mi historia: {story}", "Empiezo yo, entonces. {story}"],
			"wry": ["Humor negro. Ya sabes dónde has venido a parar.", "Yo también creía que sobrevivir a la noche sería lo más difícil."],
			"written": ["Gracias por contármelo. Recordaré los detalles.", "Te he oído. Veré si los demás cuentan lo mismo."]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}, estabas cerca de la casa de la que nadie salió esta mañana.", "Los problemas ocurren demasiado a menudo cerca de {who}."],
			"ACCUSE_FAKE": ["{who}, estuviste junto a las provisiones y no añadiste nada.", "Después de tu trabajo, los cubos seguían vacíos. ¿Lo explicas, {who}?"],
			"ACCUSE_SABOTAGE": ["{who}, alguien estropeó las provisiones. Te vieron allí al final.", "Las provisiones están arruinadas y {who} andaba cerca otra vez."],
			"ACCUSE_TUNNEL": ["{who}, usaste el túnel para llegar a otra casa. ¿Por qué callaste?", "¿Cómo llegaste tan rápido a ese refugio, {who}?"]
		}
	},
	"pt": {
		"name_label": "Nome do jogador: {name}", "name_missing": "não definido", "name_prompt": "Qual é o seu nome?", "question_title": "{who} pergunta a você",
		"answers": ["Vou contar o que sei. Faça uma pergunta direta.", "Conte sua história primeiro. Depois decido o que compartilhar.", "Eu só queria passar uma noite vivo. Vocês têm planos maiores."],
		"opening": "{story} O que trouxe você até aqui{player_clause}?",
		"stories": [
			"Eu atravessava pessoas de barco pelo rio. Uma noite, o barco voltou vazio.",
			"Cavei túmulos depois do primeiro inverno. A terra descongela antes que a memória.",
			"Eu cuidava da escola da aldeia. Agora anoto quem deixou de aparecer.",
			"Meu irmão foi buscar lenha na floresta. Ainda deixo um lugar para ele junto ao fogão.",
			"Tratei a família do moleiro. A casa está trancada e a conta continua aberta.",
			"Eu vigiava a ponte na noite em que alguém sumiu. Ainda ensaio minha explicação.",
			"Eu varria a estalagem. Na noite em que três sumiram, o livro registrou seis canecas.",
			"Eu consertava o relógio da torre. Uma vez ele parou antes da meia-noite.",
			"Minha esposa sabia ler rastros. Entrou sozinha na mata e deixou os sapatos na porta.",
			"Eu caçava lobos. Agora os vizinhos me pagam para não chamá-los assim.",
			"Eu cultivava maçãs atrás da capela. Todo outono alguém bate na adega trancada.",
			"Diziam que eu era o melhor ferreiro. Um cliente levou a faca e nunca voltou."
		],
		"questions": {
			"arrival": ["{address}o que trouxe você à nossa aldeia? Quase ninguém chega aqui por acaso."],
			"night": ["{address}como você sobreviveu à noite passada? Ao amanhecer, estava em outro lugar."],
			"alibi": ["{address}você disse que iria para um abrigo e apareceu em outro. Por quê?"],
			"work": ["{address}viram você perto dos mantimentos que sumiram. O que aconteceu?"],
			"sabotage": ["{address}quem estragou os mantimentos? Você viu alguma coisa?"],
			"death": ["{address}alguém não apareceu pela manhã. O que você viu naquela noite?"],
			"tunnel": ["{address}você chegou rápido demais ao outro abrigo. Como fez isso?"],
			"trust": ["{address}a quem você confiaria sua vida esta noite?"],
			"rumor": ["{address}qual boato sobre a aldeia parece verdadeiro?"]
		},
		"question_reply": {
			"open": ["Vou me lembrar. Parece que você está falando com franqueza.", "Obrigado. Aqui se valoriza uma resposta direta."],
			"guarded": ["Justo. Primeiro, vou contar minha história: {story}", "Tudo bem, eu começo. {story}"],
			"wry": ["Humor sombrio. Você já entendeu onde veio parar.", "Também achei que sobreviver à noite seria a parte difícil."],
			"written": ["Obrigado por contar. Vou me lembrar dos detalhes.", "Eu ouvi. Depois vejo se os outros contam a mesma coisa."]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}, você estava perto da casa de onde ninguém saiu hoje cedo.", "Problemas acontecem perto de {who} com frequência demais."],
			"ACCUSE_FAKE": ["{who}, você estava perto dos mantimentos, mas nada foi acrescentado.", "Depois do seu trabalho, os baldes continuaram vazios. Explica, {who}?"],
			"ACCUSE_SABOTAGE": ["{who}, alguém estragou os mantimentos. Viram você lá por último.", "Os mantimentos foram arruinados e {who} estava por perto de novo."],
			"ACCUSE_TUNNEL": ["{who}, você usou o túnel para chegar a outra casa. Por que ficou calado?", "Como você chegou tão rápido àquele abrigo, {who}?"]
		}
	},
	"tr": {
		"name_label": "Oyuncu adı: {name}", "name_missing": "belirtilmedi", "name_prompt": "Adın ne?", "question_title": "{who} sana soruyor",
		"answers": ["Bildiğimi anlatırım. Açıkça sor.", "Önce sen hikâyeni anlat. Sonra ne paylaşacağıma karar veririm.", "Sadece bir gece sağ çıkmak istedim. Burada planlar daha büyük."],
		"opening": "{story} Seni buraya ne getirdi{player_clause}?",
		"stories": [
			"İnsanları nehirden kayıkla geçirirdim. Bir gece kayık yolcusuz döndü.",
			"İlk kıştan sonra mezar kazdım. Toprak, anılardan önce çözülüyor.",
			"Köy okulunu işletirdim. Şimdi gelmeyenlerin adını yazıyorum.",
			"Kardeşim odun toplamak için ormana gitti. Hâlâ sobanın yanında ona yer ayırırım.",
			"Değirmencinin ailesini tedavi ettim. Evleri kilitli, borçları hâlâ duruyor.",
			"Birinin kaybolduğu gece köprüyü bekliyordum. Açıklamamı hâlâ prova ediyorum.",
			"Hanı süpürürdüm. Üç kişinin kaybolduğu gece defterde altı kupa yazıyordu.",
			"Kule saatini tamir ederdim. Bir gün saat gece yarısından önce durdu.",
			"Eşim izleri okuyabilirdi. Ayakkabılarını kapıda bırakıp ormana tek başına gitti.",
			"Kurt avlardım. Şimdi komşular bana onlara kurt dememem için para veriyor.",
			"Şapelin arkasında elma yetiştirirdim. Her sonbahar kilitli mahzenin kapısı çalınır.",
			"Köyün en iyi demircisi derlerdi. Bir müşteri bıçağını aldı, bir daha dönmedi."
		],
		"questions": {
			"arrival": ["{address}köyümüze seni ne getirdi? Buraya pek kimse tesadüfen gelmez."],
			"night": ["{address}geçen geceyi nasıl atlattın? Şafakta seni beklenmedik bir yerde gördüler."],
			"alibi": ["{address}önce bir evi söyledin, sonra başka bir yerde çıktın. Neden?"],
			"work": ["{address}eksilen erzakların yanında seni görmüşler. Orada ne oldu?"],
			"sabotage": ["{address}erzağı kim bozdu? Bir şey gördün mü?"],
			"death": ["{address}sabah biri ortada yoktu. O gece ne gördün?"],
			"tunnel": ["{address}öteki eve çok çabuk vardın. Nasıl geçtin?"],
			"trust": ["{address}bu gece kime hayatını emanet edersin?"],
			"rumor": ["{address}köyle ilgili hangi söylenti sana doğru geliyor?"]
		},
		"question_reply": {
			"open": ["Bunu aklımda tutacağım. Açık konuşuyorsun gibi.", "Sağ ol. Burada net cevaplara değer verilir."],
			"guarded": ["Haklısın. Önce kendi hikâyemi anlatayım: {story}", "Peki, ben başlayayım. {story}"],
			"wry": ["Kara mizah. Buraya nasıl bir yere geldiğini anlamışsın.", "Ben de geceyi atlatmanın en zor şey olacağını sanmıştım."],
			"written": ["Anlattığın için sağ ol. Ayrıntıları aklımda tutacağım.", "Seni duydum. Bakalım başkaları da aynı şeyi söyleyecek mi."]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}, bu sabah kimsenin çıkmadığı evin yakınındaydın.", "Kötü şeyler {who} yakındayken fazla sık oluyor."],
			"ACCUSE_FAKE": ["{who}, erzakların yanındaydın ama hiçbir şey artmadı.", "Sen çalıştıktan sonra kovalar hâlâ boştu. Açıkla, {who}?"],
			"ACCUSE_SABOTAGE": ["{who}, biri erzağı bozdu. Orada en son seni görmüşler.", "Erzak mahvoldu, {who} yine yakındaydı."],
			"ACCUSE_TUNNEL": ["{who}, tünelden başka eve geçtin. Neden söylemedin?", "O eve bu kadar çabuk nasıl vardın, {who}?"]
		}
	},
	"hi": {
		"name_label": "खिलाड़ी का नाम: {name}", "name_missing": "नहीं दिया गया", "name_prompt": "तुम्हारा नाम क्या है?", "question_title": "{who} तुमसे पूछ रहे हैं",
		"answers": ["मैं जो जानता हूँ, बता दूँगा। कोई खास बात पूछो।", "पहले अपनी कहानी बताओ। फिर तय करूँगा कि क्या बताना है।", "मैं बस एक रात बचना चाहता था। यहाँ योजनाएँ कुछ बड़ी हैं।"],
		"opening": "{story} तुम्हें यहाँ क्या लाया{player_clause}?",
		"stories": [
			"मैं नाव से लोगों को नदी पार कराता था। एक रात नाव खाली लौट आई।",
			"पहली सर्दी के बाद मैंने कब्रें खोदीं। मिट्टी यादों से पहले पिघलती है।",
			"मैं गाँव का स्कूल चलाता था। अब उन लोगों के नाम लिखता हूँ जो आना बंद कर चुके हैं।",
			"मेरा भाई लकड़ी लेने जंगल गया था। आज भी चूल्हे के पास उसके लिए जगह रखता हूँ।",
			"मैंने चक्की वाले के परिवार का इलाज किया। उनका घर बंद है और हिसाब अब भी बाकी है।",
			"जिस रात कोई गायब हुआ, मैं पुल पर पहरा दे रहा था। अपना जवाब अब तक दोहराता हूँ।",
			"मैं सराय में सफ़ाई करता था। तीन लोगों के गायब होने की रात हिसाब में छह मग थे।",
			"मैं मीनार की घड़ी ठीक करता था। एक बार वह आधी रात से पहले रुक गई।",
			"मेरी पत्नी पैरों के निशान पढ़ सकती थी। वह अकेली जंगल गई और जूते दरवाज़े पर छोड़ गई।",
			"मैं भेड़ियों का शिकार करता था। अब पड़ोसी मुझे उन्हें भेड़िया न कहने के पैसे देते हैं।",
			"मैं चैपल के पीछे सेब उगाता था। हर पतझड़ बंद तहख़ाने पर कोई दस्तक देता है।",
			"लोग मुझे गाँव का सबसे अच्छा लोहार कहते थे। एक ग्राहक चाकू ले गया और फिर नहीं लौटा।"
		],
		"questions": {
			"arrival": ["{address}तुम्हें हमारे गाँव में क्या लाया? यहाँ लोग यूँ ही नहीं आते।"],
			"night": ["{address}पिछली रात कैसे बचे? सुबह तुम्हें ऐसी जगह देखा गया जहाँ उम्मीद नहीं थी।"],
			"alibi": ["{address}पहले एक घर बताया, फिर दूसरे में मिले। क्यों?"],
			"work": ["{address}तुम्हें गायब सामान के पास देखा गया। वहाँ क्या हुआ?"],
			"sabotage": ["{address}सामान किसने बिगाड़ा? कुछ देखा था?"],
			"death": ["{address}सुबह एक आदमी गायब था। उस रात तुमने क्या देखा?"],
			"tunnel": ["{address}तुम दूसरे घर बहुत जल्दी पहुँच गए। कैसे गए?"],
			"trust": ["{address}आज रात तुम किस पर अपनी जान का भरोसा करोगे?"],
			"rumor": ["{address}गाँव की कौन-सी अफ़वाह तुम्हें सच लगती है?"]
		},
		"question_reply": {
			"open": ["तुम्हारा जवाब याद रखूँगा। लगता है तुम साफ़ बोल रहे हो।", "धन्यवाद। यहाँ सीधे जवाब की क़द्र है।"],
			"guarded": ["ठीक है। पहले मैं अपनी कहानी सुनाता हूँ: {story}", "अच्छा, मैं शुरू करता हूँ। {story}"],
			"wry": ["काला मज़ाक। लगता है तुम्हें समझ आ गया कि तुम कहाँ आ पहुँचे।", "मैंने भी सोचा था कि बस रात काटना ही मुश्किल होगा।"],
			"written": ["बताने के लिए धन्यवाद। मैं बारीकियाँ याद रखूँगा।", "मैंने सुन लिया। देखूँगा कि बाकी लोग भी यही कहते हैं या नहीं।"]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}, तुम उस घर के पास थे जहाँ से आज सुबह कोई बाहर नहीं आया।", "{who} के पास मुसीबत कुछ ज़्यादा ही आती है।"],
			"ACCUSE_FAKE": ["{who}, सामान के पास थे, फिर भी कुछ बढ़ा नहीं।", "तुम्हारे काम के बाद बाल्टियाँ खाली थीं। बताओ, {who}?"],
			"ACCUSE_SABOTAGE": ["{who}, किसी ने सामान बिगाड़ा। वहाँ आख़िर में तुम्हें देखा गया।", "सामान खराब है और {who} फिर पास में था।"],
			"ACCUSE_TUNNEL": ["{who}, तुम सुरंग से दूसरे घर गए। चुप क्यों रहे?", "तुम वहाँ इतनी जल्दी कैसे पहुँचे, {who}?"]
		}
	},
	"vi": {
		"name_label": "Tên người chơi: {name}", "name_missing": "chưa đặt", "name_prompt": "Bạn tên gì?", "question_title": "{who} hỏi bạn",
		"answers": ["Tôi sẽ kể những gì mình biết. Hỏi cụ thể đi.", "Kể chuyện của bạn trước. Rồi tôi sẽ quyết định nói gì.", "Tôi chỉ muốn sống qua một đêm. Ở đây ai cũng có kế hoạch lớn hơn."],
		"opening": "{story} Điều gì đưa bạn đến đây{player_clause}?",
		"stories": [
			"Tôi chở người qua sông bằng thuyền. Một đêm, chiếc thuyền trở về không có ai.",
			"Tôi đào mộ sau mùa đông đầu tiên. Đất tan băng nhanh hơn ký ức.",
			"Tôi trông nom trường làng. Giờ tôi ghi tên những người đã thôi đến lớp.",
			"Em trai tôi vào rừng kiếm củi. Tối nào tôi cũng để dành chỗ bên bếp cho nó.",
			"Tôi chữa bệnh cho gia đình người xay bột. Nhà họ khóa cửa, tiền thuốc vẫn chưa trả.",
			"Tôi gác cầu vào đêm có người mất tích. Đến giờ tôi vẫn tập nói lời giải thích.",
			"Tôi quét quán trọ. Đêm ba người mất tích, sổ ghi có sáu chiếc cốc.",
			"Tôi sửa đồng hồ trên tháp. Có lần nó dừng trước nửa đêm.",
			"Vợ tôi biết đọc dấu chân. Bà ấy vào rừng một mình và để giày ở trước cửa.",
			"Tôi từng săn sói. Giờ hàng xóm trả tiền để tôi đừng gọi họ là sói.",
			"Tôi trồng táo sau nhà nguyện. Mỗi mùa thu, có ai đó gõ cửa hầm đã khóa.",
			"Người ta gọi tôi là thợ rèn giỏi nhất. Một khách hàng lấy con dao rồi không quay lại."
		],
		"questions": {
			"arrival": ["{address}điều gì đưa bạn đến làng chúng tôi? Hiếm ai đến đây mà không có lý do."],
			"night": ["{address}bạn đã sống sót qua đêm qua thế nào? Bình minh lên, người ta thấy bạn ở chỗ khác."],
			"alibi": ["{address}bạn nói sẽ đến một nhà, rồi lại xuất hiện ở nhà khác. Vì sao?"],
			"work": ["{address}người ta thấy bạn cạnh số lương thực bị mất. Chuyện gì đã xảy ra?"],
			"sabotage": ["{address}ai đã phá hoại lương thực? Bạn có thấy gì không?"],
			"death": ["{address}sáng nay có người mất tích. Đêm đó bạn thấy gì?"],
			"tunnel": ["{address}bạn đến nhà bên kia nhanh quá. Bạn đi đường nào?"],
			"trust": ["{address}đêm nay bạn tin ai đến mức giao mạng sống của mình?"],
			"rumor": ["{address}lời đồn nào về ngôi làng này khiến bạn tin?"]
		},
		"question_reply": {
			"open": ["Tôi sẽ nhớ câu trả lời này. Có vẻ bạn đang nói thật lòng.", "Cảm ơn. Ở đây người ta quý câu trả lời thẳng thắn."],
			"guarded": ["Cũng phải. Để tôi kể chuyện của mình trước: {story}", "Được, tôi bắt đầu. {story}"],
			"wry": ["Hài hước đen đấy. Chắc bạn hiểu mình vừa đến nơi nào rồi.", "Tôi cũng tưởng sống qua đêm mới là chuyện khó nhất."],
			"written": ["Cảm ơn đã kể. Tôi sẽ nhớ những chi tiết đó.", "Tôi nghe rồi. Để xem người khác có kể giống vậy không."]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}, bạn ở gần căn nhà mà sáng nay không ai bước ra.", "Rắc rối cứ xảy ra gần {who} quá thường xuyên."],
			"ACCUSE_FAKE": ["{who}, bạn ở cạnh đồ tiếp tế mà chẳng có gì tăng lên.", "Sau lượt làm việc của bạn, xô vẫn rỗng. Giải thích đi, {who}?"],
			"ACCUSE_SABOTAGE": ["{who}, có người phá hoại đồ tiếp tế. Người ta thấy bạn ở đó cuối cùng.", "Đồ tiếp tế hỏng rồi, {who} lại ở gần đó."],
			"ACCUSE_TUNNEL": ["{who}, bạn dùng đường hầm sang nhà khác. Sao không nói?", "Bạn đến căn nhà kia nhanh thế bằng cách nào, {who}?"]
		}
	},
	"zh": {
		"name_label": "玩家姓名：{name}", "name_missing": "未设置", "name_prompt": "你叫什么名字？", "question_title": "{who}在问你",
		"answers": ["我会说出我知道的事。问具体一点。", "先讲讲你的经历，再决定我说什么。", "我只想熬过这一夜。你们的打算可大得多。"],
		"opening": "{story} 你为什么来到这里{player_clause}？",
		"stories": [
			"我曾撑船送人过河。有一天夜里，船回来时空无一人。",
			"第一个冬天过后，我开始挖坟。泥土解冻得比记忆还快。",
			"我曾在村里的学校教书。现在我记下那些不再来上学的名字。",
			"我弟弟进森林捡柴后再没回来。我每天仍在炉边给他留个位子。",
			"我给磨坊主一家治过病。他们的房子锁着，药钱至今没付清。",
			"有人失踪的那晚，我在桥边守夜。直到现在，我还在练习怎么解释。",
			"我曾在旅店打扫。三个人失踪的那晚，账本上却记着六只杯子。",
			"我修过塔楼的钟。有一次，它在午夜前就停了。",
			"我的妻子会辨认脚印。她独自进了森林，把鞋留在门口。",
			"我以前猎狼。现在邻居付钱让我别把他们叫作狼。",
			"我曾在教堂后种苹果。每年秋天，都有人敲那间锁着的地窖门。",
			"人们说我是村里最好的铁匠。有个客人拿走刀后再也没回来。"
		],
		"questions": {
			"arrival": ["{address}是什么让你来到我们村子？这里很少有人会无缘无故出现。"],
			"night": ["{address}你昨晚是怎么活下来的？天亮时，有人在意料之外的地方看见了你。"],
			"alibi": ["{address}你先说要去一间屋子，后来却出现在另一间。为什么？"],
			"work": ["{address}有人看见你在丢失的物资旁边。那里发生了什么？"],
			"sabotage": ["{address}是谁毁了物资？你看见了什么吗？"],
			"death": ["{address}早上有人不见了。那晚你看见了什么？"],
			"tunnel": ["{address}你到另一间屋子的速度太快了。你是怎么过去的？"],
			"trust": ["{address}今晚你愿意把性命托付给谁？"],
			"rumor": ["{address}村里的哪条传言让你觉得是真的？"]
		},
		"question_reply": {
			"open": ["我会记住这个回答。你似乎在坦诚地说话。", "谢谢。在这里，人们看重直截了当的回答。"],
			"guarded": ["有道理。那我先讲讲自己的故事：{story}", "好吧，我先说。{story}"],
			"wry": ["黑色幽默。看来你已经知道自己到了什么地方。", "我也以为熬过夜晚就是最难的事。"],
			"written": ["谢谢你愿意告诉我。我会记住这些细节。", "我听到了。之后我会看看别人是不是也这么说。"]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}，你当时就在那间早上没人出来的屋子附近。", "麻烦事发生在{who}附近的次数太多了。"],
			"ACCUSE_FAKE": ["{who}，你在物资旁边忙了半天，数量却没增加。", "你干完活后，桶还是空的。能解释一下吗，{who}？"],
			"ACCUSE_SABOTAGE": ["{who}，有人毁了物资。最后有人看见你在那里。", "物资被毁了，{who}又在附近。"],
			"ACCUSE_TUNNEL": ["{who}，你走地道去了另一间屋子。为什么不说？", "{who}，你怎么这么快就到了那间屋子？"]
		}
	}
}


## Дополнительные эпизоды, личные главы и приметы у двери. Все строки есть на каждом языке игры.
const EXTRA := {
	"ru": {
		"cases": [["Лодка вернулась пустой", "Паромщик клянётся, что перевёз троих. На берегу нашли только мокрый след и один сапог."], ["Земля у могилы", "Старую могилу кто-то перекапывает по ночам. Наутро у каждого своя версия, кто был рядом."], ["Имя на доске", "В заброшенной школе каждое утро появляется новое имя. Учитель говорит, что мел давно отсырел."]],
		"anchor_titles": ["[Паромщик|Паромщица]", "[Могильщик|Могильщица]", "[Учитель|Учительница]"],
		"chapters": [["В камышах я [нашёл|нашла] один сапог. Второй до сих пор стоит у меня у печи." , "Весной под водой мелькнул огонёк. Я [решил|решила], что утопленники наконец-то завели себе фонарь."], ["Одну могилу я [оставил|оставила] без имени. Каждую ночь кто-то присыпает её свежей землёй.", "Я [узнал|узнала] почерк на деревянной табличке. Он принадлежал человеку, которого я [хоронил|хоронила] дважды."], ["В классе снова появилась строка: «Мы ещё здесь». Мел лежит в запертом ящике.", "Я [перестал|перестала] стирать имена с доски. Список стал длиннее, зато посещаемость теперь безупречная."]],
		"question_tags": ["У соседа своя версия. Сверю её с твоей.", "Подумай о подробности, которую остальные могли пропустить."],
		"door_signs": {"breath": "Между словами почти не видно выдоха. В такую стужу пар обычно заметнее.", "rhythm": "Три удара ложатся с одинаковой паузой, словно их отмерили заранее.", "shadow": "Тень пальцев на двери на мгновение отстаёт от руки.", "ordinary": "Пальцы дрожат, слова сбиваются. Страх или холод, отсюда не понять."}
	},
	"en": {
		"cases": [["The boat came back empty", "The ferryman swears he carried three people. On the bank, someone found a wet trail and one boot."], ["Fresh earth", "Someone keeps digging at an old grave. By morning, every witness remembers a different visitor."], ["A name on the slate", "A new name appears in the abandoned school each morning. The teacher says the chalk has been damp for years."]],
		"anchor_titles": ["[Ferryman|Ferrywoman]", "Gravedigger", "Teacher"],
		"chapters": [["I found one boot in the reeds. The other still sits by my stove.", "A light moved under the spring flood. I decided the drowned had finally bought a lantern."], ["I left one grave unnamed. Someone covers it with fresh earth every night.", "I recognized the writing on the marker. It belonged to someone I buried twice."], ["The line appeared again: ‘We are still here.’ The chalk is locked away.", "I stopped erasing the names. The list grew, but attendance became perfect."]],
		"question_tags": ["Your neighbour has another version. I want to compare them.", "Think of one detail the others may have missed."],
		"door_signs": {"breath": "There is barely a trace of breath between words. It should show more in this cold.", "rhythm": "The three knocks have exactly the same pause between them.", "shadow": "The shadow of the visitor’s fingers lags behind the hand for a moment.", "ordinary": "Their fingers shake and the words stumble. Fear or cold, you cannot tell from here."}
	},
	"de": {
		"cases": [["Das Boot kam leer zurück", "Der Fährmann schwört, drei Menschen übergesetzt zu haben. Am Ufer fand man nur eine nasse Spur und einen Stiefel."], ["Frische Erde", "Jemand gräbt nachts an einem alten Grab. Am Morgen erinnert sich jeder Zeuge an einen anderen Besucher."], ["Ein Name auf der Tafel", "Jeden Morgen steht ein neuer Name in der verlassenen Schule. Der Lehrer sagt, die Kreide sei längst feucht."]],
		"anchor_titles": ["[Fährmann|Fährfrau]", "[Totengräber|Totengräberin]", "[Lehrer|Lehrerin]"],
		"chapters": [["Im Schilf fand ich einen Stiefel. Der andere steht noch immer bei meinem Ofen.", "Im Frühlingshochwasser sah ich ein Licht. Ich dachte, die Ertrunkenen hätten sich endlich eine Laterne gekauft."], ["Ein Grab ließ ich ohne Namen. Jede Nacht deckt jemand frische Erde darauf.", "Ich erkannte die Schrift auf dem Schild. Sie gehörte jemandem, den ich zweimal begraben habe."], ["Die Zeile stand wieder dort: „Wir sind noch hier.“ Die Kreide liegt eingeschlossen.", "Ich wische die Namen nicht mehr weg. Die Liste wurde länger, aber die Anwesenheit ist nun tadellos."]],
		"question_tags": ["Dein Nachbar erzählt es anders. Ich möchte die Versionen vergleichen.", "Denk an ein Detail, das den anderen entgangen sein könnte."],
		"door_signs": {"breath": "Zwischen den Worten ist kaum Atem zu sehen. Bei dieser Kälte müsste mehr zu sehen sein.", "rhythm": "Zwischen den drei Schlägen liegt jedes Mal genau dieselbe Pause.", "shadow": "Der Schatten der Finger hinkt einen Augenblick hinter der Hand her.", "ordinary": "Die Finger zittern, die Worte stocken. Angst oder Kälte, von hier aus schwer zu sagen."}
	},
	"fr": {
		"cases": [["La barque est revenue vide", "Le passeur jure avoir transporté trois personnes. Sur la rive, on n’a trouvé qu’une trace mouillée et une botte."], ["La terre fraîche", "Quelqu’un creuse une vieille tombe chaque nuit. Au matin, les témoins décrivent chacun un visiteur différent."], ["Un nom sur l’ardoise", "Un nouveau nom apparaît chaque matin dans l’école abandonnée. Le maître dit que la craie est humide depuis des années."]],
		"anchor_titles": ["[Passeur|Passeuse]", "[Fossoyeur|Fossoyeuse]", "[Enseignant|Enseignante]"],
		"chapters": [["J’ai trouvé une botte dans les roseaux. L’autre est toujours près de mon poêle.", "Au printemps, une lumière a bougé sous l’eau. J’ai décidé que les noyés s’étaient enfin offert une lanterne."], ["J’ai laissé une tombe sans nom. Chaque nuit, quelqu’un la recouvre de terre fraîche.", "J’ai reconnu l’écriture sur la plaque. Elle appartenait à quelqu’un que j’ai enterré deux fois."], ["La phrase est revenue : « Nous sommes encore là. » La craie est enfermée.", "J’ai cessé d’effacer les noms. La liste s’allonge, mais les présences sont parfaites."]],
		"question_tags": ["Ton voisin raconte autre chose. Je veux comparer vos versions.", "Pense à un détail que les autres ont peut-être manqué."],
		"door_signs": {"breath": "On voit à peine son souffle entre les mots. Par ce froid, il devrait être plus visible.", "rhythm": "Les trois coups sont séparés par exactement la même pause.", "shadow": "L’ombre de ses doigts prend un instant de retard sur sa main.", "ordinary": "Ses doigts tremblent et ses mots hésitent. La peur ou le froid, impossible à dire d’ici."}
	},
	"es": {
		"cases": [["La barca volvió vacía", "El barquero jura que cruzó a tres personas. En la orilla solo encontraron un rastro mojado y una bota."], ["Tierra removida", "Alguien cava una tumba antigua cada noche. Por la mañana, cada testigo recuerda a un visitante distinto."], ["Un nombre en la pizarra", "Cada mañana aparece un nombre nuevo en la escuela abandonada. El maestro dice que la tiza lleva años húmeda."]],
		"anchor_titles": ["[Barquero|Barquera]", "[Sepulturero|Sepulturera]", "[Maestro|Maestra]"],
		"chapters": [["Encontré una bota entre los juncos. La otra sigue junto a mi estufa.", "En la crecida de primavera vi una luz bajo el agua. Decidí que los ahogados por fin se habían comprado un farol."], ["Dejé una tumba sin nombre. Cada noche alguien la cubre con tierra fresca.", "Reconocí la letra de la placa. Era de alguien a quien enterré dos veces."], ["La frase volvió a aparecer: «Seguimos aquí». La tiza está bajo llave.", "Dejé de borrar los nombres. La lista creció, pero la asistencia ahora es perfecta."]],
		"question_tags": ["Tu vecino cuenta otra versión. Quiero compararlas.", "Piensa en un detalle que los demás quizá pasaron por alto."],
		"door_signs": {"breath": "Casi no se ve su aliento entre palabras. Con este frío debería notarse más.", "rhythm": "Los tres golpes tienen exactamente la misma pausa.", "shadow": "La sombra de sus dedos tarda un instante en seguir a la mano.", "ordinary": "Le tiemblan los dedos y tropiezan sus palabras. Desde aquí no sabes si es miedo o frío."}
	},
	"pt": {
		"cases": [["O barco voltou vazio", "O barqueiro jura que levou três pessoas. Na margem, encontraram apenas um rastro molhado e uma bota."], ["Terra recém-revolvida", "Alguém mexe numa sepultura antiga toda noite. Pela manhã, cada testemunha lembra de uma visita diferente."], ["Um nome no quadro", "Toda manhã surge um nome novo na escola abandonada. O professor diz que o giz está úmido há anos."]],
		"anchor_titles": ["[Barqueiro|Barqueira]", "[Coveiro|Coveira]", "[Professor|Professora]"],
		"chapters": [["Encontrei uma bota entre os juncos. A outra continua perto do meu fogão.", "Na cheia da primavera vi uma luz sob a água. Decidi que os afogados enfim compraram uma lanterna."], ["Deixei uma sepultura sem nome. Toda noite alguém a cobre com terra fresca.", "Reconheci a letra na placa. Era de alguém que enterrei duas vezes."], ["A frase apareceu de novo: “Ainda estamos aqui.” O giz está trancado.", "Parei de apagar os nomes. A lista cresceu, mas a chamada ficou perfeita."]],
		"question_tags": ["Seu vizinho conta outra versão. Quero comparar as duas.", "Pense em um detalhe que os outros talvez não tenham percebido."],
		"door_signs": {"breath": "Quase não se vê o bafo entre as palavras. Nesse frio, deveria aparecer mais.", "rhythm": "Os três golpes têm exatamente o mesmo intervalo.", "shadow": "A sombra dos dedos demora um instante para acompanhar a mão.", "ordinary": "Os dedos tremem e as palavras falham. Daqui não dá para saber se é medo ou frio."}
	},
	"tr": {
		"cases": [["Kayık boş döndü", "Kayıkçı üç kişiyi karşıya geçirdiğine yemin ediyor. Kıyıda yalnızca ıslak bir iz ve tek bir çizme bulundu."], ["Taze toprak", "Biri her gece eski bir mezarı kazıyor. Sabah olunca her tanık başka bir ziyaretçiyi hatırlıyor."], ["Tahtadaki isim", "Terk edilmiş okulda her sabah yeni bir isim beliriyor. Öğretmen tebeşirin yıllardır nemli olduğunu söylüyor."]],
		"anchor_titles": ["Kayıkçı", "Mezarcı", "Öğretmen"],
		"chapters": [["Sazlıkta bir çizme buldum. Diğeri hâlâ sobamın yanında duruyor.", "Bahar taşkınında suyun altında bir ışık gördüm. Boğulanlar sonunda fener almış diye düşündüm."], ["Bir mezarı isimsiz bıraktım. Biri her gece üstünü taze toprakla örtüyor.", "Tahtadaki yazıyı tanıdım. İki kez gömdüğüm birine aitti."], ["Tahtada yine şu yazıyordu: “Hâlâ buradayız.” Tebeşir kilitli çekmecede.", "İsimleri silmeyi bıraktım. Liste uzadı ama yoklama artık kusursuz."]],
		"question_tags": ["Komşun başka türlü anlatıyor. İki anlatımı karşılaştıracağım.", "Başkalarının kaçırmış olabileceği bir ayrıntıyı düşün."],
		"door_signs": {"breath": "Konuşurken nefesi neredeyse görünmüyor. Bu soğukta daha belirgin olmalı.", "rhythm": "Üç vuruşun arasındaki süre tamamen aynı.", "shadow": "Parmaklarının gölgesi elini bir an gecikmeyle izliyor.", "ordinary": "Parmakları titriyor, sözleri takılıyor. Buradan korku mu soğuk mu anlayamıyorsun."}
	},
	"hi": {
		"cases": [["नाव खाली लौटी", "नाविक कसम खाता है कि उसने तीन लोगों को पार पहुँचाया। किनारे पर बस गीले निशान और एक जूता मिला।"], ["ताज़ी मिट्टी", "हर रात कोई पुरानी कब्र खोदता है। सुबह तक हर गवाह को कोई दूसरा आगंतुक याद रहता है।"], ["पट्टी पर नाम", "छोड़े गए स्कूल में हर सुबह एक नया नाम दिखता है। शिक्षक कहता है कि चॉक बरसों से गीली है।"]],
		"anchor_titles": ["नाविक", "[कब्र खोदने वाला|कब्र खोदने वाली]", "[शिक्षक|शिक्षिका]"],
		"chapters": [["सरकंडों में मुझे एक जूता मिला। दूसरा अब भी मेरे चूल्हे के पास है।", "वसंत की बाढ़ में पानी के नीचे रोशनी दिखी। मैंने सोचा, डूबे हुए लोगों ने आखिर लालटेन खरीद ली।"], ["एक कब्र पर मैंने नाम नहीं लिखा। कोई हर रात उस पर ताज़ी मिट्टी डालता है।", "तख्ती की लिखावट पहचान ली। वह उसी की थी जिसे मैंने दो बार दफनाया।"], ["पट्टी पर फिर लिखा था: “हम अब भी यहीं हैं।” चॉक ताले में बंद है।", "मैंने नाम मिटाना छोड़ दिया। सूची लंबी हुई, पर हाज़िरी अब पूरी रहती है।"]],
		"question_tags": ["पड़ोसी की कहानी अलग है। दोनों बातों का मिलान करना है।", "ऐसी बात याद करो जो बाकी लोगों से छूट गई हो।"],
		"door_signs": {"breath": "बातों के बीच उसकी साँस मुश्किल से दिखती है। इस ठंड में भाप अधिक दिखनी चाहिए।", "rhythm": "तीनों दस्तकों के बीच बिल्कुल बराबर ठहराव है।", "shadow": "उँगलियों की परछाईं हाथ के पीछे एक पल से चलती है।", "ordinary": "उँगलियाँ काँपती हैं और बात अटकती है। यहाँ से डर और ठंड में फर्क नहीं दिखता।"}
	},
	"vi": {
		"cases": [["Con thuyền trở về trống không", "Người lái đò thề đã chở ba người qua sông. Trên bờ chỉ có dấu chân ướt và một chiếc ủng."], ["Đất mới trên mộ", "Đêm nào đó cũng đào một ngôi mộ cũ. Đến sáng, mỗi nhân chứng nhớ một người khách khác nhau."], ["Cái tên trên bảng", "Mỗi sáng, một cái tên mới hiện lên trong ngôi trường bỏ hoang. Thầy giáo nói phấn đã ẩm từ lâu."]],
		"anchor_titles": ["Người lái đò", "Người đào mộ", "[Thầy giáo|Cô giáo]"],
		"chapters": [["Tôi tìm thấy một chiếc ủng trong đám sậy. Chiếc còn lại vẫn ở cạnh bếp nhà tôi.", "Mùa nước lên, tôi thấy ánh đèn dưới mặt sông. Tôi nghĩ người chết đuối cuối cùng cũng mua được đèn lồng."], ["Tôi để một ngôi mộ không tên. Đêm nào cũng có người phủ đất mới lên đó.", "Tôi nhận ra nét chữ trên bia. Đó là của người tôi đã chôn hai lần."], ["Dòng chữ lại hiện ra: “Chúng tôi vẫn ở đây.” Phấn bị khóa trong ngăn kéo.", "Tôi thôi xóa tên. Danh sách dài hơn, nhưng điểm danh giờ luôn đủ."]],
		"question_tags": ["Hàng xóm kể khác. Tôi muốn đối chiếu hai lời kể.", "Hãy nhớ một chi tiết mà người khác có thể bỏ sót."],
		"door_signs": {"breath": "Giữa những lời nói, hơi thở gần như không hiện ra. Trời lạnh thế này đáng lẽ phải rõ hơn.", "rhythm": "Ba tiếng gõ có khoảng nghỉ giống hệt nhau.", "shadow": "Bóng ngón tay chậm hơn bàn tay một thoáng.", "ordinary": "Ngón tay run, lời nói ngập ngừng. Đứng đây không rõ vì sợ hay vì lạnh."}
	},
	"zh": {
		"cases": [["空船归来", "摆渡人发誓自己送了三个人过河。岸边只找到湿的脚印和一只靴子。"], ["新翻的泥土", "每晚都有人挖一座旧坟。到了早晨，每个目击者都记得不同的访客。"], ["黑板上的名字", "废弃学校里每天早晨都会出现一个新名字。老师说粉笔早就受潮了。"]],
		"anchor_titles": ["摆渡人", "掘墓人", "教师"],
		"chapters": [["我在芦苇里找到一只靴子。另一只还放在我的炉边。", "春汛时我看见水下有光。我想，溺死的人终于买得起灯笼了。"], ["我留了一座无名坟。每晚都有人给它添上新土。", "我认出了墓牌上的字迹，那属于一个我埋了两次的人。"], ["那句话又出现了：“我们还在这里。”粉笔被锁了起来。", "我不再擦掉名字。名单变长了，不过出勤率总算完美。"]],
		"question_tags": ["邻居讲的版本不同，我想把两种说法对一对。", "想想有没有别人忽略的细节。"],
		"door_signs": {"breath": "说话间几乎看不到呼气。这样的寒夜里，本该更明显。", "rhythm": "三次敲门之间的停顿完全一样。", "shadow": "手指的影子慢了一瞬才跟上动作。", "ordinary": "手指在发抖，说话也不连贯。隔着门分不清是害怕还是冷。"}
	}
}


const DOOR_UI := {
	"ru": {"inspect": "Осмотреть", "done": "Осмотрено", "limit": "Внимательно осмотреть можно двоих. Примета может обмануть.", "record": "У двери, ночь {n}: {text}", "case_recap": "Дело «{case}». Осмотрено стучащих: {n}.", "remembered": "Из прошлого разговора: {text}"},
	"en": {"inspect": "Inspect", "done": "Inspected", "limit": "You can inspect two visitors. A sign can mislead you.", "record": "At the door, night {n}: {text}", "case_recap": "Case: “{case}”. Visitors inspected: {n}.", "remembered": "From your earlier conversation: {text}"},
	"de": {"inspect": "Prüfen", "done": "Geprüft", "limit": "Du kannst zwei Besucher prüfen. Ein Merkmal kann täuschen.", "record": "An der Tür, Nacht {n}: {text}", "case_recap": "Fall: „{case}“. Untersuchte Besucher: {n}.", "remembered": "Aus eurem früheren Gespräch: {text}"},
	"fr": {"inspect": "Observer", "done": "Observé", "limit": "Tu peux examiner deux visiteurs. Un signe peut tromper.", "record": "À la porte, nuit {n} : {text}", "case_recap": "Affaire : « {case} ». Visiteurs examinés : {n}.", "remembered": "De votre conversation précédente : {text}"},
	"es": {"inspect": "Observar", "done": "Observado", "limit": "Puedes observar a dos visitantes. Una señal puede engañar.", "record": "En la puerta, noche {n}: {text}", "case_recap": "Caso: «{case}». Visitantes observados: {n}.", "remembered": "De vuestra conversación anterior: {text}"},
	"pt": {"inspect": "Examinar", "done": "Examinado", "limit": "Você pode examinar dois visitantes. Um sinal pode enganar.", "record": "À porta, noite {n}: {text}", "case_recap": "Caso: “{case}”. Visitantes examinados: {n}.", "remembered": "Da conversa anterior: {text}"},
	"tr": {"inspect": "İncele", "done": "İncelendi", "limit": "İki ziyaretçiyi inceleyebilirsin. Bir işaret yanıltabilir.", "record": "Kapıda, {n}. gece: {text}", "case_recap": "Dosya: “{case}”. İncelenen ziyaretçi: {n}.", "remembered": "Önceki konuşmanızdan: {text}"},
	"hi": {"inspect": "जाँचें", "done": "जाँचा", "limit": "दो आगंतुकों की जाँच कर सकते हो। कोई संकेत भटका सकता है।", "record": "दरवाज़े पर, रात {n}: {text}", "case_recap": "मामला: “{case}”. जाँचे गए आगंतुक: {n}।", "remembered": "पिछली बातचीत से: {text}"},
	"vi": {"inspect": "Quan sát", "done": "Đã xem", "limit": "Bạn có thể xem xét hai người. Một dấu hiệu có thể đánh lừa.", "record": "Ở cửa, đêm {n}: {text}", "case_recap": "Vụ việc: “{case}”. Số người đã xem xét: {n}.", "remembered": "Từ cuộc trò chuyện trước: {text}"},
	"zh": {"inspect": "查看", "done": "已查看", "limit": "你可以仔细观察两位来客。线索可能会误导你。", "record": "门前，第{n}夜：{text}", "case_recap": "案件：“{case}”。查看的来客：{n}位。", "remembered": "你想起之前的谈话：{text}"}
}


static func _data() -> Dictionary:
	return DATA.get(L.code, DATA["ru"])


static func _extra() -> Dictionary:
	return EXTRA.get(L.code, EXTRA["en"])


static func case_title(id: int) -> String:
	var cases: Array = _extra().cases
	return String(cases[posmod(id, cases.size())][0])


static func anchor_title(anchor_id: int, female: bool = false) -> String:
	var titles: Array = _extra().anchor_titles
	return L.fill(String(titles[anchor_id]), {"me_f": female}) if anchor_id >= 0 and anchor_id < titles.size() else ""


static func case_hook(id: int) -> String:
	var cases: Array = _extra().cases
	return String(cases[posmod(id, cases.size())][1])


static func anchor_chapter(anchor_id: int, chapter: int, speaker: Villager = null) -> String:
	var chapters: Array = _extra().chapters
	if anchor_id < 0 or anchor_id >= chapters.size():
		return ""
	var lines: Array = chapters[anchor_id]
	return L.fill(String(lines[chapter]), {"me": speaker}) if chapter >= 0 and chapter < lines.size() else ""


static func door_sign(tell: StringName, salt: int = 0) -> String:
	var signs: Dictionary = _extra().door_signs
	if String(tell) == "ordinary" or not signs.has(String(tell)):
		var bank: Array = ORDINARY_SIGNS.get(L.code, StoryLoc.get_v("signs") if StoryLoc.has("signs") else [])
		if not bank.is_empty():
			return String(bank[posmod(salt, bank.size())])
	return String(signs.get(String(tell), signs.get("ordinary", "")))


## Обычный человек у двери: ничего странного, но каждый раз по-своему. Подсказок про упыря здесь нет.
const ORDINARY_SIGNS := {
	"ru": [
		"Пальцы дрожат, слова сбиваются. Страх или холод, отсюда не понять.",
		"Пар изо рта густой, на ресницах иней. Стоит, переминаясь с ноги на ногу.",
		"Стучит неровно, то тише, то громче. Всё время оглядывается на лес.",
		"Говорит шёпотом и часто сглатывает. Рукой держится за косяк.",
		"Плечи в снегу, шапка набок. Похоже, бежал{who:|а} от самого колодца.",
		"Дышит тяжело, голос срывается. На рукаве свежая грязь.",
		"Тень на двери качается вместе с фонарём в руке. Фонарь почти погас.",
		"Слышно, как стучат зубы. Пальцы спрятаны в рукава.",
	],
	"en": [
		"Their fingers shake and the words stumble. Fear or cold, you cannot tell from here.",
		"Thick breath fogs the air, frost on the lashes. They shift from foot to foot.",
		"The knocking is uneven, soft then loud. They keep glancing at the forest.",
		"They whisper and keep swallowing. One hand grips the doorframe.",
		"Snow on the shoulders, hat askew. Looks like they ran all the way from the well.",
		"Heavy breathing, a breaking voice. Fresh mud on one sleeve.",
		"The shadow on the door sways with the lantern in their hand. The flame is nearly out.",
		"You can hear their teeth chattering. Fingers tucked into sleeves.",
	],
}


static func door_ui(key: String) -> String:
	var ui: Dictionary = DOOR_UI.get(L.code, DOOR_UI["en"])
	return String(ui.get(key, ""))


static func door_mimic_title() -> String:
	var names := {"ru": "Подражатель", "en": "Mimic", "de": "Nachahmer", "fr": "Imitateur",
		"es": "Imitador", "pt": "Imitador", "tr": "Taklitçi", "hi": "नकलची", "vi": "Kẻ bắt chước", "zh": "模仿者"}
	return String(names.get(L.code, names["en"]))


static func question_tags() -> PackedStringArray:
	return PackedStringArray(_extra().question_tags)


static func door_record(day: int, tell: StringName) -> String:
	return L.fill(door_ui("record"), {"n": day, "text": door_sign(tell)})


static func case_recap(case_id: int, inspected: int) -> String:
	return L.fill(door_ui("case_recap"), {"case": case_title(case_id), "n": inspected})


static func player_name_label(value: String) -> String:
	var shown_name := value if not Save.player_name.is_empty() else String(_data().name_missing)
	return L.fill(String(_data().name_label), {"name": shown_name})


static func name_prompt() -> String:
	return String(_data().name_prompt)


static func question_title(who: String) -> String:
	return L.fill(String(_data().question_title), {"who": who})


static func question_answers() -> PackedStringArray:
	return PackedStringArray(_data().answers)


static func story(id: int, speaker: Villager = null) -> String:
	if speaker != null and not speaker.guest_id.is_empty():
		return Guests.story(speaker)
	var stories: Array = _data().stories
	if L.code == "ru":
		return L.fill(String(PEOPLE_RU[posmod(id, PEOPLE_RU.size())][1]), {"me": speaker})
	if posmod(id, stories.size()) == 8 and speaker != null and speaker.female:
		return String(HUSBAND_STORY.get(L.code, HUSBAND_STORY.en))
	return L.fill(String(stories[posmod(id, stories.size())]), {"me": speaker}) if not stories.is_empty() else ""


static func opening_question(story_id: int, player: String, speaker: Villager = null) -> String:
	var separator := "，" if L.code == "zh" else ", "
	var player_clause := separator + player if not Save.player_name.is_empty() else ""
	return L.fill(String(_data().opening), {"story": story(story_id, speaker), "player_clause": player_clause})


static func question(topic: String, player: String, rng: RandomNumberGenerator) -> String:
	var questions: Dictionary = _data().questions
	var lines := PackedStringArray(questions.get(topic, questions.get("trust", PackedStringArray())))
	if lines.is_empty():
		return ""
	var index := rng.randi_range(0, lines.size() - 1)
	var separator := "，" if L.code == "zh" else ", "
	var address := player + separator if not Save.player_name.is_empty() else ""
	var line := L.fill(lines[index], {"address": address})
	var tags: Array = _extra().question_tags
	if not tags.is_empty() and rng.randf() < 0.55:
		line += ("" if L.code == "zh" else " ") + String(tags[rng.randi_range(0, tags.size() - 1)])
	return line


static func question_reaction(answer_kind: int, story_id: int, rng: RandomNumberGenerator, speaker: Villager = null) -> String:
	var replies: Dictionary = _data().question_reply
	var key := "written"
	match answer_kind:
		0: key = "open"
		1: key = "guarded"
		2: key = "wry"
	var lines := PackedStringArray(replies.get(key, replies.get("written", PackedStringArray())))
	if lines.is_empty():
		return ""
	var index := rng.randi_range(0, lines.size() - 1)
	return L.fill(lines[index], {"story": story(story_id, speaker), "me": speaker})


## Возраст и прошлое принадлежат персонажу. Скрытая роль назначается отдельно.
const AGES := [34, 41, 61, 21, 47, 54, 23, 29, 45, 58, 26, 56]
const PEOPLE_RU := [
	["[Паромщик|Паромщица]", "Я [переправлял|переправляла] людей через реку. Моя дочь уплыла на том пароме. Лодка вернулась пустой. Я до сих пор ставлю на стол две тарелки.", "У дочери на рукаве была красная лента. Вчера такую нашли у чужой двери. Мне страшно спросить, у чьей.", "Я слышу её голос с реки. Если однажды побегу туда ночью, останови меня. Даже если буду просить пропустить."],
	["[Могильщик|Могильщица]", "Я [хоронил|хоронила] своего отца. Он боялся закрытых помещений, поэтому крышку я [прибил|прибила] только на два гвоздя. С тех пор жалею об этом.", "На его могиле земля тёплая. Я проверяю ладонью каждое утро. Остальным говорю, что это кроты.", "Здесь платят за могилу заранее. Я теперь беру только половину: у нас слишком много возвратов."],
	["[Учитель|Учительница]", "Сорок лет я [учил|учила] детей читать. Последней из класса ушла моя внучка, сестра Кости. Её тетрадь всё ещё лежит на первой парте.", "Внучка писала букву «я» задом наперёд. Новые имена на доске написаны так же. Я [скрыл|скрыла] это от соседей.", "Когда меня спрашивают, зачем я открываю школу, отвечаю: привычка. На самом деле боюсь, что она вернётся к запертой двери."],
	["[Подмастерье|Подмастерье]", "Сестра ушла в лес за дровами. Она научила меня свистеть, если заблужусь. Теперь ночью из леса отвечают на наш свист.", "Мы с сестрой прятали деньги под мостом, чтобы уехать. Я [достал|достала] их вчера. На двоих уже не хватит.", "Я всё-таки хочу выбраться. Если останусь ждать всех, кого люблю, здесь состарюсь раньше времени."],
	["[Фельдшер|Фельдшер]", "Я [лечил|лечила] семью мельника. Его жена попросила спасти только ребёнка. Я [пообещал|пообещала], хотя уже [знал|знала], что не смогу.", "Иногда мне кажется, что у стучащих под кожей нет пульса. Потом проверяю свой: от страха тоже едва бьётся.", "Сохрани мне место у двери. Я не обещаю чудес, но руки у меня ещё помнят, как вытаскивать живых."],
	["[Сторож|Сторожиха]", "В ту ночь я [охранял|охраняла] мост. Услышав знакомый голос, [ушёл|ушла] с поста. Пока меня не было, пропали трое.", "Это был голос матери. Она умерла за год до той ночи. Я всё равно [пошёл|пошла]. Вот что труднее всего объяснить.", "Если услышишь своё имя из темноты, не отвечай сразу. Пусть сначала назовут то, чего чужой знать не может."],
	["[Работник трактира|Работница трактира]", "В трактире я [откладывал|откладывала] деньги на свадьбу. Вечером пропали трое гостей. Утром на столе стояли шесть оплаченных кружек.", "Обручальное кольцо ношу на шнурке. Надеть его пока некому. Но сдать за муку рука тоже не поднимается.", "Когда всё кончится, открою трактир. С большими окнами. И такую вывеску, чтобы её было видно за рекой."],
	["[Часовщик|Часовщица]", "Башенные часы остановились в ночь моего венчания. Мы решили, что это к счастью: время будто подождало нас. Сейчас так уже не шутим.", "Я храню записку с обещанием встретиться у моста. Дата размыта дождём. Всё остальное помню наизусть.", "На башне сломан один зубец. Починить можно. Только тогда снова придётся считать, сколько времени мы здесь потеряли."],
	["[Следопыт|Следопыт]", "[Моя жена умела|Мой муж умел] читать следы. [Она ушла|Он ушёл] в лес [одна|один], оставив обувь у порога. Я [нашёл|нашла] только отпечатки босых ног.", "На снегу были две дорожки. Я [рассказал|рассказала] всем только об одной: вторая возвращалась к нашему дому.", "Я не открою на один голос. Сначала спрошу, где мы встретились. Ответа никто в деревне не знает."],
	["[Охотник|Охотница]", "Я [охотился|охотилась] с сыном. Теперь хожу в лес [один|одна]. Его ружьё держу заряженным: он всегда забывал это сделать.", "На его прикладе три зарубки. Я [нашёл|нашла] такую же отметину на дереве у тропы. Свежую.", "Раньше я [боялся|боялась], что сын будет похож на меня. Теперь [отдал|отдала] бы что угодно, чтобы снова услышать, как он со мной спорит."],
	["[Садовник|Садовница]", "Я [посадил|посадила] яблоню в день рождения сестры. Она исчезла осенью. Весной дерево зацвело только с той стороны, где её окно.", "Под яблоней я [закопал|закопала] её любимую чашку. Вчера чашка стояла на пороге. Я [убрал|убрала] её раньше, чем проснулись соседи.", "Обещай, что если выживем, поможешь собрать яблоки. Хочется попросить о чём-нибудь, что будет после этой ночи."],
	["[Кузнец|Кузнечиха]", "Последний нож я [сделал|сделала] для человека, который собирался защищать семью. Дом у него теперь пустой. Нож лежит у меня на верстаке.", "На рукояти осталась детская царапина. Он просил её не зашлифовывать. Я [узнал|узнала] нож по ней, когда нашёл у реки.", "Соседи заказывают новые засовы. Хорошо бы знать, кого мы ими удерживаем снаружи, а кого запираем внутри."]
]
const JOBS_EN := ["Ferry keeper", "Gravedigger", "Teacher", "Apprentice", "Medic", "Bridge keeper", "Inn worker", "Clockmaker", "Tracker", "Hunter", "Gardener", "Smith"]
const HUSBAND_STORY := {
	"ru": "Мой муж умел читать следы. Он ушёл в лес один, оставив обувь у порога.",
	"en": "My husband could read tracks. He went into the woods alone and left his shoes at the door.",
	"de": "Mein Mann konnte Spuren lesen. Er ging allein in den Wald und ließ seine Schuhe vor der Tür.",
	"fr": "Mon mari savait lire les traces. Il est parti seul dans les bois, laissant ses chaussures au seuil.",
	"es": "Mi marido sabía leer huellas. Entró solo al bosque y dejó sus zapatos en la puerta.",
	"pt": "Meu marido sabia ler rastros. Entrou sozinho na floresta e deixou os sapatos à porta.",
	"tr": "Kocam iz okuyabilirdi. Ayakkabılarını kapıda bırakıp tek başına ormana gitti.",
	"hi": "मेरे पति पदचिह्न पहचानते थे। वे जूते दरवाज़े पर छोड़कर अकेले जंगल चले गए।",
	"vi": "Chồng tôi biết đọc dấu chân. Anh ấy vào rừng một mình, để giày trước cửa.",
	"zh": "我丈夫会辨认足迹。他把鞋留在门口，独自走进了森林。"
}

static func story_age(id: int) -> int:
	return AGES[posmod(id, AGES.size())]


static func person_title(v: Villager) -> String:
	if not v.guest_id.is_empty():
		return Guests.title(v)
	var young := v.age < 28
	if L.code == "ru":
		var gender := ("Девушка" if v.female else "Юноша") if young else ("Женщина" if v.female else "Мужчина")
		return "%s, %s. %s" % [gender, L.fill("{n} {n#год|года|лет}", {"n": v.age}), L.fill(String(PEOPLE_RU[posmod(v.story_id, 12)][0]), {"me": v})]
	if StoryLoc.has("fmt"):
		var g: Array = StoryLoc.get_v("g")
		var jobs: Array = StoryLoc.get_v("jobs")
		var gw: String = g[(0 if v.female else 1) if young else (2 if v.female else 3)]
		return L.fill(String(StoryLoc.get_v("fmt")), {"g": gw, "n": str(v.age), "job": L.fill(String(jobs[posmod(v.story_id, 12)]), {"me": v})})
	var gender := ("Young woman" if v.female else "Young man") if young else ("Woman" if v.female else "Man")
	return "%s, %d. %s" % [gender, v.age, JOBS_EN[posmod(v.story_id, 12)]]


static func personal_chapter(v: Villager, step: int) -> String:
	if not v.guest_id.is_empty():
		return Guests.clue(v, clampi(step, 1, Guests.REVEAL_DAY - 1))   # разговор наедине — улика раньше, чем узнают все
	if L.code == "ru":
		return L.fill(String(PEOPLE_RU[posmod(v.story_id, 12)][clampi(step + 1, 1, 3)]), {"me": v})
	return story(v.story_id, v) if step == 0 else anchor_chapter(posmod(v.story_id, 3), mini(step - 1, 1), v)


static func bond_text(v: Villager, m: Match) -> String:
	var base := _bond_text(v, m)
	var tie := m.get_villager(v.tie_id)
	if tie != null:
		var side := "a" if Match.TIES.any(func(t: Array) -> bool: return t[0] == v.story_id) else "b"
		var t := L.t("tie.%s_%s" % [v.tie_kind, side], {"me": v, "who": tie})
		base = t if base.is_empty() else base + " " + t
	return base


## Семья и пара. Лида — бабушка Кости (TASK-007): у пары внук и бабушка свои строки на всех языках.
static func _bond_text(v: Villager, m: Match) -> String:
	var family := m.get_villager(v.family_id)
	if family != null and v.family_kind in ["grandchild", "grandparent"]:
		if not family.alive:
			return grief_text(v, family)
		return L.t("bond.grand_parent" if v.family_kind == "grandchild" else "bond.grand_child", {"me": v, "name": family.name})
	if family != null:
		var parent := v.age > family.age
		if L.code == "ru":
			return ("Мой сын %s оставил дома письмо. Я обещала прочитать его только после нашего отъезда." % family.name if parent else
				"Моя мать %s хранит моё письмо. Я надеюсь забрать его, когда мы выберемся." % family.name) if family.alive else grief_text(v, family)
		if StoryLoc.has("bond_parent"):
			return L.fill(String(StoryLoc.get_v("bond_parent" if parent else "bond_child")), {"name": family.name, "me": v}) if family.alive else grief_text(v, family)
		return ("My son %s left a letter at home. I promised to read it after we leave." % family.name if parent else
			"My mother %s keeps my letter. I hope to take it when we leave.") if family.alive else grief_text(v, family)
	var partner := m.get_villager(v.partner_id)
	if partner == null:
		return ""
	if L.code == "ru":
		var relation := "Любит %s. Они собирались уехать вместе." % L.gram().name_case(partner.name, "acc", partner.female)
		if not partner.alive:
			relation += " Теперь ждёт у пустого дома."
		return relation
	if StoryLoc.has("bond_love"):
		var t := L.fill(String(StoryLoc.get_v("bond_love")), {"name": partner.name, "me": v})
		return t + (L.fill(String(StoryLoc.get_v("bond_lost")), {"me": v}) if not partner.alive else "")
	return "Loves %s. They planned to leave together." % partner.name


static func grief_text(survivor: Villager, lost: Villager) -> String:
	if StoryLoc.has("grief"):
		return L.fill(String(StoryLoc.get_v("grief")), {"lost": lost, "who": survivor.name, "me": survivor})
	if L.code != "ru":
		return "%s is gone. %s still keeps a place for them at the table." % [lost.name, survivor.name]
	var fate := "выгнали" if lost.exiled else ("погибла" if lost.female else "погиб")
	if survivor.family_id == lost.id:
		if survivor.age > lost.age:
			return "%s %s. Мать всё ещё держит его письмо запечатанным." % [lost.name, fate]
		return "%s %s. Сын ставит для неё миску за общим столом." % [lost.name, fate]
	if survivor.partner_id == lost.id:
		return "%s больше не вернётся. %s держит их дорожную сумку у двери." % [lost.name, survivor.name]
	return ""


static func epilogue(v: Villager) -> String:
	if not v.guest_id.is_empty():
		return ""
	if v.story_step == 0:
		return ""
	if v.alive and StoryLoc.has("epi"):
		var endings_l: Array = StoryLoc.get_v("epi")
		return L.fill(String(endings_l[posmod(v.story_id, endings_l.size())]), {"who": v.name, "me": v})
	if StoryLoc.has("epi_alive"):
		return L.fill(String(StoryLoc.get_v("epi_alive" if v.alive else "epi_dead")), {"who": v.name})
	if L.code != "ru":
		return "%s kept the story you heard alive." % v.name if v.alive else "The story %s told you ended here." % v.name
	if not v.alive:
		return "%s так и не [успел|успела] рассказать тебе конец своей истории.".replace("[успел|успела]", "успела" if v.female else "успел") % v.name
	var endings := [
		"На причале {who} находит красную ленту и впервые оставляет её там, где её нашли.",
		"{who} снимает с могилы отца один гвоздь: теперь он может закрыть её по своей воле.",
		"{who} открывает школу. На первой парте лежит новая тетрадь, старая убрана в ящик.",
		"{who} забирает деньги из-под моста и оставляет сестре записку на случай возвращения.",
		"{who} снова перевязывает раны. Обещаний спасти всех больше не даёт.",
		"{who} возвращается на мост. Там снова слышен голос матери, но пост остаётся занятым.",
		"{who} вешает над трактиром вывеску. С реки её видно ещё до сумерек.",
		"{who} чинит башенные часы. Первый удар колокола слушает рядом с тем, кого ждал.",
		"{who} показывает соседям вторую дорожку следов. Искать теперь будут вместе.",
		"{who} разряжает ружьё сына. Впервые за много дней руки не дрожат.",
		"{who} собирает яблоки. Одну корзину оставляет у окна сестры.",
		"{who} переплавляет последний нож в новые засовы для общего дома.",
	]
	return String(endings[posmod(v.story_id, endings.size())]).replace("{who}", v.name)


static func village_intro(m: Match) -> String:
	if L.code == "ru":
		return "Перед сумерками дорога вывела тебя к реке. На другом берегу кто-то звал по имени. У причала тебя остановили: «На голос с того берега не отвечай».\n\nЗдесь живут люди, которым есть кого ждать. Ночью к их дверям приходят знакомые лица. Иногда под ними уже кто-то другой.\n\nСегодня обереги сохранились в %d домах. Остальные дома заперты: ночевать там опасно. До колокола нужно познакомиться с соседями и решить, чьему голосу поверить." % m.houses.size()
	if StoryLoc.has("intro"):
		return L.fill(String(StoryLoc.get_v("intro")), {"n": str(m.houses.size())})
	return "The road ends at a river. A familiar voice calls from the far bank. The ferry keeper asks you not to answer.\n\nThese people have someone to wait for. At night familiar faces knock on their doors. Some have changed.\n\nOnly %d houses still have protective charms. Meet your neighbours before the bell and decide whose voice to trust." % m.houses.size()


static func opening_beats(m: Match) -> Array:
	if StoryLoc.has("beats"):
		var couple := String(StoryLoc.get_v("couple_anon"))
		for resident: Villager in m.villagers:
			if resident.partner_id >= 0:
				couple = L.fill(String(StoryLoc.get_v("couple_named")), {"a": resident.name, "b": m.get_villager(resident.partner_id).name})
				break
		var b: Array = StoryLoc.get_v("beats")
		return [[b[0], b[1]], [b[2], L.fill(String(b[3]), {"couple": couple})]]
	var couple_ru := "У двоих жителей одна дорожная сумка на двоих. Они собирались уехать вместе."
	var couple_en := "Two residents have one travel bag between them. They planned to leave together."
	for resident: Villager in m.villagers:
		if resident.partner_id >= 0:
			var other := m.get_villager(resident.partner_id)
			couple_ru = "%s и %s собирались уехать вместе. У них одна дорожная сумка на двоих." % [resident.name, other.name]
			couple_en = "%s and %s planned to leave together. They have one travel bag between them." % [resident.name, other.name]
			break
	if L.code == "ru":
		return [
			["На другом берегу", "Ты слышишь своё имя из темноты. Голос знакомый, хотя здесь тебя никто не знает. Перевозчик гасит фонарь и шепчет: «Не отвечай. Оно запоминает голоса»."],
			["До первого колокола", couple_ru + " В посёлке есть и другие обещания, которые ночь может оборвать. Поговори с людьми, пока они рядом."],
		]
	return [
		["Across the river", "A familiar voice calls your name from the dark. Nobody here should know it. The ferryman puts out his lantern: 'Do not answer. It remembers voices.'"],
		["Before the first bell", couple_en + " Others here made promises too. Talk to them while you can."],
	]


static func narrative_ui(key: String) -> String:
	var ru := {"cast": "Те, с кем встретишь ночь", "personal": "Поговорить о прошлом", "listen": "Я рядом. Расскажи ещё.", "doubt": "Что ты скрываешь от остальных?", "later": "Давай продолжим завтра.", "thanks": "Спасибо. Обычно меня прерывают раньше.", "hurt": "Я [рассказал|рассказала] то, о чём молчу годами. Теперь ты мне не веришь?", "prompt": "{who}, расскажи, что с тобой случилось.", "first_goal": "До колокола узнай историю хотя бы одного жителя. Первый разговор даст дополнительный осмотр у двери.", "bonus_earned": "Житель доверился тебе. Сегодня у двери доступен третий осмотр."}
	var en := {"cast": "The people you will face the night with", "personal": "Ask about their past", "listen": "I'm here. Tell me more.", "doubt": "What are you hiding from the others?", "later": "Let's continue tomorrow.", "thanks": "Thank you for listening. People usually interrupt me.", "hurt": "I told you something I have kept to myself for years. Does that make me suspicious?", "prompt": "{who}, tell me what happened to you.", "first_goal": "Hear one resident's story before the bell. Your first talk grants an extra door inspection.", "bonus_earned": "A resident trusted you. You have a third inspection at the door tonight."}
	if StoryLoc.has("ui") and (StoryLoc.get_v("ui") as Dictionary).has(key):
		return String((StoryLoc.get_v("ui") as Dictionary)[key])
	return String((ru if L.code == "ru" else en).get(key, key))


const MOURNING_UI := {
	"ru": {"action": "Поддержать в трауре", "title": "{who} переживает утрату. Как ответить?",
		"options": ["Выслушать", "Помочь с вещами", "Побыть рядом молча"],
		"player": ["Я тебя выслушаю.", "Могу помочь разобрать оставшиеся вещи.", "Я побуду рядом молча."],
		"reply": ["Спасибо. Мне трудно говорить об этом вслух.", "Я пока не могу разбирать вещи. Останься со мной.", "Посиди ещё немного. Сейчас тишина легче слов."]},
	"en": {"action": "Offer support", "title": "{who} is grieving. What will you say?",
		"options": ["Listen", "Help with their belongings", "Stay quietly"],
		"player": ["I'm here. I'll listen.", "I can help sort through what they left behind.", "I'll stay with you in silence."],
		"reply": ["Thank you. I haven't been able to say this aloud.", "I'm not ready to sort through their things. Stay with me.", "Sit with me a little longer. Silence is easier than words."]},
	"de": {"action": "Trost anbieten", "title": "{who} trauert. Was sagst du?",
		"options": ["Zuhören", "Bei den Sachen helfen", "Still dableiben"],
		"player": ["Ich höre dir zu.", "Ich kann dir helfen, die Sachen zu ordnen.", "Ich bleibe still bei dir."],
		"reply": ["Danke. Ich konnte bisher nicht darüber sprechen.", "Ich bin noch nicht bereit, die Sachen durchzusehen. Bleib bei mir.", "Bleib noch etwas. Schweigen ist heute leichter als Worte."]},
	"fr": {"action": "Réconforter", "title": "{who} est en deuil. Que répondre ?",
		"options": ["Écouter", "Aider avec ses affaires", "Rester en silence"],
		"player": ["Je t'écoute.", "Je peux t'aider à trier ses affaires.", "Je reste avec toi en silence."],
		"reply": ["Merci. Je n'arrivais pas à en parler à voix haute.", "Je ne suis pas prêt{me:|e} à ranger ses affaires. Reste avec moi.", "Reste encore un peu. Aujourd'hui, le silence est plus doux que les mots."]},
	"es": {"action": "Ofrecer apoyo", "title": "{who} está de duelo. ¿Qué respondes?",
		"options": ["Escuchar", "Ayudar con sus cosas", "Acompañar en silencio"],
		"player": ["Estoy aquí. Te escucho.", "Puedo ayudarte a ordenar sus cosas.", "Me quedaré contigo en silencio."],
		"reply": ["Gracias. No había podido decirlo en voz alta.", "Aún no estoy list{me:o|a} para ordenar sus cosas. Quédate conmigo.", "Quédate un poco más. Hoy el silencio es más fácil que hablar."]},
	"pt": {"action": "Oferecer apoio", "title": "{who} está de luto. O que você responde?",
		"options": ["Escutar", "Ajudar com os pertences", "Ficar em silêncio"],
		"player": ["Estou aqui. Vou escutar.", "Posso ajudar a separar as coisas que ficaram.", "Vou ficar aqui com você, em silêncio."],
		"reply": ["Agradeço. Eu ainda não conseguia falar disso em voz alta.", "Ainda não estou pront{me:o|a} para mexer nas coisas. Fica comigo.", "Fica mais um pouco. Hoje o silêncio é mais fácil que as palavras."]},
	"tr": {"action": "Yanında ol", "title": "{who} yas tutuyor. Ne söyleyeceksin?",
		"options": ["Dinle", "Eşyalarına yardım et", "Sessizce yanında kal"],
		"player": ["Buradayım, seni dinliyorum.", "Kalan eşyaları toplamana yardım edebilirim.", "Sessizce yanında kalacağım."],
		"reply": ["Sağ ol. Bunu sesli söyleyemiyordum.", "Eşyaları toplamaya hazır değilim. Yanımda kal.", "Biraz daha otur. Bugün sessizlik sözlerden kolay."]},
	"hi": {"action": "साथ दें", "title": "{who} शोक में है। तुम क्या कहोगे?",
		"options": ["बात सुनें", "सामान में मदद करें", "चुपचाप साथ रहें"],
		"player": ["मैं यहाँ हूँ।", "बची हुई चीज़ें समेटने में मदद कर सकता हूँ।", "मैं चुपचाप साथ रहूँगा।"],
		"reply": ["धन्यवाद। इस बारे में बोलना मेरे लिए मुश्किल था।", "मैं अभी सामान समेटने के लिए तैयार नहीं हूँ। मेरे साथ रहो।", "थोड़ी देर और बैठो। आज चुप्पी शब्दों से आसान है।"]},
	"vi": {"action": "Ở bên an ủi", "title": "{who} đang chịu tang. Bạn sẽ nói gì?",
		"options": ["Lắng nghe", "Giúp thu dọn đồ", "Ở lại trong im lặng"],
		"player": ["Mình ở đây, cứ nói đi.", "Mình có thể giúp dọn những món đồ còn lại.", "Mình sẽ ngồi đây cùng bạn, không nói gì."],
		"reply": ["Cảm ơn. Mình vẫn chưa thể nói chuyện này thành lời.", "Mình chưa sẵn sàng dọn đồ. Ở lại với mình nhé.", "Ngồi thêm một chút. Hôm nay im lặng dễ chịu hơn lời nói."]},
	"zh": {"action": "安慰", "title": "{who}正在哀悼。你会怎么回应？",
		"options": ["听他说", "帮忙整理遗物", "安静地陪着"],
		"player": ["我在听。", "我可以帮你整理留下的东西。", "我会安静地陪着你。"],
		"reply": ["谢谢。我一直没能把这些话说出口。", "我还没准备好整理遗物。陪陪我。", "再坐一会儿吧。今天沉默比说话容易。"]}
}


static func mourning_action() -> String:
	return String(MOURNING_UI.get(L.code, MOURNING_UI.en).action)


static func mourning_title(mourner: Villager) -> String:
	return L.fill(String(MOURNING_UI.get(L.code, MOURNING_UI.en).title), {"who": mourner, "me": mourner})


static func mourning_options(mourner: Villager, lost: Villager) -> PackedStringArray:
	var out := PackedStringArray()
	for text: String in MOURNING_UI.get(L.code, MOURNING_UI.en).options:
		out.append(L.fill(text, {"me": mourner, "lost": lost}))
	return out


static func mourning_line(kind: String, choice: int, mourner: Villager, lost: Villager) -> String:
	var lines: Array = MOURNING_UI.get(L.code, MOURNING_UI.en).get(kind, [])
	if choice < 0 or choice >= lines.size():
		return ""
	return L.fill(String(lines[choice]), {"me": mourner, "who": mourner, "lost": lost})


static func has_bank(bank_id: String) -> bool:
	var accusations: Dictionary = _data().accusations
	return accusations.has(bank_id)


static func bank(bank_id: String) -> PackedStringArray:
	var accusations: Dictionary = _data().accusations
	return PackedStringArray(accusations.get(bank_id, PackedStringArray()))
