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
	"kitchen": Color("3e4842"),
	"cement": Color("4a4642"),
	"pharmacy": Color("3e5450"),
	"lab": Color("38424e"),
	"radio": Color("3c3a48"),
}


static func _r(ci: CanvasItem, o: Vector2, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(o.x + x, o.y + y, w, h), c)


## o — левый верхний угол комнаты, t — время для анимации, powered — есть ли энергия.
## tier — уровень улучшения (видно по отделке), decor — украшения по слотам, paint_id — окраска стен.
static func paint(ci: CanvasItem, type: String, o: Vector2, t: float = 0.0, powered: bool = true,
		tier: int = 1, decor: Array = [], paint_id: String = "") -> void:
	var wall: Color = WALLS.get(type, Color("333333"))
	var tint: Color = DecorDefs.PAINTS.get(paint_id, DecorDefs.PAINTS[""])["color"]
	if tint.a > 0.0:
		wall = wall.lerp(tint, 0.45)
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
		"kitchen": _kitchen(ci, o, t, powered)
		"cement": _cement(ci, o, t, powered)
		"pharmacy": _pharmacy(ci, o, t, powered)
		"lab": _lab(ci, o, t, powered)
		"radio": _radio(ci, o, t, powered)
	_tier_trim(ci, o, t, tier, powered)
	for i in decor.size():
		_decor(ci, o, String(decor[i]), i, t, powered)


## Отделка улучшенной комнаты: II — клёпаный пол и кабельный короб, III — латунь и светящаяся панель.
static func _tier_trim(ci: CanvasItem, o: Vector2, t: float, tier: int, powered: bool) -> void:
	if tier < 2:
		return
	_r(ci, o, 2, FLOOR_Y, W - 4, 4, Color("3a3a42"))
	_r(ci, o, 2, FLOOR_Y, W - 4, 1, Color("6a6a74"))
	for x in range(5, W - 4, 8):
		_r(ci, o, x, FLOOR_Y + 2, 1, 1, Color("8a8a94"))
	_r(ci, o, 2, 4, W - 4, 1, Color("2a2a30"))
	for x in range(8, W - 4, 16):
		_r(ci, o, x, 4, 2, 2, Color("55555c"))
	if tier < 3:
		return
	var brass := Color("c8a050")
	_r(ci, o, 2, 2, 3, 1, brass)
	_r(ci, o, 2, 2, 1, 3, brass)
	_r(ci, o, W - 5, 2, 3, 1, brass)
	_r(ci, o, W - 3, 2, 1, 3, brass)
	_r(ci, o, 2, FLOOR_Y - 1, W - 4, 1, brass.darkened(0.3))
	# Панель состояния
	_r(ci, o, W - 9, 16, 5, 6, Color("1a1614"))
	if powered:
		_r(ci, o, W - 8, 17, 3, 1, Color("5fc2b0"))
		_r(ci, o, W - 8, 19, 1 + int(t * 2.0) % 3, 1, Color("7fe05a"))


