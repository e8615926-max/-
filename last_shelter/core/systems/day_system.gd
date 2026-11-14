class_name DaySystem
extends RefCounted
## Правила смены дня: производство, потребление, состояние жителей,
## отношения, экспедиции и случайные события.

const FOOD_PER_SURVIVOR := 2
const WATER_PER_SURVIVOR := 2
const ARRIVAL_CHANCE := 0.15


# --- Экономика ------------------------------------------------------------

static func food_need(s: SurvivorData) -> int:
	return FOOD_PER_SURVIVOR - (1 if s.has_trait("frugal") else 0)


static func worker_output(s: SurvivorData, def: Dictionary) -> float:
	var value := float(def["base"]) + s.effective_skill(def["skill"])
	if s.has_trait("hardworker"):
		value *= 1.25
	if s.mood < 30.0:
		value *= 0.7
	if s.health < s.max_health * 0.3:
		value *= 0.7
	return value


## Сколько комната произведёт за день (если есть энергия).
static func room_output(room: RoomData) -> int:
	var def := room.get_def()
	if def["produces"] == "":
		return 0
	var total := float(def["passive"])
	for s in GameState.workers_of(room.id):
		total += worker_output(s, def)
	return roundi(total)


## Прогноз на следующий день без изменения состояния.
## Возвращает {"delta": {ресурс: изменение}, "unpowered": [id комнат], "outputs": {id: выработка}}.
static func compute_economy() -> Dictionary:
	var delta := {"food": 0, "water": 0, "metal": 0, "power": 0}
	var unpowered: Array[int] = []
	var outputs := {}

	# Сначала генераторы пополняют запас, затем комнаты по очереди забирают энергию.
	var power_pool := GameState.get_resource("power")
	for room in GameState.rooms:
		if room.type == "generator":
			var out := room_output(room)
			outputs[room.id] = out
			power_pool += out
	for room in GameState.rooms:
		if room.type == "generator":
			continue
		var def := room.get_def()
		var need := int(def["power"])
		if need > power_pool:
			unpowered.append(room.id)
			continue
		power_pool -= need
		if def["produces"] != "":
			var out := room_output(room)
			outputs[room.id] = out
			delta[def["produces"]] += out
	delta["power"] = power_pool - GameState.get_resource("power")

	for s in GameState.survivors_in_shelter():
		delta["food"] -= food_need(s)
		delta["water"] -= WATER_PER_SURVIVOR
	return {"delta": delta, "unpowered": unpowered, "outputs": outputs}


# --- Смена дня ------------------------------------------------------------

## Завершает текущий день. Возвращает отчёт:
## {"day": номер прошедшего дня, "lines": [{"text", "kind"}], "delta": {ресурс: изменение}, "game_over": bool}
static func advance() -> Dictionary:
	var lines: Array[Dictionary] = []
	var finished_day := GameState.day
	var before := GameState.resources.duplicate()
	var eco := compute_economy()
	var delta: Dictionary = eco["delta"]
	var unpowered: Array[int] = eco["unpowered"]

	# 1. Ресурсы.
	var hungry := false
	var thirsty := false
	for res in ResourceDefs.IDS:
		var value := GameState.get_resource(res) + int(delta[res])
		if value < 0:
			hungry = hungry or res == "food"
			thirsty = thirsty or res == "water"
			value = 0
		GameState.resources[res] = mini(value, GameState.get_cap(res))
	if hungry:
		lines.append({"text": "Еды не хватило. Жители голодают.", "kind": "bad"})
	if thirsty:
		lines.append({"text": "Воды не хватило. Жители страдают от жажды.", "kind": "bad"})
	for room_id in unpowered:
		lines.append({"text": "%s: нет энергии, комната не работала." % GameState.get_room(room_id).display_name(), "kind": "bad"})

	# 2. Опыт за работу и лечение в медпункте.
	var heal := 0.0
	for room in GameState.rooms:
		if unpowered.has(room.id):
			continue
		var def := room.get_def()
		var workers := GameState.workers_of(room.id)
		if room.type == "medbay":
			heal += 6.0
			for s in workers:
				heal += s.effective_skill("medicine") * 2.0
		if def["skill"] != "":
			for s in workers:
				if s.add_xp(def["skill"], 10):
					lines.append({"text": "%s: навык «%s» вырос до %d." % [
						s.first_name, SkillDefs.name_of(def["skill"]), s.skill_level(def["skill"])], "kind": "good"})

	# 3. Здоровье и настроение тех, кто в убежище.
	var people := GameState.survivors_in_shelter()
	var crowded := GameState.population() > GameState.bed_capacity()
	for s in people:
		s.set_condition("hungry", hungry)
		s.set_condition("thirsty", thirsty)
		if hungry:
			s.change_health(-12.0)
			s.change_mood(-10.0)
		if thirsty:
			s.change_health(-15.0)
			s.change_mood(-10.0)
		if not hungry and not thirsty:
			s.change_health(3.0)
		s.change_health(heal)
		if s.has_condition("wounded") and s.health >= s.max_health * 0.6:
			s.set_condition("wounded", false)
			lines.append({"text": "%s %s от ран." % [s.first_name, s.by_gender("оправился", "оправилась")], "kind": "good"})

		# Настроение медленно стремится к спокойному уровню.
		s.change_mood((60.0 - s.mood) * 0.1)
		if s.has_trait("optimist"):
			s.change_mood(3.0)
		if not unpowered.is_empty():
			s.change_mood(-3.0)
		if crowded:
			s.change_mood(-4.0)
		var friends := RelationshipSystem.count_at_level(s, people, RelationshipSystem.FRIEND_LEVEL)
		var enemies := RelationshipSystem.count_at_level(s, people, RelationshipSystem.ENEMY_LEVEL)
		s.change_mood(minf(friends * 2.0, 6.0) - enemies * 3.0)
	if crowded:
		lines.append({"text": "В убежище тесно: не хватает спальных мест.", "kind": "bad"})

	# 4. Отношения и экспедиции.
	RelationshipSystem.daily_update(lines)
	ExpeditionSystem.tick(lines)

	# 5. Потери.
	var dead: Array[SurvivorData] = []
	for s in GameState.survivors:
		if not s.is_alive():
			dead.append(s)
	for s in dead:
		lines.append({"text": "%s не %s этот день." % [s.full_name(), s.by_gender("пережил", "пережила")], "kind": "bad"})
		for other in GameState.survivors:
			if other.id != s.id:
				other.change_mood(-10.0 - maxf(other.get_relation(s.id), 0.0) * 0.2)
		GameState.remove_survivor(s.id)

	# 6. Случайные гости.
	if finished_day >= 2 and not GameState.survivors.is_empty() and GameState.has_free_bed() \
			and GameState.rng.randf() < ARRIVAL_CHANCE:
		var newcomer := SurvivorFactory.create_random(GameState.rng)
		GameState.add_survivor(newcomer)
		lines.append({"text": "В убежище новый житель: %s (%s)." % [
			newcomer.full_name(), newcomer.background.to_lower()], "kind": "good"})

	if lines.is_empty():
		lines.append({"text": "День прошёл спокойно.", "kind": "info"})

	GameState.day += 1
	var actual := {}
	for res in ResourceDefs.IDS:
		actual[res] = GameState.get_resource(res) - int(before[res])
	GameState.emit_all()
	return {
		"day": finished_day,
		"lines": lines,
		"delta": actual,
		"game_over": GameState.survivors.is_empty(),
	}
