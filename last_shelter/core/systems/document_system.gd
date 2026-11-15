class_name DocumentSystem
extends RefCounted
## Находки в вылазках: документы, записи, снаряжение и сигналы. Каждая находка — шаг к разгадке
## Катастрофы; житель, видевший то же самое в ту ночь, узнаёт это и вспоминает.

const BASE_CHANCE := 0.4


## Что ещё можно найти в этом месте.
static func remaining(location: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in LocationDefs.INFO[location].get("docs", []):
		if not GameState.documents.has(id):
			result.append(id)
	return result


static func find_chance(s: SurvivorData) -> float:
	var chance := BASE_CHANCE + s.effective_skill("scavenging") * 0.04
	if s.has_trait("curious"):
		chance += 0.15
	return clampf(chance, 0.0, 0.9)


## Пробует найти что-то новое после вылазки. Возвращает id находки или "".
static func try_find(s: SurvivorData, location: String, rng: RandomNumberGenerator, lines: Array[Dictionary],
		force: bool = false) -> String:
	var pool := remaining(location)
	if pool.is_empty() or (not force and rng.randf() >= find_chance(s)):
		return ""
	var id: String = pool[rng.randi() % pool.size()]
	reveal(id, lines, s)
	return id


## Записывает находку в архив, кладёт снаряжение на склад и ищет тех, кто узнаёт увиденное.
static func reveal(id: String, lines: Array[Dictionary], finder: SurvivorData = null) -> void:
	if GameState.documents.has(id) or not DocumentDefs.exists(id):
		return
	var def: Dictionary = DocumentDefs.INFO[id]
	GameState.documents.append(id)
	var who := finder.first_name if finder != null else "Жители"
	lines.append({"text": "%s: %s «%s». %s" % [who, String(DocumentDefs.KIND_NAMES[def["kind"]]).to_lower(), def["title"], def["text"]],
		"kind": "story", "log": true})
	if def.has("item"):
		GameState.storage_add(String(def["item"]))
		lines.append({"text": "На склад: %s." % ItemDefs.name_of(String(def["item"])).to_lower(), "kind": "good"})
	var witness := witness_of(id)
	if witness != null:
		witness.change_mood(-4.0)
		lines.append({"text": "%s узнаёт это: «%s» Значит, %s не %s." % [witness.first_name, _memory(witness),
			witness.by_gender("он", "она"), witness.by_gender("ошибался", "ошибалась")], "kind": "story", "log": true})
	GameState.world_changed.emit()


## Житель, чья биография перекликается с находкой.
static func witness_of(id: String) -> SurvivorData:
	var hint := String(DocumentDefs.INFO[id].get("bio_hint", ""))
	if hint == "":
		return null
	for s in GameState.survivors:
		if s.bio.findn(hint) >= 0:
			return s
	return null


## Фраза из биографии, в которой житель вспоминает ту ночь.
static func _memory(s: SurvivorData) -> String:
	for sentence in s.bio.split(". "):
		for id: String in DocumentDefs.INFO:
			var hint := String(DocumentDefs.INFO[id].get("bio_hint", ""))
			if hint != "" and sentence.findn(hint) >= 0:
				return sentence.trim_suffix(".") + "."
	return "Я видел это своими глазами."


## Сколько находок всего и сколько уже найдено.
static func progress() -> Vector2i:
	return Vector2i(GameState.documents.size(), DocumentDefs.INFO.size())
