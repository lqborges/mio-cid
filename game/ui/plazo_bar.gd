class_name PlazoBar
extends Control

## Nine-day exile countdown. Independent of camp_night / feed (PR-05a owns those).

const MAX_DAYS := 9
const HIDE_AFTER_BEAT := &"a1_navapalos"
const IRON := Color(0.18, 0.16, 0.13, 0.92)
const PARCHMENT := Color(0.91, 0.85, 0.72)
const FILL := Color(0.35, 0.33, 0.38)

var days_left: int = 9


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(232, 36)
	add_to_group("hud_click_sink")
	_sync_from_clock()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		accept_event()
	# Clock is a stub until PR-05a; skip per-frame polling when the field is absent.
	set_process(CampaignClock != null and "plazo_days_left" in CampaignClock)
	if EventBus:
		EventBus.beat_completed.connect(_on_beat_completed)


func _process(_delta: float) -> void:
	_sync_from_clock()


func _on_beat_completed(id: StringName) -> void:
	if id == HIDE_AFTER_BEAT:
		hide()


func _sync_from_clock() -> void:
	# Duck-type the clock; never call camp_night — plazo is not a feeding segment.
	if CampaignClock != null and "plazo_days_left" in CampaignClock:
		days_left = int(CampaignClock.get("plazo_days_left"))
	queue_redraw()


func _draw() -> void:
	var size := get_size()
	if size.x < 8.0 or size.y < 8.0:
		size = custom_minimum_size
	draw_rect(Rect2(Vector2.ZERO, size), IRON)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8.0, 14.0), "plazo", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PARCHMENT)
	var track := Rect2(8.0, 18.0, size.x - 16.0, 12.0)
	draw_rect(track, Color(0.32, 0.28, 0.22))
	var ratio := clampf(float(days_left) / float(MAX_DAYS), 0.0, 1.0)
	draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, track.size.y)), FILL)
	var step := track.size.x / float(MAX_DAYS)
	for i in range(1, MAX_DAYS):
		var x := track.position.x + step * i
		draw_line(Vector2(x, track.position.y), Vector2(x, track.position.y + track.size.y), PARCHMENT, 1.0)
	draw_rect(track, PARCHMENT, false, 1.0)
