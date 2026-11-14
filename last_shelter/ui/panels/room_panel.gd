class_name RoomPanel
extends BasePanel
## Окно комнаты: что она делает, в каком состоянии оборудование и кто в ней работает.
## Здесь назначаются работники и заказывается ремонт.

signal survivor_requested(id: int)

var room_id: int = 0
var _list: VBoxContainer


func _init(id: int) -> void:
	super("Комната", Vector2(860, 560))
	room_id = id
	var parts := UI.scroll_list(8)
	content.add_child(parts[0])
	_list = parts[1]


func _ready() -> void:
	GameState.survivors_changed.connect(_refresh)
	GameState.resources_changed.connect(_refresh)
	GameState.rooms_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var room := GameState.get_room(room_id)
	if room == null:
		close()
		return
	UI.clear(_list)
	var def := room.get_def()
	set_title(room.display_name())
	_list.add_child(UI.wrap_label(def["desc"], 18))

	var eco := DaySystem.compute_economy()
	var powered := not (eco["unpowered"] as Array).has(room.id) and not room.broken
	var status := UI.hbox(10)
	if int(def["power"]) > 0:
		status.add_child(UI.icon("power", 2))
		status.add_child(UI.label("Расход: %d в день" % int(def["power"]), 17, UITheme.TEXT_DIM))
	if room.broken:
		status.add_child(UI.label("Сломано — комната не работает!", 17, UITheme.BAD))
	elif not powered:
		status.add_child(UI.label("Нет энергии — комната не работает!", 17, UITheme.BAD))
	elif room.type == "kitchen":
		status.add_child(UI.icon("food", 2))
		status.add_child(UI.label("Экономия еды: %d в день" % int((eco["outputs"] as Dictionary).get(room.id, 0)), 17, UITheme.GOOD))
		if not GameState.workers_of(room.id).is_empty():
			status.add_child(UI.label("Горячая еда: настроение +2 всем", 17, UITheme.GOOD))
	elif def["produces"] != "":
		var res: String = def["produces"]
		status.add_child(UI.icon(ResourceDefs.INFO[res]["icon"], 2))
		status.add_child(UI.label("Выработка: +%d в день" % int((eco["outputs"] as Dictionary).get(room.id, 0)), 17, UITheme.GOOD))
	if int(def["beds"]) > 0:
		status.add_child(UI.label("Спальных мест: %d" % int(def["beds"]), 17, UITheme.TEXT_DIM))
	if int(def["cap"]) > 0:
		status.add_child(UI.label("Вместимость склада: +%d" % int(def["cap"]), 17, UITheme.TEXT_DIM))
	if room.type == "medbay" and powered:
		status.add_child(UI.label("Лечение: +%d здоровья всем в день" % roundi(DaySystem.medbay_heal(room)), 17, UITheme.GOOD))
	_list.add_child(status)
	if room.can_break():
		_list.add_child(_condition_card(room))

	var slots := int(def["slots"])
	if slots <= 0:
		_list.add_child(UI.wrap_label("В этой комнате не нужны работники."))
		return

	var skill: String = def["skill"]
	var workers := GameState.workers_of(room.id)
	_list.add_child(UI.section_title("Работники  %d/%d  ·  навык: %s" % [workers.size(), slots, SkillDefs.name_of(skill)]))
	if workers.is_empty():
		_list.add_child(UI.wrap_label("Пока никто не назначен."))
	for s in workers:
		_list.add_child(_worker_row(s, skill, "Снять", GameState.assign.bind(s.id, -1), true))

	var free_slot := workers.size() < slots
	var candidates: Array[SurvivorData] = []
	for s in GameState.survivors_in_shelter():
		if s.room_id != room.id:
			candidates.append(s)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: SurvivorData, b: SurvivorData) -> bool:
		return a.effective_skill(skill) > b.effective_skill(skill))
	_list.add_child(UI.section_title("Можно назначить"))
	for s in candidates:
		_list.add_child(_worker_row(s, skill, "Назначить", GameState.assign.bind(s.id, room.id), free_slot))


## Состояние оборудования и кнопка ремонта / обслуживания.
func _condition_card(room: RoomData) -> PanelContainer:
	var card := UI.card(UITheme.PANEL_DARK, 10)
	var row := UI.hbox(12)
	card.add_child(row)
	row.add_child(UI.icon("build", 3))
	var info := UI.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UI.hbox(10)
	head.add_child(UI.label("Оборудование: %d%%" % roundi(room.condition), 19))
	head.add_child(UI.label(MaintenanceSystem.status_text(room), 17, MaintenanceSystem.status_color(room)))
	info.add_child(head)
	var bar := UI.bar(room.condition, 0.0, 100.0, MaintenanceSystem.status_color(room), Vector2(200, 14))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(bar)
	var hint := "Изнашивается каждый день; ниже 30% может сломаться."
	if MaintenanceSystem.has_repairer():
		hint += " С мастером ремонт дешевле."
	info.add_child(UI.label(hint, 15, UITheme.TEXT_DIM))
	row.add_child(info)
	if MaintenanceSystem.needs_service(room):
		var cost := MaintenanceSystem.repair_cost(room)
		var action := "Починить" if room.broken else "Обслужить"
		var b := UI.accent_button("%s · %d металла" % [action, cost], 230, 60)
		UI.pass_scroll(b)
		b.add_theme_font_size_override("font_size", 18)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = MaintenanceSystem.repair_error(room) != ""
		b.pressed.connect(func() -> void: MaintenanceSystem.repair(room))
		row.add_child(b)
	return card


func _worker_row(s: SurvivorData, skill: String, action: String, callable: Callable, enabled: bool) -> PanelContainer:
	var card := UI.card(UITheme.PANEL_LIGHT, 8)
	var row := UI.hbox(12)
	card.add_child(row)
	var portrait := UI.texture(SurvivorSprites.get_portrait(s.appearance, 3))
	portrait.custom_minimum_size = Vector2(44, 60)
	row.add_child(portrait)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(s.full_name(), 20))
	var room := GameState.get_room(room_id)
	var note := "%s: %d  ·  %s" % [SkillDefs.name_of(skill), s.effective_skill(skill), SurvivorsPanel.location_text(s)]
	if room != null and DaySystem.is_specialist(s, room):
		note += "  ·  специалист"
	info.add_child(UI.label(note, 15, UITheme.TEAL if room != null and DaySystem.is_specialist(s, room) else UITheme.TEXT_DIM))
	row.add_child(info)
	var profile := UI.button("Профиль", 110, 52)
	UI.pass_scroll(profile)
	profile.add_theme_font_size_override("font_size", 17)
	profile.pressed.connect(func() -> void: survivor_requested.emit(s.id))
	row.add_child(profile)
	var b := UI.accent_button(action, 130, 52)
	UI.pass_scroll(b)
	b.add_theme_font_size_override("font_size", 17)
	b.disabled = not enabled
	b.pressed.connect(func() -> void: callable.call())
	row.add_child(b)
	return card
