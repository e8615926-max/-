class_name SurvivorProfilePanel
extends BasePanel
## Личный профиль выжившего с пятью разделами:
## общее, здоровье, инвентарь, навыки, отношения.

signal back_requested
signal survivor_requested(id: int)

const TABS := [
	["general", "Общее"],
	["health", "Здоровье"],
	["inventory", "Инвентарь"],
	["skills", "Навыки"],
	["relations", "Отношения"],
]

var survivor_id: int = 0

var _tab: String = "general"
var _tab_buttons: Dictionary = {}
var _side: VBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer


func _init(id: int, tab: String = "general") -> void:
	super("Профиль", Vector2(1120, 610))
	survivor_id = id
	_tab = tab
	add_back_button().pressed.connect(func() -> void: back_requested.emit())

	var row := UI.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)

	_side = UI.vbox(8)
	_side.custom_minimum_size.x = 230
	row.add_child(_side)

	var right := UI.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)

	var tabs := UI.hbox(6)
	right.add_child(tabs)
	for entry: Array in TABS:
		var tab_id: String = entry[0]
		var b := UI.button(entry[1], 0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_select_tab.bind(tab_id))
		tabs.add_child(b)
		_tab_buttons[tab_id] = b

	var parts := UI.scroll_list(10)
	_scroll = parts[0]
	_body = parts[1]
	right.add_child(_scroll)


func _ready() -> void:
	GameState.survivors_changed.connect(_refresh)
	GameState.storage_changed.connect(_refresh)
	_refresh()


func _select_tab(tab_id: String) -> void:
	_tab = tab_id
	_scroll.scroll_vertical = 0
	_refresh()


func _refresh() -> void:
	var s := GameState.get_survivor(survivor_id)
	if s == null:
		close()
		return
	set_title(s.full_name())
	for tab_id: String in _tab_buttons:
		var b: Button = _tab_buttons[tab_id]
		var active := tab_id == _tab
		b.add_theme_stylebox_override("normal",
			UITheme.button_box(UITheme.ACCENT_DARK, UITheme.ACCENT, true) if active
			else UITheme.button_box(UITheme.PANEL_LIGHT, UITheme.BORDER))
		b.add_theme_color_override("font_color", UITheme.ACCENT if active else UITheme.TEXT)

	var keep_scroll := _scroll.scroll_vertical
	_build_side(s)
	UI.clear(_body)
	match _tab:
		"general": _build_general(s)
		"health": _build_health(s)
		"inventory": _build_inventory(s)
		"skills": _build_skills(s)
		"relations": _build_relations(s)
	_scroll.set_deferred("scroll_vertical", keep_scroll)


# --- Левая колонка ----------------------------------------------------------

func _build_side(s: SurvivorData) -> void:
	UI.clear(_side)
	var frame := UI.card(UITheme.PANEL_DARK, 10)
	var portrait := UI.texture(SurvivorSprites.get_portrait(s.appearance, 9))
	portrait.custom_minimum_size = Vector2(150, 190)
	frame.add_child(portrait)
	_side.add_child(frame)

	_side.add_child(UI.wrap_label(s.background, 16))
	_side.add_child(_mini_stat("health", s.health, s.max_health, UITheme.BAD))
	_side.add_child(_mini_stat("mood", s.mood, 100.0, UITheme.ACCENT))
	var where := UI.wrap_label(SurvivorsPanel.location_text(s), 16, UITheme.TEAL)
	_side.add_child(where)


func _mini_stat(icon_name: String, value: float, max_value: float, color: Color) -> HBoxContainer:
	var row := UI.hbox(8)
	row.add_child(UI.icon(icon_name, 2))
	var bar := UI.bar(value, 0.0, max_value, color, Vector2(100, 16))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	var number := UI.label(str(roundi(value)), 16, UITheme.TEXT_DIM)
	number.custom_minimum_size.x = 34
	row.add_child(number)
	return row


# --- Общее ------------------------------------------------------------------

