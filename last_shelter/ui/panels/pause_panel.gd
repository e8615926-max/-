class_name PausePanel
extends BasePanel
## Игровое меню: летопись, исследования, эфир, архив, звук, сохранение и выход в главное меню.

signal save_requested
signal exit_requested
signal chronicle_requested
signal research_requested
signal radio_requested
signal world_requested


func _init() -> void:
	super("Меню", Vector2(720, 520))
	content.add_child(UI.wrap_label("Игра сохраняется сама: в конце каждого дня, после событий и при сворачивании.", 16))
	var resume := UI.accent_button("Продолжить", 0, 68)
	resume.pressed.connect(close)
	content.add_child(resume)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	_add(grid, "Летопись убежища", "chronicle", func() -> void: chronicle_requested.emit())
	_add(grid, "Исследования", "research", func() -> void: research_requested.emit())
	_add(grid, "Журнал эфира", "radio", func() -> void: radio_requested.emit())
	_add(grid, "Архив находок", "archive", func() -> void: world_requested.emit())
	var sound := _add(grid, "", "sound", Callable())
	sound.name = "SoundToggle"
	sound.text = _sound_text()
	sound.pressed.connect(func() -> void:
		SoundManager.toggle()
		sound.text = _sound_text())
	_add(grid, "Сохранить игру", "", func() -> void: save_requested.emit())
	var exit := UI.button("В главное меню", 0, 64)
	exit.pressed.connect(func() -> void: exit_requested.emit())
	content.add_child(exit)


func _add(grid: GridContainer, text: String, icon_name: String, action: Callable) -> Button:
	var b := UI.button(text, 0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if icon_name != "":
		b.icon = PixelIcons.get_icon(icon_name, 3)
	if action.is_valid():
		b.pressed.connect(action)
	grid.add_child(b)
	return b


static func _sound_text() -> String:
	return "Звук: включён" if SoundManager.enabled else "Звук: выключен"
