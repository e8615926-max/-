class_name PausePanel
extends BasePanel
## Игровое меню: сохранение и выход в главное меню.

signal save_requested
signal exit_requested


func _init() -> void:
	super("Меню", Vector2(480, 380))
	content.add_child(UI.wrap_label("Игра сохраняется автоматически в конце каждого дня и при сворачивании.", 16))
	var resume := UI.accent_button("Продолжить", 0, 68)
	resume.pressed.connect(close)
	content.add_child(resume)
	var save := UI.button("Сохранить игру", 0, 68)
	save.pressed.connect(func() -> void: save_requested.emit())
	content.add_child(save)
	var exit := UI.button("В главное меню", 0, 68)
	exit.pressed.connect(func() -> void: exit_requested.emit())
	content.add_child(exit)
