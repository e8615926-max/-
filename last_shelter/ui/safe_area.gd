class_name SafeArea
extends RefCounted
## Отступ от выреза камеры и скруглённых углов экрана на телефонах.
## Берётся одинаковым слева и справа: при повороте телефона на 180°
## вырез переезжает на другую сторону, а раскладка остаётся корректной.

## Больше этого отступа не бывает даже на самых «зубастых» экранах.
const MAX_INSET := 120.0


## Боковой отступ в координатах интерфейса (0 на ПК и на экранах без выреза).
static func side_inset(viewport: Viewport) -> float:
	if viewport == null or not OS.has_feature("mobile"):
		return 0.0
	var window := Rect2(Vector2(DisplayServer.window_get_position()), Vector2(DisplayServer.window_get_size()))
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window.size.x <= 0.0 or safe.size.x <= 0.0:
		return 0.0
	var left := maxf(safe.position.x - window.position.x, 0.0)
	var right := maxf(window.end.x - safe.end.x, 0.0)
	var factor := viewport.get_visible_rect().size.x / window.size.x
	return clampf(maxf(left, right) * factor, 0.0, MAX_INSET)
