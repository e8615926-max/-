class_name RelationshipSystem
extends RefCounted
## Отношения между выжившими. У каждого своё отношение к другому (-100..100),
## которое меняется каждый день в зависимости от характера, настроения и совместной работы.

const LEVEL_NAMES: Array[String] = ["Вражда", "Неприязнь", "Нейтрально", "Приятели", "Дружба"]
const LEVEL_COLORS: Array[Color] = [
	Color("d9534a"), Color("d98a4a"), Color("a89c86"), Color("9fc45a"), Color("5fc2b0"),
]
const FRIEND_LEVEL := 4
const ENEMY_LEVEL := 0


## Индекс уровня отношений 0..4 по числовому значению.
static func level_of(value: float) -> int:
	if value <= -60.0:
		return 0
	if value <= -20.0:
		return 1
	if value < 20.0:
		return 2
	if value < 60.0:
		return 3
	return 4


static func level_name(value: float) -> String:
	return LEVEL_NAMES[level_of(value)]


static func level_color(value: float) -> Color:
	return LEVEL_COLORS[level_of(value)]


## Взаимное отношение пары — среднее двух личных.
static func mutual(a: SurvivorData, b: SurvivorData) -> float:
	return (a.get_relation(b.id) + b.get_relation(a.id)) * 0.5


## Насколько двое подходят друг другу (примерно от −0.8 до 1.1):
## каждое общее увлечение сближает, «Душа компании» помогает, «Ворчун» мешает.
static func compatibility(a: SurvivorData, b: SurvivorData) -> float:
	var value := -0.15 + 0.3 * shared_interests(a, b).size()
	for s: SurvivorData in [a, b]:
		if s.has_trait("sociable"):
			value += 0.25
		if s.has_trait("grumpy"):
			value -= 0.3
	return value


static func shared_interests(a: SurvivorData, b: SurvivorData) -> Array:
	var result: Array = []
	for interest in a.interests:
		if b.interests.has(interest):
			result.append(interest)
	return result


## Первое впечатление при знакомстве.
static func introduce(a: SurvivorData, b: SurvivorData, rng: RandomNumberGenerator) -> void:
	a.relationships[b.id] = rng.randf_range(-8.0, 15.0)
	b.relationships[a.id] = rng.randf_range(-8.0, 15.0)


static func count_at_level(s: SurvivorData, others: Array[SurvivorData], level: int) -> int:
	var count := 0
	for other in others:
		if other.id != s.id and level_of(s.get_relation(other.id)) == level:
			count += 1
	return count


## Ежедневное общение всех, кто сейчас в убежище. Добавляет заметные события в lines.
static func daily_update(lines: Array[Dictionary]) -> void:
	var rng := GameState.rng
	var people := GameState.survivors_in_shelter()
	for i in people.size():
		for j in range(i + 1, people.size()):
			_interact(people[i], people[j], rng, lines)


static func _interact(a: SurvivorData, b: SurvivorData, rng: RandomNumberGenerator, lines: Array[Dictionary]) -> void:
	var same_room := a.room_id != -1 and a.room_id == b.room_id
	if rng.randf() > (0.95 if same_room else 0.6):
		return

	var before := level_of(mutual(a, b))
	# Тон встречи: основу задают общие увлечения и характер, настроение добавляет
	# сиюминутный фон, а сложившиеся отношения тянут в ту же сторону.
	var tone := rng.randf_range(-1.0, 1.0) + compatibility(a, b)
	tone += ((a.mood + b.mood) * 0.5 - 50.0) / 100.0
	tone += mutual(a, b) / 300.0
	var strength := 9.0 if same_room else 6.0
	_apply(a, b, tone * strength * rng.randf_range(0.7, 1.3))
	_apply(b, a, tone * strength * rng.randf_range(0.7, 1.3))

	if tone > 0.8:
		a.change_mood(2.0)
		b.change_mood(2.0)
	elif tone < -0.8:
		a.change_mood(-3.0)
		b.change_mood(-3.0)

	var after := level_of(mutual(a, b))
	if after == before:
		return
	var pair := "%s и %s" % [a.first_name, b.first_name]
	if after > before:
		var shared := shared_interests(a, b)
		var reason := ""
		if not shared.is_empty():
			reason = " Их сблизило общее увлечение: %s." % InterestDefs.name_of(shared[0]).to_lower()
		match after:
			4: lines.append({"text": "%s стали друзьями.%s" % [pair, reason], "kind": "good"})
			3: lines.append({"text": "%s нашли общий язык.%s" % [pair, reason], "kind": "good"})
			_: lines.append({"text": "%s помирились." % pair, "kind": "info"})
	else:
		match after:
			0: lines.append({"text": "%s теперь враждуют." % pair, "kind": "bad"})
			1: lines.append({"text": "%s поссорились." % pair, "kind": "bad"})
			_: lines.append({"text": "%s охладели друг к другу." % pair, "kind": "info"})


static func _apply(who: SurvivorData, other: SurvivorData, amount: float) -> void:
	if who.has_trait("loner"):
		amount *= 0.5
	who.change_relation(other.id, amount)
