class_name WorldPanel
extends BasePanel
## Внешний мир: торговец у ворот, соседние общины и архив находок.

signal message(text: String)

const TABS := [["trade", "Торговец", "trade"], ["shelters", "Общины", "shelters"], ["archive", "Архив", "archive"]]

var _tab: String = "trade"
var _tabs_row: HBoxContainer
var _list: VBoxContainer


func _init(tab: String = "trade") -> void:
	super("Внешний мир", Vector2(960, 600))
	_tab = tab
	_tabs_row = UI.hbox(8)
	content.add_child(_tabs_row)
	var parts := UI.scroll_list(8)
	content.add_child(parts[0])
	_list = parts[1]


func _ready() -> void:
	GameState.world_changed.connect(_refresh)
	GameState.resources_changed.connect(_refresh)
	GameState.storage_changed.connect(_refresh)
	_refresh()


func get_tab() -> String:
	return _tab


func show_tab(tab: String) -> void:
	_tab = tab
	_refresh()


func _refresh() -> void:
	UI.clear(_tabs_row)
	for entry: Array in TABS:
		var id: String = entry[0]
		var b := UI.button(entry[1], 0, 60)
		b.icon = PixelIcons.get_icon(entry[2], 3)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "tab_" + id
		if id == _tab:
			b.add_theme_stylebox_override("normal", UITheme.button_box(UITheme.ACCENT_DARK, UITheme.ACCENT, true))
			b.add_theme_color_override("font_color", UITheme.ACCENT)
		b.pressed.connect(show_tab.bind(id))
		_tabs_row.add_child(b)
	UI.clear(_list)
	match _tab:
		"trade": _fill_trade()
		"shelters": _fill_shelters()
		"archive": _fill_archive()


# --- Торговец ------------------------------------------------------------------

func _fill_trade() -> void:
	if not TradeSystem.present():
		var card := UI.card(UITheme.PANEL_DARK, 14)
		var box := UI.vbox(6)
		card.add_child(box)
		box.add_child(UI.label("У ворот никого нет", 20))
		var wait := maxi(GameState.next_merchant_day - GameState.day, 1)
		box.add_child(UI.wrap_label("Бродячие торговцы заходят раз в несколько дней. Следующего ждут примерно через %d дн." % wait, 16))
		_list.add_child(card)
		return
	var m: Dictionary = GameState.merchant
	var def: Dictionary = MerchantDefs.INFO[m["id"]]
	var head := UI.card(UITheme.PANEL_DARK, 12)
	var head_box := UI.vbox(4)
	head.add_child(head_box)
	head_box.add_child(UI.label(String(def["name"]), 22, UITheme.ACCENT))
	head_box.add_child(UI.wrap_label(String(def["greeting"]), 16))
	head_box.add_child(UI.label("Уйдёт через %d дн. · Покупает вещи за: %s" % [int(m["days_left"]),
		ResourceDefs.name_of(TradeSystem.currency()).to_lower()], 15, UITheme.TEAL))
	_list.add_child(head)

	_list.add_child(UI.section_title("Обмен"))
	var deals: Array = m["deals"]
	for i in deals.size():
		var buy := func() -> void:
			if TradeSystem.buy(i):
				SoundManager.play("coins")
		_list.add_child(_deal_card(deals[i], TradeSystem.deal_error(i), "Осталось: %d" % int(deals[i]["stock"]), buy))

	_list.add_child(UI.section_title("Продать со склада"))
	if GameState.storage.is_empty():
		_list.add_child(UI.label("На складе нечего продать.", 16, UITheme.TEXT_DIM))
	for item_id: String in GameState.storage.keys():
		var card := UI.card(UITheme.PANEL_LIGHT, 8)
		var row := UI.hbox(12)
		card.add_child(row)
		var icon := UI.texture(PixelIcons.item_icon(item_id, 4))
		icon.custom_minimum_size = Vector2(44, 44)
		row.add_child(icon)
		var name_label := UI.label("%s ×%d" % [ItemDefs.name_of(item_id), GameState.storage_count(item_id)], 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UI.cost_row({TradeSystem.currency(): TradeSystem.sell_price(item_id)}, 18))
		var error := TradeSystem.sell_error(item_id)
		var sell := UI.button("Продать" if error == "" else error, 180, 56)
		sell.disabled = error != ""
		sell.pressed.connect(func() -> void:
			if TradeSystem.sell(item_id):
				SoundManager.play("coins"))
		row.add_child(sell)
		_list.add_child(card)


## Карточка сделки: отдаём → получаем, пометка и кнопка.
func _deal_card(deal: Dictionary, error: String, note: String, action: Callable, give_override: Dictionary = {}) -> Control:
	var card := UI.card(UITheme.PANEL_LIGHT, 8)
	var row := UI.hbox(12)
	card.add_child(row)
	row.add_child(UI.cost_row(give_override if not give_override.is_empty() else deal["give"], 18))
	row.add_child(UI.label("→", 22, UITheme.TEXT_DIM))
	var gain := UI.hbox(8)
	gain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if deal.has("item"):
		var item_id := String(deal["item"])
		var icon := UI.texture(PixelIcons.item_icon(item_id, 4))
		icon.custom_minimum_size = Vector2(44, 44)
		gain.add_child(icon)
		var info := UI.vbox(0)
		var rare := ItemDefs.is_rare(item_id) or bool(deal.get("rare", false))
		info.add_child(UI.label(ItemDefs.name_of(item_id) + ("  · редкость" if rare else ""), 18, UITheme.ACCENT if rare else UITheme.TEXT))
		info.add_child(UI.label(ItemDefs.effect_text(item_id), 14, UITheme.TEAL))
		gain.add_child(info)
	else:
		gain.add_child(UI.cost_row(deal["get"], 18))
	row.add_child(gain)
	if note != "":
		row.add_child(UI.label(note, 15, UITheme.TEXT_DIM))
	var b := UI.accent_button("Обменять" if error == "" else error, 200, 56)
	b.disabled = error != ""
	b.pressed.connect(action)
	row.add_child(b)
	return card


