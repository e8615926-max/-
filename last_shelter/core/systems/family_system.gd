class_name FamilySystem
extends RefCounted
## Семьи: родственники (брат/сестра, родитель/ребёнок) и пары.
## Родные поддерживают друг друга, переживают за ушедших в вылазку и тяжело переносят утраты.

const RELATIONS: Array[String] = ["sibling", "parent", "child", "partner"]
## Кем приходится человек — мужская и женская форма.
const LABELS := {
	"sibling": ["Брат", "Сестра"],
	"parent": ["Отец", "Мать"],
	"child": ["Сын", "Дочь"],
	"partner": ["Любимый", "Любимая"],
}
## Стартовая теплота отношений между родными.
const BOND := 45.0
const COUPLE_THRESHOLD := 85.0
const COUPLE_CHANCE := 0.08
const MAX_RELATIVES := 3


static func inverse(rel: String) -> String:
	match rel:
		"parent": return "child"
		"child": return "parent"
	return rel


## Связывает двоих: other приходится s тем, что указано в rel.
static func link(s: SurvivorData, other: SurvivorData, rel: String, bond: bool = true) -> void:
	s.family[other.id] = rel
	other.family[s.id] = inverse(rel)
	if bond:
		s.change_relation(other.id, BOND)
		other.change_relation(s.id, BOND)


static func relation(s: SurvivorData, other_id: int) -> String:
	return String(s.family.get(other_id, ""))


static func is_family(a: SurvivorData, b: SurvivorData) -> bool:
	return a.family.has(b.id)


## Кем other приходится s: «Сестра», «Отец», «Любимый»… ("" — не родня).
static func label(s: SurvivorData, other: SurvivorData) -> String:
	var rel := relation(s, other.id)
	if rel == "":
		return ""
	return String(LABELS[rel][1 if other.gender == "f" else 0])


static func has_partner(s: SurvivorData) -> bool:
	return s.family.values().has("partner")


static func relatives_in_shelter(s: SurvivorData) -> Array[SurvivorData]:
	var result: Array[SurvivorData] = []
	for other_id: int in s.family:
		var other := GameState.get_survivor(other_id)
		if other != null and not other.on_expedition:
			result.append(other)
	return result


static func relatives_away(s: SurvivorData) -> Array[SurvivorData]:
	var result: Array[SurvivorData] = []
	for other_id: int in s.family:
		var other := GameState.get_survivor(other_id)
		if other != null and other.on_expedition:
			result.append(other)
	return result


## Какие родственники ещё могут найтись у s (по возрасту и числу уже найденных).
static func possible_relations(s: SurvivorData) -> Array[String]:
	var result: Array[String] = []
	var blood := 0
	for rel: String in s.family.values():
		if rel != "partner":
			blood += 1
	if blood >= MAX_RELATIVES:
		return result
	result.append("sibling")
	if s.age <= 50:
		result.append("parent")
	if s.age >= 38:
		result.append("child")
	return result


## Создаёт родственника для s. Возвращает {"survivor": новичок, "rel": кем он приходится s} или {}.
static func make_relative(s: SurvivorData, rng: RandomNumberGenerator) -> Dictionary:
	var options := possible_relations(s)
	if options.is_empty():
		return {}
	var rel: String = options[rng.randi() % options.size()]
	var n := SurvivorFactory.create_random(rng)
	n.last_name = SurvivorFactory.surname_for(SurvivorFactory.surname_base(s), n.gender)
	match rel:
		"sibling":
			n.age = clampi(s.age + rng.randi_range(-12, 12), 16, 75)
		"parent":
			n.age = clampi(s.age + rng.randi_range(20, 32), 38, 82)
		"child":
			n.age = clampi(s.age - rng.randi_range(20, 32), 16, 60)
	# Что значит s для новичка: «брат жив», «мать жива»…
	var host_label := String(LABELS[inverse(rel)][1 if s.gender == "f" else 0]).to_lower()
	var alive := "жива" if s.gender == "f" else "жив"
	n.bio = "%s %s" % [BioDefs.gendered("Узнав, что %s %s, {отправился|отправилась} на поиски." % [host_label, alive], n.gender), n.bio]
	return {"survivor": n, "rel": rel}


## Близкие друзья иногда становятся парой (не больше одной пары за день).
static func try_form_couples(lines: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var people := GameState.survivors_in_shelter()
	for i in people.size():
		for j in range(i + 1, people.size()):
			var a := people[i]
			var b := people[j]
			if not a.is_adult() or not b.is_adult() or is_family(a, b):
				continue
			if has_partner(a) or has_partner(b):
				continue
			if RelationshipSystem.mutual(a, b) < COUPLE_THRESHOLD or rng.randf() > COUPLE_CHANCE:
				continue
			link(a, b, "partner", false)
			a.change_mood(10.0)
			b.change_mood(10.0)
			lines.append({"text": "%s и %s теперь вместе." % [a.first_name, b.first_name], "kind": "good", "log": true})
			return
