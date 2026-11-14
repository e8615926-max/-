class_name ResearchDefs
extends RefCounted
## Технологии лаборатории. points — сколько очков исследования нужно,
## cost — ресурсы, которые тратятся при начале исследования, requires — что изучить раньше.
## Эффекты применяют системы через ResearchSystem.has(id).

const ORDER: Array[String] = [
	"hydroponics", "filtration", "power_grid", "cement_mix", "pharmacology", "field_medicine",
	"toolmaking", "armor", "reinforced", "insulation", "scouting", "radio_decoding", "comfort",
]

const INFO := {
	"hydroponics": {"name": "Гидропоника", "desc": "Питательный раствор вместо грунта: ферма даёт на 20% больше еды.",
		"points": 30, "cost": {"water": 10}, "requires": []},
	"filtration": {"name": "Тонкая фильтрация", "desc": "Очистка воды даёт на 20% больше, дизентерия почти исчезает.",
		"points": 30, "cost": {"metal": 10}, "requires": []},
	"power_grid": {"name": "Умная энергосеть", "desc": "Генераторы вырабатывают на 25% больше энергии.",
		"points": 40, "cost": {"metal": 20}, "requires": []},
	"cement_mix": {"name": "Добавки к бетону", "desc": "Бетонный цех работает на 30% быстрее.",
		"points": 30, "cost": {"concrete": 10}, "requires": []},
	"pharmacology": {"name": "Фармакология", "desc": "Открывает аптеку — комнату, где делают медикаменты.",
		"points": 40, "cost": {"medicine": 3}, "requires": []},
	"field_medicine": {"name": "Полевая медицина", "desc": "Врачи лечат болезни в полтора раза быстрее; в аптеке можно делать таблетки.",
		"points": 35, "cost": {"medicine": 5}, "requires": ["pharmacology"]},
	"toolmaking": {"name": "Инструментальное дело", "desc": "В мастерской можно изготавливать ножи, ключи, совки и противогазы.",
		"points": 35, "cost": {"metal": 15}, "requires": []},
	"armor": {"name": "Защитное снаряжение", "desc": "В мастерской можно делать бронежилеты и пистолеты.",
		"points": 50, "cost": {"metal": 25}, "requires": ["toolmaking"]},
	"reinforced": {"name": "Армированные конструкции", "desc": "Открывает третий уровень улучшения комнат.",
		"points": 50, "cost": {"concrete": 20}, "requires": []},
	"insulation": {"name": "Утепление и вентиляция", "desc": "Оборудование изнашивается на 25% медленнее, в убежище уютнее: настроение +1 в день.",
		"points": 35, "cost": {"wood": 20}, "requires": []},
	"scouting": {"name": "Картография", "desc": "Вылазки на день дольше и на 15% добычливее.",
		"points": 40, "cost": {"food": 10}, "requires": []},
	"radio_decoding": {"name": "Дешифровка сигналов", "desc": "Радиорубка ловит передачи в полтора раза быстрее и читает шифровки.",
		"points": 45, "cost": {"metal": 15}, "requires": []},
	"comfort": {"name": "Уют", "desc": "Открывает гирлянды, книжные полки и аквариумы.",
		"points": 20, "cost": {"wood": 10}, "requires": []},
}


static func exists(id: String) -> bool:
	return INFO.has(id)


static func name_of(id: String) -> String:
	return String(INFO[id]["name"])
