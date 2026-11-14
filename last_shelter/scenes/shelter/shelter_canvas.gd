class_name ShelterCanvas
extends Node2D
## Слой с фоном и комнатами. Перерисовывается несколько раз в секунду ради
## простой анимации (лампы, вода, растения) — этого достаточно и дёшево для телефона.

const REDRAW_INTERVAL := 0.2

## Тип комнаты, выбранный для стройки ("" — обычный режим).
var build_type: String = ""
## Комнаты без энергии по прогнозу на текущий день.
var unpowered: Array[int] = []

var _time: float = 0.0
var _accum: float = 0.0
var _specks: Array[Rect2] = []
var _speck_colors: Array[Color] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var palette := [Color("3a2c22"), Color("1f1611"), Color("453528"), Color("5a5048")]
	for i in 260:
		var x := floorf(rng.randf_range(-260.0, ShelterLayout.WORLD_W + 260.0))
		var y := floorf(rng.randf_range(ShelterLayout.SURFACE_Y + 4.0, ShelterLayout.WORLD_H + 120.0))
		var w := 2.0 if rng.randf() < 0.4 else 1.0
		_specks.append(Rect2(x, y, w, 1))
		_speck_colors.append(palette[rng.randi() % palette.size()])


func _process(delta: float) -> void:
	_time += delta
	_accum += delta
	if _accum >= REDRAW_INTERVAL:
		_accum = 0.0
		queue_redraw()


func _draw() -> void:
	var x0 := -900.0
	var x1 := ShelterLayout.WORLD_W + 900.0
	var ground := float(ShelterLayout.SURFACE_Y) - 4.0
	SurfacePainter.paint_sky(self, x0, x1, ground, 40.0, _time, GameState.minute,
		-10.0, ShelterLayout.WORLD_W + 10.0)
	SurfacePainter.paint_ground(self, x0, x1, ground, 700.0)
	for i in _specks.size():
		draw_rect(_specks[i], _speck_colors[i])
	SurfacePainter.paint_entrance(self, ShelterLayout.SHAFT_X - 2.0, ground, _time)
	_draw_shaft()

	var night := GameState.is_night()
	for level in ShelterLayout.LEVELS:
		for col in ShelterLayout.COLS:
			var o := ShelterLayout.room_origin(level, col)
			var room := GameState.room_at(level, col)
			if room != null:
				var powered := not unpowered.has(room.id) and not room.broken
				RoomPainter.paint(self, room.type, o, _time, powered)
				_draw_condition(room, o)
				_draw_slab(o)
				if room.broken:
					_draw_broken(o)
				elif unpowered.has(room.id):
					_draw_no_power(o)
				if night:
					var alpha := 0.32 if room.type == "quarters" else 0.45
					draw_rect(Rect2(o.x + 2, o.y + 2, ShelterLayout.ROOM_W - 4, ShelterLayout.ROOM_H - 4),
						Color(0.02, 0.03, 0.08, alpha))
			elif build_type != "" and GameState.can_build_at(level, col):
				_draw_build_slot(o)


func _draw_shaft() -> void:
	var x := float(ShelterLayout.SHAFT_X)
	var top := float(ShelterLayout.SURFACE_Y) - 4.0
	var bottom := float(ShelterLayout.SURFACE_Y + ShelterLayout.LEVELS * ShelterLayout.CELL_H)
	draw_rect(Rect2(x, top, ShelterLayout.SHAFT_W, bottom - top), Color("17161a"))
	draw_rect(Rect2(x + 2, top, ShelterLayout.SHAFT_W - 4, bottom - top - 2), Color("101014"))
	# Направляющие и тросы
	draw_rect(Rect2(x + 4, top, 1, bottom - top - 2), Color("3a3a42"))
	draw_rect(Rect2(x + 15, top, 1, bottom - top - 2), Color("3a3a42"))
	draw_rect(Rect2(x + 9, top, 1, bottom - top - 2), Color("2a2a30"))
	for level in ShelterLayout.LEVELS:
		var fy := float(ShelterLayout.SURFACE_Y + level * ShelterLayout.CELL_H + RoomPainter.FLOOR_Y)
		draw_rect(Rect2(x + 2, fy, ShelterLayout.SHAFT_W - 4, 1), Color("3a3a42"))
		draw_rect(Rect2(x + 17, fy - 12, 1, 2), Color("e8b04a") if int(_time * 2.0 + level) % 3 != 0 else Color("6a5020"))
	# Кабина лифта стоит на верхнем этаже
	var cy := float(ShelterLayout.SURFACE_Y + RoomPainter.FLOOR_Y - 20)
	draw_rect(Rect2(x + 4, cy, 12, 20), Color("55555c"))
	draw_rect(Rect2(x + 5, cy + 1, 10, 18), Color("2f3a44"))
	draw_rect(Rect2(x + 5, cy + 1, 10, 1), Color("ffe9a8"))
	draw_rect(Rect2(x + 9, cy + 2, 1, 17), Color("55555c"))


