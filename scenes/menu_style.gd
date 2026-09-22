extends RefCounted
## Gemeinsamer Neon-Look fuer End-Menüs (Game Over / Victory):
## dunkles Panel mit Cyan-Rahmen, Primary-Button in Sonar-Cyan,
## Secondary-Button als Ghost mit Rahmen. Eine Quelle, kein Copy-Paste.

const CYAN := Color(0.3, 1.0, 0.9)
const CYAN_DIM := Color(0.2, 0.65, 0.6)
const TEXT_MAIN := Color(0.9, 0.97, 0.98)
const TEXT_DIM := Color(0.6, 0.75, 0.78)
const PANEL_BG := Color(0.03, 0.07, 0.1, 0.94)
const BTN_BG := Color(0.1, 0.5, 0.55)
const BTN_HOVER := Color(0.16, 0.68, 0.72)
const BTN_PRESS := Color(0.07, 0.36, 0.4)
const BTN_TEXT := Color(0.02, 0.08, 0.09)


static func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = CYAN
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 36.0
	s.content_margin_right = 36.0
	s.content_margin_top = 28.0
	s.content_margin_bottom = 28.0
	return s


static func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 16.0
	s.content_margin_right = 16.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	return s


static func apply_panel(p: PanelContainer) -> void:
	p.add_theme_stylebox_override("panel", _panel_style())


static func style_title(l: Label, color: Color, size: int) -> void:
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)


static func style_text(l: Label, size: int) -> void:
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.add_theme_font_size_override("font_size", size)


static func style_button(b: Button, primary: bool) -> void:
	if primary:
		b.add_theme_stylebox_override("normal", _btn_style(BTN_BG, BTN_BG))
		b.add_theme_stylebox_override("hover", _btn_style(BTN_HOVER, BTN_HOVER))
		b.add_theme_stylebox_override("pressed", _btn_style(BTN_PRESS, BTN_PRESS))
		b.add_theme_stylebox_override("focus", _btn_style(BTN_HOVER, CYAN))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", TEXT_MAIN)
	else:
		b.add_theme_stylebox_override("normal", _btn_style(Color(0, 0, 0, 0), CYAN_DIM))
		b.add_theme_stylebox_override("hover", _btn_style(Color(0.15, 0.4, 0.42, 0.5), CYAN))
		b.add_theme_stylebox_override("pressed", _btn_style(Color(0.07, 0.3, 0.32, 0.6), CYAN))
		b.add_theme_stylebox_override("focus", _btn_style(Color(0.15, 0.4, 0.42, 0.5), CYAN))
		b.add_theme_color_override("font_color", CYAN)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", 20)
