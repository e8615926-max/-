class_name IllnessDefs
extends RefCounted
## Болезни. work — множитель работы, health/mood — изменение за день,
## contagion — шанс заразить соседа за день, days — сколько длится,
## needs_medicine — без лекарств не проходит (только вредит).

const INFO := {
	"cold": {"name": "Простуда", "desc": "Насморк и кашель. Проходит сама, с лечением быстрее.",
		"work": 0.85, "health": -1.0, "mood": -1.0, "contagion": 0.1, "days": [3, 5], "needs_medicine": false},
	"flu": {"name": "Грипп", "desc": "Жар и ломота. Очень заразен.",
		"work": 0.6, "health": -3.0, "mood": -2.0, "contagion": 0.18, "days": [5, 8], "needs_medicine": false},
	"dysentery": {"name": "Дизентерия", "desc": "От плохой воды. Изматывает и обезвоживает.",
		"work": 0.6, "health": -3.0, "mood": -2.0, "contagion": 0.08, "days": [3, 6], "needs_medicine": false},
	"infection": {"name": "Заражение раны", "desc": "Рана воспалилась. Без лекарств не проходит и становится только хуже.",
		"work": 0.7, "health": -4.0, "mood": -2.0, "contagion": 0.0, "days": [4, 6], "needs_medicine": true},
	"radiation": {"name": "Лучевая болезнь", "desc": "След зелёного свечения. Лечится долго и только лекарствами.",
		"work": 0.7, "health": -2.0, "mood": -3.0, "contagion": 0.0, "days": [8, 12], "needs_medicine": true},
}


static func exists(id: String) -> bool:
	return INFO.has(id)


static func name_of(id: String) -> String:
	return String(INFO[id]["name"])


static func needs_medicine(id: String) -> bool:
	return bool(INFO[id]["needs_medicine"])


static func roll_days(id: String, rng: RandomNumberGenerator) -> int:
	var range_days: Array = INFO[id]["days"]
	return rng.randi_range(int(range_days[0]), int(range_days[1]))
