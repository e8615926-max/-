class_name MaintenanceSystem
extends RefCounted
## Износ оборудования, поломки и ремонт.
## Работающие комнаты каждый день изнашиваются; ниже 30% они могут сломаться
## и стоят, пока их не починят. Обслуживание заранее обходится дешевле ремонта.

const BREAK_THRESHOLD := 30.0
const REPAIRED_CONDITION := 70.0
const BROKEN_REPAIR_COST := 15
## Обслуживание: 1 металл за каждые 5% износа.
const SERVICE_STEP := 5.0
## Скидка, если в убежище есть автомеханик или мастер на все руки.
const DISCOUNT := 0.7


## Износ комнаты за день.
static func daily_wear(room: RoomData, workers: Array[SurvivorData], powered: bool) -> float:
	var base := float(room.get_def()["wear"])
	if base <= 0.0:
		return 0.0
	if not powered:
		return base * 0.5
	var wear := base * (1.0 + 0.25 * workers.size())
	var best_engineering := 0
	for s in workers:
		if s.has_trait("clumsy"):
			wear *= 1.5
		if s.has_trait("handy"):
			wear *= 0.6
		best_engineering = maxi(best_engineering, s.effective_skill("engineering"))
	# Толковый инженер в смене бережёт технику.
	wear *= clampf(1.15 - best_engineering * 0.05, 0.6, 1.1)
	return wear


static func has_repairer() -> bool:
	for s in GameState.survivors_in_shelter():
		if s.has_trait("handy") or s.profession == "mechanic":
			return true
	return false


static func needs_service(room: RoomData) -> bool:
	return room.can_break() and (room.broken or room.condition < 99.5)


static func repair_cost(room: RoomData) -> int:
	if not needs_service(room):
		return 0
	var cost := float(BROKEN_REPAIR_COST) if room.broken else ceilf((100.0 - room.condition) / SERVICE_STEP)
	if has_repairer():
		cost *= DISCOUNT
	return maxi(1, roundi(cost))


## Пустая строка — чинить можно, иначе причина отказа.
static func repair_error(room: RoomData) -> String:
	if not needs_service(room):
		return "Оборудование в порядке"
	if GameState.survivors_in_shelter().is_empty():
		return "Некому чинить"
	if not GameState.can_afford("metal", repair_cost(room)):
		return "Недостаточно металла"
	return ""


static func repair(room: RoomData) -> bool:
	if repair_error(room) != "":
		return false
	GameState.resources["metal"] = GameState.get_resource("metal") - repair_cost(room)
	if room.broken:
		room.broken = false
		room.condition = maxf(room.condition, REPAIRED_CONDITION)
		GameState.log_event("Отсек «%s» починили, он снова работает." % room.display_name(), "good")
	else:
		room.condition = 100.0
	GameState.resources_changed.emit()
	GameState.rooms_changed.emit()
	return true


static func status_text(room: RoomData) -> String:
	if room.broken:
		return "Сломано"
	if room.condition < BREAK_THRESHOLD:
		return "На грани поломки"
	if room.condition < 60.0:
		return "Изношено"
	return "Исправно"


static func status_color(room: RoomData) -> Color:
	if room.broken or room.condition < BREAK_THRESHOLD:
		return UITheme.BAD
	if room.condition < 60.0:
		return UITheme.ACCENT
	return UITheme.GOOD


## Ежедневный износ и поломки.
static func tick(lines: Array[Dictionary], unpowered: Array[int]) -> void:
	var rng := GameState.rng
	for room in GameState.rooms:
		if room.broken or not room.can_break():
			continue
		var wear := daily_wear(room, GameState.workers_of(room.id), not unpowered.has(room.id))
		room.condition = maxf(room.condition - wear, 0.0)
		if room.condition < BREAK_THRESHOLD and rng.randf() < 0.05 + (BREAK_THRESHOLD - room.condition) / 60.0:
			room.broken = true
			lines.append({"text": "Поломка: отсек «%s» остановился. Нужен ремонт." % room.display_name(),
				"kind": "bad", "log": true})
