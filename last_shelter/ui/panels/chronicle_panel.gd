class_name ChroniclePanel
extends BasePanel
## Летопись убежища: важные события по дням, свежие сверху.

const KIND_COLORS := {"good": UITheme.GOOD, "bad": UITheme.BAD, "info": UITheme.TEXT, "story": UITheme.TEAL}

var _list: VBoxContainer


func _init() -> void:
	super("Летопись убежища", Vector2(920, 590))
	var parts := UI.scroll_list(6)
	content.add_child(parts[0])
	_list = parts[1]


func _ready() -> void:
	GameState.chronicle_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	UI.clear(_list)
	if GameState.chronicle.is_empty():
		var empty := UI.card(UITheme.PANEL_DARK, 12)
		empty.add_child(UI.label("Пока ничего не записано.", 18, UITheme.TEXT_DIM))
		_list.add_child(empty)
		return
	var current_day := -1
	for i in range(GameState.chronicle.size() - 1, -1, -1):
		var entry: Dictionary = GameState.chronicle[i]
		var entry_day := int(entry["day"])
		if entry_day != current_day:
			current_day = entry_day
			_list.add_child(UI.section_title("День %d" % entry_day))
		var row := UI.hbox(10)
		var color: Color = KIND_COLORS.get(entry.get("kind", "info"), UITheme.TEXT)
		var mark := ColorRect.new()
		mark.color = color
		mark.custom_minimum_size = Vector2(6, 6)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		row.add_child(UI.wrap_label(String(entry["text"]), 18, color))
		_list.add_child(row)