# --- Общины --------------------------------------------------------------------

func _fill_shelters() -> void:
	_list.add_child(UI.wrap_label("Соседи узнают о нас, когда мы находим их места. Помощь улучшает отношения, просьбы — расходуют доверие. С друзьями обмен выгоднее, а союзники сами присылают подарки.", 15))
	for id: String in ShelterDefs.INFO:
		var def: Dictionary = ShelterDefs.INFO[id]
		if not ShelterSystem.is_known(id):
			var hidden := UI.card(UITheme.PANEL_DARK, 12)
			hidden.add_child(UI.label("Неизвестная община · о ней узнают в месте «%s»" % LocationDefs.name_of(String(def["location"])),
				16, UITheme.TEXT_DIM))
			_list.add_child(hidden)
			continue
		var rel := ShelterSystem.relation(id)
		var card := UI.card(UITheme.PANEL_LIGHT, 12)
		var box := UI.vbox(6)
		card.add_child(box)
		var title := UI.hbox(10)
		title.add_child(UI.label(String(def["name"]), 21, UITheme.ACCENT))
		title.add_child(UI.label("%d чел." % int(def["people"]), 15, UITheme.TEXT_DIM))
		title.add_child(UI.spacer())
		title.add_child(UI.label("%s (%s)" % [ShelterSystem.relation_label(rel), UI.signed(rel)], 17,
			UITheme.GOOD if rel >= 25 else (UITheme.BAD if rel < -10 else UITheme.TEXT)))
		box.add_child(title)
		var bar := UI.bar(rel + 100, 0.0, 200.0, UITheme.GOOD if rel >= 0 else UITheme.BAD, Vector2(200, 12))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(bar)
		box.add_child(UI.wrap_label(String(def["situation"]), 16))
		var actions := UI.hbox(10)
		var help_error := ShelterSystem.help_error(id)
		var help := UI.button("Помочь: %s" % ResourceDefs.cost_text(def["needs"]) if help_error == "" else help_error, 0, 56)
		help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		help.disabled = help_error != ""
		help.pressed.connect(func() -> void:
			if ShelterSystem.send_help(id):
				SoundManager.play("confirm")
				message.emit("%s благодарят за помощь" % ShelterDefs.name_of(id)))
		actions.add_child(help)
		var ask_error := ShelterSystem.request_error(id)
		var ask := UI.button("Попросить: %s" % ResourceDefs.cost_text(def["offers"]) if ask_error == "" else ask_error, 0, 56)
		ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ask.disabled = ask_error != ""
		ask.pressed.connect(func() -> void:
			if ShelterSystem.request_help(id):
				SoundManager.play("coins"))
		actions.add_child(ask)
		box.add_child(actions)
		var deals: Array = def["deals"]
		for i in deals.size():
			var cost := ShelterSystem.deal_cost(id, i)
			var swap := func() -> void:
				if ShelterSystem.trade(id, i):
					SoundManager.play("coins")
			box.add_child(_deal_card(deals[i], ShelterSystem.trade_error(id, i), "", swap, cost))
		_list.add_child(card)


# --- Архив ---------------------------------------------------------------------

func _fill_archive() -> void:
	var progress := DocumentSystem.progress()
	var head := UI.card(UITheme.PANEL_DARK, 12)
	var head_box := UI.vbox(4)
	head.add_child(head_box)
	head_box.add_child(UI.label("Собрано находок: %d из %d" % [progress.x, progress.y], 20, UITheme.ACCENT))
	var bar := UI.bar(progress.x, 0.0, progress.y, UITheme.TEAL, Vector2(200, 12))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_box.add_child(bar)
	var where: PackedStringArray = []
	for id in GameState.locations:
		if not DocumentSystem.remaining(id).is_empty():
			where.append(LocationDefs.name_of(id))
	if not where.is_empty():
		head_box.add_child(UI.wrap_label("Ещё есть что искать: %s." % ", ".join(where), 15, UITheme.TEAL))
	_list.add_child(head)
	if GameState.documents.is_empty():
		_list.add_child(UI.wrap_label("Пока ничего. Документы, записи и снаряжение находят в вылазках — каждая находка проясняет, что случилось той ночью.", 16))
	for i in range(GameState.documents.size() - 1, -1, -1):
		var doc_id := GameState.documents[i]
		var def: Dictionary = DocumentDefs.INFO[doc_id]
		var card := UI.card(UITheme.PANEL_LIGHT, 10)
		var box := UI.vbox(4)
		card.add_child(box)
		box.add_child(UI.label("%s · %s" % [DocumentDefs.KIND_NAMES[def["kind"]], def["title"]], 18, UITheme.ACCENT))
		box.add_child(UI.wrap_label(String(def["text"]), 17, UITheme.TEXT))
		var witness := DocumentSystem.witness_of(doc_id)
		if witness != null:
			box.add_child(UI.label("%s видел%s это в ту ночь." % [witness.first_name, witness.by_gender("", "а")], 15, UITheme.TEAL))
		_list.add_child(card)