func _build_general(s: SurvivorData) -> void:
	_body.add_child(UI.section_title("Общая информация"))
	var grid := GridContainer.new()
	grid.columns = 2
	_body.add_child(grid)
	_info_row(grid, "Имя", s.full_name())
	_info_row(grid, "Пол", "Женский" if s.gender == "f" else "Мужской")
	_info_row(grid, "Возраст", "%d" % s.age)
	_info_row(grid, "Прошлое", s.background)
	_info_row(grid, "Увлечения", InterestDefs.list_text(s.interests) if not s.interests.is_empty() else "—")
	_info_row(grid, "В убежище", "с %d-го дня (%d дн.)" % [s.joined_day, GameState.day - s.joined_day + 1])

	_body.add_child(UI.section_title("Работа"))
	if s.on_expedition:
		_body.add_child(UI.wrap_label("Сейчас в экспедиции. Назначить на работу можно после возвращения."))
		return
	_body.add_child(UI.wrap_label("Выберите рабочее место. На выработку влияет подходящий навык."))
	var flow := HFlowContainer.new()
	_body.add_child(flow)
	flow.add_child(_job_button(s, -1, "Отдых"))
	for room in GameState.rooms:
		var slots := int(room.get_def()["slots"])
		if slots <= 0:
			continue
		var text := "%s  %d/%d" % [room.display_name(), GameState.workers_of(room.id).size(), slots]
		flow.add_child(_job_button(s, room.id, text))


func _info_row(grid: GridContainer, title: String, value: String) -> void:
	var key := UI.label(title, 18, UITheme.TEXT_DIM)
	key.custom_minimum_size.x = 150
	grid.add_child(key)
	grid.add_child(UI.wrap_label(value, 18, UITheme.TEXT))


func _job_button(s: SurvivorData, room_id: int, text: String) -> Button:
	var b := UI.button(text, 150, 56)
	UI.pass_scroll(b)
	b.add_theme_font_size_override("font_size", 18)
	if s.room_id == room_id:
		b.add_theme_stylebox_override("normal", UITheme.button_box(UITheme.ACCENT_DARK, UITheme.ACCENT, true))
		b.add_theme_color_override("font_color", UITheme.ACCENT)
	elif room_id != -1 and not GameState.room_has_free_slot(room_id):
		b.disabled = true
	b.pressed.connect(func() -> void: GameState.assign(s.id, room_id))
	return b


# --- Здоровье ---------------------------------------------------------------

func _build_health(s: SurvivorData) -> void:
	_body.add_child(UI.section_title("Здоровье"))
	_body.add_child(_big_stat("health", "%s  ·  %d / %d" % [s.health_label(), roundi(s.health), roundi(s.max_health)],
		s.health, s.max_health, UITheme.BAD))
	_body.add_child(UI.section_title("Настроение"))
	_body.add_child(_big_stat("mood", "%s  ·  %d / 100" % [s.mood_label(), roundi(s.mood)], s.mood, 100.0, UITheme.ACCENT))

	_body.add_child(UI.section_title("Состояние"))
	var notes: Array = []
	if s.has_condition("hungry"):
		notes.append(["Голод: вчера не хватило еды. Здоровье падает.", UITheme.BAD])
	if s.has_condition("thirsty"):
		notes.append(["Жажда: вчера не хватило воды. Здоровье падает.", UITheme.BAD])
	if s.has_condition("wounded"):
		notes.append(["Ранение: получено в экспедиции. Помогут медпункт или аптечка.", UITheme.BAD])
	if s.mood < 30.0:
		notes.append(["Подавленность: работает на 30% хуже.", UITheme.BAD])
	if s.health < s.max_health * 0.3:
		notes.append(["Истощение: работает на 30% хуже.", UITheme.BAD])
	if s.on_expedition:
		notes.append(["Находится на поверхности.", UITheme.TEAL])
	var people := GameState.survivors_in_shelter()
	var friends := RelationshipSystem.count_at_level(s, people, RelationshipSystem.FRIEND_LEVEL)
	var enemies := RelationshipSystem.count_at_level(s, people, RelationshipSystem.ENEMY_LEVEL)
	if friends > 0:
		notes.append(["Друзья рядом (%d): настроение растёт." % friends, UITheme.GOOD])
	if enemies > 0:
		notes.append(["Враги рядом (%d): настроение падает." % enemies, UITheme.BAD])
	if notes.is_empty():
		notes.append(["Жалоб нет.", UITheme.GOOD])
	for note: Array in notes:
		_body.add_child(UI.wrap_label(note[0], 18, note[1]))

	var healing := false
	for i in s.inventory.size():
		var item_id: String = s.inventory[i]
		if ItemDefs.is_usable(item_id):
			if not healing:
				_body.add_child(UI.section_title("Можно использовать"))
				healing = true
			_body.add_child(_item_row(item_id, "", [["Использовать", InventorySystem.use_item.bind(s, i), true]]))


