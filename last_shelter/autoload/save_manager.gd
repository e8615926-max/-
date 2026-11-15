extends Node
## Локальные сохранения (автозагрузка SaveManager).
## Один слот, JSON в user:// — работает без сети и без разрешений Android;
## в браузере Godot хранит user:// в IndexedDB.
## Версия 2 добавила время суток, летопись, состояние комнат, профессии, биографии
## и семьи; версия 3 — новые ресурсы, болезни, уровни комнат, исследования, эфир и украшения;
## версия 4 — новые места и их истощение, находки, торговцы и отношения с другими общинами.
## Старые сохранения загружаются с разумными значениями по умолчанию.

const SAVE_PATH := "user://savegame.json"
const TEMP_PATH := "user://savegame.tmp"
const VERSION := 4


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var payload := {"version": VERSION, "state": GameState.to_dict()}
	# Сначала пишем во временный файл, чтобы не испортить сохранение
	# при закрытии приложения посреди записи.
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось открыть файл сохранения: %d" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	return dir.rename(TEMP_PATH, SAVE_PATH) == OK


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Файл сохранения повреждён")
		return false
	var payload: Dictionary = parsed
	if int(payload.get("version", 0)) > VERSION or not payload.get("state") is Dictionary:
		push_warning("Неподдерживаемая версия сохранения")
		return false
	GameState.from_dict(payload["state"])
	return not GameState.survivors.is_empty()


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func _notification(what: int) -> void:
	# Android может выгрузить приложение без предупреждения — сохраняемся при сворачивании.
	# В браузере вкладку могут закрыть в любой момент — сохраняемся, когда она теряет фокус.
	var leaving := what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("web"):
		leaving = true
	if leaving and GameState.active and not GameState.survivors.is_empty():
		save_game()
