class_name ShelterLayout
extends RefCounted
## Геометрия убежища в «арт-пикселях» (до увеличения на экране).

const COLS := 8
const LEVELS := 4
const ROOM_W := 64
const ROOM_H := 40
## Высота ячейки: комната плюс перекрытие, на котором пишется название.
const SLAB_H := 6
const CELL_H := ROOM_H + SLAB_H
const SHAFT_W := 20
const MARGIN := 8
## Высота поверхности над первым этажом.
const SURFACE_Y := 30

const WORLD_W := MARGIN * 2 + SHAFT_W + COLS * ROOM_W
const WORLD_H := SURFACE_Y + LEVELS * CELL_H + 6

const SHAFT_X := MARGIN
const ROOMS_X := MARGIN + SHAFT_W


static func room_origin(level: int, col: int) -> Vector2:
	return Vector2(ROOMS_X + col * ROOM_W, SURFACE_Y + level * CELL_H)


## Ячейка под точкой мира: Vector2i(col, level) или (-1, -1), если мимо.
static func slot_at(p: Vector2) -> Vector2i:
	var col := floori((p.x - ROOMS_X) / ROOM_W)
	var level := floori((p.y - SURFACE_Y) / CELL_H)
	if col < 0 or col >= COLS or level < 0 or level >= LEVELS:
		return Vector2i(-1, -1)
	return Vector2i(col, level)
