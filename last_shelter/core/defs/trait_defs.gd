class_name TraitDefs
extends RefCounted
## Черты характера. Эффекты применяются в игровых системах по идентификатору:
## работа и настроение — DaySystem, отношения — RelationshipSystem, события — EventSystem,
## вылазки — ExpeditionSystem, износ оборудования — MaintenanceSystem.

const INFO := {
	"hardworker": {"name": "Трудяга", "name_f": "Трудяга",
		"desc": "Работает на 25% продуктивнее."},
	"lazy": {"name": "Лентяй", "name_f": "Лентяйка",
		"desc": "Работает на 20% хуже и позже приходит на смену, зато реже грустит."},
	"optimist": {"name": "Оптимист", "name_f": "Оптимистка",
		"desc": "Настроение каждый день немного растёт."},
	"pessimist": {"name": "Пессимист", "name_f": "Пессимистка",
		"desc": "Настроение понемногу падает, зато беды переносит вдвое спокойнее."},
	"kind": {"name": "Добрый", "name_f": "Добрая",
		"desc": "Легко ладит с людьми и умеет мирить поссорившихся."},
	"sociable": {"name": "Душа компании", "name_f": "Душа компании",
		"desc": "Легче находит общий язык и хорошо мирит людей."},
	"grumpy": {"name": "Ворчун", "name_f": "Ворчунья",
		"desc": "Чаще ссорится с соседями."},
	"loner": {"name": "Одиночка", "name_f": "Одиночка",
		"desc": "Отношения меняются медленнее, не скучает без друзей."},
	"nervous": {"name": "Нервный", "name_f": "Нервная",
		"desc": "Беды переживает в полтора раза тяжелее; в вылазках рискует сильнее."},
	"brave": {"name": "Смельчак", "name_f": "Смельчак",
		"desc": "Приносит из вылазок на 20% больше и не теряется в опасности."},
	"tough": {"name": "Крепкий", "name_f": "Крепкая",
		"desc": "Больше здоровья, получает вдвое меньше урона."},
	"frugal": {"name": "Экономный", "name_f": "Экономная",
		"desc": "Съедает на одну порцию еды меньше."},
	"glutton": {"name": "Обжора", "name_f": "Обжора",
		"desc": "Съедает на одну порцию еды больше."},
	"curious": {"name": "Любознательный", "name_f": "Любознательная",
		"desc": "Получает на 20% больше опыта."},
	"clumsy": {"name": "Неуклюжий", "name_f": "Неуклюжая",
		"desc": "Оборудование в его комнате изнашивается в полтора раза быстрее."},
	"handy": {"name": "Мастер на все руки", "name_f": "Мастер на все руки",
		"desc": "Бережёт оборудование; с ним в убежище ремонт дешевле."},
}

## Пары черт, которые не могут быть у одного человека.
const CONFLICTS := [
	["sociable", "grumpy"], ["sociable", "loner"], ["kind", "grumpy"], ["hardworker", "lazy"],
	["optimist", "pessimist"], ["frugal", "glutton"], ["brave", "nervous"], ["clumsy", "handy"],
]


static func ids() -> Array:
	return INFO.keys()


static func exists(id: String) -> bool:
	return INFO.has(id)


## Название с учётом пола: «Добрый» / «Добрая».
static func name_for(id: String, gender: String = "m") -> String:
	var info: Dictionary = INFO[id]
	return String(info["name_f"] if gender == "f" else info["name"])


static func name_of(id: String) -> String:
	return name_for(id, "m")


static func get_desc(id: String) -> String:
	return INFO[id]["desc"]


static func conflicts(a: String, b: String) -> bool:
	for pair: Array in CONFLICTS:
		if pair.has(a) and pair.has(b):
			return true
	return false
