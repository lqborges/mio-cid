class_name HonorMeters
extends Control

## Three distinct meters. Shape + pattern carry identity; hue is secondary (colorblind).

const METERS := [&"onores", &"honor", &"honra"]
const LABEL_KEYS := {
	&"onores": "hud.onores",
	&"honor": "hud.honor",
	&"honra": "hud.honra",
}
const GLOSS_KEYS := {
	&"onores": "hud.onores.gloss",
	&"honor": "hud.honor.gloss",
	&"honra": "hud.honra.gloss",
}
const TIP_KEYS := {
	&"onores": "hud.onores.tip",
	&"honor": "hud.honor.tip",
	&"honra": "hud.honra.tip",
}
const GLOSS_FALLBACK := {
	&"onores": "feudos",
	&"honor": "rey",
	&"honra": "nombre",
}
const LABEL_FALLBACK := {
	&"onores": "Honores",
	&"honor": "Honor",
	&"honra": "Honra",
}
const TIP_FALLBACK := {
	&"onores": "Honores: feudos y derecho a mantener mesnada.",
	&"honor": "Honor: valía ante el rey.",
	&"honra": "Honra: el nombre que os guardan en las salas.",
}
const PANEL_SIZE := Vector2(232, 228)
const COL_PAD := 10.0
const COLORS := {
	&"onores": Color(0.20, 0.68, 0.96),
	&"honor": Color(0.98, 0.74, 0.16),
	&"honra": Color(0.22, 0.82, 0.56),
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

const IRON := Color(0.08, 0.06, 0.04, 0.96)
const PARCHMENT := Color(0.97, 0.92, 0.80)
const INK := Color(0.05, 0.04, 0.03, 0.92)
const TRACK := Color(0.14, 0.12, 0.09)
const GLOSS_INK := Color(0.86, 0.78, 0.58)
const CAPTION_NODES := {
	&"onores": ["LabelOnores", "GlossOnores"],
	&"honor": ["LabelHonor", "GlossHonor"],
	&"honra": ["LabelHonra", "GlossHonra"],
}

var _name_labels: Array[Label] = []
var _gloss_labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	clip_contents = false
	add_to_group("hud_click_sink")
	_ensure_captions()
	_bind_state()
	if EventBus:
		EventBus.honor_logged.connect(_on_honor_logged)
	var loc := get_node_or_null("/root/Loc")
	if loc != null and loc.has_signal("locale_changed") and not loc.locale_changed.is_connected(_on_locale_changed):
		loc.locale_changed.connect(_on_locale_changed)
	_refresh_captions()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		accept_event()


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


func _on_locale_changed(_code: String) -> void:
	_refresh_captions()
	queue_redraw()


func caption_texts() -> PackedStringArray:
	_refresh_captions()
	var out := PackedStringArray()
	for lbl in _name_labels:
		out.append(lbl.text)
	return out


func gloss_texts() -> PackedStringArray:
	_refresh_captions()
	var out := PackedStringArray()
	for lbl in _gloss_labels:
		out.append(lbl.text)
	return out


func _ensure_captions() -> void:
	if _name_labels.size() == METERS.size():
		return
	_name_labels.clear()
	_gloss_labels.clear()
	var inner := PANEL_SIZE.x - COL_PAD * 2.0
	var col_w := inner / 3.0
	for i in METERS.size():
		var meter: StringName = METERS[i]
		var names: Array = CAPTION_NODES[meter]
		var name_lbl := get_node_or_null(str(names[0])) as Label
		if name_lbl == null:
			name_lbl = _make_caption(str(names[0]), 12, PARCHMENT)
			add_child(name_lbl)
		var gloss_lbl := get_node_or_null(str(names[1])) as Label
		if gloss_lbl == null:
			gloss_lbl = _make_caption(str(names[1]), 11, GLOSS_INK)
			add_child(gloss_lbl)
		var origin_x := COL_PAD + col_w * float(i)
		name_lbl.position = Vector2(origin_x, PANEL_SIZE.y - 38.0)
		name_lbl.size = Vector2(col_w, 16.0)
		gloss_lbl.position = Vector2(origin_x, PANEL_SIZE.y - 22.0)
		gloss_lbl.size = Vector2(col_w, 16.0)
		_name_labels.append(name_lbl)
		_gloss_labels.append(gloss_lbl)


func _make_caption(node_name: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.name = node_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


func _refresh_captions() -> void:
	_ensure_captions()
	for i in METERS.size():
		_name_labels[i].text = _meter_label(METERS[i])
		_gloss_labels[i].text = _meter_gloss(METERS[i])


func _meter_at(at_position: Vector2) -> StringName:
	var size := get_size()
	if size.x < 8.0:
		size = custom_minimum_size
	var inner := size.x - COL_PAD * 2.0
	var col_w := inner / 3.0
	if col_w <= 0.0:
		return &""
	var index := int(floor((at_position.x - COL_PAD) / col_w))
	if index < 0 or index >= METERS.size():
		return &""
	return METERS[index]


func _get_tooltip(at_position: Vector2) -> String:
	var meter := _meter_at(at_position)
	if meter == &"":
		return ""
	var label := _meter_label(meter)
	var gloss := _meter_gloss(meter)
	var tip := _meter_tip(meter)
	var value := _meter_value(meter)
	return "%s (%s)  %d\n%s" % [label, gloss, int(round(value)), tip]


func _draw() -> void:
	var size := get_size()
	if size.x < 8.0 or size.y < 8.0:
		size = custom_minimum_size
	draw_rect(Rect2(Vector2.ZERO, size), IRON)
	draw_rect(Rect2(Vector2.ZERO, size), PARCHMENT, false, 2.0)
	var honor := _honor()
	var inner := size.x - COL_PAD * 2.0
	var col_w := inner / 3.0
	for i in METERS.size():
		var meter: StringName = METERS[i]
		var value := 8.0 if meter == &"onores" else (15.0 if meter == &"honor" else 40.0)
		if honor:
			value = float(honor.get(meter))
		_draw_column(i, col_w, size.y, value, meter)


func _draw_column(index: int, col_w: float, height: float, value: float, meter: StringName) -> void:
	var origin := Vector2(COL_PAD + col_w * index, 0.0)
	var color: Color = COLORS[meter]
	var icon_c := origin + Vector2(col_w * 0.5, 22.0)
	_draw_shape(SHAPES[meter], icon_c, color)
	var bar := Rect2(origin.x + col_w * 0.24, 40.0, col_w * 0.52, height - 88.0)
	draw_rect(bar, TRACK)
	var ratio := clampf(value / 100.0, 0.0, 1.0)
	var fill_h := bar.size.y * ratio
	var fill := Rect2(bar.position.x, bar.position.y + bar.size.y - fill_h, bar.size.x, fill_h)
	draw_rect(fill, color)
	_draw_pattern(PATTERNS[meter], fill, Color(1.0, 1.0, 1.0, 0.22))
	draw_rect(bar, PARCHMENT, false, 2.0)
	var chip := Rect2(origin.x + 2.0, height - 40.0, col_w - 4.0, 36.0)
	draw_rect(chip, INK)


func _meter_value(meter: StringName) -> float:
	var honor := _honor()
	if honor:
		return float(honor.get(meter))
	if meter == &"onores":
		return 8.0
	if meter == &"honor":
		return 15.0
	return 40.0


func _meter_label(meter: StringName) -> String:
	var key := str(LABEL_KEYS.get(meter, ""))
	var fallback := str(LABEL_FALLBACK.get(meter, String(meter)))
	return _loc(key, fallback)


func _meter_gloss(meter: StringName) -> String:
	var key := str(GLOSS_KEYS.get(meter, ""))
	var fallback := str(GLOSS_FALLBACK.get(meter, ""))
	return _loc(key, fallback)


func _meter_tip(meter: StringName) -> String:
	var key := str(TIP_KEYS.get(meter, ""))
	var fallback := str(TIP_FALLBACK.get(meter, ""))
	return _loc(key, fallback)


func _loc(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var loc := get_node_or_null("/root/Loc")
	if loc == null or not loc.has_method("text"):
		return fallback
	var t := str(loc.call("text", key))
	if t.is_empty() or t == key:
		return fallback
	return t


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
