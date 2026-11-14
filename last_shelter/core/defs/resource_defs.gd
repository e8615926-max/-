class_name ResourceDefs
extends RefCounted
## Описание ресурсов убежища.

const IDS: Array[String] = ["food", "water", "metal", "power"]

const INFO := {
	"food": {"name": "Еда", "icon": "food", "color": Color("d9634a")},
	"water": {"name": "Вода", "icon": "water", "color": Color("4fa3d8")},
	"metal": {"name": "Металл", "icon": "metal", "color": Color("a8a59c")},
	"power": {"name": "Энергия", "icon": "power", "color": Color("e8b04a")},
}

## Вместимость склада без складских комнат (каждая комната добавляет свой "cap" из RoomDefs).
const BASE_CAP := 100

const START := {"food": 40, "water": 40, "metal": 90, "power": 30}


static func name_of(id: String) -> String:
	return INFO[id]["name"]


static func get_color(id: String) -> Color:
	return INFO[id]["color"]
