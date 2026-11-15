class_name ShelterDefs
extends RefCounted
## Другие уцелевшие общины. relation — стартовое отношение к нам (−100..100),
## needs — чем им можно помочь, offers — чем делятся по просьбе, deals — обмен (цена зависит от отношений).
## hostile — может требовать дань и нападать. location — место, где о ней узнают (оно открыто — община известна).

const INFO := {
	"north": {"name": "Убежище «Северное»", "relation": 15, "people": 20, "location": "north_shelter",
		"situation": "Двадцать человек в таком же убежище, как наше. Воды вдоволь, лекарств нет совсем.",
		"needs": {"medicine": 3}, "offers": {"water": 15, "food": 8},
		"deals": [{"give": {"medicine": 2}, "get": {"water": 15}}, {"give": {"metal": 10}, "get": {"food": 10}}]},
	"metro": {"name": "Община «Заречная»", "relation": -5, "people": 35, "location": "metro",
		"situation": "Живут на станции метро и в тоннелях. Сборщики хлама, к чужакам недоверчивы, но торгуют.",
		"needs": {"food": 12}, "offers": {"metal": 15, "wood": 8},
		"deals": [{"give": {"food": 12}, "get": {"metal": 15}}, {"give": {"water": 10}, "get": {"wood": 12}},
			{"give": {"metal": 40}, "item": "binoculars"}]},
	"rubezh": {"name": "Гарнизон «Рубеж»", "relation": -20, "people": 15, "hostile": true, "location": "military",
		"situation": "Остатки военной колонны. Хорошо вооружены, считают округу своей и требуют «налог».",
		"needs": {"food": 10, "metal": 10}, "offers": {"medicine": 6, "metal": 10},
		"deals": [{"give": {"food": 15}, "get": {"medicine": 5}}, {"give": {"metal": 30, "food": 20}, "item": "rifle"}]},
}


static func name_of(id: String) -> String:
	return String(INFO[id]["name"])
