class_name RoomData
extends RefCounted
## Построенная комната: тип и положение в сетке убежища.

var id: int = 0
var type: String = ""
## Этаж (0 — верхний).
var level: int = 0
## Столбец (0 — у шахты лифта).
var col: int = 0


func get_def() -> Dictionary:
	return RoomDefs.get_def(type)


func display_name() -> String:
	return RoomDefs.name_of(type)


func to_dict() -> Dictionary:
	return {"id": id, "type": type, "level": level, "col": col}


static func from_dict(d: Dictionary) -> RoomData:
	var r := RoomData.new()
	r.id = int(d.get("id", 0))
	r.type = String(d.get("type", ""))
	r.level = int(d.get("level", 0))
	r.col = int(d.get("col", 0))
	return r
