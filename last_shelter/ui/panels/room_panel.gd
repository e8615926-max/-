class_name RoomPanel
extends BasePanel
## Окно комнаты: что она делает и кто в ней работает. Здесь же назначаются работники.

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
	var powered := not (eco["unpowered"] as Array).has(room.id)
	var status := UI.hbox(10)
	if int(def["power"]) > 0:
		status.add_child(UI.icon("power", 2))
		status.add_child(UI.label("Расход: %d в день" % int(def["power"]), 17, UITheme.TEXT_DIM))
	if not powered:
		status.add_child(UI.label("Нет энергии — комната не работает!", 17, UITheme.BAD))
	elif def["produces"] != "":
		var res: String = def["produces"]
		status.add_child(UI.icon(ResourceDefs.INFO[res]["icon"], 2))
		status.add_child(UI.label("Выработка: +%d в день" % int((eco["outputs"] as Dictionary).get(room.id, 0)), 17, UITheme.GOOD))
	if int(def["beds"]) > 0:
		status.add_child(UI.label("Спальных мест: %d" % int(def["beds"]), 17, UITheme.TEXT_DIM))
	if int(def["cap"]) > 0:
		status.add_child(UI.label("Вместимость склада: +%d" % int(def["cap"]), 17, UITheme.TEXT_DIM))
	if room.type == "medbay" and powered:
		var heal := 6
		for s in GameState.workers_of(room.id):
			heal += s.effective_skill("medicine") * 2
		status.add_child(UI.label("Лечение: +%d здоровья всем в день" % heal, 17, UITheme.GOOD))
	_list.add_child(status)

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
	info.add_child(UI.label("%s: %d  ·  %s" % [SkillDefs.name_of(skill), s.effective_skill(skill),
		SurvivorsPanel.location_text(s)], 15, UITheme.TEXT_DIM))
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