func _big_stat(icon_name: String, text: String, value: float, max_value: float, color: Color) -> VBoxContainer:
	var box := UI.vbox(6)
	var row := UI.hbox(10)
	row.add_child(UI.icon(icon_name, 3))
	row.add_child(UI.label(text, 20))
	box.add_child(row)
	var bar := UI.bar(value, 0.0, max_value, color, Vector2(200, 22))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(bar)
	return box


# --- Инвентарь --------------------------------------------------------------

func _build_inventory(s: SurvivorData) -> void:
	var can_trade := not s.on_expedition
	_body.add_child(UI.section_title("Экипировка"))
	for slot in ItemDefs.SLOTS:
		var item_id: String = s.equipment[slot]
		var slot_name: String = ItemDefs.SLOT_NAMES[slot]
		if item_id == "":
			_body.add_child(_empty_row("%s: пусто" % slot_name))
		else:
			_body.add_child(_item_row(item_id, slot_name,
				[["Снять", InventorySystem.unequip.bind(s, slot), InventorySystem.has_space(s)]]))

	_body.add_child(UI.section_title("Рюкзак  %d/%d" % [s.inventory.size(), SurvivorData.MAX_INVENTORY]))
	if s.inventory.is_empty():
		_body.add_child(_empty_row("В рюкзаке пусто"))
	for i in s.inventory.size():
		var item_id: String = s.inventory[i]
		var actions: Array = []
		if ItemDefs.get_slot(item_id) != "":
			actions.append(["Надеть", InventorySystem.equip.bind(s, i), true])
		if ItemDefs.is_usable(item_id):
			actions.append(["Использовать", InventorySystem.use_item.bind(s, i), true])
		actions.append(["На склад", InventorySystem.put_to_storage.bind(s, i), can_trade])
		_body.add_child(_item_row(item_id, "", actions))

	_body.add_child(UI.section_title("Общий склад"))
	if GameState.storage.is_empty():
		_body.add_child(_empty_row("На складе нет предметов"))
	for item_id: String in GameState.storage:
		_body.add_child(_item_row(item_id, "×%d" % GameState.storage_count(item_id),
			[["Взять", InventorySystem.take_from_storage.bind(s, item_id), can_trade and InventorySystem.has_space(s)]]))


## Строка предмета. actions — массив [текст, Callable, доступно].
func _item_row(item_id: String, note: String, actions: Array) -> PanelContainer:
	var card := UI.card(UITheme.PANEL_LIGHT, 8)
	var row := UI.hbox(12)
	card.add_child(row)
	var icon := UI.texture(PixelIcons.item_icon(item_id, 4))
	icon.custom_minimum_size = Vector2(44, 44)
	row.add_child(icon)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := ItemDefs.name_of(item_id)
	if note != "":
		title += "  ·  " + note
	info.add_child(UI.label(title, 19))
	info.add_child(UI.label(ItemDefs.effect_text(item_id), 15, UITheme.TEAL))
	row.add_child(info)
	for action: Array in actions:
		var b := UI.button(action[0], 120, 52)
		UI.pass_scroll(b)
		b.add_theme_font_size_override("font_size", 17)
		b.disabled = not bool(action[2])
		var callable: Callable = action[1]
		b.pressed.connect(func() -> void: callable.call())
		row.add_child(b)
	return card


func _empty_row(text: String) -> PanelContainer:
	var card := UI.card(UITheme.PANEL_DARK, 12)
	card.add_child(UI.label(text, 17, UITheme.TEXT_DIM))
	return card


# --- Навыки -----------------------------------------------------------------

