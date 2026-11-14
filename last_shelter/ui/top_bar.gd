class_name TopBar
extends PanelContainer
## Верхняя панель: день, ресурсы с прогнозом на завтра, кнопка выживших и меню.

signal menu_pressed
signal survivors_pressed

const HEIGHT := 76

var _day_label: Label
var _value_labels: Dictionary = {}
var _delta_labels: Dictionary = {}
var _survivors_button: Button
var _style: StyleBoxFlat


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	_style = UITheme.box(UITheme.PANEL, UITheme.BORDER, 0, 8)
	_style.border_width_bottom = 3
	set_side_inset(0.0)
	add_theme_stylebox_override("panel", _style)

	var row := UI.hbox(14)
	add_child(row)

	var menu := UI.icon_button("menu", 3, 60)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	row.add_child(menu)

	var day_chip := _chip()
	day_chip.add_child(UI.icon("day", 3))
	_day_label = UI.label("День 1", 22, UITheme.ACCENT)
	day_chip.add_child(_day_label)
	row.add_child(day_chip.get_parent())

	row.add_child(UI.spacer())

	for res in ResourceDefs.IDS:
		var chip := _chip()
		chip.get_parent().tooltip_text = ResourceDefs.name_of(res)
		chip.add_child(UI.icon(ResourceDefs.INFO[res]["icon"], 3))
		var value := UI.label("0", 22)
		value.custom_minimum_size.x = 44
		chip.add_child(value)
		var delta := UI.label("", 16, UITheme.TEXT_DIM)
		delta.custom_minimum_size.x = 34
		chip.add_child(delta)
		_value_labels[res] = value
		_delta_labels[res] = delta
		row.add_child(chip.get_parent())

	row.add_child(UI.spacer())

	_survivors_button = UI.button("0/0", 130, 60)
	_survivors_button.icon = PixelIcons.get_icon("survivors", 3)
	_survivors_button.pressed.connect(func() -> void: survivors_pressed.emit())
	row.add_child(_survivors_button)


func _ready() -> void:
	GameState.resources_changed.connect(refresh)
	GameState.survivors_changed.connect(refresh)
	GameState.rooms_changed.connect(refresh)
	GameState.day_changed.connect(refresh)
	refresh()


## Дополнительный отступ по бокам (вырез камеры), фон панели при этом тянется до края.
func set_side_inset(inset: float) -> void:
	_style.content_margin_left = 12.0 + inset
	_style.content_margin_right = 12.0 + inset


## Создаёт рамку-«плашку» и возвращает её внутренний HBox.
func _chip() -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL_DARK, UITheme.PANEL_LIGHT, 2, 8))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := UI.hbox(8)
	panel.add_child(box)
	return box


func refresh() -> void:
	_day_label.text = "День %d" % GameState.day
	var forecast: Dictionary = DaySystem.compute_economy()["delta"]
	for res in ResourceDefs.IDS:
		var value := GameState.get_resource(res)
		var value_label: Label = _value_labels[res]
		value_label.text = str(value)
		value_label.add_theme_color_override("font_color", UITheme.BAD if value <= 0 else UITheme.TEXT)
		var change := int(forecast[res])
		var delta_label: Label = _delta_labels[res]
		delta_label.text = UI.signed(change)
		var color := UITheme.TEXT_DIM
		if change > 0:
			color = UITheme.GOOD
		elif change < 0:
			color = UITheme.BAD
		delta_label.add_theme_color_override("font_color", color)
	_survivors_button.text = "%d/%d" % [GameState.population(), GameState.bed_capacity()]
