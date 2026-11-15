class_name LocationDefs
extends RefCounted
## Места для вылазок. Новые места открывают радиопередачи.
## loot — {ресурс: [мин, макс] за день}, items — что можно найти, danger — множитель риска,
## illness — {id, chance} риск болезни, research — очки исследования, supplies — дополнительный груз,
## survivor — шанс встретить человека (в первый раз — наверняка, если есть место),
## first_visit — что узнают при первом посещении, docs — находки (документы, записи, снаряжение),
## которые попадаются при повторных визитах, reveals — какие места открывает первая вылазка сюда,
## shelter — какая община здесь живёт. Каждый визит немного истощает место (см. ExpeditionSystem).

const INFO := {
	"outskirts": {"name": "Окрестности", "desc": "Руины вокруг убежища: понемногу всего.",
		"days": [1, 3], "danger": 1.0, "survivor": 0.12,
		"loot": {"metal": [6, 12], "food": [2, 5], "water": [1, 4], "wood": [3, 7], "concrete": [1, 3]},
		"items": ["knife", "trowel", "chocolate", "medkit", "overalls", "jacket", "wrench", "gasmask"],
		"docs": ["sirens_signal"], "reveals": ["factory"]},
	"houses": {"name": "Заброшенные дома", "desc": "Пустые квартиры на окраине: кухни, аптечки, чьи-то дневники.",
		"days": [1, 3], "danger": 0.8, "survivor": 0.15,
		"loot": {"food": [3, 6], "wood": [4, 8], "medicine": [0, 2]}, "items": ["chocolate", "jacket", "overalls", "medkit"],
		"docs": ["diary_teen", "answering_machine"], "reveals": ["metro"]},
	"factory": {"name": "Завод «Прогресс»", "desc": "Цеха, станки и горы металла. Перекрытия ненадёжны.",
		"days": [2, 3], "danger": 1.3, "survivor": 0.1,
		"loot": {"metal": [10, 18], "concrete": [2, 4]}, "items": ["wrench", "gasmask", "toolkit"],
		"docs": ["order_emerald", "shift_tape", "toolkit_find"], "reveals": ["military"],
		"first_visit": "В конторе цеха — стопки нарядов с грифом «Изумруд». Завод делал детали для того самого объекта."},
	"metro": {"name": "Станция «Заречная»", "desc": "Под землёй живёт община. Можно разжиться водой и слухами.",
		"days": [2, 3], "danger": 1.0, "survivor": 0.2,
		"loot": {"water": [5, 10], "food": [2, 5], "metal": [3, 6]}, "items": ["binoculars", "knife", "medkit"],
		"docs": ["metro_map", "birds_tape"], "shelter": "metro",
		"first_visit": "Старший общины показал тоннель на север: «Там светится. Мы туда не ходим и вам не советуем»."},
	"military": {"name": "Военная часть 41-17", "desc": "Брошенная база: оружие, лекарства и фон свечения.",
		"days": [2, 4], "danger": 1.8, "survivor": 0.1, "illness": {"id": "radiation", "chance": 0.15},
		"loot": {"metal": [6, 10], "medicine": [2, 4]}, "items": ["pistol", "armor", "rifle", "hazmat"],
		"docs": ["evac_order", "numbers_key", "rifle_find"], "shelter": "rubezh",
		"first_visit": "На плацу брошены машины с открытыми дверцами. Люди ушли пешком — и очень быстро."},
	"north_shelter": {"name": "Убежище «Северное»", "desc": "Соседи по несчастью. Делятся едой и водой, а взамен просят лекарства.",
		"days": [2, 3], "danger": 0.5, "survivor": 0.35, "supplies": {"medicine": 3},
		"loot": {"water": [8, 14], "food": [6, 10]}, "items": ["chocolate", "overalls"], "shelter": "north",
		"first_visit": "В «Северном» двадцать человек. Их старшая показала карту: все убежища района строили по одному проекту — на случай аварии на объекте «Изумруд»."},
	"hospital": {"name": "Больница №3", "desc": "Разграблена, но в подвале ещё есть лекарства. Можно подцепить заразу.",
		"days": [2, 3], "danger": 1.2, "survivor": 0.25, "illness": {"id": "flu", "chance": 0.2},
		"loot": {"medicine": [3, 6], "metal": [2, 5]}, "items": ["medkit", "pills", "labcoat"], "docs": ["doctor_memo"],
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
		"loot": {"metal": [4, 8], "medicine": [1, 3]}, "items": ["gasmask", "labcoat", "pills", "hazmat"],
		"docs": ["dome_photo", "last_log"],
		"first_visit": "В разбитой лаборатории нашли журнал смены: «03:10 — резонанс выше расчётного. 03:13 — купол светится. 03:14 —» дальше страница обуглена."},
}


static func exists(id: String) -> bool:
	return INFO.has(id)


static func name_of(id: String) -> String:
	return String(INFO[id]["name"])
