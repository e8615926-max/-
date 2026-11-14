class_name ExpeditionsPanel
extends BasePanel
## Экспедиции: текущие вылазки и отправка новой.

signal message(text: String)

var _list: VBoxContainer
## Нижняя часть окна вне прокрутки: длительность, припасы и кнопка отправки.
var _footer: VBoxContainer
var _selected_id: int = -1
var _days: int = 1


func _init() -> void:
	super("Экспедиции", Vector2(940, 590))
	var parts := UI.scroll_list(8)
	content.add_child(parts[0])
	_list = parts[1]
	_footer = UI.vbox(8)
	content.add_child(_footer)


func _ready() -> void:
	GameState.survivors_changed.connect(_refresh)
	GameState.expeditions_changed.connect(_refresh)
	GameState.resources_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	UI.clear(_list)
	UI.clear(_footer)

	_list.add_child(UI.section_title("На поверхности"))
	if GameState.expeditions.is_empty():
		var empty := UI.card(UITheme.PANEL_DARK, 12)
		empty.add_child(UI.label("Сейчас никто не в экспедиции.", 17, UITheme.TEXT_DIM))
		_list.add_child(empty)
	for e in GameState.expeditions:
		var s := GameState.get_survivor(int(e["survivor_id"]))
		if s == null:
			continue
		var total := int(e["total_days"])
		var left := int(e["days_left"])
		var card := UI.card(UITheme.PANEL_LIGHT, 8)
		var row := UI.hbox(12)
		card.add_child(row)
		var portrait := UI.texture(SurvivorSprites.get_portrait(s.appearance, 3))
		portrait.custom_minimum_size = Vector2(44, 60)
		row.add_child(portrait)
		row.add_child(UI.label(s.full_name(), 20))
		var bar := UI.bar(total - left, 0.0, total, UITheme.TEAL, Vector2(160, 18))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		row.add_child(UI.label("вернётся через %d дн." % left, 17, UITheme.TEAL))
		_list.add_child(card)

	_list.add_child(UI.section_title("Новая экспедиция"))
	var candidates := GameState.survivors_in_shelter()
	if candidates.is_empty():
		_list.add_child(UI.wrap_label("В убежище некого отправить."))
		return
	if GameState.get_survivor(_selected_id) == null or GameState.get_survivor(_selected_id).on_expedition:
		_selected_id = -1
	_list.add_child(UI.wrap_label("Кого отправить? «Разведка» увеличивает добычу, «Бой» снижает риск. Чем дольше вылазка, тем больше и того, и другого.", 16))
	for s in candidates:
		_list.add_child(_candidate_button(s))

	var days_row := UI.hbox(8)
	days_row.add_child(UI.label("Дней:", 17, UITheme.TEXT_DIM))
	for d in range(ExpeditionSystem.MIN_DAYS, ExpeditionSystem.MAX_DAYS + 1):
		var b := UI.button(str(d), 72, 56)
		if d == _days:
			b.add_theme_stylebox_override("normal", UITheme.button_box(UITheme.ACCENT_DARK, UITheme.ACCENT, true))
			b.add_theme_color_override("font_color", UITheme.ACCENT)
		b.pressed.connect(func() -> void:
			_days = d
			_refresh())
		days_row.add_child(b)
	days_row.add_child(UI.spacer())
	var supplies := ExpeditionSystem.supplies_for(_days)
	days_row.add_child(UI.label("Припасы:", 17, UITheme.TEXT_DIM))
	for res: String in supplies:
		days_row.add_child(UI.icon(ResourceDefs.INFO[res]["icon"], 2))
		var enough := GameState.can_afford(res, int(supplies[res]))
		days_row.add_child(UI.label(str(int(supplies[res])), 18, UITheme.TEXT if enough else UITheme.BAD))
	_footer.add_child(days_row)

	var selected := GameState.get_survivor(_selected_id)
	if selected != null and not selected.on_expedition:
		var risk := ExpeditionSystem.danger_of(selected, _days)
		var odds := UI.label("%s: риск ранения %d%%, шанс находки %d%%" % [selected.first_name,
			roundi(risk * 100.0), roundi(ExpeditionSystem.find_chance(selected, _days) * 100.0)],
			17, UITheme.BAD if risk >= 0.4 else UITheme.TEAL)
		_footer.add_child(odds)
	var error := ExpeditionSystem.start_error(selected, _days)
	var send := UI.accent_button("Отправить в экспедицию" if error == "" else error, 0, 68)
	send.disabled = error != ""
	send.pressed.connect(_send)
	_footer.add_child(send)


func _candidate_button(s: SurvivorData) -> Button:
	var card := UI.button("", 0, 84)
	UI.pass_scroll(card)
	if s.id == _selected_id:
		card.add_theme_stylebox_override("normal", UITheme.button_box(UITheme.ACCENT_DARK, UITheme.ACCENT, true))
	card.pressed.connect(func() -> void:
		_selected_id = s.id
		_refresh())
	var row := UI.hbox(14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	card.add_child(row)
	var portrait := UI.texture(SurvivorSprites.get_portrait(s.appearance, 3))
	portrait.custom_minimum_size = Vector2(44, 60)
	row.add_child(portrait)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UI.label(s.full_name(), 20))
	info.add_child(UI.label("Разведка: %d  ·  Бой: %d  ·  %s" % [s.effective_skill("scavenging"),
		s.effective_skill("combat"), SurvivorsPanel.location_text(s)], 15, UITheme.TEXT_DIM))
	row.add_child(info)
	row.add_child(UI.icon("health", 2))
	row.add_child(UI.bar(s.health, 0.0, s.max_health, UITheme.BAD, Vector2(120, 16)))
	UI.ignore_mouse(row)
	return card


func _send() -> void:
	var s := GameState.get_survivor(_selected_id)
	if s == null:
		return
	var first_name := s.first_name
	var days := _days
	_selected_id = -1
	if ExpeditionSystem.start(s.id, days):
		message.emit("%s уходит на поверхность на %d дн." % [first_name, days])
