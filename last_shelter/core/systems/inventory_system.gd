class_name InventorySystem
extends RefCounted
## Операции с личными вещами выживших и общим складом.
## Все функции возвращают true при успехе и сами рассылают сигналы GameState.


static func has_space(s: SurvivorData) -> bool:
	return s.inventory.size() < SurvivorData.MAX_INVENTORY


## Склад -> рюкзак.
static func take_from_storage(s: SurvivorData, item_id: String) -> bool:
	if s.on_expedition or not has_space(s) or GameState.storage_count(item_id) <= 0:
		return false
	s.inventory.append(item_id)
	GameState.storage_remove(item_id)
	GameState.survivors_changed.emit()
	return true


## Рюкзак -> склад.
static func put_to_storage(s: SurvivorData, index: int) -> bool:
	if s.on_expedition or index < 0 or index >= s.inventory.size():
		return false
	var item_id: String = s.inventory[index]
	s.inventory.remove_at(index)
	GameState.storage_add(item_id)
	GameState.survivors_changed.emit()
	return true


## Надеть предмет из рюкзака. Уже надетый в этот слот предмет вернётся в рюкзак.
static func equip(s: SurvivorData, index: int) -> bool:
	if index < 0 or index >= s.inventory.size():
		return false
	var item_id: String = s.inventory[index]
	var slot := ItemDefs.get_slot(item_id)
	if slot == "":
		return false
	var previous: String = s.equipment[slot]
	s.equipment[slot] = item_id
	if previous != "":
		s.inventory[index] = previous
	else:
		s.inventory.remove_at(index)
	GameState.survivors_changed.emit()
	return true


## Снять предмет в рюкзак.
static func unequip(s: SurvivorData, slot: String) -> bool:
	var item_id: String = s.equipment.get(slot, "")
	if item_id == "" or not has_space(s):
		return false
	s.equipment[slot] = ""
	s.inventory.append(item_id)
	GameState.survivors_changed.emit()
	return true


## Использовать расходник из рюкзака.
static func use_item(s: SurvivorData, index: int) -> bool:
	if index < 0 or index >= s.inventory.size():
		return false
	var item_id: String = s.inventory[index]
	if not ItemDefs.is_usable(item_id):
		return false
	var use: Dictionary = ItemDefs.get_def(item_id)["use"]
	if use.has("health"):
		s.change_health(float(use["health"]))
		if s.health >= s.max_health * 0.6:
			s.set_condition("wounded", false)
	if use.has("mood"):
		s.change_mood(float(use["mood"]))
	s.inventory.remove_at(index)
	GameState.survivors_changed.emit()
	return true
