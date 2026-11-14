class_name SurvivorFactory
extends RefCounted
## Создание выживших: двое стартовых, случайные новички и их биографии.

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

const ANNA_BIO := "До Катастрофы работала врачом скорой помощи в городе Новоград. В ту ночь была на вызове на окраине и видела, как небо над городом стало зелёным. Ведёт дневник и записывает всё, что помнит о прежней жизни."
const VIKTOR_BIO := "Двадцать лет обслуживал подстанции под Новоградом. За час до Катастрофы на всех щитах разом сработала аварийная защита, и он до сих пор хочет понять почему. Любит шахматы и не любит проигрывать."


static func create_starters() -> Array[SurvivorData]:
	var anna := SurvivorData.new()
	anna.first_name = "Анна"
	anna.last_name = "Волкова"
	anna.gender = "f"
	anna.age = 34
	anna.profession = "doctor"
	anna.bio = ANNA_BIO
	anna.appearance = {"skin": 0, "hair_style": 1, "hair_color": 4, "shirt": 5, "pants": 0}
	anna.skills["medicine"]["level"] = 4
	anna.skills["science"]["level"] = 3
	anna.skills["farming"]["level"] = 2
	anna.traits = ["optimist", "kind"]
	anna.interests = ["books", "chess"]
	anna.mood = 75.0
	anna.inventory = ["medkit"]
	anna.equipment["outfit"] = "labcoat"

	var viktor := SurvivorData.new()
	viktor.first_name = "Виктор"
	viktor.last_name = "Орлов"
	viktor.gender = "m"
	viktor.age = 41
	viktor.profession = "engineer"
	viktor.bio = VIKTOR_BIO
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
	s.last_name = surname_for(surname, s.gender)
	if s.gender == "f":
		s.first_name = FEMALE_NAMES[rng.randi() % FEMALE_NAMES.size()]
	else:
		s.first_name = MALE_NAMES[rng.randi() % MALE_NAMES.size()]
	s.age = rng.randi_range(19, 58)

	s.profession = ProfessionDefs.RANDOM_POOL[rng.randi() % ProfessionDefs.RANDOM_POOL.size()]
	var bonus := ProfessionDefs.skills_of(s.profession)
	for skill_id: String in bonus:
		s.skills[skill_id]["level"] = int(bonus[skill_id])
	for _i in 2:
		var skill_id: String = SkillDefs.IDS[rng.randi() % SkillDefs.IDS.size()]
		s.skills[skill_id]["level"] = mini(int(s.skills[skill_id]["level"]) + 1, SkillDefs.MAX_LEVEL)

	var pool := TraitDefs.ids()
	var count := 1 if rng.randf() < 0.6 else 2
	var guard := 0
	while s.traits.size() < count and guard < 40:
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
	s.bio = make_bio(s, rng)
	return s


## Биография из трёх частей: жизнь до Катастрофы, та ночь и личная черточка.
static func make_bio(s: SurvivorData, rng: RandomNumberGenerator) -> String:
	var city: String = BioDefs.CITIES[rng.randi() % BioDefs.CITIES.size()]
	var before := String(BioDefs.BEFORE.get(s.profession, BioDefs.BEFORE["drifter"])).replace("{city}", city)
	var night: String = BioDefs.NIGHT[rng.randi() % BioDefs.NIGHT.size()]
	var personal: String = BioDefs.PERSONAL[rng.randi() % BioDefs.PERSONAL.size()]
	return BioDefs.gendered("%s %s %s" % [before, night, personal], s.gender)


## Биография для старых сохранений, где её ещё не было. Всегда одна и та же для одного жителя.
static func ensure_bio(s: SurvivorData) -> void:
	if s.bio != "":
		return
	if s.first_name == "Анна" and s.last_name == "Волкова":
		s.bio = ANNA_BIO
		return
	if s.first_name == "Виктор" and s.last_name == "Орлов":
		s.bio = VIKTOR_BIO
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(s.full_name()) + s.id
	s.bio = make_bio(s, rng)


## Фамилия в форме нужного пола: «Орлов» → «Орлова».
static func surname_for(base: String, gender: String) -> String:
	return base + "а" if gender == "f" else base


## Мужская форма фамилии выжившего.
static func surname_base(s: SurvivorData) -> String:
	if s.gender == "f" and s.last_name.ends_with("а"):
		return s.last_name.substr(0, s.last_name.length() - 1)
	return s.last_name
