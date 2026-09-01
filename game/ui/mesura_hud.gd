class_name MesuraHud
extends Control

## 720p ira / mesura bars and six trait ticks. Spanish labels via loc keys.

const LABEL_MESURA := "hud.mesura"
const LABEL_IRA := "hud.ira"
const IRON := Color(0.18, 0.16, 0.13, 0.92)
const PARCHMENT := Color(0.91, 0.85, 0.72)
const TRACK := Color(0.32, 0.28, 0.22)
const MESURA_FILL := Color(0.62, 0.58, 0.42)
const IRA_FILL := Color(0.62, 0.22, 0.18)
const TICK_ON := Color(0.85, 0.72, 0.38)
const TICK_OFF := Color(0.28, 0.24, 0.20)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(176, 88)
	add_to_group("hud_click_sink")
	set_process(true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		accept_event()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var size := get_size()
	if size.x < 8.0 or size.y < 8.0:
		size = custom_minimum_size
	draw_rect(Rect2(Vector2.ZERO, size), IRON)
	var font := ThemeDB.fallback_font
	var mesura_name := _loc(LABEL_MESURA)
	var ira_name := _loc(LABEL_IRA)
	draw_string(font, Vector2(8.0, 14.0), mesura_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PARCHMENT)
	_draw_bar(Rect2(8.0, 18.0, size.x - 16.0, 10.0), _mesura_ratio(), MESURA_FILL)
	draw_string(font, Vector2(8.0, 42.0), ira_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PARCHMENT)
	_draw_bar(Rect2(8.0, 46.0, size.x - 16.0, 10.0), _ira_ratio(), IRA_FILL)
	_draw_ticks(Rect2(8.0, 64.0, size.x - 16.0, 16.0))


func _draw_bar(track: Rect2, ratio: float, fill: Color) -> void:
	draw_rect(track, TRACK)
	var w := track.size.x * clampf(ratio, 0.0, 1.0)
	draw_rect(Rect2(track.position, Vector2(w, track.size.y)), fill)
	draw_rect(track, PARCHMENT, false, 1.0)


func _draw_ticks(area: Rect2) -> void:
	var cap := _trait_cap()
	if cap <= 0:
		return
	var gap := 4.0
	var w := (area.size.x - gap * float(cap - 1)) / float(cap)
	var owned := _unlocked_count()
	for i in cap:
		var r := Rect2(area.position.x + (w + gap) * i, area.position.y, w, area.size.y)
		draw_rect(r, TICK_ON if i < owned else TICK_OFF)
		draw_rect(r, PARCHMENT, false, 1.0)


func _mesura_ratio() -> float:
	var mes := _mesura()
	if mes != null:
		var mx := float(mes.traits.get("mesura_max", 0.0))
		if mx > 0.0:
			return mes.mesura / mx
	var honor := _honor()
	if honor != null:
		return clampf(honor.mesura / 100.0, 0.0, 1.0)
	return 0.0


func _ira_ratio() -> float:
	var mes := _mesura()
	if mes != null:
		var mx := float(mes.traits.get("ira_max", 0.0))
		if mx > 0.0:
			return mes.ira / mx
	var honor := _honor()
	if honor != null:
		return clampf(honor.rage / 100.0, 0.0, 1.0)
	return 0.0


func _trait_cap() -> int:
	var mes := _mesura()
	if mes != null:
		return int(mes.traits.get("trait_cap", 0))
	return 0


func _unlocked_count() -> int:
	var mes := _mesura()
	if mes == null:
		return 0
	return mes.unlocked.size()


func _mesura() -> MesuraComponent:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("mesura")
	for node in nodes:
		if node is MesuraComponent:
			return node
	return null


func _honor() -> HonorState:
	var tree := get_tree()
	if tree == null:
		return null
	var service := tree.root.get_node_or_null("HonorService")
	if service != null and "state" in service and service.state is HonorState:
		return service.state
	return null


func _loc(key: String) -> String:
	var tree := get_tree()
	if tree != null:
		var loc := tree.root.get_node_or_null("Loc")
		if loc != null and loc.has_method("text"):
			return str(loc.call("text", key))
	return key
