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
	_check(GameState.build_room("storage", 2, 0), "постройка склада")
	_check(GameState.get_resource("metal") == metal - 40, "металл списан")
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

	# Повреждённый файл не должен ронять игру.
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ это не json")
	f.close()
	_check(not SaveManager.load_game(), "повреждённое сохранение отклонено")


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
	for seed_value in [11, 2024, 777]:
		GameState.new_game()
		GameState.rng.seed = seed_value
		var shortages := 0
		for _day in 60:
			_bot_assign()
			if not GameState.has_free_bed():
				_bot_build("quarters")
			var report := DaySystem.advance()
			for line: Dictionary in report["lines"]:
				if String(line["text"]).contains("не хватило"):
					shortages += 1
			if GameState.survivors.is_empty():
				break
		print("Баланс (сид %d): день %d, жителей %d, комнат %d, ресурсы %s" % [
			seed_value, GameState.day, GameState.population(), GameState.rooms.size(), str(GameState.resources)])
		_check(GameState.population() >= 3, "при разумной игре убежище растёт (сид %d)" % seed_value)
		_check(shortages == 0, "при разумной игре нет голода и жажды (сид %d)" % seed_value)


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
		for res in ["food", "water", "power"]:
			var change := int(delta[res])
			if change >= 1:
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
		if room == null and GameState.get_resource("metal") >= 110 and _bot_build("workshop"):
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
