class_name SurvivorActor
extends Sprite2D
## Житель в виде убежища: ходит туда-сюда по своей комнате.

const SPEED := 9.0

var survivor_id: int = 0

var _frames: Array[Texture2D] = []
var _zone_key: String = ""
var _min_x: float = 0.0
var _max_x: float = 0.0
var _floor_y: float = 0.0
var _fx: float = 0.0
var _target: float = 0.0
var _wait: float = 0.0
var _anim: float = 0.0


func _init() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(s: SurvivorData) -> void:
	survivor_id = s.id
	_frames = SurvivorSprites.get_frames(s.appearance)
	texture = _frames[0]


## Задаёт участок, по которому ходит житель. При смене участка житель переносится туда.
func set_zone(key: String, min_x: float, max_x: float, floor_y: float) -> void:
	if key == _zone_key:
		return
	_zone_key = key
	_min_x = min_x
	_max_x = maxf(min_x, max_x)
	_floor_y = floor_y
	_fx = randf_range(_min_x, _max_x)
	_target = randf_range(_min_x, _max_x)
	_wait = randf_range(0.0, 2.0)
	_update_position()


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	if _wait > 0.0:
		_wait -= delta
		texture = _frames[0]
		return
	var dir := signf(_target - _fx)
	_fx += dir * SPEED * delta
	if absf(_target - _fx) < 0.6:
		_wait = randf_range(1.0, 4.5)
		_target = randf_range(_min_x, _max_x)
	_anim += delta * 5.0
	texture = _frames[int(_anim) % 2]
	flip_h = dir < 0.0
	_update_position()


func _update_position() -> void:
	position = Vector2(roundf(_fx), _floor_y - SurvivorSprites.FRAME_H + 1)
