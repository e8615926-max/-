class_name ShelterSystem
extends RefCounted
## Другие общины: отношения, помощь, просьбы, обмен, подарки друзей и угрозы недругов.
## Община становится известна, когда открыто её место для вылазок.

const HELP_COOLDOWN := 3
const REQUEST_COOLDOWN := 5
const REQUEST_MIN := 30
const TRADE_MIN := -40
const ALLY_LEVEL := 60


static func is_known(id: String) -> bool:
	return GameState.locations.has(String(ShelterDefs.INFO[id]["location"]))


static func known() -> Array[String]:
	var result: Array[String] = []
	for id: String in ShelterDefs.INFO:
		if is_known(id):
			result.append(id)
	return result


static func state(id: String) -> Dictionary:
	if not GameState.shelters.has(id):
		GameState.shelters[id] = {"relation": int(ShelterDefs.INFO[id]["relation"]),
			"help_day": -99, "request_day": -99, "trade_day": -99}
	return GameState.shelters[id]


static func relation(id: String) -> int:
	return int(state(id)["relation"])


static func change_relation(id: String, amount: int) -> void:
	var st := state(id)
	st["relation"] = clampi(int(st["relation"]) + amount, -100, 100)
	GameState.world_changed.emit()


static func relation_label(value: int) -> String:
	if value >= ALLY_LEVEL:
		return "союзники"
	if value >= 25:
		return "дружелюбны"
	if value >= -10:
		return "настороженны"
	if value >= -50:
		return "враждебны"
	return "война"


# --- Действия -----------------------------------------------------------------

static func help_error(id: String) -> String:
	if not is_known(id):
		return "Об этой общине ничего не известно"
	var st := state(id)
	if GameState.day - int(st["help_day"]) < HELP_COOLDOWN:
		return "Недавно уже помогали"
	var missing := GameState.missing_resource(ShelterDefs.INFO[id]["needs"])
	if missing != "":
		return "Не хватает: %s" % ResourceDefs.name_of(missing).to_lower()
	return ""


## Отправить общине то, в чём она нуждается. Отношения заметно улучшаются.
static func send_help(id: String) -> bool:
	if help_error(id) != "":
		return false
	GameState.pay(ShelterDefs.INFO[id]["needs"])
	state(id)["help_day"] = GameState.day
	change_relation(id, 12)
	GameState.log_event("Отправили помощь: %s (%s)." % [ShelterDefs.name_of(id),
		ResourceDefs.cost_text(ShelterDefs.INFO[id]["needs"])], "good")
	GameState.resources_changed.emit()
	return true


static func request_error(id: String) -> String:
	if not is_known(id):
		return "Об этой общине ничего не известно"
	if relation(id) < REQUEST_MIN:
		return "Нужны отношения от %d" % REQUEST_MIN
	if GameState.day - int(state(id)["request_day"]) < REQUEST_COOLDOWN:
		return "Недавно уже просили"
	return ""


## Попросить о помощи: соседи делятся, но злоупотреблять не стоит.
static func request_help(id: String) -> bool:
	if request_error(id) != "":
		return false
	var offers: Dictionary = ShelterDefs.INFO[id]["offers"]
	_receive(offers)
	state(id)["request_day"] = GameState.day
	change_relation(id, -6)
	GameState.log_event("%s поделились: %s." % [ShelterDefs.name_of(id), ResourceDefs.cost_text(offers)], "good")
	return true


## Цена сделки зависит от отношений: друзья уступают, недруги дерут втридорога.
static func price_factor(id: String) -> float:
	return clampf(1.15 - relation(id) / 250.0, 0.75, 1.5)


static func deal_cost(id: String, index: int) -> Dictionary:
	var give: Dictionary = ShelterDefs.INFO[id]["deals"][index]["give"]
	var cost := {}
	for res: String in give:
		cost[res] = maxi(1, roundi(int(give[res]) * price_factor(id)))
	return cost


static func trade_error(id: String, index: int) -> String:
	if not is_known(id):
		return "Об этой общине ничего не известно"
	if relation(id) < TRADE_MIN:
		return "С нами не хотят говорить"
	if int(state(id)["trade_day"]) == GameState.day:
		return "Сегодня уже меняли"
	var deals: Array = ShelterDefs.INFO[id]["deals"]
	if index < 0 or index >= deals.size():
		return "Нет такой сделки"
	var missing := GameState.missing_resource(deal_cost(id, index))
	if missing != "":
		return "Не хватает: %s" % ResourceDefs.name_of(missing).to_lower()
	return ""


static func trade(id: String, index: int) -> bool:
	if trade_error(id, index) != "":
		return false
	var deal: Dictionary = ShelterDefs.INFO[id]["deals"][index]
	GameState.pay(deal_cost(id, index))
	if deal.has("item"):
		GameState.storage_add(String(deal["item"]))
		GameState.log_event("Выменяли у общины «%s»: %s." % [ShelterDefs.name_of(id), ItemDefs.name_of(String(deal["item"])).to_lower()], "good")
	else:
		_receive(deal["get"])
	state(id)["trade_day"] = GameState.day
	change_relation(id, 2)
	GameState.resources_changed.emit()
	GameState.storage_changed.emit()
	return true


static func _receive(gain: Dictionary) -> void:
	for res: String in gain:
		GameState.resources[res] = mini(GameState.get_resource(res) + int(gain[res]), GameState.get_cap(res))
	GameState.resources_changed.emit()


# --- Каждый день ---------------------------------------------------------------

## Союзники иногда присылают подарок, отношения понемногу возвращаются к обычным.
static func daily(lines: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for id in known():
		var st := state(id)
		var base := int(ShelterDefs.INFO[id]["relation"])
		var rel := int(st["relation"])
		if GameState.day % 4 == 0 and rel != base:
			st["relation"] = rel + (1 if rel < base else -1)
		if rel >= ALLY_LEVEL and rng.randf() < 0.1:
			var gift := {}
			var offers: Dictionary = ShelterDefs.INFO[id]["offers"]
			for res: String in offers:
				gift[res] = maxi(1, int(offers[res]) / 2)
			_receive(gift)
			lines.append({"text": "%s прислали подарок в знак дружбы: %s." % [ShelterDefs.name_of(id), ResourceDefs.cost_text(gift)],
				"kind": "good", "log": true})
	GameState.world_changed.emit()
