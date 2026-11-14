class_name PixelArt
extends RefCounted
## Собирает текстуры из «пиксельных карт» — массивов строк, где каждый символ
## соответствует цвету палитры. Вся графика игры создаётся так, без внешних файлов.

const OUTLINE := Color("14100e")


## rows — строки одинаковой длины; palette — символ -> Color; прочие символы прозрачны.
## outline добавляет тёмный контур в 1 пиксель; scale увеличивает без сглаживания.
static func make(rows: Array, palette: Dictionary, outline: bool = false, scale: int = 1) -> ImageTexture:
	var h := rows.size()
	var w := 0
	for row: String in rows:
		w = maxi(w, row.length())
	var pad := 1 if outline else 0
	var img := Image.create_empty(w + pad * 2, h + pad * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if palette.has(ch):
				img.set_pixel(x + pad, y + pad, palette[ch])
	if outline:
		img = _with_outline(img)
	if scale > 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


static func _with_outline(src: Image) -> Image:
	var out: Image = src.duplicate()
	var w := src.get_width()
	var h := src.get_height()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			var near := false
			if x > 0 and src.get_pixel(x - 1, y).a > 0.0:
				near = true
			elif x < w - 1 and src.get_pixel(x + 1, y).a > 0.0:
				near = true
			elif y > 0 and src.get_pixel(x, y - 1).a > 0.0:
				near = true
			elif y < h - 1 and src.get_pixel(x, y + 1).a > 0.0:
				near = true
			if near:
				out.set_pixel(x, y, OUTLINE)
	return out
