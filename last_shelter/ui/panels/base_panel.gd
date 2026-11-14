class_name BasePanel
extends Control
## Основа всех всплывающих окон: затемнение, рамка, заголовок и кнопка закрытия.
## Наследники наполняют `content`. Касание по затемнению закрывает окно.

signal closed

## Сюда наследники добавляют своё содержимое.
var content: VBoxContainer
## Можно ли закрыть окно крестиком / касанием мимо / кнопкой «назад».
var dismissable: bool = true

var _header: HBoxContainer
var _title: Label
var _close_button: Button


func _init(title: String = "", panel_size: Vector2 = Vector2(900, 580)) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = panel_size
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(frame)

	var root := UI.vbox(10)
	frame.add_child(root)

	_header = UI.hbox(12)
	root.add_child(_header)
	_title = UI.label(title, 28, UITheme.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_header.add_child(_title)
	_close_button = UI.icon_button("close", 3, 64)
	_close_button.pressed.connect(close)
	_header.add_child(_close_button)

	root.add_child(HSeparator.new())

	content = UI.vbox(10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)


func set_title(text: String) -> void:
	_title.text = text


func set_dismissable(value: bool) -> void:
	dismissable = value
	_close_button.visible = value


## Добавляет кнопку «назад» слева от заголовка.
func add_back_button() -> Button:
	var b := UI.icon_button("back", 3, 64)
	_header.add_child(b)
	_header.move_child(b, 0)
	return b


func close() -> void:
	closed.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	# Сюда доходят только касания мимо рамки окна.
	if dismissable and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			accept_event()
			close()
