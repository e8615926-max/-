class_name LocationDefs
extends RefCounted
## Места для вылазок. Новые места открывают радиопередачи.
## loot — {ресурс: [мин, макс] за день}, items — что можно найти, danger — множитель риска,
## illness — {id, chance} риск болезни, research — очки исследования, supplies — дополнительный груз,
## survivor — шанс встретить человека (в первый раз — наверняка, если есть место),
## first_visit — что узнают при первом посещении.

const INFO := {
	"outskirts": {"name": "Окрестности", "desc": "Руины вокруг убежища: понемногу всего.",
		"days": [1, 3], "danger": 1.0, "survivor": 0.12,
		"loot": {"metal": [6, 12], "food": [2, 5], "water": [1, 4], "wood": [3, 7], "concrete": [1, 3]},
		"items": ["knife", "trowel", "chocolate", "medkit", "overalls", "jacket", "wrench", "gasmask"]},
	"north_shelter": {"name": "Убежище «Северное»", "desc": "Соседи по несчастью. Делятся едой и водой, а взамен просят лекарства.",
		"days": [2, 3], "danger": 0.5, "survivor": 0.35, "supplies": {"medicine": 3},
		"loot": {"water": [8, 14], "food": [6, 10]}, "items": ["chocolate", "overalls"],
		"first_visit": "В «Северном» двадцать человек. Их старшая показала карту: все убежища района строили по одному проекту — на случай аварии на объекте «Изумруд»."},
	"hospital": {"name": "Больница №3", "desc": "Разграблена, но в подвале ещё есть лекарства. Можно подцепить заразу.",
		"days": [2, 3], "danger": 1.2, "survivor": 0.25, "illness": {"id": "flu", "chance": 0.2},
		"loot": {"medicine": [3, 6], "metal": [2, 5]}, "items": ["medkit", "pills", "labcoat"],
		"first_visit": "В журнале приёмного покоя за ту ночь — десятки записей: «ожоги неясной природы, кожа светится зелёным»."},
	"sawmill": {"name": "Старая лесопилка", "desc": "Штабеля досок у реки. Говорят, там живёт лесник.",
		"days": [2, 3], "danger": 0.9, "survivor": 0.3,
		"loot": {"wood": [10, 18], "food": [1, 3]}, "items": ["knife", "jacket"],
		"first_visit": "Лесник рассказал, что в ту ночь река на час потекла вспять, а рыба всплыла светящимися пятнами."},
	"cement_works": {"name": "Бетонный завод", "desc": "Мешки цемента и мародёры. Опасно.",
		"days": [2, 3], "danger": 1.5, "survivor": 0.1, "illness": {"id": "radiation", "chance": 0.1},
		"loot": {"concrete": [8, 14], "metal": [3, 6]}, "items": ["wrench", "overalls", "pistol"],
		"first_visit": "На воротах завода — свежая надпись мелом: «Изумруд не выключили. Он просто уснул»."},
	"science_town": {"name": "Научный городок", "desc": "Здесь работали над объектом «Изумруд». Фон зелёного свечения.",
		"days": [3, 4], "danger": 1.6, "survivor": 0.1, "illness": {"id": "radiation", "chance": 0.35}, "research": [15, 30],
		"loot": {"metal": [4, 8], "medicine": [1, 3]}, "items": ["gasmask", "labcoat", "pills"],
		"first_visit": "В разбитой лаборатории нашли журнал смены: «03:10 — резонанс выше расчётного. 03:13 — купол светится. 03:14 —» дальше страница обуглена."},
}


static func exists(id: String) -> bool:
	return INFO.has(id)


static func name_of(id: String) -> String:
	return String(INFO[id]["name"])
