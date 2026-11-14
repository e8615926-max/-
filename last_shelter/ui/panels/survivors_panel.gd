class_name SurvivorsPanel
extends BasePanel
## Список всех выживших убежища. Касание по карточке открывает профиль.

signal survivor_selected(id: int)

var _list: VBoxContainer


func _init() -> void:
	super("Выжившие", Vector2(940, 580))
	var parts := UI.scroll_list(8)
	content.add_child(parts[0])
	_list = parts[1]


func _ready() -> void:
	GameState.survivors_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	UI.clear(_list)
	set_title("Выжившие  %d/%d" % [GameState.population(), GameState.bed_capacity()])
	for s in GameState.survivors:
		_list.add_child(_make_card(s))


## Где сейчас находится выживший — для списков.
static func location_text(s: SurvivorData) -> String:
	if s.on_expedition:
		var e := ExpeditionSystem.find(s.id)
		return "В экспедиции (ещё %d дн.)" % int(e.get("days_left", 1))
	var room := GameState.get_room(s.room_id)
	if room != null:
		return "Работа: %s" % room.display_name()
	return "Без работы"


func _make_card(s: SurvivorData) -> Button:
	var card := UI.button("", 0, 104)
	UI.pass_scroll(card)
	card.pressed.connect(func() -> void: survivor_selected.emit(s.id))

	var row := UI.hbox(16)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	card.add_child(row)

	var portrait := UI.texture(SurvivorSprites.get_portrait(s.appearance, 4))
	portrait.custom_minimum_size = Vector2(60, 80)
	if s.on_expedition:
		portrait.modulate = Color(1, 1, 1, 0.45)
	row.add_child(portrait)

	var info := UI.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UI.label(s.full_name(), 22))
	info.add_child(UI.label("%s, %d" % [s.background, s.age], 16, UITheme.TEXT_DIM))
	var where_color := UITheme.TEAL if (s.on_expedition or s.room_id != -1) else UITheme.ACCENT
	info.add_child(UI.label(location_text(s), 16, where_color))
	row.add_child(info)

	var stats := UI.vbox(10)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_child(_stat_row("health", s.health, s.max_health, UITheme.BAD))
	stats.add_child(_stat_row("mood", s.mood, 100.0, UITheme.ACCENT))
	row.add_child(stats)

	UI.ignore_mouse(row)
	return card


func _stat_row(icon_name: String, value: float, max_value: float, color: Color) -> HBoxContainer:
	var row := UI.hbox(8)
	row.add_child(UI.icon(icon_name, 2))
	row.add_child(UI.bar(value, 0.0, max_value, color, Vector2(170, 16)))
	var number := UI.label(str(roundi(value)), 16, UITheme.TEXT_DIM)
	number.custom_minimum_size.x = 34
	row.add_child(number)
	return row
