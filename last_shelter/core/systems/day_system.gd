class_name DaySystem
extends RefCounted
## Правила смены дня: производство и потребление, самочувствие жителей,
## отношения и семьи, износ оборудования, экспедиции и события.

const FOOD_PER_SURVIVOR := 2
const WATER_PER_SURVIVOR := 2
const ARRIVAL_CHANCE := 0.08
## Кухня экономит не больше этой доли общего расхода еды.
const KITCHEN_MAX_SHARE := 0.4


# --- Экономика ------------------------------------------------------------

static func food_need(s: SurvivorData) -> int:
	var need := FOOD_PER_SURVIVOR
	if s.has_trait("frugal"):
		need -= 1
	if s.has_trait("glutton"):
		need += 1
	return need


static func is_specialist(s: SurvivorData, room: RoomData) -> bool:
	return ProfessionDefs.room_of(s.profession) == room.type


## Общий множитель работы: характер, специализация, самочувствие и коллеги.
static func work_factor(s: SurvivorData, room: RoomData) -> float:
	var factor := 1.0
	if s.has_trait("hardworker"):
		factor *= 1.25
	if s.has_trait("lazy"):
		factor *= 0.8
	if is_specialist(s, room):
		factor *= ProfessionDefs.SPEC_BONUS
	if s.mood < 30.0:
		factor *= 0.7
	if s.health < s.max_health * 0.3:
		factor *= 0.7
	if s.has_condition("sick"):
		factor *= 0.7
	return factor * RelationshipSystem.teamwork_factor(s, room.id)


static func worker_output(s: SurvivorData, room: RoomData) -> float:
	var def := room.get_def()
	return (float(def["base"]) + s.effective_skill(def["skill"])) * work_factor(s, room)


## Сколько комната произведёт за день (если есть энергия и она исправна).
static func room_output(room: RoomData) -> int:
	var def := room.get_def()
	if def["produces"] == "":
		return 0
	var total := float(def["passive"])
	for s in GameState.workers_of(room.id):
		total += worker_output(s, room)
	return roundi(total)


## Сколько еды за день сберегают повара этой кухни (без общего ограничения).
static func kitchen_savings(room: RoomData) -> float:
	var total := 0.0
	for s in GameState.workers_of(room.id):
		total += (1.0 + s.effective_skill("farming") * 0.35) * work_factor(s, room)
	return total


## Сколько здоровья в день восстанавливает медпункт.
static func medbay_heal(room: RoomData) -> float:
	var heal := 6.0
	for s in GameState.workers_of(room.id):
		heal += s.effective_skill("medicine") * 2.0 * work_factor(s, room)
	return heal


## Прогноз на следующий день без изменения состояния. Возвращает
## {"delta": {ресурс: изменение}, "unpowered": [id], "broken": [id], "outputs": {id: выработка},
##  "heal": лечение, "kitchen_fed": кормит ли кухня горячим}.
static func compute_economy() -> Dictionary:
	var delta := {"food": 0, "water": 0, "metal": 0, "power": 0}
	var unpowered: Array[int] = []
	var broken: Array[int] = []
	var outputs := {}
	var heal := 0.0
	var kitchen_raw := 0.0

	# Сначала генераторы пополняют запас, затем комнаты по очереди забирают энергию.
	var power_pool := GameState.get_resource("power")
	for room in GameState.rooms:
		if room.type != "generator":
			continue
		if room.broken:
			broken.append(room.id)
			continue
		var out := room_output(room)
		outputs[room.id] = out
		power_pool += out
	for room in GameState.rooms:
		if room.type == "generator":
			continue
		if room.broken:
			broken.append(room.id)
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
		elif room.type == "medbay":
			heal += medbay_heal(room)
		elif room.type == "kitchen":
			var saved := kitchen_savings(room)
			outputs[room.id] = roundi(saved)
			kitchen_raw += saved
	delta["power"] = power_pool - GameState.get_resource("power")

	var consumption := 0
	for s in GameState.survivors_in_shelter():
		consumption += food_need(s)
		delta["water"] -= WATER_PER_SURVIVOR
	var saved_total := mini(roundi(kitchen_raw), floori(consumption * KITCHEN_MAX_SHARE))
	delta["food"] -= consumption - saved_total
	return {"delta": delta, "unpowered": unpowered, "broken": broken, "outputs": outputs,
		"heal": heal, "kitchen_fed": kitchen_raw > 0.0}


# --- Смена дня ------------------------------------------------------------

