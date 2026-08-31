class_name HonorMeters
extends Control

## Three distinct meters. Shape + pattern carry identity; hue is secondary (colorblind).

const METERS := [&"onores", &"honor", &"honra"]
const LABELS := {
	&"onores": "onores",
	&"honor": "honor",
	&"honra": "honra",
}
const COLORS := {
	&"onores": Color(0.0, 0.45, 0.70),
	&"honor": Color(0.90, 0.62, 0.0),
	&"honra": Color(0.0, 0.62, 0.45),
}
const PATTERNS := {
	&"onores": &"hatch",
	&"honor": &"dots",
	&"honra": &"chevron",
}
const SHAPES := {
	&"onores": &"chest",
	&"honor": &"seal",
	&"honra": &"beard",
}

const IRON := Color(0.18, 0.16, 0.13, 0.92)
const PARCHMENT := Color(0.91, 0.85, 0.72)
const TRACK := Color(0.32, 0.28, 0.22)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(176, 228)
	_bind_state()
	if EventBus:
		EventBus.honor_logged.connect(_on_honor_logged)


func _bind_state() -> void:
	var honor := _honor()
	if honor == null:
		return
	if not honor.meter_changed.is_connected(_on_meter_changed):
		honor.meter_changed.connect(_on_meter_changed)
	queue_redraw()


func _honor() -> HonorState:
	if GameState == null:
		return null
	var value: Variant = GameState.honor()
	return value if value is HonorState else null


func _on_honor_logged(_event: HonorEvent) -> void:
	queue_redraw()


func _on_meter_changed(_meter: StringName, _old: float, _new: float, _id: StringName) -> void:
	queue_redraw()


func _draw() -> void:
	var size := get_size()
	if size.x < 8.0 or size.y < 8.0:
		size = custom_minimum_size
	draw_rect(Rect2(Vector2.ZERO, size), IRON)
	var honor := _honor()
	var col_w := size.x / 3.0
	for i in METERS.size():
		var meter: StringName = METERS[i]
		var value := 8.0 if meter == &"onores" else (15.0 if meter == &"honor" else 40.0)
		if honor:
			value = float(honor.get(meter))
		_draw_column(i, col_w, size.y, value, meter)


func _draw_column(index: int, col_w: float, height: float, value: float, meter: StringName) -> void:
	var origin := Vector2(col_w * index, 0.0)
	var color: Color = COLORS[meter]
	var icon_c := origin + Vector2(col_w * 0.5, 22.0)
	_draw_shape(SHAPES[meter], icon_c, color)
	var bar := Rect2(origin.x + col_w * 0.28, 40.0, col_w * 0.44, height - 72.0)
	draw_rect(bar, TRACK)
	var ratio := clampf(value / 100.0, 0.0, 1.0)
	var fill_h := bar.size.y * ratio
	var fill := Rect2(bar.position.x, bar.position.y + bar.size.y - fill_h, bar.size.x, fill_h)
	draw_rect(fill, color)
	_draw_pattern(PATTERNS[meter], fill, color.darkened(0.35))
	draw_rect(bar, PARCHMENT, false, 1.5)
	var font := ThemeDB.fallback_font
	var font_size := 12
	var label := LABELS[meter]
	var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		Vector2(origin.x + (col_w - text_w) * 0.5, height - 10.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		PARCHMENT,
	)


func _draw_shape(shape: StringName, center: Vector2, color: Color) -> void:
	match shape:
		&"chest":
			var r := Rect2(center.x - 10.0, center.y - 7.0, 20.0, 14.0)
			draw_rect(r, color)
			draw_rect(Rect2(center.x - 10.0, center.y - 10.0, 20.0, 4.0), color.lightened(0.2))
			draw_rect(r, PARCHMENT, false, 1.2)
		&"seal":
			draw_circle(center, 9.0, color)
			draw_arc(center, 9.0, 0.0, TAU, 24, PARCHMENT, 1.2)
			draw_circle(center, 3.0, PARCHMENT)
		&"beard":
			var pts := PackedVector2Array([
				center + Vector2(0.0, -9.0),
				center + Vector2(9.0, 2.0),
				center + Vector2(0.0, 10.0),
				center + Vector2(-9.0, 2.0),
			])
			draw_colored_polygon(pts, color)
			var outline := PackedVector2Array(pts)
			outline.append(pts[0])
			draw_polyline(outline, PARCHMENT, 1.2)


func _draw_pattern(kind: StringName, fill: Rect2, ink: Color) -> void:
	if fill.size.y < 2.0:
		return
	match kind:
		&"hatch":
			var y := fill.position.y + 2.0
			while y < fill.position.y + fill.size.y:
				draw_line(
					Vector2(fill.position.x, y),
					Vector2(fill.position.x + fill.size.x, y),
					ink,
					1.0,
				)
				y += 4.0
		&"dots":
			var y := fill.position.y + 3.0
			var row := 0
			while y < fill.position.y + fill.size.y:
				var x := fill.position.x + (3.0 if row % 2 == 0 else 6.0)
				while x < fill.position.x + fill.size.x - 1.5:
					draw_circle(Vector2(x, y), 1.2, ink)
					x += 5.0
				y += 5.0
				row += 1
		&"chevron":
			var y := fill.position.y + 3.0
			while y < fill.position.y + fill.size.y - 2.0:
				var mid := fill.position.x + fill.size.x * 0.5
				draw_line(
					Vector2(fill.position.x + 2.0, y + 3.0),
					Vector2(mid, y),
					ink,
					1.0,
				)
				draw_line(
					Vector2(mid, y),
					Vector2(fill.position.x + fill.size.x - 2.0, y + 3.0),
					ink,
					1.0,
				)
				y += 5.0
