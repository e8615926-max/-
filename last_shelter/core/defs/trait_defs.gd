class_name TraitDefs
extends RefCounted
## Черты характера. Эффекты применяются в игровых системах по идентификатору.

const INFO := {
	"hardworker": {"name": "Трудяга", "desc": "Производит на 25% больше на рабочем месте."},
	"optimist": {"name": "Оптимист", "desc": "Настроение каждый день немного растёт."},
	"sociable": {"name": "Душа компании", "desc": "Легче находит общий язык с другими."},
	"grumpy": {"name": "Ворчун", "desc": "Чаще ссорится с соседями."},
	"loner": {"name": "Одиночка", "desc": "Отношения меняются медленнее, не страдает без друзей."},
	"tough": {"name": "Крепкий", "desc": "Больше здоровья, получает меньше урона."},
	"brave": {"name": "Смельчак", "desc": "Приносит из экспедиций на 20% больше добычи."},
	"frugal": {"name": "Экономный", "desc": "Съедает на одну порцию еды меньше."},
}

## Пары черт, которые не могут быть у одного человека.
const CONFLICTS := [["sociable", "grumpy"], ["sociable", "loner"]]


static func ids() -> Array:
	return INFO.keys()


static func name_of(id: String) -> String:
	return INFO[id]["name"]


static func get_desc(id: String) -> String:
	return INFO[id]["desc"]


static func conflicts(a: String, b: String) -> bool:
	for pair: Array in CONFLICTS:
		if pair.has(a) and pair.has(b):
			return true
	return false
