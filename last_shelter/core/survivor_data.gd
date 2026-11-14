class_name SurvivorData
extends RefCounted
## Все данные одного выжившего. Чистая модель без узлов сцены —
## сериализуется в словарь для сохранения.

const MAX_INVENTORY := 6

var id: int = 0
var first_name: String = ""
var last_name: String = ""
## "m" или "f"
var gender: String = "m"
var age: int = 30
## Профессия до Катастрофы (см. ProfessionDefs).
var profession: String = "drifter"
## Короткая биография.
var bio: String = ""
## Индексы палитр и причёски: skin, hair_style, hair_color, shirt, pants
var appearance: Dictionary = {}

var health: float = 100.0
var max_health: float = 100.0
var mood: float = 70.0
## Временные состояния: "hungry", "thirsty", "wounded"
var conditions: Array = []
## Болезни: [{"id": см. IllnessDefs, "days": сколько ещё болеть}]
var illnesses: Array = []

## skill_id -> {"level": int, "xp": int}
var skills: Dictionary = {}
var traits: Array = []
## Увлечения (см. InterestDefs) — общие увлечения сближают.
var interests: Array = []

## Идентификаторы предметов в рюкзаке.
var inventory: Array = []
## slot -> item_id ("" если пусто)
var equipment: Dictionary = {"weapon": "", "outfit": "", "tool": ""}

## id другого выжившего -> отношение от -100 до 100
var relationships: Dictionary = {}
## id другого выжившего -> кем он приходится: "sibling", "parent", "child", "partner"
var family: Dictionary = {}

## Рабочее место (id комнаты) или -1.
var room_id: int = -1
var on_expedition: bool = false
var joined_day: int = 1


func _init() -> void:
	for skill_id in SkillDefs.IDS:
		skills[skill_id] = {"level": 1, "xp": 0}


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


## Выбирает форму слова по полу: by_gender("ранен", "ранена").
func by_gender(masculine: String, feminine: String) -> String:
	return feminine if gender == "f" else masculine


func profession_name() -> String:
	return ProfessionDefs.name_for(profession, gender)


func is_adult() -> bool:
	return age >= 18


func has_trait(trait_id: String) -> bool:
	return traits.has(trait_id)


func trait_name(trait_id: String) -> String:
	return TraitDefs.name_for(trait_id, gender)


func has_condition(cond: String) -> bool:
	return conditions.has(cond)


func set_condition(cond: String, on: bool) -> void:
	if on and not conditions.has(cond):
		conditions.append(cond)
	elif not on:
		conditions.erase(cond)


# --- Болезни ---------------------------------------------------------------

func is_ill() -> bool:
	return not illnesses.is_empty()


func has_illness(illness_id: String) -> bool:
	for entry: Dictionary in illnesses:
		if entry["id"] == illness_id:
			return true
	return false


## Заболеть. Повторная та же болезнь только продлевает срок.
func add_illness(illness_id: String, days: float) -> void:
	for entry: Dictionary in illnesses:
		if entry["id"] == illness_id:
			entry["days"] = maxf(float(entry["days"]), days)
			return
	illnesses.append({"id": illness_id, "days": days})


func cure(illness_id: String) -> void:
	for i in range(illnesses.size() - 1, -1, -1):
		if illnesses[i]["id"] == illness_id:
			illnesses.remove_at(i)


## Излечивает самую тяжёлую болезнь (сначала те, что без лекарств не проходят).
func cure_worst() -> String:
	if illnesses.is_empty():
		return ""
	var worst: Dictionary = illnesses[0]
	for entry: Dictionary in illnesses:
		if IllnessDefs.needs_medicine(entry["id"]) and not IllnessDefs.needs_medicine(worst["id"]):
			worst = entry
	var cured := String(worst["id"])
	cure(cured)
	return cured


## Множитель работы от болезней.
func illness_work_factor() -> float:
	var factor := 1.0
	for entry: Dictionary in illnesses:
		factor *= float(IllnessDefs.INFO[entry["id"]]["work"])
	return factor


# --- Навыки ---------------------------------------------------------------

func skill_level(skill_id: String) -> int:
	return int(skills[skill_id]["level"])


func skill_xp(skill_id: String) -> int:
	return int(skills[skill_id]["xp"])


func equipment_bonus(skill_id: String) -> int:
	var total := 0
	for slot: String in equipment:
		var item_id: String = equipment[slot]
		if item_id != "" and ItemDefs.exists(item_id):
			total += ItemDefs.get_bonus(item_id, skill_id)
	return total


## Уровень навыка с учётом экипировки.
func effective_skill(skill_id: String) -> int:
	return skill_level(skill_id) + equipment_bonus(skill_id)


## Множитель опыта от черт и профессии.
func xp_multiplier() -> float:
	var mult := 1.0
	if has_trait("curious"):
		mult *= 1.2
	if profession == "student":
		mult *= 1.25
	return mult


## Опыт за работу, вылазки и события — с учётом черт и профессии.
func add_skill_xp(skill_id: String, amount: int) -> bool:
	return add_xp(skill_id, roundi(amount * xp_multiplier()))


## Добавляет опыт как есть. Возвращает true, если уровень вырос.
func add_xp(skill_id: String, amount: int) -> bool:
	var entry: Dictionary = skills[skill_id]
	var level := int(entry["level"])
	if level >= SkillDefs.MAX_LEVEL:
		return false
	var xp := int(entry["xp"]) + amount
	var leveled := false
	while level < SkillDefs.MAX_LEVEL and xp >= SkillDefs.xp_for_next(level):
		xp -= SkillDefs.xp_for_next(level)
		level += 1
		leveled = true
	entry["level"] = level
	entry["xp"] = xp if level < SkillDefs.MAX_LEVEL else 0
	return leveled


