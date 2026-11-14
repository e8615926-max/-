class_name RoomData
extends RefCounted
## Построенная комната: тип, положение в сетке убежища и состояние оборудования.

var id: int = 0
var type: String = ""
## Этаж (0 — верхний).
var level: int = 0
## Столбец (0 — у шахты лифта).
var col: int = 0
## Состояние оборудования 0–100; при низком состоянии комната может сломаться.
var condition: float = 100.0
## Сломанная комната не работает, пока её не починят.
var broken: bool = false


func get_def() -> Dictionary:
	return RoomDefs.get_def(type)


func display_name() -> String:
	return RoomDefs.name_of(type)


func can_break() -> bool:
	return float(get_def()["wear"]) > 0.0


func to_dict() -> Dictionary:
	return {"id": id, "type": type, "level": level, "col": col,
		"condition": snappedf(condition, 0.1), "broken": broken}


static func from_dict(d: Dictionary) -> RoomData:
	var r := RoomData.new()
	r.id = int(d.get("id", 0))
	r.type = String(d.get("type", ""))
	r.level = int(d.get("level", 0))
	r.col = int(d.get("col", 0))
	r.condition = clampf(float(d.get("condition", 100.0)), 0.0, 100.0)
	r.broken = bool(d.get("broken", false))
	return r
