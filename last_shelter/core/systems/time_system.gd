class_name TimeSystem
extends RefCounted
## Время суток и распорядок дня жителей.
## Днём часы идут сами (06:00 → 22:00), ночью жители спят, а день заканчивается
## кнопкой «Следующий день».

const DAY_START := 360.0   # 06:00 — подъём
const NIGHT_START := 1320.0  # 22:00 — отбой
## Игровых минут в реальную секунду при скорости ×1: день длится около 2,7 минуты.
const MINUTES_PER_SECOND := 6.0
const SPEEDS: Array[int] = [1, 3]

const BREAKFAST_END := 450.0  # 07:30
const LUNCH_START := 720.0    # 12:00
const LUNCH_END := 780.0
const DINNER_START := 1080.0  # 18:00
const DINNER_END := 1140.0
const WORK_START := 450.0
const WORK_END := 1080.0
## Лентяи приходят на смену позже и уходят раньше.
const LAZY_DELAY := 60.0

const ACTIVITY_NAMES := {
	"work": "работает", "eat": "ест", "social": "общается", "rest": "отдыхает",
	"sleep": "спит", "heal": "лечится", "idle": "без дела", "away": "в экспедиции",
}


static func clock_text(minute: float) -> String:
	var m := int(minute) % 1440
	return "%02d:%02d" % [floori(m / 60.0), m % 60]


static func is_night(minute: float) -> bool:
	return minute >= NIGHT_START or minute < DAY_START


static func needs_rest(s: SurvivorData) -> bool:
	return s.health < s.max_health * 0.4 or s.is_ill() or s.has_condition("wounded")


## Чем выживший занят в эту минуту.
static func activity(s: SurvivorData, minute: float) -> String:
	if s.on_expedition:
		return "away"
	if is_night(minute):
		return "sleep"
	if needs_rest(s):
		return "heal"
	if minute < BREAKFAST_END or (minute >= LUNCH_START and minute < LUNCH_END) \
			or (minute >= DINNER_START and minute < DINNER_END):
		return "eat"
	if minute >= DINNER_END:
		return "rest" if s.has_trait("loner") else "social"
	var delay := LAZY_DELAY if s.has_trait("lazy") else 0.0
	if s.room_id != -1 and minute >= WORK_START + delay and minute < WORK_END - delay:
		return "work"
	return "idle"


## «работает: ферма», «спит», «в экспедиции»…
static func activity_text(s: SurvivorData, minute: float) -> String:
	var act := activity(s, minute)
	if act == "work":
		var room := GameState.get_room(s.room_id)
		return "работает: %s" % room.display_name().to_lower() if room != null else "работает"
	return String(ACTIVITY_NAMES.get(act, act))


## Комната, где выживший проводит это занятие (null — если подходящей нет).
static func place_for(s: SurvivorData, act: String) -> RoomData:
	match act:
		"work":
			var room := GameState.get_room(s.room_id)
			if room != null:
				return room
		"eat", "social":
			var kitchen := GameState.first_room_of_type("kitchen")
			if kitchen != null:
				return kitchen
		"heal":
			var medbay := GameState.first_room_of_type("medbay")
			if medbay != null:
				return medbay
	return bed_room(s)


## Жилой отсек, где у выжившего кровать (по четыре на отсек).
static func bed_room(s: SurvivorData) -> RoomData:
	var quarters: Array[RoomData] = []
	for room in GameState.rooms:
		if room.type == "quarters":
			quarters.append(room)
	if quarters.is_empty():
		return null
	var beds := int(RoomDefs.get_def("quarters")["beds"])
	var index := maxi(GameState.survivors.find(s), 0)
	return quarters[clampi(floori(float(index) / beds), 0, quarters.size() - 1)]