# --- Состояние ------------------------------------------------------------

func change_health(amount: float) -> void:
	health = clampf(health + amount, 0.0, max_health)


func change_mood(amount: float) -> void:
	mood = clampf(mood + amount, 0.0, 100.0)


func is_alive() -> bool:
	return health > 0.0


func health_label() -> String:
	var ratio := health / max_health
	if ratio >= 0.8:
		return by_gender("Здоров", "Здорова")
	if ratio >= 0.5:
		return "Недомогание"
	if ratio >= 0.25:
		return "Плохо"
	return "При смерти"


func mood_label() -> String:
	if mood >= 80.0:
		return by_gender("Счастлив", "Счастлива")
	if mood >= 60.0:
		return by_gender("Доволен", "Довольна")
	if mood >= 40.0:
		return by_gender("Спокоен", "Спокойна")
	if mood >= 20.0:
		return by_gender("Подавлен", "Подавлена")
	return "В отчаянии"


# --- Отношения ------------------------------------------------------------

func get_relation(other_id: int) -> float:
	return float(relationships.get(other_id, 0.0))


func change_relation(other_id: int, amount: float) -> void:
	relationships[other_id] = clampf(get_relation(other_id) + amount, -100.0, 100.0)


# --- Сохранение -----------------------------------------------------------

func to_dict() -> Dictionary:
	var rel := {}
	for other_id: int in relationships:
		rel[str(other_id)] = relationships[other_id]
	var fam := {}
	for other_id: int in family:
		fam[str(other_id)] = family[other_id]
	return {
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"gender": gender,
		"age": age,
		"profession": profession,
		"bio": bio,
		"appearance": appearance.duplicate(),
		"health": health,
		"max_health": max_health,
		"mood": mood,
		"conditions": conditions.duplicate(),
		"illnesses": illnesses.duplicate(true),
		"skills": skills.duplicate(true),
		"traits": traits.duplicate(),
		"interests": interests.duplicate(),
		"inventory": inventory.duplicate(),
		"equipment": equipment.duplicate(),
		"relationships": rel,
		"family": fam,
		"room_id": room_id,
		"on_expedition": on_expedition,
		"joined_day": joined_day,
	}


static func from_dict(d: Dictionary) -> SurvivorData:
	var s := SurvivorData.new()
	s.id = int(d.get("id", 0))
	s.first_name = String(d.get("first_name", "?"))
	s.last_name = String(d.get("last_name", ""))
	s.gender = String(d.get("gender", "m"))
	s.age = int(d.get("age", 30))
	# Сохранения версии 1 хранили профессию строкой «прошлого».
	var prof := String(d.get("profession", ""))
	if prof == "":
		prof = ProfessionDefs.from_legacy(String(d.get("background", "")))
	s.profession = prof if ProfessionDefs.exists(prof) else "drifter"
	s.bio = String(d.get("bio", ""))
	var app: Dictionary = d.get("appearance", {})
	for key: String in app:
		s.appearance[key] = int(app[key])
	s.max_health = float(d.get("max_health", 100.0))
	s.health = clampf(float(d.get("health", 100.0)), 0.0, s.max_health)
	s.mood = clampf(float(d.get("mood", 70.0)), 0.0, 100.0)
	for cond in d.get("conditions", []):
		# В версии 2 болезнь была одним состоянием «sick» — теперь это простуда.
		if String(cond) == "sick":
			s.add_illness("cold", 3.0)
		else:
			s.conditions.append(String(cond))
	for entry in d.get("illnesses", []):
		if entry is Dictionary and IllnessDefs.exists(String(entry.get("id", ""))):
			s.add_illness(String(entry["id"]), maxf(float(entry.get("days", 1.0)), 0.5))
	var saved_skills: Dictionary = d.get("skills", {})
	for skill_id in SkillDefs.IDS:
		if saved_skills.has(skill_id):
			var entry: Dictionary = saved_skills[skill_id]
			s.skills[skill_id] = {
				"level": clampi(int(entry.get("level", 1)), 1, SkillDefs.MAX_LEVEL),
				"xp": int(entry.get("xp", 0)),
			}
	for trait_id in d.get("traits", []):
		if TraitDefs.exists(String(trait_id)):
			s.traits.append(String(trait_id))
	for interest in d.get("interests", []):
		if InterestDefs.exists(String(interest)):
			s.interests.append(String(interest))
	for item_id in d.get("inventory", []):
		if ItemDefs.exists(String(item_id)):
			s.inventory.append(String(item_id))
	var saved_eq: Dictionary = d.get("equipment", {})
	for slot in ItemDefs.SLOTS:
		var item_id := String(saved_eq.get(slot, ""))
		s.equipment[slot] = item_id if ItemDefs.exists(item_id) else ""
	var rel: Dictionary = d.get("relationships", {})
	for key: String in rel:
		s.relationships[int(key)] = float(rel[key])
	var fam: Dictionary = d.get("family", {})
	for key: String in fam:
		if FamilySystem.RELATIONS.has(String(fam[key])):
			s.family[int(key)] = String(fam[key])
	s.room_id = int(d.get("room_id", -1))
	s.on_expedition = bool(d.get("on_expedition", false))
	s.joined_day = int(d.get("joined_day", 1))
	return s
