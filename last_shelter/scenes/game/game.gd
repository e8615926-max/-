extends Control
## Игровая сцена: собирает вид убежища, верхнюю и нижнюю панели,
## ведёт часы и события дня, управляет окнами, режимом стройки и сменой дня.

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"

var _shelter: ShelterView
var _top: TopBar
var _bottom: BottomBar
var _overlay: Control
var _panel: BasePanel
var _build_banner: PanelContainer
var _build_label: Label
var _toast: Label
var _toast_tween: Tween
var _fade: ColorRect
var _busy: bool = false
var _speed_index: int = 0
var _night_tween: Tween


func _ready() -> void:
	theme = UITheme.build()
	# Если сцену запустили напрямую из редактора — начинаем новую игру.
	if GameState.survivors.is_empty():
		GameState.new_game()
	GameState.active = true
	_build_ui()
	if GameState.day == 1 and GameState.workers_count() == 0:
		_show_toast("Нажмите на комнату, чтобы назначить работников", 5.0)
	if GameState.is_night():
		_start_night_pulse()


## Часы идут, пока не открыто ни одно окно; в назначенную минуту случается событие.
func _process(delta: float) -> void:
	if _busy or _has_panel() or GameState.survivors.is_empty():
		return
	if GameState.minute >= TimeSystem.NIGHT_START:
		return
	var before := GameState.minute
	GameState.advance_clock(delta * TimeSystem.MINUTES_PER_SECOND * TimeSystem.SPEEDS[_speed_index])
	var when := GameState.event_minute
	if when >= 0 and before < when and GameState.minute >= when:
		GameState.event_minute = -1
		var ev := EventSystem.roll(GameState.rng)
		if not ev.is_empty():
			_cancel_build()
			_show_event(ev)
	if GameState.minute >= TimeSystem.NIGHT_START:
		_show_toast("Ночь. Жители легли спать — нажмите «Следующий день».", 4.0)
		_start_night_pulse()


func _exit_tree() -> void:
	GameState.active = false


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_shelter = ShelterView.new()
	_shelter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shelter.room_tapped.connect(_on_room_tapped)
	_shelter.slot_tapped.connect(_on_slot_tapped)
	add_child(_shelter)

	_top = TopBar.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.menu_pressed.connect(_open_pause)
	_top.survivors_pressed.connect(_open_survivors)
	_top.chronicle_pressed.connect(_open_chronicle)
	_top.speed_pressed.connect(_toggle_speed)
	add_child(_top)

	_bottom = BottomBar.new()
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom.action_pressed.connect(_on_action)
	add_child(_bottom)

	_build_banner = PanelContainer.new()
	_build_banner.add_theme_stylebox_override("panel", UITheme.box(UITheme.PANEL, UITheme.ACCENT, 3, 10))
	_build_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_build_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_build_banner.visible = false
	var banner_row := UI.hbox(14)
	_build_banner.add_child(banner_row)
	_build_label = UI.label("", 20, UITheme.ACCENT)
	banner_row.add_child(_build_label)
	var cancel := UI.button("Отмена", 130, 52)
	cancel.pressed.connect(_cancel_build)
	banner_row.add_child(cancel)
	add_child(_build_banner)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_toast = UI.label("", 20, UITheme.TEXT)
	_toast.add_theme_stylebox_override("normal", UITheme.box(Color(0.05, 0.04, 0.04, 0.92), UITheme.ACCENT, 2, 12))
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	# Вид убежища занимает всё место между панелями, какой бы высоты они ни получились.
	var top_h := _top.get_combined_minimum_size().y
	var bottom_h := _bottom.get_combined_minimum_size().y
	_shelter.offset_top = top_h
	_shelter.offset_bottom = -bottom_h
	_build_banner.offset_top = top_h + 10
	_toast.offset_bottom = -(bottom_h + 14)

	var inset := SafeArea.side_inset(get_viewport())
	_top.set_side_inset(inset)
	_bottom.set_side_inset(inset)


# --- Окна -------------------------------------------------------------------

func _open(panel: BasePanel) -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = panel
	_toast.visible = false
	panel.closed.connect(func() -> void:
		if _panel == panel:
			_panel = null)
	_overlay.add_child(panel)


func _has_panel() -> bool:
	return _panel != null and is_instance_valid(_panel)


func _open_survivors() -> void:
	_cancel_build()
	var panel := SurvivorsPanel.new()
	panel.survivor_selected.connect(_open_profile)
	_open(panel)


func _open_profile(id: int) -> void:
	if GameState.get_survivor(id) == null:
		return
	var panel := SurvivorProfilePanel.new(id)
	panel.back_requested.connect(_open_survivors)
	panel.survivor_requested.connect(_open_profile)
	_open(panel)


func _open_build() -> void:
	_cancel_build()
	var panel := BuildPanel.new()
	panel.build_requested.connect(_start_build)
	_open(panel)


func _open_storage() -> void:
	_cancel_build()
	_open(StoragePanel.new())


func _open_expeditions() -> void:
	_cancel_build()
	var panel := ExpeditionsPanel.new()
	panel.message.connect(_show_toast)
	_open(panel)


func _open_chronicle() -> void:
	_cancel_build()
	_open(ChroniclePanel.new())


