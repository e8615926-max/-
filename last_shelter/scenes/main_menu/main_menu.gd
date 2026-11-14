extends Control
## Главное меню: продолжить, новая игра, выход.

const GAME_SCENE := "res://scenes/game/game.tscn"

var _overlay: Control


func _ready() -> void:
	theme = UITheme.build()
	GameState.active = false
	var inset := SafeArea.side_inset(get_viewport())

	add_child(MenuBackdrop.new())

	# Затемнение слева, чтобы заголовок и кнопки читались на фоне.
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.04, 0.55)
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 600 + inset
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column := UI.vbox(12)
	column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 70 + inset
	column.offset_right = 530 + inset
	column.offset_top = 50
	column.offset_bottom = -40
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	var title := UI.label("LAST\nSHELTER", 84, UITheme.ACCENT)
	title.add_theme_constant_override("line_spacing", -14)
	title.add_theme_color_override("font_shadow_color", Color("3a2408"))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_color_override("font_outline_color", Color("14100e"))
	title.add_theme_constant_override("outline_size", 10)
	column.add_child(title)
	column.add_child(UI.label("Последнее убежище. Выживи под землёй.", 20, UITheme.TEXT))

	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	column.add_child(gap)

	if SaveManager.has_save():
		var resume := UI.accent_button("Продолжить", 0, 72)
		resume.pressed.connect(_continue_game)
		column.add_child(resume)
		var fresh := UI.button("Новая игра", 0, 72)
		fresh.pressed.connect(_ask_new_game)
		column.add_child(fresh)
	else:
		var fresh := UI.accent_button("Новая игра", 0, 72)
		fresh.pressed.connect(_new_game)
		column.add_child(fresh)
	# В браузере выходить некуда: остановка движка оставила бы чёрный экран.
	if not OS.has_feature("web"):
		var quit := UI.button("Выход", 0, 72)
		quit.pressed.connect(func() -> void: get_tree().quit())
		column.add_child(quit)

	var version := UI.label("v%s" % ProjectSettings.get_setting("application/config/version", "0.1.0"), 14, UITheme.TEXT_DIM)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -12
	version.offset_bottom = -8
	add_child(version)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func _continue_game() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file(GAME_SCENE)
		return
	var panel := ConfirmPanel.new("Сохранение повреждено",
		"Не удалось загрузить сохранённую игру. Начать новую?", "Новая игра", "Отмена")
	panel.confirmed.connect(_new_game)
	_overlay.add_child(panel)


func _ask_new_game() -> void:
	var panel := ConfirmPanel.new("Новая игра",
		"Текущее сохранение будет стёрто. Начать заново?", "Начать заново", "Отмена")
	panel.confirmed.connect(_new_game)
	_overlay.add_child(panel)


func _new_game() -> void:
	SaveManager.delete_save()
	GameState.new_game()
	SaveManager.save_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _notification(what: int) -> void:
	# «Назад» в главном меню закрывает игру.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
