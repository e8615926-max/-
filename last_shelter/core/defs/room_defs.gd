class_name RoomDefs
extends RefCounted
## Типы комнат убежища.
##
## cost     — цена постройки в металле
## power    — расход энергии в день
## produces — производимый ресурс ("" если ничего)
## base     — базовая выработка одного работника (плюс его навык)
## passive  — выработка без работников
## skill    — навык, влияющий на работу
## slots    — количество рабочих мест
## beds     — спальные места
## cap      — прибавка к вместимости склада
## wear     — износ оборудования за день (0 — комната не ломается)

const BUILD_ORDER: Array[String] = [
	"quarters", "farm", "kitchen", "water", "generator", "workshop", "medbay", "storage",
]

const INFO := {
	"quarters": {"name": "Жилой отсек", "desc": "Спальные места для четырёх выживших.",
		"cost": 40, "power": 1, "produces": "", "base": 0, "passive": 0, "skill": "", "slots": 0, "beds": 4, "cap": 0, "wear": 0.0},
	"farm": {"name": "Ферма", "desc": "Гидропонные грядки. Производит еду.",
		"cost": 50, "power": 2, "produces": "food", "base": 5, "passive": 0, "skill": "farming", "slots": 2, "beds": 0, "cap": 0, "wear": 1.0},
	"kitchen": {"name": "Кухня", "desc": "Повара экономят продукты и кормят горячим: еды уходит меньше, настроение выше.",
		"cost": 60, "power": 2, "produces": "", "base": 0, "passive": 0, "skill": "farming", "slots": 2, "beds": 0, "cap": 0, "wear": 1.0},
	"water": {"name": "Очистка воды", "desc": "Фильтрует грунтовые воды. Производит воду.",
		"cost": 50, "power": 2, "produces": "water", "base": 5, "passive": 0, "skill": "science", "slots": 2, "beds": 0, "cap": 0, "wear": 1.25},
	"generator": {"name": "Генератор", "desc": "Вырабатывает энергию. Работает и без оператора, но слабо.",
		"cost": 60, "power": 0, "produces": "power", "base": 4, "passive": 4, "skill": "engineering", "slots": 2, "beds": 0, "cap": 0, "wear": 1.5},
	"workshop": {"name": "Мастерская", "desc": "Переработка лома. Производит металл.",
		"cost": 70, "power": 2, "produces": "metal", "base": 3, "passive": 0, "skill": "engineering", "slots": 2, "beds": 0, "cap": 0, "wear": 1.5},
	"medbay": {"name": "Медпункт", "desc": "Лечит всех жителей каждый день. Врач усиливает эффект.",
		"cost": 80, "power": 2, "produces": "", "base": 0, "passive": 0, "skill": "medicine", "slots": 1, "beds": 0, "cap": 0, "wear": 0.75},
	"storage": {"name": "Склад", "desc": "Увеличивает вместимость всех ресурсов на 100.",
		"cost": 40, "power": 0, "produces": "", "base": 0, "passive": 0, "skill": "", "slots": 0, "beds": 0, "cap": 100, "wear": 0.0},
}


static func exists(type: String) -> bool:
	return INFO.has(type)


static func get_def(type: String) -> Dictionary:
	return INFO[type]


static func name_of(type: String) -> String:
	return INFO[type]["name"]
