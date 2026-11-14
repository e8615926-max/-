class_name MenuBackdrop
extends Control
## Анимированный пиксельный фон главного меню: поверхность и разрез убежища под ней.

const SCALE := 4.0

var _time: float = 0.0
var _accum: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	_accum += delta
	if _accum >= 0.2:
		_accum = 0.0
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
	var w := ceilf(size.x / SCALE)
	var h := ceilf(size.y / SCALE)
	var ground := floorf(h * 0.42)
	SurfacePainter.paint_sky(self, 0.0, w, ground, ground, _time)
	SurfacePainter.paint_ground(self, 0.0, w, ground, h - ground)

	# Вход и кусочек убежища в правой части экрана.
	var x := floorf(w * 0.56)
	SurfacePainter.paint_entrance(self, x - 2.0, ground, _time)
	var top := ground + 6.0
	draw_rect(Rect2(x, ground, 20, 6 + RoomPainter.H * 2), Color("17161a"))
	draw_rect(Rect2(x + 2, ground, 16, 4 + RoomPainter.H * 2), Color("101014"))
	draw_rect(Rect2(x + 4, ground, 1, 4 + RoomPainter.H * 2), Color("3a3a42"))
	draw_rect(Rect2(x + 15, ground, 1, 4 + RoomPainter.H * 2), Color("3a3a42"))
	var rooms := [["quarters", "farm"], ["generator", "water"]]
	for level in 2:
		for col in 2:
			var o := Vector2(x + 20 + col * RoomPainter.W, top + level * RoomPainter.H)
			if o.x < w:
				RoomPainter.paint(self, rooms[level][col], o, _time, true)
