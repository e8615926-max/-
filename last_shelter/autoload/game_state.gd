extends Node
## Глобальное состояние текущей игры (автозагрузка GameState).
## Хранит данные и даёт базовые операции над ними; правила хода дня,
## экспедиций и отношений вынесены в core/systems.

signal resources_changed
signal day_changed
signal survivors_changed
signal rooms_changed
signal storage_changed
signal expeditions_changed

## true, пока открыта игровая сцена (нужно для автосохранения).
var active: bool = false

var day: int = 1
var resources: Dictionary = {"food": 0, "water": 0, "metal": 0, "power": 0}
var survivors: Array[SurvivorData] = []
var rooms: Array[RoomData] = []
## item_id -> количество на общем складе
var storage: Dictionary = {}
## Активные экспедиции: {"survivor_id", "days_left", "total_days"}
var expeditions: Array[Dictionary] = []

var next_survivor_id: int = 1
var next_room_id: int = 1
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


# --- Новая игра -----------------------------------------------------------

func reset() -> void:
	day = 1
	resources = {"food": 0, "water": 0, "metal": 0, "power": 0}
	survivors.clear()
	rooms.clear()
	storage.clear()
	expeditions.clear()
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
	emit_all()


func emit_all() -> void:
	rooms_changed.emit()
	survivors_changed.emit()
	resources_changed.emit()
	storage_changed.emit()
	expeditions_changed.emit()
	day_changed.emit()


# --- Ресурсы --------------------------------------------------------------

func get_resource(id: String) -> int:
	return int(resources.get(id, 0))


func get_cap(_id: String) -> int:
	var cap := ResourceDefs.BASE_CAP
	for room in rooms:
		cap += int(room.get_def()["cap"])
	return cap


func add_resource(id: String, amount: int) -> void:
	resources[id] = clampi(get_resource(id) + amount, 0, get_cap(id))
	resources_changed.emit()


func can_afford(id: String, amount: int) -> bool:
	return get_resource(id) >= amount


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
		beds += int(room.get_def()["beds"])
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
	if not can_build_at(level, col):
		return "Здесь строить нельзя"
	if not can_afford("metal", int(RoomDefs.get_def(type)["cost"])):
		return "Недостаточно металла"
	return ""


func build_room(type: String, level: int, col: int) -> bool:
	if build_error(type, level, col) != "":
		return false
	resources["metal"] = get_resource("metal") - int(RoomDefs.get_def(type)["cost"])
	_place_room(type, level, col)
	resources_changed.emit()
	rooms_changed.emit()
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
	return workers_of(room_id).size() < int(room.get_def()["slots"])


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
		"resources": resources.duplicate(),
		"survivors": survivors_out,
		"rooms": rooms_out,
		"storage": storage.duplicate(),
		"expeditions": expeditions.duplicate(true),
		"next_survivor_id": next_survivor_id,
		"next_room_id": next_room_id,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	day = maxi(int(d.get("day", 1)), 1)
	var saved_res: Dictionary = d.get("resources", {})
	for id in ResourceDefs.IDS:
		resources[id] = maxi(int(saved_res.get(id, 0)), 0)
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
			expeditions.append({
				"survivor_id": sid,
				"days_left": int(entry.get("days_left", 1)),
				"total_days": int(entry.get("total_days", 1)),
			})
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
	for room in rooms:
		next_room_id = maxi(next_room_id, room.id + 1)
	emit_all()
