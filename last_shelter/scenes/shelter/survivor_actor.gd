class_name SurvivorActor
extends Sprite2D
## Житель в виде убежища: бродит по своей комнате, переходит между комнатами
## через шахту лифта, спит ночью и показывает «пузыри» над головой.

const WANDER_SPEED := 9.0
const TRAVEL_SPEED := 24.0
const CLIMB_SPEED := 32.0

var survivor_id: int = 0

var _frames: Array[Texture2D] = []
var _bubble: Sprite2D
## Сколько ещё показывать пузырь; отрицательное — пока не уберут.
var _bubble_time: float = 0.0
var _room_key: String = ""
var _placed: bool = false
## x — левый край спрайта, y — уровень пола под ногами.
var _feet: Vector2 = Vector2.ZERO
var _path: Array[Vector2] = []
var _min_x: float = 0.0
var _max_x: float = 0.0
var _target_x: float = 0.0
var _wait: float = 0.0
var _anim: float = 0.0
var _resting: bool = false


func _init() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bubble = Sprite2D.new()
	_bubble.centered = false
	_bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bubble.position = Vector2(2, -11)
	_bubble.visible = false
	add_child(_bubble)


func setup(s: SurvivorData) -> void:
	survivor_id = s.id
	_frames = SurvivorSprites.get_frames(s.appearance)
	texture = _frames[0]


## Отправляет жителя в комнату: key — её код, [min_x, max_x] — где можно стоять.
## Если комната на другом этаже, путь идёт через шахту лифта (shaft_x).
func go_to(key: String, min_x: float, max_x: float, floor_y: float, shaft_x: float) -> void:
	if key == _room_key:
		return
	_room_key = key
	_min_x = min_x
	_max_x = maxf(min_x, max_x)
	var dest := Vector2(randf_range(_min_x, _max_x), floor_y)
	_path.clear()
	if not _placed:
		_placed = true
		_feet = dest
		_target_x = dest.x
		_wait = randf_range(0.0, 2.0)
		_update_position()
		return
	if absf(_feet.y - floor_y) > 0.5:
		_path.append(Vector2(shaft_x, _feet.y))
		_path.append(Vector2(shaft_x, floor_y))
	_path.append(dest)
	_target_x = dest.x


## Спит или лечится: стоит на месте.
func set_resting(on: bool) -> void:
	_resting = on


func is_traveling() -> bool:
	return not _path.is_empty()


## Показывает пузырь; duration <= 0 — пока не уберут.
func show_bubble(icon: String, duration: float) -> void:
	_bubble.texture = PixelIcons.get_bubble(icon)
	_bubble.visible = true
	_bubble_time = duration if duration > 0.0 else -1.0


func hide_bubble() -> void:
	_bubble.visible = false
	_bubble_time = 0.0


func has_lasting_bubble() -> bool:
	return _bubble.visible and _bubble_time < 0.0


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	if _bubble_time > 0.0:
		_bubble_time -= delta
		if _bubble_time <= 0.0:
			hide_bubble()
	if not _path.is_empty():
		_follow_path(delta)
		return
	if _resting or _wait > 0.0:
		_wait = maxf(_wait - delta, 0.0)
		texture = _frames[0]
		return
	var dir := signf(_target_x - _feet.x)
	_feet.x += dir * WANDER_SPEED * delta
	if absf(_target_x - _feet.x) < 0.6:
		_wait = randf_range(1.0, 4.5)
		_target_x = randf_range(_min_x, _max_x)
	_anim += delta * 5.0
	texture = _frames[int(_anim) % 2]
	flip_h = dir < 0.0
	_update_position()


func _follow_path(delta: float) -> void:
	var target := _path[0]
	if absf(target.y - _feet.y) > 0.1:
		# По шахте — вертикально, без шагов.
		_feet.x = target.x
		_feet.y = move_toward(_feet.y, target.y, CLIMB_SPEED * delta)
		texture = _frames[0]
	else:
		var dir := signf(target.x - _feet.x)
		_feet.x = move_toward(_feet.x, target.x, TRAVEL_SPEED * delta)
		_anim += delta * 7.0
		texture = _frames[int(_anim) % 2]
		if dir != 0.0:
			flip_h = dir < 0.0
	if _feet.distance_to(target) < 0.3:
		_feet = target
		_path.remove_at(0)
		if _path.is_empty():
			_target_x = _feet.x
			_wait = randf_range(0.5, 2.5)
	_update_position()


func _update_position() -> void:
	position = Vector2(roundf(_feet.x), roundf(_feet.y) - SurvivorSprites.FRAME_H + 1)
