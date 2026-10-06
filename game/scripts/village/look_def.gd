class_name LookDef
extends Resource
## Внешность жителя. Всё рисуется кодом из этих цветов и формы головы.

enum Head { BARE, CAP, SCARF, HAT, HOOD }

@export var who: String = ""
@export var coat: Color = Color("3a4650")
@export var accent: Color = Color("8a6c39")
@export var skin: Color = Color("c9a58a")
@export var hair: Color = Color("3a2a22")
@export var head: Head = Head.BARE
@export_range(0.85, 1.15) var height: float = 1.0
