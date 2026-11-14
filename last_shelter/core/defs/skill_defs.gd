class_name SkillDefs
extends RefCounted
## Навыки выживших.

const IDS: Array[String] = ["farming", "engineering", "science", "medicine", "scavenging", "combat"]

const INFO := {
	"farming": {"name": "Фермерство", "desc": "Выращивание еды на гидропонной ферме."},
	"engineering": {"name": "Инженерия", "desc": "Работа с генератором и в мастерской."},
	"science": {"name": "Наука", "desc": "Очистка воды и работа со сложным оборудованием."},
	"medicine": {"name": "Медицина", "desc": "Лечение раненых и больных в медпункте."},
	"scavenging": {"name": "Разведка", "desc": "Поиск припасов в экспедициях."},
	"combat": {"name": "Бой", "desc": "Защита от опасностей на поверхности."},
}

const MAX_LEVEL := 10


static func name_of(id: String) -> String:
	return INFO[id]["name"]


static func xp_for_next(level: int) -> int:
	return 20 + level * 15
