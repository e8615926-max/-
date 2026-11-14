class_name RoomData
extends RefCounted
## Построенная комната: тип, положение в сетке, уровень, состояние оборудования и обустройство.

var id: int = 0
var type: String = ""
## Этаж (0 — верхний).
var level: int = 0
## Столбец (0 — у шахты лифта).
var col: int = 0
## Уровень улучшения 1–3.
var tier: int = 1
## Режим работы для комнат с выбором продукта (мастерская: "metal" / "wood"); "" — по умолчанию.
var mode: String = ""
## Состояние оборудования 0–100; при низком состоянии комната может сломаться.
var condition: float = 100.0
## Сломанная комната не работает, пока её не починят.
var broken: bool = false
## Украшения по слотам ("" — пусто).
var decor: Array = ["", ""]
## Окраска стен (см. DecorDefs.PAINTS).
var paint: String = ""


func get_def() -> Dictionary:
	return RoomDefs.get_def(type)


func display_name() -> String:
	return RoomDefs.name_of(type)


## Название с уровнем: «Ферма II».
func title() -> String:
	return display_name() if tier <= 1 else "%s %s" % [display_name(), RoomDefs.TIER_NAMES[tier]]


func can_break() -> bool:
	return float(get_def()["wear"]) > 0.0


## Что сейчас производит комната ("" — ничего).
func product() -> String:
	var def := get_def()
	if def.has("modes") and (def["modes"] as Dictionary).has(mode):
		return mode
	return String(def["produces"])


## Базовая выработка работника с учётом режима.
func base_output() -> float:
	var def := get_def()
	if def.has("modes") and (def["modes"] as Dictionary).has(mode):
		return float(def["modes"][mode]["base"])
	return float(def["base"])


func comfort() -> int:
	var total := 0
	for id in decor:
		if DecorDefs.exists(String(id)):
			total += int(DecorDefs.INFO[id]["comfort"])
	return total


func to_dict() -> Dictionary:
	return {"id": id, "type": type, "level": level, "col": col, "tier": tier, "mode": mode,
		"condition": snappedf(condition, 0.1), "broken": broken, "decor": decor.duplicate(), "paint": paint}


static func from_dict(d: Dictionary) -> RoomData:
	var r := RoomData.new()
	r.id = int(d.get("id", 0))
	r.type = String(d.get("type", ""))
	r.level = int(d.get("level", 0))
	r.col = int(d.get("col", 0))
	r.tier = clampi(int(d.get("tier", 1)), 1, RoomDefs.MAX_TIER)
	r.mode = String(d.get("mode", ""))
	r.condition = clampf(float(d.get("condition", 100.0)), 0.0, 100.0)
	r.broken = bool(d.get("broken", false))
	var saved_decor: Array = d.get("decor", [])
	for i in DecorDefs.SLOTS:
		var item := String(saved_decor[i]) if i < saved_decor.size() else ""
		r.decor[i] = item if DecorDefs.exists(item) else ""
	var saved_paint := String(d.get("paint", ""))
	r.paint = saved_paint if DecorDefs.PAINTS.has(saved_paint) else ""
	return r
