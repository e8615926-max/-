class_name ResearchPanel
extends BasePanel
## Исследования: текущее с прогрессом и все технологии — изученные, доступные и закрытые.

var _list: VBoxContainer


func _init() -> void:
	super("Исследования", Vector2(980, 600))
	var parts := UI.scroll_list(8)
	content.add_child(parts[0])
	_list = parts[1]


func _ready() -> void:
	GameState.research_changed.connect(_refresh)
	GameState.resources_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	UI.clear(_list)
	var per_day := ResearchSystem.points_per_day()
	var head := UI.card(UITheme.PANEL_DARK, 12)
	var box := UI.vbox(6)
	head.add_child(box)
	if GameState.first_room_of_type("lab") == null:
		box.add_child(UI.wrap_label("Постройте лабораторию и назначьте туда людей с высокой наукой — без неё исследования не идут.", 17, UITheme.ACCENT))
	var current := GameState.research_current
	if current == "":
		box.add_child(UI.label("Сейчас ничего не изучается. Выберите технологию ниже.", 18))
	else:
		var need := float(ResearchDefs.INFO[current]["points"])
		var row := UI.hbox(10)
		row.add_child(UI.icon("research", 3))
		var days_left := "—" if per_day <= 0.0 else "≈%d дн." % ceili((need - GameState.research_progress) / per_day)
		row.add_child(UI.label("%s: %d из %d (%s)" % [ResearchDefs.name_of(current), roundi(GameState.research_progress), int(need), days_left], 18))
		row.add_child(UI.spacer())
		var cancel := UI.button("Отменить", 140, 48)
		UI.pass_scroll(cancel)
		cancel.tooltip_text = "Накопленные очки пропадут, ресурсы не вернутся"
		cancel.pressed.connect(ResearchSystem.cancel)
		row.add_child(cancel)
		box.add_child(row)
		var bar := UI.bar(GameState.research_progress, 0.0, need, UITheme.TEAL, Vector2(200, 16))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(bar)
	box.add_child(UI.label("Очков исследования в день: %.1f" % per_day, 15, UITheme.TEXT_DIM))
	_list.add_child(head)

	for id in ResearchDefs.ORDER:
		_list.add_child(_tech_card(id))


func _tech_card(id: String) -> PanelContainer:
	var def: Dictionary = ResearchDefs.INFO[id]
	var done := ResearchSystem.has(id)
	var card := UI.card(UITheme.PANEL_LIGHT if not done else UITheme.PANEL_DARK, 10)
	var row := UI.hbox(12)
	card.add_child(row)
	var info := UI.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UI.hbox(10)
	title.add_child(UI.label(String(def["name"]), 20, UITheme.GOOD if done else UITheme.TEXT))
	if done:
		title.add_child(UI.label("изучено", 15, UITheme.GOOD))
	elif GameState.research_current == id:
		title.add_child(UI.label("изучается", 15, UITheme.TEAL))
	info.add_child(title)
	info.add_child(UI.wrap_label(String(def["desc"]), 15))
	if not done:
		var cost_line := UI.cost_row(def["cost"], 16)
		cost_line.add_child(UI.label("· %d очков" % int(def["points"]), 16, UITheme.TEXT_DIM))
		info.add_child(cost_line)
		if not ResearchSystem.is_available(id):
			var names: PackedStringArray = []
			for req: String in def["requires"]:
				names.append(ResearchDefs.name_of(req))
			info.add_child(UI.label("Сначала: %s" % ", ".join(names), 15, UITheme.ACCENT))
	row.add_child(info)
	if not done and GameState.research_current != id:
		var b := UI.accent_button("Изучать", 140, 56)
		UI.pass_scroll(b)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var error := ResearchSystem.start_error(id)
		b.disabled = error != ""
		b.tooltip_text = error
		b.pressed.connect(func() -> void: ResearchSystem.start(id))
		row.add_child(b)
	return card
