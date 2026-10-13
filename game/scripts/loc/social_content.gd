class_name SocialContent
extends RefCounted
## Short personal histories and NPC-initiated questions, localized with the rest of the game.

const DATA := {
	"ru": {
		"name_label": "Имя игрока: {name}", "name_missing": "не задано", "name_prompt": "Как тебя зовут?", "question_title": "{who} спрашивает тебя",
		"answers": ["Я расскажу, что знаю. Спрашивай конкретно.", "Сначала расскажи ты. Потом решу, чем делиться.", "Я надеялся пережить только ночь. У вас тут планы шире."],
		"opening": "{story} А что привело тебя сюда{player_clause}?",
		"stories": [
			"Я переправлял людей через реку. Однажды лодка вернулась без пассажиров.",
			"Я копал могилы после первой зимы. Земля у нас оттаивает быстрее, чем память.",
			"Я держал деревенскую школу. Теперь записываю имена тех, кто перестал приходить.",
			"Мой брат ушёл в лес за дровами. С тех пор я каждый вечер оставляю ему место у печи.",
			"Я лечил семью мельника. Дом заперт, а счёт за лечение так и висит.",
			"Я дежурил у моста в ту ночь, когда исчез человек. Объяснение репетирую до сих пор.",
			"Я подметал трактир. В ночь исчезновения троих в книге осталось шесть кружек.",
			"Я чинил часы на башне. Однажды они остановились раньше полуночи.",
			"Моя жена умела читать следы. Она ушла в лес одна, оставив обувь у порога.",
			"Я охотился на волков. Теперь соседи платят, чтобы я не называл их волками.",
			"Я выращивал яблоки за часовней. Каждую осень кто-то стучит в запертую кладовую.",
			"Меня считали лучшим кузнецом. Заказчик забрал нож и больше за ним не пришёл."
		],
		"questions": {
			"arrival": ["{address}что привело тебя в нашу деревню? Сюда редко приходят случайно."],
			"night": ["{address}как ты пережил прошлую ночь? Утром тебя видели совсем не там, где ждали."],
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
			"wry": ["Шутка мрачная. Значит, ты уже понял, где оказался.", "Вот и я думал, что пережить ночь будет главным делом."],
			"written": ["Спасибо, что рассказал. Постараюсь запомнить именно это.", "Я тебя услышал. Потом сравню с тем, что скажут другие."]
		},
		"accusations": {
			"ACCUSE_DEATH": ["{who}, ты был рядом с домом, откуда утром не вышел жилец.", "Слишком часто беда случается рядом с {who}."],
			"ACCUSE_FAKE": ["{who}, ты был у припасов, а их больше не стало.", "После твоей работы вёдра остались пустыми. Объяснишь, {who}?"],
			"ACCUSE_SABOTAGE": ["{who}, кто-то испортил припасы. Последним там видели тебя.", "Запасы испорчены, а {who} опять рядом. Совпадение?"],
			"ACCUSE_TUNNEL": ["{who}, ты пролез в другой дом по туннелю. Почему промолчал?", "Откуда ты взялся в том убежище, {who}? Дорога туда не короткая."]
		}
	},
	"en": {
		"name_label": "Player name: {name}", "name_missing": "not set", "name_prompt": "What should we call you?", "question_title": "{who} asks you",
		"answers": ["I'll tell you what I know. Ask me something specific.", "Tell me your story first. Then I'll decide what to share.", "I came hoping to survive one night. You have bigger plans here."],
		"opening": "{story} What brought you here{player_clause}?",
		"stories": [
			"I ferried people across the river. One night, my boat came back empty.",
			"I dug graves after the first winter. The ground thaws faster than people's memories.",
			"I kept the village school. Now I write down the names of those who stopped coming.",
			"My brother went into the woods for firewood. I still leave him a place by the stove each night.",
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


static func _data() -> Dictionary:
	return DATA.get(L.code, DATA["ru"])


static func player_name_label(value: String) -> String:
	var shown_name := value if not Save.player_name.is_empty() else String(_data().name_missing)
	return L.fill(String(_data().name_label), {"name": shown_name})


static func name_prompt() -> String:
	return String(_data().name_prompt)


static func question_title(who: String) -> String:
	return L.fill(String(_data().question_title), {"who": who})


static func question_answers() -> PackedStringArray:
	return PackedStringArray(_data().answers)


static func story(id: int) -> String:
	var stories: Array = _data().stories
	return String(stories[posmod(id, stories.size())]) if not stories.is_empty() else ""


static func opening_question(story_id: int, player: String) -> String:
	var separator := "，" if L.code == "zh" else ", "
	var player_clause := separator + player if not Save.player_name.is_empty() else ""
	return L.fill(String(_data().opening), {"story": story(story_id), "player_clause": player_clause})


static func question(topic: String, player: String, rng: RandomNumberGenerator) -> String:
	var questions: Dictionary = _data().questions
	var lines := PackedStringArray(questions.get(topic, questions.get("trust", PackedStringArray())))
	if lines.is_empty():
		return ""
	var index := rng.randi_range(0, lines.size() - 1)
	var separator := "，" if L.code == "zh" else ", "
	var address := player + separator if not Save.player_name.is_empty() else ""
	return L.fill(lines[index], {"address": address})


static func question_reaction(answer_kind: int, story_id: int, rng: RandomNumberGenerator) -> String:
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
	return L.fill(lines[index], {"story": story(story_id)})


static func has_bank(bank_id: String) -> bool:
	var accusations: Dictionary = _data().accusations
	return accusations.has(bank_id)


static func bank(bank_id: String) -> PackedStringArray:
	var accusations: Dictionary = _data().accusations
	return PackedStringArray(accusations.get(bank_id, PackedStringArray()))
