extends RefCounted
class_name PixelUIStyle

const INK := Color("10243a")
const PANEL := Color("183852")
const PANEL_HIGHLIGHT := Color("245273")
const PRIMARY := Color("45d8d0")
const GOLD := Color("ffd35a")
const HEALTH := Color("55e39a")
const SHIELD := Color("65c8ff")
const DANGER := Color("ff5a62")
const BOSS := Color("d967ff")
const TEXT := Color("fff4d2")
const MUTED := Color("718395")
const DIM := Color("0b1728")


static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(INK, 0.9))
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_stylebox("panel", "PanelContainer", make_panel(PRIMARY))
	theme.set_stylebox("normal", "Button", make_button(PANEL_HIGHLIGHT, PRIMARY))
	theme.set_stylebox("hover", "Button", make_button(Color("326b82"), GOLD))
	theme.set_stylebox("focus", "Button", make_button(Color("326b82"), GOLD))
	theme.set_stylebox("pressed", "Button", make_button(INK, GOLD))
	theme.set_stylebox("disabled", "Button", make_button(Color(PANEL, 0.65), MUTED))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", GOLD)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_font_size("font_size", "Button", 17)
	theme.set_stylebox("background", "ProgressBar", make_bar_background())
	theme.set_stylebox("fill", "ProgressBar", make_bar_fill(HEALTH))
	return theme


static func make_panel(border_color: Color = PRIMARY, fill_color: Color = PANEL) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.anti_aliasing = false
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(INK, 0.72)
	style.shadow_size = 4
	style.shadow_offset = Vector2(4, 4)
	return style


static func make_compact_panel(border_color: Color, fill_color: Color = PANEL, horizontal_margin: float = 8.0, vertical_margin: float = 5.0, border_width: int = 3) -> StyleBoxFlat:
	var style := make_panel(border_color, fill_color)
	style.set_border_width_all(border_width)
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


static func make_slot_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var fill := Color(PANEL_HIGHLIGHT, 0.98) if selected else Color(PANEL, 0.86)
	var border := accent if selected else Color(MUTED, 0.62)
	var style := make_panel(border, fill)
	style.set_border_width_all(4 if selected else 2)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.shadow_size = 3 if selected else 0
	return style


static func make_button(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := make_panel(border_color, fill_color)
	style.set_border_width_all(3)
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


static func make_bar_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DIM
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.anti_aliasing = false
	return style


static func make_bar_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.2)
	style.border_width_top = 2
	style.border_width_left = 2
	style.set_corner_radius_all(2)
	style.anti_aliasing = false
	return style
