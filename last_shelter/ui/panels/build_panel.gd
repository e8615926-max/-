class_name BuildPanel
extends BasePanel
## Меню строительства: выбор типа комнаты. После выбора игрок указывает место в убежище.

signal build_requested(type: String)


## Маленькое превью комнаты той же графикой, что и в убежище.
class RoomPreview extends Control:
	var type: String = ""

	func _init(room_type: String) -> void:
		type = room_type
		custom_minimum_size = Vector2(RoomPainter.W, RoomPainter.H) * 2.0
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
		RoomPainter.paint(self, type, Vector2.ZERO, 0.0, true)


var _list: VBoxContainer


func _init() -> void:
	super("Строительство", Vector2(980, 590))
	var parts := UI.scroll_list(8)
	content.add_child(parts[0])
	_list = parts[1]


func _ready() -> void:
	GameState.resources_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	UI.clear(_list)
	for type in RoomDefs.BUILD_ORDER:
		var def := RoomDefs.get_def(type)
		var cost := RoomDefs.cost_of(type)
		var research := RoomDefs.research_of(type)
		var locked := research != "" and not ResearchSystem.has(research)

		var card := UI.card(UITheme.PANEL_LIGHT, 10)
		var row := UI.hbox(16)
		card.add_child(row)
		row.add_child(RoomPreview.new(type))

		var info := UI.vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label(def["name"], 22))
		info.add_child(UI.wrap_label(def["desc"], 16))
		var stats := UI.cost_row(cost)
		if int(def["power"]) > 0:
			stats.add_child(UI.icon("power", 2))
			stats.add_child(UI.label("−%d в день" % int(def["power"]), 16, UITheme.TEXT_DIM))
		if int(def["slots"]) > 0:
			stats.add_child(UI.icon("survivors", 2))
			stats.add_child(UI.label("мест: %d" % int(def["slots"]), 16, UITheme.TEXT_DIM))
		info.add_child(stats)
		if locked:
			info.add_child(UI.label("Нужно исследование: %s" % ResearchDefs.name_of(research), 16, UITheme.ACCENT))
		row.add_child(info)

		var b := UI.accent_button("Построить", 170, 64)
		UI.pass_scroll(b)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = locked or not GameState.can_pay(cost)
		b.pressed.connect(func() -> void: build_requested.emit(type))
		row.add_child(b)
		_list.add_child(card)
