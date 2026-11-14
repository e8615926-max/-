class_name SurvivorFactory
extends RefCounted
## Создание выживших: двое стартовых и случайные новички.

const MALE_NAMES: Array[String] = [
	"Виктор", "Алексей", "Дмитрий", "Игорь", "Максим", "Олег",
	"Павел", "Роман", "Сергей", "Тимур", "Юрий", "Глеб",
]
const FEMALE_NAMES: Array[String] = [
	"Анна", "Вера", "Дарья", "Елена", "Зоя", "Ирина",
	"Кира", "Лидия", "Мария", "Нина", "Ольга", "Софья",
]
## Мужская форма; женская получается добавлением «а».
const SURNAMES: Array[String] = [
	"Волков", "Орлов", "Соколов", "Морозов", "Зайцев", "Громов",
	"Лебедев", "Кузнецов", "Воронин", "Савин", "Белов", "Тихонов",
]

const BACKGROUNDS: Array[Dictionary] = [
	{"title": "Бывший врач скорой помощи", "skills": {"medicine": 4, "science": 2}},
	{"title": "Инженер-энергетик", "skills": {"engineering": 4, "science": 1}},
	{"title": "Агроном", "skills": {"farming": 4, "science": 1}},
	{"title": "Школьный учитель химии", "skills": {"science": 4, "medicine": 1}},
	{"title": "Автомеханик", "skills": {"engineering": 3, "scavenging": 2}},
	{"title": "Бывший военный", "skills": {"combat": 4, "scavenging": 2}},
	{"title": "Охотник", "skills": {"scavenging": 3, "combat": 3}},
	{"title": "Фермер", "skills": {"farming": 3, "engineering": 2}},
	{"title": "Медсестра", "skills": {"medicine": 3, "farming": 1}},
	{"title": "Курьер", "skills": {"scavenging": 4}},
	{"title": "Студент", "skills": {"science": 2, "scavenging": 1}},
	{"title": "Повар", "skills": {"farming": 2, "medicine": 1}},
]


static func create_starters() -> Array[SurvivorData]:
	var anna := SurvivorData.new()
	anna.first_name = "Анна"
	anna.last_name = "Волкова"
	anna.gender = "f"
	anna.age = 34
	anna.background = "Бывший врач скорой помощи"
	anna.appearance = {"skin": 0, "hair_style": 1, "hair_color": 4, "shirt": 5, "pants": 0}
	anna.skills["medicine"]["level"] = 4
	anna.skills["science"]["level"] = 3
	anna.skills["farming"]["level"] = 2
	anna.traits = ["optimist"]
	anna.interests = ["books", "chess"]
	anna.mood = 75.0
	anna.inventory = ["medkit"]
	anna.equipment["outfit"] = "labcoat"

	var viktor := SurvivorData.new()
	viktor.first_name = "Виктор"
	viktor.last_name = "Орлов"
	viktor.gender = "m"
	viktor.age = 41
	viktor.background = "Инженер-энергетик"
	viktor.appearance = {"skin": 1, "hair_style": 0, "hair_color": 0, "shirt": 7, "pants": 1}
	viktor.skills["engineering"]["level"] = 4
	viktor.skills["scavenging"]["level"] = 2
	viktor.skills["combat"]["level"] = 2
	viktor.traits = ["hardworker"]
	viktor.interests = ["chess", "tech"]
	viktor.mood = 65.0
	viktor.equipment["tool"] = "wrench"

	return [anna, viktor]


static func create_random(rng: RandomNumberGenerator) -> SurvivorData:
	var s := SurvivorData.new()
	s.gender = "f" if rng.randf() < 0.5 else "m"
	var surname: String = SURNAMES[rng.randi() % SURNAMES.size()]
	if s.gender == "f":
		s.first_name = FEMALE_NAMES[rng.randi() % FEMALE_NAMES.size()]
		s.last_name = surname + "а"
	else:
		s.first_name = MALE_NAMES[rng.randi() % MALE_NAMES.size()]
		s.last_name = surname
	s.age = rng.randi_range(19, 58)

	var bg: Dictionary = BACKGROUNDS[rng.randi() % BACKGROUNDS.size()]
	s.background = bg["title"]
	var bonus: Dictionary = bg["skills"]
	for skill_id: String in bonus:
		s.skills[skill_id]["level"] = int(bonus[skill_id])
	for _i in 2:
		var skill_id: String = SkillDefs.IDS[rng.randi() % SkillDefs.IDS.size()]
		s.skills[skill_id]["level"] = mini(int(s.skills[skill_id]["level"]) + 1, SkillDefs.MAX_LEVEL)

	var pool := TraitDefs.ids()
	var count := 1 if rng.randf() < 0.6 else 2
	var guard := 0
	while s.traits.size() < count and guard < 30:
		guard += 1
		var candidate: String = pool[rng.randi() % pool.size()]
		if s.traits.has(candidate):
			continue
		var ok := true
		for existing: String in s.traits:
			if TraitDefs.conflicts(existing, candidate):
				ok = false
		if ok:
			s.traits.append(candidate)
	var hobbies := InterestDefs.ids()
	while s.interests.size() < InterestDefs.PER_SURVIVOR:
		var hobby: String = hobbies[rng.randi() % hobbies.size()]
		if not s.interests.has(hobby):
			s.interests.append(hobby)
	if s.has_trait("tough"):
		s.max_health = 120.0
	s.health = s.max_health * rng.randf_range(0.7, 1.0)
	s.mood = rng.randf_range(45.0, 75.0)

	var styles := [0, 2, 3] if s.gender == "m" else [1, 4, 0]
	s.appearance = {
		"skin": rng.randi() % SurvivorSprites.SKIN.size(),
		"hair_style": styles[rng.randi() % styles.size()],
		"hair_color": rng.randi() % SurvivorSprites.HAIR.size(),
		"shirt": rng.randi() % SurvivorSprites.SHIRT.size(),
		"pants": rng.randi() % SurvivorSprites.PANTS.size(),
	}
	return s
