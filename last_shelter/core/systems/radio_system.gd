class_name RadioSystem
extends RefCounted
## Радиорубка: радисты копят сигнал; когда его хватает — убежище слышит передачу.
## Сюжетные передачи открывают места для вылазок и понемногу раскрывают тайну Катастрофы.

const BASE_THRESHOLD := 12.0
const THRESHOLD_STEP := 4.0


static func signal_per_day(unavailable: Array[int] = []) -> float:
	var total := 0.0
	for room in GameState.rooms:
		if room.type != "radio" or room.broken or unavailable.has(room.id):
			continue
		for s in GameState.workers_of(room.id):
			total += (room.base_output() + s.effective_skill("science")) * DaySystem.work_factor(s, room) \
				* RoomDefs.tier_output(room.tier)
	return total * ResearchSystem.signal_mult()


## Сколько сигнала нужно до следующей передачи.
static func threshold() -> float:
	return BASE_THRESHOLD + THRESHOLD_STEP * GameState.radio_log.size()


## Следующая сюжетная передача, которую уже можно услышать, или {}.
static func next_story() -> Dictionary:
	for t: Dictionary in TransmissionDefs.STORY:
		if GameState.radio_heard.has(t["id"]) or GameState.radio_pending == t["id"]:
			continue
		if GameState.day < int(t.get("min_day", 1)):
			continue
		return t
	return {}


static func _find(id: String) -> Dictionary:
	for t: Dictionary in TransmissionDefs.STORY:
		if t["id"] == id:
			return t
	return {}


static func daily(lines: Array[Dictionary], unavailable: Array[int], rng: RandomNumberGenerator) -> void:
	# Шифровка, которую научились читать, расшифровывается сразу.
	if GameState.radio_pending != "":
		var pending := _find(GameState.radio_pending)
		if pending.is_empty() or ResearchSystem.has(String(pending.get("requires", ""))):
			GameState.radio_pending = ""
			if not pending.is_empty():
				_receive(pending, lines, true)
	var power := signal_per_day(unavailable)
	if power <= 0.0:
		return
	GameState.radio_progress += power
	if GameState.radio_progress < threshold():
		GameState.radio_changed.emit()
		return
	GameState.radio_progress -= threshold()
	var story := next_story()
	if story.is_empty():
		var filler: String = TransmissionDefs.FILLER[rng.randi() % TransmissionDefs.FILLER.size()]
		_add_log("Эфир", filler)
		lines.append({"text": "Радиорубка: %s" % filler, "kind": "info"})
	elif story.has("requires") and not ResearchSystem.has(String(story["requires"])):
		GameState.radio_pending = story["id"]
		_add_log(String(story["title"]), String(story["encrypted"]))
		lines.append({"text": "Радиорубка поймала шифровку «%s». Нужна дешифровка." % story["title"], "kind": "info", "log": true})
	else:
		_receive(story, lines, false)
	GameState.radio_changed.emit()


static func _receive(t: Dictionary, lines: Array[Dictionary], decoded: bool) -> void:
	GameState.radio_heard.append(String(t["id"]))
	_add_log(String(t["title"]), String(t["text"]))
	var text := "%s «%s»: %s" % ["Расшифрована передача" if decoded else "Радиорубка поймала передачу", t["title"], t["text"]]
	var place := String(t.get("unlock", ""))
	if place != "" and not GameState.locations.has(place):
		GameState.locations.append(place)
		text += " Новое место для вылазок: %s." % LocationDefs.name_of(place)
	lines.append({"text": text, "kind": "story", "log": true})
	GameState.radio_changed.emit()


static func _add_log(title: String, text: String) -> void:
	GameState.radio_log.append({"day": GameState.day, "title": title, "text": text})
