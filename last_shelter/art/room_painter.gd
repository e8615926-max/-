class_name RoomPainter
extends RefCounted
## Рисует комнаты убежища прямоугольниками на пиксельной сетке 64×40.
## Вызывается из _draw() любого CanvasItem (вид убежища, превью в меню стройки).

const W := 64
const H := 40
## Высота линии пола от верха комнаты — здесь стоят жители.
const FLOOR_Y := 34

const FRAME := Color("17161a")
const FRAME_LIGHT := Color("3a3a42")

const WALLS := {
	"quarters": Color("3a4654"),
	"farm": Color("26382a"),
	"water": Color("1f3a42"),
	"generator": Color("43322a"),
	"workshop": Color("3f3a2e"),
	"medbay": Color("56686a"),
	"storage": Color("3a332c"),
}


static func _r(ci: CanvasItem, o: Vector2, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(o.x + x, o.y + y, w, h), c)


## o — левый верхний угол комнаты, t — время для анимации, powered — есть ли энергия.
static func paint(ci: CanvasItem, type: String, o: Vector2, t: float = 0.0, powered: bool = true) -> void:
	var wall: Color = WALLS.get(type, Color("333333"))
	if not powered:
		wall = wall.darkened(0.45)
	var wall_dark := wall.darkened(0.18)

	_r(ci, o, 0, 0, W, H, FRAME)
	_r(ci, o, 1, 1, W - 2, 1, FRAME_LIGHT)
	_r(ci, o, 2, 2, W - 4, H - 4, wall)
	for x in range(13, W - 4, 12):
		_r(ci, o, x, 2, 1, FLOOR_Y - 2, wall_dark)
	_r(ci, o, 2, 2, W - 4, 2, wall_dark)
	# Пол
	_r(ci, o, 2, FLOOR_Y, W - 4, 4, Color("2a2a30"))
	_r(ci, o, 2, FLOOR_Y, W - 4, 1, Color("4a4a54"))
	# Лампа
	var lamp := Color("ffe9a8") if powered else Color("4a4438")
	_r(ci, o, 28, 2, 8, 2, Color("55524c"))
	_r(ci, o, 29, 4, 6, 1, lamp)
	if powered:
		_r(ci, o, 27, 5, 10, 1, Color(1.0, 0.92, 0.66, 0.18))
		_r(ci, o, 25, 6, 14, 1, Color(1.0, 0.92, 0.66, 0.08))

	match type:
		"quarters": _quarters(ci, o)
		"farm": _farm(ci, o, t, powered)
		"water": _water(ci, o, t, powered)
		"generator": _generator(ci, o, t)
		"workshop": _workshop(ci, o, t, powered)
		"medbay": _medbay(ci, o)
		"storage": _storage(ci, o)


static func _bunk(ci: CanvasItem, o: Vector2, x: float, top: Color, bottom: Color) -> void:
	var post := Color("6b6a70")
	_r(ci, o, x, 12, 1, 22, post)
	_r(ci, o, x + 17, 12, 1, 22, post)
	for i in 2:
		var y := 17.0 + i * 11.0
		_r(ci, o, x + 1, y + 3, 16, 1, post)
		_r(ci, o, x + 1, y, 16, 3, top if i == 0 else bottom)
		_r(ci, o, x + 1, y, 16, 1, (top if i == 0 else bottom).lightened(0.2))
		_r(ci, o, x + 1, y - 1, 5, 2, Color("e6dcc8"))


static func _quarters(ci: CanvasItem, o: Vector2) -> void:
	_bunk(ci, o, 5, Color("8a4a3a"), Color("4a6a8a"))
	_bunk(ci, o, 41, Color("5a7a4a"), Color("8a6a3a"))
	# Плакат
	_r(ci, o, 27, 10, 10, 12, Color("d9c8a0"))
	_r(ci, o, 28, 11, 8, 5, Color("c8503c"))
	_r(ci, o, 30, 12, 4, 3, Color("e8b04a"))
	_r(ci, o, 28, 18, 8, 1, Color("55524c"))
	_r(ci, o, 28, 20, 5, 1, Color("55524c"))
	# Тумбочка
	_r(ci, o, 28, 27, 8, 7, Color("5a4a3a"))
	_r(ci, o, 28, 27, 8, 1, Color("7a6a54"))
	_r(ci, o, 31, 30, 2, 1, Color("d9c8a0"))


