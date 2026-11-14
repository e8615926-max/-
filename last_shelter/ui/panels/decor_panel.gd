class_name DecorPanel
extends BasePanel
## Выбор украшения для места в комнате.

signal back_requested

var room_id: int = 0
var slot: int = 0
var _list: VBoxContainer


func _init(id: int, slot_index: int) -> void:
	super("Украшение", Vector2(820, 580))
	room_id = id
	slot = slot_index
	add_back_button().pressed.connect(func() -> void: back_requested.emit())
	var parts := UI.scroll_list(8)
	content.add_child(parts[0])
	_list = parts[1]


func _ready() -> void:
	GameState.resources_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var room := GameState.get_room(room_id)
	if room == null:
		close()
		return
	UI.clear(_list)
	set_title("%s · %s" % [room.title(), "слева" if slot == 0 else "справа"])
	_list.add_child(UI.wrap_label("Украшения добавляют уют: каждое очко уюта поднимает настроение всех жителей (до %d очков на убежище)." % DecorDefs.COMFORT_CAP, 16))
	if String(room.decor[slot]) != "":
		var remove := UI.button("Убрать: %s" % DecorDefs.name_of(String(room.decor[slot])), 0, 56)
		UI.pass_scroll(remove)
		remove.pressed.connect(func() -> void:
			GameState.set_decor(room, slot, "")
			back_requested.emit())
		_list.add_child(remove)
	for id in DecorDefs.ORDER:
		var def: Dictionary = DecorDefs.INFO[id]
		var card := UI.card(UITheme.PANEL_LIGHT, 8)
		var row := UI.hbox(12)
		card.add_child(row)
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label("%s · уют +%d" % [def["name"], int(def["comfort"])], 19))
		var error := GameState.decor_error(id)
		if error.begins_with("Нужно"):
			info.add_child(UI.label(error, 15, UITheme.ACCENT))
		else:
			info.add_child(UI.cost_row(def["cost"], 16))
		row.add_child(info)
		var b := UI.accent_button("Поставить", 150, 52)
		UI.pass_scroll(b)
		b.disabled = error != ""
		b.pressed.connect(func() -> void:
			if GameState.set_decor(room, slot, id):
				back_requested.emit())
		row.add_child(b)
		_list.add_child(card)