## Украшение в слоте: 0 — у левой стены, 1 — у правой.
static func _decor(ci: CanvasItem, o: Vector2, id: String, slot: int, t: float, powered: bool) -> void:
	if not DecorDefs.exists(id):
		return
	var x := 4.0 if slot == 0 else W - 14.0
	match id:
		"poster":
			_r(ci, o, x + 1, 7, 8, 10, Color("d9c8a0"))
			_r(ci, o, x + 2, 8, 6, 4, Color("4f8fb8"))
			_r(ci, o, x + 3, 9, 4, 2, Color("e8b04a"))
			_r(ci, o, x + 2, 14, 6, 1, Color("55524c"))
		"painting":
			_r(ci, o, x, 7, 10, 8, Color("8a6a2a"))
			_r(ci, o, x + 1, 8, 8, 6, Color("4a7a9a"))
			_r(ci, o, x + 1, 11, 8, 3, Color("4f7a3a"))
			_r(ci, o, x + 6, 9, 2, 2, Color("f0c070"))
		"flag":
			_r(ci, o, x + 1, 6, 1, 14, Color("8a8a92"))
			_r(ci, o, x + 2, 6, 7, 5, Color("c8503c"))
			_r(ci, o, x + 4, 7, 3, 3, Color("e8b04a"))
		"garland":
			for k in 6:
				var on := powered and (int(t * 3.0) + k) % 2 == 0
				var colors := [Color("e8b04a"), Color("c8503c"), Color("5fc2b0")]
				_r(ci, o, x - 2 + k * 2, 6 + (k % 2), 1, 1, colors[k % 3] if on else Color("3a3a42"))
		"plant":
			_r(ci, o, x + 3, FLOOR_Y - 4, 5, 4, Color("a0522d"))
			_r(ci, o, x + 4, FLOOR_Y - 9, 1, 5, Color("3f7234"))
			_r(ci, o, x + 2, FLOOR_Y - 10, 3, 2, Color("6fae4e"))
			_r(ci, o, x + 5, FLOOR_Y - 8, 3, 2, Color("6fae4e"))
		"rug":
			_r(ci, o, x - 1, FLOOR_Y, 12, 1, Color("b0443a"))
			_r(ci, o, x + 1, FLOOR_Y, 2, 1, Color("e8b04a"))
			_r(ci, o, x + 7, FLOOR_Y, 2, 1, Color("e8b04a"))
		"lamp":
			_r(ci, o, x + 4, FLOOR_Y - 10, 1, 10, Color("6a6a72"))
			_r(ci, o, x + 2, FLOOR_Y - 13, 5, 3, Color("e8b04a") if powered else Color("6a5020"))
			if powered:
				_r(ci, o, x + 1, FLOOR_Y - 10, 7, 1, Color(1.0, 0.85, 0.5, 0.25))
		"bookshelf":
			_r(ci, o, x, FLOOR_Y - 14, 10, 14, Color("6a4a30"))
			for row in 3:
				for k in 4:
					_r(ci, o, x + 1 + k * 2, FLOOR_Y - 13 + row * 4, 1, 3, [Color("c8503c"), Color("4f8fb8"), Color("e8b04a"), Color("6fae4e")][(k + row) % 4])
		"aquarium":
			_r(ci, o, x, FLOOR_Y - 8, 10, 8, Color("5a6a72"))
			_r(ci, o, x + 1, FLOOR_Y - 7, 8, 6, Color("2a6a9a"))
			var fx := x + 2.0 + float(int(t * 2.0) % 5)
			_r(ci, o, fx, FLOOR_Y - 5, 2, 1, Color("e8803a"))
			_r(ci, o, x + 1, FLOOR_Y - 7, 8, 1, Color("8ad0f0"))


static func _cement(ci: CanvasItem, o: Vector2, t: float, powered: bool) -> void:
	# Бетономешалка
	_r(ci, o, 8, 14, 18, 14, Color("8a8a92"))
	_r(ci, o, 10, 12, 14, 2, Color("9a9aa2"))
	var turn := int(t * 4.0) % 3 if powered else 0
	for k in 3:
		_r(ci, o, 10 + k * 5 + turn, 16, 2, 10, Color("6a6a72"))
	_r(ci, o, 14, 28, 6, 6, Color("55555c"))
	# Мешки и формы с бетоном
	for k in 3:
		_r(ci, o, 34 + k * 7, 28, 6, 6, Color("c8b890"))
		_r(ci, o, 34 + k * 7, 28, 6, 1, Color("ddd0a8"))
	_r(ci, o, 36, 20, 18, 6, Color("8f8c86"))
	_r(ci, o, 36, 20, 18, 1, Color("aaa7a0"))
	_r(ci, o, 30, 8, 2, 12, Color("4fa3d8"))
	if powered and int(t * 3.0) % 2 == 0:
		_r(ci, o, 31, 20, 1, 2, Color("8ad0f0"))