func _build_skills(s: SurvivorData) -> void:
	_body.add_child(UI.section_title("Навыки"))
	for skill_id in SkillDefs.IDS:
		var level := s.skill_level(skill_id)
		var bonus := s.equipment_bonus(skill_id)
		var card := UI.card(UITheme.PANEL_LIGHT, 10)
		var box := UI.vbox(4)
		card.add_child(box)
		var row := UI.hbox(10)
		var name_label := UI.label(SkillDefs.name_of(skill_id), 20)
		name_label.custom_minimum_size.x = 160
		row.add_child(name_label)
		row.add_child(UI.label("Ур. %d" % level, 20, UITheme.ACCENT))
		if bonus > 0:
			row.add_child(UI.label("+%d экипировка" % bonus, 16, UITheme.TEAL))
		row.add_child(UI.spacer())
		if level >= SkillDefs.MAX_LEVEL:
			row.add_child(UI.label("Максимум", 16, UITheme.GOOD))
		else:
			var need := SkillDefs.xp_for_next(level)
			row.add_child(UI.label("опыт %d/%d" % [s.skill_xp(skill_id), need], 15, UITheme.TEXT_DIM))
			row.add_child(UI.bar(s.skill_xp(skill_id), 0.0, need, UITheme.TEAL, Vector2(150, 14)))
		box.add_child(row)
		box.add_child(UI.wrap_label(SkillDefs.INFO[skill_id]["desc"], 15))
		_body.add_child(card)

	_body.add_child(UI.section_title("Характеристики"))
	if s.traits.is_empty():
		_body.add_child(_empty_row("Особых черт нет"))
	for trait_id: String in s.traits:
		var card := UI.card(UITheme.PANEL_LIGHT, 10)
		var box := UI.vbox(2)
		card.add_child(box)
		box.add_child(UI.label(TraitDefs.name_of(trait_id), 20, UITheme.ACCENT))
		box.add_child(UI.wrap_label(TraitDefs.get_desc(trait_id), 16))
		_body.add_child(card)


# --- Отношения --------------------------------------------------------------

func _build_relations(s: SurvivorData) -> void:
	_body.add_child(UI.section_title("Отношение к другим жителям"))
	var others: Array[SurvivorData] = []
	for other in GameState.survivors:
		if other.id != s.id:
			others.append(other)
	if others.is_empty():
		_body.add_child(_empty_row("В убежище больше никого нет"))
		return
	others.sort_custom(func(a: SurvivorData, b: SurvivorData) -> bool:
		return s.get_relation(a.id) > s.get_relation(b.id))
	for other in others:
		_body.add_child(_relation_card(s, other))
	_body.add_child(UI.wrap_label(
		"Отношения меняются каждый день. Общие увлечения сближают, совместная работа ускоряет перемены, а плохое настроение и тяжёлый характер ведут к ссорам.", 15))


func _relation_card(s: SurvivorData, other: SurvivorData) -> Button:
	var mine := s.get_relation(other.id)
	var theirs := other.get_relation(s.id)
	var shared := RelationshipSystem.shared_interests(s, other)
	var card := UI.button("", 0, 92 if shared.is_empty() else 116)
	UI.pass_scroll(card)
	card.pressed.connect(func() -> void: survivor_requested.emit(other.id))

	var row := UI.hbox(14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	card.add_child(row)
	var portrait := UI.texture(SurvivorSprites.get_portrait(other.appearance, 3))
	portrait.custom_minimum_size = Vector2(46, 62)
	row.add_child(portrait)

	var info := UI.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := UI.hbox(10)
	top.add_child(UI.label(other.full_name(), 20))
	top.add_child(UI.label(RelationshipSystem.level_name(mine), 18, RelationshipSystem.level_color(mine)))
	top.add_child(UI.spacer())
	top.add_child(UI.label(UI.signed(roundi(mine)), 18, RelationshipSystem.level_color(mine)))
	info.add_child(top)
	info.add_child(UI.RelationBar.new(mine, RelationshipSystem.level_color(mine)))
	info.add_child(UI.label("В ответ: %s (%s)" % [RelationshipSystem.level_name(theirs).to_lower(), UI.signed(roundi(theirs))],
		15, UITheme.TEXT_DIM))
	if not shared.is_empty():
		info.add_child(UI.label("Общие увлечения: %s" % InterestDefs.list_text(shared).to_lower(), 15, UITheme.TEAL))
	row.add_child(info)
	UI.ignore_mouse(row)
	return card
