class_name RoomDefs
extends RefCounted
## Типы комнат убежища.
##
## cost     — цена постройки {ресурс: количество}
## power    — расход энергии в день
## produces — производимый ресурс ("" если ничего); modes — переключаемые продукты
## base     — базовая выработка одного работника (плюс его навык); rate — общий множитель
## passive  — выработка без работников
## skill    — навык, влияющий на работу
## slots    — рабочие места; beds — спальные места; cap — прибавка к вместимости склада
## wear     — износ оборудования за день (0 — комната не ломается)
## consumes — расход ресурса на каждого работника в день
## research — какое исследование открывает комнату

const BUILD_ORDER: Array[String] = [
	"quarters", "farm", "kitchen", "water", "generator", "workshop", "cement",
	"medbay", "pharmacy", "lab", "radio", "storage",
]
const MAX_TIER := 3
const TIER_NAMES: Array[String] = ["", "I", "II", "III"]
## Множитель работы по уровню комнаты.
const TIER_OUTPUT: Array[float] = [1.0, 1.0, 1.35, 1.75]

const INFO := {
	"quarters": {"name": "Жилой отсек", "desc": "Спальные места для четырёх выживших; каждый уровень добавляет ещё две.",
		"cost": {"metal": 20, "wood": 20}, "power": 1, "produces": "", "base": 0, "passive": 0, "skill": "", "slots": 0, "beds": 4, "cap": 0, "wear": 0.0},
	"farm": {"name": "Ферма", "desc": "Гидропонные грядки. Производит еду.",
		"cost": {"metal": 30, "wood": 15}, "power": 2, "produces": "food", "base": 5, "passive": 0, "skill": "farming", "slots": 2, "beds": 0, "cap": 0, "wear": 1.0},
	"kitchen": {"name": "Кухня", "desc": "Повара экономят продукты и кормят горячим: еды уходит меньше, настроение выше.",
		"cost": {"metal": 30, "wood": 20}, "power": 2, "produces": "", "base": 0, "passive": 0, "skill": "farming", "slots": 2, "beds": 0, "cap": 0, "wear": 1.0},
	"water": {"name": "Очистка воды", "desc": "Фильтрует грунтовые воды. Производит воду.",
		"cost": {"metal": 35, "concrete": 10}, "power": 2, "produces": "water", "base": 5, "passive": 0, "skill": "science", "slots": 2, "beds": 0, "cap": 0, "wear": 1.25},
	"generator": {"name": "Генератор", "desc": "Вырабатывает энергию. Работает и без оператора, но слабо.",
		"cost": {"metal": 40, "concrete": 15}, "power": 0, "produces": "power", "base": 4, "passive": 4, "skill": "engineering", "slots": 2, "beds": 0, "cap": 0, "wear": 1.5},
	"workshop": {"name": "Мастерская", "desc": "Перерабатывает лом в металл или распиливает балки и мебель из завалов на доски. Здесь же изготавливают снаряжение.",
		"cost": {"metal": 45, "wood": 15}, "power": 2, "produces": "metal", "base": 3, "passive": 0, "skill": "engineering", "slots": 2, "beds": 0, "cap": 0, "wear": 1.5,
		"modes": {"metal": {"name": "Металл", "base": 3}, "wood": {"name": "Доски", "base": 4}}},
	"cement": {"name": "Бетонный цех", "desc": "Замешивает бетон из щебня и воды. Каждый работник расходует 1 воду в день.",
		"cost": {"metal": 35, "wood": 15}, "power": 2, "produces": "concrete", "base": 2, "passive": 0, "skill": "engineering", "slots": 2, "beds": 0, "cap": 0, "wear": 1.25,
		"consumes": {"water": 1}},
	"medbay": {"name": "Медпункт", "desc": "Лечит раны и болезни. Врачи ускоряют выздоровление; на лечение болезней уходят медикаменты.",
		"cost": {"metal": 40, "wood": 10, "concrete": 10}, "power": 2, "produces": "", "base": 0, "passive": 0, "skill": "medicine", "slots": 2, "beds": 0, "cap": 0, "wear": 0.75},
	"pharmacy": {"name": "Аптека", "desc": "Готовит лекарства из трав и химикатов. Производит медикаменты.",
		"cost": {"metal": 40, "concrete": 15, "medicine": 4}, "power": 2, "produces": "medicine", "base": 1, "rate": 0.5, "passive": 0, "skill": "medicine", "slots": 2, "beds": 0, "cap": 0, "wear": 1.0,
		"research": "pharmacology"},
	"lab": {"name": "Лаборатория", "desc": "Учёные исследуют технологии: новые комнаты, снаряжение и улучшения производства.",
		"cost": {"metal": 55, "wood": 10, "concrete": 20}, "power": 3, "produces": "", "base": 2, "passive": 0, "skill": "science", "slots": 2, "beds": 0, "cap": 0, "wear": 1.0},
	"radio": {"name": "Радиорубка", "desc": "Слушает эфир: ловит передачи, находит других выживших и новые места для вылазок.",
		"cost": {"metal": 50, "wood": 10, "concrete": 10}, "power": 3, "produces": "", "base": 2, "passive": 0, "skill": "science", "slots": 1, "beds": 0, "cap": 0, "wear": 1.0},
	"storage": {"name": "Склад", "desc": "Увеличивает вместимость всех ресурсов на 100; каждый уровень — ещё на 50.",
		"cost": {"metal": 20, "wood": 20}, "power": 0, "produces": "", "base": 0, "passive": 0, "skill": "", "slots": 0, "beds": 0, "cap": 100, "wear": 0.0},
}


static func exists(type: String) -> bool:
	return INFO.has(type)


static func get_def(type: String) -> Dictionary:
	return INFO[type]


static func name_of(type: String) -> String:
	return INFO[type]["name"]


static func cost_of(type: String) -> Dictionary:
	return INFO[type]["cost"]


static func research_of(type: String) -> String:
	return String(INFO[type].get("research", ""))


## Цена улучшения до уровня to_tier: часть цены постройки плюс бетон.
static func upgrade_cost(type: String, to_tier: int) -> Dictionary:
	var base: Dictionary = INFO[type]["cost"]
	var mult := 0.8 if to_tier == 2 else 1.5
	var cost := {}
	for res: String in base:
		if res != "medicine":
			cost[res] = roundi(int(base[res]) * mult)
	cost["concrete"] = int(cost.get("concrete", 0)) + (10 if to_tier == 2 else 25)
	return cost


static func beds_of(type: String, tier: int) -> int:
	var beds := int(INFO[type]["beds"])
	return beds + 2 * (tier - 1) if beds > 0 else 0


static func cap_of(type: String, tier: int) -> int:
	return roundi(int(INFO[type]["cap"]) * (1.0 + 0.5 * (tier - 1)))


static func slots_of(type: String, tier: int) -> int:
	var slots := int(INFO[type]["slots"])
	return slots + 1 if slots > 0 and tier >= 3 else slots


static func tier_output(tier: int) -> float:
	return TIER_OUTPUT[clampi(tier, 1, MAX_TIER)]
