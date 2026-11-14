class_name UI
extends RefCounted
## Мелкие фабрики элементов интерфейса, чтобы панели собирались коротко и единообразно.


static func label(text: String, font_size: int = 20, color: Color = UITheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Текст с переносом строк, растягивается по ширине.
static func wrap_label(text: String, font_size: int = 18, color: Color = UITheme.TEXT_DIM) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 80
	return l


static func texture(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func icon(icon_name: String, scale: int = 3) -> TextureRect:
	return texture(PixelIcons.get_icon(icon_name, scale))


static func button(text: String, min_width: float = 0.0, min_height: float = UITheme.TOUCH) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, min_height)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func icon_button(icon_name: String, scale: int = 3, side: float = UITheme.TOUCH) -> Button:
	var b := button("", side, side)
	b.icon = PixelIcons.get_icon(icon_name, scale)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


## Выделенная янтарная кнопка для главного действия.
static func accent_button(text: String, min_width: float = 0.0, min_height: float = UITheme.TOUCH) -> Button:
	var b := button(text, min_width, min_height)
	b.add_theme_stylebox_override("normal", UITheme.button_box(UITheme.ACCENT_DARK, UITheme.ACCENT))
	b.add_theme_stylebox_override("hover", UITheme.button_box(UITheme.ACCENT_DARK.lightened(0.1), UITheme.ACCENT))
	b.add_theme_stylebox_override("pressed", UITheme.button_box(UITheme.ACCENT_DARK.darkened(0.2), UITheme.ACCENT, true))
	b.add_theme_color_override("font_color", UITheme.ACCENT.lightened(0.3))
	b.add_theme_color_override("font_hover_color", UITheme.ACCENT.lightened(0.5))
	return b


static func bar(value: float, min_value: float, max_value: float, color: Color,
		min_size: Vector2 = Vector2(140, 16)) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = min_value
	p.max_value = max_value
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = min_size
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("fill", UITheme.box(color, Color("0d0b0a"), 2, 0))
	return p


## Шкала от -100 до 100, заполняется от середины: влево — неприязнь, вправо — симпатия.
class RelationBar extends Control:
	var value: float = 0.0
	var color: Color = Color.WHITE

	func _init(bar_value: float, bar_color: Color) -> void:
		value = clampf(bar_value, -100.0, 100.0)
		color = bar_color
		custom_minimum_size = Vector2(200, 14)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0d0b0a"))
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), UITheme.PANEL_DARK)
		var mid := floorf(size.x * 0.5)
		var half := (size.x - 4.0) * 0.5 * absf(value) / 100.0
		if value >= 0.0:
			draw_rect(Rect2(mid, 2, half, size.y - 4), color)
		else:
			draw_rect(Rect2(mid - half, 2, half, size.y - 4), color)
		draw_rect(Rect2(mid - 1, 0, 2, size.y), UITheme.TEXT_DIM)


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hbox(separation: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


## Вложенная карточка внутри панели.
static func card(bg: Color = UITheme.PANEL_LIGHT, pad: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(bg, UITheme.BORDER, 2, pad))
	return p


## Вертикальная прокрутка; возвращает [ScrollContainer, VBoxContainer с содержимым].
static func scroll_list(separation: int = 8) -> Array:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := vbox(separation)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	return [sc, list]


static func section_title(text: String) -> Label:
	return label(text.to_upper(), 16, UITheme.ACCENT)


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Кнопки внутри прокрутки должны пропускать перетаскивание пальцем к ScrollContainer.
static func pass_scroll(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS


## Отключает перехват касаний у всего поддерева (для содержимого кнопок-карточек).
static func ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)


static func signed(value: int) -> String:
	return ("+%d" % value) if value > 0 else ("−%d" % absi(value) if value < 0 else "0")
