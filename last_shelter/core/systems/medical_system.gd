class_name MedicalSystem
extends RefCounted
## Болезни и лечение. Каждый день болезнь вредит, а выздоровление идёт само
## (кроме тяжёлых болезней). В исправном медпункте врачи лечат быстрее и тратят медикаменты:
## одна единица на больного в день. Навык медицины и специализация врача ускоряют лечение.

## Шанс дизентерии у каждого при нехватке воды.
const DYSENTERY_CHANCE := 0.12


## Сила лечения: сколько дополнительных дней болезни снимается за день.
static func treatment_power(unavailable: Array[int] = []) -> float:
	var best := 0.0
	for room in GameState.rooms:
		if room.type != "medbay" or room.broken or unavailable.has(room.id):
			continue
		var power := 0.5
		for s in GameState.workers_of(room.id):
			power += s.effective_skill("medicine") * 0.25 * DaySystem.work_factor(s, room)
		best = maxf(best, power * RoomDefs.tier_output(room.tier))
	return best * ResearchSystem.treatment_mult()


static func has_medbay(unavailable: Array[int] = []) -> bool:
	for room in GameState.rooms:
		if room.type == "medbay" and not room.broken and not unavailable.has(room.id):
			return true
	return false


## Сколько больных сегодня будут лечиться лекарствами (столько медикаментов уйдёт).
static func patients_today(unavailable: Array[int] = []) -> int:
	if not has_medbay(unavailable):
		return 0
	var count := 0
	for s in GameState.survivors_in_shelter():
		if s.is_ill():
			count += 1
	return mini(count, GameState.get_resource("medicine"))


static func daily(lines: Array[Dictionary], unavailable: Array[int], thirsty: bool, rng: RandomNumberGenerator) -> void:
	var people := GameState.survivors_in_shelter()
	var medbay := has_medbay(unavailable)
	var power := treatment_power(unavailable)
	# Сначала лечат тех, у кого болезнь без лекарств не проходит.
	var patients: Array[SurvivorData] = []
	for s in people:
		if s.is_ill():
			patients.append(s)
	patients.sort_custom(func(a: SurvivorData, b: SurvivorData) -> bool:
		return _severity(a) > _severity(b))
	for s in patients:
		var treated := medbay and GameState.get_resource("medicine") > 0
		if treated:
			GameState.resources["medicine"] = GameState.get_resource("medicine") - 1
		for i in range(s.illnesses.size() - 1, -1, -1):
			var entry: Dictionary = s.illnesses[i]
			var def: Dictionary = IllnessDefs.INFO[entry["id"]]
			s.change_health(float(def["health"]) * (0.5 if s.has_trait("tough") else 1.0))
			s.change_mood(float(def["mood"]))
			var progress := 0.0 if bool(def["needs_medicine"]) else 1.0
			if treated:
				progress = 1.0 + power
			entry["days"] = float(entry["days"]) - progress
			if float(entry["days"]) <= 0.0:
				s.illnesses.remove_at(i)
				lines.append({"text": "%s %s: %s позади." % [s.first_name, s.by_gender("выздоровел", "выздоровела"),
					IllnessDefs.name_of(entry["id"]).to_lower()], "kind": "good"})
	_spread(people, lines, rng)
	if thirsty and not ResearchSystem.has("filtration"):
		for s in people:
			if not s.has_illness("dysentery") and rng.randf() < DYSENTERY_CHANCE:
				infect(s, "dysentery", rng, lines, "от грязной воды")


static func _severity(s: SurvivorData) -> int:
	var score := 0
	for entry: Dictionary in s.illnesses:
		score += 10 if IllnessDefs.needs_medicine(entry["id"]) else 1
	return score


## Заразные болезни передаются соседям.
static func _spread(people: Array[SurvivorData], lines: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var crowded := GameState.population() > GameState.bed_capacity()
	var carriers: Array = []
	for s in people:
		for entry: Dictionary in s.illnesses:
			if float(IllnessDefs.INFO[entry["id"]]["contagion"]) > 0.0:
				carriers.append([s, String(entry["id"])])
	for pair: Array in carriers:
		var source: SurvivorData = pair[0]
		var id: String = pair[1]
		var chance := float(IllnessDefs.INFO[id]["contagion"]) * (1.5 if crowded else 1.0)
		for other in people:
			if other != source and not other.has_illness(id) and rng.randf() < chance:
				infect(other, id, rng, lines, "от %s" % source.first_name)


static func infect(s: SurvivorData, id: String, rng: RandomNumberGenerator, lines: Array[Dictionary], reason: String = "") -> void:
	if s.has_illness(id):
		return
	s.add_illness(id, IllnessDefs.roll_days(id, rng))
	var text := "%s %s: %s" % [s.first_name, s.by_gender("заболел", "заболела"), IllnessDefs.name_of(id).to_lower()]
	if reason != "":
		text += " (%s)" % reason
	lines.append({"text": text + ".", "kind": "bad"})
