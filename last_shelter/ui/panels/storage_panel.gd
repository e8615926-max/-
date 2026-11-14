class_name StoragePanel
extends BasePanel
## Склад: запасы ресурсов с прогнозом и общие предметы.

var _list: VBoxContainer


func _init() -> void:
	super("Склад", Vector2(900, 580))
	var parts := UI.scroll_list(8)
	content.add_child(parts[0])
	_list = parts[1]


func _ready() -> void:
	GameState.resources_changed.connect(_refresh)
	GameState.storage_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	UI.clear(_list)
	var forecast: Dictionary = DaySystem.compute_economy()["delta"]

	_list.add_child(UI.section_title("Ресурсы"))
	for res in ResourceDefs.IDS:
		var value := GameState.get_resource(res)
		var cap := GameState.get_cap(res)
		var change := int(forecast[res])
		var card := UI.card(UITheme.PANEL_LIGHT, 10)
		var row := UI.hbox(12)
		card.add_child(row)
		row.add_child(UI.icon(ResourceDefs.INFO[res]["icon"], 3))
		var name_label := UI.label(ResourceDefs.name_of(res), 20)
		name_label.custom_minimum_size.x = 110
		row.add_child(name_label)
		var bar := UI.bar(value, 0.0, cap, ResourceDefs.get_color(res), Vector2(200, 20))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		var amount := UI.label("%d / %d" % [value, cap], 19)
		amount.custom_minimum_size.x = 110
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(amount)
		var color := UITheme.TEXT_DIM
		if change > 0:
			color = UITheme.GOOD
		elif change < 0:
			color = UITheme.BAD
		var delta := UI.label("%s в день" % UI.signed(change), 17, color)
		delta.custom_minimum_size.x = 120
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(delta)
		_list.add_child(card)
	_list.add_child(UI.wrap_label("Вместимость увеличивают складские комнаты. Излишки сверх вместимости пропадают.", 15))

	_list.add_child(UI.section_title("Предметы"))
	if GameState.storage.is_empty():
		var empty := UI.card(UITheme.PANEL_DARK, 12)
		empty.add_child(UI.label("На складе нет предметов. Их приносят из экспедиций.", 17, UITheme.TEXT_DIM))
		_list.add_child(empty)
	for item_id: String in GameState.storage:
		var card := UI.card(UITheme.PANEL_LIGHT, 8)
		var row := UI.hbox(12)
		card.add_child(row)
		var icon := UI.texture(PixelIcons.item_icon(item_id, 4))
		icon.custom_minimum_size = Vector2(44, 44)
		row.add_child(icon)
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label(ItemDefs.name_of(item_id), 19))
		info.add_child(UI.wrap_label(ItemDefs.get_def(item_id)["desc"], 15))
		row.add_child(info)
		row.add_child(UI.label(ItemDefs.effect_text(item_id), 16, UITheme.TEAL))
		row.add_child(UI.label("×%d" % GameState.storage_count(item_id), 22, UITheme.ACCENT))
		_list.add_child(card)
	if not GameState.storage.is_empty():
		_list.add_child(UI.wrap_label("Выдать предмет можно в профиле выжившего, раздел «Инвентарь».", 15))