func _show_event(ev: Dictionary) -> void:
	if ev.is_empty():
		return
	var panel := EventPanel.new(ev)
	panel.resolved.connect(func(_result: Dictionary) -> void: SaveManager.save_game())
	_open(panel)


func _toggle_speed() -> void:
	_speed_index = (_speed_index + 1) % TimeSystem.SPEEDS.size()
	_top.set_speed(TimeSystem.SPEEDS[_speed_index])


func _open_pause() -> void:
	_cancel_build()
	var panel := PausePanel.new()
	panel.chronicle_requested.connect(_open_chronicle)
	panel.research_requested.connect(_open_research)
	panel.radio_requested.connect(_open_radio)
	panel.save_requested.connect(func() -> void:
		_show_toast("Игра сохранена" if SaveManager.save_game() else "Не удалось сохранить игру")
		panel.close())
	panel.exit_requested.connect(_exit_to_menu)
	_open(panel)


func _on_room_tapped(room_id: int) -> void:
	if _busy:
		return
	if _shelter.get_build_type() != "":
		_show_toast("Это место уже занято")
		return
	_open_room(room_id)


func _open_room(room_id: int) -> void:
	var panel := RoomPanel.new(room_id)
	panel.survivor_requested.connect(_open_profile)
	panel.research_requested.connect(_open_research)
	panel.radio_requested.connect(_open_radio)
	panel.decor_requested.connect(_open_decor)
	_open(panel)


func _open_research() -> void:
	_cancel_build()
	_open(ResearchPanel.new())


func _open_radio() -> void:
	_cancel_build()
	_open(RadioPanel.new())


func _open_decor(room_id: int, slot: int) -> void:
	var panel := DecorPanel.new(room_id, slot)
	panel.back_requested.connect(_open_room.bind(room_id))
	_open(panel)


func _on_action(action: String) -> void:
	if _busy:
		return
	match action:
		"build": _open_build()
		"survivors": _open_survivors()
		"storage": _open_storage()
		"expeditions": _open_expeditions()
		"next_day": _next_day()


# --- Стройка ----------------------------------------------------------------

func _start_build(type: String) -> void:
	if _has_panel():
		_panel.close()
	_shelter.set_build_type(type)
	_build_label.text = "%s: выберите подсвеченное место" % RoomDefs.name_of(type)
	_build_banner.visible = true


func _cancel_build() -> void:
	_shelter.set_build_type("")
	_build_banner.visible = false


func _on_slot_tapped(level: int, col: int) -> void:
	var type := _shelter.get_build_type()
	if type == "" or _busy:
		return
	var error := GameState.build_error(type, level, col)
	if error != "":
		_show_toast(error)
		return
	GameState.build_room(type, level, col)
	_cancel_build()
	_show_toast("Построено: %s" % RoomDefs.name_of(type))


# --- Смена дня --------------------------------------------------------------

func _next_day() -> void:
	if _has_panel():
		return
	_cancel_build()
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(_resolve_day)
	tween.tween_interval(0.15)
	tween.tween_property(_fade, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false)


func _resolve_day() -> void:
	var report := DaySystem.advance()
	_stop_night_pulse()
	if not report["game_over"]:
		SaveManager.save_game()
	var panel := DayReportPanel.new(report)
	if report["game_over"]:
		panel.closed.connect(_show_game_over.bind(int(report["day"])), CONNECT_DEFERRED)
	elif not (report["event"] as Dictionary).is_empty():
		# Событие, до которого не дошли днём, случается утром.
		panel.closed.connect(_show_event.bind(report["event"]), CONNECT_DEFERRED)
	_open(panel)


## Ночью кнопка «Следующий день» мягко мигает.
func _start_night_pulse() -> void:
	if _night_tween != null and _night_tween.is_valid():
		return
	var button := _bottom.get_button("next_day")
	_night_tween = create_tween().set_loops()
	_night_tween.tween_property(button, "self_modulate", Color(1.35, 1.25, 1.0), 0.6)
	_night_tween.tween_property(button, "self_modulate", Color.WHITE, 0.6)


func _stop_night_pulse() -> void:
	if _night_tween != null and _night_tween.is_valid():
		_night_tween.kill()
	_night_tween = null
	_bottom.get_button("next_day").self_modulate = Color.WHITE


func _show_game_over(days: int) -> void:
	SaveManager.delete_save()
	var panel := ConfirmPanel.new("Убежище опустело",
		"Последний житель погиб. Убежище продержалось %d дн.\nМожет быть, в следующий раз повезёт больше." % days,
		"В главное меню")
	panel.set_dismissable(false)
	panel.confirmed.connect(func() -> void:
		GameState.reset()
		get_tree().change_scene_to_file(MAIN_MENU))
	_open(panel)


func _exit_to_menu() -> void:
	if not GameState.survivors.is_empty():
		SaveManager.save_game()
	get_tree().change_scene_to_file(MAIN_MENU)


# --- Сообщения и системные кнопки ---------------------------------------------

func _show_toast(text: String, duration: float = 2.2) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)


func _go_back() -> void:
	if _busy:
		return
	if _has_panel():
		if _panel.dismissable:
			_panel.close()
	elif _shelter.get_build_type() != "":
		_cancel_build()
	else:
		_open_pause()


func _notification(what: int) -> void:
	# Системная кнопка «назад» на Android.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()