## Бетонное перекрытие под комнатой — на нём вид убежища показывает название.
func _draw_slab(o: Vector2) -> void:
	var y := o.y + ShelterLayout.ROOM_H
	draw_rect(Rect2(o.x, y, ShelterLayout.ROOM_W, ShelterLayout.SLAB_H), Color("1d1b20"))
	draw_rect(Rect2(o.x, y, ShelterLayout.ROOM_W, 1), Color("0f0e11"))
	draw_rect(Rect2(o.x, y + ShelterLayout.SLAB_H - 1, ShelterLayout.ROOM_W, 1), Color("0f0e11"))
	draw_rect(Rect2(o.x, y, 1, ShelterLayout.SLAB_H), Color("0f0e11"))
	draw_rect(Rect2(o.x + ShelterLayout.ROOM_W - 1, y, 1, ShelterLayout.SLAB_H), Color("0f0e11"))


## Полоска состояния оборудования на полу — когда пора подумать о ремонте.
func _draw_condition(room: RoomData, o: Vector2) -> void:
	if not room.can_break() or (room.condition >= 70.0 and not room.broken):
		return
	var w := ShelterLayout.ROOM_W - 8.0
	var color := Color("e0655a") if room.condition < MaintenanceSystem.BREAK_THRESHOLD else Color("e8b04a")
	draw_rect(Rect2(o.x + 4, o.y + RoomPainter.FLOOR_Y + 2, w, 1), Color("17161a"))
	draw_rect(Rect2(o.x + 4, o.y + RoomPainter.FLOOR_Y + 2, roundf(w * room.condition / 100.0), 1), color)


## Сломанная комната: темно, дым, искры и предупреждающая табличка.
func _draw_broken(o: Vector2) -> void:
	draw_rect(Rect2(o.x + 2, o.y + 2, ShelterLayout.ROOM_W - 4, ShelterLayout.ROOM_H - 4), Color(0, 0, 0, 0.4))
	for k in 3:
		var rise := fmod(_time * 5.0 + k * 6.0, 18.0)
		draw_rect(Rect2(o.x + 26 + k * 5 + (int(rise) % 3), o.y + 30 - rise, 3, 2),
			Color(0.55, 0.55, 0.6, maxf(0.5 - rise * 0.025, 0.05)))
	if int(_time * 6.0) % 3 == 0:
		draw_rect(Rect2(o.x + 20, o.y + 22, 1, 1), Color("fff0a0"))
		draw_rect(Rect2(o.x + 23, o.y + 20, 1, 1), Color("ffb040"))
		draw_rect(Rect2(o.x + 41, o.y + 24, 1, 1), Color("ffb040"))
	var bx := o.x + ShelterLayout.ROOM_W - 12.0
	var by := o.y + 5.0
	draw_rect(Rect2(bx, by, 7, 9), Color("e8b04a"))
	draw_rect(Rect2(bx + 3, by + 1, 1, 5), Color("1a1614"))
	draw_rect(Rect2(bx + 3, by + 7, 1, 1), Color("1a1614"))


func _draw_no_power(o: Vector2) -> void:
	draw_rect(Rect2(o.x + 2, o.y + 2, ShelterLayout.ROOM_W - 4, ShelterLayout.ROOM_H - 4), Color(0, 0, 0, 0.35))
	if int(_time * 2.0) % 2 == 0:
		# Мигающая молния
		var bx := o.x + ShelterLayout.ROOM_W - 12.0
		var by := o.y + 5.0
		draw_rect(Rect2(bx + 3, by, 3, 2), Color("d9534a"))
		draw_rect(Rect2(bx + 2, by + 2, 3, 2), Color("d9534a"))
		draw_rect(Rect2(bx + 1, by + 4, 5, 1), Color("d9534a"))
		draw_rect(Rect2(bx + 3, by + 5, 2, 2), Color("d9534a"))
		draw_rect(Rect2(bx + 2, by + 7, 2, 1), Color("d9534a"))


func _draw_build_slot(o: Vector2) -> void:
	var pulse := 0.55 + 0.35 * sin(_time * 4.0)
	var c := Color(0.91, 0.69, 0.29, pulse)
	var w := float(ShelterLayout.ROOM_W)
	var h := float(ShelterLayout.ROOM_H)
	draw_rect(Rect2(o.x + 2, o.y + 2, w - 4, h - 4), Color(0.91, 0.69, 0.29, 0.10))
	# Пунктирная рамка
	var x := 2.0
	while x < w - 4.0:
		draw_rect(Rect2(o.x + x, o.y + 2, 4, 1), c)
		draw_rect(Rect2(o.x + x, o.y + h - 3, 4, 1), c)
		x += 7.0
	var y := 2.0
	while y < h - 4.0:
		draw_rect(Rect2(o.x + 2, o.y + y, 1, 4), c)
		draw_rect(Rect2(o.x + w - 3, o.y + y, 1, 4), c)
		y += 7.0
	# Плюс
	draw_rect(Rect2(o.x + w / 2 - 1, o.y + h / 2 - 6, 2, 12), c)
	draw_rect(Rect2(o.x + w / 2 - 6, o.y + h / 2 - 1, 12, 2), c)
