class_name ConfirmPanel
extends BasePanel
## Простое окно с текстом и одной или двумя кнопками.

signal confirmed


func _init(title: String, text: String, ok_text: String, cancel_text: String = "") -> void:
	super(title, Vector2(620, 300))
	var body := UI.wrap_label(text, 20, UITheme.TEXT)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)

	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(row)
	if cancel_text != "":
		var cancel := UI.button(cancel_text, 180)
		cancel.pressed.connect(close)
		row.add_child(cancel)
	var ok := UI.accent_button(ok_text, 220)
	ok.pressed.connect(func() -> void:
		confirmed.emit()
		close())
	row.add_child(ok)
