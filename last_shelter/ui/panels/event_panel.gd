class_name EventPanel
extends BasePanel
## Окно случайного события: описание, варианты решения с ценой и шансом,
## затем итог. Закрыть окно можно только после выбора.

signal resolved(result: Dictionary)

const KIND_COLORS := {"good": UITheme.GOOD, "bad": UITheme.BAD, "info": UITheme.TEXT}
const CATEGORY_ICONS := {
	"breakdown": "build", "emergency": "power", "trouble": "storage", "health": "health",
	"social": "survivors", "visitor": "expedition", "luck": "chronicle", "expedition": "expedition",
	"shelter": "shelters",
}

var _event: Dictionary
var _choices_box: VBoxContainer


func _init(ev: Dictionary) -> void:
	super(String(ev["title"]), Vector2(880, 540))
	_event = ev
	set_dismissable(false)

	var head := UI.hbox(14)
	var icon := UI.icon(String(CATEGORY_ICONS.get(ev["category"], "chronicle")), 5)
	icon.custom_minimum_size = Vector2(56, 56)
	head.add_child(icon)
	head.add_child(UI.wrap_label(String(ev["text"]), 21, UITheme.TEXT))
	content.add_child(head)
	content.add_child(UI.section_title("Как поступить?"))

	_choices_box = UI.vbox(10)
	_choices_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_choices_box)
	var choices := EventSystem.choices_of(ev)
	for i in choices.size():
		_choices_box.add_child(_choice_button(i))


func _choice_button(index: int) -> Button:
	var view := EventSystem.choice_view(_event, index)
	var b := UI.button("", 0, 76)
	b.disabled = not view["enabled"]
	b.pressed.connect(_choose.bind(index))
	var box := UI.vbox(2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UI.label(String(view["label"]), 21, UITheme.TEXT if view["enabled"] else UITheme.TEXT_DIM)
	box.add_child(title)
	if String(view["note"]) != "":
		box.add_child(UI.label(String(view["note"]), 16, UITheme.TEAL if view["enabled"] else UITheme.TEXT_DIM))
	b.add_child(box)
	UI.ignore_mouse(box)
	return b


func _choose(index: int) -> void:
	var result := EventSystem.resolve(_event, index, GameState.rng)
	if not result.get("ok", false):
		return
	UI.clear(_choices_box)
	var color: Color = KIND_COLORS.get(result["kind"], UITheme.TEXT)
	var card := UI.card(UITheme.PANEL_DARK, 16)
	card.add_child(UI.wrap_label(String(result["text"]), 21, color))
	_choices_box.add_child(card)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choices_box.add_child(spacer)
	var ok := UI.accent_button("Продолжить", 0, 68)
	ok.pressed.connect(close)
	_choices_box.add_child(ok)
	set_dismissable(true)
	SoundManager.play("bad" if result["kind"] == "bad" else "confirm")
	resolved.emit(result)
