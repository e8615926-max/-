class_name ExpeditionSystem
extends RefCounted
## Вылазки на поверхность. Выживший уходит на 1–3 дня с запасом еды и воды
## и возвращается с добычей, а иногда с ранениями, находками или новым жителем.
## Итог зависит от навыков, экипировки, характера и профессии.

const MIN_DAYS := 1
const MAX_DAYS := 3
const SUPPLY_PER_DAY := 2
const MIN_HEALTH := 40.0


static func supplies_for(days: int, location: String = "outskirts") -> Dictionary:
	var supplies := {"food": SUPPLY_PER_DAY * days, "water": SUPPLY_PER_DAY * days}
	var extra: Dictionary = LocationDefs.INFO[location].get("supplies", {})
	for res: String in extra:
		supplies[res] = int(supplies.get(res, 0)) + int(extra[res])
	return supplies


## Сколько дней можно провести в этом месте: [мин, макс].
static func days_range(location: String) -> Array[int]:
	var range_days: Array = LocationDefs.INFO[location]["days"]
	return [int(range_days[0]), int(range_days[1]) + ResearchSystem.extra_expedition_days()]


## Пустая строка — отправить можно, иначе причина отказа.
static func start_error(s: SurvivorData, days: int, location: String = "outskirts") -> String:
	if s == null:
		return "Выберите выжившего"
	if s.on_expedition:
		return "%s уже в экспедиции" % s.first_name
	if not GameState.locations.has(location):
		return "Это место ещё не найдено"
	var range_days := days_range(location)
	if days < range_days[0] or days > range_days[1]:
		return "Неверная длительность"
	if s.health < MIN_HEALTH:
		return "%s: слишком мало здоровья" % s.first_name
	var missing := GameState.missing_resource(supplies_for(days, location))
	if missing != "":
		return "Не хватает припасов: %s" % ResourceDefs.name_of(missing).to_lower()
	return ""


## Вероятность ранения за вылазку.
static func danger_of(s: SurvivorData, days: int, location: String = "outskirts") -> float:
	var danger := (0.2 + 0.12 * days - s.effective_skill("combat") * 0.04) * float(LocationDefs.INFO[location]["danger"])
	if s.profession == "soldier":
		danger *= 0.6
	if s.has_trait("nervous"):
		danger *= 1.25
	return clampf(danger, 0.05, 0.85)


## Вероятность принести полезную вещь.
static func find_chance(s: SurvivorData, days: int) -> float:
	var chance := 0.25 + 0.15 * days + s.effective_skill("scavenging") * 0.02
	if s.profession == "courier":
		chance += 0.2
	return clampf(chance, 0.0, 0.95)


static func start(survivor_id: int, days: int, location: String = "outskirts") -> bool:
	var s := GameState.get_survivor(survivor_id)
	if start_error(s, days, location) != "":
		return false
	GameState.pay(supplies_for(days, location))
	s.room_id = -1
	s.on_expedition = true
	GameState.expeditions.append({"survivor_id": s.id, "days_left": days, "total_days": days, "location": location})
	GameState.resources_changed.emit()
	GameState.survivors_changed.emit()
	GameState.expeditions_changed.emit()
	return true


static func find(survivor_id: int) -> Dictionary:
	for e in GameState.expeditions:
		if int(e["survivor_id"]) == survivor_id:
			return e
	return {}


## Продвигает все экспедиции на один день; вернувшиеся приносят добычу.
static func tick(lines: Array[Dictionary]) -> void:
	for i in range(GameState.expeditions.size() - 1, -1, -1):
		var e: Dictionary = GameState.expeditions[i]
		e["days_left"] = int(e["days_left"]) - 1
		if int(e["days_left"]) > 0:
			continue
		GameState.expeditions.remove_at(i)
		var s := GameState.get_survivor(int(e["survivor_id"]))
		if s != null:
			_resolve(s, int(e["total_days"]), String(e.get("location", "outskirts")), lines)


