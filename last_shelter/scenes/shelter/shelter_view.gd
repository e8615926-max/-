class_name ShelterView
extends Control
## Вид убежища сбоку: масштабирует пиксельный мир под экран, показывает
## комнаты и жителей и превращает касания в события «нажата комната / ячейка».

signal room_tapped(room_id: int)
signal slot_tapped(level: int, col: int)

const TAP_SLOP := 16.0

var _world: Node2D
var _canvas: ShelterCanvas
var _actor_layer: Node2D
var _label_layer: Control
var _actors: Dictionary = {}
var _scale: int = 3
var _press_pos: Vector2 = Vector2.INF


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_world = Node2D.new()
	add_child(_world)
	_canvas = ShelterCanvas.new()
	_world.add_child(_canvas)
	_actor_layer = Node2D.new()
	_world.add_child(_actor_layer)
	_label_layer = Control.new()
	_label_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_label_layer)


func _ready() -> void:
	resized.connect(_layout)
	GameState.rooms_changed.connect(_refresh)
	GameState.survivors_changed.connect(_refresh)
	GameState.resources_changed.connect(_refresh_power)
	_layout()
	_refresh()


func set_build_type(type: String) -> void:
	_canvas.build_type = type
	_canvas.queue_redraw()


func get_build_type() -> String:
	return _canvas.build_type


# --- Раскладка ------------------------------------------------------------

func _layout() -> void:
	var fit := minf(size.x / ShelterLayout.WORLD_W, size.y / ShelterLayout.WORLD_H)
	_scale = clampi(floori(fit), 1, 8)
	_world.scale = Vector2(_scale, _scale)
	var world_px := Vector2(ShelterLayout.WORLD_W, ShelterLayout.WORLD_H) * _scale
	_world.position = ((size - world_px) * 0.5).floor()
	_refresh_labels()


func _world_to_local(p: Vector2) -> Vector2:
	return _world.position + p * _scale


# --- Обновление содержимого -------------------------------------------------

func _refresh() -> void:
	_refresh_power()
	_refresh_actors()
	_refresh_labels()
	_canvas.queue_redraw()


func _refresh_power() -> void:
	var unpowered: Array[int] = DaySystem.compute_economy()["unpowered"]
	if unpowered != _canvas.unpowered:
		_canvas.unpowered = unpowered
		_canvas.queue_redraw()


func _refresh_actors() -> void:
	var alive := {}
	for s in GameState.survivors:
		alive[s.id] = true
		var actor: SurvivorActor = _actors.get(s.id)
		if actor == null:
			actor = SurvivorActor.new()
			actor.setup(s)
			_actor_layer.add_child(actor)
			_actors[s.id] = actor
		actor.visible = not s.on_expedition
		if s.on_expedition:
			actor.set_zone("away", 0.0, 0.0, 0.0)
			continue
		# Без работы жители отдыхают в жилом отсеке (или у лифта, если его нет).
		var room := GameState.get_room(s.room_id)
		if room == null:
			room = GameState.first_room_of_type("quarters")
		if room != null:
			var o := ShelterLayout.room_origin(room.level, room.col)
			actor.set_zone("room%d" % room.id, o.x + 4.0,
				o.x + ShelterLayout.ROOM_W - 4.0 - SurvivorSprites.FRAME_W, o.y + RoomPainter.FLOOR_Y)
		else:
			actor.set_zone("shaft", ShelterLayout.SHAFT_X + 3.0, ShelterLayout.SHAFT_X + 3.0,
				float(ShelterLayout.SURFACE_Y + RoomPainter.FLOOR_Y))
	for id: int in _actors.keys():
		if not alive.has(id):
			(_actors[id] as SurvivorActor).queue_free()
			_actors.erase(id)


func _refresh_labels() -> void:
	for child in _label_layer.get_children():
		child.queue_free()
	for room in GameState.rooms:
		var def := room.get_def()
		var text := room.display_name()
		var slots := int(def["slots"])
		if slots > 0:
			text += "  %d/%d" % [GameState.workers_of(room.id).size(), slots]
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", clampi(_scale * 4 + 1, 9, 22))
		label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Подпись лежит на перекрытии под комнатой и не закрывает графику.
		label.clip_text = true
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = _world_to_local(ShelterLayout.room_origin(room.level, room.col) + Vector2(3, ShelterLayout.ROOM_H))
		label.size = Vector2(ShelterLayout.ROOM_W - 6, ShelterLayout.SLAB_H) * _scale
		_label_layer.add_child(label)


# --- Ввод -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_press_pos = mb.position
		return
	# Срабатываем на отпускание, если палец почти не сдвинулся.
	if _press_pos == Vector2.INF or _press_pos.distance_to(mb.position) > TAP_SLOP:
		_press_pos = Vector2.INF
		return
	_press_pos = Vector2.INF
	var world_pos := (mb.position - _world.position) / float(_scale)
	var slot := ShelterLayout.slot_at(world_pos)
	if slot.x < 0:
		return
	var room := GameState.room_at(slot.y, slot.x)
	if room != null:
		room_tapped.emit(room.id)
	else:
		slot_tapped.emit(slot.y, slot.x)
	accept_event()
