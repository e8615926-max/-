class_name RoomPanel
extends BasePanel
## Окно комнаты: что она делает, в каком состоянии оборудование и кто в ней работает.
## Здесь назначаются работники и заказывается ремонт.

signal survivor_requested(id: int)
signal research_requested
signal radio_requested
signal decor_requested(room_id: int, slot: int)

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
	GameState.storage_changed.connect(_refresh)
	GameState.research_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var room := GameState.get_room(room_id)
	if room == null:
		close()
		return
	UI.clear(_list)
	var def := room.get_def()
	set_title(room.title())
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
	elif room.product() != "":
		var res: String = room.product()
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
	_list.add_child(_upgrade_card(room))
	if def.has("modes"):
		_list.add_child(_mode_row(room))
	_add_special(room, eco)
	_add_crafting(room)
	_add_decor(room)

	var slots := RoomDefs.slots_of(room.type, room.tier)
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


## Уровень комнаты и кнопка улучшения.
func _upgrade_card(room: RoomData) -> PanelContainer:
	var card := UI.card(UITheme.PANEL_DARK, 10)
	var row := UI.hbox(12)
	card.add_child(row)
	var info := UI.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label("Уровень %d из %d" % [room.tier, RoomDefs.MAX_TIER], 19))
	if room.tier < RoomDefs.MAX_TIER:
		info.add_child(UI.label(_upgrade_benefit(room), 15, UITheme.TEAL))
		info.add_child(UI.cost_row(RoomDefs.upgrade_cost(room.type, room.tier + 1), 16))
	else:
		info.add_child(UI.label("Комната улучшена полностью.", 15, UITheme.GOOD))
	row.add_child(info)
	if room.tier < RoomDefs.MAX_TIER:
		var error := GameState.upgrade_error(room)
		var b := UI.accent_button("Улучшить до %s" % RoomDefs.TIER_NAMES[room.tier + 1], 210, 60)
		UI.pass_scroll(b)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = error != ""
		b.tooltip_text = error
		b.pressed.connect(func() -> void: GameState.upgrade_room(room))
		row.add_child(b)
		if error.begins_with("Нужно"):
			info.add_child(UI.label(error, 15, UITheme.ACCENT))
	return card


func _upgrade_benefit(room: RoomData) -> String:
	var next := room.tier + 1
	var parts: PackedStringArray = []
	var def := room.get_def()
	if int(def["beds"]) > 0:
		parts.append("мест: %d → %d" % [RoomDefs.beds_of(room.type, room.tier), RoomDefs.beds_of(room.type, next)])
	if int(def["cap"]) > 0:
		parts.append("вместимость: +%d → +%d" % [RoomDefs.cap_of(room.type, room.tier), RoomDefs.cap_of(room.type, next)])
	if int(def["slots"]) > 0:
		parts.append("работа ×%.2f → ×%.2f" % [RoomDefs.tier_output(room.tier), RoomDefs.tier_output(next)])
		if RoomDefs.slots_of(room.type, next) > RoomDefs.slots_of(room.type, room.tier):
			parts.append("+1 рабочее место")
	if room.can_break():
		parts.append("износ меньше")
	return "Дальше: " + ", ".join(parts)


func _mode_row(room: RoomData) -> HBoxContainer:
	var row := UI.hbox(8)
	row.add_child(UI.label("Производит:", 17, UITheme.TEXT_DIM))
	var modes: Dictionary = room.get_def()["modes"]
	for mode_id: String in modes:
		var b := UI.button(String(modes[mode_id]["name"]), 130, 52)
		UI.pass_scroll(b)
		b.icon = PixelIcons.get_icon(ResourceDefs.INFO[mode_id]["icon"], 2)
		if room.product() == mode_id:
			b.add_theme_stylebox_override("normal", UITheme.button_box(UITheme.ACCENT_DARK, UITheme.ACCENT, true))
			b.add_theme_color_override("font_color", UITheme.ACCENT)
		b.pressed.connect(func() -> void: GameState.set_room_mode(room, mode_id))
		row.add_child(b)
	return row