static func _pharmacy(ci: CanvasItem, o: Vector2, t: float, powered: bool) -> void:
	# Шкаф со склянками
	_r(ci, o, 5, 8, 20, 26, Color("d0d8d8"))
	for row in 3:
		_r(ci, o, 6, 15 + row * 7, 18, 1, Color("8a9a9a"))
		for k in 4:
			_r(ci, o, 7 + k * 4, 11 + row * 7, 2, 4, [Color("6fd0a0"), Color("c8503c"), Color("e8b04a"), Color("4fa3d8")][(k + row) % 4])
	# Стол с колбами и горелкой
	_r(ci, o, 32, 25, 26, 2, Color("8a8a92"))
	_r(ci, o, 34, 27, 2, 7, Color("6a6a72"))
	_r(ci, o, 54, 27, 2, 7, Color("6a6a72"))
	_r(ci, o, 36, 19, 4, 6, Color("a8e0f0"))
	_r(ci, o, 37, 21, 2, 4, Color("6fd0a0"))
	_r(ci, o, 46, 21, 6, 4, Color("a8e0f0"))
	_r(ci, o, 47, 23, 4, 2, Color("e87a5a"))
	if powered:
		var rise := fmod(t * 5.0, 6.0)
		_r(ci, o, 48, 20 - rise, 1, 1, Color(1, 1, 1, 0.5))
		_r(ci, o, 47, 25, 4, 1, Color("ff9040"))


static func _lab(ci: CanvasItem, o: Vector2, t: float, powered: bool) -> void:
	# Доска с формулами
	_r(ci, o, 5, 7, 22, 13, Color("2a3a30"))
	_r(ci, o, 5, 7, 22, 1, Color("6a6a72"))
	for k in 4:
		_r(ci, o, 7, 10 + k * 2, 6 + (k * 5) % 12, 1, Color("d0d8d0"))
	# Компьютер
	_r(ci, o, 34, 14, 14, 10, Color("4a4a52"))
	_r(ci, o, 35, 15, 12, 8, Color("17262a") if powered else Color("1a1a1e"))
	if powered:
		for k in 3:
			_r(ci, o, 36, 16 + k * 2, 3 + (int(t * 4.0) + k * 3) % 9, 1, Color("5fc2b0"))
	_r(ci, o, 32, 25, 26, 2, Color("8a8a92"))
	_r(ci, o, 34, 27, 2, 7, Color("6a6a72"))
	_r(ci, o, 54, 27, 2, 7, Color("6a6a72"))
	# Микроскоп
	_r(ci, o, 51, 18, 2, 7, Color("b0b0b8"))
	_r(ci, o, 49, 23, 6, 2, Color("6a6a72"))
	_r(ci, o, 50, 17, 4, 2, Color("6a6a72"))
	# Шкаф с образцами
	_r(ci, o, 8, 22, 14, 12, Color("5a6a72"))
	_r(ci, o, 9, 24, 12, 3, Color("a8e0f0"))
	_r(ci, o, 11, 25, 2, 2, Color("7fe05a") if powered else Color("2f5a24"))


static func _radio(ci: CanvasItem, o: Vector2, t: float, powered: bool) -> void:
	# Стойка с аппаратурой
	_r(ci, o, 5, 10, 22, 24, Color("4a4a52"))
	for row in 3:
		_r(ci, o, 6, 12 + row * 7, 20, 5, Color("2a2a30"))
		_r(ci, o, 8, 13 + row * 7, 4, 3, Color("6a6a72"))
		var lit := powered and (int(t * 3.0) + row) % 3 != 0
		_r(ci, o, 22, 14 + row * 7, 2, 1, Color("e8b04a") if lit else Color("3a3a42"))
	# Шкала частот
	_r(ci, o, 14, 13, 8, 3, Color("d9c8a0"))
	var needle := 14.0 + float(int(t * 2.0) % 8) if powered else 15.0
	_r(ci, o, needle, 12, 1, 5, Color("c8503c"))
	# Стол, микрофон и наушники
	_r(ci, o, 32, 25, 26, 2, Color("8a6a4a"))
	_r(ci, o, 34, 27, 2, 7, Color("5a4a3a"))
	_r(ci, o, 54, 27, 2, 7, Color("5a4a3a"))
	_r(ci, o, 40, 19, 1, 6, Color("6a6a72"))
	_r(ci, o, 39, 17, 3, 3, Color("2a2a30"))
	_r(ci, o, 47, 21, 6, 1, Color("2a2a30"))
	_r(ci, o, 47, 22, 1, 3, Color("2a2a30"))
	_r(ci, o, 52, 22, 1, 3, Color("2a2a30"))
	# Антенна под потолком
	_r(ci, o, 44, 3, 1, 9, Color("8a8a92"))
	if powered and int(t * 2.0) % 2 == 0:
		_r(ci, o, 43, 2, 3, 1, Color("ff5a40"))


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


