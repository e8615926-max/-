class_name ResearchSystem
extends RefCounted
## Исследования лаборатории: очки копятся каждый день, изученные технологии
## открывают комнаты, снаряжение и улучшают производство.

static func has(id: String) -> bool:
	return GameState.research_done.has(id)


static func is_available(id: String) -> bool:
	if has(id):
		return false
	for req: String in ResearchDefs.INFO[id]["requires"]:
		if not has(req):
			return false
	return true


## Пустая строка — начать можно, иначе причина отказа.
static func start_error(id: String) -> String:
	if not ResearchDefs.exists(id):
		return "Неизвестная технология"
	if has(id):
		return "Уже изучено"
	if GameState.research_current != "":
		return "Лаборатория занята другим исследованием"
	if not is_available(id):
		return "Сначала изучите: %s" % ResearchDefs.name_of(String(ResearchDefs.INFO[id]["requires"][0]))
	var missing := GameState.missing_resource(ResearchDefs.INFO[id]["cost"])
	if missing != "":
		return "Не хватает: %s" % ResourceDefs.name_of(missing).to_lower()
	return ""


static func start(id: String) -> bool:
	if start_error(id) != "":
		return false
	GameState.pay(ResearchDefs.INFO[id]["cost"])
	GameState.research_current = id
	GameState.research_progress = 0.0
	GameState.research_changed.emit()
	return true


## Отмена: накопленное пропадает, ресурсы не возвращаются.
static func cancel() -> void:
	GameState.research_current = ""
	GameState.research_progress = 0.0
	GameState.research_changed.emit()


## Очки исследования в день от всех работающих лабораторий.
static func points_per_day(unavailable: Array[int] = []) -> float:
	var total := 0.0
	for room in GameState.rooms:
		if room.type != "lab" or room.broken or unavailable.has(room.id):
			continue
		for s in GameState.workers_of(room.id):
			var points := (room.base_output() + s.effective_skill("science")) * DaySystem.work_factor(s, room)
			if s.has_trait("curious"):
				points *= 1.25
			total += points * RoomDefs.tier_output(room.tier)
	return total


static func add_points(amount: float, lines: Array[Dictionary]) -> void:
	if GameState.research_current == "" or amount <= 0.0:
		return
	GameState.research_progress += amount
	var id := GameState.research_current
	if GameState.research_progress >= float(ResearchDefs.INFO[id]["points"]):
		GameState.research_done.append(id)
		GameState.research_current = ""
		GameState.research_progress = 0.0
		lines.append({"text": "Исследование завершено: %s. %s" % [ResearchDefs.name_of(id), ResearchDefs.INFO[id]["desc"]],
			"kind": "good", "log": true})
	GameState.research_changed.emit()


static func daily(lines: Array[Dictionary], unavailable: Array[int]) -> void:
	add_points(points_per_day(unavailable), lines)


# --- Эффекты технологий ---------------------------------------------------------

static func output_mult(product: String) -> float:
	match product:
		"food":
			return 1.2 if has("hydroponics") else 1.0
		"water":
			return 1.2 if has("filtration") else 1.0
		"power":
			return 1.25 if has("power_grid") else 1.0
		"concrete":
			return 1.3 if has("cement_mix") else 1.0
	return 1.0


static func wear_mult() -> float:
	return 0.75 if has("insulation") else 1.0


static func treatment_mult() -> float:
	return 1.5 if has("field_medicine") else 1.0


static func max_tier() -> int:
	return 3 if has("reinforced") else 2


static func extra_expedition_days() -> int:
	return 1 if has("scouting") else 0


static func loot_mult() -> float:
	return 1.15 if has("scouting") else 1.0


static func signal_mult() -> float:
	return 1.5 if has("radio_decoding") else 1.0
