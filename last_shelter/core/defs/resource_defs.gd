class_name ResourceDefs
extends RefCounted
## Описание ресурсов убежища.

const IDS: Array[String] = ["food", "water", "power", "medicine", "metal", "wood", "concrete"]
## Ресурсы, у которых на верхней панели показан прогноз на завтра.
const DAILY: Array[String] = ["food", "water", "power", "medicine"]
## Стройматериалы: тратятся на постройку, улучшения и ремонт.
const MATERIALS: Array[String] = ["metal", "wood", "concrete"]

const INFO := {
	"food": {"name": "Еда", "icon": "food", "color": Color("d9634a")},
	"water": {"name": "Вода", "icon": "water", "color": Color("4fa3d8")},
	"power": {"name": "Энергия", "icon": "power", "color": Color("e8b04a")},
	"medicine": {"name": "Медикаменты", "icon": "medicine", "color": Color("6fd0a0")},
	"metal": {"name": "Металл", "icon": "metal", "color": Color("a8a59c")},
	"wood": {"name": "Дерево", "icon": "wood", "color": Color("b07a48")},
	"concrete": {"name": "Бетон", "icon": "concrete", "color": Color("8f8c86")},
}

## Вместимость склада без складских комнат (каждая комната добавляет свой "cap" из RoomDefs).
const BASE_CAP := 100

const START := {"food": 40, "water": 40, "power": 30, "medicine": 6, "metal": 90, "wood": 40, "concrete": 20}
## Ресурсы, появившиеся в версии 3: старые сохранения получают стартовый запас.
const ADDED_V3: Array[String] = ["medicine", "wood", "concrete"]


static func name_of(id: String) -> String:
	return INFO[id]["name"]


static func get_color(id: String) -> Color:
	return INFO[id]["color"]


## «металл 40, дерево 10»
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for res in IDS:
		if int(cost.get(res, 0)) > 0:
			parts.append("%s %d" % [name_of(res).to_lower(), int(cost[res])])
	return ", ".join(parts)
