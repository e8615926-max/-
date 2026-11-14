extends Node
## Автотест логики и сцен. Запуск без экрана:
##   godot --headless --path . res://tests/smoke_test.tscn
## Код выхода 0 — всё в порядке, 1 — есть ошибки.

const SAVE_PATH := "user://savegame.json"
const PRODUCER := {"food": "farm", "water": "water", "power": "generator", "metal": "workshop"}

var _failed: int = 0
var _passed: int = 0


func _ready() -> void:
	# Не трогаем настоящее сохранение игрока.
	var backup := ""
	if FileAccess.file_exists(SAVE_PATH):
		backup = FileAccess.get_file_as_string(SAVE_PATH)

	_test_art()
	_test_new_game()
	_test_assignment_and_economy()
	_test_building()
	_test_inventory()
	_test_interests()
	_test_relationships()
	_test_expedition()
	_test_save_load()
	_test_migration_v1()
	_test_traits_and_professions()
	_test_kitchen()
	_test_maintenance()
	_test_families()
	_test_time()
	_test_events()
	_test_chronicle()
	_test_migration_v2()
	_test_resources_and_costs()
	_test_upgrades()
	_test_medicine()
	_test_research()
	_test_radio_and_locations()
	_test_decor_and_crafting()
	_test_long_run()
	_test_balance()
	await _test_scenes()

	if backup != "":
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		SaveManager.delete_save()

	print("\n=== Тесты: пройдено %d, провалено %d ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("ПРОВАЛ: " + what)


func _test_art() -> void:
	for icon_name: String in PixelIcons.ICONS:
		var rows: Array = PixelIcons.ICONS[icon_name]
		var ok := rows.size() == 10
		for row: String in rows:
			ok = ok and row.length() == 10
		_check(ok, "иконка %s должна быть 10×10" % icon_name)
	for item_id: String in ItemDefs.INFO:
		_check(PixelIcons.has_icon("item_" + item_id), "нет иконки предмета " + item_id)
	for res in ResourceDefs.IDS:
		_check(PixelIcons.has_icon(ResourceDefs.INFO[res]["icon"]), "нет иконки ресурса " + res)
	for head: Array in SurvivorSprites.HEADS:
		for row: String in head:
			_check(row.length() == 12, "строка головы должна быть 12 символов")
	var frames := SurvivorSprites.get_frames({"skin": 1, "hair_style": 2, "hair_color": 3, "shirt": 4, "pants": 1})
	_check(frames.size() == 2 and frames[0].get_width() == SurvivorSprites.FRAME_W
		and frames[0].get_height() == SurvivorSprites.FRAME_H, "размер кадра выжившего")
	for type in RoomDefs.BUILD_ORDER:
		_check(RoomPainter.WALLS.has(type), "нет графики комнаты " + type)
	for item_id in ItemDefs.LOOT_TABLE:
		_check(ItemDefs.exists(item_id), "неизвестный предмет в добыче: " + item_id)


func _test_new_game() -> void:
	GameState.new_game()
	_check(GameState.day == 1, "новая игра начинается с первого дня")
	_check(GameState.survivors.size() == 2, "двое стартовых выживших")
	_check(GameState.rooms.size() == 4, "четыре стартовые комнаты")
	_check(GameState.bed_capacity() == 4, "четыре спальных места")
	var a := GameState.survivors[0]
	var b := GameState.survivors[1]
	_check(a.id != b.id and a.id > 0, "уникальные идентификаторы")
	_check(a.relationships.has(b.id) and b.relationships.has(a.id), "стартовые выжившие знакомы")
	_check(a.full_name() != "" and not a.appearance.is_empty(), "у выжившего есть имя и внешность")
	_check(a.profession == "doctor" and b.profession == "engineer", "у стартовых жителей есть профессии")
	_check(a.bio == SurvivorFactory.ANNA_BIO and b.bio != "", "у стартовых жителей есть биографии")
	_check(GameState.minute == TimeSystem.DAY_START, "игра начинается утром")


func _test_assignment_and_economy() -> void:
	GameState.new_game()
	var anna := GameState.survivors[0]
	var viktor := GameState.survivors[1]
	var farm := GameState.first_room_of_type("farm")
	var generator := GameState.first_room_of_type("generator")
	var idle: Dictionary = DaySystem.compute_economy()["delta"]
	_check(int(idle["food"]) < 0, "без работников еда убывает")
	_check(GameState.assign(anna.id, farm.id), "назначение на ферму")
	_check(GameState.assign(viktor.id, generator.id), "назначение на генератор")
	var busy: Dictionary = DaySystem.compute_economy()["delta"]
	_check(int(busy["food"]) > int(idle["food"]), "работник фермы увеличивает еду")
	_check(int(busy["power"]) > int(idle["power"]), "оператор увеличивает энергию")
	_check(not GameState.assign(viktor.id, GameState.first_room_of_type("quarters").id), "в жилой отсек назначить нельзя")
	_check(viktor.room_id == generator.id, "неудачное назначение не меняет работу")

	var food_before := GameState.get_resource("food")
	var report := DaySystem.advance()
	_check(GameState.day == 2, "день увеличился")
	_check(int(report["day"]) == 1 and not (report["lines"] as Array).is_empty(), "отчёт о дне заполнен")
	_check(GameState.get_resource("food") - food_before == int(report["delta"]["food"]), "отчёт совпадает с изменением еды")

	# Нехватка энергии отключает комнаты, голод бьёт по здоровью.
	GameState.resources["power"] = 0
	GameState.assign(viktor.id, -1)
	GameState.resources["food"] = 0
	GameState.assign(anna.id, -1)
	var unpowered: Array = DaySystem.compute_economy()["unpowered"]
	_check(not unpowered.is_empty(), "без энергии есть отключённые комнаты")
	var health_before := anna.health
	DaySystem.advance()
	_check(anna.health < health_before and anna.has_condition("hungry"), "голод снижает здоровье")


func _test_building() -> void:
	GameState.new_game()
	_check(not GameState.can_build_at(0, 0), "занятую ячейку застроить нельзя")
	_check(not GameState.can_build_at(2, 3), "нельзя строить без соседа слева")
	_check(GameState.can_build_at(2, 0) and GameState.can_build_at(0, 3), "можно строить у шахты и рядом с комнатой")
	var metal := GameState.get_resource("metal")
	var wood := GameState.get_resource("wood")
	_check(GameState.build_room("storage", 2, 0), "постройка склада")
	_check(GameState.get_resource("metal") == metal - 20 and GameState.get_resource("wood") == wood - 20, "металл и дерево списаны")
	_check(GameState.get_cap("food") == 200, "склад увеличил вместимость")
	GameState.resources["metal"] = 5
	_check(not GameState.build_room("medbay", 0, 3), "без металла строить нельзя")
	_check(GameState.build_error("medbay", 0, 3) != "", "есть причина отказа")


func _test_inventory() -> void:
	GameState.new_game()
	var viktor := GameState.survivors[1]
	_check(viktor.effective_skill("engineering") == viktor.skill_level("engineering") + 2, "ключ даёт бонус к инженерии")
	_check(InventorySystem.unequip(viktor, "tool"), "снять инструмент")
	_check(viktor.equipment["tool"] == "" and viktor.inventory.has("wrench"), "ключ в рюкзаке")
	_check(InventorySystem.take_from_storage(viktor, "knife"), "взять нож со склада")
	_check(GameState.storage_count("knife") == 0, "нож ушёл со склада")
	_check(InventorySystem.equip(viktor, viktor.inventory.find("knife")), "надеть нож")
	_check(viktor.equipment["weapon"] == "knife", "нож в слоте оружия")
	_check(InventorySystem.take_from_storage(viktor, "medkit"), "взять аптечку")
	viktor.health = 30.0
	_check(InventorySystem.use_item(viktor, viktor.inventory.find("medkit")), "использовать аптечку")
	_check(is_equal_approx(viktor.health, 70.0), "аптечка лечит на 40")
	_check(InventorySystem.put_to_storage(viktor, viktor.inventory.find("wrench")), "вернуть ключ на склад")
	_check(GameState.storage_count("wrench") == 1, "ключ на складе")
	_check(not InventorySystem.take_from_storage(viktor, "pistol"), "нельзя взять то, чего нет")


func _test_interests() -> void:
	GameState.new_game()
	var anna := GameState.survivors[0]
	var viktor := GameState.survivors[1]
	_check(RelationshipSystem.shared_interests(anna, viktor) == ["chess"], "стартовых выживших сближают шахматы")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for _i in 20:
		var s := SurvivorFactory.create_random(rng)
		var ok: bool = s.interests.size() == InterestDefs.PER_SURVIVOR and s.interests[0] != s.interests[1]
		for interest: String in s.interests:
			ok = ok and InterestDefs.exists(interest)
		_check(ok, "у новичка два разных увлечения")
	var loner := SurvivorFactory.create_random(rng)
	loner.interests = ["fishing", "stars"]
	loner.traits = []
	_check(RelationshipSystem.compatibility(anna, viktor) > RelationshipSystem.compatibility(anna, loner),
		"общие увлечения повышают совместимость")


## Пара с заданным характером, настроением и увлечениями; возвращает отношения через 30 дней.
func _relation_after_month(traits: Array, mood: float, interests_a: Array, interests_b: Array) -> float:
	GameState.reset()
	GameState.rng.seed = 7
	var people: Array[SurvivorData] = []
	for interests: Array in [interests_a, interests_b]:
		var s := SurvivorFactory.create_random(GameState.rng)
		s.traits = traits.duplicate()
		s.interests = interests.duplicate()
		s.mood = mood
		GameState.add_survivor(s)
		people.append(s)
	for _day in 30:
		var lines: Array[Dictionary] = []
		RelationshipSystem.daily_update(lines)
	return RelationshipSystem.mutual(people[0], people[1])


func _test_relationships() -> void:
	_check(RelationshipSystem.level_of(-80.0) == 0 and RelationshipSystem.level_of(0.0) == 2
		and RelationshipSystem.level_of(75.0) == 4, "границы уровней отношений")
	var friends := _relation_after_month(["sociable"], 80.0, ["chess", "music"], ["music", "chess"])
	var rivals := _relation_after_month(["grumpy"], 20.0, ["chess", "music"], ["sport", "cards"])
	_check(RelationshipSystem.level_of(friends) >= 3, "родственные души сближаются (%d)" % roundi(friends))
	_check(RelationshipSystem.level_of(rivals) <= 1, "ворчуны без общих интересов ссорятся (%d)" % roundi(rivals))
	_check(absf(friends) <= 100.0 and absf(rivals) <= 100.0, "отношения в пределах −100..100")

	GameState.new_game()
	var a := GameState.survivors[0]
	var b := GameState.survivors[1]
	GameState.remove_survivor(b.id)
	_check(not a.relationships.has(b.id), "после ухода отношения удаляются")


func _test_expedition() -> void:
	GameState.new_game()
	var viktor := GameState.survivors[1]
	GameState.assign(viktor.id, GameState.first_room_of_type("generator").id)
	var food := GameState.get_resource("food")
	_check(ExpeditionSystem.start_error(viktor, 2) == "", "экспедицию можно начать")
	_check(ExpeditionSystem.start(viktor.id, 2), "экспедиция началась")
	_check(viktor.on_expedition and viktor.room_id == -1, "выживший ушёл и снят с работы")
	_check(GameState.get_resource("food") == food - 4, "припасы списаны")
	_check(not ExpeditionSystem.start(viktor.id, 1), "нельзя отправить дважды")
	_check(GameState.survivors_in_shelter().size() == 1, "в убежище остался один")
	var metal := GameState.get_resource("metal")
	DaySystem.advance()
	_check(viktor.on_expedition, "через день ещё в пути")
	DaySystem.advance()
	_check(not viktor.on_expedition and GameState.expeditions.is_empty(), "через два дня вернулся")
	_check(GameState.get_resource("metal") > metal, "экспедиция принесла металл")


func _test_save_load() -> void:
	GameState.new_game()
	var anna := GameState.survivors[0]
	GameState.assign(anna.id, GameState.first_room_of_type("farm").id)
	GameState.build_room("workshop", 1, 1)
	ExpeditionSystem.start(GameState.survivors[1].id, 3)
	DaySystem.advance()
	anna.add_xp("farming", 7)
	GameState.minute = 800.0
	GameState.rooms[1].condition = 42.5
	GameState.rooms[1].broken = true
	anna.add_illness("flu", 4.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var found := FamilySystem.make_relative(anna, rng)
	GameState.add_survivor(found["survivor"])
	FamilySystem.link(anna, found["survivor"], found["rel"])
	var snapshot := JSON.stringify(GameState.to_dict())
	_check(SaveManager.save_game(), "сохранение записано")
	_check(SaveManager.has_save(), "файл сохранения существует")
	GameState.reset()
	_check(GameState.survivors.is_empty(), "состояние сброшено")
	_check(SaveManager.load_game(), "сохранение загружено")
	_check(JSON.stringify(GameState.to_dict()) == snapshot, "после загрузки состояние совпадает")
	var loaded := GameState.survivors[0]
	_check(loaded.relationships.has(GameState.survivors[1].id), "ключи отношений восстановлены как числа")
	_check(loaded.interests == ["books", "chess"], "увлечения восстановлены")
	_check(GameState.survivors[1].on_expedition and GameState.expeditions.size() == 1, "экспедиция восстановлена")
	_check(loaded.room_id == GameState.first_room_of_type("farm").id, "рабочее место восстановлено")
	_check(not loaded.family.is_empty() and GameState.rooms[1].broken and is_equal_approx(GameState.minute, 800.0),
		"семья, поломки и время суток восстановлены")

	# Повреждённый файл не должен ронять игру.
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ это не json")
	f.close()
	_check(not SaveManager.load_game(), "повреждённое сохранение отклонено")


func _test_migration_v1() -> void:
	var fixture := FileAccess.get_file_as_string("res://tests/fixtures/save_v1.json")
	_check(fixture != "", "есть образец сохранения версии 1")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(fixture)
	f.close()
	GameState.reset()
	_check(SaveManager.load_game(), "сохранение версии 1 загружается")
	_check(GameState.day == 4 and GameState.survivors.size() == 3, "день и жители из старого сохранения на месте")
	var anna := GameState.survivors[0]
	var viktor := GameState.survivors[1]
	var third := GameState.survivors[2]
	_check(anna.profession == "doctor" and viktor.profession == "engineer" and third.profession == "soldier",
		"профессии перенесены из старого поля «прошлое»")
	_check(anna.bio == SurvivorFactory.ANNA_BIO and viktor.bio == SurvivorFactory.VIKTOR_BIO and third.bio != "",
		"у всех жителей появились биографии")
	_check(third.on_expedition and GameState.expeditions.size() == 1, "экспедиция из старого сохранения продолжается")
	_check(anna.equipment["weapon"] == "knife", "экипировка сохранилась")
	_check(GameState.minute == TimeSystem.DAY_START, "старое сохранение продолжается с утра")
	var rooms_ok := true
	for room in GameState.rooms:
		rooms_ok = rooms_ok and is_equal_approx(room.condition, 100.0) and not room.broken
	_check(rooms_ok, "комнаты старого сохранения исправны")
	_check(not GameState.chronicle.is_empty(), "для старого сохранения начата летопись")
	var snapshot := JSON.stringify(GameState.to_dict())
	_check(SaveManager.save_game(), "старая игра пересохраняется")
	GameState.reset()
	_check(SaveManager.load_game() and JSON.stringify(GameState.to_dict()) == snapshot, "после пересохранения состояние то же")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_check(int(saved["version"]) == SaveManager.VERSION, "пересохранено в новой версии")


func _test_traits_and_professions() -> void:
	GameState.new_game()
	var farm := GameState.first_room_of_type("farm")
	var a := GameState.survivors[0]
	var b := GameState.survivors[1]
	for s: SurvivorData in [a, b]:
		s.traits = []
		s.profession = "drifter"
		s.skills["farming"]["level"] = 3
		s.equipment = {"weapon": "", "outfit": "", "tool": ""}
		s.mood = 60.0
	a.relationships[b.id] = 0.0
	b.relationships[a.id] = 0.0
	var base := DaySystem.worker_output(a, farm)
	a.traits = ["hardworker"]
	var hard := DaySystem.worker_output(a, farm)
	a.traits = ["lazy"]
	var lazy := DaySystem.worker_output(a, farm)
	_check(hard > base and lazy < base, "трудяга работает лучше, лентяй хуже")
	a.traits = []
	a.profession = "agronomist"
	_check(is_equal_approx(DaySystem.worker_output(a, farm), base * ProfessionDefs.SPEC_BONUS), "агроном на ферме — специалист")
	a.profession = "drifter"
	GameState.assign(a.id, farm.id)
	GameState.assign(b.id, farm.id)
	a.relationships[b.id] = 80.0
	b.relationships[a.id] = 80.0
	var friends := DaySystem.worker_output(a, farm)
	a.relationships[b.id] = -80.0
	b.relationships[a.id] = -80.0
	var enemies := DaySystem.worker_output(a, farm)
	_check(friends > base and enemies < base, "друзья в смене помогают, враги мешают")
	a.traits = ["frugal"]
	var frugal := DaySystem.food_need(a)
	a.traits = ["glutton"]
	var glutton := DaySystem.food_need(a)
	_check(frugal < DaySystem.FOOD_PER_SURVIVOR and glutton > DaySystem.FOOD_PER_SURVIVOR, "экономный ест меньше, обжора больше")
	a.traits = ["curious"]
	_check(is_equal_approx(a.xp_multiplier(), 1.2), "любознательный учится быстрее")
	a.traits = []
	a.profession = "student"
	_check(a.xp_multiplier() > 1.0, "студент учится быстрее")
	var scout := SurvivorData.new()
	var plain := ExpeditionSystem.danger_of(scout, 2)
	scout.profession = "soldier"
	_check(ExpeditionSystem.danger_of(scout, 2) < plain, "бывшему военному в вылазках безопаснее")
	scout.profession = "drifter"
	scout.traits = ["nervous"]
	_check(ExpeditionSystem.danger_of(scout, 2) > plain, "нервному в вылазках опаснее")
	scout.traits = []
	scout.profession = "courier"
	_check(ExpeditionSystem.find_chance(scout, 2) > ExpeditionSystem.find_chance(SurvivorData.new(), 2), "курьер чаще находит вещи")
	for id in ProfessionDefs.RANDOM_POOL:
		_check(BioDefs.BEFORE.has(id) and ProfessionDefs.name_for(id, "f") != "", "профессия %s описана" % id)
	for id: String in TraitDefs.ids():
		_check(TraitDefs.name_for(id, "f") != "" and TraitDefs.get_desc(id) != "", "черта %s описана" % id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for _i in 30:
		var n := SurvivorFactory.create_random(rng)
		_check(n.bio.length() > 40 and not n.bio.contains("{") and not n.bio.contains("|"), "биография собрана: " + n.bio)
		var conflict := n.traits.size() == 2 and TraitDefs.conflicts(n.traits[0], n.traits[1])
		_check(not conflict, "у новичка нет противоречивых черт")


func _test_kitchen() -> void:
	GameState.new_game()
	GameState.resources["metal"] = 200
	_check(GameState.build_room("kitchen", 0, 3), "кухню можно построить")
	var kitchen := GameState.first_room_of_type("kitchen")
	var before: Dictionary = DaySystem.compute_economy()["delta"]
	_check(not DaySystem.compute_economy()["kitchen_fed"], "пустая кухня не кормит")
	var cook := GameState.survivors[1]
	GameState.assign(cook.id, kitchen.id)
	var eco := DaySystem.compute_economy()
	_check(int(eco["delta"]["food"]) > int(before["food"]), "повар экономит еду")
	_check(eco["kitchen_fed"] and int((eco["outputs"] as Dictionary).get(kitchen.id, 0)) > 0, "кухня кормит горячим")
	var plain_saving := DaySystem.kitchen_savings(kitchen)
	cook.profession = "cook"
	_check(DaySystem.kitchen_savings(kitchen) > plain_saving, "профессиональный повар экономит больше")
	_check(TimeSystem.place_for(cook, "eat") == kitchen, "есть ходят на кухню")


func _test_maintenance() -> void:
	GameState.new_game()
	var gen := GameState.first_room_of_type("generator")
	var viktor := GameState.survivors[1]
	GameState.assign(viktor.id, gen.id)
	viktor.traits = []
	var w_normal := MaintenanceSystem.daily_wear(gen, GameState.workers_of(gen.id), true)
	viktor.traits = ["clumsy"]
	var w_clumsy := MaintenanceSystem.daily_wear(gen, GameState.workers_of(gen.id), true)
	viktor.traits = ["handy"]
	var w_handy := MaintenanceSystem.daily_wear(gen, GameState.workers_of(gen.id), true)
	_check(w_clumsy > w_normal and w_handy < w_normal, "неуклюжий изнашивает технику, мастер бережёт")
	viktor.traits = ["hardworker"]
	var condition := gen.condition
	DaySystem.advance()
	_check(gen.condition < condition, "оборудование изнашивается за день")
	gen.condition = 1.0
	var lines: Array[Dictionary] = []
	var empty: Array[int] = []
	for _i in 30:
		if gen.broken:
			break
		MaintenanceSystem.tick(lines, empty)
	_check(gen.broken and not lines.is_empty(), "изношенная комната ломается, об этом сообщают")
	var eco := DaySystem.compute_economy()
	_check((eco["broken"] as Array).has(gen.id) and not (eco["outputs"] as Dictionary).has(gen.id), "сломанный генератор не работает")
	GameState.resources["metal"] = 0
	_check(MaintenanceSystem.repair_error(gen) != "" and not MaintenanceSystem.repair(gen), "без металла не починить")
	GameState.resources["metal"] = 100
	var cost := MaintenanceSystem.repair_cost(gen)
	_check(MaintenanceSystem.repair(gen) and not gen.broken and gen.condition >= MaintenanceSystem.REPAIRED_CONDITION,
		"ремонт возвращает комнату в строй")
	_check(GameState.get_resource("metal") == 100 - cost, "ремонт стоит металла")
	gen.condition = 50.0
	var service := MaintenanceSystem.repair_cost(gen)
	viktor.profession = "mechanic"
	_check(MaintenanceSystem.repair_cost(gen) < service, "с автомехаником ремонт дешевле")
	_check(not GameState.first_room_of_type("quarters").can_break(), "жилой отсек не ломается")


## Настроение Виктора после гибели человека: родного или чужого.
func _mood_after_loss(linked: bool) -> float:
	GameState.new_game()
	GameState.rng.seed = 99
	var viktor := GameState.survivors[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var found := FamilySystem.make_relative(viktor, rng)
	var relative: SurvivorData = found["survivor"]
	GameState.add_survivor(relative)
	if linked:
		FamilySystem.link(viktor, relative, found["rel"], false)
	viktor.relationships[relative.id] = 0.0
	relative.relationships[viktor.id] = 0.0
	relative.health = 1.0
	GameState.resources["food"] = 0
	DaySystem.advance()
	_check(GameState.get_survivor(relative.id) == null and viktor.family.is_empty(), "погибший удалён и из семьи")
	return viktor.mood


func _test_families() -> void:
	GameState.new_game()
	var viktor := GameState.survivors[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var seen := {}
	for _i in 40:
		var found := FamilySystem.make_relative(viktor, rng)
		if found.is_empty():
			continue
		var n: SurvivorData = found["survivor"]
		var rel := String(found["rel"])
		seen[rel] = true
		_check(n.last_name == SurvivorFactory.surname_for("Орлов", n.gender), "фамилия родственника: " + n.full_name())
		if rel == "parent":
			_check(n.age > viktor.age, "родитель старше")
		elif rel == "child":
			_check(n.age < viktor.age and n.age >= 16, "ребёнок младше, но взрослый")
		_check(n.bio.begins_with("Узнав, что"), "в биографии родственника есть история поиска")
	_check(seen.has("sibling") and seen.has("child") and seen.has("parent"), "находятся братья и сёстры, родители и дети")
	var found := FamilySystem.make_relative(viktor, rng)
	var relative: SurvivorData = found["survivor"]
	GameState.add_survivor(relative)
	FamilySystem.link(viktor, relative, found["rel"])
	_check(FamilySystem.relation(relative, viktor.id) == FamilySystem.inverse(found["rel"]), "родство записано в обе стороны")
	_check(viktor.get_relation(relative.id) > 30.0, "родные сразу близки")
	_check(FamilySystem.label(viktor, relative) != "", "видно, кем приходится родственник")
	_check(RelationshipSystem.compatibility(viktor, relative) > RelationshipSystem.compatibility(viktor, GameState.survivors[0]) - 0.5,
		"родство повышает совместимость")
	var with_family := _mood_after_loss(true)
	var stranger := _mood_after_loss(false)
	_check(with_family < stranger - 15.0, "гибель родного человека бьёт сильнее (%d против %d)" % [roundi(with_family), roundi(stranger)])

	GameState.new_game()
	var a := GameState.survivors[0]
	var b := GameState.survivors[1]
	a.relationships[b.id] = 95.0
	b.relationships[a.id] = 95.0
	GameState.rng.seed = 5
	var lines: Array[Dictionary] = []
	for _i in 200:
		FamilySystem.try_form_couples(lines, GameState.rng)
		if FamilySystem.has_partner(a):
			break
	_check(FamilySystem.relation(a, b.id) == "partner" and FamilySystem.relation(b, a.id) == "partner", "близкие друзья становятся парой")
	_check(not lines.is_empty() and lines[0].get("log", false), "новая пара попадает в летопись")


func _test_time() -> void:
	GameState.new_game()
	var anna := GameState.survivors[0]
	var farm := GameState.first_room_of_type("farm")
	GameState.assign(anna.id, farm.id)
	anna.traits = []
	_check(TimeSystem.activity(anna, 400.0) == "eat", "в 06:40 завтрак")
	_check(TimeSystem.activity(anna, 600.0) == "work", "в 10:00 работа")
	_check(TimeSystem.activity(anna, 750.0) == "eat", "в 12:30 обед")
	_check(TimeSystem.activity(anna, 1200.0) == "social", "вечером общение")
	_check(TimeSystem.activity(anna, 1320.0) == "sleep", "в 22:00 сон")
	_check(TimeSystem.place_for(anna, "work") == farm, "работать идут в свою комнату")
	_check(TimeSystem.place_for(anna, "sleep").type == "quarters", "спать идут в жилой отсек")
	anna.traits = ["lazy"]
	_check(TimeSystem.activity(anna, 480.0) == "idle", "лентяй приходит на смену позже")
	anna.traits = ["loner"]
	_check(TimeSystem.activity(anna, 1200.0) == "rest", "одиночка вечером отдыхает в стороне")
	anna.add_illness("cold", 3.0)
	_check(TimeSystem.activity(anna, 600.0) == "heal", "больной лечится, а не работает")
	_check(TimeSystem.clock_text(605.0) == "10:05", "часы показывают время")
	GameState.minute = 1300.0
	GameState.advance_clock(100.0)
	_check(GameState.minute == TimeSystem.NIGHT_START and GameState.is_night(), "часы останавливаются на отбое")
	DaySystem.advance()
	_check(GameState.minute == TimeSystem.DAY_START and not GameState.is_night(), "новый день начинается утром")


## Убежище, в котором возможны все события.
func _event_stage() -> void:
	GameState.new_game()
	GameState.rng.seed = 31
	GameState.day = 5
	for res in ResourceDefs.MATERIALS:
		GameState.resources[res] = 400
	GameState.build_room("kitchen", 0, 3)
	GameState.build_room("workshop", 1, 1)
	GameState.build_room("quarters", 2, 0)
	GameState.resources = {"food": 60, "water": 60, "power": 50, "medicine": 10, "metal": 100, "wood": 50, "concrete": 50}
	var anna := GameState.survivors[0]
	var viktor := GameState.survivors[1]
	var lazy := SurvivorFactory.create_random(GameState.rng)
	lazy.traits = ["lazy"]
	GameState.add_survivor(lazy)
	GameState.assign(lazy.id, GameState.first_room_of_type("farm").id)
	var nervous := SurvivorFactory.create_random(GameState.rng)
	nervous.traits = ["nervous"]
	GameState.add_survivor(nervous)
	lazy.relationships[nervous.id] = -70.0
	nervous.relationships[lazy.id] = -70.0
	anna.relationships[viktor.id] = 70.0
	viktor.relationships[anna.id] = 70.0
	GameState.storage = {"medkit": 2, "chocolate": 2}


func _state_valid() -> bool:
	for res in ResourceDefs.IDS:
		if GameState.get_resource(res) < 0 or GameState.get_resource(res) > GameState.get_cap(res):
			return false
	for s in GameState.survivors:
		if s.health < 0.0 or s.health > s.max_health or s.mood < 0.0 or s.mood > 100.0:
			return false
		for other_id: int in s.family:
			if GameState.get_survivor(other_id) == null:
				return false
	for room in GameState.rooms:
		if room.condition < 0.0 or room.condition > 100.0:
			return false
	return true


func _test_events() -> void:
	for id: String in EventDefs.ids():
		_event_stage()
		var ev := EventSystem.build(id, GameState.rng)
		_check(not ev.is_empty(), "событие «%s» возможно" % id)
		if ev.is_empty():
			continue
		_check(not String(ev["text"]).contains("{"), "текст события заполнен: %s" % ev["text"])
		for i in EventSystem.choices_of(ev).size():
			_event_stage()
			var fresh := EventSystem.build(id, GameState.rng)
			var view := EventSystem.choice_view(fresh, i)
			_check(view["enabled"], "вариант %d события «%s» доступен" % [i, id])
			var log_size := GameState.chronicle.size()
			var result := EventSystem.resolve(fresh, i, GameState.rng)
			_check(result["ok"] and String(result["text"]) != "" and not String(result["text"]).contains("{"),
				"итог %s/%d: %s" % [id, i, result["text"]])
			_check(GameState.chronicle.size() == log_size + 1, "итог «%s» записан в летопись" % id)
			_check(_state_valid(), "после «%s» состояние корректно" % id)

	_event_stage()
	GameState.resources["metal"] = 0
	var leak := EventSystem.build("pipe_leak", GameState.rng)
	_check(not EventSystem.choice_view(leak, 0)["enabled"], "без металла нельзя заварить трубу")
	_check(not EventSystem.resolve(leak, 0, GameState.rng)["ok"], "недоступный вариант не применяется")
	GameState.resources["medicine"] = 0
	var sick := EventSystem.build("sickness", GameState.rng)
	_check(not EventSystem.choice_view(sick, 0)["enabled"], "без медикаментов сразу не вылечить")
	var repair_choice: Dictionary = EventDefs.INFO["pipe_leak"]["choices"][1]
	var weak := SurvivorData.new()
	var strong := SurvivorData.new()
	strong.skills["engineering"]["level"] = 8
	_check(EventSystem.success_chance(repair_choice, strong) > EventSystem.success_chance(repair_choice, weak), "шанс успеха растёт с навыком")
	var mediate: Dictionary = EventDefs.INFO["argument"]["choices"][0]
	var kind := SurvivorData.new()
	kind.traits = ["kind"]
	_check(EventSystem.success_chance(mediate, kind) > EventSystem.success_chance(mediate, SurvivorData.new()), "добрые лучше мирят")

	_event_stage()
	var rel_ev := EventSystem.build("relative_arrival", GameState.rng)
	var host := GameState.get_survivor(int(rel_ev["ctx"]["a"]))
	var before := GameState.population()
	EventSystem.resolve(rel_ev, 0, GameState.rng)
	_check(GameState.population() == before + 1 and not host.family.is_empty(), "родственник поселился и связан с семьёй")

	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var scheduled := 0
	var in_range := true
	for _i in 200:
		var m := EventSystem.schedule(rng)
		if m >= 0:
			scheduled += 1
			in_range = in_range and m >= EventSystem.EARLIEST and m <= EventSystem.LATEST
	_check(scheduled > 80 and scheduled < 160 and in_range, "события случаются примерно в 60% дней и в дневное время")
	_event_stage()
	var kinds := {}
	for _i in 80:
		var ev := EventSystem.roll(GameState.rng)
		if not ev.is_empty():
			kinds[ev["id"]] = true
	_check(kinds.size() >= 8, "случайный выбор даёт разные события (%d)" % kinds.size())


func _test_chronicle() -> void:
	GameState.new_game()
	_check(GameState.chronicle.size() == 1, "новая игра открывает летопись")
	for i in GameState.CHRONICLE_MAX + 20:
		GameState.log_event("запись %d" % i)
	_check(GameState.chronicle.size() == GameState.CHRONICLE_MAX, "летопись не растёт бесконечно")
	_check(String(GameState.chronicle[-1]["text"]) == "запись %d" % (GameState.CHRONICLE_MAX + 19), "свежие записи остаются")
	GameState.new_game()
	GameState.resources["metal"] = 100
	GameState.build_room("kitchen", 0, 3)
	_check(String(GameState.chronicle[-1]["text"]).contains("кухня"), "постройка попадает в летопись")


func _test_migration_v2() -> void:
	var fixture := FileAccess.get_file_as_string("res://tests/fixtures/save_v2.json")
	_check(fixture != "", "есть образец сохранения версии 2")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(fixture)
	f.close()
	GameState.reset()
	_check(SaveManager.load_game(), "сохранение версии 2 загружается")
	_check(GameState.day == 3 and GameState.survivors.size() == 4, "день и жители на месте")
	var anna := GameState.survivors[0]
	_check(anna.has_illness("cold") and not anna.has_condition("sick"), "старая «болезнь» стала простудой")
	for res in ResourceDefs.ADDED_V3:
		_check(GameState.get_resource(res) == int(ResourceDefs.START[res]), "старая игра получила стартовый запас: %s" % res)
	var water := GameState.first_room_of_type("water")
	_check(water.broken and water.tier == 1 and water.decor == ["", ""], "комнаты перенесены с поломками, уровень 1")
	_check(GameState.expeditions.size() == 1 and GameState.expeditions[0]["location"] == "outskirts", "вылазка идёт в окрестности")
	_check(GameState.locations == ["outskirts"] and GameState.research_done.is_empty(), "места и исследования по умолчанию")
	_check(GameState.first_room_of_type("kitchen") != null and not GameState.chronicle.is_empty(), "кухня и летопись сохранились")
	var snapshot := JSON.stringify(GameState.to_dict())
	SaveManager.save_game()
	GameState.reset()
	_check(SaveManager.load_game() and JSON.stringify(GameState.to_dict()) == snapshot, "пересохранение в версии 3 без потерь")


func _test_resources_and_costs() -> void:
	GameState.new_game()
	for res in ResourceDefs.IDS:
		_check(GameState.get_resource(res) == int(ResourceDefs.START[res]), "стартовый запас: %s" % res)
		_check(PixelIcons.has_icon(ResourceDefs.INFO[res]["icon"]), "есть иконка ресурса %s" % res)
	for type in RoomDefs.BUILD_ORDER:
		_check(RoomPainter.WALLS.has(type), "нарисована комната %s" % type)
	GameState.resources["concrete"] = 0
	_check(GameState.build_error("generator", 2, 0).contains("бетон"), "без бетона генератор не построить")
	_check(GameState.build_error("pharmacy", 2, 0).contains("Фармакология"), "аптека закрыта до исследования")
	GameState.resources["concrete"] = 100
	GameState.resources["metal"] = 200
	_check(GameState.build_room("cement", 2, 0), "бетонный цех строится")
	var cement := GameState.first_room_of_type("cement")
	var viktor := GameState.survivors[1]
	GameState.assign(viktor.id, cement.id)
	var eco := DaySystem.compute_economy()
	var idle_water := -2 * GameState.survivors_in_shelter().size()
	_check(int(eco["delta"]["concrete"]) > 0 and int(eco["delta"]["water"]) == idle_water - 1, "цех делает бетон и тратит воду")
	GameState.build_room("workshop", 1, 1)
	var workshop := GameState.first_room_of_type("workshop")
	GameState.assign(viktor.id, workshop.id)
	_check(int(DaySystem.compute_economy()["delta"]["metal"]) > 0, "мастерская по умолчанию даёт металл")
	GameState.set_room_mode(workshop, "wood")
	var wood_eco := DaySystem.compute_economy()
	_check(int(wood_eco["delta"]["wood"]) > 0 and int(wood_eco["delta"]["metal"]) == 0, "в режиме «доски» мастерская даёт дерево")


func _test_upgrades() -> void:
	GameState.new_game()
	for res in ResourceDefs.MATERIALS:
		GameState.resources[res] = 300
	var quarters := GameState.first_room_of_type("quarters")
	var farm := GameState.first_room_of_type("farm")
	var anna := GameState.survivors[0]
	GameState.assign(anna.id, farm.id)
	var before := DaySystem.room_output(farm)
	_check(GameState.upgrade_room(farm) and farm.tier == 2, "ферма улучшается до II")
	_check(DaySystem.room_output(farm) > before and farm.title() == "Ферма II", "улучшенная ферма даёт больше")
	_check(GameState.upgrade_error(farm).contains("Армированные"), "третий уровень закрыт до исследования")
	var beds := GameState.bed_capacity()
	GameState.upgrade_room(quarters)
	_check(GameState.bed_capacity() == beds + 2, "улучшенный жилой отсек даёт больше мест")
	GameState.research_done.append("reinforced")
	_check(GameState.upgrade_room(farm) and farm.tier == 3, "после исследования доступен уровень III")
	_check(RoomDefs.slots_of("farm", 3) == 3 and GameState.room_has_free_slot(farm.id), "на III уровне лишнее рабочее место")
	var wear_low := MaintenanceSystem.daily_wear(farm, GameState.workers_of(farm.id), true)
	farm.tier = 1
	_check(MaintenanceSystem.daily_wear(farm, GameState.workers_of(farm.id), true) > wear_low, "улучшенное оборудование изнашивается медленнее")
	farm.tier = 3
	_check(GameState.upgrade_error(farm) == "Максимальный уровень", "выше III не улучшить")
	GameState.resources["concrete"] = 0
	_check(not GameState.upgrade_room(quarters), "без ресурсов не улучшить")


func _test_medicine() -> void:
	GameState.new_game()
	GameState.rng.seed = 13
	var anna := GameState.survivors[0]
	var viktor := GameState.survivors[1]
	anna.add_illness("flu", 6.0)
	_check(anna.is_ill() and anna.illness_work_factor() < 1.0, "больной работает хуже")
	var lines: Array[Dictionary] = []
	var none: Array[int] = []
	var health := anna.health
	MedicalSystem.daily(lines, none, false, GameState.rng)
	_check(anna.health < health and anna.illnesses[0]["days"] < 6.0, "без медпункта грипп вредит, но проходит сам")
	anna.illnesses.clear()
	anna.add_illness("infection", 5.0)
	MedicalSystem.daily(lines, none, false, GameState.rng)
	_check(is_equal_approx(float(anna.illnesses[0]["days"]), 5.0), "заражение без лекарств не проходит")
	for res in ResourceDefs.MATERIALS:
		GameState.resources[res] = 300
	GameState.build_room("medbay", 2, 0)
	var medbay := GameState.first_room_of_type("medbay")
	var medicine := GameState.get_resource("medicine")
	var weak := MedicalSystem.treatment_power()
	GameState.assign(anna.id, -1)
	GameState.assign(viktor.id, medbay.id)
	viktor.skills["medicine"]["level"] = 2
	var skill2 := MedicalSystem.treatment_power()
	viktor.skills["medicine"]["level"] = 8
	_check(MedicalSystem.treatment_power() > skill2 and skill2 > weak, "навык врача ускоряет лечение")
	viktor.illnesses.clear()
	MedicalSystem.daily(lines, none, false, GameState.rng)
	_check(GameState.get_resource("medicine") == medicine - 1 and float(anna.illnesses[0]["days"]) < 5.0, "в медпункте лечат за медикаменты")
	for _i in 6:
		MedicalSystem.daily(lines, none, false, GameState.rng)
	_check(not anna.has_illness("infection"), "с лечением заражение проходит")
	GameState.resources["medicine"] = 0
	anna.add_illness("radiation", 9.0)
	MedicalSystem.daily(lines, none, false, GameState.rng)
	_check(is_equal_approx(float(anna.illnesses[0]["days"]), 9.0), "без медикаментов лучевая болезнь не лечится")
	anna.illnesses.clear()
	anna.inventory = ["pills"]
	anna.add_illness("flu", 5.0)
	_check(InventorySystem.use_item(anna, 0) and not anna.is_ill(), "таблетки лечат болезнь")
	# Заразность
	for i in 4:
		GameState.add_survivor(SurvivorFactory.create_random(GameState.rng))
	for s in GameState.survivors:
		s.illnesses.clear()
	anna.add_illness("flu", 8.0)
	var spread := false
	for _i in 10:
		MedicalSystem._spread(GameState.survivors_in_shelter(), lines, GameState.rng)
		for s in GameState.survivors:
			if s != anna and s.is_ill():
				spread = true
	_check(spread, "грипп заразен")
	var shortage := false
	GameState.research_done.clear()
	for _i in 20:
		MedicalSystem.daily(lines, none, true, GameState.rng)
		for s in GameState.survivors:
			if s.has_illness("dysentery"):
				shortage = true
	_check(shortage, "при нехватке воды бывает дизентерия")


func _test_research() -> void:
	GameState.new_game()
	for res in ResourceDefs.IDS:
		GameState.resources[res] = 100
	_check(ResearchSystem.start_error("field_medicine").contains("Фармакология"), "у технологий есть зависимости")
	var water := GameState.get_resource("water")
	_check(ResearchSystem.start("hydroponics") and GameState.get_resource("water") == water - 10, "исследование стоит ресурсов")
	_check(ResearchSystem.start_error("filtration").contains("занята"), "одновременно идёт одно исследование")
	_check(is_equal_approx(ResearchSystem.points_per_day(), 0.0), "без лаборатории очков нет")
	GameState.build_room("lab", 2, 0)
	var lab := GameState.first_room_of_type("lab")
	var anna := GameState.survivors[0]
	GameState.assign(anna.id, lab.id)
	_check(ResearchSystem.points_per_day() > 0.0, "учёный в лаборатории даёт очки")
	var farm := GameState.first_room_of_type("farm")
	var viktor := GameState.survivors[1]
	GameState.assign(viktor.id, farm.id)
	var food := DaySystem.room_output(farm)
	var lines: Array[Dictionary] = []
	for _i in 30:
		ResearchSystem.daily(lines, [])
		if ResearchSystem.has("hydroponics"):
			break
	_check(ResearchSystem.has("hydroponics") and GameState.research_current == "", "исследование завершается со временем")
	_check(DaySystem.room_output(farm) > food, "гидропоника увеличивает урожай")
	_check(not lines.is_empty() and lines[-1].get("log", false), "открытие записано в летопись")
	ResearchSystem.start("pharmacology")
	ResearchSystem.cancel()
	_check(GameState.research_current == "" and not ResearchSystem.has("pharmacology"), "исследование можно отменить")
	for id in ResearchDefs.ORDER:
		for req: String in ResearchDefs.INFO[id]["requires"]:
			_check(ResearchDefs.exists(req), "зависимость %s существует" % req)


func _test_radio_and_locations() -> void:
	GameState.new_game()
	GameState.rng.seed = 17
	for res in ResourceDefs.IDS:
		GameState.resources[res] = 100
	_check(GameState.locations == ["outskirts"], "в начале известны только окрестности")
	_check(ExpeditionSystem.start_error(GameState.survivors[1], 2, "hospital").contains("не найдено"), "в неизвестное место не пойти")
	GameState.build_room("radio", 2, 0)
	var radio := GameState.first_room_of_type("radio")
	var anna := GameState.survivors[0]
	GameState.assign(anna.id, radio.id)
	_check(RadioSystem.signal_per_day() > 0.0, "радист ловит сигнал")
	var lines: Array[Dictionary] = []
	GameState.day = 30
	for _i in 120:
		RadioSystem.daily(lines, [], GameState.rng)
	_check(GameState.radio_heard.size() >= 5, "сюжетные передачи приходят по порядку (%d)" % GameState.radio_heard.size())
	_check(GameState.radio_heard[0] == "numbers" and GameState.locations.has("hospital") and GameState.locations.has("north_shelter"),
		"передачи открывают места для вылазок")
	_check(GameState.radio_pending == "military" and not GameState.locations.has("science_town"), "шифровку не прочесть без дешифровки")
	GameState.research_done.append("radio_decoding")
	RadioSystem.daily(lines, [], GameState.rng)
	_check(GameState.radio_heard.has("military") and GameState.locations.has("science_town"), "после дешифровки открывается научный городок")
	var story := 0
	for line in lines:
		if line["kind"] == "story":
			story += 1
	_check(story >= 5 and GameState.radio_log.size() >= 6, "передачи попадают в журнал и итоги дня")
	# Вылазка в больницу: лекарства, находка о Катастрофе и встреча
	GameState.day = 31
	var viktor := GameState.survivors[1]
	viktor.health = viktor.max_health
	GameState.resources["medicine"] = 20
	var medicine := GameState.get_resource("medicine")
	var people := GameState.population()
	_check(ExpeditionSystem.start(viktor.id, 2, "hospital"), "отправка в больницу")
	lines.clear()
	ExpeditionSystem.tick(lines)
	ExpeditionSystem.tick(lines)
	_check(GameState.get_resource("medicine") > medicine, "из больницы приносят медикаменты")
	_check(GameState.visited.has("hospital") and GameState.population() == people + 1, "первая вылазка — находка и новый житель")
	var clue := false
	for line in lines:
		clue = clue or (line["kind"] == "story" and String(line["text"]).contains("журнале"))
	_check(clue, "в больнице находят улику о Катастрофе")
	_check(ExpeditionSystem.supplies_for(2, "north_shelter").has("medicine"), "в «Северное» несут лекарства")
	GameState.research_done.append("scouting")
	_check(ExpeditionSystem.days_range("outskirts")[1] == 4, "картография удлиняет вылазки")


func _test_decor_and_crafting() -> void:
	GameState.new_game()
	for res in ResourceDefs.IDS:
		GameState.resources[res] = 100
	var quarters := GameState.first_room_of_type("quarters")
	_check(GameState.comfort() == 0, "без украшений уюта нет")
	var wood := GameState.get_resource("wood")
	_check(GameState.set_decor(quarters, 0, "painting") and GameState.get_resource("wood") == wood - 6, "картина ставится за дерево")
	_check(GameState.comfort() == 2 and quarters.decor[0] == "painting", "украшение даёт уют")
	_check(not GameState.set_decor(quarters, 1, "aquarium") and GameState.decor_error("aquarium").contains("Уют"), "аквариум закрыт до исследования")
	GameState.set_paint(quarters, "warm")
	_check(quarters.paint == "warm", "стены можно перекрасить")
	var anna := GameState.survivors[0]
	anna.mood = 50.0
	var people := GameState.survivors_in_shelter()
	var empty: Array[int] = []
	DaySystem._update_mood(anna, people, empty, false, false, 1)
	var with_decor := anna.mood
	GameState.set_decor(quarters, 0, "")
	anna.mood = 50.0
	DaySystem._update_mood(anna, people, empty, false, false, 1)
	_check(with_decor > anna.mood, "уют поднимает настроение")
	for id in DecorDefs.ORDER:
		_check(DecorDefs.INFO[id].has("cost") and int(DecorDefs.INFO[id]["comfort"]) > 0, "украшение %s описано" % id)
	_check(not GameState.craft("armor"), "без исследований ничего не изготовить")
	GameState.research_done.append_array(["toolmaking", "armor"])
	var metal := GameState.get_resource("metal")
	_check(GameState.craft("armor") and GameState.storage_count("armor") == 1 and GameState.get_resource("metal") == metal - 25, "бронежилет изготовлен")
	for item_id: String in ItemDefs.RECIPES:
		_check(ItemDefs.exists(item_id) and ResearchDefs.exists(String(ItemDefs.RECIPES[item_id]["research"])), "рецепт %s корректен" % item_id)


func _test_long_run() -> void:
	# 150 дней с бестолковым «игроком»: система не должна падать и выходить за границы.
	GameState.new_game()
	GameState.rng.seed = 12345
	for i in 150:
		if GameState.survivors.is_empty():
			break
		for room in GameState.rooms:
			for s in GameState.survivors_in_shelter():
				if s.room_id == -1 and GameState.room_has_free_slot(room.id):
					GameState.assign(s.id, room.id)
		if i % 7 == 3:
			for type in ["workshop", "quarters", "storage", "medbay", "farm"]:
				for level in ShelterLayout.LEVELS:
					for col in ShelterLayout.COLS:
						if GameState.build_error(type, level, col) == "" and GameState.rooms.size() < 4 + floori(i / 7.0):
							GameState.build_room(type, level, col)
		if i % 9 == 5 and GameState.survivors_in_shelter().size() > 2:
			ExpeditionSystem.start(GameState.survivors_in_shelter()[-1].id, 1 + i % 3)
		DaySystem.advance()
		for res in ResourceDefs.IDS:
			var v := GameState.get_resource(res)
			if v < 0 or v > GameState.get_cap(res):
				_check(false, "ресурс %s вне границ: %d" % [res, v])
		for s in GameState.survivors:
			if s.health < 0.0 or s.health > s.max_health or s.mood < 0.0 or s.mood > 100.0:
				_check(false, "показатели %s вне границ" % s.full_name())
			if s.inventory.size() > SurvivorData.MAX_INVENTORY:
				_check(false, "переполнен рюкзак")
	_check(GameState.population() <= maxi(GameState.bed_capacity(), 2), "жителей не больше спальных мест")
	_check(true, "долгий прогон завершён")


# --- Баланс -------------------------------------------------------------------

func _test_balance() -> void:
	# «Разумный игрок»: ставит людей туда, где ресурс кончится раньше всего,
	# и строит то, чего не хватает. Убежище должно жить и расти.
	for seed_value in [11, 2024, 777, 5, 42]:
		GameState.new_game()
		GameState.rng.seed = seed_value
		var shortages := 0
		for _day in 60:
			_bot_manage()
			var report := DaySystem.advance()
			_bot_answer(report["event"])
			for line: Dictionary in report["lines"]:
				if String(line["text"]).contains("не хватило"):
					shortages += 1
			if GameState.survivors.is_empty():
				break
		print("Баланс (сид %d): день %d, жителей %d, комнат %d, ресурсы %s" % [
			seed_value, GameState.day, GameState.population(), GameState.rooms.size(), str(GameState.resources)])
		_check(GameState.population() >= 3, "при разумной игре убежище растёт (сид %d)" % seed_value)
		_check(shortages == 0, "при разумной игре нет голода и жажды (сид %d)" % seed_value)


func _bot_manage() -> void:
	for room in GameState.rooms:
		if room.broken or (room.can_break() and room.condition < 45.0):
			MaintenanceSystem.repair(room)
	# Не хватает досок — мастерская пилит доски, иначе перерабатывает лом.
	var workshop := GameState.first_room_of_type("workshop")
	if workshop != null:
		var need_wood := GameState.get_resource("wood") < 25 and GameState.get_resource("metal") >= 40
		GameState.set_room_mode(workshop, "wood" if need_wood else "metal")
	var people := GameState.survivors_in_shelter()
	# Мастерская нужна, когда в ней есть кому работать.
	if GameState.first_room_of_type("workshop") == null and people.size() >= 3 and GameState.get_resource("metal") >= 70:
		_bot_build("workshop")
	# Мало металла — лучший разведчик идёт на поверхность.
	if GameState.get_resource("metal") < 20 and people.size() >= 3 and GameState.expeditions.is_empty():
		var scout: SurvivorData = null
		for s in people:
			if s.health >= 60.0 and (scout == null or s.effective_skill("scavenging") > scout.effective_skill("scavenging")):
				scout = s
		if scout != null:
			ExpeditionSystem.start(scout.id, 2)
	_bot_assign()
	if not GameState.has_free_bed():
		_bot_build("quarters")


## Отвечает на событие первым доступным вариантом.
func _bot_answer(ev: Dictionary) -> void:
	if ev.is_empty():
		return
	for i in EventSystem.choices_of(ev).size():
		if EventSystem.choice_view(ev, i)["enabled"]:
			EventSystem.resolve(ev, i, GameState.rng)
			return


func _bot_room_with_slot(type: String) -> RoomData:
	for room in GameState.rooms:
		if room.type == type and GameState.room_has_free_slot(room.id):
			return room
	return null


func _bot_build(type: String) -> bool:
	for level in ShelterLayout.LEVELS:
		for col in ShelterLayout.COLS:
			if GameState.build_error(type, level, col) == "":
				return GameState.build_room(type, level, col)
	return false


func _bot_assign() -> void:
	var free := GameState.survivors_in_shelter()
	for s in free:
		GameState.assign(s.id, -1)
	while not free.is_empty():
		var delta: Dictionary = DaySystem.compute_economy()["delta"]
		var need := ""
		var worst := INF
		for res in ["food", "water", "power", "metal"]:
			var change := int(delta[res])
			if change >= 1:
				continue
			if res == "metal" and GameState.get_resource("metal") >= 15:
				continue
			var days_left := float(GameState.get_resource(res)) / float(1 - change)
			if days_left < worst:
				worst = days_left
				need = res
		var room: RoomData = null
		if need != "":
			room = _bot_room_with_slot(PRODUCER[need])
			if room == null and _bot_build(PRODUCER[need]):
				room = _bot_room_with_slot(PRODUCER[need])
		if room == null:
			room = _bot_room_with_slot("workshop")
		if room == null:
			for type in ["farm", "water", "generator"]:
				room = _bot_room_with_slot(type)
				if room != null:
					break
		if room == null:
			return
		var skill: String = room.get_def()["skill"]
		free.sort_custom(func(a: SurvivorData, b: SurvivorData) -> bool:
			return a.effective_skill(skill) > b.effective_skill(skill))
		GameState.assign(free[0].id, room.id)
		free.remove_at(0)


# --- Сцены ----------------------------------------------------------------------

func _test_scenes() -> void:
	GameState.new_game()
	var menu: Node = (load("res://scenes/main_menu/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	_check(menu.get_child_count() > 0, "главное меню построено")
	menu.queue_free()
	await get_tree().process_frame

	GameState.new_game()
	GameState.storage_add("pistol")
	ExpeditionSystem.start(GameState.survivors[1].id, 2)
	var game: Node = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	_check(GameState.active, "игровая сцена активна")

	var first := GameState.survivors[0].id
	game.call("_open_survivors")
	await get_tree().process_frame
	for tab: Array in SurvivorProfilePanel.TABS:
		var panel := SurvivorProfilePanel.new(first, tab[0])
		game.call("_open", panel)
		await get_tree().process_frame
		_check(panel.is_inside_tree(), "раздел профиля «%s» открыт" % tab[1])
	for method in ["_open_build", "_open_storage", "_open_expeditions", "_open_pause"]:
		game.call(method)
		await get_tree().process_frame
	game.call("_on_room_tapped", GameState.first_room_of_type("farm").id)
	await get_tree().process_frame
	GameState.assign(first, GameState.first_room_of_type("farm").id)
	await get_tree().process_frame

	game.call("_start_build", "storage")
	game.call("_on_slot_tapped", 2, 0)
	_check(GameState.room_at(2, 0) != null, "постройка через интерфейс")
	game.call("_resolve_day")
	await get_tree().process_frame
	_check(GameState.day == 2, "смена дня через интерфейс")
	game.call("_go_back")
	await get_tree().process_frame
	game.queue_free()
	await get_tree().process_frame
	_check(not GameState.active, "после выхода сцена неактивна")
