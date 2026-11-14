class_name RadioPanel
extends BasePanel
## Журнал эфира: пойманные передачи, свежие сверху, и сигнал до следующей.

var _list: VBoxContainer


func _init() -> void:
	super("Журнал эфира", Vector2(920, 590))
	var parts := UI.scroll_list(8)
	content.add_child(parts[0])
	_list = parts[1]


func _ready() -> void:
	GameState.radio_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	UI.clear(_list)
	var head := UI.card(UITheme.PANEL_DARK, 12)
	var box := UI.vbox(6)
	head.add_child(box)
	if GameState.first_room_of_type("radio") == null:
		box.add_child(UI.wrap_label("Постройте радиорубку и посадите туда радиста: наука помогает ловить слабые сигналы.", 17, UITheme.ACCENT))
	box.add_child(UI.label("Сигнал до следующей передачи: %d из %d · в день %.1f" % [roundi(GameState.radio_progress),
		roundi(RadioSystem.threshold()), RadioSystem.signal_per_day()], 17))
	var bar := UI.bar(GameState.radio_progress, 0.0, RadioSystem.threshold(), UITheme.ACCENT, Vector2(200, 14))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(bar)
	if GameState.radio_pending != "":
		box.add_child(UI.label("Есть шифровка — нужна «%s»." % ResearchDefs.name_of("radio_decoding"), 15, UITheme.ACCENT))
	var places: PackedStringArray = []
	for id in GameState.locations:
		places.append(LocationDefs.name_of(id))
	box.add_child(UI.wrap_label("Известные места для вылазок: %s." % ", ".join(places), 15, UITheme.TEAL))
	_list.add_child(head)
	if GameState.radio_log.is_empty():
		_list.add_child(UI.label("Эфир пока молчит.", 17, UITheme.TEXT_DIM))
	for i in range(GameState.radio_log.size() - 1, -1, -1):
		var entry: Dictionary = GameState.radio_log[i]
		var card := UI.card(UITheme.PANEL_LIGHT, 10)
		var entry_box := UI.vbox(4)
		card.add_child(entry_box)
		entry_box.add_child(UI.label("День %d · %s" % [int(entry["day"]), entry["title"]], 18, UITheme.ACCENT))
		entry_box.add_child(UI.wrap_label(String(entry["text"]), 17, UITheme.TEXT))
		_list.add_child(card)
