class_name ExpeditionSystem
extends RefCounted
## Вылазки на поверхность. Выживший уходит на 1–3 дня с запасом еды и воды
## и возвращается с добычей, а иногда с ранениями, находками или новым жителем.
## Итог зависит от навыков, экипировки, характера и профессии.

const MIN_DAYS := 1
const MAX_DAYS := 3
const SUPPLY_PER_DAY := 2
const MIN_HEALTH := 40.0


static func supplies_for(days: int) -> Dictionary:
	return {"food": SUPPLY_PER_DAY * days, "water": SUPPLY_PER_DAY * days}


## Пустая строка — отправить можно, иначе причина отказа.
static func start_error(s: SurvivorData, days: int) -> String:
	if s == null:
		return "Выберите выжившего"
	if s.on_expedition:
		return "%s уже в экспедиции" % s.first_name
	if days < MIN_DAYS or days > MAX_DAYS:
		return "Неверная длительность"
	if s.health < MIN_HEALTH:
		return "%s: слишком мало здоровья" % s.first_name
	var supplies := supplies_for(days)
	for res: String in supplies:
		if not GameState.can_afford(res, int(supplies[res])):
			return "Не хватает припасов: %s" % ResourceDefs.name_of(res).to_lower()
	return ""


## Вероятность ранения за вылазку.
static func danger_of(s: SurvivorData, days: int) -> float:
	var danger := 0.2 + 0.12 * days - s.effective_skill("combat") * 0.04
	if s.profession == "soldier":
		danger *= 0.6
	if s.has_trait("nervous"):
		danger *= 1.25
	return clampf(danger, 0.05, 0.8)


## Вероятность принести полезную вещь.
static func find_chance(s: SurvivorData, days: int) -> float:
	var chance := 0.25 + 0.15 * days + s.effective_skill("scavenging") * 0.02
	if s.profession == "courier":
		chance += 0.2
	return clampf(chance, 0.0, 0.95)


static func start(survivor_id: int, days: int) -> bool:
	var s := GameState.get_survivor(survivor_id)
	if start_error(s, days) != "":
		return false
	var supplies := supplies_for(days)
	for res: String in supplies:
		GameState.resources[res] = GameState.get_resource(res) - int(supplies[res])
	s.room_id = -1
	s.on_expedition = true
	GameState.expeditions.append({"survivor_id": s.id, "days_left": days, "total_days": days})
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
			_resolve(s, int(e["total_days"]), lines)


static func _resolve(s: SurvivorData, days: int, lines: Array[Dictionary]) -> void:
	var rng := GameState.rng
	s.on_expedition = false
	var mult := 1.0 + s.effective_skill("scavenging") * 0.08
	if s.has_trait("brave"):
		mult *= 1.2

	var loot := {"metal": 0, "food": 0, "water": 0}
	for _day in days:
		loot["metal"] += roundi(rng.randi_range(8, 14) * mult)
		loot["food"] += roundi(rng.randi_range(2, 5) * mult)
		loot["water"] += roundi(rng.randi_range(1, 4) * mult)
	if s.profession == "hunter":
		loot["food"] = roundi(loot["food"] * 1.6)
	var parts: PackedStringArray = []
	for res: String in loot:
		var cap := GameState.get_cap(res)
		GameState.resources[res] = mini(GameState.get_resource(res) + int(loot[res]), cap)
		parts.append("%s +%d" % [ResourceDefs.name_of(res).to_lower(), int(loot[res])])
	lines.append({"text": "%s возвращается из экспедиции: %s." % [s.first_name, ", ".join(parts)], "kind": "good", "log": true})

	if rng.randf() < find_chance(s, days):
		var item_id: String = ItemDefs.LOOT_TABLE[rng.randi() % ItemDefs.LOOT_TABLE.size()]
		GameState.storage[item_id] = GameState.storage_count(item_id) + 1
		lines.append({"text": "Находка отправлена на склад: %s." % ItemDefs.name_of(item_id).to_lower(), "kind": "good"})

	if rng.randf() < danger_of(s, days):
		var damage := float(rng.randi_range(10, 25))
		if s.has_trait("tough"):
			damage *= 0.5
		s.health = maxf(s.health - damage, 5.0)
		s.set_condition("wounded", true)
		s.change_mood(-12.0 if s.has_trait("nervous") else -8.0)
		lines.append({"text": "%s %s на поверхности (−%d здоровья)." % [s.first_name, s.by_gender("ранен", "ранена"), int(damage)],
			"kind": "bad", "log": true})
	else:
		s.change_mood(5.0)

	if s.add_skill_xp("scavenging", 12 * days):
		lines.append({"text": "%s: навык «Разведка» вырос до %d." % [s.first_name, s.skill_level("scavenging")], "kind": "good"})
	if s.add_skill_xp("combat", 6 * days):
		lines.append({"text": "%s: навык «Бой» вырос до %d." % [s.first_name, s.skill_level("combat")], "kind": "good"})

	if GameState.has_free_bed() and rng.randf() < 0.12 * days:
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
