class_name DecorDefs
extends RefCounted
## Украшения и окраска комнат. Уют от украшений поднимает настроение всем жителям.
## place — "wall" (на стене) или "floor" (на полу), comfort — очки уюта.

const SLOTS := 2
## Сколько уюта засчитывается максимум и сколько настроения в день даёт одно очко.
const COMFORT_CAP := 12
const MOOD_PER_COMFORT := 0.25

const ORDER: Array[String] = ["poster", "plant", "rug", "lamp", "painting", "flag", "garland", "bookshelf", "aquarium"]

const INFO := {
	"poster": {"name": "Довоенный плакат", "cost": {"wood": 2}, "comfort": 1, "place": "wall"},
	"plant": {"name": "Цветок в горшке", "cost": {"wood": 3, "water": 2}, "comfort": 1, "place": "floor"},
	"rug": {"name": "Плетёный коврик", "cost": {"wood": 5}, "comfort": 1, "place": "floor"},
	"lamp": {"name": "Тёплая лампа", "cost": {"metal": 4}, "comfort": 1, "place": "floor"},
	"painting": {"name": "Картина", "cost": {"wood": 6}, "comfort": 2, "place": "wall"},
	"flag": {"name": "Флаг убежища", "cost": {"wood": 3, "metal": 2}, "comfort": 2, "place": "wall"},
	"garland": {"name": "Гирлянда", "cost": {"metal": 3, "power": 3}, "comfort": 2, "place": "wall", "research": "comfort"},
	"bookshelf": {"name": "Книжная полка", "cost": {"wood": 10}, "comfort": 3, "place": "floor", "research": "comfort"},
	"aquarium": {"name": "Аквариум", "cost": {"metal": 8, "water": 10}, "comfort": 3, "place": "floor", "research": "comfort"},
}

## Окраска стен: тон, к которому подмешивается цвет комнаты.
const PAINTS := {
	"": {"name": "Обычная", "color": Color(0, 0, 0, 0)},
	"warm": {"name": "Тёплая", "color": Color("8a5a3a")},
	"cold": {"name": "Холодная", "color": Color("3a5a8a")},
	"green": {"name": "Зелёная", "color": Color("3f6a40")},
	"cream": {"name": "Светлая", "color": Color("8a8470")},
}
const PAINT_ORDER: Array[String] = ["", "warm", "cold", "green", "cream"]


static func exists(id: String) -> bool:
	return INFO.has(id)


static func name_of(id: String) -> String:
	return String(INFO[id]["name"])
