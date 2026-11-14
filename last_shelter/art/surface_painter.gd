class_name SurfacePainter
extends RefCounted
## Рисует поверхность над убежищем: закатное небо, руины города и вход в бункер.
## Используется видом убежища и фоном главного меню.

## Доли высоты неба для шести полос (от зенита к горизонту).
const SKY_STOPS: Array[float] = [1.0, 0.62, 0.40, 0.24, 0.12, 0.05]
## Палитры неба по времени суток, от зенита к горизонту.
const SKY_PALETTES := {
	"night": [Color("0a0c18"), Color("0f1226"), Color("151a33"), Color("1b2140"), Color("222848"), Color("2a2f4c")],
	"dawn": [Color("1d2342"), Color("39385a"), Color("6b4f66"), Color("b0705a"), Color("e09a5c"), Color("f0c070")],
	"day": [Color("33495f"), Color("41586e"), Color("53697c"), Color("6c7f8c"), Color("8a979c"), Color("a6aca8")],
	"dusk": [Color("171425"), Color("241a30"), Color("3d2438"), Color("6a3238"), Color("a04e38"), Color("d07a3c")],
}
## Опорные точки суток [минута, палитра]; между ними цвета плавно смешиваются.
const SKY_KEYS := [
	[0.0, "night"], [330.0, "night"], [390.0, "dawn"], [510.0, "day"], [1020.0, "day"],
	[1140.0, "dusk"], [1260.0, "dusk"], [1320.0, "night"], [1440.0, "night"],
]
const DARKNESS := {"night": 1.0, "dusk": 0.55, "dawn": 0.45, "day": 0.0}
const SUN_RISE := 360.0
const SUN_SET := 1290.0
## Фон главного меню — вечер.
const MENU_MINUTE := 1200.0
const RUINS_FAR := Color("2a1c2c")
const RUINS_NEAR := Color("170f18")
const GROUND := Color("4a3e2c")
const GROUND_DARK := Color("33281c")
const DIRT := Color("2b2019")


## Между какими палитрами сейчас время суток: [палитра А, палитра Б, доля от А к Б].
static func _sky_segment(minute: float) -> Array:
	var m := fposmod(minute, 1440.0)
	for i in SKY_KEYS.size() - 1:
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if m >= float(a[0]) and m <= float(b[0]):
			var span := float(b[0]) - float(a[0])
			return [String(a[1]), String(b[1]), 0.0 if span <= 0.0 else (m - float(a[0])) / span]
	return ["night", "night", 0.0]


## Цвета полос неба в эту минуту.
static func sky_colors(minute: float) -> Array[Color]:
	var seg := _sky_segment(minute)
	var pa: Array = SKY_PALETTES[seg[0]]
	var pb: Array = SKY_PALETTES[seg[1]]
	var result: Array[Color] = []
	for i in pa.size():
		result.append((pa[i] as Color).lerp(pb[i], float(seg[2])))
	return result


## Насколько темно снаружи: 0 — день, 1 — ночь.
static func darkness(minute: float) -> float:
	var seg := _sky_segment(minute)
	return lerpf(float(DARKNESS[seg[0]]), float(DARKNESS[seg[1]]), float(seg[2]))


## Небо и руины от x0 до x1; земля на высоте ground_y, небо занимает sky_h пикселей.
## minute — время суток; солнце и луна ходят над видимым участком [view_from, view_to].
static func paint_sky(ci: CanvasItem, x0: float, x1: float, ground_y: float, sky_h: float, t: float,
		minute: float = MENU_MINUTE, view_from: float = NAN, view_to: float = NAN) -> void:
	if is_nan(view_from):
		view_from = x0
	if is_nan(view_to):
		view_to = x1
	var colors := sky_colors(minute)
	ci.draw_rect(Rect2(x0, ground_y - sky_h - 2000.0, x1 - x0, 2000.0), colors[0])
	for i in colors.size():
		var h := sky_h * SKY_STOPS[i]
		ci.draw_rect(Rect2(x0, ground_y - h, x1 - x0, h), colors[i])
	# Звёзды проступают в сумерках и ярче всего ночью.
	var dark := darkness(minute)
	if dark > 0.3:
		var alpha := 0.75 * clampf((dark - 0.3) / 0.5, 0.0, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 40:
			var sx := rng.randf_range(x0, x1)
			var sy := ground_y - sky_h * rng.randf_range(0.45, 1.0)
			var phase := rng.randf() * 10.0
			if sin(t * 0.8 + phase) > -0.5:
				ci.draw_rect(Rect2(floorf(sx), floorf(sy), 1, 1), Color(1, 0.95, 0.85, alpha))
	var width := view_to - view_from
	if minute >= SUN_RISE and minute <= SUN_SET:
		# Солнце: низкое и золотое на рассвете и закате, высокое и бледное днём.
		var p := (minute - SUN_RISE) / (SUN_SET - SUN_RISE)
		var arc := sin(p * PI)
		var sun_x := floorf(lerpf(view_from + width * 0.1, view_to - width * 0.1, p))
		var sun_y := floorf(ground_y - sky_h * (0.1 + 0.55 * arc))
		var sun := Color("f0b060").lerp(Color("f2e8c0"), arc)
		ci.draw_rect(Rect2(sun_x - 5, sun_y, 10, 9), sun)
		ci.draw_rect(Rect2(sun_x - 7, sun_y + 3, 14, 3), sun)
		ci.draw_rect(Rect2(sun_x - 3, sun_y - 2, 6, 2), sun)
		ci.draw_rect(Rect2(sun_x - 3, sun_y + 9, 6, 2), sun)
	elif dark > 0.6:
		# Месяц
		var mx := floorf(view_from + width * 0.72)
		var my := floorf(ground_y - sky_h * 0.55)
		ci.draw_rect(Rect2(mx, my, 6, 6), Color("e8e4d0"))
		ci.draw_rect(Rect2(mx + 1, my - 1, 4, 8), Color("e8e4d0"))
		ci.draw_rect(Rect2(mx - 1, my + 1, 8, 4), Color("e8e4d0"))
		ci.draw_rect(Rect2(mx + 3, my - 1, 4, 6), colors[0])
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