static func _kitchen(ci: CanvasItem, o: Vector2, t: float, powered: bool) -> void:
	# Кафель над плитой
	for i in 5:
		for j in 2:
			_r(ci, o, 5 + i * 5, 13 + j * 4, 4, 3, Color("6a7a74") if (i + j) % 2 == 0 else Color("56665f"))
	# Плита с духовкой
	_r(ci, o, 5, 22, 25, 12, Color("6a6a72"))
	_r(ci, o, 5, 22, 25, 1, Color("9a9aa2"))
	_r(ci, o, 8, 26, 19, 6, Color("2a2a30"))
	_r(ci, o, 9, 27, 17, 4, Color("e07a30") if powered else Color("3a2a20"))
	_r(ci, o, 9, 27, 17, 1, Color("ffd080") if powered else Color("3a2a20"))
	# Кастрюля и сковорода
	_r(ci, o, 7, 17, 8, 5, Color("b0b0b8"))
	_r(ci, o, 7, 17, 8, 1, Color("d0d0d8"))
	_r(ci, o, 6, 18, 1, 2, Color("8a8a92"))
	_r(ci, o, 15, 18, 1, 2, Color("8a8a92"))
	_r(ci, o, 18, 19, 9, 3, Color("4a4a52"))
	_r(ci, o, 19, 19, 7, 1, Color("d97b3a"))
	_r(ci, o, 27, 20, 3, 1, Color("4a4a52"))
	# Пар
	if powered:
		for k in 3:
			var rise := fmod(t * 6.0 + k * 3.5, 10.0)
			_r(ci, o, 9 + k * 2 + (int(rise) % 2), 15 - rise, 1, 1, Color(1, 1, 1, maxf(0.55 - rise * 0.05, 0.05)))
	# Полка с банками
	_r(ci, o, 36, 11, 22, 1, Color("8a6a4a"))
	_r(ci, o, 37, 7, 3, 4, Color("c8503c"))
	_r(ci, o, 41, 6, 3, 5, Color("e8b04a"))
	_r(ci, o, 45, 8, 3, 3, Color("6fae4e"))
	_r(ci, o, 50, 6, 4, 5, Color("d9c8a0"))
	_r(ci, o, 55, 8, 2, 3, Color("4fa3d8"))
	# Стол с мисками и табуреты
	_r(ci, o, 35, 24, 23, 2, Color("8a6a4a"))
	_r(ci, o, 35, 24, 23, 1, Color("a8875e"))
	_r(ci, o, 37, 26, 2, 8, Color("5a4a3a"))
	_r(ci, o, 54, 26, 2, 8, Color("5a4a3a"))
	_r(ci, o, 39, 22, 5, 2, Color("efe6d0"))
	_r(ci, o, 40, 22, 3, 1, Color("d97b3a"))
	_r(ci, o, 49, 22, 5, 2, Color("efe6d0"))
	_r(ci, o, 50, 22, 3, 1, Color("6fae4e"))
	_r(ci, o, 41, 29, 4, 1, Color("6a5a4a"))
	_r(ci, o, 42, 30, 2, 4, Color("5a4a3a"))
	_r(ci, o, 48, 29, 4, 1, Color("6a5a4a"))
	_r(ci, o, 49, 30, 2, 4, Color("5a4a3a"))