static func _farm(ci: CanvasItem, o: Vector2, t: float, powered: bool) -> void:
	var glow := Color("e070d8") if powered else Color("4a2a48")
	_r(ci, o, 6, 7, 20, 2, Color("55524c"))
	_r(ci, o, 38, 7, 20, 2, Color("55524c"))
	_r(ci, o, 7, 9, 18, 1, glow)
	_r(ci, o, 39, 9, 18, 1, glow)
	if powered:
		_r(ci, o, 6, 10, 20, 12, Color(0.88, 0.44, 0.85, 0.07))
		_r(ci, o, 38, 10, 20, 12, Color(0.88, 0.44, 0.85, 0.07))
	for tray in 2:
		var x := 5.0 + tray * 32.0
		_r(ci, o, x, 28, 22, 6, Color("6a6a72"))
		_r(ci, o, x, 28, 22, 1, Color("8a8a92"))
		_r(ci, o, x + 1, 27, 20, 1, Color("3a2a1a"))
		for i in 5:
			var px := x + 2.0 + i * 4.0
			var grow := 4.0 + ((i * 7 + tray * 3) % 4)
			var sway := 1.0 if int(t * 1.5 + i + tray) % 4 == 0 else 0.0
			_r(ci, o, px + 1, 27 - grow, 1, grow, Color("3f7234"))
			_r(ci, o, px + sway, 26 - grow, 3, 2, Color("6fae4e"))
			_r(ci, o, px + 1 + sway, 25 - grow, 1, 1, Color("9fd46e"))
			if (i + tray) % 3 == 0:
				_r(ci, o, px + 2, 28 - grow, 1, 1, Color("d9534a"))


static func _water(ci: CanvasItem, o: Vector2, t: float, powered: bool) -> void:
	for tank in 2:
		var x := 7.0 + tank * 33.0
		_r(ci, o, x, 10, 17, 24, Color("7a9aa0"))
		_r(ci, o, x, 10, 17, 1, Color("a8c8cc"))
		_r(ci, o, x, 10, 1, 24, Color("a8c8cc"))
		_r(ci, o, x + 16, 10, 1, 24, Color("4a6a70"))
		_r(ci, o, x + 3, 13, 11, 17, Color("12242a"))
		var level := 11.0 + (roundf(sin(t * 1.2 + tank * 2.0)) if powered else -4.0)
		_r(ci, o, x + 3, 30 - level, 11, level, Color("3a8ac0"))
		_r(ci, o, x + 3, 30 - level, 11, 1, Color("8ad0f0"))
		if powered:
			var bubble := fmod(t * 6.0 + tank * 5.0, level - 2.0)
			_r(ci, o, x + 5 + tank * 4, 29 - bubble, 1, 1, Color("c8f0ff"))
		_r(ci, o, x + 2, 31, 13, 1, Color("4a6a70"))
	# Трубы
	_r(ci, o, 24, 15, 16, 2, Color("8a8a92"))
	_r(ci, o, 24, 15, 16, 1, Color("b0b0b8"))
	_r(ci, o, 31, 4, 2, 11, Color("8a8a92"))
	_r(ci, o, 30, 20, 4, 4, Color("c8503c"))
	_r(ci, o, 31, 21, 2, 2, Color("e87a5a"))


