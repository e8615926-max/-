class_name InterestDefs
extends RefCounted
## Увлечения выживших. Общие увлечения сближают людей, без них отношения
## складываются как повезёт — так появляются и друзья, и недруги.

const INFO := {
	"chess": "Шахматы",
	"music": "Музыка",
	"books": "Книги",
	"cooking": "Кулинария",
	"tech": "Техника",
	"sport": "Спорт",
	"cards": "Карточные игры",
	"stars": "Астрономия",
	"drawing": "Рисование",
	"fishing": "Рыбалка",
}

## Сколько увлечений у каждого выжившего.
const PER_SURVIVOR := 2


static func ids() -> Array:
	return INFO.keys()


static func exists(id: String) -> bool:
	return INFO.has(id)


static func name_of(id: String) -> String:
	return String(INFO.get(id, id))


## Названия через запятую: «Книги, шахматы».
static func list_text(id_list: Array) -> String:
	var names: PackedStringArray = []
	for id: String in id_list:
		names.append(name_of(id) if names.is_empty() else name_of(id).to_lower())
	return ", ".join(names)
