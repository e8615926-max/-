class_name EventSystem
extends RefCounted
## Случайные события: выбор подходящего события, проверки навыков и последствия.
## Событие — словарь {"id", "title", "category", "text", "ctx"}; ctx хранит участников
## (a, b — id выживших), комнату (room — id), гостя (newcomer — SurvivorData) и родство (relation).

const DAILY_CHANCE := 0.6
const EARLIEST := 540   # 09:00
const LATEST := 1200    # 20:00

static var _gender_re: RegEx


## Минута, когда сегодня случится событие, или -1, если день пройдёт спокойно.
static func schedule(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(EARLIEST, LATEST) if rng.randf() < DAILY_CHANCE else -1


## Случайное подходящее событие (с учётом весов) или {}.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var candidates: Array = []
	var total := 0.0
	for id: String in EventDefs.INFO:
		var ev := build(id, rng)
		if ev.is_empty():
			continue
		var weight := float(EventDefs.INFO[id]["weight"]) * _weight_bonus(ev)
		candidates.append([ev, weight])
		total += weight
	if candidates.is_empty():
		return {}
	var pick := rng.randf() * total
	for c: Array in candidates:
		pick -= float(c[1])
		if pick <= 0.0:
			return c[0]
	return candidates[-1][0]


## Изношенные комнаты ломаются чаще.
static func _weight_bonus(ev: Dictionary) -> float:
	var room := GameState.get_room(int(ev["ctx"].get("room", -1)))
	if room == null or String(ev["category"]) not in ["breakdown", "emergency"]:
		return 1.0
	return 1.0 + (100.0 - room.condition) / 50.0


## Собирает конкретное событие, если сейчас для него есть условия, иначе {}.
static func build(id: String, rng: RandomNumberGenerator) -> Dictionary:
	if not EventDefs.INFO.has(id):
		return {}
	var def: Dictionary = EventDefs.INFO[id]
	var needs: Dictionary = def.get("needs", {})
	var people := GameState.survivors_in_shelter()
	if people.is_empty() or GameState.day < int(needs.get("min_day", 1)):
		return {}
	if needs.has("min_food") and GameState.get_resource("food") < int(needs["min_food"]):
		return {}
	if needs.get("free_bed", false) and not GameState.has_free_bed():
		return {}
	var ctx := {}

	if needs.has("room"):
		var types: Array = needs["room"] if needs["room"] is Array else [needs["room"]]
		var rooms: Array[RoomData] = []
		for room in GameState.rooms:
			if types.has(room.type) and not room.broken:
				rooms.append(room)
		if rooms.is_empty():
			return {}
		ctx["room"] = rooms[rng.randi() % rooms.size()].id

	if needs.has("actor"):
		var pool: Array[SurvivorData] = []
		for s in people:
			if _fits_actor(s, String(needs["actor"])):
				pool.append(s)
		if pool.is_empty():
			return {}
		var actor := pool[rng.randi() % pool.size()]
		ctx["a"] = actor.id
		if String(needs["actor"]) == "lazy_worker":
			ctx["room"] = actor.room_id

	match String(needs.get("pair", "")):
		"rivals":
			var pair := RelationshipSystem.worst_pair(people)
			if pair.is_empty():
				return {}
			ctx["a"] = pair[0].id
			ctx["b"] = pair[1].id
		"friends":
			var pairs := RelationshipSystem.friendly_pairs(people)
			if pairs.is_empty():
				return {}
			var chosen: Array = pairs[rng.randi() % pairs.size()]
			ctx["a"] = (chosen[0] as SurvivorData).id
			ctx["b"] = (chosen[1] as SurvivorData).id

	if needs.get("newcomer", false):
		ctx["newcomer"] = SurvivorFactory.create_random(rng)
	if needs.get("relative", false):
		var found := FamilySystem.make_relative(GameState.get_survivor(int(ctx.get("a", -1))), rng)
		if found.is_empty():
			return {}
		ctx["newcomer"] = found["survivor"]
		ctx["relation"] = found["rel"]

	var ev := {"id": id, "title": def["title"], "category": def["category"], "ctx": ctx}
	ev["text"] = fill(def["text"], ev)
	return ev


static func _fits_actor(s: SurvivorData, rule: String) -> bool:
	match rule:
		"any":
			return true
		"healthy":
			return not s.has_condition("sick") and not s.has_condition("wounded")
		"lazy_worker":
			var room := GameState.get_room(s.room_id)
			return s.has_trait("lazy") and room != null and not room.broken
		"troubled":
			return s.has_trait("nervous") or s.mood < 30.0
		"relative_host":
			return s.is_adult() and not FamilySystem.possible_relations(s).is_empty()
	return false


# --- Текст -----------------------------------------------------------------

static func _person(ev: Dictionary, key: String, helper: SurvivorData) -> SurvivorData:
	match key:
		"h":
			return helper
		"n":
			return ev["ctx"].get("newcomer")
	return GameState.get_survivor(int(ev["ctx"].get(key, -1)))


## Подставляет имена, комнату и формы по полу.
static func fill(text: String, ev: Dictionary, helper: SurvivorData = null) -> String:
	if _gender_re == null:
		_gender_re = RegEx.new()
		_gender_re.compile("\\{([abhn]):([^{}|]*)\\|([^{}|]*)\\}")
	var result := text
	for m in _gender_re.search_all(text):
		var who := _person(ev, m.get_string(1), helper)
		var form := m.get_string(3) if who != null and who.gender == "f" else m.get_string(2)
		result = result.replace(m.get_string(0), form)
	for key in ["a", "b", "h", "n"]:
		var who := _person(ev, key, helper)
		result = result.replace("{%s}" % key, who.first_name if who != null else "Кто-то")
	var newcomer: SurvivorData = ev["ctx"].get("newcomer")
	if newcomer != null:
		result = result.replace("{n_full}", newcomer.full_name())
		result = result.replace("{n_prof}", newcomer.profession_name().to_lower())
		var actor := GameState.get_survivor(int(ev["ctx"].get("a", -1)))
		var rel := String(ev["ctx"].get("relation", ""))
		if actor != null and rel != "":
			result = result.replace("{rel}", String(FamilySystem.LABELS[rel][1 if newcomer.gender == "f" else 0]).to_lower())
	var room := GameState.get_room(int(ev["ctx"].get("room", -1)))
	if room != null:
		result = result.replace("{room}", room.display_name())
	return result


# --- Выбор и проверки --------------------------------------------------------

static func choices_of(ev: Dictionary) -> Array:
	return EventDefs.INFO[ev["id"]]["choices"]


## Сила человека в проверке: навык или, для «social», умение ладить с людьми.
static func check_level(s: SurvivorData, skill: String) -> float:
	if skill == "social":
		var level := 3.0 + s.mood / 50.0
		if s.has_trait("kind"):
			level += 2.0
		if s.has_trait("sociable"):
			level += 2.0
		if s.has_trait("grumpy"):
			level -= 2.0
		return level
	return float(s.effective_skill(skill))


## Кто возьмётся за дело: лучший по нужному навыку (участников спора не зовут мирить самих себя).
static func helper_for(ev: Dictionary, choice: Dictionary) -> SurvivorData:
	var check: Dictionary = choice.get("check", {})
	if not check.has("skill"):
		return null
	var skill := String(check["skill"])
	var exclude: Array = []
	if check.get("exclude_actors", false):
		exclude = [int(ev["ctx"].get("a", -1)), int(ev["ctx"].get("b", -1))]
	var best: SurvivorData = null
	for s in GameState.survivors_in_shelter():
		if exclude.has(s.id):
			continue
		if best == null or check_level(s, skill) > check_level(best, skill):
			best = s
	return best


static func success_chance(choice: Dictionary, helper: SurvivorData) -> float:
	var check: Dictionary = choice["check"]
	if check.has("chance"):
		return float(check["chance"])
	if helper == null:
		return 0.0
	var chance := 0.5 + 0.1 * (check_level(helper, String(check["skill"])) - float(check["difficulty"]))
	if check.get("danger", false):
		if helper.has_trait("brave"):
			chance += 0.1
		if helper.has_trait("nervous"):
			chance -= 0.1
		if helper.profession == "soldier":
			chance += 0.1
	return clampf(chance, 0.1, 0.95)


## Как показать вариант: {"label", "note" (цена, шанс), "enabled"}.
static func choice_view(ev: Dictionary, index: int) -> Dictionary:
	var choice: Dictionary = choices_of(ev)[index]
	var notes: PackedStringArray = []
	var enabled := true
	var cost: Dictionary = choice.get("cost", {})
	for res: String in cost:
		notes.append("%s %d" % [ResourceDefs.name_of(res).to_lower(), int(cost[res])])
		if not GameState.can_afford(res, int(cost[res])):
			enabled = false
	if choice.has("item"):
		var item_id := String(choice["item"])
		if GameState.storage_count(item_id) > 0:
			notes.append("со склада: %s" % ItemDefs.name_of(item_id).to_lower())
		else:
			notes.append("нужно: %s (нет на складе)" % ItemDefs.name_of(item_id).to_lower())
			enabled = false
	if choice.has("check"):
		var helper := helper_for(ev, choice)
		if choice["check"].has("chance"):
			notes.append("шанс %d%%" % roundi(success_chance(choice, null) * 100.0))
		elif helper == null:
			notes.append("некому поручить")
			enabled = false
		else:
			notes.append("%s, шанс %d%%" % [helper.first_name, roundi(success_chance(choice, helper) * 100.0)])
	return {"label": fill(choice["label"], ev), "note": " · ".join(notes), "enabled": enabled}


## Применяет выбор. Возвращает {"text", "kind", "ok"} и записывает итог в летопись.
static func resolve(ev: Dictionary, index: int, rng: RandomNumberGenerator) -> Dictionary:
	if not choice_view(ev, index)["enabled"]:
		return {"text": "Сейчас так поступить нельзя.", "kind": "info", "ok": false}
	var choice: Dictionary = choices_of(ev)[index]
	var cost: Dictionary = choice.get("cost", {})
	for res: String in cost:
		GameState.resources[res] = GameState.get_resource(res) - int(cost[res])
	if choice.has("item"):
		GameState.storage_remove(String(choice["item"]))
	var helper: SurvivorData = null
	var outcome: Dictionary
	if choice.has("check"):
		helper = helper_for(ev, choice)
		outcome = choice["success"] if rng.randf() < success_chance(choice, helper) else choice["fail"]
	else:
		outcome = choice["outcome"]
	var extra := _apply_effects(outcome.get("effects", []), ev, helper, rng)
	var text := fill(outcome["text"], ev, helper)
	if extra != "":
		text = "%s %s" % [text, extra]
	var kind := String(outcome.get("kind", "info"))
	GameState.log_event("%s. %s" % [ev["title"], text], kind)
	GameState.emit_all()
	return {"text": text, "kind": kind, "ok": true}


static func _targets(target: String, ev: Dictionary, helper: SurvivorData) -> Array[SurvivorData]:
	var result: Array[SurvivorData] = []
	match target:
		"a", "b":
			var s := GameState.get_survivor(int(ev["ctx"].get(target, -1)))
			if s != null:
				result.append(s)
		"ab":
			for key in ["a", "b"]:
				var s := GameState.get_survivor(int(ev["ctx"].get(key, -1)))
				if s != null:
					result.append(s)
		"h":
			if helper != null:
				result.append(helper)
		"all":
			result = GameState.survivors_in_shelter()
		"kind":
			for s in GameState.survivors_in_shelter():
				if s.has_trait("kind"):
					result.append(s)
	return result


static func _apply_effects(effects: Array, ev: Dictionary, helper: SurvivorData, rng: RandomNumberGenerator) -> String:
	var notes: PackedStringArray = []
	var room := GameState.get_room(int(ev["ctx"].get("room", -1)))
	for e: Dictionary in effects:
		match String(e["type"]):
			"resource":
				var res := String(e["id"])
				var amount := int(e.get("amount", 0))
				if e.has("percent"):
					amount = -maxi(int(e.get("min", 0)), roundi(GameState.get_resource(res) * float(e["percent"])))
				GameState.resources[res] = clampi(GameState.get_resource(res) + amount, 0, GameState.get_cap(res))
			"room_damage":
				if room != null and room.can_break():
					room.condition = clampf(room.condition - float(e["amount"]), 0.0, 100.0)
					if room.condition <= 0.0:
						room.broken = true
			"room_break":
				if room != null and room.can_break():
					room.broken = true
					room.condition = minf(room.condition, 20.0)
			"room_repair":
				if room != null:
					room.condition = clampf(room.condition + float(e["amount"]), 0.0, 100.0)
			"room_product":
				if room != null and String(room.get_def()["produces"]) != "":
					var product := String(room.get_def()["produces"])
					GameState.resources[product] = clampi(GameState.get_resource(product) + int(e["amount"]), 0, GameState.get_cap(product))
			"health":
				for s in _targets(String(e["target"]), ev, helper):
					var amount := float(e["amount"])
					if amount < 0.0 and s.has_trait("tough"):
						amount *= 0.5
					s.change_health(amount)
					if amount < 0.0:
						s.health = maxf(s.health, 1.0)
			"mood":
				for s in _targets(String(e["target"]), ev, helper):
					var amount := float(e["amount"])
					if amount < 0.0 and s.has_trait("nervous"):
						amount *= 1.5
					if amount < 0.0 and s.has_trait("pessimist"):
						amount *= 0.5
					s.change_mood(amount)
			"relation":
				var a := GameState.get_survivor(int(ev["ctx"].get("a", -1)))
				var b := GameState.get_survivor(int(ev["ctx"].get("b", -1)))
				if a != null and b != null:
					a.change_relation(b.id, float(e["amount"]))
					b.change_relation(a.id, float(e["amount"]))
			"condition":
				for s in _targets(String(e["target"]), ev, helper):
					s.set_condition(String(e["id"]), true)
			"unassign":
				for s in _targets(String(e["target"]), ev, helper):
					GameState.assign(s.id, -1)
			"xp":
				for s in _targets(String(e["target"]), ev, helper):
					s.add_skill_xp(String(e["skill"]), int(e["amount"]))
			"spread_sickness":
				var sick: PackedStringArray = []
				for s in GameState.survivors_in_shelter():
					if not s.has_condition("sick") and rng.randf() < float(e["chance"]):
						s.set_condition("sick", true)
						sick.append(s.first_name)
				if not sick.is_empty():
					notes.append("Заболели ещё: %s." % ", ".join(sick))
			"cache":
				var item_id: String = ItemDefs.LOOT_TABLE[rng.randi() % ItemDefs.LOOT_TABLE.size()]
				var metal := rng.randi_range(10, 20)
				GameState.storage_add(item_id)
				GameState.resources["metal"] = mini(GameState.get_resource("metal") + metal, GameState.get_cap("metal"))
				notes.append("%s и %d металла." % [ItemDefs.name_of(item_id).to_lower(), metal])
			"newcomer":
				var n: SurvivorData = ev["ctx"].get("newcomer")
				if n != null and GameState.has_free_bed() and GameState.get_survivor(n.id) == null:
					GameState.add_survivor(n)
			"relative":
				var n: SurvivorData = ev["ctx"].get("newcomer")
				var host := GameState.get_survivor(int(ev["ctx"].get("a", -1)))
				if n != null and host != null and GameState.has_free_bed():
					GameState.add_survivor(n)
					FamilySystem.link(host, n, String(ev["ctx"]["relation"]))
	return " ".join(notes)
