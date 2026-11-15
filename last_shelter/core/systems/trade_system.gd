class_name TradeSystem
extends RefCounted
## Бродячие торговцы: приходят раз в несколько дней, стоят у ворот пару дней,
## у каждого свой набор сделок и редкий товар. Им же можно продать лишние вещи со склада.

const FIRST_DAY := 3
const GAP := [4, 7]
## Сколько получаем за предмет: доля ценности в «валюте» торговца.
const SELL_RATE := {"metal": 0.6, "food": 0.5, "medicine": 0.15}


static func present() -> bool:
	return not GameState.merchant.is_empty()


## Наводит порядок в сохранённом торговце; битые данные — нет торговца.
static func sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		return {}
	var d: Dictionary = raw
	var id := String(d.get("id", ""))
	if not MerchantDefs.INFO.has(id):
		return {}
	var deals: Array = []
	for deal in d.get("deals", []):
		if not deal is Dictionary:
			continue
		var clean := {"give": _clean_cost(deal.get("give", {})), "stock": maxi(int(deal.get("stock", 0)), 0)}
		if deal.has("item"):
			if not ItemDefs.exists(String(deal["item"])):
				continue
			clean["item"] = String(deal["item"])
		else:
			clean["get"] = _clean_cost(deal.get("get", {}))
		clean["rare"] = bool(deal.get("rare", false))
		deals.append(clean)
	return {"id": id, "days_left": maxi(int(d.get("days_left", 1)), 1), "deals": deals}


static func _clean_cost(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for res: String in raw:
			if ResourceDefs.IDS.has(res) and int(raw[res]) > 0:
				out[res] = int(raw[res])
	return out


## Новый торговец с набором сделок из своего пула. Цены немного плавают.
static func make_visit(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var def: Dictionary = MerchantDefs.INFO[id]
	var pool: Array = (def["deals"] as Array).duplicate()
	var deals: Array = []
	while not pool.is_empty() and deals.size() < MerchantDefs.DEALS_PER_VISIT:
		var deal: Dictionary = pool.pop_at(rng.randi() % pool.size())
		deals.append(_priced(deal, rng, rng.randi_range(1, 3), false))
	var rare: Array = def["rare"]
	if not rare.is_empty() and rng.randf() < 0.6:
		deals.append(_priced(rare[rng.randi() % rare.size()], rng, 1, true))
	return {"id": id, "days_left": MerchantDefs.VISIT_DAYS, "deals": deals}


static func _priced(deal: Dictionary, rng: RandomNumberGenerator, stock: int, rare: bool) -> Dictionary:
	var give := {}
	var factor := rng.randf_range(0.85, 1.2)
	for res: String in deal["give"]:
		give[res] = maxi(1, roundi(int(deal["give"][res]) * factor))
	var out := {"give": give, "stock": stock, "rare": rare}
	if deal.has("item"):
		out["item"] = deal["item"]
	else:
		out["get"] = (deal["get"] as Dictionary).duplicate()
	return out


## Раз в день: торговец уходит или приходит новый.
static func daily(lines: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	if present():
		GameState.merchant["days_left"] = int(GameState.merchant["days_left"]) - 1
		if int(GameState.merchant["days_left"]) <= 0:
			lines.append({"text": "%s: торговец уходит дальше." % MerchantDefs.name_of(GameState.merchant["id"]), "kind": "info"})
			GameState.merchant = {}
			GameState.next_merchant_day = GameState.day + 1 + rng.randi_range(int(GAP[0]), int(GAP[1]))
		GameState.world_changed.emit()
		return
	# day — номер дня, который сейчас закончился; торговец будет ждать утром.
	if GameState.day + 1 >= GameState.next_merchant_day:
		var ids := MerchantDefs.INFO.keys()
		var id: String = ids[rng.randi() % ids.size()]
		GameState.merchant = make_visit(id, rng)
		lines.append({"text": "У ворот торговец: %s. %s" % [MerchantDefs.name_of(id), MerchantDefs.INFO[id]["greeting"]],
			"kind": "good", "log": true, "sound": "merchant"})
		GameState.world_changed.emit()


static func deal_error(index: int) -> String:
	if not present():
		return "Торговца нет"
	var deals: Array = GameState.merchant["deals"]
	if index < 0 or index >= deals.size():
		return "Нет такой сделки"
	var deal: Dictionary = deals[index]
	if int(deal["stock"]) <= 0:
		return "Распродано"
	var missing := GameState.missing_resource(deal["give"])
	if missing != "":
		return "Не хватает: %s" % ResourceDefs.name_of(missing).to_lower()
	return ""


static func buy(index: int) -> bool:
	if deal_error(index) != "":
		return false
	var deal: Dictionary = GameState.merchant["deals"][index]
	GameState.pay(deal["give"])
	if deal.has("item"):
		GameState.storage_add(String(deal["item"]))
		GameState.log_event("Куплено у торговца: %s." % ItemDefs.name_of(String(deal["item"])).to_lower(), "good")
	else:
		for res: String in deal["get"]:
			GameState.resources[res] = mini(GameState.get_resource(res) + int(deal["get"][res]), GameState.get_cap(res))
	deal["stock"] = int(deal["stock"]) - 1
	GameState.resources_changed.emit()
	GameState.storage_changed.emit()
	GameState.world_changed.emit()
	return true


## Чем торговец платит за вещи.
static func currency() -> String:
	if not present():
		return ""
	return String(MerchantDefs.INFO[GameState.merchant["id"]]["buys"])


static func sell_price(item_id: String) -> int:
	var cur := currency()
	if cur == "":
		return 0
	return maxi(1, roundi(ItemDefs.value_of(item_id) * float(SELL_RATE[cur])))


static func sell_error(item_id: String) -> String:
	if not present():
		return "Торговца нет"
	if GameState.storage_count(item_id) <= 0:
		return "Нет на складе"
	if GameState.get_resource(currency()) >= GameState.get_cap(currency()):
		return "Склад полон"
	return ""


static func sell(item_id: String) -> bool:
	if sell_error(item_id) != "":
		return false
	var cur := currency()
	var price := sell_price(item_id)
	GameState.storage_remove(item_id)
	GameState.resources[cur] = mini(GameState.get_resource(cur) + price, GameState.get_cap(cur))
	GameState.resources_changed.emit()
	GameState.storage_changed.emit()
	GameState.world_changed.emit()
	return true
