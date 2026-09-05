class_name PlazoBar
extends Control

## Nine-day exile countdown. Independent of camp_night / feed (PR-05a owns those).

const MAX_DAYS := 9
const HIDE_AFTER_BEAT := &"a1_navapalos"
const IRON := Color(0.08, 0.06, 0.04, 0.96)
const PARCHMENT := Color(0.97, 0.92, 0.80)
const INK := Color(0.05, 0.04, 0.03, 0.92)
const FILL := Color(0.72, 0.42, 0.86)

var days_left: int = 9


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(232, 36)
	size = custom_minimum_size
	add_to_group("hud_click_sink")
	_sync_from_clock()
	# Clock is a stub until PR-05a; skip per-frame polling when the field is absent.
	set_process(CampaignClock != null and "plazo_days_left" in CampaignClock)
	if EventBus and not EventBus.beat_completed.is_connected(_on_beat_completed):
		EventBus.beat_completed.connect(_on_beat_completed)
	var loc := get_node_or_null("/root/Loc")
	if loc != null and loc.has_signal("locale_changed") and not loc.locale_changed.is_connected(_on_locale_changed):
		loc.locale_changed.connect(_on_locale_changed)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		accept_event()


func _process(_delta: float) -> void:
	_sync_from_clock()


func _on_beat_completed(id: StringName) -> void:
	if id == HIDE_AFTER_BEAT:
		hide()


func _on_locale_changed(_code: String) -> void:
	queue_redraw()


func _sync_from_clock() -> void:
	# Duck-type the clock; never call camp_night — plazo is not a feeding segment.
	if CampaignClock != null and "plazo_days_left" in CampaignClock:
		days_left = int(CampaignClock.get("plazo_days_left"))
	queue_redraw()


func _get_tooltip(_at_position: Vector2) -> String:
	return "%s  %d / %d\n%s" % [_plazo_label(), days_left, MAX_DAYS, _plazo_tip()]


func _plazo_label() -> String:
	return _loc("hud.plazo", "Plazo")


func _plazo_tip() -> String:
	return _loc("hud.plazo.tip", "Días que restan del destierro de nueve jornadas.")


func _loc(key: String, fallback: String) -> String:
	var loc := get_node_or_null("/root/Loc")
	if loc == null or not loc.has_method("text"):
		return fallback
	var t := str(loc.call("text", key))
	if t.is_empty() or t == key:
		return fallback
	return t


func _draw() -> void:
	var size := get_size()
	if size.x < 8.0 or size.y < 8.0:
		size = custom_minimum_size
	draw_rect(Rect2(Vector2.ZERO, size), IRON)
	draw_rect(Rect2(Vector2.ZERO, size), PARCHMENT, false, 2.0)
	var font := ThemeDB.fallback_font
	var caption := "%s  %d" % [_plazo_label(), days_left]
	draw_rect(Rect2(6.0, 2.0, size.x - 12.0, 14.0), INK)
	draw_string(font, Vector2(8.0, 14.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PARCHMENT)
	var track := Rect2(8.0, 18.0, size.x - 16.0, 12.0)
	draw_rect(track, Color(0.14, 0.12, 0.09))
	var ratio := clampf(float(days_left) / float(MAX_DAYS), 0.0, 1.0)
	draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, track.size.y)), FILL)
	var step := track.size.x / float(MAX_DAYS)
	for i in range(1, MAX_DAYS):
		var x := track.position.x + step * i
		draw_line(Vector2(x, track.position.y), Vector2(x, track.position.y + track.size.y), PARCHMENT, 1.0)
	draw_rect(track, PARCHMENT, false, 1.5)
