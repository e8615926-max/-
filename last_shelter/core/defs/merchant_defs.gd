class_name MerchantDefs
extends RefCounted
## Бродячие торговцы. Каждый визит — свой набор сделок из пула торговца.
## Сделка: give — что отдаём, get — что получаем (ресурсы), item — получаем предмет, stock — сколько раз.
## buys — ресурс, которым торговец платит за наши предметы.

const VISIT_DAYS := 2
const DAILY_CHANCE := 0.15
const DEALS_PER_VISIT := 5

const INFO := {
	"mikhalych": {"name": "Старьёвщик Михалыч", "greeting": "«Железо, доски, всякая всячина — меняю честно, почти»",
		"buys": "metal",
		"deals": [
			{"give": {"food": 10}, "get": {"metal": 12}},
			{"give": {"water": 10}, "get": {"wood": 12}},
			{"give": {"metal": 15}, "get": {"concrete": 10}},
			{"give": {"wood": 15}, "get": {"metal": 12}},
			{"give": {"metal": 20}, "item": "wrench"},
			{"give": {"metal": 12, "wood": 6}, "item": "gasmask"},
			{"give": {"food": 15}, "item": "jacket"},
		],
		"rare": [{"give": {"metal": 60, "food": 20}, "item": "toolkit"}, {"give": {"metal": 50, "wood": 20}, "item": "binoculars"}]},
	"caravan": {"name": "Караван «Тихие колёса»", "greeting": "«Возим еду с юга. Платите бетоном и металлом — у нас стройка»",
		"buys": "food",
		"deals": [
			{"give": {"metal": 12}, "get": {"food": 15}},
			{"give": {"concrete": 10}, "get": {"water": 15}},
			{"give": {"metal": 10}, "get": {"water": 12}},
			{"give": {"wood": 12}, "get": {"food": 12}},
			{"give": {"medicine": 3}, "get": {"food": 20}},
			{"give": {"metal": 15}, "item": "chocolate"},
		],
		"rare": [{"give": {"metal": 70, "concrete": 20}, "item": "rifle"}, {"give": {"food": 40, "water": 30}, "item": "armor"}]},
	"doctor_lee": {"name": "Доктор Ли", "greeting": "«Лекарства не бесплатны, но лучше дорогие, чем никаких»",
		"buys": "medicine",
		"deals": [
			{"give": {"food": 12}, "get": {"medicine": 4}},
			{"give": {"metal": 15}, "get": {"medicine": 5}},
			{"give": {"water": 15}, "get": {"medicine": 4}},
			{"give": {"metal": 15}, "item": "medkit"},
			{"give": {"food": 10, "water": 10}, "item": "pills"},
		],
		"rare": [{"give": {"metal": 60, "medicine": 10}, "item": "hazmat"}]},
}


static func name_of(id: String) -> String:
	return String(INFO[id]["name"])
