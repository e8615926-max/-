class_name ProfessionDefs
extends RefCounted
## Профессии до Катастрофы: стартовые навыки и специализация.
## Специалист работает на 25% лучше в своей комнате; у «полевых» профессий — бонусы в вылазках.

const SPEC_BONUS := 1.25

## Профессии, которые выпадают новичкам.
const RANDOM_POOL: Array[String] = [
	"doctor", "nurse", "engineer", "mechanic", "agronomist", "farmer",
	"chemist", "cook", "soldier", "hunter", "courier", "student",
]

const INFO := {
	"doctor": {"m": "Врач скорой помощи", "f": "Врач скорой помощи",
		"skills": {"medicine": 4, "science": 2}, "room": "medbay",
		"spec": "В медпункте лечит на 25% лучше."},
	"nurse": {"m": "Медбрат", "f": "Медсестра",
		"skills": {"medicine": 3, "farming": 1}, "room": "medbay",
		"spec": "В медпункте лечит на 25% лучше."},
	"engineer": {"m": "Инженер-энергетик", "f": "Инженер-энергетик",
		"skills": {"engineering": 4, "science": 1}, "room": "generator",
		"spec": "На генераторе работает на 25% лучше."},
	"mechanic": {"m": "Автомеханик", "f": "Автомеханик",
		"skills": {"engineering": 3, "scavenging": 2}, "room": "workshop",
		"spec": "В мастерской работает на 25% лучше; с ним ремонт дешевле."},
	"agronomist": {"m": "Агроном", "f": "Агроном",
		"skills": {"farming": 4, "science": 1}, "room": "farm",
		"spec": "На ферме работает на 25% лучше."},
	"farmer": {"m": "Фермер", "f": "Фермер",
		"skills": {"farming": 3, "engineering": 2}, "room": "farm",
		"spec": "На ферме работает на 25% лучше."},
	"chemist": {"m": "Учитель химии", "f": "Учительница химии",
		"skills": {"science": 4, "medicine": 1}, "room": "water",
		"spec": "На очистке воды работает на 25% лучше."},
	"cook": {"m": "Повар", "f": "Повар",
		"skills": {"farming": 2, "medicine": 1}, "room": "kitchen",
		"spec": "На кухне экономит на 25% больше еды."},
	"soldier": {"m": "Бывший военный", "f": "Бывшая военная",
		"skills": {"combat": 4, "scavenging": 2}, "room": "",
		"spec": "В вылазках получает ранения на 40% реже, в беде не теряется."},
	"hunter": {"m": "Охотник", "f": "Охотница",
		"skills": {"scavenging": 3, "combat": 3}, "room": "",
		"spec": "Приносит из вылазок на 60% больше еды."},
	"courier": {"m": "Курьер", "f": "Курьер",
		"skills": {"scavenging": 4}, "room": "",
		"spec": "В вылазках чаще находит полезные вещи."},
	"student": {"m": "Студент", "f": "Студентка",
		"skills": {"science": 2, "scavenging": 1}, "room": "",
		"spec": "Быстро учится: +25% опыта."},
	"drifter": {"m": "Бродяга", "f": "Бродяга",
		"skills": {}, "room": "", "spec": ""},
}

## Старые сохранения хранили профессию строкой «прошлого».
const LEGACY := {
	"Бывший врач скорой помощи": "doctor",
	"Инженер-энергетик": "engineer",
	"Агроном": "agronomist",
	"Школьный учитель химии": "chemist",
	"Автомеханик": "mechanic",
	"Бывший военный": "soldier",
	"Охотник": "hunter",
	"Фермер": "farmer",
	"Медсестра": "nurse",
	"Курьер": "courier",
	"Студент": "student",
	"Повар": "cook",
}


static func exists(id: String) -> bool:
	return INFO.has(id)


static func _info(id: String) -> Dictionary:
	return INFO.get(id, INFO["drifter"])


static func name_for(id: String, gender: String) -> String:
	return String(_info(id)["f" if gender == "f" else "m"])


static func skills_of(id: String) -> Dictionary:
	return _info(id)["skills"]


## Тип комнаты, где профессия даёт бонус ("" — бонус вне комнат).
static func room_of(id: String) -> String:
	return String(_info(id)["room"])


static func spec_text(id: String) -> String:
	return String(_info(id)["spec"])


static func from_legacy(title: String) -> String:
	return String(LEGACY.get(title, "drifter"))
