class_name UITheme
extends RefCounted
## Единая тема интерфейса: тёмный «бункерный» фон, янтарные акценты,
## прямые углы и толстые рамки под пиксельную графику.

const BG := Color("14110f")
const PANEL := Color("231e19")
const PANEL_LIGHT := Color("332b24")
const PANEL_DARK := Color("1a1613")
const BORDER := Color("6b5a45")
const ACCENT := Color("e8b04a")
const ACCENT_DARK := Color("6e4f1c")
const TEAL := Color("5fc2b0")
const TEXT := Color("efe6d0")
const TEXT_DIM := Color("a89c86")
const GOOD := Color("8fd06a")
const BAD := Color("e0655a")

## Минимальная высота кнопки, удобная для пальца.
const TOUCH := 64


static func box(bg: Color, border: Color, border_w: int = 2, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_content_margin_all(pad)
	s.anti_aliasing = false
	return s


## Кнопка с утолщённой нижней гранью — выглядит объёмной.
static func button_box(bg: Color, border: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := box(bg, border, 2, 12)
	if pressed:
		s.border_width_top = 5
		s.border_width_bottom = 2
	else:
		s.border_width_bottom = 5
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20

	t.set_stylebox("normal", "Button", button_box(PANEL_LIGHT, BORDER))
	t.set_stylebox("hover", "Button", button_box(PANEL_LIGHT.lightened(0.08), ACCENT))
	t.set_stylebox("pressed", "Button", button_box(ACCENT_DARK, ACCENT, true))
	t.set_stylebox("disabled", "Button", button_box(PANEL_DARK, PANEL_LIGHT))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(TEXT_DIM, 0.5))
	t.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_constant("h_separation", "Button", 10)

	t.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 3, 16))
	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("background", "ProgressBar", box(PANEL_DARK, Color("0d0b0a"), 2, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color("0d0b0a"), 2, 0))

	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("h_separation", "HFlowContainer", 8)
	t.set_constant("v_separation", "HFlowContainer", 8)
	t.set_constant("h_separation", "GridContainer", 10)
	t.set_constant("v_separation", "GridContainer", 10)

	var sep := StyleBoxFlat.new()
	sep.bg_color = BORDER
	sep.content_margin_top = 1
	sep.content_margin_bottom = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 10)

	var grabber := box(BORDER, BORDER, 0, 0)
	grabber.content_margin_left = 4
	grabber.content_margin_right = 4
	t.set_stylebox("scroll", "VScrollBar", box(PANEL_DARK, PANEL_DARK, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	return t
