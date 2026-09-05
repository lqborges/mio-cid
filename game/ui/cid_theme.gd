class_name CidTheme
extends RefCounted
## Shared iron / parchment chrome. Hue is secondary to shape.

const IRON := Color(0.18, 0.16, 0.13, 0.92)
const PARCHMENT := Color(0.91, 0.85, 0.72)
const INK := Color(0.82, 0.76, 0.64)
const DIM := Color(0.05, 0.04, 0.03, 0.62)
const TITLE_SIZE := 16
const DETAIL_SIZE := 13
const TOAST_TITLE := 18
const TOAST_BODY := 14


static func paint_label(label: Label, size: int = TITLE_SIZE, color: Color = PARCHMENT) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)


static func paint_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.80))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.94, 0.80))
	button.add_theme_color_override("font_pressed_color", Color(0.78, 0.70, 0.52))
	button.add_theme_color_override("font_disabled_color", Color(0.50, 0.46, 0.40))
	button.add_theme_font_size_override("font_size", 16)
