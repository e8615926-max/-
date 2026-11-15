extends Node
## Глобальное состояние текущей игры (автозагрузка GameState).
## Хранит данные и даёт базовые операции над ними; правила хода дня,
## экспедиций, отношений и событий вынесены в core/systems.

signal resources_changed
signal day_changed
signal survivors_changed
signal rooms_changed
signal storage_changed
signal expeditions_changed
signal time_changed
signal chronicle_changed
signal research_changed
signal radio_changed
## Торговцы, соседние общины и находки.
signal world_changed

## Сколько записей хранит летопись.
const CHRONICLE_MAX := 300

## true, пока открыта игровая сцена (нужно для автосохранения).
var active: bool = false

var day: int = 1
## Время суток в минутах от полуночи (06:00 = 360).
var minute: float = TimeSystem.DAY_START
## Когда сегодня случится событие (минута) или -1.
var event_minute: int = -1
var resources: Dictionary = {}
var survivors: Array[SurvivorData] = []
var rooms: Array[RoomData] = []
## item_id -> количество на общем складе
var storage: Dictionary = {}
## Активные экспедиции: {"survivor_id", "days_left", "total_days"}
var expeditions: Array[Dictionary] = []
## Летопись убежища: {"day", "text", "kind"}
var chronicle: Array[Dictionary] = []

## Исследования: изученные, текущее и накопленные очки.
var research_done: Array[String] = []
var research_current: String = ""
var research_progress: float = 0.0
## Эфир: накопленный сигнал, услышанные передачи, журнал и ждущая расшифровки.
var radio_progress: float = 0.0
var radio_heard: Array[String] = []
var radio_log: Array[Dictionary] = []
var radio_pending: String = ""
## Места для вылазок: открытые и уже посещённые.
var locations: Array[String] = ["outskirts", "houses"]
var visited: Array[String] = []
## Сколько раз побывали в месте и насколько оно разграблено (0..1, со временем восстанавливается).
var location_visits: Dictionary = {}
var depletion: Dictionary = {}
## Найденные документы, записи и сигналы — по порядку находки.
var documents: Array[String] = []
## Торговец у ворот: {"id", "days_left", "deals": [{"give", "get"|"item", "stock"}]} или {}.
var merchant: Dictionary = {}
var next_merchant_day: int = 3
## Отношения с другими общинами: {id: {"relation", "help_day", "request_day", "trade_day"}}.
var shelters: Dictionary = {}

var next_survivor_id: int = 1
var next_room_id: int = 1
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


# --- Новая игра -----------------------------------------------------------

func reset() -> void:
	day = 1
	minute = TimeSystem.DAY_START
	event_minute = -1
	resources = {}
	for id in ResourceDefs.IDS:
		resources[id] = 0
	survivors.clear()
	rooms.clear()
	storage.clear()
	expeditions.clear()
	chronicle.clear()
	research_done.clear()
	research_current = ""
	research_progress = 0.0
	radio_progress = 0.0
	radio_heard.clear()
	radio_log.clear()
	radio_pending = ""
	locations = ["outskirts", "houses"]
	visited.clear()
	location_visits = {}
	depletion = {}
	documents.clear()
	merchant = {}
	next_merchant_day = 3
	shelters = {}
	next_survivor_id = 1
	next_room_id = 1


func new_game() -> void:
	reset()
	resources = ResourceDefs.START.duplicate()
	_place_room("quarters", 0, 0)
	_place_room("farm", 0, 1)
	_place_room("water", 0, 2)
	_place_room("generator", 1, 0)
	for s in SurvivorFactory.create_starters():
		add_survivor(s)
	storage = {"knife": 1, "medkit": 1, "chocolate": 1, "trowel": 1}
	event_minute = EventSystem.schedule(rng)
	log_event("Гермодверь закрылась. В убежище двое: %s и %s." % [
		survivors[0].full_name(), survivors[1].full_name()], "info")
	emit_all()


func emit_all() -> void:
	rooms_changed.emit()
	survivors_changed.emit()
	resources_changed.emit()
	storage_changed.emit()
	expeditions_changed.emit()
	day_changed.emit()
	time_changed.emit()
	chronicle_changed.emit()
	research_changed.emit()
	radio_changed.emit()
	world_changed.emit()