static func _resolve(s: SurvivorData, days: int, location: String, lines: Array[Dictionary]) -> void:
	var rng := GameState.rng
	var place: Dictionary = LocationDefs.INFO[location]
	s.on_expedition = false
	var mult := (1.0 + s.effective_skill("scavenging") * 0.08) * ResearchSystem.loot_mult()
	if s.has_trait("brave"):
		mult *= 1.2

	var loot_table: Dictionary = place["loot"]
	var loot := {}
	for res: String in loot_table:
		var amounts: Array = loot_table[res]
		var total := 0
		for _day in days:
			total += roundi(rng.randi_range(int(amounts[0]), int(amounts[1])) * mult)
		if res == "food" and s.profession == "hunter":
			total = roundi(total * 1.6)
		loot[res] = total
	var parts: PackedStringArray = []
	for res in ResourceDefs.IDS:
		if loot.has(res):
			GameState.resources[res] = mini(GameState.get_resource(res) + int(loot[res]), GameState.get_cap(res))
			parts.append("%s +%d" % [ResourceDefs.name_of(res).to_lower(), int(loot[res])])
	lines.append({"text": "%s возвращается (%s): %s." % [s.first_name, LocationDefs.name_of(location), ", ".join(parts)],
		"kind": "good", "log": true})

	var items: Array = place["items"]
	if rng.randf() < find_chance(s, days):
		var item_id: String = items[rng.randi() % items.size()]
		GameState.storage[item_id] = GameState.storage_count(item_id) + 1
		lines.append({"text": "Находка отправлена на склад: %s." % ItemDefs.name_of(item_id).to_lower(), "kind": "good"})

	if place.has("research"):
		var points := rng.randi_range(int(place["research"][0]), int(place["research"][1]))
		if GameState.research_current != "":
			lines.append({"text": "Записи из лаборатории продвинули исследование (+%d очков)." % points, "kind": "good"})
			ResearchSystem.add_points(points, lines)

	if not GameState.visited.has(location):
		GameState.visited.append(location)
		if place.has("first_visit"):
			lines.append({"text": "%s: %s" % [LocationDefs.name_of(location), place["first_visit"]], "kind": "story", "log": true})

	if rng.randf() < danger_of(s, days, location):
		var damage := float(rng.randi_range(10, 25))
		if s.has_trait("tough"):
			damage *= 0.5
		s.health = maxf(s.health - damage, 5.0)
		s.set_condition("wounded", true)
		s.change_mood(-12.0 if s.has_trait("nervous") else -8.0)
		lines.append({"text": "%s %s на поверхности (−%d здоровья)." % [s.first_name, s.by_gender("ранен", "ранена"), int(damage)],
			"kind": "bad", "log": true})
		# Грязная рана без обработки может воспалиться.
		if rng.randf() < 0.35:
			MedicalSystem.infect(s, "infection", rng, lines, "рана воспалилась")
	else:
		s.change_mood(5.0)
	if place.has("illness") and rng.randf() < float(place["illness"]["chance"]):
		MedicalSystem.infect(s, String(place["illness"]["id"]), rng, lines, LocationDefs.name_of(location))

	if s.add_skill_xp("scavenging", 12 * days):
		lines.append({"text": "%s: навык «Разведка» вырос до %d." % [s.first_name, s.skill_level("scavenging")], "kind": "good"})
	if s.add_skill_xp("combat", 6 * days):
		lines.append({"text": "%s: навык «Бой» вырос до %d." % [s.first_name, s.skill_level("combat")], "kind": "good"})

	# Первая встреча в месте, о котором говорили по радио, — наверняка; потом по случаю.
	var first_meeting := location != "outskirts" and not GameState.visited.has(location + ":met")
	var chance := float(place["survivor"]) * days
	if GameState.has_free_bed() and (first_meeting or rng.randf() < chance):
		if first_meeting:
			GameState.visited.append(location + ":met")
		_bring_newcomer(s, rng, lines)


## На поверхности иногда находятся люди, а порой — родные.
static func _bring_newcomer(s: SurvivorData, rng: RandomNumberGenerator, lines: Array[Dictionary]) -> void:
	if rng.randf() < 0.35:
		var found := FamilySystem.make_relative(s, rng)
		if not found.is_empty():
			var relative: SurvivorData = found["survivor"]
			GameState.add_survivor(relative)
			FamilySystem.link(s, relative, found["rel"])
			lines.append({"text": "%s %s на поверхности родного человека: %s — %s." % [
				s.first_name, s.by_gender("встретил", "встретила"), FamilySystem.label(s, relative).to_lower(),
				relative.full_name()], "kind": "good", "log": true})
			return
	var newcomer := SurvivorFactory.create_random(rng)
	GameState.add_survivor(newcomer)
	newcomer.change_relation(s.id, 15.0)
	lines.append({"text": "%s %s в убежище нового жителя: %s." % [s.first_name, s.by_gender("привёл", "привела"), newcomer.full_name()],
		"kind": "good", "log": true})
