class_name BottomBar
extends PanelContainer
## Нижняя панель с основными действиями.

signal action_pressed(action: String)

const HEIGHT := 108

const ACTIONS := [
	["build", "Стройка", "build"],
	["survivors", "Выжившие", "survivors"],
	["storage", "Склад", "storage"],
	["expeditions", "Экспедиции", "expedition"],
	["next_day", "Следующий день", "next_day"],
]

var _buttons: Dictionary = {}
var _style: StyleBoxFlat


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	_style = UITheme.box(UITheme.PANEL, UITheme.BORDER, 0, 8)
	_style.border_width_top = 3
	set_side_inset(0.0)
	add_theme_stylebox_override("panel", _style)

	var row := UI.hbox(10)
	add_child(row)
	for entry: Array in ACTIONS:
		var action: String = entry[0]
		var b: Button
		if action == "next_day":
			b = UI.accent_button(entry[1], 0, 88)
		else:
			b = UI.button(entry[1], 0, 88)
		b.icon = PixelIcons.get_icon(entry[2], 3)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_constant_override("h_separation", 0)
		b.pressed.connect(func() -> void: action_pressed.emit(action))
		row.add_child(b)
		_buttons[action] = b


func get_button(action: String) -> Button:
	return _buttons.get(action)


## Дополнительный отступ по бокам (вырез камеры), фон панели при этом тянется до края.
func set_side_inset(inset: float) -> void:
	_style.content_margin_left = 12.0 + inset
	_style.content_margin_right = 12.0 + inset