# --- Время и летопись ---------------------------------------------------------

## Двигает часы вперёд (не дальше отбоя). Сигнал — раз в 10 игровых минут.
func advance_clock(minutes: float) -> void:
	var before := floori(minute / 10.0)
	minute = minf(minute + minutes, TimeSystem.NIGHT_START)
	if floori(minute / 10.0) != before:
		time_changed.emit()


func is_night() -> bool:
	return TimeSystem.is_night(minute)


func log_event(text: String, kind: String = "info") -> void:
	chronicle.append({"day": day, "text": text, "kind": kind})
	if chronicle.size() > CHRONICLE_MAX:
		chronicle = chronicle.slice(chronicle.size() - CHRONICLE_MAX)
	chronicle_changed.emit()


# --- Ресурсы --------------------------------------------------------------

func get_resource(id: String) -> int:
	return int(resources.get(id, 0))


func get_cap(_id: String) -> int:
	var cap := ResourceDefs.BASE_CAP
	for room in rooms:
		cap += RoomDefs.cap_of(room.type, room.tier)
	return cap


func add_resource(id: String, amount: int) -> void:
	resources[id] = clampi(get_resource(id) + amount, 0, get_cap(id))
	resources_changed.emit()


func can_afford(id: String, amount: int) -> bool:
	return get_resource(id) >= amount


func can_pay(cost: Dictionary) -> bool:
	for res: String in cost:
		if not can_afford(res, int(cost[res])):
			return false
	return true


