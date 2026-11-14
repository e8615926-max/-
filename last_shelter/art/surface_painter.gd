class_name SurfacePainter
extends RefCounted
## Рисует поверхность над убежищем: закатное небо, руины города и вход в бункер.
## Используется видом убежища и фоном главного меню.

const SKY_BANDS := [
	[Color("171425"), 1.0],
	[Color("241a30"), 0.62],
	[Color("3d2438"), 0.40],
	[Color("6a3238"), 0.24],
	[Color("a04e38"), 0.12],
	[Color("d07a3c"), 0.05],
]
const RUINS_FAR := Color("2a1c2c")
const RUINS_NEAR := Color("170f18")
const GROUND := Color("4a3e2c")
const GROUND_DARK := Color("33281c")
const DIRT := Color("2b2019")


## Небо и руины от x0 до x1; земля находится на высоте ground_y, небо занимает sky_h пикселей.
static func paint_sky(ci: CanvasItem, x0: float, x1: float, ground_y: float, sky_h: float, t: float) -> void:
	ci.draw_rect(Rect2(x0, ground_y - sky_h - 2000.0, x1 - x0, 2000.0), SKY_BANDS[0][0])
	for band: Array in SKY_BANDS:
		var h := sky_h * float(band[1])
		ci.draw_rect(Rect2(x0, ground_y - h, x1 - x0, h), band[0])
	# Звёзды
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 40:
		var sx := rng.randf_range(x0, x1)
		var sy := ground_y - sky_h * rng.randf_range(0.45, 1.0)
		var phase := rng.randf() * 10.0
		if sin(t * 0.8 + phase) > -0.5:
			ci.draw_rect(Rect2(floorf(sx), floorf(sy), 1, 1), Color(1, 0.95, 0.85, 0.7))
	# Солнце у горизонта
	var sun_x := floorf(lerpf(x0, x1, 0.72))
	ci.draw_rect(Rect2(sun_x - 5, ground_y - 9, 10, 9), Color("f0b060"))
	ci.draw_rect(Rect2(sun_x - 7, ground_y - 6, 14, 6), Color("f0b060"))
	ci.draw_rect(Rect2(sun_x - 3, ground_y - 11, 6, 2), Color("f0b060"))
	# Дальние и ближние руины
	_ruins(ci, x0, x1, ground_y, 31, RUINS_FAR, 10.0, 26.0, 9.0)
	_ruins(ci, x0, x1, ground_y, 12, RUINS_NEAR, 4.0, 15.0, 13.0)


static func _ruins(ci: CanvasItem, x0: float, x1: float, ground_y: float, seed_value: int,
		color: Color, min_h: float, max_h: float, step: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x := floorf(x0 / step) * step
	while x < x1:
		var w := floorf(rng.randf_range(step * 0.5, step * 1.4))
		var h := floorf(rng.randf_range(min_h, max_h))
		if rng.randf() < 0.75:
			ci.draw_rect(Rect2(x, ground_y - h, w, h), color)
			# Обломанная верхушка и пустые окна
			if rng.randf() < 0.6:
				ci.draw_rect(Rect2(x, ground_y - h - 2, floorf(w * 0.4), 2), color)
			if h > 12.0 and w > 5.0:
				ci.draw_rect(Rect2(x + 2, ground_y - h + 3, 1, 2), color.lightened(0.12))
				ci.draw_rect(Rect2(x + w - 3, ground_y - h + 7, 1, 2), color.lightened(0.12))
		x += w + floorf(rng.randf_range(0.0, 4.0))


## Полоса земли от x0 до x1 и толща грунта вниз на depth пикселей.
static func paint_ground(ci: CanvasItem, x0: float, x1: float, ground_y: float, depth: float) -> void:
	ci.draw_rect(Rect2(x0, ground_y, x1 - x0, depth), DIRT)
	ci.draw_rect(Rect2(x0, ground_y, x1 - x0, 2), GROUND)
	ci.draw_rect(Rect2(x0, ground_y + 2, x1 - x0, 1), GROUND_DARK)
	var bands := [Color("261c16"), Color("211813"), Color("1c1410"), Color("17100d")]
	var y := ground_y + 40.0
	for c: Color in bands:
		if y >= ground_y + depth:
			break
		ci.draw_rect(Rect2(x0, y, x1 - x0, ground_y + depth - y), c)
		y += 44.0


## Бетонная будка входа; x — левый край, основание стоит на ground_y.
static func paint_entrance(ci: CanvasItem, x: float, ground_y: float, t: float) -> void:
	var y := ground_y - 16.0
	ci.draw_rect(Rect2(x - 3, y - 2, 30, 3), Color("55555c"))
	ci.draw_rect(Rect2(x - 3, y - 2, 30, 1), Color("7a7a82"))
	ci.draw_rect(Rect2(x, y + 1, 24, 15), Color("6b6a70"))
	ci.draw_rect(Rect2(x, y + 1, 1, 15), Color("8a8a92"))
	ci.draw_rect(Rect2(x + 23, y + 1, 1, 15), Color("3a3a42"))
	# Гермодверь
	ci.draw_rect(Rect2(x + 7, y + 4, 10, 12), Color("2a2a30"))
	ci.draw_rect(Rect2(x + 8, y + 5, 8, 11), Color("4a5a6a"))
	ci.draw_rect(Rect2(x + 11, y + 9, 2, 2), Color("e8b04a"))
	ci.draw_rect(Rect2(x + 8, y + 5, 8, 1), Color("6a7a8a"))
	# Сигнальная лампа
	var on := int(t * 1.5) % 2 == 0
	ci.draw_rect(Rect2(x + 11, y - 5, 2, 3), Color("ff5a40") if on else Color("6a2a20"))
	if on:
		ci.draw_rect(Rect2(x + 10, y - 6, 4, 5), Color(1.0, 0.35, 0.25, 0.25))
	# Трещины и трава
	ci.draw_rect(Rect2(x + 3, y + 6, 1, 4), Color("4a4a52"))
	ci.draw_rect(Rect2(x + 20, y + 10, 1, 3), Color("4a4a52"))
	ci.draw_rect(Rect2(x - 5, ground_y - 2, 1, 2), Color("6a6a3a"))
	ci.draw_rect(Rect2(x - 7, ground_y - 1, 1, 1), Color("6a6a3a"))
	ci.draw_rect(Rect2(x + 28, ground_y - 2, 1, 2), Color("6a6a3a"))
