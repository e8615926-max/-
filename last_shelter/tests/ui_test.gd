extends Node
## Тест интерфейса настоящими нажатиями. События мыши и касаний проходят обычный
## путь ввода Godot, поэтому тест ловит неработающие и перекрытые кнопки.
## Нужен экран (на сервере — виртуальный):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 res://tests/ui_test.tscn
## Из редактора: запустить сцену tests/ui_test.tscn и не трогать мышь.
## Если задана переменная окружения SHOT_DIR, по ходу сохраняются скриншоты.

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const SAVE_PATH := "user://savegame.json"
## Точка заведомо вне любого окна (слева от рамки) — для закрытия касанием мимо.
const OUTSIDE := Vector2(20, 400)

var _passed: int = 0
var _failed: int = 0
var _shot_dir: String = ""


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	_run.call_deferred()


func _run() -> void:
	var backup := ""
	if FileAccess.file_exists(SAVE_PATH):
		backup = FileAccess.get_file_as_string(SAVE_PATH)
	SaveManager.delete_save()
	GameState.reset()

	# Меню становится текущей сценой, а тест остаётся рядом и переживает смену сцен.
	var menu: Node = (load(MAIN_MENU) as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	Input.warp_mouse(Vector2(640, 360))
	await _frames(10)

	await _test_new_game()
	await _test_survivors()
	await _test_build_and_rooms()
	await _test_storage_and_expedition()
	await _test_time_and_events()
	await _test_next_day_and_save()
	await _test_touch_scroll()
	await _test_restart_and_game_over()

	if backup != "":
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		SaveManager.delete_save()
	print("\n=== UI-тест: пройдено %d, провалено %d ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Сценарии -----------------------------------------------------------------

func _test_new_game() -> void:
	_check(_button("Продолжить") == null, "без сохранения нет кнопки «Продолжить»")
	await _shot("01_menu")
	await _click(_button("Новая игра"), "кнопка «Новая игра»")
	_check(await _wait_scene("Game"), "«Новая игра» открывает убежище")
	_calm()
	_check(GameState.day == 1 and GameState.survivors.size() == 2, "новая игра: день 1, двое выживших")
	_check(SaveManager.has_save(), "новая игра сразу сохраняется")
	await _shot("02_game")


func _test_survivors() -> void:
	var anna := GameState.survivors[0]
	var viktor := GameState.survivors[1]
	await _click(_button("2/4"), "кнопка выживших в верхней панели")
	_check(_panel(SurvivorsPanel) != null, "верхняя кнопка открывает список выживших")
	await _shot("03_survivors")
	await _click(_card(anna.full_name()), "карточка Анны")
	var profile := _panel(SurvivorProfilePanel) as SurvivorProfilePanel
	_check(profile != null and profile.survivor_id == anna.id, "карточка открывает профиль")
	if profile == null:
		return
	_check(_label_exact(anna.bio) != null, "в профиле видна биография")
	for tab: Array in SurvivorProfilePanel.TABS:
		await _click(_button(tab[1]), "вкладка «%s»" % tab[1])
		_check(profile.get("_tab") == tab[0], "вкладка «%s» переключается" % tab[1])
		await _shot("04_profile_" + tab[0])

	await _click(_button("Общее"), "вкладка «Общее»")
	await _click(_button("Ферма  0/2"), "работа «Ферма»")
	_check(anna.room_id == GameState.first_room_of_type("farm").id, "назначение на работу из профиля")

	await _click(_button("Инвентарь"), "вкладка «Инвентарь»")
	await _click(_row_button("Нож", "Взять"), "взять нож со склада")
	_check(anna.inventory.has("knife"), "предмет со склада попадает в рюкзак")
	await _click(_row_button("Нож", "Надеть"), "надеть нож")
	_check(anna.equipment["weapon"] == "knife", "предмет из рюкзака надевается")

	await _click(_button("Отношения"), "вкладка «Отношения»")
	await _click(_card(viktor.full_name()), "карточка Виктора в отношениях")
	profile = _panel(SurvivorProfilePanel) as SurvivorProfilePanel
	_check(profile != null and profile.survivor_id == viktor.id, "из отношений открывается чужой профиль")
	if profile == null:
		return
	await _click((profile.get("_header") as Node).get_child(0) as Control, "кнопка «назад»")
	var list := _panel(SurvivorsPanel)
	_check(list != null, "«назад» возвращает к списку")
	if list == null:
		return
	await _click(list.get("_close_button") as Control, "крестик")
	_check(_panel(BasePanel) == null, "крестик закрывает окно")


func _test_build_and_rooms() -> void:
	var shelter := get_tree().current_scene.get("_shelter") as ShelterView
	var viktor := GameState.survivors[1]
	var farm := GameState.first_room_of_type("farm")

	await _click(_button("Стройка"), "кнопка «Стройка»")
	_check(_panel(BuildPanel) != null, "«Стройка» открывает меню строительства")
	await _shot("05_build")
	await _click(_row_button("Жилой отсек", "Построить"), "выбрать жилой отсек")
	_check(shelter.get_build_type() == "quarters", "выбор комнаты включает режим стройки")
	await _click(_button("Отмена"), "отмена стройки")
	_check(shelter.get_build_type() == "" and GameState.rooms.size() == 4, "«Отмена» выключает режим стройки")

	await _click(_button("Стройка"), "кнопка «Стройка»")
	await _click(_row_button("Склад", "Построить"), "выбрать склад")
	await _shot("06_build_mode")
	await _tap(_slot_center(shelter, 2, 0))
	var built := GameState.room_at(2, 0)
	_check(built != null and built.type == "storage", "касание по подсвеченной ячейке строит комнату")
	_check(shelter.get_build_type() == "", "после постройки режим стройки выключается")

	await _tap(_slot_center(shelter, farm.level, farm.col))
	var room_panel := _panel(RoomPanel) as RoomPanel
	_check(room_panel != null and room_panel.room_id == farm.id, "касание по комнате открывает её окно")
	await _click(_row_button(viktor.full_name(), "Назначить"), "назначить Виктора")
	_check(viktor.room_id == farm.id, "назначение из окна комнаты")
	await _shot("07_room")
	await _click(_row_button(viktor.full_name(), "Снять"), "снять Виктора")
	_check(viktor.room_id == -1, "снятие с работы")
	await _click(_row_button(viktor.full_name(), "Профиль"), "профиль из окна комнаты")
	_check(_panel(SurvivorProfilePanel) != null, "из окна комнаты открывается профиль")
	await _tap(OUTSIDE)
	_check(_panel(BasePanel) == null, "касание мимо окна закрывает его")


func _test_storage_and_expedition() -> void:
	var viktor := GameState.survivors[1]
	await _click(_button("Склад"), "кнопка «Склад»")
	_check(_panel(StoragePanel) != null, "«Склад» открывает склад")
	await _shot("08_storage")
	await _tap(OUTSIDE)

	await _click(_button("Экспедиции"), "кнопка «Экспедиции»")
	_check(_panel(ExpeditionsPanel) != null, "«Экспедиции» открывает экспедиции")
	await _click(_card(viktor.full_name()), "выбор Виктора")
	await _click(_button("2"), "длительность 2 дня")
	await _shot("09_expedition")
	await _click(_button("Отправить в экспедицию"), "отправить в экспедицию")
	_check(viktor.on_expedition and int(ExpeditionSystem.find(viktor.id).get("total_days", 0)) == 2,
		"экспедиция отправлена на 2 дня")
	var panel := _panel(ExpeditionsPanel)
	if panel != null:
		await _click(panel.get("_close_button") as Control, "крестик")


func _test_next_day_and_save() -> void:
	var viktor_id := GameState.survivors[1].id
	await _click(_button("Следующий день"), "кнопка «Следующий день»")
	await _seconds(1.2)
	_check(GameState.day == 2 and _panel(DayReportPanel) != null, "«Следующий день» завершает день и показывает итоги")
	await _shot("10_report")
	await _click(_button("Начать день 2"), "закрыть итоги дня")
	_calm()
	_check(_panel(BasePanel) == null, "итоги дня закрываются")

	await _click(_menu_button(), "кнопка меню")
	_check(_panel(PausePanel) != null, "кнопка меню открывает меню")
	SaveManager.delete_save()
	await _click(_button("Сохранить игру"), "сохранить игру")
	_check(SaveManager.has_save(), "«Сохранить игру» записывает сохранение")
	await _key(KEY_ESCAPE)
	_check(_panel(PausePanel) != null, "Esc / «назад» без окон открывает меню")
	await _key(KEY_ESCAPE)
	_check(_panel(BasePanel) == null, "Esc / «назад» закрывает окно")

	await _click(_menu_button(), "кнопка меню")
	await _click(_button("В главное меню"), "в главное меню")
	_check(await _wait_scene("MainMenu"), "выход в главное меню")
	await _click(_button("Продолжить"), "продолжить")
	_check(await _wait_scene("Game"), "«Продолжить» открывает убежище")
	_calm()
	var viktor := GameState.get_survivor(viktor_id)
	_check(GameState.day == 2 and viktor != null and viktor.on_expedition,
		"сохранение загружено: день 2, Виктор в экспедиции")


func _test_time_and_events() -> void:
	var game := get_tree().current_scene
	await _click(_button("×1"), "кнопка скорости")
	_check(_button("×3") != null, "скорость времени переключается на ×3")

	await _click(_button_prefix("День "), "кнопка дня")
	var chronicle := _panel(ChroniclePanel)
	_check(chronicle != null, "кнопка дня открывает летопись")
	_check(_label_prefix("Гермодверь закрылась") != null, "в летописи записано начало")
	await _shot("12_chronicle")
	if chronicle != null:
		await _click(chronicle.get("_close_button") as Control, "закрыть летопись")

	# Событие в назначенный час.
	GameState.event_minute = int(GameState.minute) + 3
	var panel: Node = null
	for _i in 180:
		await get_tree().process_frame
		panel = _panel(EventPanel)
		if panel != null:
			break
	_check(panel != null, "в назначенный час случается событие")
	if panel != null:
		await _shot("13_event")
		var choices := _find_all(func(n: Node) -> bool:
			return n is Button and (n as Button).text == "" and not (n as Button).disabled, panel)
		var log_size := GameState.chronicle.size()
		await _click(choices[0] as Control if not choices.is_empty() else null, "вариант решения")
		_check(GameState.chronicle.size() == log_size + 1, "итог события записан в летопись")
		await _shot("14_event_result")
		await _click(_button("Продолжить"), "продолжить после события")
		_check(_panel(EventPanel) == null, "окно события закрывается после выбора")
	_calm()

	# Поломка и ремонт из окна комнаты.
	var farm := GameState.first_room_of_type("farm")
	farm.broken = true
	farm.condition = 20.0
	GameState.resources["metal"] = 80
	GameState.rooms_changed.emit()
	await _frames(3)
	await _tap(_slot_center(game.get("_shelter") as ShelterView, farm.level, farm.col))
	_check(_panel(RoomPanel) != null, "окно сломанной комнаты открывается")
	await _shot("15_broken_room")
	await _click(_button_prefix("Починить"), "кнопка ремонта")
	_check(not farm.broken and GameState.get_resource("metal") < 80, "ремонт чинит отсек за металл")
	await _tap(OUTSIDE)

	# Ночь: часы доходят до отбоя и останавливаются.
	GameState.minute = TimeSystem.NIGHT_START - 5.0
	for _i in 180:
		await get_tree().process_frame
		if GameState.is_night():
			break
	_check(GameState.is_night() and GameState.minute == TimeSystem.NIGHT_START, "наступает ночь, часы встают на отбое")
	await _frames(30)
	await _shot("16_night")
	await _click(_button("×3"), "вернуть скорость ×1")


func _test_touch_scroll() -> void:
	for _i in 5:
		GameState.add_survivor(SurvivorFactory.create_random(GameState.rng))
	await _click(_button("Выжившие"), "кнопка «Выжившие» внизу")
	var list := _panel(SurvivorsPanel)
	_check(list != null, "нижняя кнопка «Выжившие» открывает список")
	if list == null:
		return
	var scroll := _find_all(func(n: Node) -> bool: return n is ScrollContainer, list)[0] as ScrollContainer
	var card := _card(GameState.survivors[2].full_name())

	# Палец ложится на карточку и тянет список вверх.
	Input.emulate_touch_from_mouse = true
	var pos := card.get_global_rect().get_center()
	Input.warp_mouse(pos)
	await _frames(2)
	_push_button(pos, true)
	await _frames(1)
	for _i in 12:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.relative = Vector2(0, -20)
		pos += motion.relative
		motion.position = pos
		motion.global_position = pos
		get_viewport().push_input(motion, true)
		await _frames(1)
	_check(not card.is_pressed(), "прокрутка отменяет нажатие карточки")
	_push_button(pos, false)
	await _frames(10)
	Input.emulate_touch_from_mouse = false
	_check(scroll.scroll_vertical > 0, "список прокручивается пальцем")
	_check(_panel(SurvivorProfilePanel) == null, "после прокрутки профиль не открывается")
	await _shot("11_survivors_scrolled")
	await _key(KEY_ESCAPE)


func _test_restart_and_game_over() -> void:
	await _click(_menu_button(), "кнопка меню")
	await _click(_button("В главное меню"), "в главное меню")
	await _wait_scene("MainMenu")
	await _click(_button("Новая игра"), "новая игра поверх сохранения")
	_check(_panel(ConfirmPanel) != null, "новая игра поверх сохранения требует подтверждения")
	await _click(_button("Отмена"), "отмена")
	_check(_panel(ConfirmPanel) == null and SaveManager.has_save(), "«Отмена» сохраняет прежнюю игру")
	await _click(_button("Новая игра"), "новая игра")
	await _click(_button("Начать заново"), "начать заново")
	_check(await _wait_scene("Game") and GameState.day == 1, "«Начать заново» начинает новую игру")
	_calm()

	# Конец игры: все погибают от голода и жажды.
	for s in GameState.survivors:
		s.health = 1.0
	GameState.resources["food"] = 0
	GameState.resources["water"] = 0
	await _click(_button("Следующий день"), "следующий день")
	await _seconds(1.2)
	await _click(_button("Начать день 2"), "закрыть итоги")
	await _frames(5)
	_check(_panel(ConfirmPanel) != null, "после гибели всех жителей показывается конец игры")
	await _shot("12_game_over")
	await _key(KEY_ESCAPE)
	_check(_panel(ConfirmPanel) != null, "окно конца игры не закрывается кнопкой «назад»")
	await _click(_button("В главное меню"), "в главное меню")
	_check(await _wait_scene("MainMenu"), "из конца игры — в главное меню")
	_check(not SaveManager.has_save() and _button("Продолжить") == null, "после конца игры сохранение удалено")


# --- Ввод ---------------------------------------------------------------------

## Касание в точке экрана: курсор переезжает туда, затем нажатие и отпускание.
func _tap(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	await _frames(2)
	_push_button(pos, true)
	await _frames(1)
	_push_button(pos, false)
	await _frames(3)


func _push_button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)


## Нажимает элемент интерфейса; если он в списке за краем — сначала прокручивает к нему.
func _click(control: Control, what: String) -> void:
	if control == null:
		_check(false, "не найдено: " + what)
		return
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(control)
			await _frames(2)
			break
		parent = parent.get_parent()
	await _tap(control.get_global_rect().get_center())


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		get_viewport().push_input(ev)
		await _frames(2)


# --- Поиск элементов --------------------------------------------------------------

## Тест не должен зависеть от случайных событий: убираем запланированное на сегодня.
func _calm() -> void:
	GameState.event_minute = -1


func _button_prefix(prefix: String) -> Button:
	var found := _find_all(func(n: Node) -> bool: return n is Button and (n as Button).text.begins_with(prefix))
	return found[0] if not found.is_empty() else null


func _label_prefix(prefix: String) -> Label:
	var found := _find_all(func(n: Node) -> bool: return n is Label and (n as Label).text.begins_with(prefix))
	return found[0] if not found.is_empty() else null


func _label_exact(text: String) -> Label:
	var found := _find_all(func(n: Node) -> bool: return n is Label and (n as Label).text == text)
	return found[0] if not found.is_empty() else null


func _find_all(filter: Callable, root: Node = null) -> Array:
	var out: Array = []
	_walk(root if root != null else get_tree().root, out, filter)
	return out


func _walk(node: Node, out: Array, filter: Callable) -> void:
	if node.is_queued_for_deletion():
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if filter.call(node):
		out.append(node)
	for child in node.get_children():
		_walk(child, out, filter)


func _button(text: String, root: Node = null) -> Button:
	var found := _find_all(func(n: Node) -> bool: return n is Button and (n as Button).text == text, root)
	return found[0] if not found.is_empty() else null


## Кнопка-карточка, внутри которой есть надпись с этим текстом.
func _card(label_text: String) -> Button:
	for label: Label in _find_all(func(n: Node) -> bool: return n is Label and (n as Label).text == label_text):
		var p := label.get_parent()
		while p != null and not (p is Button):
			p = p.get_parent()
		if p != null:
			return p as Button
	return null


## Кнопка в той же строке-карточке, что и надпись, начинающаяся с label_prefix.
func _row_button(label_prefix: String, button_text: String) -> Button:
	for label: Label in _find_all(func(n: Node) -> bool: return n is Label and (n as Label).text.begins_with(label_prefix)):
		var p := label.get_parent()
		while p != null and not (p is PanelContainer):
			p = p.get_parent()
		if p != null:
			var b := _button(button_text, p)
			if b != null:
				return b
	return null


func _panel(type: Variant) -> Node:
	var found := _find_all(func(n: Node) -> bool: return is_instance_of(n, type))
	return found[0] if not found.is_empty() else null


func _menu_button() -> Button:
	var top := get_tree().current_scene.get("_top") as Node
	var found := _find_all(func(n: Node) -> bool: return n is Button, top)
	return found[0] if not found.is_empty() else null


func _slot_center(view: ShelterView, level: int, col: int) -> Vector2:
	var world := view.get("_world") as Node2D
	var center := ShelterLayout.room_origin(level, col) + Vector2(ShelterLayout.ROOM_W, ShelterLayout.ROOM_H) * 0.5
	return world.get_global_transform() * center


# --- Служебное ------------------------------------------------------------------

func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("ПРОВАЛ: " + what)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _seconds(time: float) -> void:
	await get_tree().create_timer(time).timeout


func _wait_scene(scene_name: String) -> bool:
	for _i in 300:
		var scene := get_tree().current_scene
		if scene != null and scene.name == scene_name and scene.is_node_ready():
			await _frames(3)
			return true
		await get_tree().process_frame
	return false


func _shot(shot_name: String) -> void:
	if _shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shot_dir, shot_name])