## Завершает текущий день. Возвращает отчёт:
## {"day": номер прошедшего дня, "lines": [{"text", "kind", "log"?}], "delta": {ресурс: изменение},
##  "game_over": bool, "event": событие, которое не успело случиться днём, или {}}
static func advance() -> Dictionary:
	var lines: Array[Dictionary] = []
	var rng := GameState.rng
	var finished_day := GameState.day
	var before := GameState.resources.duplicate()
	var eco := compute_economy()
	var delta: Dictionary = eco["delta"]
	var unpowered: Array[int] = eco["unpowered"]
	var broken: Array[int] = eco["broken"]
	var heal := float(eco["heal"])
	var kitchen_fed := bool(eco["kitchen_fed"])

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
		lines.append({"text": "Еды не хватило. Жители голодают.", "kind": "bad", "log": true})
	if thirsty:
		lines.append({"text": "Воды не хватило. Жители страдают от жажды.", "kind": "bad", "log": true})
	for room_id in unpowered:
		lines.append({"text": "%s: нет энергии, комната не работала." % GameState.get_room(room_id).display_name(), "kind": "bad"})
	for room_id in broken:
		lines.append({"text": "%s: сломано, отсек простаивает." % GameState.get_room(room_id).display_name(), "kind": "bad"})

	# 2. Опыт за работу.
	for room in GameState.rooms:
		if unpowered.has(room.id) or room.broken:
			continue
		var skill: String = room.get_def()["skill"]
		if skill == "":
			continue
		for s in GameState.workers_of(room.id):
			if s.add_skill_xp(skill, 10):
				lines.append({"text": "%s: навык «%s» вырос до %d." % [
					s.first_name, SkillDefs.name_of(skill), s.skill_level(skill)], "kind": "good"})

	# 3. Здоровье и настроение тех, кто в убежище.
	var people := GameState.survivors_in_shelter()
	var crowded := GameState.population() > GameState.bed_capacity()
	for s in people:
		var damage_mult := 0.5 if s.has_trait("tough") else 1.0
		s.set_condition("hungry", hungry)
		s.set_condition("thirsty", thirsty)
		if hungry:
			s.change_health(-12.0 * damage_mult)
			s.change_mood(-10.0)
		if thirsty:
			s.change_health(-15.0 * damage_mult)
			s.change_mood(-10.0)
		if not hungry and not thirsty:
			s.change_health(3.0)
		s.change_health(heal)
		_update_sickness(s, heal > 0.0, lines, rng)
		if s.has_condition("wounded") and s.health >= s.max_health * 0.6:
			s.set_condition("wounded", false)
			lines.append({"text": "%s %s от ран." % [s.first_name, s.by_gender("оправился", "оправилась")], "kind": "good"})
		_update_mood(s, people, unpowered, crowded, kitchen_fed, finished_day)
	if crowded:
		lines.append({"text": "В убежище тесно: не хватает спальных мест.", "kind": "bad"})

	# 4. Отношения, пары и экспедиции.
	RelationshipSystem.daily_update(lines)
	ExpeditionSystem.tick(lines)

	# 5. Износ оборудования.
	MaintenanceSystem.tick(lines, unpowered)

	# 6. Потери.
	var dead: Array[SurvivorData] = []
	for s in GameState.survivors:
		if not s.is_alive():
			dead.append(s)
	for s in dead:
		lines.append({"text": "%s не %s этот день." % [s.full_name(), s.by_gender("пережил", "пережила")],
			"kind": "bad", "log": true})
		for other in GameState.survivors:
			if other.id == s.id:
				continue
			var loss := 10.0 + maxf(other.get_relation(s.id), 0.0) * 0.2
			if FamilySystem.is_family(other, s):
				loss += 25.0
			other.change_mood(-loss)
		GameState.remove_survivor(s.id)

	# 7. Случайные гости.
	if finished_day >= 2 and not GameState.survivors.is_empty() and GameState.has_free_bed() \
			and rng.randf() < ARRIVAL_CHANCE:
		var newcomer := SurvivorFactory.create_random(rng)
		GameState.add_survivor(newcomer)
		lines.append({"text": "В убежище новый житель: %s (%s)." % [
			newcomer.full_name(), newcomer.profession_name().to_lower()], "kind": "good", "log": true})

	# 8. Событие, до которого не дошли днём, случается утром.
	var pending := {}
	if GameState.event_minute >= 0 and not GameState.survivors.is_empty():
		pending = EventSystem.roll(rng)

	if lines.is_empty():
		lines.append({"text": "День прошёл спокойно.", "kind": "info"})
	for line in lines:
		if line.get("log", false):
			GameState.log_event(line["text"], line["kind"])

	GameState.day += 1
	GameState.minute = TimeSystem.DAY_START
	GameState.event_minute = EventSystem.schedule(rng)
	var actual := {}
	for res in ResourceDefs.IDS:
		actual[res] = GameState.get_resource(res) - int(before[res])
	GameState.emit_all()
	return {
		"day": finished_day,
		"lines": lines,
		"delta": actual,
		"game_over": GameState.survivors.is_empty(),
		"event": pending,
	}


## Болезнь отнимает силы, но проходит сама; медпункт ускоряет выздоровление.
static func _update_sickness(s: SurvivorData, medbay: bool, lines: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	if not s.has_condition("sick"):
		return
	s.change_health(-2.0)
	s.change_mood(-2.0)
	if rng.randf() < (0.55 if medbay else 0.3):
		s.set_condition("sick", false)
		lines.append({"text": "%s %s." % [s.first_name, s.by_gender("выздоровел", "выздоровела")], "kind": "good"})


static func _update_mood(s: SurvivorData, people: Array[SurvivorData], unpowered: Array[int],
		crowded: bool, kitchen_fed: bool, day: int) -> void:
	# Настроение медленно стремится к спокойному уровню.
	s.change_mood((60.0 - s.mood) * 0.1)
	if s.has_trait("optimist"):
		s.change_mood(3.0)
	if s.has_trait("pessimist"):
		s.change_mood(-2.0)
	if s.has_trait("lazy"):
		s.change_mood(1.0)
	if kitchen_fed:
		s.change_mood(2.0)
	if not unpowered.is_empty():
		s.change_mood(-3.0)
	if crowded:
		s.change_mood(-4.0)
	var friends := RelationshipSystem.count_at_level(s, people, RelationshipSystem.FRIEND_LEVEL)
	var enemies := RelationshipSystem.count_at_level(s, people, RelationshipSystem.ENEMY_LEVEL)
	s.change_mood(minf(friends * 2.0, 6.0) - enemies * 3.0)
	if friends == 0 and not s.has_trait("loner") and people.size() >= 3 and day >= 5:
		s.change_mood(-1.0)
	# Родные рядом поддерживают, а за ушедших в вылазку тревожно.
	s.change_mood(minf(FamilySystem.relatives_in_shelter(s).size() * 3.0, 6.0))
	s.change_mood(-2.0 * FamilySystem.relatives_away(s).size())
