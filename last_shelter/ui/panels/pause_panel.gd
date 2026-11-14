class_name PausePanel
extends BasePanel
## Игровое меню: летопись, сохранение и выход в главное меню.

signal save_requested
signal exit_requested
signal chronicle_requested


func _init() -> void:
	super("Меню", Vector2(480, 450))
	content.add_child(UI.wrap_label("Игра сохраняется сама: в конце каждого дня, после событий и при сворачивании.", 16))
	var resume := UI.accent_button("Продолжить", 0, 68)
	resume.pressed.connect(close)
	content.add_child(resume)
	var chronicle := UI.button("Летопись убежища", 0, 68)
	chronicle.icon = PixelIcons.get_icon("chronicle", 3)
	chronicle.pressed.connect(func() -> void: chronicle_requested.emit())
	content.add_child(chronicle)
	var save := UI.button("Сохранить игру", 0, 68)
	save.pressed.connect(func() -> void: save_requested.emit())
	content.add_child(save)
	var exit := UI.button("В главное меню", 0, 68)
	exit.pressed.connect(func() -> void: exit_requested.emit())
	content.add_child(exit)
