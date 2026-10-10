class_name LookDef
extends Resource
## Внешность жителя. Всё рисуется кодом из этих цветов и формы головы.

enum Head { BARE, CAP, SCARF, HAT, HOOD,
	USHANKA, DEERSTALKER, BERET, PHRYGIAN, MUSKETEER, SOMBRERO, FEZ, TURBAN, CONICAL,
	GOLD_BAND, JESTER, CANGACEIRO, LUCHADOR, CATRINA, FLOWER_CROWN, TOP_HAT, STRAW, KOKOSHNIK }
enum Hair { SHORT, BANGS, PONYTAIL, CURLY, BALD, BOB, BUN, SPIKY, LONG, BRAIDS, PIGTAILS }
enum Beard { NONE, STUBBLE, MUSTACHE, FULL }
enum Brows { THIN, THICK, STERN }
enum Nose { BUTTON, LONG, ROUND }
enum Outfit { COAT, DRESS, SWEATER, JACKET, ROBE, SAREE, QIPAO }
enum Bow { NONE, BOW, CLIP, FLOWER }
## Звериная голова вместо человеческой: персонажи-символы стран (медведь, панда, слон…).
## Тело и одежда остаются человеческими, лицо так же показывает эмоции.
enum Animal { NONE, BEAR, PANDA, MONKEY, PIG, CAT, TIGER, JAGUAR, WOLF, FOX, BULLDOG, RABBIT,
	ELEPHANT, BUFFALO, ROOSTER, MACAW, PEACOCK }

@export var who: String = ""
@export var coat: Color = Color("3a4650")
@export var accent: Color = Color("8a6c39")
@export var skin: Color = Color("c9a58a")
@export var hair: Color = Color("3a2a22")
@export var head: Head = Head.BARE
@export_range(0.85, 1.15) var height: float = 1.0
## Приметы лица: по ним жителя узнают без подписи.
@export var hair_style: Hair = Hair.SHORT
@export var beard: Beard = Beard.NONE
@export var brows: Brows = Brows.THIN
@export var nose: Nose = Nose.BUTTON
@export var eye: Color = Color("5a4030")
@export var glasses: bool = false
@export var freckles: bool = false
@export var scar: bool = false
@export_range(0, 2) var age: int = 1           ## 0 — молодой, 1 — взрослый, 2 — старый (седина, морщины)
## Пол и одежда: девушку видно по силуэту — платье, косы, ресницы.
@export var female: bool = false
@export var outfit: Outfit = Outfit.COAT
@export var bow: Bow = Bow.NONE
@export var earrings: bool = false
@export var animal: Animal = Animal.NONE