static func _generator(ci: CanvasItem, o: Vector2, t: float) -> void:
	var on := int(t * 2.5) % 2 == 0
	# Кабели
	_r(ci, o, 2, 9, 16, 1, Color("1a1614"))
	_r(ci, o, 46, 9, 16, 1, Color("1a1614"))
	_r(ci, o, 17, 9, 1, 8, Color("1a1614"))
	_r(ci, o, 46, 9, 1, 8, Color("1a1614"))
	# Корпус
	_r(ci, o, 14, 17, 36, 17, Color("6a6a72"))
	_r(ci, o, 14, 17, 36, 1, Color("9a9aa2"))
	_r(ci, o, 14, 17, 1, 17, Color("9a9aa2"))
	_r(ci, o, 49, 17, 1, 17, Color("3a3a42"))
	_r(ci, o, 20, 12, 24, 5, Color("55555c"))
	_r(ci, o, 20, 12, 24, 1, Color("7a7a82"))
	# Катушка
	var coil := Color("ffb040") if on else Color("d97b3a")
	_r(ci, o, 28, 6, 8, 6, Color("3a3a42"))
	_r(ci, o, 29, 7, 6, 4, coil)
	_r(ci, o, 30, 8, 4, 2, coil.lightened(0.4))
	# Решётка
	for i in 4:
		_r(ci, o, 18, 21 + i * 2, 12, 1, Color("2a2a30"))
	# Индикаторы
	_r(ci, o, 36, 21, 3, 3, Color("7fe05a") if on else Color("2f5a24"))
	_r(ci, o, 41, 21, 3, 3, Color("e8b04a"))
	_r(ci, o, 36, 26, 8, 2, Color("1a1614"))
	_r(ci, o, 36, 26, 3 + int(t * 3.0) % 5, 2, Color("5fc2b0"))
	# Предупреждающая полоса
	for i in 9:
		_r(ci, o, 14 + i * 4, 31, 4, 3, Color("e8b04a") if i % 2 == 0 else Color("1a1614"))


static func _workshop(ci: CanvasItem, o: Vector2, t: float, powered: bool) -> void:
	# Щит с инструментами
	_r(ci, o, 6, 8, 20, 12, Color("5a4a3a"))
	_r(ci, o, 6, 8, 20, 1, Color("7a6a54"))
	_r(ci, o, 8, 10, 1, 7, Color("b0b0b8"))
	_r(ci, o, 7, 10, 3, 2, Color("b0b0b8"))
	_r(ci, o, 12, 10, 2, 8, Color("c8503c"))
	_r(ci, o, 16, 11, 5, 1, Color("b0b0b8"))
	_r(ci, o, 18, 11, 1, 7, Color("7a5a3c"))
	_r(ci, o, 22, 10, 2, 6, Color("e8b04a"))
	# Верстак
	_r(ci, o, 5, 25, 28, 2, Color("8a6a4a"))
	_r(ci, o, 5, 25, 28, 1, Color("a8875e"))
	_r(ci, o, 6, 27, 2, 7, Color("5a4a3a"))
	_r(ci, o, 30, 27, 2, 7, Color("5a4a3a"))
	_r(ci, o, 9, 28, 20, 1, Color("5a4a3a"))
	_r(ci, o, 9, 21, 6, 4, Color("6a6a72"))
	_r(ci, o, 11, 19, 2, 2, Color("9a9aa2"))
	_r(ci, o, 19, 23, 8, 2, Color("9a9aa2"))
	if powered and int(t * 5.0) % 3 == 0:
		_r(ci, o, 22, 21, 1, 1, Color("fff0a0"))
		_r(ci, o, 24, 20, 1, 1, Color("ffb040"))
		_r(ci, o, 20, 20, 1, 1, Color("ffb040"))
	# Станок
	_r(ci, o, 40, 20, 18, 14, Color("4a5a6a"))
	_r(ci, o, 40, 20, 18, 1, Color("6a7a8a"))
	_r(ci, o, 43, 14, 4, 6, Color("6a6a72"))
	_r(ci, o, 43, 13, 10, 2, Color("6a6a72"))
	_r(ci, o, 51, 15, 2, 4, Color("b0b0b8"))
	_r(ci, o, 43, 24, 6, 4, Color("1a1614"))
	_r(ci, o, 44, 25, 4, 2, Color("7fe05a") if powered else Color("2f5a24"))
	_r(ci, o, 52, 24, 3, 3, Color("c8503c"))
	# Лом
	_r(ci, o, 34, 31, 5, 3, Color("7a7a82"))
	_r(ci, o, 35, 29, 3, 2, Color("9a6a4a"))


