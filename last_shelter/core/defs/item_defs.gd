class_name ItemDefs
extends RefCounted
## Предметы: экипировка (даёт бонус к навыкам) и расходники (используются один раз).

const SLOTS: Array[String] = ["weapon", "outfit", "tool"]
const SLOT_NAMES := {"weapon": "Оружие", "outfit": "Одежда", "tool": "Инструмент"}

const INFO := {
	"knife": {"name": "Нож", "slot": "weapon", "bonus": {"combat": 1},
		"desc": "Простой, но надёжный клинок."},
	"pistol": {"name": "Пистолет", "slot": "weapon", "bonus": {"combat": 3},
		"desc": "Старый, но исправный. Патронов мало."},
	"wrench": {"name": "Разводной ключ", "slot": "tool", "bonus": {"engineering": 2},
		"desc": "Главный аргумент любого механика."},
	"trowel": {"name": "Садовый совок", "slot": "tool", "bonus": {"farming": 2},
		"desc": "Помогает ухаживать за рассадой."},
	"gasmask": {"name": "Противогаз", "slot": "tool", "bonus": {"scavenging": 2},
		"desc": "Позволяет заходить туда, куда другие не рискнут."},
	"overalls": {"name": "Рабочий комбинезон", "slot": "outfit", "bonus": {"engineering": 1, "farming": 1},
		"desc": "Не жалко испачкать."},
	"labcoat": {"name": "Лабораторный халат", "slot": "outfit", "bonus": {"science": 2, "medicine": 1},
		"desc": "Почти белый."},
	"jacket": {"name": "Кожаная куртка", "slot": "outfit", "bonus": {"combat": 1, "scavenging": 1},
		"desc": "Защищает от ветра и не только."},
	"medkit": {"name": "Аптечка", "slot": "", "use": {"health": 40},
		"desc": "Бинты, антисептик, обезболивающее."},
	"chocolate": {"name": "Шоколад", "slot": "", "use": {"mood": 25},
		"desc": "Довоенная плитка. На вес золота."},
}

## Что можно найти в экспедиции.
const LOOT_TABLE: Array[String] = [
	"knife", "pistol", "wrench", "trowel", "gasmask", "overalls",
	"labcoat", "jacket", "medkit", "medkit", "chocolate", "chocolate",
]


static func exists(id: String) -> bool:
	return INFO.has(id)


static func get_def(id: String) -> Dictionary:
	return INFO[id]


static func name_of(id: String) -> String:
	return INFO[id]["name"]


static func get_slot(id: String) -> String:
	return INFO[id]["slot"]


static func is_usable(id: String) -> bool:
	return INFO[id].has("use")


static func get_bonus(id: String, skill: String) -> int:
	var def: Dictionary = INFO[id]
	if not def.has("bonus"):
		return 0
	return int((def["bonus"] as Dictionary).get(skill, 0))


## Короткое описание эффекта: «Инженерия +2» или «Здоровье +40».
static func effect_text(id: String) -> String:
	var def: Dictionary = INFO[id]
	var parts: PackedStringArray = []
	if def.has("bonus"):
		var bonus: Dictionary = def["bonus"]
		for skill: String in bonus:
			parts.append("%s +%d" % [SkillDefs.name_of(skill), int(bonus[skill])])
	if def.has("use"):
		var use: Dictionary = def["use"]
		if use.has("health"):
			parts.append("Здоровье +%d" % int(use["health"]))
		if use.has("mood"):
			parts.append("Настроение +%d" % int(use["mood"]))
	return ", ".join(parts)