## Списывает цену, если хватает всего. Возвращает, получилось ли.
func pay(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	for res: String in cost:
		resources[res] = get_resource(res) - int(cost[res])
	resources_changed.emit()
	return true


## Первый ресурс, которого не хватает ("" — хватает всего).
func missing_resource(cost: Dictionary) -> String:
	for res in ResourceDefs.IDS:
		if int(cost.get(res, 0)) > get_resource(res):
			return res
	return ""


# --- Выжившие -------------------------------------------------------------

func get_survivor(id: int) -> SurvivorData:
	for s in survivors:
		if s.id == id:
			return s
	return null


func survivors_in_shelter() -> Array[SurvivorData]:
	var result: Array[SurvivorData] = []
	for s in survivors:
		if not s.on_expedition:
			result.append(s)
	return result


func population() -> int:
	return survivors.size()


func bed_capacity() -> int:
	var beds := 0
	for room in rooms:
		beds += RoomDefs.beds_of(room.type, room.tier)
	return beds


func has_free_bed() -> bool:
	return population() < bed_capacity()


func add_survivor(s: SurvivorData) -> void:
	s.id = next_survivor_id
	next_survivor_id += 1
	s.joined_day = day
	s.room_id = -1
	s.on_expedition = false
	for other in survivors:
		RelationshipSystem.introduce(s, other, rng)
	survivors.append(s)
	survivors_changed.emit()


func remove_survivor(id: int) -> void:
	var s := get_survivor(id)
	if s == null:
		return
	survivors.erase(s)
	for other in survivors:
		other.relationships.erase(id)
		other.family.erase(id)
	for i in range(expeditions.size() - 1, -1, -1):
		if int(expeditions[i]["survivor_id"]) == id:
			expeditions.remove_at(i)
	survivors_changed.emit()


# --- Комнаты --------------------------------------------------------------

func get_room(id: int) -> RoomData:
	for room in rooms:
		if room.id == id:
			return room
	return null


func room_at(level: int, col: int) -> RoomData:
	for room in rooms:
		if room.level == level and room.col == col:
			return room
	return null


func first_room_of_type(type: String) -> RoomData:
	for room in rooms:
		if room.type == type:
			return room
	return null


## Строить можно у шахты лифта или вплотную к уже построенной комнате слева.
func can_build_at(level: int, col: int) -> bool:
	if level < 0 or level >= ShelterLayout.LEVELS or col < 0 or col >= ShelterLayout.COLS:
		return false
	if room_at(level, col) != null:
		return false
	return col == 0 or room_at(level, col - 1) != null


## Пустая строка — строить можно, иначе причина отказа.
func build_error(type: String, level: int, col: int) -> String:
	if not RoomDefs.exists(type):
		return "Неизвестный тип комнаты"
	var research := RoomDefs.research_of(type)
	if research != "" and not ResearchSystem.has(research):
		return "Нужно исследование: %s" % ResearchDefs.name_of(research)
	if not can_build_at(level, col):
		return "Здесь строить нельзя"
	var missing := missing_resource(RoomDefs.cost_of(type))
	if missing != "":
		return "Не хватает: %s" % ResourceDefs.name_of(missing).to_lower()
	return ""


func build_room(type: String, level: int, col: int) -> bool:
	if build_error(type, level, col) != "":
		return false
	pay(RoomDefs.cost_of(type))
	_place_room(type, level, col)
	log_event("Построен новый отсек: %s." % RoomDefs.name_of(type).to_lower(), "good")
	resources_changed.emit()
	rooms_changed.emit()
	return true


## Пустая строка — улучшить можно, иначе причина отказа.
func upgrade_error(room: RoomData) -> String:
	if room.tier >= RoomDefs.MAX_TIER:
		return "Максимальный уровень"
	if room.tier + 1 > ResearchSystem.max_tier():
		return "Нужно исследование: %s" % ResearchDefs.name_of("reinforced")
	if room.broken:
		return "Сначала почините отсек"
	var missing := missing_resource(RoomDefs.upgrade_cost(room.type, room.tier + 1))
	if missing != "":
		return "Не хватает: %s" % ResourceDefs.name_of(missing).to_lower()
	return ""


func upgrade_room(room: RoomData) -> bool:
	if upgrade_error(room) != "":
		return false
	pay(RoomDefs.upgrade_cost(room.type, room.tier + 1))
	room.tier += 1
	room.condition = 100.0
	log_event("Отсек улучшен: %s." % room.title(), "good")
	rooms_changed.emit()
	return true


## Переключает продукт комнаты (мастерская: металл или доски).
func set_room_mode(room: RoomData, new_mode: String) -> void:
	if room.get_def().has("modes") and (room.get_def()["modes"] as Dictionary).has(new_mode):
		room.mode = new_mode
		rooms_changed.emit()
		resources_changed.emit()


## Ставит украшение в слот (платит цену) или убирает ("" — пусто).
func set_decor(room: RoomData, slot: int, decor_id: String) -> bool:
	if slot < 0 or slot >= DecorDefs.SLOTS:
		return false
	if decor_id != "":
		if not DecorDefs.exists(decor_id) or decor_error(decor_id) != "":
			return false
		pay(DecorDefs.INFO[decor_id]["cost"])
	room.decor[slot] = decor_id
	rooms_changed.emit()
	return true


func decor_error(decor_id: String) -> String:
	var research := String(DecorDefs.INFO[decor_id].get("research", ""))
	if research != "" and not ResearchSystem.has(research):
		return "Нужно исследование: %s" % ResearchDefs.name_of(research)
	var missing := missing_resource(DecorDefs.INFO[decor_id]["cost"])
	if missing != "":
		return "Не хватает: %s" % ResourceDefs.name_of(missing).to_lower()
	return ""


func set_paint(room: RoomData, paint_id: String) -> void:
	if DecorDefs.PAINTS.has(paint_id):
		room.paint = paint_id
		rooms_changed.emit()


## Уют убежища от украшений (с потолком).
func comfort() -> int:
	var total := 0
	for room in rooms:
		total += room.comfort()
	return mini(total, DecorDefs.COMFORT_CAP)


func craft_error(item_id: String) -> String:
	var recipe: Dictionary = ItemDefs.RECIPES.get(item_id, {})
	if recipe.is_empty():
		return "Это не изготовить"
	if not ResearchSystem.has(String(recipe["research"])):
		return "Нужно исследование: %s" % ResearchDefs.name_of(String(recipe["research"]))
	var missing := missing_resource(recipe["cost"])
	if missing != "":
		return "Не хватает: %s" % ResourceDefs.name_of(missing).to_lower()
	return ""


## Изготавливает предмет на общий склад.
func craft(item_id: String) -> bool:
	if craft_error(item_id) != "":
		return false
	pay(ItemDefs.RECIPES[item_id]["cost"])
	storage_add(item_id)
	return true


func _place_room(type: String, level: int, col: int) -> RoomData:
	var room := RoomData.new()
	room.id = next_room_id
	next_room_id += 1
	room.type = type
	room.level = level
	room.col = col
	rooms.append(room)
	return room


func workers_of(room_id: int) -> Array[SurvivorData]:
	var result: Array[SurvivorData] = []
	for s in survivors:
		if s.room_id == room_id and not s.on_expedition:
			result.append(s)
	return result


func workers_count() -> int:
	var count := 0
	for s in survivors:
		if s.room_id != -1 and not s.on_expedition:
			count += 1
	return count


func room_has_free_slot(room_id: int) -> bool:
	var room := get_room(room_id)
	if room == null:
		return false
	return workers_of(room_id).size() < RoomDefs.slots_of(room.type, room.tier)


## Назначает выжившего на работу. room_id = -1 снимает с работы.
func assign(survivor_id: int, room_id: int) -> bool:
	var s := get_survivor(survivor_id)
	if s == null or s.on_expedition:
		return false
	if room_id != -1 and s.room_id != room_id and not room_has_free_slot(room_id):
		return false
	s.room_id = room_id
	survivors_changed.emit()
	return true


# --- Общий склад предметов --------------------------------------------------

func storage_count(item_id: String) -> int:
	return int(storage.get(item_id, 0))


func storage_add(item_id: String, amount: int = 1) -> void:
	storage[item_id] = storage_count(item_id) + amount
	storage_changed.emit()


func storage_remove(item_id: String) -> bool:
	var count := storage_count(item_id)
	if count <= 0:
		return false
	if count == 1:
		storage.erase(item_id)
	else:
		storage[item_id] = count - 1
	storage_changed.emit()
	return true


# --- Сохранение -----------------------------------------------------------

func to_dict() -> Dictionary:
	var survivors_out: Array = []
	for s in survivors:
		survivors_out.append(s.to_dict())
	var rooms_out: Array = []
	for room in rooms:
		rooms_out.append(room.to_dict())
	return {
		"day": day,
		"minute": roundi(minute),
		"event_minute": event_minute,
		"resources": resources.duplicate(),
		"survivors": survivors_out,
		"rooms": rooms_out,
		"storage": storage.duplicate(),
		"expeditions": expeditions.duplicate(true),
		"chronicle": chronicle.duplicate(true),
		"research_done": research_done.duplicate(),
		"research_current": research_current,
		"research_progress": snappedf(research_progress, 0.01),
		"radio_progress": snappedf(radio_progress, 0.01),
		"radio_heard": radio_heard.duplicate(),
		"radio_log": radio_log.duplicate(true),
		"radio_pending": radio_pending,
		"locations": locations.duplicate(),
		"visited": visited.duplicate(),
		"location_visits": location_visits.duplicate(),
		"depletion": depletion.duplicate(),
		"documents": documents.duplicate(),
		"merchant": merchant.duplicate(true),
		"next_merchant_day": next_merchant_day,
		"shelters": shelters.duplicate(true),
		"next_survivor_id": next_survivor_id,
		"next_room_id": next_room_id,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	day = maxi(int(d.get("day", 1)), 1)
	minute = clampf(float(d.get("minute", TimeSystem.DAY_START)), TimeSystem.DAY_START, TimeSystem.NIGHT_START)
	event_minute = int(d.get("event_minute", -1))
	var saved_res: Dictionary = d.get("resources", {})
	for id in ResourceDefs.IDS:
		resources[id] = maxi(int(saved_res.get(id, 0)), 0)
	# Сохранения до версии 3 не знали дерева, бетона и медикаментов — выдаём стартовый запас.
	for id in ResourceDefs.ADDED_V3:
		if not saved_res.has(id):
			resources[id] = int(ResourceDefs.START[id])
	for entry: Dictionary in d.get("rooms", []):
		var room := RoomData.from_dict(entry)
		if RoomDefs.exists(room.type):
			rooms.append(room)
	for entry: Dictionary in d.get("survivors", []):
		survivors.append(SurvivorData.from_dict(entry))
	var saved_storage: Dictionary = d.get("storage", {})
	for item_id: String in saved_storage:
		if ItemDefs.exists(item_id) and int(saved_storage[item_id]) > 0:
			storage[item_id] = int(saved_storage[item_id])
	for entry: Dictionary in d.get("expeditions", []):
		var sid := int(entry.get("survivor_id", 0))
		if get_survivor(sid) != null:
			var place := String(entry.get("location", "outskirts"))
			expeditions.append({
				"survivor_id": sid,
				"days_left": int(entry.get("days_left", 1)),
				"total_days": int(entry.get("total_days", 1)),
				"location": place if LocationDefs.exists(place) else "outskirts",
			})
	for entry: Dictionary in d.get("chronicle", []):
		chronicle.append({"day": int(entry.get("day", 1)), "text": String(entry.get("text", "")),
			"kind": String(entry.get("kind", "info"))})
	for id in d.get("research_done", []):
		if ResearchDefs.exists(String(id)) and not research_done.has(String(id)):
			research_done.append(String(id))
	var current := String(d.get("research_current", ""))
	research_current = current if ResearchDefs.exists(current) else ""
	research_progress = maxf(float(d.get("research_progress", 0.0)), 0.0)
	radio_progress = maxf(float(d.get("radio_progress", 0.0)), 0.0)
	for id in d.get("radio_heard", []):
		radio_heard.append(String(id))
	for entry: Dictionary in d.get("radio_log", []):
		radio_log.append({"day": int(entry.get("day", 1)), "title": String(entry.get("title", "")),
			"text": String(entry.get("text", ""))})
	radio_pending = String(d.get("radio_pending", ""))
	var saved_places: Array = d.get("locations", ["outskirts"])
	locations.clear()
	for id in saved_places:
		if LocationDefs.exists(String(id)) and not locations.has(String(id)):
			locations.append(String(id))
	for id in d.get("visited", []):
		visited.append(String(id))
	# Сохранения до версии 4 не знали домов и мест, которые открывают сами вылазки.
	if not locations.has("outskirts"):
		locations.insert(0, "outskirts")
	if not locations.has("houses"):
		locations.insert(1, "houses")
	for id in visited:
		if LocationDefs.exists(id):
			for revealed: String in LocationDefs.INFO[id].get("reveals", []):
				if not locations.has(revealed):
					locations.append(revealed)
	var saved_visits: Dictionary = d.get("location_visits", {})
	for id: String in saved_visits:
		if LocationDefs.exists(id):
			location_visits[id] = maxi(int(saved_visits[id]), 0)
	var saved_depletion: Dictionary = d.get("depletion", {})
	for id: String in saved_depletion:
		if LocationDefs.exists(id):
			depletion[id] = clampf(float(saved_depletion[id]), 0.0, 1.0)
	for id in d.get("documents", []):
		if DocumentDefs.exists(String(id)) and not documents.has(String(id)):
			documents.append(String(id))
	merchant = TradeSystem.sanitize(d.get("merchant", {}))
	next_merchant_day = int(d.get("next_merchant_day", day + 2))
	var saved_shelters: Dictionary = d.get("shelters", {})
	for id: String in saved_shelters:
		if ShelterDefs.INFO.has(id):
			var entry: Dictionary = saved_shelters[id]
			shelters[id] = {"relation": clampi(int(entry.get("relation", 0)), -100, 100),
				"help_day": int(entry.get("help_day", -99)), "request_day": int(entry.get("request_day", -99)),
				"trade_day": int(entry.get("trade_day", -99))}
	next_survivor_id = int(d.get("next_survivor_id", 1))
	next_room_id = int(d.get("next_room_id", 1))
	# Защита от повреждённых сохранений: счётчики и ссылки должны быть согласованы.
	for s in survivors:
		next_survivor_id = maxi(next_survivor_id, s.id + 1)
		if s.room_id != -1 and get_room(s.room_id) == null:
			s.room_id = -1
		var away := false
		for e in expeditions:
			if int(e["survivor_id"]) == s.id:
				away = true
		s.on_expedition = away
		for other_id: int in s.family.keys():
			if get_survivor(other_id) == null:
				s.family.erase(other_id)
		# Сохранения версии 1 не знали биографий.
		SurvivorFactory.ensure_bio(s)
	for room in rooms:
		next_room_id = maxi(next_room_id, room.id + 1)
	if chronicle.is_empty():
		log_event("Летопись убежища начата на %d-й день." % day, "info")
	emit_all()