static func _medbay(ci: CanvasItem, o: Vector2) -> void:
	# Знак
	_r(ci, o, 8, 8, 10, 10, Color("efe6d0"))
	_r(ci, o, 12, 9, 2, 8, Color("c8503c"))
	_r(ci, o, 9, 12, 8, 2, Color("c8503c"))
	# Койка
	_r(ci, o, 6, 26, 26, 3, Color("efe6d0"))
	_r(ci, o, 6, 26, 26, 1, Color("ffffff"))
	_r(ci, o, 6, 24, 6, 2, Color("a8d0e0"))
	_r(ci, o, 16, 25, 16, 2, Color("5fc2b0"))
	_r(ci, o, 6, 29, 26, 1, Color("8a8a92"))
	_r(ci, o, 7, 30, 1, 4, Color("8a8a92"))
	_r(ci, o, 30, 30, 1, 4, Color("8a8a92"))
	# Капельница
	_r(ci, o, 36, 12, 1, 22, Color("b0b0b8"))
	_r(ci, o, 34, 33, 5, 1, Color("b0b0b8"))
	_r(ci, o, 34, 12, 5, 1, Color("b0b0b8"))
	_r(ci, o, 37, 13, 3, 5, Color("a8e0f0"))
	_r(ci, o, 38, 18, 1, 5, Color("a8e0f0"))
	# Шкаф
	_r(ci, o, 44, 12, 14, 22, Color("d0d8d8"))
	_r(ci, o, 44, 12, 14, 1, Color("ffffff"))
	_r(ci, o, 51, 13, 1, 20, Color("8a9a9a"))
	_r(ci, o, 46, 15, 4, 6, Color("a8d0e0"))
	_r(ci, o, 53, 15, 4, 6, Color("a8d0e0"))
	_r(ci, o, 47, 18, 2, 3, Color("c8503c"))
	_r(ci, o, 54, 17, 2, 4, Color("6fae4e"))
	_r(ci, o, 49, 25, 1, 3, Color("55524c"))
	_r(ci, o, 53, 25, 1, 3, Color("55524c"))


static func _crate(ci: CanvasItem, o: Vector2, x: float, y: float, w: float, h: float) -> void:
	_r(ci, o, x, y, w, h, Color("8a6a4a"))
	_r(ci, o, x, y, w, 1, Color("a8875e"))
	_r(ci, o, x, y + h - 1, w, 1, Color("5a4a3a"))
	_r(ci, o, x, y, 1, h, Color("5a4a3a"))
	_r(ci, o, x + w - 1, y, 1, h, Color("5a4a3a"))
	_r(ci, o, x + 2, y + floorf(h / 2.0), w - 4, 1, Color("5a4a3a"))


static func _storage(ci: CanvasItem, o: Vector2) -> void:
	# Стеллаж
	_r(ci, o, 5, 8, 1, 26, Color("6a6a72"))
	_r(ci, o, 28, 8, 1, 26, Color("6a6a72"))
	_r(ci, o, 5, 16, 24, 1, Color("6a6a72"))
	_r(ci, o, 5, 25, 24, 1, Color("6a6a72"))
	_crate(ci, o, 7, 9, 8, 7)
	_r(ci, o, 17, 11, 4, 5, Color("c8503c"))
	_r(ci, o, 22, 12, 4, 4, Color("4fa3d8"))
	_crate(ci, o, 8, 19, 6, 6)
	_crate(ci, o, 16, 18, 10, 7)
	_r(ci, o, 8, 28, 5, 6, Color("6fae4e"))
	_r(ci, o, 8, 28, 5, 1, Color("9fd46e"))
	_crate(ci, o, 15, 27, 9, 7)
	# Бочки
	for i in 2:
		var x := 33.0 + i * 8.0
		_r(ci, o, x, 24, 6, 10, Color("4a6a8a"))
		_r(ci, o, x, 24, 6, 1, Color("6a8aaa"))
		_r(ci, o, x, 27, 6, 1, Color("2d4a66"))
		_r(ci, o, x, 31, 6, 1, Color("2d4a66"))
	# Штабель
	_crate(ci, o, 49, 25, 10, 9)
	_crate(ci, o, 50, 17, 8, 8)
	_r(ci, o, 52, 20, 4, 2, Color("e8b04a"))
