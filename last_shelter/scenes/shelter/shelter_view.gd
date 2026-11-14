class_name ShelterView
extends Control
## Вид убежища сбоку: масштабирует пиксельный мир под экран, показывает
## комнаты и жителей и превращает касания в события «нажата комната / ячейка».

signal room_tapped(room_id: int)
signal slot_tapped(level: int, col: int)

const TAP_SLOP := 16.0
## Где стоит житель, ожидающий в шахте лифта.
const SHAFT_STAND_X := ShelterLayout.SHAFT_X + 3.0
const ROUTINE_INTERVAL := 0.25
const BUBBLE_INTERVAL := 2.2

var _world: Node2D
var _canvas: ShelterCanvas
var _actor_layer: Node2D
var _label_layer: Control
var _actors: Dictionary = {}
var _scale: int = 3
var _press_pos: Vector2 = Vector2.INF
var _routine_timer: float = 0.0
var _bubble_timer: float = 0.0


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
	GameState.time_changed.connect(_update_routines)
	_layout()
	_refresh()


func _process(delta: float) -> void:
	_routine_timer += delta
	_bubble_timer += delta
	if _routine_timer >= ROUTINE_INTERVAL:
		_routine_timer = 0.0
		_update_routines()
	if _bubble_timer >= BUBBLE_INTERVAL:
		_bubble_timer = 0.0
		_update_bubbles()


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
	_refresh_labels()


func _refresh_actors() -> void:
	var alive := {}
	for s in GameState.survivors:
		alive[s.id] = true
		if not _actors.has(s.id):
			var actor := SurvivorActor.new()
			actor.setup(s)
			_actor_layer.add_child(actor)
			_actors[s.id] = actor
	for id: int in _actors.keys():
		if not alive.has(id):
			(_actors[id] as SurvivorActor).queue_free()
			_actors.erase(id)
	_update_routines()


## Распорядок дня: каждый житель идёт туда, где по времени должен быть.
func _update_routines() -> void:
	var minute := GameState.minute
	for s in GameState.survivors:
		var actor: SurvivorActor = _actors.get(s.id)
		if actor == null:
			continue
		actor.visible = not s.on_expedition
		if s.on_expedition:
			continue
		var act := TimeSystem.activity(s, minute)
		var room := TimeSystem.place_for(s, act)
		if room != null:
			var o := ShelterLayout.room_origin(room.level, room.col)
			actor.go_to("room%d" % room.id, o.x + 4.0, o.x + ShelterLayout.ROOM_W - 4.0 - SurvivorSprites.FRAME_W,
				o.y + RoomPainter.FLOOR_Y, SHAFT_STAND_X)
		else:
			actor.go_to("shaft", SHAFT_STAND_X, SHAFT_STAND_X,
				float(ShelterLayout.SURFACE_Y + RoomPainter.FLOOR_Y), SHAFT_STAND_X)
		actor.set_resting(act == "sleep" or act == "heal")
		if act == "sleep":
			if not actor.has_lasting_bubble():
				actor.show_bubble("zzz", 0.0)
		elif actor.has_lasting_bubble():
			actor.hide_bubble()
	# Ночью свет в убежище приглушён — и жители тоже в полутьме.
	_actor_layer.modulate = Color(0.62, 0.62, 0.78) if GameState.is_night() else Color.WHITE


## Пузыри: кто ест, а кто болтает — сердечко с друзьями, молния с недругами.
func _update_bubbles() -> void:
	if GameState.is_night():
		return
	var minute := GameState.minute
	var groups := {}
	for s in GameState.survivors_in_shelter():
		var actor: SurvivorActor = _actors.get(s.id)
		if actor == null or actor.is_traveling():
			continue
		var act := TimeSystem.activity(s, minute)
		if act == "eat" and randf() < 0.35:
			actor.show_bubble("eat", 1.6)
		elif act == "social":
			var room := TimeSystem.place_for(s, act)
			if room != null:
				if not groups.has(room.id):
					groups[room.id] = []
				(groups[room.id] as Array).append(s)
	for room_id: int in groups:
		var group: Array = groups[room_id]
		if group.size() < 2:
			continue
		for s: SurvivorData in group:
			if randf() > 0.5:
				continue
			var partner: SurvivorData = null
			var strongest := -1.0
			for other: SurvivorData in group:
				if other != s and absf(RelationshipSystem.mutual(s, other)) > strongest:
					strongest = absf(RelationshipSystem.mutual(s, other))
					partner = other
			var m := RelationshipSystem.mutual(s, partner)
			var icon := "chat"
			if m >= 40.0 or FamilySystem.is_family(s, partner):
				icon = "heart"
			elif m <= -30.0:
				icon = "angry"
			(_actors[s.id] as SurvivorActor).show_bubble(icon, 1.8)


func _refresh_labels() -> void:
	for child in _label_layer.get_children():
		child.queue_free()
	for room in GameState.rooms:
		var def := room.get_def()
		var text := room.display_name()
		var slots := int(def["slots"])
		if slots > 0:
			text += "  %d/%d" % [GameState.workers_of(room.id).size(), slots]
		if room.broken:
			text += "  · сломано"
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", clampi(_scale * 4 + 1, 9, 22))
		label.add_theme_color_override("font_color", UITheme.BAD if room.broken else UITheme.TEXT_DIM)
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