## Особые сведения: исследования, эфир, лечение.
func _add_special(room: RoomData, eco: Dictionary) -> void:
	match room.type:
		"lab":
			var card := UI.card(UITheme.PANEL_DARK, 10)
			var row := UI.hbox(12)
			card.add_child(row)
			row.add_child(UI.icon("research", 3))
			var text := "Сейчас ничего не изучается."
			if GameState.research_current != "":
				text = "Изучается: %s — %d из %d" % [ResearchDefs.name_of(GameState.research_current),
					roundi(GameState.research_progress), int(ResearchDefs.INFO[GameState.research_current]["points"])]
			var info := UI.vbox(2)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(UI.label(text, 17))
			info.add_child(UI.label("Очков исследования в день: %.1f" % float(eco["research"]), 15, UITheme.TEAL))
			row.add_child(info)
			var b := UI.accent_button("Исследования", 190, 56)
			UI.pass_scroll(b)
			b.pressed.connect(func() -> void: research_requested.emit())
			row.add_child(b)
			_list.add_child(card)
		"radio":
			var card := UI.card(UITheme.PANEL_DARK, 10)
			var row := UI.hbox(12)
			card.add_child(row)
			row.add_child(UI.icon("radio", 3))
			var info := UI.vbox(2)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(UI.label("Сигнал: %d из %d до следующей передачи" % [roundi(GameState.radio_progress), roundi(RadioSystem.threshold())], 17))
			info.add_child(UI.label("Сигнала в день: %.1f · передач: %d" % [float(eco["signal"]), GameState.radio_log.size()], 15, UITheme.TEAL))
			row.add_child(info)
			var b := UI.accent_button("Журнал эфира", 190, 56)
			UI.pass_scroll(b)
			b.pressed.connect(func() -> void: radio_requested.emit())
			row.add_child(b)
			_list.add_child(card)
		"medbay":
			var ill := 0
			for s in GameState.survivors_in_shelter():
				if s.is_ill():
					ill += 1
			var text := "Больных: %d · сила лечения: +%.1f дня в день · медикаментов: %d" % [ill,
				MedicalSystem.treatment_power(), GameState.get_resource("medicine")]
			_list.add_child(UI.wrap_label(text, 16, UITheme.TEAL))
			if ill > 0 and GameState.get_resource("medicine") <= 0:
				_list.add_child(UI.label("Нет медикаментов — болезни лечатся только сами!", 16, UITheme.BAD))


## Изготовление снаряжения (после исследований).
func _add_crafting(room: RoomData) -> void:
	var recipes: Array[String] = []
	for item_id: String in ItemDefs.RECIPES:
		if ItemDefs.RECIPES[item_id]["room"] == room.type:
			recipes.append(item_id)
	if recipes.is_empty():
		return
	_list.add_child(UI.section_title("Изготовление"))
	for item_id in recipes:
		var recipe: Dictionary = ItemDefs.RECIPES[item_id]
		var card := UI.card(UITheme.PANEL_LIGHT, 8)
		var row := UI.hbox(12)
		card.add_child(row)
		var icon := UI.texture(PixelIcons.item_icon(item_id, 4))
		icon.custom_minimum_size = Vector2(44, 44)
		row.add_child(icon)
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label("%s · %s" % [ItemDefs.name_of(item_id), ItemDefs.effect_text(item_id)], 18))
		if ResearchSystem.has(String(recipe["research"])):
			info.add_child(UI.cost_row(recipe["cost"], 16))
		else:
			info.add_child(UI.label("Нужно исследование: %s" % ResearchDefs.name_of(String(recipe["research"])), 15, UITheme.ACCENT))
		row.add_child(info)
		var b := UI.button("Сделать", 130, 52)
		UI.pass_scroll(b)
		b.disabled = GameState.craft_error(item_id) != "" or room.broken
		b.pressed.connect(func() -> void: GameState.craft(item_id))
		row.add_child(b)
		_list.add_child(card)


## Обустройство: два места для украшений и окраска стен.
func _add_decor(room: RoomData) -> void:
	_list.add_child(UI.section_title("Обустройство · уют убежища %d из %d" % [GameState.comfort(), DecorDefs.COMFORT_CAP]))
	var row := UI.hbox(8)
	for slot in DecorDefs.SLOTS:
		var current := String(room.decor[slot])
		var side := "Слева" if slot == 0 else "Справа"
		var b := UI.button("%s: %s" % [side, DecorDefs.name_of(current) if current != "" else "пусто"], 0, 52)
		UI.pass_scroll(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func() -> void: decor_requested.emit(room.id, slot))
		row.add_child(b)
	_list.add_child(row)
	var paints := UI.hbox(6)
	paints.add_child(UI.label("Стены:", 17, UITheme.TEXT_DIM))
	for paint_id in DecorDefs.PAINT_ORDER:
		var info: Dictionary = DecorDefs.PAINTS[paint_id]
		var b := UI.button(String(info["name"]), 0, 48)
		UI.pass_scroll(b)
		b.add_theme_font_size_override("font_size", 15)
		if room.paint == paint_id:
			b.add_theme_stylebox_override("normal", UITheme.button_box(UITheme.ACCENT_DARK, UITheme.ACCENT, true))
		b.pressed.connect(func() -> void: GameState.set_paint(room, paint_id))
		paints.add_child(b)
	_list.add_child(paints)


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
